<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# implicit-boot-mode

## Status

provisional

## Summary

The required boot mode for a host depends on several factors,
including support in the hardware, whether IPv6 is being used, and
whether virtual media is being used. We do not need to support all
combinations of those features with all boot modes. Asking the user to
give us the boot mode explicitly introduces an opportunity for them to
specify an incorrect value. We have enough information about the host
already to determine the correct boot mode to use. Therefore we should
not need to extend the BareMetalHost API in order to support multiple
boot modes.

## Motivation

When booting using virtual media, Ironic builds a custom ISO for each
host. Today, it only includes the correct contents for one boot mode
at a time. Some attempt is made to determine the right value by
examining the hardware, but that is not always possible. When
necessary, there is a way to configure a default.

Several proposals have been floated to introduce a way for the user to
explicitly set a boot mode. This proposal asserts that we can
successfully manage the x86 hardware supported by metal3 today without
it. Avoiding a new API field avoids several opportunities for
misconfiguration.

### Goals

- Describe a method for providing a deterministic boot mode value to
  Ironic without relying on the user to set the value directly.
- Ensure that metal3's behavior is always deterministic.

### Non-Goals

- Address boot mode selection for non-x86 hardware.

## Proposal

For each host, Ironic maintains a set of properties telling it how to
manage the hardware. One of these is the `boot_mode`. Valid values
are `bios` and `uefi`. When the `boot_mode` property is
explicitly set, Ironic will try to ensure that the hardware is
configured accordingly and it may also choose different paths in the
provisioning process. In particular, there is a branch in the ISO
building logic to include different content based on the boot mode.

If the `boot_mode` is not specified, Ironic tries to determine the
right value by looking at the hardware settings. Some BMC types do not
support this capability, especially when using the IPMI protocol. When
Ironic cannot determine the right value for itself, and has not been
told explicitly what value to use, it falls back to a global default
specified by a configuration option. Metal3 is not typically deployed
in a way that allows that option to be changed easily.

We want to ensure that metal3's behavior is always deterministic and
predictable. We also want to keep the API as minimal as possible, and
to avoid introducing API fields in a way that makes it likely that a
user would either need to tell us something we can figure out or that
they could tell us something incorrect.

Given those goals, it is useful to examine the different situations in
which different boot modes are appropriate, and how to select the
right mode at the right time.

The first approach would be to try to always require the same boot
mode for all hosts. Most modern x86 hosts support UEFI. It is
therefore useful as a default. However, many contributors have
somewhat older hardware, which works better with the BIOS boot
mode. While this hardware is not necessarily our target, it isn't
practical to abandon support entirely by always requiring
UEFI. Similarly, there are reasons we cannot always require a host to
use the BIOS boot mode. UEFI supports desirable features, such as
secure booting, non-x86 hardware, and PXE on IPv6 networks. For these
reasons, a single boot mode will not work.

The desired features do give us some hints about how we can determine
the boot mode implicitly, however. For example, we have no plans to
support virtual media with IPMI. We can also tell whether the
provisioning network is using IPv4 or IPv6. Using this information, we
could build a set of rules to determine the boot mode. However, we
would have to document those rules, and they may not seem obvious to
the end-user.

At least some of the features are tied to the protocol used to
communicate with the BMC. We could therefore link the boot mode to the
BMC driver, and have a deterministic method for choosing the boot mode
that is also easy to document.

The proposal, therefore, is to always use BIOS mode when using IPMI
and to prefer UEFI when using Redfish. We can implement this by adding
a new method to the [AccessDetails
interface](https://github.com/metal3-io/baremetal-operator/blob/master/pkg/bmc/access.go#L27)
to return the properties for a host, including the `boot_mode`. This
API is consistent with other similar methods in that class that return
other sets of data passed to Ironic when a host is registered.

We can be somewhat flexible with the rules by allowing the BMC driver
in metal3 to look at some of the other settings for the host to decide
which boot mode to set. For example, when the driver author knows that
Ironic supports determining the boot mode correctly, it could choose
to skip setting a mode unless the other settings (use of virtual media
or IPv6, for example) require a particular value. This would
complicate the documentation, but may be necessary for some drivers
where trying to have Ironic set the boot mode frequently causes
provisioning failures and it is better to use the host's existing
configuration when possible.

In order to be transparent about what metal3 is doing, we can add a
status field to show the boot mode used. The field's name could be
something like `Status.Provisioning.BootMode`, and it would contain a
string for either `"BIOS"` or `"UEFI"` for now and possibly other
values later for other hardware platforms.

### User Stories

#### As a user, I want to provision a host using virtual media instead of PXE

#### As a user, I want to provision a host that uses an IPMI-based BMC

#### As a user, I want to provision a host using an IPv6 provisioning network

### Risks and Mitigations

## Design Details

- Update the [AccessDetails
  interface](https://github.com/metal3-io/baremetal-operator/blob/master/pkg/bmc/access.go#L27)
  to include the new method, `NodeProperties()`.
- Update each implementation of the interface to include the new
  method with at least a static return value.
- Update the default for Ironic to be UEFI.

### Dependencies

N/A

### Test Plan

- Test provisioning using IPMI
- Test provisioning on an IPv6 network
- Test provisioning using virtual media

### Upgrade / Downgrade Strategy

N/A

### Version Skew Strategy

N/A

## Alternatives

See the [Proposal](#proposal) section above and the reference links below.

## References

- [baremetal-operator PR to add boot mode field](https://github.com/metal3-io/baremetal-operator/pull/437)
- [baremetal-operator PR to support BIOS configuration](https://github.com/metal3-io/baremetal-operator/pull/302)
- [Design proposal that at one point included boot mode with other BIOS settings](https://github.com/metal3-io/metal3-docs/pull/63)
- [Wikipedia article about UEFI](https://en.wikipedia.org/wiki/Unified_Extensible_Firmware_Interface)
