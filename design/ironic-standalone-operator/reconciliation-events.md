# Proposal: Kubernetes Events during reconciliation

## Summary

Ironic Standalone Operator should emit Kubernetes Events on the `Ironic`
custom resource to make meaningful state transitions and actionable
failures visible to cluster users (`kubectl describe ironic ...`), without
flooding the cluster with repetitive messages.

This document proposes a small, stable set of **Event reasons**, their **types**
(Normal/Warning), and the **conditions under which they are recorded**.

## Goals

- Surface **actionable** failures (e.g. invalid version, missing
  referenced Secret/ConfigMap).
- Surface **meaningful state transitions** (e.g. ready, version change,
  operator-created credentials).
- Avoid event spam: **no** per-reconcile "started/finished" events and **no**
  transient operational errors (those belong in logs and
  `status.conditions`).
- Keep the contract stable so downstream docs/automation can rely on reasons.

## Non-goals

- Emitting events on every child object create/update (too noisy).
- Emitting events for every internal step in `pkg/ironic` (implementation
  detail).

## Background

The controller uses a `record.EventRecorder` and already requests RBAC for
`events` (`create`, `patch`). Events should be attached to the `Ironic` CR
because it is the primary user-facing object.

## Proposed event contract

### General rules (anti-spam)

- Do **not** emit an event at the start or successful end of each reconcile
  loop (`Reconciling` / `Reconciled` are intentionally omitted).
- Do **not** emit Warning events for **transient** errors (e.g. API conflicts,
  temporary network issues, ensure failures that will be retried); use logs
  and conditions instead.
- Emit Normal events for **durable, user-visible changes** (e.g. version
  change request, new API credentials Secret created).
- Emit events on **Ready condition transitions** (`False → True` / `True →
  False`) with messages aligned to `status.conditions`, not on every
  intermediate "in progress" status string.
- Do **not** emit separate "in progress" or “error without Ready flip” events;
  represent not-ready and error states through **one** path: the Ready
  condition and its message (see `IronicReady` / `IronicNotReady` below).
- Prefer Warning events only for **actionable** or **configuration**
  problems.
- Use stable `reason` strings; avoid embedding variable data in `reason`.
- Include variable detail in the message (e.g. namespaced name, versions).

### Event reasons

| Reason | Type | When | Message (template) |
|---|---|---|---|
| `VersionError` | Warning | Invalid/unsupported version configuration (user action required) | `Failed to process version: <error>` |
| `DowngradeRejected` | Warning | Downgrade blocked due to external DB constraint | `Downgrade from <installed> to <requested> is not supported with external database` |
| `VersionChange` | Normal | Requested version changed (upgrade/downgrade requested) | `Version change requested from <installed> to <requested>` |
| `APISecretCreated` | Normal | Operator generated new API credentials Secret | `Created new API credentials secret: <name>` |
| `SecretNotFound` | Warning | User referenced a Secret that does not exist | `secret <ns>/<name> not found` |
| `ConfigMapNotFound` | Warning | User referenced a ConfigMap that does not exist | `configmap <ns>/<name> not found` |
| `IronicReady` | Normal | Ready condition transitions to `True` | `Ironic deployment is now ready` |
| `IronicNotReady` | Warning | Ready condition transitions to `False` (includes configuration errors and dependency failures surfaced there) | `<message from Ready condition>` |

Notes:

- `SecretNotFound` and `ConfigMapNotFound` are user-actionable and should stay
  aligned with setting failure reasons in Conditions.
- Any “error” or “not ready” situation that does not flip Ready in the same
  reconcile should still be reflected in Conditions first; when Ready becomes
  `False`, use **`IronicNotReady`** with the same message users see in
  `status.conditions` (no separate `IronicError` reason).

## Deletion, finalizers, and cleanup

Debugging deletion, finalizers, and teardown is an **operator** concern.
Visibility for that belongs in **controller logs**, not in user-facing Events
on the `Ironic` CR. No additional Event reasons are proposed for cleanup
flows.

## Implementation plan (high level)

- Ensure `IronicReconciler` has an `EventRecorder` and it is initialized in
  `cmd/main.go` (controller-runtime manager recorder).
- Record events only for the reasons in the table above, following the general
  rules.
- Keep emission in the controller layer; do not sprinkle events throughout
  lower-level helpers unless necessary.
- Add/verify RBAC permissions for `events` are present in generated RBAC.

## Testing plan

- Add unit tests for event emission in the controller using a fake recorder:
   - Ready transition emits `IronicReady` once.
   - Missing Secret/ConfigMap emits `SecretNotFound` / `ConfigMapNotFound`.
   - Invalid version emits `VersionError` (or equivalent user-error path).
- Assert that **transient** reconcile errors do **not** emit Warning Events
  (only logs/conditions).
- Validate via e2e/functional tests (optional, if already covering these
  flows):
   - Deploy an `Ironic` CR and assert a `IronicReady` event appears when Ready
     becomes `True`.

## Compatibility and upgrade considerations

- Event reasons form a user-visible contract; changes should be backwards
  compatible when possible.
- If renaming reasons is necessary, keep old reasons for at least one release
  cycle (or document clearly in release notes).
