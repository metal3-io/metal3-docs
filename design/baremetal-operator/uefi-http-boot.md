# Add UEFI HTTP boot hardware driver

## Status

Implementable

## Summary

This design proposes to add a new hardware driver `redfish-uefihttp` to
support the UEFI HTTP boot interface using the Redfish API.

## Motivation

HTTP boot is available since at least 9 years, it was standardized in UEFI
version 2.5, and it's considered as a natural valid replacement for
PXE boot.
It addresses PXE issues for security, relying on HTTPs and using a
reliable TCP connection, and scalability and performance, for example with
the possibility of using HTTP load balancers.
In general HTTP boot grants a faster, more reliable and more secure way to
obtain operating system images and EFI executables during a network boot
process.
It is also compatible with UEFI Secure Boot, which is quite hard to impossible
to implement using standard PXE boot method.

### Goals

Support UEFI HTTP boot interface using Redfish API to boot from an ISO images.

### Non-Goals

- HTTP boot is a UEFI only feature, so support for Legacy (BIOS) can't and
won't be taken into consideration.
- Any non-Redfish support for HTTP boot.
- This implementation covers only booting from an ISO image, it won't take
into consideration booting using kernel plus ramdisk.
- Despite HTTP boot being a valid replacement and an improvement on PXE
boot methods, this change does not aim to replace, change, deprecate, or
remove the current PXE boot methods in use.

## Proposal

Add a new hardware driver called `redfish-uefihttp`, similar to
`redfish-virtualmedia`, to the Baremetal Operator.
The new hardware driver supports UEFI HTTP boot using the ironic
`redfish-https` boot interface.

## Design Details

Using exclusively Redfish API, the accepted value of `Firmware Interface` and
`RAIDInterface` for the `redfish-uefihttp` hardware driver will be `redfish`.
Secure Boot will also be supported.

When the `redfish-uefihttp` hardware driver is used we need to configure the
`redfish-https` boot interface in ironic, which is currently not enabled
in ironic-image.

### Implementation Details/Notes/Constraints

It should be enough to add the new `redfish-uefihttp` hardware driver to
BMO to support the UEFI HTTP boot feature.
As for the `redfish-virtualmedia` driver, the new `redfish-uefihttp` relies
on network boot from an ISO image that is composed by Ironic, but unlike
Virtual Media boot, it requires a Provisioning Network to be configured.
This is because the UEFI HTTP boot is essentially "secured PXE" designed
to overcome limitations of the traditional PXE boot method, and it requires
functional DNS, DHCP and HTTP servers to be configured.
The ISO image is provided by the HTTP server and the host boots from it
exactly like it used to boot from a standard ramdisk during PXE booting.

### Risks and Mitigations

The UEFI HTTP boot provides a high level of security for a network boot
process, relying on secure communication between BMC and HTTP server to
transfer all the files and images needed to boot the host.

### Work Items

- Add a new hardware driver called `redfish-uefihttp` to BMO.
- Add `redfish-https` to supported boot interfaces to the ironic-image.
- Update metal3 documentation with details on the new hardware driver and
how to use it.

### Dependencies

Ironic implementation of the `redfish-https` boot interface [has been
already completed](https://review.opendev.org/c/openstack/ironic/+/900964).

### Test Plan

The new hardware driver can currently be tested only on supported hardware
as the Redfish support must be enabled and supported by the BMC.
Although the support for UEFI HTTP boot has been added to sushy-tools, so
the current BMO e2e tests set can be expanded to cover this scenario.

Unit tests will be implemented as usual.

### Upgrade / Downgrade Strategy

The new hardware driver will be available after upgrading the version
of Baremetal Operator.

### Version Skew Strategy

None

## Drawbacks

Adding one more hardware driver with a different boot interface complicates
the decision process to decide which boot interface to use, in particular in
this case between `redfish-virtualmedia` and `redfish-uefihttp` since they both
rely on network booting from an ISO image.
In general, the main difference is that the UEFI HTTP boot supports Secure
Boot, while virtual media does not, but on the other hand, the UEFI HTTP boot
requires a DHCP server to be present on the network in order to handle
the boot media discovery and IP address management.

## Alternatives

The users will keep using other hardware drivers already implemented in
Baremetal Operator API.
The existing interfaces do not cover some important cases and have some
limitations, such as:

- iPXE does not support Secure Boot.
- To rely on Virtual Media boot, it is necessary to grant access to the
Control Plane from the BMC.

## References

[UEFI 2.5 release notes](https://uefi.org/sites/default/files/resources/UEFI%202_5.pdf)
[Ironic HTTP Boot](https://docs.openstack.org/ironic/latest/admin/interfaces/boot.html#http-boot)
