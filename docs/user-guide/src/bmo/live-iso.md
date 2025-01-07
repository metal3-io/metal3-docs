# Live ISO

The live-iso API in Metal3 allows booting a BareMetalHost with an ISO image
instead of writing an image to the local disk using the IPA deploy ramdisk.

This feature has two primary use cases:

- Running ephemeral load on hosts (e.g. calculations or simulations that do not
  store local data).
- Integrating a 3rd party installer (e.g. [coreos
  installer](https://docs.fedoraproject.org/en-US/fedora-coreos/bare-metal/)).

**Warning:** this feature is designed to work with virtual media (see
[supported hardware](./supported_hardware.md). While it's possible to boot an
ISO over iPXE, the booted OS will not be able to access any data on the ISO
except for the kernel and initramfs it booted from.

To boot a live ISO, you need to set the image URL to the location of the ISO
and set the `format` field to `live-iso`, for example:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: live-iso-booted-node
spec:
  bootMACAddress: 80:c1:6e:7a:e8:10
  bmc:
    address: redfish-virtualmedia://192.168.111.1:8000/redfish/v1/Systems/1
    credentialsName: live-iso-booted-node-secret
  image:
    url: http://1.2.3.4/image.iso
    format: live-iso
  online: true
```

**Note**: `image.checksum`, `rootDeviceHints`, `networkData` and `userData`
will not be used since the image is not written to disk.

For more details, please see the [design proposal](https://github.com/metal3-io/metal3-docs/blob/main/design/baremetal-operator/bmh_live_iso.md).
