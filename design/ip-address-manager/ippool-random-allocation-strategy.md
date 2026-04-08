<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# IPPool Random Allocation Strategy

## Status

implementable

## Summary

Introduce a configurable `AllocationStrategy` field on `IPPoolSpec` so that
operators can choose between `sequential` (the existing behavior, default)
and `random` allocation when issuing IP addresses from an `IPPool`.

## Motivation

Today the Metal3 IPAM controller always allocates the first available
address in a pool. While simple and deterministic, this has the following
drawbacks:

- Whenever workloads are recreated, the same low-numbered IPs are
  repeatedly reused, which can collide with systems that key on a specific
  IP — ARP/neighbor caches, monitoring history, external allow-lists, and
  so on.
- Because numbers are consumed sequentially from the front of the range,
  it is trivially predictable which IP a claim will receive.
- Some users want behavior closer to Neutron and other cloud IPAM systems,
  which randomize allocations to reduce reuse collisions.

A pluggable strategy lets operators opt into randomized allocation without
changing the default behavior of existing pools.

### Goals

- Add an `AllocationStrategy` enum field to `IPPoolSpec` supporting
  `sequential` (default) and `random`.
- Preserve full backward compatibility: pools with no value, or with
  `sequential`, behave exactly as today.
- Guarantee that `spec.preAllocations` and per-claim explicit requests
  (`requestedIP` annotation) remain deterministic regardless of strategy.
- Bound memory usage when randomly allocating from very large subnets.
- Forbid changing the strategy after pool creation, to avoid unexpected
  shifts in in-flight allocations.

## Proposal

Make the allocation strategy a first-class property of `IPPool` so that
each pool declares for itself how it hands out IPs. The existing sequential
behavior remains the default; users opt into random allocation only when
they need it. The core idea of this proposal is to let pools that want
determinism and pools that want dispersion coexist on a per-pool basis
inside the same cluster.

The detailed direction is:

- **Declared per pool.** Strategy is expressed as a single field on the
  `IPPool` manifest rather than as a controller-wide flag, so the manifest
  alone tells you how that pool will allocate.
- **Existing behavior is the default.** Pools that do not set the field
  continue to allocate sequentially from the front. No existing manifest
  needs to change.
- **Random is opt-in.** Random allocation is offered as a choice for
  reducing repeated reuse of the same IP and lowering the chance of
  conflicts with residual state in external systems (ARP caches, firewall
  state tables, monitoring history, etc.).
- **Deterministic paths are always preserved.** Addresses bound by
  `spec.preAllocations`, and claims that specify a `requestedIP`
  annotation, are honored exactly regardless of the strategy. Random
  applies only to allocations that have actual freedom of choice.
- **Strategy is fixed for the pool's lifetime.** Changing the behavior of
  a pool that already has live allocations would create unpredictable risk
  for operators, so switching strategies should be done by creating a new
  pool.
- **Allocation cost stays bounded regardless of pool size.** Even on very
  large subnets, a single allocation must complete within bounded
  memory/CPU. To achieve this we cap the random candidate set, following
  the same line of thinking used by precedents such as Neutron.
- **Cryptographic security is a non-goal.** IP selection is not a security
  boundary, so a regular pseudo-random source is sufficient.

### Example

A pool that opts into random allocation:

```yaml
apiVersion: ipam.metal3.io/v1alpha1
kind: IPPool
metadata:
  name: provisioning-pool
spec:
  allocationStrategy: random
  pools:
  - start: 192.168.0.10
    end: 192.168.0.250
  prefix: 24
  gateway: 192.168.0.1
```

Omitting `allocationStrategy` (or setting it to `sequential`) preserves
the existing behavior, so no existing manifest needs to change.

### User Stories

#### Story 1

In an environment that recreates workloads frequently, I want to reduce
cases where the same low-numbered IPs are reused over and over and collide
with residual state in external systems such as ARP caches, firewall
state, and monitoring history. Random allocation should therefore be
selectable on a per-`IPPool` basis.

#### Story 2

I expect existing `IPPool` manifests and the tests/automation built on top
of them to keep working unchanged on a newer IPAM version. The new field
must therefore default to the existing sequential behavior.

#### Story 3

Within the same cluster I want to operate both pools that need
deterministic IP issuance (e.g. fixed infrastructure) and pools that need
dispersion (e.g. short-lived workloads). The allocation strategy must
therefore be declared per pool, not per controller.

#### Story 4

I want to avoid the situation where the strategy of a pool that already
has live allocations is changed mid-flight, causing unpredictable
reallocations. The strategy must therefore be immutable after pool
creation.
