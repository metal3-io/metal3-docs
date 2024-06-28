# RAID setup

[RAID](https://en.wikipedia.org/wiki/RAID) is a technology that allows creating
volumes with certain properties out of two or more physical disks. Depending on
the [RAID level](https://en.wikipedia.org/wiki/Standard_RAID_levels), you may
be able to merge several disks into a larger one or achieve redundancy.

Metal3 supports two RAID implementation:

- *Hardware RAID* is implemented by hardware itself and can be configured
  through the machine's BMC.
- *Software RAID* is implemented by the Linux kernel and can be configured
  using the standard `mdadm` tool.

To create or delete RAID volumes, you need to edit the `spec.raid` field of the
`BareMetalHost` resource, changing either the `hardwareRAIDVolumes` or the
`softwareRAIDVolumes` array. If the host is in the `available` state, it will
be moved to the `preparing` state and the new settings will be applied. After
some time, the host will move back to `available`, and the resulting changes
will be reflected in its `status.raid` field.

**Note:** RAID setup requires 1-2 reboots of the machine and thus may take 5-20
minutes.

**Warning:** never try to configure both hardware and software RAID at the same
time on the same host. While theoretically possible, this mode makes little
sense and is not supported well by the underlying Ironic service.

## Hardware RAID

*Hardware RAID* is a type of RAID that is configured by a special component of
the bare-metal machine - *RAID controller*. The resulting RAID volumes are
normally presented transparently to the operating system and can be used as
normal disks.

Not all hardware models and Metal3 drivers support RAID: check [supported
hardware](supported_hardware.md) for details.

### Automatic allocation

One approach is to define the required level, disk count and volume size,
letting Ironic to automatically select the disks to place RAID on, for example:

```yaml
spec:
  raid:
    hardwareRAIDVolumes:
    - name: volume1
      level: "5"
      numberOfPhysicalDisks: 3
      sizeGibibytes: 350
```

The most common RAID levels are `0`, `1`, `5` and `1+0`. Levels `2`, `6`,
`5+0` and `6+0` are also supported by Metal3 but may not be supported by all
hardware models. The level dictates the minimum number of physical disks and
the maximum size of a RAID volume.

**Note:** because of values like `1+0`, RAID level is a string, not a number.

You can use the boolean `rotational` field to limit the types of physical
disks:

- `true` to use only rotational disks (traditional spinning hard drives)
- `false` to use non-rotational storage (flash-based: SSD, NVMe)
- any types are used by default

### Manual allocation

Alternatively, you can provide the controller and a list of disk identifiers.
Note that these are internal disk identifiers as reported by the BMC, not
standard Linux names like `/dev/sda`. For example, on a Dell machine:

```yaml
spec:
  raid:
    hardwareRAIDVolumes:
    - name: volume2
      level: "0"
      controller: RAID.Integrated.1-1
      physicalDisks:
      - Disk.Bay.5:Enclosure.Internal.0-1:RAID.Integrated.1-1
      - Disk.Bay.6:Enclosure.Internal.0-1:RAID.Integrated.1-1
      - Disk.Bay.7:Enclosure.Internal.0-1:RAID.Integrated.1-1
```

If you do not specify the size of the volume, the maximum possible size will be
used (depending on size of the physical disks).

### Removing RAID

To remove the RAID configuration, set `hardwareRAIDVolumes` to an empty list:

```yaml
spec:
  raid:
    hardwareRAIDVolumes: []
```

**Warning:** there is a crucial difference between setting
`hardwareRAIDVolumes` to an empty list and removing the `raid` field
completely: the former will remove any existing volumes, the latter will not
touch any existing RAID configuration.

## Software RAID

**Warning:** software RAID support is experimental. Please report any issues
you encounter.

*Software RAID* is configured by the `mdadm` utility from within the
[IPA](../ironic/ironic-python-agent.md) ramdisk, which will be automatically
booted by Ironic when the host moves to the `preparing` state.

A subset of the hardware RAID API is provided for software RAID volumes with
the following limitations:

- The only supported levels are `0`, `1` and `1+0`.
- Only one or two RAID volumes can be created on a host.
- The first volume **must** have level `1` and should be used as the root
  device.
- It is not possible to specify the number of physical disks.
- The backing physical disks must not have any data or partitions on them.
- Your instance image must have Linux software RAID support, including the
  `mdadm` utility. Other operating systems may not work at all.

Check the [Ironic software RAID
guide](https://docs.openstack.org/ironic/latest/admin/raid.html#software-raid)
for more implementation details.

### Software RAID: automatic allocation

You can specify the sizes and the levels of the volume(s) and let Ironic do the
rest. You can also omit the size of the last volume:

```yaml
spec:
  raid:
    softwareRAIDVolumes:
    - level: "1"
      sizeGibibytes: 10
    - level: "0"
```

**Note:** the same physical disks will be used for both volumes. Each physical
disk will have partitions corresponding to each of the volumes.

### Software RAID: manual allocation

You can specify the backing physical disks using the same format as the
`rootDeviceHints` field of the `BareMetalHost` resource, for example:

```yaml
spec:
  raid:
    softwareRAIDVolumes:
    - level: "1"
      physicalDisks:
      - serialNumber: abcd
      - serialNumber: efgh
```

### Removing software RAID

To remove the RAID configuration, set `softwareRAIDVolumes` to an empty list:

```yaml
spec:
  raid:
    softwareRAIDVolumes: []
```

**Warning:** even when [automated cleaning](automated_cleaning.md) is enabled,
software RAID is not automatically removed on deprovisioning.
