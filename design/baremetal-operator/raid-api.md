# raid-api

## Status

implemented

## Summary

This design describes changes needed to allow RAID storage
configuration as part of provisioning hosts.

## Motivation

While it is reasonable to assume that cloud instances and VMs only
need one drive with minimal configuration, many classes of server
hardware need to have RAID storage configured to present fast and
reliable storage to the OS. While it is possible today to
pre-configure the hosts, it would be more convenient for users if
metal3 could do that work for them.

### Goals

1. Provide an API to specify the RAID storage configuration to use
   when provisioning a host.
1. Outline the controller/provisioner logic changes needed to pass the
   instructions to Ironic to have the storage configured.
1. Support basic RAID levels `0`, `1`, and `1+0`.

### Non-Goals

1. Provide default RAID configuration.
1. Retain existing RAID configuration on a host if it matches the
   desired configuration at the time of provisioning (we make no
   assumptions about preserving the state of the storage system or its
   contents).
1. Re-provision a host if the RAID settings change. (Users are
   expected to explicitly deprovision the host and then reprovision
   it.)
1. Support every possible RAID configuration.

## Proposal

### User Stories

1. As a user, I can specify the RAID configuration for a host before
   provisioning it.
1. As a user, I can choose between hardware and software RAID for each
   host.

## Design Details

### API Changes

The `BareMetalHost` API will change to accept RAID configuration
inputs and to reflect the settings that were used when a host is
provisioned (in case they are changed after provisioning).

New `spec` fields will be added in a section called `raid`, with
separate fields describing the hardware and software RAID settings. If
the hardware settings are provided, the software settings are ignored.

For hardware RAID, the inputs describe how to combine physical disks
into a RAID volume via the RAID controller hardware in the host.

```yaml
spec:
  raid:
    hardwareVolumes:
    - sizeGibibytes: 1000
      level: 1
      name: volume-name
      rotational: true
      numberOfPhysicalDisks: 2
```

- The RAID level for a volume is required and should be expressed as
  one of `"1"`, `"0"`, or `"1+0"`.
- The size for a volume is optional and should be expressed in
  gibibytes.
- The number of disks to use for the volume defaults to a minimum
  value based on the RAID level.

For software RAID, the inputs describe how to configure the operating
system to see physical disks in a RAID configuration through software
drivers, without using any special hardware.

```yaml
spec:
  raid:
    softwareVolumes:
    - sizeGibibytes: 1000
      level: 1
      physicalDisks:
      - deviceName: /dev/sda
      - deviceName: /dev/sdb
```

- The RAID level for a volume is required and should be expressed as
  one of `"1"`, `"0"`, or `"1+0"`.
- The size for a volume is optional and should be expressed in
  gibibytes.
- The disks to use are specified using the same syntax as the
  `rootDeviceHints`.

Software RAID is constrained in other ways:

- There must be 0, 1, or 2 software RAID devices.
- The first software RAID volume must use RAID level 1 because
  otherwise GRUB will need to understand how to assemble the `mdraid`
  device to be able to boot anything. RAID-1 is safe in this regard
  because any mirror looks just like a normal disk.
- The second software RAID volume may use RAID level `0`, `1`, or
  `1+0`.

Regardless of the type of RAID used, the first volume defined is used
as the root volume by default. If the host also has `rootDeviceHints`
configured, those hints override this behavior, and the RAID devices
are not flagged as the root volume.

The status fields of the `BareMetalHost` expand to include the RAID
configuration used for the most recent provisioning operation.

```yaml
status:
  provisioning:
    raid:
      hardwareVolumes: ...
      softwareVolumes: ...
```

### Controller Changes

Ironic applies RAID configuration during a cleaning phase, separate
from the provisioning phase. In order for the metal3 controller to
track this new phase, a new "preparing" state is introduced to the
metal3 state machine, between "ready" and "provisioning". The
controller and provisioner need to handle the new state.

### Implementation Details/Notes/Constraints

If the RAID instructions do not meet the validation criteria given
above, the host is not provisioned and Ironic is not given any
cleaning or provisioning instructions. The error is reported through
the host status, and reconciliation stops until the settings are
modified again.

Valid RAID settings are stored in the status fields when provisioning
starts, and only those values are used by the provisioner to ensure
that if the spec fields are updated after provisioning has started
Ironic is not given conflicting instructions. This is similar to how
the root device hints are managed.

### Risks and Mitigations

Reconfiguring the RAID controller can lead to unexpected data loss, so
during provisioning the existing configuration is only erased when
explicit settings are given via the API. To manually configure a host,
the user can pre-configure it and not provide RAID instructions to
metal3.

Leaving the storage of a host configured after it is deprovisioned can
result in data exposure, so the host's RAID configuration is always
erased during deprovisioning.

Not all hosts support hardware RAID configuration. Software RAID is
available as an option, and if hardware RAID setup fails the host will
report an error message and fail to provision.

### Work Items

See [the implementation](https://github.com/metal3-io/baremetal-operator/pull/292).

### Dependencies

None

### Test Plan

- Unit tests for determining the instructions to pass to Ironic.

### Upgrade / Downgrade Strategy

Older versions of the baremetal-operator will ignore the RAID fields.

### Version Skew Strategy

None

## Drawbacks

None

## Alternatives

We could rely on the user to pre-configure the host's RAID setup, but
that would move a lot of burden to the user that we could eliminate by
taking advantage of the existing Ironic feature.

## References

- [original issue](https://github.com/metal3-io/baremetal-operator/issues/206)
- [implementation](https://github.com/metal3-io/baremetal-operator/pull/292)
