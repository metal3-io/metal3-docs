<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# host-config-drive

## Status

[Implemented](https://github.com/metal3-io/baremetal-operator/pull/70)

## Summary

Provisioning hosts requires two separate images. The first is the
primary target image for the host, and contains the operating system
and other software that the host will run. These are generally
reusable across many hosts. Customization data can also be provided
via a second "config drive" image, which contains configuration settings
that are typically interpreted by a firstboot agent (cloud-init, ignition)
in the primary target image.

Customization data can be provided in several formats, but most commonly
a "user data" blob is provided, with a format that depends on the specific
firstboot agent.  This data can be  built into an ISO image, which is handled
 by Ironic via writing an ISO to a separate partition with a predictable disk
label, accessible to the primary target image when the host boots.

Given use of Ironic, first boot agents must be configured to look for data
in the OpenStack config drive format using the path
`/openstack/latest/user_data`.

User data contents are stored in a Secret within the
kubernetes database because they can contain sensitive
information.

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

User data settings come from the contents of a secret, is referenced
via the BaremetalHost userData spec field.  The format of this data may
differ depending on the firstboot tool in the primary OS image, so
assumptions regarding the specific tool should be avoided in the BMO.

Corresponding changes will be required in the Cluster/Machine API layer
to ensure the required secret for the given host role is provided via
the BMH userData field.

### Risks and Mitigations

Passing the user data to Ironic as a JSON string instead of an encoded
ISO requires a recent version of Ironic (since the development cycle for Stein),
an interim solution may be required until this is available in the metal3 images.

## Design Details

### Work Items

- Add a `UserDataSecretRef` of type `SecretRef` to the
  `BareMetalHostSpec` structure to hold the location of the Secret
  containing the user data.
- We may want to define a new type to hold all of the provisioning
  instructions, rather than adding individual fields to the host spec
  directly.
- Update the cluster-api provider to find and pass the worker user data Secret to
  the baremetal operator through the new field in the
  `BareMetalHostSpec`.
- Update the baremetal operator to retrieve the user data Secret
  content and pass it to Ironic, when it is present.

### Dependencies

This will require work in both the actuator/provider and operator repositories.

We will need to use version of Ironic from the Stein release series,
which includes the user data support in the API.

### Test Plan

Manual or automated integration tests for ensuring the config drive
content is applied to the server during provisioning.

### Upgrade / Downgrade Strategy

N/A

### Version Skew Strategy

N/A

## Drawbacks

N/A

## Alternatives

N/A

## References

- [CoreOS setting for the config drive user data path](https://github.com/coreos/ignition/blob/master/internal/providers/openstack/openstack.go#L42)
- [golang config drive builder in gophercloud/utils](https://github.com/gophercloud/utils/blob/master/openstack/baremetal/v1/nodes/configdrive.go)
