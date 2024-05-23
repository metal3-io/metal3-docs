# Ironic Container Images

The currently available ironic container images are:

| Name and link to repository | Published image | Content/Purpose |
| --- | --- | --- |
| [ironic-image](https://github.com/metal3-io/ironic-image) | `quay.io/metal3-io/ironic` | Ironic services / BMC emulators |
| [ironic-ipa-downloader](https://github.com/metal3-io/ironic-ipa-downloader) | `quay.io/metal3-io/ironic-ipa-downloader` | Download and cache the [ironic python agent][ipa] ramdisk |
| [ironic-client](https://github.com/metal3-io/ironic-client) | `quay.io/metal3-io/ironic-client` | Ironic command-line interface (for debugging) |

The main `ironic-image` currently contains entry points to run both Ironic
itself and its auxiliary services: *dnsmasq* and *httpd*.

[ipa]: ironic-python-agent

## How to build a container image

Each repository mentioned in the list contains a Dockerfile that can be
used to build the corresponding container, for example:

```bash
git clone https://github.com/metal3-io/ironic-image.git
cd ironic-image
docker build . -f Dockerfile
```

In some cases a **make** sub-command is provided to build the image using
docker, usually `make docker`.

## Customizing source builds

When building the ironic image, it is also possible to specify a different
source for ironic, ironic-lib or the sushy library using the build arguments
`IRONIC_SOURCE`, `IRONIC_LIB_SOURCE` and `SUSHY_SOURCE`. It is also possible
to apply local patches to the source. See [ironic-image
README](https://github.com/metal3-io/ironic-image/blob/main/README.md) for
details.

## Special resources: sushy-tools and virtualbmc

The Dockerfiles needed to build
[sushy-tools](https://docs.openstack.org/sushy-tools/latest/) (Redfish
emulator) and [VirtualBMC](https://docs.openstack.org/virtualbmc/latest/) (IPMI
emulator) containers can be found in the `ironic-image` container repository,
under the `resources` directory.
