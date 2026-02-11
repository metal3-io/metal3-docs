<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# bios-config

## Status

provisional

## Summary

This document explains the usage of YAML attributes for BIOS
configuration for the BareMetalHost of the BMO. These configurations
will be applied to the host according to the vendor's BMC driver being
used by Ironic.

## Motivation

We need this document to specify the typical usage of BIOS YAML
attributes in the BareMetalHost YAML.

### Goals

1. To agree on the format of the attributes that are to be supported
   as a starting point
1. To keep the attribute naming vendor agnostic

### Non-Goals

1. To list every attribute for every vendor exhaustively

## Proposal

The proposal is to set/unset the BIOS configuration values using
vendor drivers available for each BMC type. For this purpose, new YAML
attributes are to be introduced in the BareMetalHost spec.

### Implementation Details/Notes/Constraints

All the BIOS related attributes or fields will come under the
sub-section called ```bios``` in spec. The values for each attribute
can be a boolean or a string. The vendor driver type to implement this
configuration is not to be specified separately as it is already known
from the bmc sub-section.

The proposed BMH looks like the following, given the three supported
parameters

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: bm0
spec:
  online: true
  bmc:
    address: idrac://192.168.122.1:6230/
    credentialsName: bm0-bmc-secret
  bootMACAddress: 52:54:00:b7:b2:6f
  firmware:
    sriovEnabled: false
    virtualizationDisabled: false
    simultaneousMultithreadingDisabled: false
```

We've decided to name the section "firmware" to make it future proof,
since the notion of BIOS is irrelevant outside of x86
architectures. This is also to make the distinction that BIOS !=
UEFI. Moreover, in the future, this can be extended to add extra
information, for instance current firmware version etc. Then it can be
decided to restructure this section.

The booleans are to be implemented as pointers, allowing us to detect
when user has asked for a change.

To handle settings that are vendor specific, the following format can
be used:

```yaml
firmware:
  attr: value1
  #attr: value2
  vendor:
    vendor_attr: value1
    #vendor_attr: value2
```

The proposal only deals with the generic BIOS configurations (listed
above), and nothing vendor specific will be developed/tested,
although, formatting for those will be part of this specification.

One gotcha to this is about hiding the vendor sprawl in the parameter
names and coming up with generic titles for the config params. Have
had many discussions on this, and we have agreed to the format
specified above.

This would then need to be handled in the operator code (the
vendor-specific implementation for Ironic API calls). Meaning, it will
still be required to map these *generic* names to the actual parameter
names in the API call for it to function.

### Risks and Mitigations

None

## Design Details

This BIOS config will be implemented through Ironic
`bios-interface`. These settings will only be applied to a host
when it is being provisioned with an image. A change in BIOS configs
on a host with running workload will NOT trigger reprovisioning.

The code changes required would entail

- Creating a go struct with the BIOS configs in the `ironic.go
  (pkg/provisioner/ironic/ironic.go)`

- Creating a new function to validate config params and build a final
  JSON object, called `buildBIOSConfig` in `ironic.go`

- Creating a new function to build clean steps for BIOS config called
  `buildBIOSCleanSteps` in `ironic.go`

### Work Items

- Extend the BareMetalHost CRD with the new parameters for iDRAC BMC type.

- Validation of input values in the YAML parameters

- A function to handle the cleaning steps related to BIOS configuration and its implementation

- Unit tests for all the work above

### Dependencies

- Ironic
- Baremetal-operator

### Test Plan

- Unit tests for the functions

- Integration testing with actual hardware

### Upgrade / Downgrade Strategy

None

### Version Skew Strategy

None

## Drawbacks

None

## Alternatives

None

## References

- [PR in baremetal-operator repo with discussion on this
  topic](https://github.com/metal3-io/baremetal-operator/pull/302)

- [Issue #364 in the baremetal-operator repo was the starting point
  for
  this](https://github.com/metal3-io/baremetal-operator/issues/364)

- [Issue #206 in the baremetal-operator repo was a similar discussion
  between the community and Fujitsu
  guys](https://github.com/metal3-io/baremetal-operator/issues/206)
