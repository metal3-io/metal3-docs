 <!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Annotation for Power Cycling and Deleting Failed Nodes

## Status

implementable

## Table of Contents

<!--ts-->
   * [Title](#title)
      * [Status](#status)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
         * [Non-Goals](#non-goals)
      * [Proposal](#proposal)
         * [User Stories](#user-stories)
            * [Story 1](#story-1)
         * [Implementation Details/Notes/Constraints [optional]](#implementation-detailsnotesconstraints-optional)
         * [Risks and Mitigations](#risks-and-mitigations)
      * [Design Details](#design-details)
         * [Work Items](#work-items)
         * [Dependencies](#dependencies)
         * [Test Plan](#test-plan)
         * [Upgrade / Downgrade Strategy](#upgrade--downgrade-strategy)
         * [Version Skew Strategy](#version-skew-strategy)
      * [Drawbacks [optional]](#drawbacks-optional)
      * [Alternatives [optional]](#alternatives-optional)
      * [References](#references)

<!-- Added by: stack, at: 2019-02-15T11:41-05:00 -->

<!--te-->

[Tools for generating]: https://github.com/ekalinin/github-markdown-toc

## Summary

It is not always practical to require admin intervention once a node has been
identified as having reached a bad or unknown state.

In order to automate the recovery of exclusive workloads (eg. RWO volumes and
StatefulSets), we need a way to put failed nodes into a safe state, indicate to
the scheduler that affected workloads can be started elsewhere, and then
attempt to recover capacity.

## Motivation

Hardware is imperfect, and software contains bugs. When node level failures
such as kernel hangs or dead NICs occur, the work required from the cluster
does not decrease - workloads from affected nodes need to be restarted
somewhere. 

However some workloads may require at-most-one semantics.  Failures affecting
these kind of workloads risk data loss and/or corruption if "lost" nodes are
assumed to be dead when they are still running.  For this reason it is
important to know that the node has reached a safe state before initiating
recovery of the workload.

Powering off the affected node via IPMI or related technologies achieves this,
but must be paired with deletion of the Node object to signal to the scheduler
that no Pods or PersistentVolumes are present there.

Ideally customers would over-provision the cluster so that a node failure (or
several) does not put additional stress on surviving peers, however budget
constraints mean that this is often not the case, particularly in Edge
deployments which may consist of as few as three nodes of commodity hardware. 
Even when deployments start off over-provisioned, there is a tendency for the
extra capacity to become permanently utilised.  It is therefore usually
important to recover the lost capacity quickly.

For this reason it is desirable to power the machine back on again, in the hope
that the problem was transient and the node can return to a healthy state.
Upon restarting, kubelet automatically contacts the masters to re-register
itself, allowing it to host workloads.

### Goals

- Enable the safe automated recovery of exclusive workloads
- Provide the possibility of restoring cluster capacity automatically

### Non-Goals

- Creating a public API for rebooting a node
- Identifying when automated recovery should be triggered
- Taking actions other than power cycling to return the node to full health

## Proposal

This proposal calls for a new machine remediation controller (MRC) in CAPM3
which watches for the presence of a `host.metal3.io/external-remediation` Machine
annotation. If present, the controller will locate the Machine
and BareMetalHost host objects via their annotations, and will annotate the BareMetalHost
CR with a `reboot.metal3.io/machine-remediation` to power cycle the host by
utilizing the [Baremetal-Operator reboot API](https://github.com/metal3-io/metal3-docs/blob/master/design/reboot-interface.md).
Upon host power off, the controller will delete the node and then remove the annotation,
allowing it to be powered back on.
After restart/crash of the new controller it will check for
`reboot.metal3.io/machine-remediation` annotation on all hosts,
and continue remediation process, to make sure that such host is
not left in powered off state.

## Assumptions

MHC checks that each machine has a node, and if it doesn't after some timeout,
it will mark the machine as unhealthy. There could be situations where this timeout
expires few seconds after MRC powered on the machine, resulting in one or more
redundant reboot(s).
Current MHC implementation checks that `now() - Machine.LastUpdated < timeout`.
MRC deletes the unhealthy node, which updates `Machine.LastUpdated`.
We assume that this implementation won't change.

In addition, MRC has some operations to perform between node deletion (which triggers
update of `Machine.LastUpdated`) to powering on the host, and these operations
are also counted against that timeout. These operations are removing
MAO's annotation and removing the reboot annotation. We assume that this
time is negligible, especially compared to a newly provisioned host, and in case of
temporary failure to remove one of the annotations we will risk in additional reboot.

### User Stories

#### Story 1

As a customer, I would like to have highly available applications so that my
cluster infrastructure will be self healing and the nodes to be remediated automatically,
without risking in any data loss/corruption.

### Implementation Details/Notes/Constraints [optional]

The MRC will be implemented in openshift/CAPBM and will later need to be ported
back to metal3/CAPM3.

Previous design relied on the existence of a new CRD to store state.
This design is CRD-free and only uses annotations.

### Risks and Mitigations

RBAC rules will be needed to ensure that only specific roles can trigger
machines to reboot. Without this, the system would be exposed to DoS style
attacks.

## Design Details

MRC will:
1. Power off hosts referenced by unhealthy Machine (by adding
`reboot.metal3.io/machine-remediation` annotation)
2. Delete nodes referenced by unhealthy Machines (when referenced host is powered off)
3. Remove `host.metal3.io/external-remediation` annotation from powered off
hosts referenced by node-less machines
5. Power on hosts referenced by machines without
`host.metal3.io/external-remediation` annotation (by removing
`reboot.metal3.io/machine-remediation` annotation from host)

See truth table below:

|Node Ref exists?|Needs remediation annotation|Powered on?|Reboot annotation|MRC action|
|:-:|:-:|:-:|:-:|---|
|0|1|1|0|Add reboot annotation|
|1|1|1|0|Add reboot annotation|
|1|1|0|1|Delete node|
|0|0|1|0|nothing|
|0|0|1|1|nothing|
|0|1|0|0|nothing|
|0|1|1|1|nothing|
|1|0|0|0|nothing|
|1|0|1|0|nothing|
|1|0|1|1|nothing|
|1|1|0|0|nothing|
|1|1|1|1|nothing|
|0|1|0|1|Remove needs-remediation annoation|
|0|0|0|1|Remove reboot annotation|
|1|0|0|1|Remove reboot annotation|

### Work Items

- Create a new machine remediation controller in openshift/CAPBM repo
- Backport to upstream

### Dependencies

This design is intended to integrate with OpenShift’s [Machine Healthcheck
implementation](https://github.com/openshift/machine-api-operator/blob/master/pkg/controller/machinehealthcheck/machinehealthcheck_controller.go#L407)
 and [Baremetal Operator Reboot API](https://github.com/metal3-io/baremetal-operator/pull/424)

### Test Plan

Unit tests will be added for the new controller.

In addition we will develop end-to-end test plans that cover both transient and
permanent failures, as well as negative-flow tests where the IPMI in
non-functional or inaccessible.

### Upgrade / Downgrade Strategy

The added functionality is inert without external input.
No changes are required to preserve the existing behaviour.

### Version Skew Strategy

If CAPM3 and the BMO are in different pods, an upgrade or downgrade could lead to
version skew (one pod supports machine remediation and the other doesn't)
An upgrade or downgrade affecting one component will
eventually be applied to the other and any version skew is temporary.
During the transient case that CAPM3 does not include the MRC, Host can be left in powered
off state, since MRC could add reboot annotation, and then it get downgraded, and there will
be no controller to remove the reboot annotation.
During the transient case that BMO does not support the reboot API, MRC could request for a reboot,
which won't commence until BMO upgrades to a version which supports reboot annotation.
In both cases, the impact is just delayed remediation and will be resolved once there's
no version skew.

## Drawbacks [optional]

Baremetal is currently the only platform looking to implement this feature, so
any implementation is necessarily non-standard.

If other platforms come to see value in power based recovery, there may need to
design a different or more formal signaling method (than an annotation) as well
as decompose the implementation into discrete units that can live behind a
platform independent interface such as the Machine or Cluster APIs.

## Alternatives [optional]

1. Wait for equivalent functionality to be exposed by the Machine and/or Cluster APIs.
2. Use a CRD to track the remediation progress instead of inferring it based on the existence or
otherwise of Node objects, Machine and Host annotations. This was tried in the past but was mainly
rejected since there was no operator to install that CRD.

## References

Internal only
