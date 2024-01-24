# Live ISO

The live-iso API in Metal3 allows booting a BareMetalHost with a live ISO image instead of writing an image to
the local disk using the IPA deploy ramdisk.

Why we need it?

In some circumstances, i.e to reduce boot time for ephemeral workloads, it may be possible to boot an iso
and not deploy any image to disk (saving the time to write the image and reboot). This API is also useful
for integration with 3rd party installers distributed as a CD image, for example leveraging the existing
toolchains like [fedora-coreos installer](https://docs.fedoraproject.org/en-US/fedora-coreos/bare-metal/)
might be desirable.

How to use it?

Here is an example with a BareMetalHost CRD, where iso referenced by the url and `live-iso` set in DiskFormat will be
live-booted without deploying an image to disk. Additionally, live ISO mode is supported with any
virtualmedia driver when used as a BMC driver. Also, checksum options are not required in this case, and will be
ignored if specified:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: live-iso-booted-node
spec:
  image:
    url: http://1.2.3.4/image.iso
    format: live-iso
  online: true
```

**Note**: `rootDeviceHints`, `networkData` and `userData` will not be used
since the image is not written to disk.

For more details, please see the [design proposal](https://github.com/metal3-io/metal3-docs/blob/main/design/baremetal-operator/bmh_live_iso.md).
