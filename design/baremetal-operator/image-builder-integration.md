<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Custom agent image controller

## Status

implemented

## Summary

Enable a custom image containing the ironic-python-agent to be built for each
BareMetalHost, instead of requiring all hosts to use the same agent image. The
interface to the image builder will be defined by a new PreprovisioningImage CR
in metal³, with users able to substitute their own implementations of image
building (in most cases this is expected to involve light customisation of an
existing image) by creating a controller. The baremetal-operator will create
and use PreprovisioningImages as required when configured to do so.

## Motivation

When running the ironic-python-agent (IPA) deploy ramdisk, the agent is reliant
on information baked in to the ramdisk image or available to discover from the
immediate environment in order to be able to contact Ironic. In most cases this
involves DHCP supplying an IP address and default route.

Some users would prefer not to run DHCP in their infrastructure, but rather use
static IP addresses instead. In some cases, particularly when provisioning
using virtualmedia and not using PXE, they might prefer that the network on
which to contact Ironic is not an untagged VLAN. In many cases, servers will be
connected to switches that use static link aggregators, and thus should set up
NIC bonding to enable reliable two-way communication.

Currently there is no way to use static IPs or configure any of the other
options on a per-host basis because all hosts are booted using the same ramdisk
image.

### Goals

- Allow each host to use its own deploy ramdisk image customised with an
  appropriate network configuration.

### Non-Goals

- Allow users who expect to provision a host to specify their own custom image
  containing IPA.
- Use Ironic with images that don't contain IPA.
- Implement custom provisioners not based on Ironic.

## Proposal

### User Stories

As a data center operator, I would like to manage hosts with metal³ and deploy
them via virtualmedia on networks where there is no DHCP-like configuration
service.

## Design Details

A new Custom Resource type, `PreprovisioningImage` will be created in the
metal3.io group. The Spec will contain the following (optional) fields:

- Name of networkData Secret
- Architecture

The Status will contain the following fields:

- Image URL
- Image format (ISO or initrd)
- Image checksum
- SecretReference + Version of networkData
- Architecture
- Error message
- Ready condition
- Error condition

A default controller for this resource type will be implemented that simply
sets a fixed URL (supplied in its own environment or command line) as the
output. However, provision will be made for interested parties to implement
alternate controllers to allow image customisation by making it easy to disable
this default controller.

A command-line switch (defaulting to off) will enable integration between the
baremetal-operator and the image request controller.

A new field, `preprovisioningNetworkData` will be added to the `BareMetalHost`
Spec for the purposes of image building. If the regular `networkData` field is
not specified, the `preprovisioningNetworkData` will be used in its place for
the provisioned image also.

### Implementation Details/Notes/Constraints

When integration is enabled and the driver is virtualmedia based (i.e. supports
an ISO ramdisk format), the controller portion of the baremetal-operator will
update the `PreprovisioningImage` with the same name and namespace as the
`BareMetalHost`, creating it if it doesn't exist, to point to a networkData
Secret.

The networkData Secret to be used will be obtained from the new
`preprovisioningNetworkData` field in the `BareMetalHost` Spec.

The Architecture will be obtained from the Host's hardware profile. Currently
we don't ratify the choice of hardware profile until after inspection, but we
could move this state earlier. In any event, we don't support multiple
architectures today, so we could use a default value in the interim.

In some provisioning states, the ironic provisioner will refuse to report
registration complete in `ValidateMangementAccess()` until the Ready condition
is true in the corresponding `PreprovisioningImage` Status (indicating that the
image is available at the linked URL), and the Secret reference + Architecture
in the Status matches what is expected. It will then configure the Node to use
the ramdisk Image from the URL in the Status. This must be done before
inspection or cleaning starts, but can be after the Ironic node reaches the
Manageable state. Completion of `ValidateManagementAccess()` will only be
blocked due to the image not being ready in the Registering, Inspecting, and
Deprovisioning states, or when required by Ironic.

The contents of the networkData Secret are generally assumed to be in the same
format output by OpenStack and consumable by cloud-init. However, for Metal³'s
purposes this is not a requirement as the data is passed through directly.
Authors of image customisation controllers are free to interpret the data in
any way they see fit.

Since PXE-booted hosts generally must be connected to the provisioning network
on an untagged VLAN using LACP for any NIC bonding, and on the provisioning
network ironic will supply an IP address via DHCP, there should be no need for
this feature other than when using virtualmedia drivers. An API option can
always be added later if this proves not to be the case.

The `BareMetalHost` should be set as the Owner of the `PreprovisioningImage` so
that the image gets deleted when the Host is deleted. This allows controllers
to use the resource to perform cache management.

If the image cache is lost, the controller must clear the Ready condition on
all existing `PreprovisioningImage` objects.

### Risks and Mitigations

If the consumer of the BareMetalHost resource is able to modify the
networkData, they will be able to influence the configuration of the Host after
they have deprovisioned and potentially released it. This is largely mitigated
by specifying the preprovisioningNetworkData separately from the networkData
that is potentially controlled by the user. A user with write access to the
`BareMetalHost` already has almost unlimited control over it anyway; if their
access is moderated through another controller then they will only be able to
control the networkData and not the preprovisioningNetworkData.

### Work Items

- Implement the new `PreprovisioningImage` CRD
- Implement a basic controller to reconcile the `PreprovisioningImage`
- Add runtime flag to configure image building integration
- Add the `preprovisioningNetworkData` field to the `BareMetalHost` Spec
- Add a watch on the `PreprovisioningImage` for the `BareMetalHost` reconciler
- Create/update the `PreprovisioningImage` when it is missing/outdated
- Pause registration until the image URL is available
- Pass the ramdisk URL to Ironic

### Dependencies

None

### Test Plan

Enable the functionality in the integration test, using the default (trivial)
controller implementation for the `PreprovisioningImage`. This should produce
the same result as today, but exercise the integration between the two resource
types.

### Upgrade / Downgrade Strategy

This functionality will be disabled by default, so that existing users don't
need to do anything special on upgrade.

### Version Skew Strategy

The API surface area is very small, so we are unlikely to encounter version
skew issues.

## Drawbacks

This adds complexity inside the baremetal-operator, for something that is not
needed by many users.

## Alternatives

### Add the ramdisk image URL to the BareMetalHost API

Instead of trying to integrate the two controllers, add a field to the
BareMetalHost specifying the URL of the ramdisk image.

To avoid a race, this must be done as part of creating the BaremetalHost CR or
the baremetal-operator must block until the image is available.

The former would be a significant limitation as it requires running a little
workflow in the process of creating a BareMetalHost - something that often
might be done manually by a user.

Since this functionality would be disabled by default, however, the latter
would not prevent backwards compatibility. We could automatically fill in the
field in the Spec with the known value whenever it is blank if the
functionality is disabled.

This puts a lot of power in the hands of any user with write access to the
BareMetalHost, but this is largely the case anyway pending the implementation
of API decomposition (which would also eliminate the concern here).

Arguably this couples the BareMetalHost API more tightly to how today's Ironic
works, with the assumption that pre-provisioning we will boot a ramdisk agent
now baked in to the API.

Overall this is more flexible, since the image URL can be added in any way (not
necessarily by adding a separate controller). It also has fewer moving parts.
On the other hand, the more opinionated proposal above provides a more
stuctured way for associating the network data with the BareMetalHost it
applies to.

### Have Ironic customise the image

Currently Ironic just boots the Node with a given kernel and initrd. However,
when deploying using virtual media it has the capability to [customise the ISO
image to include the
networkData](https://docs.openstack.org/ironic/latest/admin/dhcp-less.html#configuring-network-data).
(Specifically, this is implemented in the iLO and redfish drivers, and
inherited by idrac-redfish-virtualmedia.)

Unfortunately, this requires that the image already contain built-in capability
to decode the networkData and apply the network config. (In practice, this
means images using cloud-init and network data in the OpenStack format only.)
This excludes others, such as CoreOS. Although CoreOS has the ability to pull
in a container to process data, it cannot do so without network access, so
processing the networkData other than with something built in to the operating
system presents a chicken-and-egg problem.

Another downside of this is that there is no access from outside for a user to
request their own image build (e.g. to manually boot a server into the deploy
ramdisk for discovery).

Ironic verifies the data against a JSON Schema, whereas currently the
networkData field in the BareMetalHost is free-form JSON. However, the choice
of schema is customisable by a config option, so it could be set to free-form
to avoid breaking backward compatibility for existing resources.

With this strategy we would always have to update the network data when it
changes; we have no way of distinguishing between changes made by an
administrator or other user.

### Configure the IP address from within a fixed image

Using IPv6 Neighbour Discovery, we can determine the network prefix for each
interface. Using the network prefix we can statelessly choose a static IP
address without fear of collison (by using the Modified EUI-64 method based on
the MAC address, and/or a stable privacy address).

If the host is not directly attached to the network Ironic is on, Neighbour
Discovery can also locate routers on the attached networks and identify which
are suitable to be used as a default route.

For dynamically configured bonds (i.e. using LACP), only one port in the bond
will be up, but this should be sufficient for the purposes of the ramdisk.

Information about VLANs and static bonds can be obtained only from LLDP. This
information could be theoretically be used to automatically configure the
interfaces on the ramdisk. However, this is dependent on the network switch
configuration, and users may prefer not to rely on that (although we also rely
on it for obtaining the hardware details). We could only guarantee operation
when the route back to the Ironic API uses only untagged VLANs and doesn't go
through interfaces that should be statically bonded.

This only works for networks with IPv6 but, improbably, there are actually real
users who want to eliminate external DHCP requirements from their IPv4-only
environments.

## References

- [Proposal for customisable deployment
  procedure](https://github.com/metal3-io/metal3-docs/pull/180) that includes
  the alternate option of specifying the deploy image in the BareMetalHost Spec.
- [Stateless IPv6 address
  autoconfiguration](https://en.wikipedia.org/wiki/IPv6_address#Stateless_address_autoconfiguration)
