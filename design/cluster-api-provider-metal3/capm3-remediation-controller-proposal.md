<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# capm3-remediation-controller

<!-- cSpell:ignore beekhof,maelk,fmuyassarov -->

Co-authored-by: @jan-est, @beekhof, @n1r1, @maelk, @fmuyassarov.

## Status

implemented

## Summary

Automated mechanism for remediating unhealthy nodes.

## Motivation

It is not always practical to require admin intervention once a node has been
identified as having reached a bad or unknown state. In order to automate the
recovery of unhealthy nodes we need a programmatic way to put them back into a
safe and healthy state.

The Cluster API includes an optional
[MachineHealthcheck](https://cluster-api.sigs.k8s.io/tasks/automated-machine-management/healthchecking)
(MHC)
component that implements automated health checking capability, and with
the [External Remediation proposal](https://github.com/kubernetes-sigs/cluster-api/pull/3190)
it will be possible to plug in Metal3 specific remediation strategies to
remediate unhealthy nodes while relying on Cluster
API MHC to determine those nodes as unhealthy.

We would like to enable an automated mechanism in Metal3 that supports a
recovery flow tailored for bare metal environments whenever Machine(s)
meet unhealthiness criteria set by Cluster API MHC.

### Goals

* Enable automated remediation that doesn't always reprovision the node.
* Integrate with Cluster API MHC.
* Support remediation based on power cycling the underlying hardware.
* Support use of BMO reboot API and Cluster-API-Provider-Metal3 (CAPM3)
  unhealthy annotation as part of automated remediation cycles.

### Non-Goals

* Create a CAPM3 specific MachineHealthCheck.
* Add new remediation or power cycle APIs into BMO.

## Proposal

This proposal calls for a new Metal3Remediation object and a new controller in
CAPM3 that uses BMO APIs to perform automated remediation of unhealthy
nodes in Metal3 project.

The new controller will locate a Machine with the same name as the
Metal3Remediation CR and uses existing BMO and CAPM3 APIs to remediate
associated unhealthy baremetal nodes.

New remediation controller supports reboot strategy specified in
Metal3Remediation CRD and uses the same object to store
state of the current remediation cycle.

This proposal also introduces Metal3RemediationTemplate CRD. The
Metal3RemediationTemplate is used by CAPI MachineHealthCheck to create
Metal3Remediation objects when it detects unhealthy Machines in the cluster.

### User Stories

#### Story 1

As an administrator, I would like my cluster to be highly available and nodes
be self healing in case they fail to operate.

#### Story 2

As an administrator, I would like to have a simple way of requesting recovery
for my node when I find it to be unhealthy.

#### Story 3

As an administrator, I would like to see historical data about the health of my
cluster nodes for debugging purposes.

#### Story 4

As an administrator, I should be able to mark ready nodes to be unusable.

### Design Details

CAPI MachineHealthCheck will allow infrastructure providers to implement its
own remediation controller to reconcile External Machine Remediation (EMR) CRs.
EMRs are generated using infrastructure provider defined External Remediation
Template.

CAPM3 needs a new controller, remediation controller to watch and reconcile
Metal3Remediation objects. New controller does not have effect on existing APIs
and adding new remediation features does not include changes in other CAPM3
controllers. This design adds two new CRDs, namely Metal3Remediation and
Metal3RemediationTemplate.

#### Remediation Controller

* MRC watches for the presence of Metal3Remediation CR.
* Based on the remediation strategy defined in ```.spec.strategy.type``` in
  Metal3Remediation, RC uses BMO APIs to get hosts back into a healthy or
  manageable state.
* RC uses ```.status.phase``` to save the states of the remediation. Available
  states are running, waiting, deleting machine.
* After RC have finished its remediation, it will wait for the Metal3Remediation
  CR to be removed. (When using CAPI MachineHealthCheck controller,
  MHC will noticed the Node becomes healthy and deletes the instantiated
  MachineRemediation CR.).
* If RCs timeout for Node to become healthy expires, it sets
  `capi.MachineOwnerRemediatedCondition` to False on Machine object
  to start deletion of the unhealthy Machine and the corresponding Metal3Remediation.
* If RCs timeout for Node to become healthy expires, it annotates BareMetalHost with
  `capi.metal3.io/unhealthy` annotation, sets BMH Online field to False and
  removes the Machine object.

#### Remediation operations

* BMO reboot annotation: ```reboot.metal3.io```
* BMO power off/on annotation: ```reboot.metal3.io/{key}```
* CAPM3 unhealthy annotation: ```capi.metal3.io/unhealthy```
* CAPI condition: ```capi.MachineOwnerRemediatedCondition```

#### Watch

* Watch Metal3Remediation CR resources.
* Watch BareMetalHost CR resources.

#### Reconcile

* Fetch a Machine matching the name of the Metal3Remediation and operate over
  BareMetalHost objects.
* Sets ```capi.MachineOwnerRemediatedCondition``` to False on Machine objects.

#### Metal3Remediation CRD

```yaml
apiVersion: remediation.metal3.io/v1alphaX
kind: Metal3Remediation
metadata:
  name: NAME_OF_UNHEALTHY_MACHINE
  namespace: NAMESPACE_OF_UNHEALTHY_MACHINE
  ownerReferences:
  - apiVersion: cluster.x-k8s.io/v1alphaX
    kind: Machine
    name: MACHINE_NAME
spec:
  strategy:
    type: reboot
    retryLimit: 3
    timeout: 300s
status:
  phase: running
  retryCount: 1
  lastRemediated: LAST_REMEDIATION_TIMESTAMP
```

#### Metal3RemediationTemplate CRD

Metal3RemediationTemplate is used in clusters which are using CAPI
MachineHealthCheck CR for detecting unhealthy Machines. MHC instantiates the
template generating Metal3Remediation.

```yaml
kind: Metal3RemediationTemplate
apiVersion: remediation.metal3.io/v1alphaX
metadata:
  name: M3_REMEDIATION_TEMPLATE_NAME
  namespace: NAMESPACE_OF_UNHEALTHY_MACHINE
spec:
  template:
    spec:
      strategy:
        type: reboot
        rebootLimit: 3
        timeout: 300s
```

### Implementation Details/Notes/Constraints

New Metal3Remediation CRD will be added as a part of CAPM3 v1alpha4 API.

### Risks and Mitigations

There is a slight possibility that
[BareMetalHost v1alpha2 API Migration](https://github.com/metal3-io/metal3-docs/pull/101)
changes the APIs and some rewriting of the remediation controller
code needs to be done after that.

### Work Items

* Implementation of remediation controller in CAPM3
* Unit tests for remediation controller
* Definition of Metal3Remediation and Metal3RemediationTemplate
* Documentation and instructions on how to use CAPI MachineHealthCheck
  with CAPM3 remediation features.

### Dependencies

This proposal depends on Cluster API external remediation
[proposal](https://github.com/kubernetes-sigs/cluster-api/pull/3190),
which enables support for external remediation strategies.

### Test Plan

* Unit tests for all the cases should be in place.
* e2e testing in Metal3-dev-env.

### Upgrade / Downgrade Strategy

This feature will be added in CAPM3 version v1alpha4 as part of the
release v0.4.X.

### Version Skew Strategy

If CAPM3 and the BMO are in different pods, an upgrade or downgrade could lead
to version skew (one pod supports machine remediation and the other doesn't)

An upgrade or downgrade affecting one component will
eventually be applied to the other and any version skew is temporary.

During the transient case that CAPM3 does not include the RC Host can be left in
unwanted state since RC could add annotation on BMH. After
downgrade there will be no controller to remove the annotations.

The impact is just delayed remediation and will be resolved once there's
no version skew.

## Drawbacks

* Only Machines owned by a MachineSet will be remediated by a MachineHealthCheck.
* Control Plane Machines are currently not supported and will not be remediated
  if they are unhealthy.

## Alternatives

* Omit the CAPI MachineHealthCheck and create Metal3 MachineHealthCheck
  controller and add remediation logic within the same controller.

## References

1. [CAPI MachineHealthCheck](https://cluster-api.sigs.k8s.io/tasks/automated-machine-management/healthchecking)
1. [CAPI External Remediation Proposal](https://github.com/kubernetes-sigs/cluster-api/pull/3190/files)
1. [re-inspection API proposal](https://github.com/metal3-io/metal3-docs/blob/main/design/baremetal-operator/inspection-api.md)
1. [BareMetalHost v1alpha2 API Migration](https://github.com/metal3-io/metal3-docs/pull/101)
