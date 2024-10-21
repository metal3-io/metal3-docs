# Add non-bootable iso attach API to BareMetalHost

## Status

Implementable

## Summary

Add a new Custom Resource(CR), `DataImage`, to the cluster to attach a
generic non-bootable ISO (a CD "ISO 9660" image) image to a provisioned
or externallyProvisioned BMH using Ironic.

## Motivation

In certain scenarios it is desirable to attach a non-bootable iso image
to a system after provisioning has finished, for example:

A configuration ISO can be used to provide first-boot configuration to a host
deployed from a standard image in advance. An operator may have a pool of
powered off hosts with operating system already provisioned. Then, adding
a host to the cluster boils down to powering it on with a configuration ISO provided.

### Goals

Expose the Ironic API to attach non-bootable iso images via Metal3.

### Non-Goals

* Supporting non-ISO images i.e. media types other than CD/DVD
* Supporting drivers other than Redfish and its derived drivers.

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
  url: http://1.2.3.4/image.iso
```

We will use ownerReferences in the `DataImage` CR to link it to the corresponding `BareMetalHost` object.

Since we are using a CR, a user can create RBAC policies that doesn't allow unauthorized users
to attach a non-bootable iso image to hosts.

We may consider adding support for HTTP credentials and TLS settings in the future
but it's outside the scope of this proposal.

As part of this proposal, the DataImage attachment will happen after the next reboot
because many hardwares need a reboot for attaching an image. For example, Dell iDrac
usually operates in terms of tasks, so once we create a task to attach a virtual
media, it will wait for the next reboot.
But we may add such an option in the future, something like - `immediate: true`,
to immediately attach the DataImage without waiting for reboot, for compatible hardware.

**Note** : As part of this proposal, the dataImage will be attached after the node
has been Provisioned or ExternallyProvisioned.

### Ironic Support

The [proposal](https://bugs.launchpad.net/ironic/+bug/2033288) for exposing this functionality in Ironic has been
accepted by the upstream Ironic community.

The [Ironic implementation](https://review.opendev.org/c/openstack/ironic/+/894918) based on the above proposal has been completed.

Other than that, we just need the implementation for driver specific support,
which in this proposal is Redfish.

## Design Details

Create a new Custom Resource(CR), `DataImage`, with spec field `Url` and the same `Name`
and `Namespace` as the `BareMetalHost` where we are attaching the image.

To attach an ISO, first the `DataImage` CR object is created and then it is attached to the
BMH on its next reboot/power on.

The `DataImage` `Status` will cache the image details including the attachment
status, which will inform us if the attachment succeeded and can also be used
for detachment - either when the attachment fails and we retry or when the user
explicitly requests detachment by deleting the `DataImage` CRD that corresponds to a BMH.

We will introduce a new flag, `NonBootableISOImage` (under `pkg/hardwareutils/bmc`), at the
webhook level to validate if a given driver supports the non-bootable ISO feature.

### Implementation Details

As part of the design we are assuming that to attach an image to a BMH object, the user
will create the corresponding `DataImage` CR (with the same `Name` and `Namespace` as the
`BareMetalHost` object). The BMH Controller will add the ownerReference for the corresponding BMH
(example : [HostFirmwareSettings](https://github.com/metal3-io/baremetal-operator/blob/9ce684e6462a6ab55ff650cb6c11f9ba1ffb395d/docs/api.md?plain=1#L664)) and it will also add a finalizer to the `DataImage` after its attached.
Then, on the next reboot/power-on of the BMH, the `DataImage` will be attached and the `DataImage`
`Status` will be updated to reflect the status of the attachment, including which image was attached.
In case of detachment of the ISO(`DataImage`), similar process will be followed where the actual
detachment will happen on the next reboot/power-on and the `DataImage` Status will reflect the status
of detachment, example : number of failures. The finalizer will also be removed once the
detachment succeeds.
Here is an example of what the `DataImage` `Status` might look like:

```yaml
status:
  lastReconciliation: "2024-01-01T12:00:00Z"
  error:
    count: 0
    message: ""
  attachedImage:
    url: "http://example.com/images/dataimage.iso"
```

Since the attachment of the ISO happens when a BMH reconcile is triggered as a result of BMH
reboot/power on, so handling the attachment/detachment of dataImage when the host reaches steady state (refer [`actionManageSteadyState` function](https://github.com/metal3-io/baremetal-operator/blob/9ce684e6462a6ab55ff650cb6c11f9ba1ffb395d/controllers/metal3.io/baremetalhost_controller.go#L1414) )
makes sense since we only reach this state when a host has been either provisioned or externallyProvisioned, and
any power state changes (including reboot via rebootAnnotation) are also handled after the host reaches this state
( refer [`manageHostPower` function](https://github.com/metal3-io/baremetal-operator/blob/1bb45eef449c942711b1c0937ecff2b10a326eb3/controllers/metal3.io/baremetalhost_controller.go#L222) )

We need to cache the attached image along with the attachment status in the `Status`
of the `DataImage` to know if the image has been attached successfully. This
will also help us determine if a different image was attached previously which
needs to be detached first before attaching the new dataImage. Or, if the user
deletes the dataImage CR and the `Status` contains a cached entry, which will
again trigger detachment of that image.

In case the image fails to attach, we will retry until either the attachment succeeds
or the user removes the dataImage CR. In case of failure in attachment, we will
always do a detachment before the next retry, and record the reason for failure in the
logs. In case of persistent failures, we will retry with increasing delays until the
attachment/detachment succeeds.

## Dependencies

There is a dependency on the implementation(based on the proposal shared
above) on Ironic side to finish for this feature to work. But this doesn't
block the development of the BMO API.

## Upgrade / Downgrade Strategy

This feature adds a Custom Resource(CR) to the cluster which doesn't make
any changes to the `BareMetalHost` `Spec`, so all the existing `BareMetalHost`
definitions should continue to work as before.

This feature will become available after upgrade, and downgrade is also pretty
straightforward where the user just needs to remove the `DataImage` CRs.

Explicit microversion negotiation support has been added to Gophercloud ([pr](https://github.com/gophercloud/gophercloud/pull/2791))
which can be used in case we don't want to use the master branch for Ironic.

## Alternatives

We can also achieve this using the existing `BMH.Spec.Image` field, but this
attempts to change the boot order of the system and relies on the host to
fallback to the installed system when booting the image fails.
