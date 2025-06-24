<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Preprovisioning kernel argument support

## Status

implemented

## Summary

This document describes the BareMetalHost spec attribute for
configuring preprovisioning image kernel arguments with support for
PreprovisioningImage integration and format-specific parameter handling.

## Motivation

There are situations where a user would need node specific kernel arguments
for the preprovisioning image. The reason could be the use of a mixed set of
hardware, troubleshooting provisioning or boot issues, selectively configuring
custom logic e.g. enabling IPA plugins or other services embedded in the
preprovisioning image.

### Goals

1. Implement a string type optional spec field named `preprovisioningExtraKernelParams`
1. Extend the generic `Provisioner` interface to support the new optional field
1. Implement support for the `preprovisioningExtraKernelParams` in the Ironic
   provisioner
1. Combine the values of the `preprovisioningExtraKernelParams` and the
   `preprovisioningImage`'s `status.extraKernelParams` field when a
   `preprovisioningImage` is referenced by the BMH and the `status.extraKernelParams`
   is not empty
1. Handle format-specific parameter behavior for different PreprovisioningImage
   formats
1. Support kernel parameter updates across all lifecycle management operations

### Non-Goals

1. Implement validation for the new optional field
1. Provide a default value for the new spec field
1. Implement conditional logic to overwrite default kernel parameters on
   per node basis without using the %default% mechanism

## Proposal

This document describes the BareMetalHost spec attribute for
configuring preprovisioning image kernel arguments with intelligent
parameter combination logic based on PreprovisioningImage formats.

The proposal involves a new spec field modification to the BMO API
that is fully backward compatible as the new `preprovisioningExtraKernelParams`
field is optional.

### Implementation Details/Notes/Constraints

The `preprovisioningExtraKernelParams` field is located directly under the
`spec` section as a string field. The feature provides intelligent parameter
combination based on PreprovisioningImage format and ownership:

#### Basic Usage

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: bm0
spec:
  online: true
  bmc:
    address: "idrac://192.168.122.1:6230/"
    credentialsName: bm0-bmc-secret
  preprovisioningExtraKernelParams: "console=ttyS0,115200 intel_iommu=on"
  # ...
  bootMACAddress: "52:54:00:b7:b2:6f"
```

#### Parameter Combination Logic

The feature supports four distinct scenarios with 3 outcomes based on
PreprovisioningImage format and ownership:

1. **No PreprovisioningImage or Provisioner without PPI support**
   - Uses only BMH `preprovisioningExtraKernelParams`
   - Formatted with `%default%` prefix by Ironic provisioner

1. **ISO format PreprovisioningImage**
   - **BMH parameters are ignored** (kernel params already embedded in ISO)
   - Warning logged when BMH params are specified but ignored
   - Only PPI kernel parameters are used

1. **InitRD format PreprovisioningImage**
   - **BMH and PPI parameters are combined**
   - Final result: `BMH_params + " " + PPI_params`
   - Both external and BMO-managed PPIs supported

1. **BMO-managed PreprovisioningImage (default provider)**
   - Uses only BMH `preprovisioningExtraKernelParams`
   - PPI parameters from default provider are ignored
   - Maintains consistency with non-PPI deployments

#### Ownership Detection

The feature distinguishes between:

- **External PreprovisioningImages**: Created/managed by external controllers
- **BMO-managed PreprovisioningImages**: Created by BMO's default image provider

This distinction enables different parameter handling strategies and prepares
for future multi-tenancy support.

#### Ironic Integration

The Ironic provisioner:

- Always prepends `%default%` to kernel parameters for consistency
- Updates BMC driver_info with `kernel_append_params` during registration
- Supports conditional driver_info updates when parameters change
- Maintains compatibility across all BMC protocols (IPMI, Redfish, iDRAC)

#### Lifecycle Operation Support

Kernel parameters are updated during all relevant lifecycle operations:

- **Registration**: Initial parameter setup
- **Preparing**: Parameters refreshed before cleaning
- **Provisioning**: Parameters applied for deployment
- **Servicing**: Parameters updated for maintenance operations

This enables dynamic kernel parameter changes for debugging and operational
needs.

### Format-Specific Behavior Matrix

| PreprovisioningImage Format | BMH Params | PPI Params | Final Result | Notes |
|----------------------------|-------------|------------|--------------|-------|
| No PPI / No PPI Support    | Used        | N/A        | `%default% BMH_params` | Standard behavior |
| ISO (External)             | Ignored     | Used       | `PPI_params` | Warning logged if BMH params specified |
| ISO (BMO-managed)          | Used        | Ignored    | `%default% BMH_params` | Consistent with no-PPI behavior |
| InitRD (External)          | Used        | Used       | `%default% BMH_params PPI_params` | Parameters combined |
| InitRD (BMO-managed)       | Used        | Ignored    | `%default% BMH_params` | Consistent with no-PPI behavior |
| Unknown Format             | Used        | Ignored    | `%default% BMH_params` | Fallback behavior |

### Risks and Mitigations

Providing faulty kernel arguments might result in boot issues or unexpected
behavior during the lifecycle of the preprovisioning image. The feature
provides several mitigations:

- Graceful fallback to BMH parameters when PPI processing fails
- Warning logs for format-specific parameter behavior
- Maintains %default% prefix for Ironic consistency
- No validation prevents breaking existing workflows

## Design Details

The feature extends the BMO architecture with:

1. **Enhanced BareMetalHost Controller**
   - `retrievePreprovisioningExtraKernelParamsSpec()` for intelligent parameter
     combination
   - Ownership detection logic for external vs BMO-managed PreprovisioningImages
   - Format-specific parameter handling with switch-based logic

1. **PreprovisioningImage Controller Integration**
   - `findOwnerBMH()` for controller owner reference resolution
   - BMH kernel parameter injection for initrd format images
   - Groundwork for future multi-tenancy support

1. **Provisioner Interface Extensions**
   - Extended `ManagementAccessData` with `PreprovisioningExtraKernelParams`
     field
   - Backward compatibility with existing provisioner implementations
   - Graceful degradation for provisioners without PPI support

1. **Ironic Provisioner Enhancements**
   - Updated BMC driver implementations for kernel parameter support
   - Conditional driver_info updates based on parameter changes
   - `fmtPreprovExtraKernParams()` helper for consistent parameter formatting

### Work Items

- String type optional spec field named `preprovisioningExtraKernelParams`
- Extended generic `Provisioner` interface to support the new optional field
- Support for `preprovisioningExtraKernelParams` in the Ironic driver
- Extended data types used in different operational states to hold
  `preprovisioningExtraKernelParams`
- Comprehensive unit tests covering all parameter combination scenarios
- PreprovisioningImage integration with ownership detection
- Format-specific parameter handling (ISO vs initRD)
- BMC driver integration across all supported protocols

### Dependencies

- Ironic (for the Ironic Provisioner implementation)
- PreprovisioningImage CRD (for PPI integration scenarios)

### Test Plan

- Unit tests covering scenarios for parameter combination logic
- Unit tests for kernel parameter formatting and ownership resolution
- Integration tests with existing BMC driver test suites
- Integration testing with VMs as part of e2e workflow (planned)

### Upgrade / Downgrade Strategy

- **Upgrade**: No user action required, field is optional and backward compatible
- **Downgrade**: Users must remove the `preprovisioningExtraKernelParams`
  field from BMH specs to maintain API compatibility

### Version Skew Strategy

The feature handles version skew gracefully:

- Provisioners without PPI support fall back to BMH-only parameters
- Older Ironic versions continue to work with standard kernel parameter handling
- No breaking changes to existing provisioner interfaces

## Drawbacks

- Additional complexity in parameter combination logic
- Format-specific behavior may be unintuitive for users
- No validation of kernel parameter syntax

## Alternatives

Alternative approaches considered but not implemented:

- Status field for last applied parameters (complexity vs benefit)
- Array-based parameter specification (string more flexible, no functional
  benefit)
- Separate fields for different parameter types (over-engineering)

## Reference

- [Ironic kernel_append_params Documentation](https://docs.openstack.org/ironic/latest/install/advanced.html#appending-kernel-parameters-to-boot-instances)
