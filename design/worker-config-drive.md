<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# worker-config-drive

## Status

implementable

## Table of Contents

<!--ts-->
   * [worker-config-drive](#worker-config-drive)
      * [Status](#status)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
         * [Non-Goals](#non-goals)
      * [Proposal](#proposal)
         * [Implementation Details/Notes/Constraints](#implementation-detailsnotesconstraints)
         * [Risks and Mitigations](#risks-and-mitigations)
      * [Design Details](#design-details)
         * [Work Items](#work-items)
         * [Dependencies](#dependencies)
         * [Test Plan](#test-plan)
         * [Upgrade / Downgrade Strategy](#upgrade--downgrade-strategy)
         * [Version Skew Strategy](#version-skew-strategy)
      * [Drawbacks [optional]](#drawbacks-optional)
      * [Alternatives [optional]](#alternatives-optional)
      * [References](#references)

<!-- Added by: dhellmann, at: 2019-03-14T09:25-0400 -->

<!--te-->

## Summary

Provisioning hosts requires two separate images. The first is the
primary target image for the host, and contains the operating system
and other software that the host will run. These are generally
reusable across many hosts. The second image is the "config drive
image", which contains configuration settings passed to the target
image by writing an ISO to a separate partition accessible when the
host boots. The config drive image is often, but not always,
customized for each host. It is always often customized for the role a
host plays (master, worker, etc.).

In order to bring a host into the cluster as a worker we have to give
it the correct Ignition configuration as it boots as the "user data"
portion of the config drive image.  The target images we are using for
nodes in an OpenShift (and eventually Kubernetes) cluster are RHEL
CoreOS images with Ignition configured to look for its data in the
OpenStack config drive format using the path
`/openstack/latest/user_data`.

The Ignition file contents are stored in a Secret within the
kubernetes database because they contain certificate authority
information. There are different Ignition settings for worker and
master nodes, so something will need to know the intended role of each
host being provisioned in order to select the correct settings. Each
Secret has a key `userData` already.

Once the Ignition file contents are selected, they can be passed to
Ironic as the user data for the host and Ironic can build the config
drive ISO using the correct path based on the OpenStack standard
format.

The component best situated to select the right Ignition file contents
is currently is the baremetal actuator in the cluster-api provider.
The actuator knows the role of the host being allocated to a Machine,
so it can select the right Ignition configuration to include as the
user data.

The baremetal operator can receive the Secret, extract the `userData`
value, and pass the contents to Ironic as part of preparing the host
for provisioning.

## Motivation

### Goals

- Avoid having the baremetal operator tightly coupled to provisioning
  hosts to become nodes in the cluster.
- Avoid leaking secrets when passing the config drive to the baremetal
  operator.

### Non-Goals

N/A

## Proposal

### Implementation Details/Notes/Constraints

Under OpenShift, the worker settings come from the contents of a
secret (`openshift-machine-api/worker-user-data`), which holds a
base64-encoded copy of the Ignition JSON data in the `userData` key.

Before allocating a host to be a worker, the actuator will identify
the Secret containing the worker settings and include a reference to
it with the other provisioning instructions (image name, checksum,
etc.) it gives to the baremetal operator when it allocates a host. The
baremetal operator will access the secret and pass the contents to
Ironic as the user data content for the config drive.

The OpenStack cloud provider uses a value in the provider spec in the
Machine object to determine the name of this secret. We could do
something similar in our actuator, which would make it easier to
support generic Kubernetes as well as OpenShift.

### Risks and Mitigations

Passing the user data to Ironic as a JSON string instead of an encoded
ISO requires a newer version of Ironic than we have available in our
images today, but it should be available within the next few weeks
since the development cycle for Stein is ending. If we need it before
then, we could build the ISO in the operator and pass the encoded
contents instead.

## Design Details

### Work Items

- Add a `UserDataSecretRef` of type `SecretRef` to the
  `BareMetalHostSpec` structure to hold the location of the Secret
  containing the user data.
- We may want to define a new type to hold all of the provisioning
  instructions, rather than adding individual fields to the host spec
  directly.
- Update the actuator to find and pass the worker user data Secret to
  the baremetal operator through the new field in the
  `BareMetalHostSpec`.
- Update the baremetal operator to retrieve the user data Secret
  content and pass it to Ironic, when it is present.

### Dependencies

This will require work in both the actuator and operator repositories.

We will need to use version of Ironic from the Stein release series,
which includes the user data support in the API.

### Test Plan

Manual or automated integration tests for ensuring the config drive
content is applied to the server during provisioning.

### Upgrade / Downgrade Strategy

N/A

### Version Skew Strategy

N/A

## Drawbacks [optional]

N/A

## Alternatives [optional]

N/A

## References

- [CoreOS setting for the config drive user data path](https://github.com/coreos/ignition/blob/master/internal/providers/openstack/openstack.go#L42)
- [golang config drive builder in gophercloud/utils](https://github.com/gophercloud/utils/blob/master/openstack/baremetal/v1/nodes/configdrive.go)
