<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# userdefined-rootdevicehints

## Status

provisional

## Table of Contents

<!--ts-->
   * [userdefined-rootdevicehints](#userdefined-rootdevicehints)
      * [Status](#status)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
         * [Non-Goals](#non-goals)
      * [Proposal](#proposal)
         * [Implementation Details/Notes/Constraints](#implementation-detailsnotesconstraints)
         * [Risks and Mitigations](#risks-and-mitigations)
      * [Design Details](#design-details)
         * [Work Items](#work-items)
         * [Dependencies](#dependencies)
         * [Test Plan](#test-plan)
         * [Upgrade / Downgrade Strategy](#upgrade--downgrade-strategy)
         * [Version Skew Strategy](#version-skew-strategy)
      * [References](#references)

<!-- Added by: mikkosest -->

<!--te-->

## Summary

This document explains how rootdevicehints could be given as user defined parameters as part BaremetalHostSpec. The idea is that user would have the possibilty to define selective constraints for root device selection. Sometimes selective constrains will not be completely deterministic, but it is up to the user to decide which hints to use. 
Originally the only way for an user to select the used root device hints, was to to choose the name of the hardware profile which has hardcoded root device hint values. When exposing root device hints as part of the BMH spec, this will be part of deprecation steps for hardware profile.

## Motivation

We need to be able select root device, when there are multiple devices available so that device is not chosen randomly

### Goals

1. Decide which root device hints are needed be supported.
2. Agree on the way how information is propagated to ironic through BMO


### Non-Goals

The complete set of root device hints as input are not needed, only the relevant ones.

## Proposal

### Implementation Details/Notes/Constraints

- BaremetalHostSpec need to be updated to support list of following root device hints:
* devicename
* hctl
* vendor
* size
* wwn

Deteriministic selectors. i.e if used together with each other, those should point the same device instance and should not conflict with group selectors below.

Deterministic selectors
* devicename
* hctl
* wwn

Group selectors
* vendor
* size


The above parameters are optional in BaremetalHostSpec. Originally Hardware profiles contains hardcoded root device hints, which will be now removed. If there is deterministic hint like devicename or wwn used, then those will dominant selectors over other hints which would be ignored. 

The new struct type added to spec could look like below. In the original inventory code there is an Storage struct that has pretty much the same content, but by having a separete struct we can control easily if we want to add or deprecate support for some hints. Size is given in Gigabytes while in Storage it is given in bytes in order to avoid scale typos in size input.

type RootDeviceHints struct {
	// A device name like "/dev/vda"
	DeviceName string `json:"devicename,omitempty"`

	// A SCSI bus address like 0:0:0:0
	HCTL string `json:"hctl,omitempty"`

	// Device identifier
	Model string `json:"model,omitempty"`

	// Device vendor
	Vendor string `json:"vendor,omitempty"`

	// Disk serial number
	Serial string `json:"serial,omitempty"`

	// Size of the device in GiB
	SizeGigaBytes int `json:"size,omitempty"`

	// Unique storage identifier
	WWN string `json:"wwn,omitempty"`

	// Unique storage identifier with the vendor extension appended
	WWNWithExtension string `json:"wwnWithExtension,omitempty"`

	// Unique vendor storage identifier
	WWNVendorExtension string `json:"wwnVendorExtension,omitempty"`
}


### Risks and Mitigations

-

## Design Details

### Work Items

- Update BaremetalHostSpec with new RootDeviceHints type struct to have above parameters as optional.
- Generate new CRDs and update BMO ironic and profile pkg code to interpret the spec and propagate root device hint parameters as string map to gophercloud package
- Update unit tests
- Verify device selection in metal3-dev-env 

### Dependencies

This requires refactoring of BMO repository code.

### Test Plan

- Unit test
- metal3-dev-env integration test

### Upgrade / Downgrade Strategy

N/A

### Version Skew Strategy

N/A

## References

- [Ironic Root Device Hint Documentation](https://docs.openstack.org/ironic/pike/install/include/root-device-hints.html)

