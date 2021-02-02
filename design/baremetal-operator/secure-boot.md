<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Secure boot support

## Status

implemented

## Summary

This design proposes exposing an ability to turn UEFI secure boot on and off
during provisioning and deprovisioning.

## Motivation

Security-conscious deployments would like to make sure secure boot is enabled
for their instances, so that the hardware refuses to boot kernel-level code
that has not been signed with a known key.

### Goals

- API addition to enable secure boot before booting the instance (and disable
  it on deprovisioning)

### Non-Goals

- Support for custom secure boot keys.
- Secure boot during deployment/cleaning/inspection.

## Proposal

## Design Details

Add a new value for `BootMode` enumeration: `UEFISecureBoot`. If set on a host,
the following change are done to the corresponding Ironic node object:

- `boot_mode:uefi,secure_boot:true` is added to `properties.capabilities`.
- `secure_boot` with a value of `true` is added to
  `instance_info.capabilities`.

Add a `SupportsSecureBoot` call to `AccessDetails`, returning `true` for
`redfish://`, `redfish-virtualmedia://`, `idrac-virtualmedia`, `ilo4://`,
`ilo5://` and `irmc://`.

### Implementation Details/Notes/Constraints

- Strictly speaking, it's enough to add the `secure_boot` capability only to
  `instance_info`, `properties` is only updated for consistency.
- Secure boot can be used with live ISO but only when virtual media is used to
  deliver it (secure boot is incompatible with network booting in practice).

### Risks and Mitigations

None, secure boot is off by default.

### Work Items

- Update `AccessDetails` with a new call.
- Define a new value for `BootMode`.

### Dependencies

- [Ironic support for Redfish secure boot
  management](https://review.opendev.org/c/openstack/ironic/+/771493) is on
  review upstream.

### Test Plan

Unfortunately, at this point it's only possible to test this feature on real
hardware.

### Upgrade / Downgrade Strategy

None

### Version Skew Strategy

None

## Drawbacks

None

## Alternatives

Require users to configure secure boot manually. This approach has two large
disadvantages:

- It's not always trivial to do.
- It breaks network booting.

## References

- [Ironic secure boot
  documentation](https://docs.openstack.org/ironic/latest/admin/security.html#uefi-secure-boot-mode)
