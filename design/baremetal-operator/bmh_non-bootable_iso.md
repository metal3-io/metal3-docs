# Add non-bootable iso attach API to BareMetalHost

## Status

Implementable

## Summary

Add a new Custom Resource(CR), `DataImage`, to the cluster which will make it possible,
using ownerReferences (example : [HostFirmwareSettings](https://github.com/metal3-io/baremetal-operator/blob/9ce684e6462a6ab55ff650cb6c11f9ba1ffb395d/docs/api.md?plain=1#L664)) and same `Name` and `Namespace` as the `BareMetalHost`, to attach a generic non-bootable ISO (a CD "ISO 9660" image) image via Ironic, after the host has been provisioned.

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

Add a new Custom Resource(CR), `DataImage` (with same `name` and `namespace` as the BMH), which contains the spec containing details of the
non-bootable iso image, example :

#### Design spec

```yaml
apiVersion: metal3.io/v1alpha1
kind: DataImage
metadata:
  name: metal-worker-0
  namespace: metal-cluster
spec:
  dataImage:
    url: http://1.2.3.4/image.iso
```

We will use ownerReferences in the `DataImage` CR to link it to the corresponding `BareMetalHost` object.

Since we are using a CR, a user can create RBAC policies that doesn't allow unauthorized users
to attach a non-bootable iso image to hosts.

We may consider adding support for HTTP credentials and TLS settings in the future
but it's outside the scope of this proposal.

**Note** : As part of this proposal, the dataImage will be attached after the node
has been Provisioned or ExternallyProvisioned.

### Ironic Support

The [proposal](https://bugs.launchpad.net/ironic/+bug/2033288) for exposing this functionaility in Ironic has been
accepted by the upstream Ironic community.

The [Ironic implementation](https://review.opendev.org/c/openstack/ironic/+/894918) based on the above proposal has been completed.

Other than that, we just need the implementation for driver specific support,
which in this proposal is Redfish.

## Design Details

Create a new Custom Resource(CR), `DataImage`, with spec field `Url` and same `Name`
and `Namespace` as the `BareMetalHost` where we are attaching the image.

The ISO will be attached when the `DataImage` CR object is created and the
corresponding ownerReference is added for the `BareMetalHost` object,  which will trigger a
reconciliation. In case a reboot is requested at the same time using
`RebootAnnotation`, the ISO will be attached first.

The `BareMetalHostStatus` will cache the image details including the attachment
status, which will inform us if the attachment succeeded and can also be used
for detachment - either when the attachment fails and we retry or when the user
explicitly requests detachment by deleting the `DataImage` CRD that corresponds to a BMH.

We will introduce a new flag, `NonBootableISOImage`, at the webhook level to validate if a given driver supports the
non-bootable ISO feature.

### Implementation Details

As part of the design we are assuming that to attach an image to a BMH object, the user
will create the corresponding `DataImage` CR (with the same `Name` and `Namespace` as the
`BareMetalHost` object) with `OwnerReference` to the BMH object.
At the same time and independently, the user might also request a reboot via rebootAnnotation
or power state change via `online` field.

In such scenarios, we want to attach the dataImage first(before the reboot), so handling the
attachment/detachment of dataImage when the host reaches steady state (refer [`actionManageSteadyState` function](https://github.com/metal3-io/baremetal-operator/blob/9ce684e6462a6ab55ff650cb6c11f9ba1ffb395d/controllers/metal3.io/baremetalhost_controller.go#L1414) )
makes sense since we only reach this state when a host has been either provisioned or externallyProvisioned, and also
any power state change (including reboot via rebootAnnotation) are also handled after the host reaches this state
( refer [`manageHostPower` function](https://github.com/metal3-io/baremetal-operator/blob/1bb45eef449c942711b1c0937ecff2b10a326eb3/controllers/metal3.io/baremetalhost_controller.go#L222) )

We need to cache the attached image along with the attachment status in `Status`
of the BareMetalHost to know if the image has been attached successfully. This
will also help us determine if a different image was attached previously which
needs to be detached first before attaching the new dataImage. Or, if the user
deletes the dataImage CR and the `Status` contains a cached entry, which will
again trigger detachment of that image.

In case the image fails to attach, we will retry until either the attachment succeeds
or the user removes the dataImage CR. In case of failure in attachment, we will
always do a detachment before the next retry, and record the reason for failure in the
logs.

## Dependencies

There is a dependency on the implementation(based on the proposal shared
above) on Ironic side to finish for this feature to work. But this doesn't
block the development of the BMO API.

## Upgrade / Downgrade Strategy

This feature is adds a Custom Resource(CR) to the cluster and a label to `BareMetalHost`
which doesn't makes any changes to the BareMetalHost API, so all the existing
`BareMetalHost` definitions should continue to work as before.

This feature will become available after upgrade, and downgrade is also pretty
straightforward where the user just need to remove the `DataImage` CRs.

Explicit microversion negotiation support has been added to Gophercloud ([pr](https://github.com/gophercloud/gophercloud/pull/2791))
which can be used in case we don't want to use the master branch for Ironic.

## Alternatives

We can also achieve this using the existing `BMH.Spec.Image` field, but this
attempts to change the boot order of the system and relies on the host to
fallback to the installed system when booting the image fails.