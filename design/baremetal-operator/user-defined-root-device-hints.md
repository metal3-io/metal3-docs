<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# user-defined-root-device-hints

## Status

implemented

## Summary

This document explains how `rootDeviceHints` could be given as user
defined parameters as part BaremetalHostSpec. The idea is that user
would have the possibility to define selective constraints for root
device selection. Sometimes selective constrains will not be
completely deterministic, but it is up to the user to decide which
hints to use.

Originally the only way for an user to select the used root device
hints, was to choose the name of the hardware profile which has
hardcoded root device hint values. When exposing root device hints as
part of the BMH spec, this will be part of deprecation steps for
hardware profile.

## Motivation

We need to be able select root device, when there are multiple devices
available so that device is not chosen randomly

### Goals

1. Decide which root device hints are needed be supported.
1. Agree on the way how information is propagated to ironic through BMO

### Non-Goals

The complete set of root device hints as input are not needed, only
the relevant ones.

## Proposal

### Implementation Details/Notes/Constraints

The BaremetalHostSpec need to be updated to have an optional root
device hint field. We need to support explicit values of different
types, rather than using an index into discovered values from the
status field, to support external storage such as SAN arrays or Ceph
clusters. External storage may not be present at the time of
inspection, so it would not appear in the set of discovered storage
locations.

The list of selectors to be added will include some deterministic
values, meaning that they should always result in the same device
instance being selected and should not conflict with group selectors
below.

- device name
- HCTL
- WWN
- serial number

Other selectors will be less deterministic, because multiple devices
may match.

- vendor/manufacturer name
- size

If multiple selectors are specified, a device must match all of them
to be used.

Devices are examined in the order they are discovered by the
provisioning agent running on the host. The first device that matches
all of the selectors is used.

Originally hardware profiles defined hard-coded root device
hints. Hardware profiles will be removed as part of the next version
of the BareMetalHost API. Until then, if an explicit hint is given it
will be used instead of the value from the profile. If no explicit
hint is given the profile setting will be used.

The new struct type added to spec could look like below.

- Size is given in Gigabytes while in Storage it is given in bytes in
  order to avoid scale typos in size input.
- There are 2 forms of the WWN value, using separate fields or a
  combined field. These match the discovered values and allow the user
  to provide matching input without having to build a composite string
  if one is not found through inspection.

```go
type RootDeviceHints struct {
    // A device name like "/dev/vda"
    DeviceName string `json:"deviceName,omitempty"`

    // A SCSI bus address like 0:0:0:0
    HCTL string `json:"hctl,omitempty"`

    // Device identifier
    Model string `json:"model,omitempty"`

    // Device vendor
    Vendor string `json:"vendor,omitempty"`

    // Disk serial number
    SerialNumber string `json:"serialNumber,omitempty"`

    // Size of the device in gigabytes
    SizeGigabytes int `json:"sizeGigabytes,omitempty"`

    // Unique storage identifier
    WWN string `json:"wwn,omitempty"`

    // Unique storage identifier with the vendor extension appended
    WWNWithExtension string `json:"wwnWithExtension,omitempty"`

    // Unique vendor storage identifier
    WWNVendorExtension string `json:"wwnVendorExtension,omitempty"`
}
```

### Risks and Mitigations

- The proposed format is based on the inspection values and inputs
  that Ironic uses. This ties us a bit more to Ironic, but the values
  are also expressive enough that another provisioning tool should be
  able to accept them in some form, or metal3 code should be able to
  use them to identify a discovered device.

## Design Details

### Work Items

- Update BaremetalHostSpec with new RootDeviceHints type struct to
  have above parameters as optional.
- Generate new CRDs and update BMO ironic and profile pkg code to
  interpret the spec and propagate root device hint parameters as
  string map to gophercloud package
- Update unit tests
- Verify device selection in metal3-dev-env

### Dependencies

This requires refactoring of BMO repository code.

### Test Plan

- Unit test
- metal3-dev-env integration test

### Upgrade / Downgrade Strategy

In the original inventory code there is an Storage struct that has
pretty much the same content, but by having a separate struct we can
control easily if we want to add or deprecate support for some hints.

### Version Skew Strategy

N/A

## References

- [Ironic Root Device Hint Documentation](https://docs.openstack.org/ironic/pike/install/include/root-device-hints.html)
- [Implementation](https://github.com/metal3-io/baremetal-operator/pull/495)
