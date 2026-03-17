# Proposal: Kubernetes Events during reconciliation

## Summary

Ironic Standalone Operator should emit Kubernetes Events on the `Ironic`
custom resource to make reconciliation progress and failures visible to
cluster users (`kubectl describe ironic ...`), without flooding the cluster
with repetitive messages.

This document proposes a small, stable set of **Event reasons**, their **types**
(Normal/Warning), and the **conditions under which they are recorded**.

## Goals

- Provide actionable feedback during reconcile (start, progress, ready).
- Surface user-actionable failures (e.g. referenced Secret/ConfigMap missing).
- Surface operator/actionable failures (transient reconcile failures).
- Avoid event spam: emit primarily on transitions or user-actionable changes.
- Keep the contract stable so downstream docs/automation can rely on reasons.

## Non-goals

- Emitting events on every child object create/update (too noisy).
- Emitting events for every internal step in `pkg/ironic` (implementation detail).s

## Background

The controller uses a `record.EventRecorder` and already requests RBAC for
`events` (`create`, `patch`). Events should be attached to the `Ironic` CR
because it is the primary user-facing object.

## Proposed event contract

### General rules (anti-spam)

- Emit "start" and "fully reconciled" events at most once per reconcile loop.
- Emit transition events (Ready/NotReady) only when the Ready condition changes.
- Emit "in progress" events only when the status/conditions meaningfully change
  (e.g. `status.String()` changes), and ideally rate-limit per Generation.
- Prefer Warning events only for user-actionable errors or hard failures.
- Use stable `reason` strings; avoid embedding variable data in `reason`.
- Include variable detail in the message (e.g. namespaced name, versions).

### Event reasons

| Reason | Type | When | Message (template) |
|---|---|---|---|
| `Reconciling` | Normal | Beginning of reconciliation for an `Ironic` object | `Starting reconciliation` |
| `ReconcileFailed` | Warning | Reconcile returned error (will be retried) | `Reconciliation failed: <error>` |
| `Reconciled` | Normal | Reconcile completed with no requeue and no error | `Object has been fully reconciled` |
| `VersionError` | Warning | Invalid/unsupported version configuration (user action required) | `Failed to process version: <error>` |
| `DowngradeRejected` | Warning | Downgrade blocked due to external DB constraint | `Downgrade from <installed> to <requested> is not supported with external database` |
| `VersionChange` | Normal | Requested version changed (upgrade requested) | `Version change requested from <installed> to <requested>` |
| `APISecretCreated` | Normal | Operator generated new API credentials Secret | `Created new API credentials secret: <name>` |
| `APISecretError` | Warning | Ensuring API secret failed (transient) | `Failed to ensure API secret: <error>` |
| `SecretNotFound` | Warning | User referenced a Secret that does not exist | `secret <ns>/<name> not found` |
| `ConfigMapNotFound` | Warning | User referenced a ConfigMap that does not exist | `configmap <ns>/<name> not found` |
| `EnsureIronicFailed` | Warning | Creating/updating Ironic child resources failed (transient) | `Failed to ensure Ironic resources: <error>` |
| `IronicReady` | Normal | Ready condition transitions `False → True` | `Ironic deployment is now ready` |
| `IronicNotReady` | Warning | Ready condition transitions `True → False` | `<status>` |
| `IronicError` | Warning | Status indicates error (without necessarily flipping Ready) | `<status>` |
| `IronicInProgress` | Normal | Status indicates progress (not ready, not error) | `<status>` |

Notes:

- `SecretNotFound` and `ConfigMapNotFound` are intended to be user-actionable,
  and should be aligned with setting `IronicReasonFailed` in Conditions.
- The `<status>` messages should match what is surfaced via Conditions (e.g.
  `resource: <status>`), so users see consistent messaging between Events and
  `status.conditions`.

## Proposed follow-ups / gaps

The contract above intentionally stays narrow. After the initial rollout, we
can consider adding **a small number** of additional events if they prove
valuable and non-noisy, for example:

- `FinalizerAdded` / `FinalizerRemoved`: only on transition, to help explain
  deletion behavior.
- `CleanupStarted` / `CleanupFailed`: during finalization and resource teardown.

These should be added only if users commonly debug deletion/cleanup issues and
need explicit breadcrumbs.

## Implementation plan (high level)

- Ensure `IronicReconciler` has an `EventRecorder` and it is initialized in
  `cmd/main.go` (controller-runtime manager recorder).
- Record events using the reasons and conditions above.
- Keep emission in the controller layer; do not sprinkle events throughout
  lower-level helpers unless necessary.
- Add/verify RBAC permissions for `events` are present in generated RBAC.

## Testing plan

- Add unit tests for event emission in the controller using a fake recorder:
   - Ready transition emits `IronicReady` once.
   - Missing Secret/ConfigMap emits `SecretNotFound` / `ConfigMapNotFound`.
   - Transient reconcile errors emit `ReconcileFailed`.
- Validate via e2e/functional tests (optional, if already covering these flows):
   - Deploy an `Ironic` CR and assert at least one `IronicReady` event appears.

## Compatibility and upgrade considerations

- Event reasons form a user-visible contract; changes should be backwards
  compatible when possible.
- If renaming reasons is necessary, keep old reasons for at least one release
  cycle (or document clearly in release notes).
