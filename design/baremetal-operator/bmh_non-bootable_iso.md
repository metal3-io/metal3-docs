# Add non-bootable iso attach API to BareMetalHost

## Status

Implementable

## Summary

Add a new field in BareMetalHost so that it is possible to attach a generic
non-bootable ISO (a CD "ISO 9660" image) image via Ironic, after the host has been provisioned.

## Motivation

In certain scenarios it is desirable to attach a non-bootable iso image
to a system after provisioning has finished, for example :

A configuration ISO can be used to provide first-boot configuration to a host
deployed from a standard image in advance. An operator may have a pool of
powered off hosts with operating system already provisioned. Then, adding
a host to the cluster boils down to powering it on with a configuration ISO provided.

### Goals

Expose the Ironic API to attach non-bootable iso images via Metal3.

### Non-Goals

Supporting non-ISO images i.e. media types other than CD/DVD, supporting
drivers other than Redfish and its derived drivers.

## Proposal

### BMO Proposal

Add a new optional section in the BareMetalHost spec containing details of the
non-bootable iso image, example :

#### Design spec

```yaml
  spec:
    dataImage:
      url: http://1.2.3.4/image.iso
```

We may consider adding support for HTTP credentials and TLS settings in the future
but it's outside the scope of this proposal.

**Note** : As part of this proposal, the dataImage will be attached after the node
has been Provisioned or ExternallyProvisioned.

### Ironic Support

The [proposal](https://bugs.launchpad.net/ironic/+bug/2033288) for exposing this functionaility in Ironic has been
accepted by the upstream Ironic community.

The [Ironic implementation](https://review.opendev.org/c/openstack/ironic/+/894918) based on the above proposalon has been completed.

Other than that, we just need the implementation for driver specific support,
which in this proposal is Redfish.

## Design Details

Add an optional section `DataImage` to `BareMetalHostSpec`, with sub-field
`Url`.

The ISO will be attached when the `BareMetalHost` object is edited to add
the `DataImage` spec triggering a reconciliation. In case a reboot is requested
at the same time using `RebootAnnotation`, the ISO will be attached first.

The `BareMetalHostStatus` will cache the image details, which will inform
us if the attachment succeeded and will also be used for detachment, either
when the attachment fails and we retry or when the user explicitly requests
detachment by removing the `DataImage` spec from `BareMetalHost` object.

A flag will be used at the webhook level to validate if a given driver supports the
non-bootable ISO feature. Since the support for attaching an ISO as virtual media is
equivalent for both `PreprovisioningISOImage` and `NonBootableISOImage`, we plan to
rename the existing flag for `PreprovisioningISOImage` i.e. `SupportsISOPreprovisioningImage`
to `SupportVirtualMediaISOImage` and use it for both the cases.

### Implementation Details

As part of the design we are assuming that the user will edit the BareMetalHost
to add the dataImage spec, and might also request reboot via rebootAnnotation
or power state change via `online` field.

We want to attach the dataImage first, so handling the attachment/detachment of dataImage
inside the Reconcile function, after reconciling host data and updating hardware details ([code reference](https://github.com/metal3-io/baremetal-operator/blob/1bb45eef449c942711b1c0937ecff2b10a326eb3/controllers/metal3.io/baremetalhost_controller.go#L152) ), makes sense since
any power state change (including reboot via rebootAnnotation) will be handled later on via the stateMachine ( [code reference](https://github.com/metal3-io/baremetal-operator/blob/1bb45eef449c942711b1c0937ecff2b10a326eb3/controllers/metal3.io/baremetalhost_controller.go#L222) ).

We need to cache the attached image in `Status` of the BareMetalHost to know if the
image has been attached. This will also help us determine if a different image is
attached previously which needs to be detached first before attaching the new
dataImage. Or if the user delets the dataImage spec and the `Status` contains a
cached entry, which will again trigger detachment of that image.

In case the image fails to attach, we will retry until either the attachment succeeds
or the user removes the dataImage spec. In case of failure in attachment, we will
always do a detachment before the next retry, and record the reason for failure in the
logs.

## Dependencies

There is a dependency on the implementation(based on the proposal shared
above) on Ironic side to finish for this feature to work. But this doesn't
block the development of the BMO API.

## Upgrade / Downgrade Strategy

This feature is added to the BareMetalHost API as an optional field, so all the
existing BareMetalHost definitions should continue to work as before.

This feature will become available after upgrade, and downgrade is also
possible as long as the corresponding fields are not used.

Explicit microversion negotiation support has been added to Gophercloud ([pr](https://github.com/gophercloud/gophercloud/pull/2791))
which can be used in case we don't want to use the master branch for Ironic.

## Alternatives

We can also achieve this using the existing `BMH.Spec.Image` field, but this
attempts to change the boot order of the system and relies on the host to
fallback to the installed system when booting the image fails.