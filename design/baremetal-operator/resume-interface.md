<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Title

Resume from error state

## Status

provisional

## Summary

This proposal aims to introduce a new declarative API
to forcibly resume a waiting BareMetalHost resource from an error state
when a fix is immediately available, so that it could be possible
to reduce the waiting time required

## Motivation

The current BMO error retry mechanism implements an
exponential backoff with jittering: this means that when a BMH
goes into an error state its reconciliation loop gap increases
as long as the error conditions persists (based on BMH `Status.ErrorCount`).

In some cases it's necessary a human (or more generally an external)
intervention to fix the issue. If the fix involves amending the
BMH resource then an immediate reconciliation is triggered and the
new state is evaluated again.
Instead, if the fix does not generate a relevant event (for example,
a firmware update on the host) captured by BMO, then it's necessary
to wait for the next scheduled reconciliation loop for a new
state evaluation, and the waiting time could be longer for higher
values of `Status.ErrorCount`.

### Goals

* A declarative API to force resuming a BMH currently waiting in error state

### Non-Goals

* Clear or remove the current BMH error state

## Proposal

## Design Details

A new annotation `resume.metal3.io` will be used to trigger a new
reconciliation loop, and to reset the `Status.ErrorCount` field to 1. In this
way, the BMH resource will restart reconciliation with a narrowed loops

### Implementation Details/Notes/Constraints

The annotation must be consumed as soon as possible within the BMO reconcile
loop, and it should be removed as soon as the `Status.ErrorCount` is set to 1.
If the BMH resource is not in an error state (`Status.ErrorCount` already
set to zero) then the annotation must be removed and the event properly logged.

### Risks and Mitigations

None

### Work Items

* Modify the BMO reconcile loop to handle the new annotation
* Unit tests for the above points

### Test Plan

Verify through unit tests that a reconcile loop remove the
`resume.metal3.io` annotation and sets the ErrorCount field to 1 (if the BMH
was in error)

### Upgrade / Downgrade Strategy

None

## Drawbacks

None

## Alternatives

Reducing the backoff gaps (or upper limit) could mitigate somehow as the
waiting time will be reduced

