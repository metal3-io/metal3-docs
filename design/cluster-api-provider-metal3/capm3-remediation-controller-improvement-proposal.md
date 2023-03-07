<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# capm3-remediation-controller-improvement

## Status

implemented

## Summary

We would like to add Node deletion to the existing remediation strategy.

## Motivation

The original reboot remediation controller proposal \[1\] misses details on how
remediation should actually be done. During implementation there was
some discussion if the Node should be deleted or not \[2\]. The decision was
to keep it simple and skip Node deletion.
Skipping Node deletion has a big drawback though: workloads on unresponsive
Nodes won't be rescheduled quickly, because they are assumed to be still
running. Deleting the the Node signals that the workloads are not running
anymore, which results in quickly rescheduled workloads with less downtime.

### Goals

* Quick rescheduling of workloads on failed Nodes by signaling that they
  are not running anymore by deleting the Node.

### Non-Goals

* Change the remediation API

## Proposal

The remediation controller's reconcile method will be modified to not only
reboot the Machine, but also delete the Node.

### User Stories

#### Story 1

As a user, I expect minimal downtime of my workloads in case of Node issues.

## Design Details

Unfortunately adding Node deletion to the controller's reconcile method is a
bigger change in the implementation than it sounds, because the old
one-step fencing process (trigger reboot by setting the appropriate annotation)
becomes a multiple step process, and after each step we need to wait for
success before executing the next one:

* power Machine off
* backup Node labels and annotations
* delete the Node
* power Machine on
* restore labels and annotations on recreated Node

### Implementation Details/Notes/Constraints

None.

### Risks and Mitigations

None.

### Work Items

None, already implemented.

### Dependencies

Nothing new.

### Test Plan

Unit and e2e tests are already updated.

### Upgrade / Downgrade Strategy

Node deletion might fail on existing target cluster because of missing RBAC
roles for it. In this case Node deletion will be skipped and the Machine
will just be power cycled \[3\].

### Version Skew Strategy

None.

## Drawbacks

None.

## Alternatives

There was a discussion if this should be a new remediation strategy.
Consent in the one was that remediation without Node deletion is incomplete,
and that it should be added to the existing reboot strategy \[4\].

## References

* [1] [Original Proposal](https://github.com/metal3-io/metal3-docs/blob/main/design/cluster-api-provider-metal3/capm3-remediation-controller-proposal.md)
* [2] [Node deletion discussion](https://github.com/metal3-io/metal3-docs/pull/118#issuecomment-655326761)
* [3] [RBAC issue on upgrade](https://github.com/metal3-io/cluster-api-provider-metal3/pull/367#discussion_r852388737)
* [4] [Add to existing strategy discussion](https://github.com/metal3-io/cluster-api-provider-metal3/pull/367#issuecomment-978936471)
* [Issue](https://github.com/metal3-io/cluster-api-provider-metal3/issues/392)
* [Initial PR](https://github.com/metal3-io/cluster-api-provider-metal3/pull/367)
* [New PR because of CI issues](https://github.com/metal3-io/cluster-api-provider-metal3/pull/668)
