<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# image-ownership

## Status

implementable

## Table of Contents

<!--ts-->
   * [image-ownership](#image-ownership)
      * [Status](#status)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
         * [Non-Goals](#non-goals)
      * [Proposal](#proposal)
         * [Implementation Details/Notes/Constraints](#implementation-detailsnotesconstraints)
         * [Risks and Mitigations](#risks-and-mitigations)
         * [Work Items](#work-items)
         * [Dependencies](#dependencies)
         * [Test Plan](#test-plan)
         * [Upgrade / Downgrade Strategy](#upgrade--downgrade-strategy)
         * [Version Skew Strategy](#version-skew-strategy)
      * [Drawbacks](#drawbacks)
      * [Alternatives](#alternatives)
      * [References](#references)

<!-- Added by: dhellmann, at: 2019-03-08T11:55-0500 -->

<!--te-->

## Summary

In order for Metal3 to provision hosts and bring them into the
cluster, it needs to manage 2 images: the target image being written
to the host's disk, and the provisioning image used to do that. The
provisioning image is an implementation detail of Metal3, and its
use of Ironic, and so will be managed as part of Metal3 The image
written to disk is part of the cluster, and so will need to be at
least minimally configurable.

## Motivation

### Goals

- Identify the "owner" for specifying the version of the provisioning
  image
- Idenitfy the "owner" for specifying the version of the target image

### Non-Goals

- Specifying where the images are hosted during production runs
- Specifying how images are upgraded

## Proposal

### Implementation Details/Notes/Constraints

The version of the IPA image used to provision images (the
"provisioning image") is tied to the version of Ironic used by the
baremetal operator. The user has no reason to change that image, so we
do not need to make it configurable. We can either build the name and
version into the source code for the operator, or the operator can use
a versionless name/URL when passing the data to Ironic and we can have
our build system install the image into the container using that same
name. The latter should make updating Ironic simpler over time, but
may require extra work in the short term that we would not prioritize
highly.

The version of the image being written to the host (the "target
image") will change with each update of OpenShift, and may ultimately
need to be something that is decoupled to ensure that Metal3 can be
used with stock Kubernetes clusters in addition to OpenShift
clusters. Therefore it at least needs to be something the installer
can specify, and should not be hard-coded into any components. In the
interest of making the baremetal operator generic, we will have the
baremetal actuator assign the image to be provisioned to each host as
part of allocating a host to a cluster. Long term, the actuator can
derive the image name from a configuration setting or from the
provider spec in the MachineSet/Machine. In the near term, the
actuator can use a hard-coded value.

### Risks and Mitigations

Allowing customization of the target image may result in users
choosing images that are not suitable for hosting a
Kubernetes/OpenShift cluster.

Not allowing customization of the provisioning image will mean that
users will need to upgrade their baremetal operator component in order
to make use of updated versions of the provisioning tool.

### Work Items

- Add an image URL field to the BareMetalHost CRD
- Figure out how the actuator is going to know the URL (where is the
  image being served?)
- Update the actuator to pass that URL by updating the host object at
  the same time that it sets the machine reference on the host
- Update the baremetal operator to use the URL in the host object
  instead of the value currently hard-coded in the controller

### Dependencies

We need to work out where the target image is going to come from in a
production system so we can understand how to build a valid URL in the
actuator.

### Test Plan

We will have updated unit tests for the operator and whatever
end-to-end tests verify image provisioning works will need to
configure the system with the right URL.

### Upgrade / Downgrade Strategy

The provisioning image URL is managed by the operator, so it will be
upgraded or downgraded as the operator itself changes.

The target image relies on the version of the OS being used to start
the cluster, and will need to be set by the installer.

### Version Skew Strategy

The versions of the two images are not directly related so there
should not be an issue with skew.

The version of the provisioning image is tied to the version of the
baremetal operator, so we need to package them together or otherwise
ensure that the operator can fetch the image it needs.

## Drawbacks

The baremetal operator would be bit simpler if it owned both images,
but it would be less reusable.

## Alternatives

We could make the provisioning image configurable, but the only
benefit to doing that would be to allow updates to that image
independently of the other components and if we allow that we may have
untested configurations running in the field.

## References

N/A
