<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# First class support for CoreOS images

## Status

implementable

## Summary

This design proposes adding first class support for CoreOS images and ramdisks,
while retaining all features of the Ironic backend. CoreOS (existing in the
forms of Fedora CoreOS and Red Hat CoreOS) is a Linux distribution specifically
aimed at creating container-based appliances, e.g. deploying Kubernetes.

Note: *CoreOS* in this document implies both Fedora CoreOS and Red Hat CoreOS.
the former will be used in Metal3 by default.

## Motivation

Currently deploying CoreOS is possible both through a normal workflow and by
attaching a CoreOS image as a live ISO and running `coreos-installer` from it.

Compared to the normal Ironic workflow this proposal:

- Gets rid of special ramdisk images, normal CoreOS artifacts are used.
- Simplifies customization of Ironic Python Agent by shipping it as a
  container.
- Enables customization specific to CoreOS Installer.

Compared to the live ISO approach this proposal:

- Does not require disabling inspection and cleaning.
- Allows additional customizations on top of what CoreOS Installer does,
  e.g. a potential fix for the [HPE virtual media
  issue](https://storyboard.openstack.org/#!/story/2008763).

### Goals

- Support Ironic Python Agent images based on CoreOS.
- Support using `coreos-installer` for installation for CoreOS.
- Use unmodified CoreOS images.

Note: CoreOS IPA images will support installing any target images, not only
CoreOS.

### Non-Goals

- Swap out Ironic for anything else.
- Any customizations on top of the MVP.

## Proposal

There are two sub-features in this design proposal that are going to work
together, but can be implemented sequentially:

1. Enable standard Ironic workflow using a CoreOS based ramdisk.
2. Support using `coreos-installer` to install CoreOS.

A proof of concept of both features can be found here:
<https://github.com/dtantsur/ironic-agent-image>.

## Design Details

Since we want to use unmodified CoreOS images (which makes a lot of sense from
the maintainability perspective), we need an alternative way to start Ironic
Python Agent on them. A canonical way to do is to to inject [Ignition
configuration](https://coreos.github.io/ignition/examples/#start-services) that
pulls a container and runs it with podman. [Example configuration
template](https://github.com/dtantsur/ironic-agent-image/blob/main/ignition/ignition.json),
[example service
template](https://github.com/dtantsur/ironic-agent-image/blob/main/ignition/service).

Note: Ignition is a CoreOS analog of cloud-init.

We need to distinguish between two cases:

1. PXE/iPXE booting
2. ISO booting (with virtual media)

CoreOS
[publishes](https://getfedora.org/en/coreos/download?tab=metal_virtualized&stream=stable)
both kinds of artifacts (and more), but the customization pattern is completely
different.

### PXE images

CoreOS publishes 3 artifacts: a kernel, an initramfs and a root filesystem, all
three are required for successful boot. The root filesystem and the Ignition
configuration are specified as URLs via the kernel parameters.

We will place the root filesystem and the generated Ignition configuration into
the shared location where other HTTP artifacts are located. The Ironic's
`pxe_append_params` will be updated with links to them.

### ISO image

We cannot modify kernel parameters on the ISO image without rebuilding it, thus
we will use a different [customization
procedure](https://coreos.github.io/coreos-installer/iso-embed-ignition/). On
the Ironic start-up the downloaded ISO will be customized to include the
generated Ignition configuration, including an Ironic Python Agent
configuration file with the endpoint URLs (Ironic, Inspector, etc).

Note: This is done by the `coreos-installer` command by writing an archive
with the Ignition configuration to a pre-allocated space in the ISO image.

### Enabling

From the operator's perspective, the CoreOS IPA support will be enabled by
setting a new environment variable `IRONIC_USE_COREOS_IPA=true`. By default the
old RDO images will be used (this may change in the future as we gain more
experience with CoreOS).

It will also be possible to use a custom registry for the IPA container. By
default `quay.io/metal3-io/ironic-agent` (to be created) will be used.

### Invoking coreos-installer

The default deployment procedure will work as before: by downloading an image
and writing it to the disk.

CoreOS installer support will be implemented using two new components:

1. [New deploy interface](https://storyboard.openstack.org/#!/story/2008719)
   that relies only on in-band [deploy
   steps](https://docs.openstack.org/ironic/latest/admin/node-deployment.html).
2. [Metal3-specific deploy
   step](https://github.com/dtantsur/ironic-agent-image/blob/main/hardware_manager/ironic_coreos_install.py)
   that will be injected into the IPA container and enabled explicitly via the
   deployment API.

From the user's perspective it will mean setting `Image.DiskFormat` to a new
value `coreos` and leaving `Image.Url` empty.

Note: we may eventually support providing a different CoreOS image via `Url`.

In this case BMO will change the Node's `DeployInterface` to `custom-agent`
and request the new deploy step with this configuration:

```yaml
---
- interface: deploy
  step: install_coreos
  priority: 80
  args:
    ignition:
      ignition:
        version: 3.0.0
      passwd:
        users:
        - name: core
          sshAuthorizedKeys:
          - "SSH key (if requested)"
```

### Risks and Mitigations

- The size of the initial download is quite large: 760 MiB CoreOS + ~360 MiB
  IPA container. This will make inspection take longer, but we'll win some time
  back when deploying, because there is no need to download another root image.

- Downloading the container adds a new potential point of failure.

### Work Items

- Update `ipa-downloader` to optionally download CoreOS images.

- Add support for preparing CoreOS images and related configuration
  to `ironic-image`.

- Update documentation to explain how to start the Ironic pod with CoreOS
  support.

- Update BMO to support requesting `coreos-installer` based installation.

### Dependencies

- Ironic `custom-agent` deploy interface:
  [RFE](https://storyboard.openstack.org/#!/story/2008719).

- We need to land some bug fixes to Ironic - see the patch chain ending with
  <https://review.opendev.org/c/openstack/ironic/+/786037/>.

- Ideally we should finish merging `ironic-inspector-image` and `ironic-image`
  first.

### Test Plan

We should likely create a new CI job that uses a CoreOS ramdisk if the CI
capacity allows that.

### Upgrade / Downgrade Strategy

Disabled by default, no upgrade concerns.

### Version Skew Strategy

N/A

## Drawbacks

- There are already two ways to install CoreOS, although both have downsides.

## Alternatives

- Do nothing, people who need CoreOS should use one of the existing methods.

## References
