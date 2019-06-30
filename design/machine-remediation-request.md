<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# machine-remediation

## Status

in-progress

## Table of Contents

<!--ts-->
* [machine-remediation](#machine-remediation)
  * [Status](#status)
  * [Table of Contents](#table-of-contents)
  * [Summary](#summary)
  * [Motivation](#motivation)
    * [Goals](#goals)
    * [Non-Goals](#non-goals)
  * [Proposal](#proposal)
    * [Implementation Details/Notes/Constraints](#implementation-detailsnotesconstraints)
      * [MachineRemediation spec API](#MachineRemediation-spec-api)
      * [MachineRemediation status API](#MachineRemediation-status-api)
    * [Risks and Mitigations](#risks-and-mitigations)
  * [Design Details](#design-details)
    * [Work Items](#work-items)
    * [Dependencies](#dependencies)
    * [Test Plan](#test-plan)
    * [Upgrade / Downgrade Strategy](#upgrade--downgrade-strategy)
    * [Version Skew Strategy](#version-skew-strategy)
  * [Alternatives](#alternatives)
  * [References](#references)

<!-- Added by: dhellmann, at: Wed Jun 26 16:08:57 EDT 2019 -->

<!--te-->

## Summary

This document explains the implementation of the Machine Remediation Request controller and
how it will work together with Machine Health Check controller to restore unhealthy machines.

## Motivation

To provide a mechanism to apply remediation strategy on an unhealthy node, that will be different by type and by a provider.

### Goals

1. To provide the interface that will make possible to apply different remediation strategy for each cloud or bare metal providers.
2. To provide details regarding the progress of the remediation operation.

### Non-Goals

1. To provide a remediation strategy for each cloud or bare metal providers.
2. To provide the integration with the **MachineHealthCheck** controller.

## Proposal

### Implementation Details/Notes/Constraints

It's common that high available environment should have a mechanism to restore unhealthy nodes and when delete and create a new node looks feasible solution for a cloud provider, in case of bare metal hosts with additional infrastructure configuration it looks like too destructive approach.
To make possible to specify the remediation strategy for different failure cases and for nodes that run on different providers, this proposal introduces **MachineRemediation** controller that should monitor all **MachineRemediation** CR's and apply the remediation strategy according to details specified under the CR.
When the **MachineRemediation** will apply the remediation strategy, one who is initiating it will be the **MachineHealthCheck** controller. It will monitor nodes, and for each unhealthy node will create **MachineRemediation** CR, if after the specified timeout the **MachineRemediation** will not have the `remediationState` equal to `Succeeded`, the **MachineHealthCheck** controller will notify about the remediation failure, and can try to use different type of the remediation strategy.

#### MachineRemediation spec API

This proposal introduces a new API type: **MachineRemediation**, that makes possible to create simple **MachineRemediation** object with the type of the remediation strategy for the specific machine.

##### Example

```yaml
apiVersion: MachineRemediation.metal3.io/v1alpha1
kind: MachineRemediation
metadata:
  name: mr-test
  namespace: openshift-machine-api
spec:
  type: reboot
  machineName: test-machine
```

#### MachineRemediation status API

**MachineRemediation** status will show what the state the remediation operation has and the time when the remediation operation started.

```yaml
status:
  state: InProgress
  reason: The fencing operation still in progress
  startTime: Thu, 20 Jun 2019 03:38:39 -0400
  endTime: Thu, 20 Jun 2019 03:40:39 -0400
```

### Risks and Mitigations

It can introduce some integration complexity between **MachineHealthCheck** and **MachineRemediation** controllers,
that will make harder to debug and to test things.

## Design Details

### Work Items

* Create new **MachineRemediation** CRD.
* Write a new controller that will watch **MachineRemediation** CR's.
* Create an operator to deploy the **MachineRemediation** controller.
* Create integration with the OLM.

### Dependencies

N/A

### Test Plan

As basic tests, it will be enough to create **MachineRemediation** CR's with the reboot type and verify that the machine really rebooted. In the future, we will need to test integration between **MachineHealthCheck** and **MachineRemediation** controllers to verify that our final fencing solution works as expected.

### Upgrade / Downgrade Strategy

Should be managed by OLM.

### Version Skew Strategy

The **MachineRemediation** controller version should be the same as **MachineHealthCheck** version.

## Alternatives

### Implement the remediation strategies under the actuator

We implement in the remediation strategy under the machine actuator. It's already watching Machine resources of course, and it already knows how to interact with whatever the local management API is that would carry out remediation.

In this case, the reboot request could be reflected as an annotation on the Machine. Status would be a little trickier, but it's not unheard of to reflect status in an annotation. So you could have a reboot/request annotation and a reboot/last annotation for example, whose values might be timestamps.

Without direct support in the machine API, this would not be as robust or clear as the **MachineRemediation**, but it would be simple to implement and would not require a new controller. It also seems like a good behavioral fit for the machine controller.

### Implement remediation strategies under the MachineHealthCheck controller

We can implement the remediation strategy under the **MachineHealthCheck** controller,
in this case, we will have fewer controllers but also less granularity, because **MachineHealthCheck** works on a group of machines.

### Implement remediation strategies under the machine-api-operator repository

We can implement the remediation strategy under the `machine-api-operator` repository, as separate controllers, it not a bad idea in the long term, because we will not need to implement our own operator and integration with OLM.
Also, it will be easier to provide components with the same version.
But it does not look real to merge this stuff quickly under the `machine-api-operator` repository, but we can move it in the future.

## References

* [machine-health-check](https://github.com/openshift/machine-api-operator/tree/master/pkg/controller/machinehealthcheck)
