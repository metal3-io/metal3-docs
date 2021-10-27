<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Add boot-iso API to BareMetalHost

## Status

implemented

## Summary

Add a new interface so that it is possible to boot arbitrary
iso images via Ironic.

## Motivation

In some circumstances it is desirable to boot an existing iso image
instead of having Ironic boot IPA, for example:

To reduce boot time for ephemeral workloads, it may be possible to boot an iso
and not deploy any image to disk (saving the time to write the image and reboot)

Where an alternative installer exists that is distributed as a live-iso, it
may be desirable to leverage that toolchain instead of the IPA deploy ramdisk,
for example the [fedora-coreos installer](https://docs.fedoraproject.org/en-US/fedora-coreos/bare-metal/)

An [Ironic API](https://docs.openstack.org/ironic/latest/admin/ramdisk-boot.html)
exists that supports this but it's not currently accessible via metal3.

### Goals

Expose the Ironic API to boot iso images via metal3.

### Non-Goals

This only considers the ability to boot an iso image (which Ironic supports
via both redfish-virtualmedia and iPXE), not live kernel/ramdisk images.

Ironic does support booting kernel/ramdisk images though, so the interface
we decide on shouldn't preclude adding that capability in future.

## Proposal

Add a option to the BareMetalHost DiskFormat spec which indicates that instead
of deploying an image to disk, a live-iso image will be booted:

```yaml
  spec:
    image:
      url: http://1.2.3.4/image.iso
      format: live-iso
    online: true
```

Note that in this mode, `rootDeviceHints` and `userData` will not be used
since the image won't be written to disk, and Ironic doesn't
support passing user-data in addition to the iso attachment at present.

At some future point it would be desirable for Ironic to add the ability
to pass userData - then a generic iso could be booted with the ability
to define customization via the userData field in the normal way.

## Design Details

When this mode is selected, we need to configure Ironic to use the [ramdisk
deploy interface](https://docs.openstack.org/ironic/latest/admin/ramdisk-boot.html)
which is not currently enabled in ironic-image.

We will also need to write the provided ISO URL into the
[instance_info boot_iso field](https://docs.openstack.org/ironic/latest/admin/drivers/redfish.html#virtual-media-ramdisk)

### Risks and Mitigations

- Currently there is no detachment API in ironic, so in the case where an installer
  iso is booted, we don't have a way to detach the virtualmedia and will have to
  rely e.g on efibootmgr in whatever iso gets booted to ensure the correct boot device.

- The inspection of a BMH will still rely on booting IPA and there's no support for
  fast-track provisioning in this workflow (since it's booting two different
  iso images) so this adds a reboot into the process.  This can potentially be
  avoided in some cases where we can provide a status annotation on creation of
  the BMH such that inspection is not performed.

- Similarly cleaning of a BMH will rely on IPA, so will require a reboot which may
  not be desirable in some situations.  This can potentially be avoided if cleaning
  is [made configurable](https://github.com/metal3-io/metal3-docs/pull/151) in future.

### Work Items

- Enable ramdisk deploy interface in ironic-image
- Add `live-iso` image format option to the BMH schema
- Update BMO deploy logic to set the `deploy_interface` and `instance_info` appropriately

### Dependencies

There are some Ironic roadmap items which can be considered soft-dependencies,
these don't block the initial implementation but may be desirable to make
this feature more flexible:

[Allow config-drive with virtualmedia ramdisk deploy](https://storyboard.openstack.org/#!/story/2008380)

[Method to detach virtualmedia after initial boot](https://storyboard.openstack.org/#!/story/2008363)

### Test Plan

This should be tested in CI - do we have any metal3 coverage for
redfish-virtualmedia atm?

### Upgrade / Downgrade Strategy

This new format is added to the BMH API as an optional new interface, all existing
BMH interfaces should continue to work as before.

On upgrade this new interface will become available, and once in use it will not
be possible to downgrade, which given the expected use in net-new deployments
is probably reasonable.

## Alternatives

We could avoid exposing this interface and mandate all users rely on IPA to
deploy disk images, but this doesn't provide a good solution for the
emphemeral worload case, and requires testing/supporting two install paths
where a platform (such as FCOS mentioned) provides existing iso based
tooling to deploy to disk.
