<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Annotation for Power Cycling and Deleting Failed Nodes

## Status

implemented

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
extra capacity to become permanently utilized. It is therefore usually
important to recover the lost capacity quickly.

For this reason it is desirable to power the machine back on again, in the hope
that the problem was transient and the node can return to a healthy state.
Upon restarting, Kubelet automatically contacts the masters to re-register
itself, allowing it to host workloads.

### Goals

- Enable the safe automated recovery of exclusive workloads
- Provide the possibility of restoring cluster capacity automatically

### Non-Goals

- Creating a public API for rebooting a node
- Identifying when automated recovery should be triggered
- Taking actions other than power cycling to return the node to full health

## Proposal

This proposal calls for a new controller which watches for the presence of a
specific Node annotation.  If present, the controller will locate the Machine
and BareMetalHost host objects via their annotations, and (in serial) use the
BareMetalHost API to power off the machine, delete the Node, and then power the
machine back on again.

In order to track the state of the recovery workflow, a [new
CRD](https://github.com/kubevirt/machine-remediation/blob/master/pkg/apis/machineremediation/v1alpha1/machineremediation_types.go)
is proposed.

### User Stories

#### Story 1

As a HA component of Metal³ that has identified a failed node, I would like a
declarative way to have the Node stopped; deleted; and restarted, so that I can
recover exclusive workloads and restore cluster capacity.

### Implementation Details/Notes/Constraints

The controller includes logic for power cycling a node.

As rebooting (software) and power cycling (hardware) a machine is a long
running multi-step process, there are currently discussions around the creation
of a public mechanism for requesting initiating these processes atomically.

While it is likely that the work proposed here may make use of such
functionality once it exists, it should not be considered a pre-requisite for
the purposes of evaluating this proposal.

### Risks and Mitigations

RBAC rules will be needed to ensure that only specific roles can trigger
machines to reboot. Without this, the system would be exposed to DoS style
attacks.

## Design Details

See [PoC code](https://github.com/kubevirt/machine-remediation/)

- A new [Machine Remediation CRD](https://github.com/kubevirt/machine-remediation/blob/master/pkg/apis/machineremediation/v1alpha1/machineremediation_types.go)
- Two new controllers:
   - [node
    reboot](https://github.com/kubevirt/machine-remediation/tree/master/pkg/controllers/nodereboot)
    which looks for the annotation and creates Machine Remediation CRs
   - [machine
    remediation](https://github.com/kubevirt/machine-remediation/tree/master/pkg/controllers/machineremediation)
    which reboots the machine and deletes the Node object (which also
    erases the signalling annotation)
- A new annotation (namespace and name is open for discussion)

### Work Items

- Make any requested modifications
- Create a PR from [KubeVirt](https://github.com/kubevirt/machine-remediation)
  into [CAPM3](https://github.com/metal3-io/cluster-api-provider-baremetal)

### Dependencies

This design is intended to integrate with OpenShift's [Machine HealthCheck
implementation](https://github.com/openshift/machine-api-operator/blob/master/pkg/controller/machinehealthcheck/machinehealthcheck_controller.go#L407)

### Test Plan

Unit tests are included in the code-base.

In addition we will develop end-to-end test plans that cover both transient and
permanent failures, as well as negative-flow tests where the IPMI in
non-functional or inaccessible.

### Upgrade / Downgrade Strategy

The added functionality is inert without external input.
No changes are required to preserve the existing behavior.

### Version Skew Strategy

By shipping the new controller with the BareMetal Operator that it consumes, we
can prevent any version mismatches.

## Drawbacks

Bare metal is currently the only platform looking to implement this feature, so
any implementation is necessarily non-standard.

If other platforms come to see value in power based recovery, there may need to
design a different or more formal signaling method (than an annotation) as well
as decompose the implementation into discrete units that can live behind a
platform independent interface such as the Machine or Cluster APIs.

## Alternatives

Wait for equivalent functionality to be exposed by the Machine and/or Cluster APIs.

## References

Internal only
