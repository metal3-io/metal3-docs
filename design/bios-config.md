<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# bios-config

## Status

provisional

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

## Summary

This document explains the usage of YAML attributes for BIOS configuration for the BareMetalHost of the BMO. These configurations will be applied to the host according to the vendor's BMC driver being used by Ironic.

## Motivation

We need this document to specify the typical usage of BIOS YAML attributes in the BareMetalHost YAML. 


### Goals

1. To agree on the format of the attributes that are to be supported as a starting point
2. To keep the attribute naming vendor agnostic

### Non-Goals

1. To list every attribute for every vendor exhaustively

## Proposal
The proposal is to set/unset the BIOS configuration values using vendor drivers available for each BMC type. For this purpose, new YAML attributes are to be introduced in the BareMetalHost spec. 
 
### Implementation Details/Notes/Constraints 
All the BIOS related attributes or fields will come under the sub-section called ```bios``` in spec. The values for each attribute can be a boolean or a string. The vendor driver type to implement this configuration is not to be specified separetely as it is already known from the bmc sub-section.
Initially, the BIOS configuration can be applied using the controller types idrac and irmc

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
 bios:
   EnableSriovGlobal: false
   EnableVirtualization: false
   EnableHyperThreading: true
   EnableAdjCacheLine: false
```

The user can only specify the BIOS values related to the BMC type being used as they will be validated accordingly.

One gotcha to this is about hiding the vendor sprawl in the parameter names and coming up with generic titles for the config params. This would then need to be handled in the operator code (the vendor-specific implementation for Ironic API calls). Meaning, it will still be required to map these *generic* names to the actual parameter names in the API call for it to function.

### Risks and Mitigations

None

## Design Details

This BIOS config will be implemented through Ironic ```vendorPassthru```. These settings will only be applied to a host when it is being provisioned with an image. A change in BIOS configs on a host with running workload will NOT trigger reprovisioning.

The code changes required would entail 
- Creating a go struct with the BIOS configs in the ```ironic.go (pkg/provisioner/ironic/ironic.go)```

- Creating a new function to validate config params and build a final JSON object, called ```buildBIOSConfig``` in ```ironic.go```

- Creating a new function to build clean steps for BIOS config called ```buildBIOSCleanSteps``` in ```ironic.go```

### Work Items

- Extend the BareMetalHost CRD with the new parameters for iDRAC and Redfish BMC types.

- Validation of input values in the YAML parameters

- A function to handle the cleaning steps related to BIOS configuration and its implementation

- Unit tests for all the work above


### Dependencies

- Ironic
- Baremetal-operator

### Test Plan

- Unit tests for the functions

- Mock deployment testing with vBMC

- Deployment testing with actual hardware


### Upgrade / Downgrade Strategy

None

### Version Skew Strategy

None

## Drawbacks

None

## Alternatives

None

## References

- [PR in baremetal-operator repo with discussion on this topic](https://github.com/metal3-io/baremetal-operator/pull/302)

- [Issue #364 in the baremetal-operator repo was the starting point for this](https://github.com/metal3-io/baremetal-operator/issues/364)

- [Issue #206 in the baremetal-operator repo was a similar discussion between the community and Fujitsu guys](https://github.com/metal3-io/baremetal-operator/issues/206)
