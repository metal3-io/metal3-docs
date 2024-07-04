# Root Device Hints

Bare-metal machines often have more than one block device, and in many cases
a user will want to specify, which of them to use as the root device. *Root
device hints* allow selecting one device or a group of devices to choose from.
You can provide the hints via the `spec.rootDeviceHints` field on your
`BareMetalHost`:

```yaml
spec:
  # ...
  rootDeviceHints:
    wwn: "0x55cd2e415652abcd"
```

**Hint:** root device hints in Metal3 are closely modeled on the Ironic's [root
device hints][ironic-hints], but there are important differences in available
hints and the comparison operators they use.

**Warning:** the default root device depends on the hardware profile as
explained below. Currently, `/dev/sda` path is used when no hints are
specified. This value is not going to work for NVMe storage. Furthermore, Linux
does not guarantee the block device names to be consistent across reboots.

[ironic-hints]: https://docs.openstack.org/ironic/latest/install/advanced.html#specifying-the-disk-for-deployment-root-device-hints

## RootDeviceHints format

One or more hints can be provided, the chosen device will need to match all of
them. Available hints are:

- ``deviceName`` -- A string containing a canonical Linux device path like
  `/dev/vda` or a *by-path* alias like `/dev/disk/by-path/pci-0000:04:00.0`.

  **Warning:** as mentioned above, block device names are not guaranteed to be
  consistent across reboots. If possible, choose a more reliable hint, such as
  `wwn` or `serialNumber`.

  **Hint:** only *by-path* aliases are supported, other aliases, such as
  *by-id* or *by-uuid*, cannot currently be used.

- `hctl` -- A string containing a SCSI bus address like `0:0:0:0`.

- `model` -- A string containing a vendor-specific device
  identifier. The hint can be a substring of the actual value.

- `vendor` -- A string containing the name of the vendor or
  manufacturer of the device. The hint can be a substring of the
  actual value.

- `serialNumber` -- A string containing the device serial number.

- `minSizeGigabytes` -- An integer representing the minimum size of the
  device in Gigabytes.

- `wwn` -- A string containing the unique storage identifier.

- `wwnWithExtension` -- A string containing the unique storage
  identifier with the vendor extension appended.

- `wwnVendorExtension` -- A string containing the unique vendor
  storage indentifier.

- `rotational` -- A boolean indicating whether the device must be
  a rotating disk (`true`) or not (`false`). Examples of non-rotational devices
  include SSD and NVMe storage.

## Finding the right hint value

Since the root device hints are only required for provisioning, you can use the
results of inspection to get an overview of available storage devices:

```bash
kubectl get hardwaredata/<BMHNAME> -n <NAMESPACE> -o jsonpath='{.spec.hardware.storage}' | jq .
```

This commands produces a JSON output, where you can find all necessary fields
to populate the root device hints before provisioning. For example, on a
virtual testing environment:

```json
[
  {
    "alternateNames": [
      "/dev/sda",
      "/dev/disk/by-path/pci-0000:03:00.0-scsi-0:0:0:0"
    ],
    "hctl": "0:0:0:0",
    "model": "QEMU HARDDISK",
    "name": "/dev/disk/by-path/pci-0000:03:00.0-scsi-0:0:0:0",
    "rotational": true,
    "serialNumber": "drive-scsi0-0-0-0",
    "sizeBytes": 32212254720,
    "type": "HDD",
    "vendor": "QEMU"
  }
]
```

## Interaction with hardware profiles

*Hardware profiles* are a deprecated concept that was introduced to describe
homogenous types of hardware. The default hardware profile is `unknown`, which
implies using `/dev/sda` as the root device.

In a future version of BareMetalHost API, the hardware profile concept will be
disabled, and Metal3 will default to having no root device hints by default. In
this case, the default logic in Ironic will apply: the smaller block device
that is at least 4 GiB. If you want this logic to apply in the current verson
of the API, use the `empty` profile:

```yaml
spec:
  # ...
  hardwareProfile: empty
```

In all other cases, use explicit root device hints.
