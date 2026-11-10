<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# IPAddressClaim sub-conditions

## Status

provisional

## Summary

IP Address Manager (IPAM) reports the result of an allocation on the Cluster
API `IPAddressClaim` with a single condition, `Ready`, and it writes that
condition directly at every success and error site. We propose to set two
sub-conditions instead, `IPAddressAllocated` and `IPAddressCreated`, and to
derive `Ready` from them in one place with the Cluster API helper
`conditions.SetSummaryCondition`.

`Ready` keeps the reasons that the Cluster API `IPAddressClaim` types define
(`PoolExhausted` and `AllocationFailed`) and becomes `True` with reason
`Ready` when both sub-conditions are `True`. The specific failure causes
(invalid requested IP, requested IP in use or outside every pool,
pre-allocation problems, invalid prefix, pool exhausted) become reasons on
`IPAddressAllocated`.

This is the approach asked for in
[issue #1538](https://github.com/metal3-io/ip-address-manager/issues/1538),
and it also fixes a bug: a claim that was allocated successfully never gets a
`Ready` condition today. Claims that were bound by an older version get the
conditions once, after the upgrade. The implementation is
[PR #1698](https://github.com/metal3-io/ip-address-manager/pull/1698), which
is on hold until this proposal is agreed.

## Motivation

What is wrong on main today:

1. **A successful claim never gets `Ready`.** Both success sites (the re-link
   path and the path after the `IPAddress` is created) set `Ready=True` with
   no reason. The `IPAddressClaim` v1beta2 CRD shipped with Cluster API
   v1.14 requires a reason of at least one character on every condition, so
   the API server rejects the conditions patch. The claim still gets
   `status.addressRef`, so consumers that wait for the address keep working
   (CAPM3 only reads `status.addressRef`, in
   `baremetal/metal3data_manager.go`), but nobody can see `Ready` on a claim
   that worked. IPAM has set `Ready` without a reason since v1.13.0, the first
   release that has the condition. An `envtest` run of `capiUpdateAddresses`
   against the real CRD in
   [PR #1698](https://github.com/metal3-io/ip-address-manager/pull/1698)
   hits the error on main and not on the branch.
1. **`Ready` is written in nine places**, six in `capiAllocateAddress` and
   three in `capiCreateAddress`. Six different failures all end up as
   `AllocationFailed`, and only the free-text message tells them apart.
   [Issue #1538](https://github.com/metal3-io/ip-address-manager/issues/1538)
   asks for `Ready` to be a summary of sub-conditions, as in the Cluster API
   condition model and in CAPM3 (`patchMetal3Machine`).
1. **Retries depend on that one condition.** `capiUpdateAddresses` skips a
   claim that has `status.addressRef` unless `anyErrorInExistingClaim` finds
   `Ready` with reason `AllocationFailed` or `PoolExhausted`. A site that sets
   `Ready` wrongly, or forgets to, changes retry behavior. Also, a transient
   `IPAddress` create error (the object already exists) does not touch `Ready`
   on main, so an old value stays.
1. **A requested IP outside every pool is reported as `PoolExhausted`.** The
   `ipAddress` annotation on a claim asks for one specific address. If that
   address is in none of the pools, the claim can never be fulfilled, whether
   or not the pools are full. `Ready` still says `PoolExhausted` with the
   message `Exhausted IP Pools`. The Cluster API types define `PoolExhausted`
   as the reason for a pool that is full, and `AllocationFailed` for other
   failures.

Open PRs add more direct writes of `Ready`
([PR #1527](https://github.com/metal3-io/ip-address-manager/pull/1527)
re-link and recover,
[PR #1564](https://github.com/metal3-io/ip-address-manager/pull/1564) name
collision), so the number of sites will grow if we do nothing.

### Goals

- `Ready` always has a reason and is computed in exactly one place.
- Every failure cause is a machine-readable reason, so users do not have to
  parse messages.
- `Ready` keeps the reasons that the Cluster API `IPAddressClaim` types define,
  and `PoolExhausted` is only used for a pool that is full.
- Claims written by older versions keep being retried correctly after an
  upgrade, with no action from the user.
- Claims that were bound by an older version get the sub-conditions and a
  `Ready` condition after an upgrade, with no action from the user.

### Non-Goals

- The metal3 `IPClaim` (`ipam.metal3.io`). It reports errors in
  `status.errorMessage` and does not change. This includes the message it
  reports for a requested IP that is outside every pool.
- New fields, new CRDs, or changes to `IPPool` and `IPAddress`.
- Changing how an address is chosen. The same claims succeed and fail as
  before and are retried at the same pace. Only the reason and the message
  reported for a requested IP outside every pool change.
- The Cluster API reason `PoolNotReady`. IPAM does not set it today and this
  does not add it.
- A flag, an annotation or a migration job for the backfill of bound claims
  (see Upgrade).

## Proposal

IPAM sets two sub-conditions on the `IPAddressClaim` while it reconciles it.
Just before the claim is patched, IPAM derives `Ready` from them. No other
code writes `Ready`.

**`IPAddressAllocated`** says whether an address was picked from the pool.

| Status | Reason | Meaning |
|--------|--------|---------|
| True | `Allocated` | An address was picked, or the claim was re-linked to its existing allocation |
| False | `InvalidRequestedIP` | The `ipAddress` annotation is not a valid IP |
| False | `PreAllocationConflict` | The annotation and `spec.preAllocations` name different IPs for this claim |
| False | `RequestedIPNotAvailable` | The requested IP is in a pool but already in use |
| False | `RequestedIPOutOfBounds` | The requested IP is not in any pool |
| False | `PreAllocationOutOfBounds` | The pre-allocated IP is not in any pool |
| False | `InvalidPrefix` | The resolved prefix is outside 0 to 128 |
| False | `PoolExhausted` | No free address in any pool, for a claim that does not request an IP (the Cluster API constant) |

**`IPAddressCreated`** says whether the `IPAddress` object exists. It is only
set once an address has been allocated, and it is removed again when an
allocation fails, because no `IPAddress` can exist without an address.

| Status | Reason | Meaning |
|--------|--------|---------|
| True | `Created` | The `IPAddress` exists and `status.addressRef` points to it |
| False | `CreateFailed` | Creating the `IPAddress` failed with a non-transient error |
| Unknown | `CreatePending` | Creating the `IPAddress` hit a transient error (it already exists) and is retried |

**`Ready`** is the summary of the two, with a custom reason function:

| IPAddressAllocated | IPAddressCreated | Ready | Reason |
|--------------------|------------------|-------|--------|
| True | True | True | `Ready` |
| False, reason `PoolExhausted` | not set | False | `PoolExhausted` |
| False, any other reason | not set | False | `AllocationFailed` |
| True | False | False | `AllocationFailed` |
| True | Unknown | Unknown | `ReadyUnknown` |
| not set | not set | Unknown | `ReadyUnknown` |

The `Ready` message is the standard summary format, for example
`* IPAddressAllocated: Exhausted IP Pools`. When both sub-conditions are True
the message is empty.

**A requested IP.** The `ipAddress` annotation is the only way to ask for a
specific address, because the `IPAddressClaim` spec has only `clusterName` and
`poolRef`. A claim with a valid requested IP that does not conflict with a
pre-allocation ends in one of three states:

- The IP is in a pool and free, and it is allocated.
- The IP is in a pool and in use. `IPAddressAllocated` has reason
  `RequestedIPNotAvailable`.
- The IP is in no pool. `IPAddressAllocated` has the new reason
  `RequestedIPOutOfBounds` and the message
  `Requested IP <ip> is not in any pool`.

Such a claim is never given another address, so it never gets `PoolExhausted`,
not even when the pools are full. `Ready` is `False` with reason
`AllocationFailed` in both failure states. Cluster API keeps `PoolExhausted`
for a pool that is full. The retry does not change: the error is transient and
the claim is requeued after 15 seconds, and a change of the `IPPool` or of the
claim enqueues the pool at once, because the controller watches both. A claim
whose requested IP equals an out-of-range pre-allocation keeps the reason
`PreAllocationOutOfBounds`.

### Examples

The examples show the `status` of a claim. `lastTransitionTime` and
`observedGeneration` are left out. A successful claim looks like this:

```yaml
status:
  addressRef:
    name: pool-192-168-0-10
  conditions:
  - type: Ready
    status: "True"
    reason: Ready
    message: ""
  - type: IPAddressAllocated
    status: "True"
    reason: Allocated
    message: ""
  - type: IPAddressCreated
    status: "True"
    reason: Created
    message: ""
```

The pool has no free address left. `IPAddressCreated` is not set and there is no
`status.addressRef`:

```yaml
status:
  conditions:
  - type: Ready
    status: "False"
    reason: PoolExhausted
    message: '* IPAddressAllocated: Exhausted IP Pools'
  - type: IPAddressAllocated
    status: "False"
    reason: PoolExhausted
    message: Exhausted IP Pools
```

The claim has the annotation `ipAddress: 192.168.0.10`, and that address is in
the pool but already used by another claim:

```yaml
status:
  conditions:
  - type: Ready
    status: "False"
    reason: AllocationFailed
    message: '* IPAddressAllocated: Requested IP not available'
  - type: IPAddressAllocated
    status: "False"
    reason: RequestedIPNotAvailable
    message: Requested IP not available
```

The claim has the annotation `ipAddress: 192.168.1.5`, and that address is in
none of the pools. The pool may have free addresses, and the claim is not
given another one:

```yaml
status:
  conditions:
  - type: Ready
    status: "False"
    reason: AllocationFailed
    message: '* IPAddressAllocated: Requested IP 192.168.1.5 is not in any pool'
  - type: IPAddressAllocated
    status: "False"
    reason: RequestedIPOutOfBounds
    message: Requested IP 192.168.1.5 is not in any pool
```

An address was allocated, but creating the `IPAddress` failed with a
non-transient error. There is no `status.addressRef`:

```yaml
status:
  conditions:
  - type: Ready
    status: "False"
    reason: AllocationFailed
    message: '* IPAddressCreated: Failed to create associated IPAddress object'
  - type: IPAddressAllocated
    status: "True"
    reason: Allocated
    message: ""
  - type: IPAddressCreated
    status: "False"
    reason: CreateFailed
    message: Failed to create associated IPAddress object
```

Creating the `IPAddress` hit a transient error (it already exists), so it is
retried and `Ready` is Unknown, not failed:

```yaml
status:
  conditions:
  - type: Ready
    status: Unknown
    reason: ReadyUnknown
    message: '* IPAddressCreated: Waiting to create associated IPAddress object'
  - type: IPAddressAllocated
    status: "True"
    reason: Allocated
    message: ""
  - type: IPAddressCreated
    status: Unknown
    reason: CreatePending
    message: Waiting to create associated IPAddress object
```

### User Stories

#### Story 1

As an operator, when a claim is stuck I want to see why from its conditions
(`kubectl describe ipaddressclaim`), for example `RequestedIPNotAvailable`,
`RequestedIPOutOfBounds` or `PoolExhausted`, without reading controller logs.

#### Story 2

As a developer of a tool that watches claims, I want `Ready=True` to appear
when the claim is bound, and I want `PoolExhausted` and `AllocationFailed` to
keep the meaning that the Cluster API `IPAddressClaim` types give them.

## Design Details

### Implementation Details/Notes/Constraints

The code is in `ipam/conditions.go` and `ipam/ippool_manager.go`.

- `capiAllocateAddress` and `capiCreateAddress` only set sub-conditions, using
  `setIPAddressAllocationFailed` and `setIPAddressClaimSubCondition`.
- `capiUpdateAddress` calls `setIPAddressClaimReadyCondition` in the deferred
  function, before `helper.Patch`. It does not do it for a claim that is being
  deleted. If the summary fails, the error is logged and returned.
- `setIPAddressClaimReadyCondition` calls `conditions.SetSummaryCondition`
  with `ForConditionTypes{IPAddressAllocated, IPAddressCreated}`,
  `IgnoreTypesIfMissing{IPAddressCreated}` (it is not set until an address is
  allocated) and a `CustomMergeStrategy` whose reason function gives the
  `Ready` reason from the table above.
- The patch helper is given `Ready`, `IPAddressAllocated` and
  `IPAddressCreated` as owned conditions.
- **Names and constants.** The condition types are `IPAddressAllocated` and
  `IPAddressCreated`. The constants for the types and the reasons are in
  `ipam/conditions.go` and stay in `ipam/`. More sub-conditions can be added
  later if there is a need: a new type goes into `ForConditionTypes` and into
  the owned conditions, and gets a row in `docs/api.md`.
- **A requested IP outside every pool.** `capiAllocateAddress` scans the pools
  one by one for a requested IP, and it remembers whether the scan reached
  that IP, free or not. After the checks for a requested IP in use and for a
  pre-allocation outside the pools, a claim with a requested IP that the scan
  never reached gets `IPAddressAllocated=False` with reason
  `RequestedIPOutOfBounds`, and a transient error with the same 15 second
  requeue as `RequestedIPNotAvailable`. The check needs a requested IP, so a
  claim without one still gets `PoolExhausted` when the pools are full.
- `anyErrorInExistingClaim` still looks at the reason of `Ready`. Because
  `Ready` is now derived, it sees `AllocationFailed` or `PoolExhausted`
  whenever an allocation or create failed, and a transient create error
  (`Ready=Unknown`) is retried because that claim has no `status.addressRef`.
- **Claims written by older versions.** They have a `Ready` and no
  sub-conditions. While `IPAddressAllocated` is missing and `Ready` exists,
  `Ready` is left as it is. This matters because the re-link path returns
  early (the `IPAddress` is being deleted, or the `Get` fails) before any
  sub-condition is set. Summarizing there would turn a failed `Ready` into
  Unknown, and for a claim that has `status.addressRef` set,
  `capiUpdateAddresses` would then skip it for good. This guard came up in
  the PR review, and it can be narrowed to claims with a stored failure, or
  dropped. Once a reconcile sets a sub-condition, `Ready` is derived and
  replaces the old one.
- Reasons must match the condition reason pattern in the CRD
  (`^[A-Za-z]([A-Za-z0-9_,:]*[A-Za-z0-9_])?$`). All of the above do.
- Messages are free text. Only types and reasons are meant to be matched on.

#### Backfill for claims bound by an older version

`capiUpdateAddresses` skips a claim that has `status.addressRef` and no error
in `Ready`, so a claim that was bound before this change would never get
`IPAddressAllocated`, `IPAddressCreated` or a derived `Ready`. Setting them
"when next reconciled" would mean never. With the v1.14 CRD such a claim has
an `addressRef` and no conditions at all, because older versions tried to
write `Ready=True` with an empty reason, which the CRD rejects. A claim with a
stale failed `Ready` is already reconciled again today.

The controller therefore reconciles a bound claim once more when it has no
`IPAddressAllocated` condition, the pool has an allocation for it, and
`status.addressRef` equals the `IPAddress` name computed from that allocation.
The pass uses the existing re-link path. It reads the `IPAddress`, sets both
sub-conditions, computes `Ready` and patches the claim status once. It cannot
allocate an address, create an `IPAddress` or change `addressRef`. Afterwards
the claim has `IPAddressAllocated`, so it is skipped like any other bound
claim. The cost is one `IPAddress` read and one status patch for each such
claim, once, and nothing on later reconciles.

A claim whose `IPAddress` is gone, or was created under another `namePrefix`,
is left as it was. If the `IPAddress` is terminating, no sub-condition is set
and the claim is requeued every 5 seconds for as long as the `IPAddress`
exists, as a claim with a failed `Ready` is today. A stored `Ready` is kept,
and a claim with no `Ready` gets `Ready=Unknown`. No flag, annotation or
migration job is needed.

#### API and user impact

- **`Ready=True` now exists.** It has reason `Ready`. Users see it for the
  first time on successful claims, and on claims bound by an older version
  after the upgrade.
- **The `Ready` message format changes** from the plain message
  (`Exhausted IP Pools`) to the summary format
  (`* IPAddressAllocated: Exhausted IP Pools`). Anything that matches on the
  message text breaks. The reason is stable.
- **A requested IP outside every pool changes reason.** `Ready` goes from
  `PoolExhausted` to `AllocationFailed`, and `IPAddressAllocated` has the new
  reason `RequestedIPOutOfBounds`. Anything outside IPAM that matches on
  `PoolExhausted` for these claims sees a different reason.
- **Two new condition types appear on a Cluster API object.** The claim kind
  is owned by Cluster API, whose field docs list `Ready` as the known type.
  The `conditions` list is a map with room for 32 entries, so extra types are
  valid, but `IPAddressAllocated`, `IPAddressCreated` and their reasons are
  Metal3 specific and not defined by Cluster API. The reference
  tables for them go in the IPAM docs (`docs/api.md`), in the same PR as the
  code.
- **The Cluster API reasons stay.** `Ready` still has reasons `PoolExhausted`
  and `AllocationFailed`, and `status.addressRef` is still set when the claim
  is fulfilled. `PoolExhausted` is now only used for a pool that is full.
- **A transient create error is `Ready=Unknown`**, not a failure and not
  unchanged as on main.

### Risks and Mitigations

- *Consumers matching on the old `Ready` message.* CAPM3 does not read claim
  conditions. Other consumers are unknown to us. The reason is unchanged, and
  the release notes call out the message change.
- *Consumers matching on `PoolExhausted` for a requested IP outside every
  pool.* This is the one case where the `Ready` reason changes. CAPM3 does not
  read claim conditions, and other consumers are unknown to us. The release
  notes call it out.
- *A bound claim that is reconciled early turns Unknown.* Handled by keeping
  the old `Ready` until a sub-condition is set (see above) and covered by
  tests. A bound claim with no `Ready` and a terminating `IPAddress` does get
  `Ready=Unknown`.
- *A bound claim whose `IPAddress` is stuck terminating is requeued every 5
  seconds.* The `IPAddress` finalizer is only removed when the claim is
  deleted, so this lasts until then, where today such a claim is skipped. It
  happens only if someone deletes the `IPAddress` of a live claim, and it
  costs one `IPAddress` read per pass and no write after the first patch, as
  for a claim with a failed `Ready` today.
- *The backfill changes an allocation.* It cannot: it only picks a claim whose
  allocation and `IPAddress` name already match, and it goes through the
  re-link path. Claims that do not match, such as a deleted `IPAddress` or a
  changed `namePrefix`, are left alone, without an error and without a write.
  Tests cover both.
- *Load after an upgrade.* Each claim bound by an older version costs one
  `IPAddress` read and one status patch, once. The reads come from the cache
  in the controller. All of them are done in one reconcile of the pool.
- *Condition churn.* A claim whose conditions did not change is not patched
  again, and `LastTransitionTime` is kept when a status does not change. Tests
  cover this.
- *Open PRs conflict.*
  [PR #1527](https://github.com/metal3-io/ip-address-manager/pull/1527) and
  [PR #1564](https://github.com/metal3-io/ip-address-manager/pull/1564) write
  `Ready` directly. Whichever merges second moves to sub-conditions (for
  [PR #1564](https://github.com/metal3-io/ip-address-manager/pull/1564) the
  name collision becomes a reason on `IPAddressCreated`).

### Work Items

- Add `ipam/conditions.go` and switch the `Ready` writes in
  `ipam/ippool_manager.go` to sub-conditions
  ([PR #1698](https://github.com/metal3-io/ip-address-manager/pull/1698),
  done).
- Report a requested IP outside every pool with the reason
  `RequestedIPOutOfBounds`, in the same PR.
- Reconcile a bound claim once when it has no `IPAddressAllocated` condition,
  in the same PR.
- Add a section on the conditions, reasons and the `Ready` derivation to
  `docs/api.md` in ip-address-manager, as asked by the maintainers.
- Add the Cluster API `IPAddressClaim` and `IPAddress` CRDs to the `envtest`
  suite, with specs that check that the API server accepts every condition
  that IPAM writes.
- Mention the `Ready` message change and the new reason for a requested IP
  outside every pool in the release notes.

### Dependencies

- Cluster API `api` v1.14 and `util/conditions` (`SetSummaryCondition`,
  `ForConditionTypes`, `IgnoreTypesIfMissing`, `CustomMergeStrategy`), already
  in `go.mod`. No new dependency.
- The Cluster API CRDs for the `envtest` suite come from the
  `sigs.k8s.io/cluster-api` module version pinned in `go.mod`, in
  `core/config/crd/bases`. The module is already in the module cache because
  the tests import it. The suite needs the `go` command when the tests run.
- [PR #1699](https://github.com/metal3-io/ip-address-manager/pull/1699) (claim
  update error handling), merged.
  [PR #1698](https://github.com/metal3-io/ip-address-manager/pull/1698) is
  rebased on it.

### Test Plan

Unit tests in `ipam/conditions_test.go` and `ipam/ippool_manager_test.go`:

- a table test for the summary: both True, pool exhausted, requested IP
  outside every pool, other allocation failure, create failed, create
  pending, nothing reported yet;
- claims written by older versions: `Ready` kept until a sub-condition is
  set, and replaced once sub-conditions exist;
- reconciling claims end to end against the fake client, including the
  re-link path and a transient create error;
- a requested IP: outside one pool, between two pools, outside a pool that is
  full, in a pool but in use, no requested IP and a full pool, and a requested
  IP that equals an out-of-range pre-allocation. Each checks the reason, the
  message, the requeue time and the `Ready` reason. A claim that an older
  version left as `PoolExhausted` for this case moves to the new reason, and a
  claim recovers when the pool is edited to include the IP;
- the backfill: claims with no conditions, with a stale failed `Ready`, or
  with a condition that another controller owns, get both sub-conditions and
  `Ready` with one status patch and no other write, and nothing is written on
  the second pass. A claim whose `IPAddress` is gone and a pool with another
  `namePrefix` are left as they were, and a claim with a terminating
  `IPAddress` is requeued with no sub-condition and `Ready=Unknown`;
- an unchanged claim is not patched again, and `LastTransitionTime` of a
  repeated exhaustion is not touched.

These unit tests use the fake client, which does not validate objects, so
they cannot tell whether the API server accepts what IPAM writes. That is how
the original bug went unnoticed. The `envtest` suite in `ipam/` therefore
also installs the Cluster API `IPAddressClaim` and `IPAddress` CRDs, taken
from the `sigs.k8s.io/cluster-api` version in `go.mod` with `go list -m`, so
it follows version bumps. A table of `envtest` specs writes every condition
and reason IPAM sets through the same patch helper call as
`capiUpdateAddresses`, and one spec runs `capiUpdateAddresses` against the API
server. The v1beta2 CRD requires a non-empty `reason` that matches
`^[A-Za-z]([A-Za-z0-9_,:]*[A-Za-z0-9_])?$`, so a `Ready` condition with an
empty reason, or a reason with a hyphen or a space, now fails the tests. The
cost is about two seconds more for each run of the `ipam` tests, and the need
for the `go` command.

e2e was not run on
[PR #1698](https://github.com/metal3-io/ip-address-manager/pull/1698) and no
new e2e test is planned. CAPM3 only reads `status.addressRef`, so the e2e
result should not depend on the conditions.

### Upgrade / Downgrade Strategy

Nothing to do on upgrade.

- A claim that is retried or re-linked gets sub-conditions and a derived
  `Ready` on its next reconcile.
- A claim that already has `status.addressRef` and no failed `Ready` used to
  be skipped by `capiUpdateAddresses`. It has no `Ready` today, because the
  API server rejected the `Ready=True` patch without a reason (see
  Motivation), so it would never get `Ready` or the sub-conditions. The
  controller reconciles it once more, as described in the backfill above:
  one `IPAddress` read and one status patch for each such claim, once. It
  does not allocate, create or change `status.addressRef`. No flag,
  annotation or migration job is needed.
- A claim that an older version left as `Ready=PoolExhausted` because its
  requested IP is in no pool has no `status.addressRef`, so it is reconciled
  on every pass already. It moves to the new reason without any backfill.
- On downgrade, older versions do not read the sub-conditions. The extra
  conditions are either left alone or replaced when the older version writes
  `Ready`. `conditions.Set` keeps `Ready` first by default, so older code that
  reads `Conditions[0]` still sees it. No cleanup is needed.

### Version Skew Strategy

None. IPAM only talks to the `IPAddressClaim` kind it already uses, in the
Cluster API v1beta2 version it already uses.

## Drawbacks

- The `Ready` message format changes for everyone, including users who never
  needed the new conditions.
- The `Ready` reason of a claim whose requested IP is outside every pool
  changes from `PoolExhausted` to `AllocationFailed`.
- IPAM now puts Metal3 specific condition types on an object that Cluster API
  owns, and we have to keep their reasons stable.
- Two conditions to read instead of one when debugging.
- Every claim that an older version bound gets one status patch after the
  upgrade.

## Alternatives

- **Only fix the bug.** Add a reason to the two `Ready=True` sites
  ([PR #1527](https://github.com/metal3-io/ip-address-manager/pull/1527) now
  adds the reason `Allocated` at both). This is a two-line change with the
  smallest risk. It does not change the nine direct writes, the six failures
  that all look like `AllocationFailed`, or the coupling to retries, so
  [issue #1538](https://github.com/metal3-io/ip-address-manager/issues/1538)
  stays open.
- **Keep `Ready` direct and add more reasons to it.** Reasons on `Ready` other
  than `PoolExhausted` and `AllocationFailed` are not what the Cluster API
  types define, so consumers that match on those reasons could miss
  them. Sub-conditions keep `Ready` on those reasons.
- **Constants in `api/v1alpha1`** instead of `ipam/`. `api/v1alpha1` is a
  separate Go module that CAPM3 imports, so constants there become a public
  API commitment, and they describe a Cluster API object, not an IPAM API
  type. Moving them into the API module later is possible, taking them out is
  a breaking change. The constants stay in `ipam/`. If downstream code needs
  to reference the reasons, we can move them then.
- **Keep the plain `Ready` message** by writing our own merge strategy instead
  of the default summary message. This keeps old matching working but differs
  from the standard Cluster API summary format. We prefer the standard format.
- **Set the sub-conditions on a bound claim only when it is next
  reconciled.** `capiUpdateAddresses` skips a bound claim that has no error,
  so a claim bound by an older version would never get them. The one-time
  backfill replaces this.
- **Keep `PoolExhausted` for a requested IP outside every pool.** This needs
  no change, but the reason then says that the pool is full when it is not,
  against what the Cluster API types define, and `docs/api.md` would need a
  caveat on it.
- **Make `RequestedIPOutOfBounds` a plain error**, as
  `PreAllocationOutOfBounds` is, instead of a transient error with a 15 second
  requeue. A pool or claim edit enqueues the pool anyway, so the requeue is
  not needed to recover, but a plain error adds error-level logs and
  exponential backoff. A transient error keeps today's retry behavior, so the
  change is limited to the reason and the message.

## References

- ip-address-manager
  [issue #1538](https://github.com/metal3-io/ip-address-manager/issues/1538):
  derive the claim Ready condition from sub-conditions
- ip-address-manager
  [PR #1698](https://github.com/metal3-io/ip-address-manager/pull/1698):
  implementation, on hold
- ip-address-manager
  [PR #1699](https://github.com/metal3-io/ip-address-manager/pull/1699):
  claim update error handling, merged
- ip-address-manager
  [PR #1527](https://github.com/metal3-io/ip-address-manager/pull/1527):
  recover claims whose `IPAddress` is deleted
- ip-address-manager
  [PR #1564](https://github.com/metal3-io/ip-address-manager/pull/1564):
  report `IPAddress` name collisions
- Cluster API `IPAddressClaim` v1beta2 types (`ipam/v1beta2`), `Ready`
  reasons `AllocationFailed`, `PoolNotReady`, `PoolExhausted`
- Cluster API IPAM provider contract:
  <https://cluster-api.sigs.k8s.io/developer/providers/contracts/ipam>
- CAPM3 `patchMetal3Machine`, which derives its `Ready` with
  `conditions.SetSummaryCondition`
