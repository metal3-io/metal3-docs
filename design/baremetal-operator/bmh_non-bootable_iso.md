# Add non-bootable iso attach API to BareMetalHost

## Status

Implementable

## Summary

Add a new field in BareMetalHost so that it is possible to attach a generic
non-bootable iso image via Ironic, after the host has been provisioned.

## Motivation

In certain scenarios it is desirable to attach a non-bootable iso image
to a system after provisioning has finished, for example :

As a config data disk to do some post provisioning configuration for the
system.

For troubleshooting of the node.

### Goals

Expose the Ironic API to attach non-bootable iso images via Metal3.

## Proposal

### BMO Proposal

Add a new optional section in the BareMetalHost spec containing details of the
non-bootable iso image, example :

```yaml
  spec:
    dataImage:
      url: http://1.2.3.4/image.iso
      username: metal
      password: password
      insecure: false
```

Note that in this case, the iso image will be attached after the node
has been provisioned or ExternallyProvisioned.

### Ironic Proposal

The [proposal](https://bugs.launchpad.net/ironic/+bug/2033288) for exposing this functionaility in Ironic has been
accepted by the upstream Ironic community.

## Design Details

Add an optional section `DataImage` to `BareMetalHostSpec`, with sub-fields
`Url`, `Username`, `Password`, `Insecure`.

## Dependencies

There is a dependency on the implementation(based on the proposal shared
above) on Ironic side to finish for this feature to work. But this doesn't
block the development of the BMO API.

## Upgrade / Downgrade Strategy

This feature is added to the BareMetalHost API as an optional field, so all the
existing BareMetalHost definitions should continue to work as before.

This feature will become available after upgrade, and downgrade is also
possible as long as the corresponding fields are not used.

## Alternatives

We can also achieve this using the existing `BMH.Spec.Image` field, but this
attempts to change the boot order of the system and relies on the host to
fallback to the installed system when booting the image fails.