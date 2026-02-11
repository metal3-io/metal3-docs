<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# managing-provisioning-dependencies

<!-- cSpell:ignore controlplanes,reprovisioned -->

## Status

in-progress

## Summary

This document explains the implementation of the Baremetal Operator Pod
as provisioned on any one of the controlplanes in the cluster.

## Motivation

We need to document how we are going to allow ironic, ironic inspector,
and dnsmasq to operate with the baremetal operator in a single pod.
This includes how to set up a static IP address for use by dnsmasq/dhcp/pxe,
how to support ironic/dnsmasq integration, how to load images for use.

### Goals

1. To agree on an architecture that allows us to deploy new nodes
   via ironic successfully and with fault tolerance.

### Non-Goals

1. To list the scheme to use for every type of controller.
1. To specify the user interface for entering address information.

## Proposal

### Implementation Details/Notes/Constraints

The ironic+bmo pod has a number of constraints that cause a fairly
specific configuration to be required.  These include:

1. Having the images available for download via http and tftp
1. Having a static IP on the provisioning network so that dnsmasq
   can operate as a DHCP server to serve PXE requests.
1. Shared storage for ironic, ironic inspector, and dnsmasq to allow
   ironic to update the image being deployed via dnsmasq configuration
   changes.

The first issue is to be resolved by using an 'init' container in the
openshift pod.  This container will download the images either from a
specific location or from the internet.

The requirement for a static IP stems from being able to run a DHCP/PXE
server within the pod.  Using a dhcp assigned address on the provisioning
network causes dnsmasq to error out.  At first I had thought of just
assigning static IPs to each provisioning interface on each controlplane node
but this quickly becomes complicated to manage.  Especially in the event
of a controlplane going down and being reprovisioned, rebooted etc.

The solution we came up with to resolve this is to use the 'lifetime'
From the ip-address manpage:

- valid_lft LFT

  The valid lifetime of this address; see section 5.5.4 of RFC
  1. When it expires, the address is removed by the kernel.
  Defaults to forever.

- preferred_lft LFT

  The preferred lifetime of this address; see section 5.5.4 of RFC
  1. When it expires, the address is no longer used for new outgoing
  connections. Defaults to forever.

So again, an init container is used to set the IP address to a
preconfigured value.  This init container sets the lifetime to 5 minutes
to allow time for the 'refresh' container to start.

As part of the main pod, the 'refresh' container refreshes the IP address
every 5 seconds for a 10 second lifetime.  This is done so that the
IP address is ephemeral and exists only while the pod itself exists.
When the pod dies, the refresh will stop and the IP will be released
within 10 seconds.  The pod can then be rescheduled and the IP will
available for use on the new server.

Shared storage is implemented via a shared volume in OpenShift.  This is
home to the dnsmasq configuration, as well as the images and the ironic
database.  This allows ironic to configure dnsmasq as required to perform
inspection or boot a production image.  It also means we only have to
download the images once, and the information in the database will also
migrate to a new node if the pod moves.

### Risks and Mitigations

There is still a risk that we could end up with two pods operating at
once in the event of a net-split situation.  There are some strategies
we could use here to perform fencing in this situation.

1. Use access to the shared storage as a method to determine if we
   have lost connectivity and self-fence.
1. Have the new ironic pod destroy the previous node if it can safely
   determine that the old host is still running.

## Design Details

### Work Items

Most of the work is completed, some tasks are still outstanding:

- Need to add the init container to download images.
- Others pending approval.

### Dependencies

N/A

### Test Plan

I think this is where a good QE strategy could be needed.  Especially
testing different PXE options and taking nodes through various states
to ensure proper transitions.  We should also test destroying the
pod ensuring it can move to a new node, and that the IP transitions
properly

### Upgrade / Downgrade Strategy

N/A

### Version Skew Strategy

N/A

## Alternatives

## References

- [PR in baremetal-operator to enable ip address management](https://github.com/metal3-io/baremetal-operator/pull/212)
