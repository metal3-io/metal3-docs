<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# service-indicator-lights

## Status

One of: provisional

## Table of Contents

<!--ts-->
   * [service-indicator-lights](#service-indicator-lights)
      * [Status](#status)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
         * [Non-Goals](#non-goals)
      * [Proposal](#proposal)
         * [User Stories](#user-stories)
            * [As an operator, I want to be able to match a software-reported fault to the hardware device that has failed.](#as-an-operator-i-want-to-be-able-to-match-a-software-reported-fault-to-the-hardware-device-that-has-failed)
         * [Implementation Details/Notes/Constraints](#implementation-detailsnotesconstraints)
         * [Risks and Mitigations](#risks-and-mitigations)
      * [Design Details](#design-details)
         * [Work Items](#work-items)
         * [Dependencies](#dependencies)
         * [Test Plan](#test-plan)
         * [Upgrade / Downgrade Strategy](#upgrade--downgrade-strategy)
         * [Version Skew Strategy](#version-skew-strategy)
      * [Drawbacks](#drawbacks)
      * [References](#references)

<!-- Added by: dhellmann, at: Wed Jun 12 16:19:59 EDT 2019 -->

<!--te-->

## Summary

Many hardware platforms have "indicator" lights in the chassis front
(or rear) panel and sometimes have other lights associated with
individual components like drives inside the chassis. We need to
provide a way to turn those lights on when service is needed for a
host, and off when service is no longer needed. This document
describes the new CRD and controller for managing indicator lights.

## Motivation

### Goals

1. Enable operations staff to identify physical devices associated
   with software-reported faults.

### Non-Goals

1. Actively manage all indicator lights for all known hardware.

## Proposal

### User Stories

#### As an operator, I want to be able to match a software-reported fault to the hardware device that has failed.

### Implementation Details/Notes/Constraints

As with many BMC-related operators, we must take care not to overwhelm
the management controller with too many requests for state or
updates. Since a single chassis might have a dozen or more indicator
lights, polling for their status regularly may place excessive load on
the management controller.

Unlike some other operations with BMCs, polling or changing the state
of the indicator light for an internal component may require
interacting with the I/O controller, which may interrupt regular I/O
operations. For this reason, Ironic does not regularly poll the status
of indicator lights and does not cache their status when an outside
user queries it.

We do not want to disturb production data flow any more than
necessary, so we want to limit the amount of polling we do related to
indicator lights from metal3.

Because of these 2 constraints, we do not want to add indicator
management to the existing BareMetalHost controller or CRD. Instead,
we will define a new CRD to represent a service indicator light that
is in use.

Only lights associated with an instance of the new CRD will be managed
at all, and that management is limited to checking and toggling the
state of the light when the resource in k8s changes. No active
management is performed to ensure that state continues to match the
resource.

### Risks and Mitigations

1. Polling too frequently will cause more than the usual level of
   issues with the BMC or disk controllers. We mitigate these problems
   by reducing the number of devices we actually poll, and reducing
   the polling frequency.

2. Because less polling is performed, the state of the CR is more
   likely to become out of sync with the hardware if some other
   component is also manipulating the indicator light. We can mitigate
   the effect of that by ensuring that the code that turns the light
   on/off checks the status before trying to change it so it is
   idempotent.

## Design Details

We will extend the `BareMetalHost` CRD to include information about
the available indicators so that users can find their IDs. The details
of how that information will be stored need to be worked out -- we may
use a simple list of strings, but if we can map the IDs to known
devices like disks we could also associate the IDs with those devices
directly by adding them to the existing data structures.

We will define a new CRD `BareMetalHostServiceIndicator` (referred to
as "indicator CRD" elsewhere in this document) with the following spec
and status structures.

```go
type BareMetalHostServiceIndicatorSpec struct {
	// HostRef is a reference to the bare metal host
	HostRef corev1.ObjectReference `json:"hostRef"`

	// Indicator ID
	ID string `json:"id"`

	// Should the light be on?
	On bool `json:"on"`
}

type BareMetalHostServiceIndicatorStatus struct {
	// Do we think the light is on?
	On bool `json:"on"`

	// LastUpdated identifies when this status was last observed.
	// +optional
	LastUpdated *metav1.Time `json:"lastUpdated,omitempty"`

	// the last error message reported by the provisioning subsystem
	ErrorMessage string `json:"errorMessage"`
}
```

We will create a new controller within the baremetal-operator to
manage the new CRD. This means we do not need a separate service
running in a separate container, so the deployment should look the
same aside from registering the new CRD.

The controller for the indicator CRD will use the same Ironic URL
configuration settings and communicate directly with Ironic to ask
about and manipulate the status of an indicator light.

The controller for the indicator CRD will only communicate with Ironic
when its `Spec.On` value does no match its `Status.On` value. As soon
as that condition is met without an error, the controller will assume
that the state is "sticky" and does not need to be changed. This may
lead to the resource settings being out of sync with the hardware if
the BMC is rebooted, or the light is automatically enabled by the BMC
itself, for example.

Deleting an indicator resource will turn the light off.

### Work Items

- Add new Ironic APIs to gophercloud
- Update gophercloud used by baremetal-operator repo
- Define indicator CRD
- Create indicator controller

### Dependencies

- We need new client code in gophercloud to use the new Ironic API for
  managing indicator lights.

### Test Plan

As with the Provisioner API, we will create an interface for managing
indicators so that we can write automated unit tests.

### Upgrade / Downgrade Strategy

N/A

### Version Skew Strategy

N/A

## Drawbacks

By not actively managing the status of the indicator and reconciling
it when it is different from the resource in k8s, it is possible for
factors outside our control to turn an indicator on or off when it
should be off or on, and for it to stay in that state. This is deemed
less risky than interrupting production data I/O regularly in order to
check the status of the indicators.

## References

- [Ironic spec with design for indicator lights](https://review.opendev.org/#/c/655685/)
- [Ironic change to add indicator API endpoints](https://review.opendev.org/#/c/651785/)
  (see earlier patches in the chain for underlying implementation details)
- [Storyboard #2005342](https://storyboard.openstack.org/#!/story/2005342)
  ticket for tracking ironic work on this feature
