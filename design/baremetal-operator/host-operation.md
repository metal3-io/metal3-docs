<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# New API for imperative operations

## Status

provisional

## Summary

This proposal introduces a new `HostOperation` custom resource that
encapsulates imperative actions on provisioned hosts: rebooting,
rebuilding, and servicing. It replaces the existing annotation-driven
reboot/servicing flow with a proper Kubernetes object that can be
watched, has conditions, and supports cancellation. The resource
provides a uniform interface for triggering stateful operations, gives
users clear feedback on progress and failures, and lays the groundwork
for future imperative actions without adding more annotations.

## Motivation

The current mechanism for triggering actions on provisioned hosts
relies on the `reboot.metal3.io` annotation and on field mutations in
BareMetalHost. This has several shortcomings:

- Rebuilding an instance with new user/network/meta data requires
  removing the `image` field, waiting for deprovisioning to start, and
  re-adding it — an error-prone sequence.
- There is no way to rebuild without going through cleaning.
- Servicing (firmware updates, BIOS changes) is coupled to the reboot
  annotation, forcing a reboot even when one is unnecessary (e.g. BMC
  firmware updates).
- A HostUpdatePolicy that disallows servicing provides no feedback to
  the user — changes are silently deferred.
- Cancelling servicing requires modifying HFS/HFC in non-obvious ways.
- The annotation does not integrate well with the planned HostClaims
  feature, which deletes annotations once passed to BareMetalHost.
- Further imperative operations (credential rotation, secure boot
  configuration) would require even more annotations.

### Goals

- Provide a single CRD for all imperative actions on provisioned
  hosts (reboot, rebuild, service).
- Surface progress and errors through standard Kubernetes conditions.
- Support cancellation of running operations where possible.
- Deprecate the plain `reboot.metal3.io` annotation.
- Enable servicing without requiring a host reboot when the hardware
  does not need one.

### Non-Goals

- Replacing the coordinated (suffixed) `reboot.metal3.io/<key>`
  annotation. It requires external synchronization that is outside
  the scope of this proposal.
- Changing the `detached` annotation (it represents state, not an
  action).
- Controlling the `online` field (it is declarative, not imperative).
- Adding a HostClaimOperation equivalent (may be added later).
- Adding operation timeouts (may be added later).
- Triggering re-inspection through HostOperation (inspection applies
  to `available` hosts, not `provisioned`).
- Extracting the servicing or rebooting logic into a separate controller.
- Rename the `onReboot` value of HostUpdatePolicy to something more suitable.

## Proposal

A new CRD `HostOperation` allows users to request an imperative action
on a provisioned BareMetalHost. Each resource represents exactly one
action. The spec is immutable after creation (enforced by a webhook),
the only mutable field is `cancelled`. Status conditions report
progress, success, or failure.

### User Stories

#### Story 1

As a cluster operator, I want to update BMC firmware on a provisioned
host without rebooting the host, so that I can reduce the maintenance
window.

I create a `HostOperation` with `operation.service` and leave
`mustReboot` as false. The operation succeeds without a host reboot if
the firmware component supports it.

#### Story 2

As a cluster operator, I want to rebuild a provisioned host with new
user data without going through full deprovisioning and cleaning, so
that the process is faster and preserves data on non-root disks.

I update the `userData` secret referenced by my BareMetalHost and
create a `HostOperation` with `operation.rebuild` and `cleaning: false`.

#### Story 3

As a cluster operator, I want to cancel a servicing operation that is
taking too long, so that my host returns to service.

I set `cancelled: true` on the `HostOperation` resource. The
controller aborts the Ironic servicing process and boots the host
back. The operation transitions to failed with reason `Cancelled`.

## Design Details

### Custom Resource Definition

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostOperation
metadata:
  name: ostest-worker-0-abcdef
  namespace: openshift-machine-api
spec:
  host: ostest-worker-0 # required - host to operate on
  operation: {}         # required - operation details, see below
  # optional fields with their defaults:
  blocking: false
  cancelled: false
  ttlSecondsAfterFinished: # unset
status:
  conditions:
  - type: Succeeded
    status: "False"
    reason: InProgress
  - type: Progressing
    status: "True"
    reason: WaitPowerOff
  startedAt: "..."
  finishedAt: "..."
```

Key rules:

- The `host` and `operation` fields are immutable after creation.
- Exactly one operation must be specified; the webhook rejects zero
  or multiple.
- Each operation has optional parameters that are specific to operation itself,
  not to the host it's running on and not to the applicable HostUpdatePolicy.
- If a `blocking` operation fails, no other operations run for the host until
  it's deleted or `blocking` is set to `false`.
- The `cancelled` field can only transition from false to true, never
  back.
- `ttlSecondsAfterFinished` controls automatic garbage collection
  after the operation completes: positive values set a delay, zero
  means immediate cleanup, missing or negative values disable cleanup entirely.
- Resources should be created with `generateName` to avoid naming
  conflicts.

### Conditions

**Succeeded** — terminal state of the operation:

| Reason | Meaning |
|--------|---------|
| `InProgress` | Not yet finished (status: False) |
| `Succeeded` | Completed successfully (status: True) |
| `NoChanges` | Service found nothing to do (status: True) |
| `Forbidden` | HostUpdatePolicy disallows the change |
| `Cancelled` | Cancelled by the user |
| `RebootFailed` | Reboot could not complete |
| `ServicingFailed` | Ironic servicing failed |
| `RebuildFailed` | Rebuild/provisioning failed |

**Progressing** — current phase of the operation:

| Reason | Meaning |
|--------|---------|
| `WaitForHostState` | Host is not yet in `provisioned` state |
| `WaitPowerOff` | Waiting for the host to power off |
| `WaitPowerOn` | Waiting for the host to power on |
| `Servicing` | Ironic servicing is running |
| `Rebuilding` | Re-provisioning is running |
| `Cancelling` | Cancellation is in progress |

**NOTE:** the list of reasons may be expanded further.

### New BareMetalHostStatus field

A new `currentHostOperation` field in `BareMetalHostStatus` will hold the
name of the HostOperation currently being executed. The BMH controller
is responsible for setting this field by selecting the oldest pending
operation (by creation timestamp).

### Reboot operation

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostOperation
metadata:
  name: ostest-worker-0-abcdef
  namespace: openshift-machine-api
spec:
  host: ostest-worker-0
  operation:
    reboot:
      # ACPI-based OS reboot (the default) or a hard reboot via the BMC
      mode: soft|hard
      # Forced reboot interrupts the currently running action and forcibly
      # reboots the host, picking up the new ramdisk image (if any).
      force: false
```

Provides the same functionality as the plain `reboot.metal3.io`
annotation with the same `mode` (soft/hard) and `force` flags.
Progress is tracked through `WaitPowerOff` and `WaitPowerOn` reasons
on the `Progressing` condition.

Unlike the current reboot annotation, a reboot operation does not
trigger servicing. Users who want to apply pending firmware or BIOS
changes during a reboot should use the service operation.

The plain `reboot.metal3.io` annotation will be deprecated. While it remains
supported, adding it when no operation is running will cause the BMH controller
to create a HostOperation of type `service` with `mustReboot: true`
automatically. If any operation is already running, the annotation is dropped
silently.

### Halt operation

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostOperation
metadata:
  name: ostest-worker-0-abcdef
  namespace: openshift-machine-api
spec:
  host: ostest-worker-0
  operation:
    halt:
      # ACPI-based OS power off (the default) or a hard power off via the BMC
      mode: soft|hard
```

Provides three types of functionality:

1. An ability to halt the machine immediately (hard power off).

1. Replacement for the coordinated (suffixed) form `reboot.metal3.io/<key>`,
   allowing us to deprecate the entire reboot annotation.

A halt operation forces the host to stay powered off regardless of its `online`
field. It may fail if powering off fails, but it *never succeeds*, requiring a
user to remove or cancel it. The host's `online` field takes effect again once
all halt operations are cancelled or deleted.

Halt operations will **not** be automatically created when a user uses the
legacy coordinated reboot API.

### Rebuild operation

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostOperation
metadata:
  name: ostest-worker-0-abcdef
  namespace: openshift-machine-api
spec:
  host: ostest-worker-0
  operation:
    rebuild:
      # Rebuild with cleaning is implemented via deprovisioning.
      # Rebuild without cleaning (the default) is implemented via Ironic
      # rebuild API.
      cleaning: false
```

Re-deploys the instance using current BareMetalHost parameters
(image, user data, network data, custom deploy). Two modes:

- `cleaning: true` — triggers deprovisioning followed by automatic
  re-provisioning. The host transitions through `deprovisioning` and
  `provisioning` states. All disks are wiped.
- `cleaning: false` — uses the Ironic `rebuild` verb, which
  re-deploys the image without running cleaning. The root device is
  cleared, but other block devices are preserved. The host transitions
  directly from `provisioned` to `provisioning` without going through
  `deprovisioning`. The Ironic rebuild API accepts new configdrive
  content and custom deploy steps, so updated user data and custom
  deploy methods are applied.

The operation finishes when the host reaches the `provisioned` state.

### Service operation

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostOperation
metadata:
  name: ostest-worker-0-abcdef
  namespace: openshift-machine-api
spec:
  host: ostest-worker-0
  operation:
    service:
      # When mustReboot is true, at least one reboot is always executed during
      # servicing, even when updating components like BMC.
      mustReboot: false
```

Triggers Ironic servicing for firmware updates and BIOS settings
changes. Differences from the current annotation-driven flow:

- **Reboot control**: unless `mustReboot` is true, the decision to
  reboot is left to Ironic. Some components (e.g. BMC firmware) can
  be updated without rebooting the host. When `mustReboot` is true,
  servicing starts with a power-off, matching the current behavior.
  Note that it will cause a reboot even if no changes are pending.
- **Policy enforcement with feedback**: if HostUpdatePolicy does not
  allow the requested changes (the `onReboot` policy is required even
  if the actual servicing may not involve a reboot), the operation
  fails immediately with reason `Forbidden` instead of being silently
  deferred.
- **No-op detection**: if HFS/HFC have no pending changes, the
  operation succeeds with reason `NoChanges`.

### Conflict Resolution and Clean-up

Multiple HostOperations may exist for the same host simultaneously.
The BareMetalHost controller resolves conflicts by sorting pending
operations by creation timestamp and recording the oldest one in
`currentHostOperation`. The operation controller does not proceed (and
does not update `startedAt`) until the operation's name appears in
the corresponding host's `currentHostOperation`.

Failed operations are considered finished unless `blocking` is set to `true` on
them: the BMH controller clears them from `currentHostOperation` and may start
the next pending operation.  This enables retry-by-recreation but requires care
when scheduling multiple operations — a follow-up operation may start even if
the preceding one failed.

Finished operations are subject to clean-up if `ttlSecondsAfterFinished` is set
to a non-negative value.

### Cancellation

An operation can be cancelled by setting `cancelled: true` or by
deleting the HostOperation resource. Using the field preserves the
resource for status tracking.

Cancellation behavior depends on the operation type:

- **Reboot**: abandoned at whatever the current power state is. The
  controller enforces the value of the `online` field afterward.
- **Rebuild**: cannot be cancelled. The webhook rejects setting
  `cancelled: true`, and deletion blocks on a finalizer until
  rebuilding completes. This mirrors a current BMO limitation where
  the only way to abort a failing deployment is to clear the
  `image`/`customDeploy` fields.
- **Service**: follows the existing servicing abort flow — Ironic
  aborts at the next safe step, then the host is booted back. The
  `Progressing` condition shows reason `Cancelling` during this
  period. Cancelling a service operation does not revert the
  underlying HFS/HFC changes — they remain pending and may be
  applied by a future service operation.

Deleting or cancelling an operation that is not currently
`Progressing` has no effect on the host.

### Implementation Details/Notes/Constraints

- A new controller will be added for the HostOperation CRD. It will
  manage the lifecycle of HostOperation resources (conditions, TTL
  cleanup, cancellation) but will not directly orchestrate power
  management or servicing. The actual operations remain in the BMH
  controller, which already owns the provisioner interaction, power
  state sequencing, and BMH status updates.

- The BMH controller's steady-state handler will be modified to check
  for pending HostOperations (via a label selector or list filtered
  by the `host` field) and populate `currentHostOperation`. When a
  current operation is set, the BMH controller carries out the
  requested action (reboot, service, rebuild) using its existing
  provisioner calls and updates the HostOperation's conditions to
  reflect progress. This replaces the current logic that checks for
  the reboot annotation and calls servicing inline.

- For the rebuild operation with `cleaning: false`, the Ironic
  provisioner will use the `rebuild` provision target (similar to
  `nodes.TargetRebuild`). This endpoint is already available in Ironic
  but not currently used by BMO.

- The `ttlSecondsAfterFinished` field will be handled by the HostOperation
  controller, which will delete the resource after the specified duration
  following `finishedAt`. It can be done efficiently by requeuing the next
  reconciliation in `FinishedAt + TTLSecondsAfterFinished - Now` seconds.

- The HostOperation resource will use a finalizer to prevent deletion
  of in-progress operations that cannot be safely interrupted
  (rebuild). The finalizer will be removed once the operation is finished.

### Potential Future Extensions

This is a list of potential enhancements we **may** decide to implement once
this design is implemented with no commitment:

- Operations for HostClaims.

- Grouping operations in some sort of a *plan* object that defines their
  order.

- Running fast inspection as an operation to update HardwareData for a
  provisioned instance.

### Risks and Mitigations

- **Orphaned operations**: if a BareMetalHost is deleted while
  operations are pending, they become orphaned. Mitigation: the BMH
  controller should set owner references on HostOperation resources
  so that they are garbage-collected when the host is deleted.

- **Backward compatibility**: consumers that rely on the reboot
  annotation need a migration path. Mitigation: the plain annotation
  continues to work (auto-creating a HostOperation) during a
  deprecation period.

- **Rebuild cancellation**: the inability to cancel rebuilds may
  frustrate users. Mitigation: document the limitation clearly and
  track it as future work on the BMH level.

### Work Items

- Define the HostOperation CRD in the BMO API.
- Implement the admission webhook (immutability of `host`/`operation`,
  single-operation validation, `cancelled` transitions, rebuild
  cancellation rejection).
- Implement the HostOperation controller with support for reboot,
  rebuild, and service operations.
- Modify the BMH controller to populate `currentHostOperation` and remove
  inline servicing/reboot logic.
- Add the Ironic rebuild provisioner call.
- Implement TTL-based cleanup.
- Deprecate the plain `reboot.metal3.io` annotation and add
  auto-creation of HostOperation.
- Update user-facing documentation.

### Dependencies

- The Ironic `rebuild` feature is required for `cleaning: false`
  rebuilds. This has been available in Ironic for a long time but
  has not been exercised by BMO before.

- The Ironic servicing API (version 1.87+) is required for the
  service operation, as it already is for the current live updates
  feature.

- No new library dependencies are anticipated. The existing
  gophercloud client should already support the necessary Ironic APIs.

### Test Plan

- **Unit tests**: controller logic for each operation type, conflict
  resolution, cancellation, TTL cleanup.
- **Integration tests**: HostOperation lifecycle with a mocked
  provisioner — creation, progress through conditions, completion,
  cancellation.
- **End-to-end tests**: reboot and service operations using the
  Redfish emulator (similar to existing servicing e2e tests). Rebuild
  with `cleaning: true` can be tested end-to-end; rebuild with
  `cleaning: false` may require using a second disk to verify that the data
  is not removed.

### Upgrade / Downgrade Strategy

The feature is additive. Existing clusters continue to work without
HostOperation resources. The plain reboot annotation is deprecated
but remains functional.

On downgrade, any existing HostOperation resources would become
orphaned CRs with no controller. The BMH controller would revert to
annotation-driven behavior. Users should delete pending
HostOperations before downgrading.

### Version Skew Strategy

The HostOperation controller and BMH controller must be from the same
BMO release. There is no cross-component version skew concern beyond
the existing Ironic API version requirements (1.87+ for servicing).

## Drawbacks

- Adds a new CRD and controller, increasing the API surface and
  operational complexity of BMO.
- The conflict resolution logic in the BMH controller adds coupling
  between the two controllers.
- Users familiar with the annotation-based workflow need to learn the
  new approach.

## Alternatives

- **Extend the annotation approach**: add more annotations for
  rebuild and service. This does not solve the fundamental problems
  with annotations (no status, no conditions, poor discoverability).

- **Use BMH spec fields for operations**: add fields like
  `requestedOperation` to BareMetalHostSpec. This conflates
  declarative configuration with imperative actions and complicates
  the reconciliation loop.

- **Tekton/Job-based approach**: model operations as Kubernetes Jobs
  or Tekton TaskRuns that call Ironic APIs. This adds external
  dependencies and does not integrate well with the BMH state machine.

## References

- [Live updates of hosts design](host-live-updates.md) — the existing
  servicing design that this proposal extends.
- [Reboot interface design](reboot-interface.md) — the current reboot
  annotation design.
- [Ironic servicing documentation](https://docs.openstack.org/ironic/latest/admin/servicing)
- [Ironic rebuild API](https://docs.openstack.org/api-ref/baremetal/?expanded=set-provision-state-detail#rebuild)
