# Ironic Container Images

The currently available ironic container images are listed below.

| Name and link to repository | Content/Purpose |
| --- | --- |
| [ironic-image](https://github.com/metal3-io/ironic-image) | Ironic api and conductor / Ironic Inspector / Sushy tools / virtualbmc |
| [ironic-ipa-downloader](https://github.com/metal3-io/ironic-ipa-downloader) | Distribute the ironic python agent ramdisk |
| [ironic-hardware-inventory-recorder-image](https://github.com/metal3-io/ironic-hardware-inventory-recorder-image) | Ironic python agent hardware collector daemon |
| [ironic-static-ip-manager](https://github.com/metal3-io/static-ip-manager-image) | Set and maintain IP for provisioning pod |
| [ironic-client](https://github.com/metal3-io/ironic-client) | Ironic CLI utilities |

## How to build a container image

Each repository mentioned in the list contains a Dockerfile that can be
used to build the relative container.
The build process is as easy as using the docker or podman command and
point to the Dockerfile, for example in case of the ironic-image:

```bash
git clone https://github.com/metal3-io/ironic-image.git
cd ironic-image
docker build . -f Dockerfile
```

In some cases a **make** sub-command is provided to build the image using
docker, usually **make docker**

## Build ironic-image from source

The standard build command builds the container using RPMs taken from the RDO
project, although an alternative build option has been provided for the
ironic-image container to use source code instead.

Setting the argument **INSTALL_TYPE** to **source** in the build cli command
triggers the build from source code:

```bash
docker build . -f Dockerfile --build-arg INSTALL_TYPE=source
```

## Work with patches in the ironic-image

The ironic-image allows testing patches for ironic projects building the
container image directly including any patch using the **patch-image.sh**
script at build time.
To use the script we need to specify a text file containing the list of
patches to be applied as the value of the build argument **PATCH_LIST**,
for example:

```bash
docker build . -f Dockerfile --build-arg PATCH_LIST=patch-list.txt
```

At the moment, only patches coming from opendev.org gerrit are accepted.
Include one patch per line in the PATCH_LIST file with the format:

project refspec

where:

- **project** is the last part of the project url including the org, for example openstack/ironic
- **refspec** is the gerrit refspec of the patch we want to test, for example refs/changes/67/759567/1

## Special resources: sushy-tools and virtualbmc

In the ironic-image container repository, under the resources directory,
we find the Dockerfiles needed to build sushy-tools and virtualbmc containers.

They can both be built exactly like the other containers using the
**docker build** command.
