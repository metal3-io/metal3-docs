# inspection API

## Status

implemented

## Summary

A declarative API is proposed to request the baremetal operator to
inspect a `Ready` BareMetalHost.

## Motivation

We would like to have an interface to allow a user to re-gather hardware
inventory of a `Ready` BareMetalHost when a hardware replacement is made.
When a user of the underlying infrastructure makes some changes to the actual
server (e.g. replace or add NIC, disk, etc.), the latest hardware inventory
including those changes need to be re-collected and updated on the spec of the
corresponding BareMetalHost object without having to delete it.

Implementation of this proposal is based on using annotation (similar to
[Reboot API](https://github.com/metal3-io/metal3-docs/blob/main/design/baremetal-operator/reboot-interface.md))
to request inspection of a `Ready` BareMetalHost.
Once the annotation is set on BareMetalHost, the baremetal operator will
request hardware inspection of the host from Ironic.

### Goals

- A declarative API to perform inspection
- Use this API for future Metal³ remediation controller

### Non-Goals

- Automated mechanism to trigger inspection

## Proposal

We follow Reboot API implementation and expect to implement the similar
annotation based interface for a user to trigger inspection.

`inspect.metal3.io` annotation form on BareMetalHost object
triggers the controller to query Ironic for inspection of a host. This form
has set-and-forget semantics and controller removes the annotation once
inspection is completed.
While the host is being inspected, the BareMetalHost will stay in
`Inspecting` state until the process is completed.

Re-inspection API can be requested only when BareMetalHost is in `Ready`
state. If a re-inspection request is made while BareMetalHost is any other
state than `Ready`, the request will be ignored. This is important in order to
not reboot a BareMetalHost (e.g. when `spec.provisioning.state == provisioned`)
or avoid having unintended inconsistent states.

|BMH state|Externally provisioned|API action|Annotation|
|---|---|---|---|
|Ready|No|move to Inspecting state|delete|
|Inspecting|No|nothing|delete|
|Provisioning|No|nothing|keep it until BMH is in Ready state|
|Provisioned|No|nothing|keep it until BMH is in Ready state|
|Provisioned|Yes|nothing|keep it until BMH is in Inspecting state|

After completing inspection, previous inspection data should be updated
both in Ironic and on the spec of the BareMetalHost object. Both
`status.operationHistory.inspect.start` and
`status.operationHistory.inspect.end` timestamps should be updated accordingly.

### User stories

#### Story1

- As a cluster admin, I would like to have a simple way of triggering
  inspection for my server after I replace NIC, disk, etc.

## Future Enhancements

Re-inspection API and reboot API interfaces can be modified to have a
more formal interface for future Metal³ remediation controller.

## Alternatives

One alternative approach to keep hardware details updated is to run Ironic
Python Agent (IPA) as a pod on the node which would be constantly updating the
hardware details of the host.

## References

- Reboot API [proposal](https://github.com/metal3-io/metal3-docs/blob/main/design/baremetal-operator/reboot-interface.md)
- Reboot API [implementation](https://github.com/metal3-io/baremetal-operator/pull/424)
