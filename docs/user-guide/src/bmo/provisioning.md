# Provisioning and Deprovisioning

<!-- cSpell:ignore fips -->

The most fundamental feature of Metal3 Bare Metal Operator is provisioning of
bare-metal machines with a user-provided image. This document explains how to
provision machines using the `BareMetalHost` API directly. Users of the Cluster
API should consult the [CAPM3 documentation](../capm3/introduction.md) instead.

## Provisioning

A freshly enrolled host gets provisioned when the two conditions are met:

- the state is `available` (see [state machine](./state_machine.md)),
- either its `image` field or its `customDeploy` field is not empty.

**NOTE:** `customDeploy` is an advanced feature that is not covered in this
document.

To start the provisioning process, you need at least two bits of information:

1. the URL of the image you want to put on the target host,
1. the value or the URL of the image checksum using either SHA256 or SHA512
   (MD5 is supported but deprecated and not compatible with FIPS 140 mode).

The minimum example looks like this:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: host-0
  namespace: my-cluster
spec:
  online: true
  bootMACAddress: 80:c1:6e:7a:e8:10
  bmc:
    address: ipmi://192.168.1.13
    credentialsName: host-0-bmc
  image:
    checksum: http://192.168.0.150/SHA256SUMS
    url: http://192.168.0.150/jammy-server-cloudimg-amd64.img
    checksumType: auto
```

In most real cases, you will also want to provide

1. first-boot configuration as described in [instance
   customization](./instance_customization.md),
1. [hints to choose the target root device](./root_device_hints.md),
1. the format of the image you use.

As a result, a more complete example will look like this:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: host-0
  namespace: my-cluster
spec:
  online: true
  bootMACAddress: 80:c1:6e:7a:e8:10
  bmc:
    address: ipmi://192.168.1.13
    credentialsName: host-0-bmc
  image:
    checksum: http://192.168.0.150/SHA256SUMS
    url: http://192.168.0.150/jammy-server-cloudimg-amd64.img
    checksumType: auto
    format: raw
  rootDeviceHints:
    wwn: "0x55cd2e415652abcd"
  userData:
    name: host-0-userdata
```

When the provisioning state of the host becomes `provisioned`, your instance is
ready to use. Note, however, that booting the operating system and applying the
first boot scripts will take a few more minutes after that.

### Note on images

Two image formats are commonly used with Metal3: QEMU's
[qcow2](https://en.wikipedia.org/wiki/Qcow) and raw disk images. Both formats
have their upsides and downsides:

- Qcow images are usually smaller and thus require less network bandwidth to
  transfer, especially if you provision many machines with different images at
  the same time.

- Raw images can be streamed directly from the remote location to the target
  block device without any conversion. However, they can be very large.

When the format is omitted, Ironic will download the image into the local cache
and inspect its format. If you want to use the streaming feature, you need to
provide the `raw` format explicitly. If you want to forcibly cache the image
(for example, because the remote image server is not accessible from the
machine being provisioned), omit the format or use `qcow2` images.

**HINT:** cloud-init is capable of [growing the last
partition](https://cloudinit.readthedocs.io/en/latest/reference/modules.html#growpart)
to occupy the remaining free space. Use this feature instead of creating very
large raw images with a lot of empty space.

**NOTE:** the special format value `live-iso` triggers a [live ISO
provisioning](./live-iso.md) that works differently from a normal one.

### Notes on checksums

Starting from BMO v0.10.0, leaving `checksumType` empty prompts Ironic to
automatically detect the checksum type based on its length. In earlier versions,
this behavior can be achieved by setting `checksumType` to `auto`.

The `checksum` value can be provided either as a URL or as the hash value
directly. Providing a URL is more convenient in case of public cloud images,
but it provides a weaker defense against man-in-the-middle attacks.

## Deprovisioning

To remove an instance from the host and make it available for new deployments,
remove the `image`, `userData`, `networkData`, `metaData` and `customDeploy`
fields (if present). Depending on the host configuration, it will either start
the [automated cleaning](./automated_cleaning.md) process or will become
`available` right away.

## Reprovisioning

If you want to apply a new image or new user or network data to the host, you
need to deprovision and provision it again. This can be done in two ways:

- If the URL of the image changes, the re-provisioning process will start
  automatically. Make sure to update the user and network data in
  the same or earlier edit operation.

- If the URL of the image is the same, you need to remove the `image` field,
  then add it back once the state of the `BareMetalHost` changes to
  `deprovisioning`.

**WARNING:** updating the `userData` and `networkData` fields alone does not
trigger a new provisioning.
