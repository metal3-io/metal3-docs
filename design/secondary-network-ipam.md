<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# secondary-network-ipam

## Status

One of: provisional

## Table of Contents

<!--ts-->
   * [secondary-network-ipam](#secondary-network-ipam)
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
      * [Alternatives](#alternatives)
      * [References](#references)

<!-- Added by: dhellmann, at: Mon Jun 17 12:54:02 EDT 2019 -->

<!--te-->

## Summary

metal3 needs to manage IP addresses on the secondary network to ensure
that supporting applications such as Ceph have persistent addresses on
each host.

## Motivation

### Goals

1. Configure secondary network interfaces on all hosts in the same way.
1. Support PXE booting hosts for provisioning.
1. Support static IPs on all hosts on secondary networks so the metal3
   components are not locked to running on the master hosts.

### Non-Goals

1. Integrate with external IPAM solutions.
1. Describe how to manage the IP or access to the web server with the
   image(s) to be provisioned.

## Proposal

### Implementation Details/Notes/Constraints

Ceph, and potentially other supporting services that use the secondary
network in some deployments, get confused if a client IP changes. We
therefore want to ensure that those IPs do not change.

We use dnsmasq to manage PXE booting servers during
provisioning. dnsmasq will not bind to an interface managed by
dhclient, so at least some of the hosts must have statically allocated
IPs on the secondary network to allow us to run dnsmasq at all. This
also means it is not sufficient to manage DHCP reservations to ensure
a given host always receives the same IP.

When we implement host discovery, we will want to allow discovered
hosts to use part of the IP range on the provisioning network that is
not used for static allocations so that a user does not have to clean
up those static allocations for hosts they are not using in their
cluster.

To meet all of these requirements, we need to configure the secondary
network interfaces on each host with a static IP address.

### Risks and Mitigations

We need to ensure the DHCP address range and static address range do
not overlap. We should be able to ensure that with careful management
of the CIDRs.

[inwinstack/ipam](https://github.com/inwinstack/ipam) may not be
stable or reliable, and we would have to either fix it, fork it, or
build a replacement.

## Design Details

We need to divide the subnet range for the provisioning network
between a set of addresses we can use for DHCP and a set for static
IPs.

We need the installer to allocate IPs for the master nodes as it
provisions them, and to record that information in the kubernetes
database so those same IPs are not used for other hosts later.

We need to store the subnet CIDR and existing allocations in the
kubernetes database somewhere so new IPs can be allocated when hosts
are provisioned.

The [inwinstack/ipam](https://github.com/inwinstack/ipam) controller
provides `Pool` and `IP` resources for allocating IPs from address
ranges. We should evaluate it to see if we can use it for managing the
IP allocations.

The machine-api-provider-baremetal controller is responsible for
making decisions about how to configure a host, so it should request
IPs for secondary networks, assign them to the interfaces, and pass
the relevant data using the ignition configuration data. It will need
to create host-specific ignition configuration resources because it
will be different for each host. It should also set the `Machine` as
an owner of the `IP` so that the reservation is deleted when the
`Machine` is deleted.

### Work Items

1. Ensure the IP ranges for secondary networks are captured by the
   installer and saved to the kubernetes database as `Pool` resources.
1. Ensure the installer registers the IP allocations for masters.
1. Ensure the IPAM service is deployed along with the other metal3
   components.
1. Update the metal3 machine controller to allocate IPs and create
   host-specific ignition configurations containing the IPs.
1. Create image to hold IPAM operator.
1. Add IPAM operator to metal3 deployment.

### Dependencies

* [inwinstack/ipam](https://github.com/inwinstack/ipam)

### Test Plan

No special requirements

### Upgrade / Downgrade Strategy

Add IPAM operator to deployment configuration

### Version Skew Strategy

N/A

## Drawbacks [optional]

This further complicates the configuration for the metal3 components
by adding yet another container/Pod/Deployment.

## Alternatives

We could require an external DHCP and IPAM solution for the secondary
networks, as we do for the primary network. This complicates
deployments and requires more services running outside of the cluster
to know about implementation details of the cluster in order to have
the external DHCP server pass PXE requests to the dnsmasq instance
that is part of the metal3 deployment, and which might change hosts
and IPs if the pod is restarted.

We could monitor the DHCP reservations given by dnsmasq and ensure
they are configured to be persistent, then also use those IPs to set
static addresses on the hosts during provisioning. This would leave a
reservation to be cleaned up when a host is removed, which might be
tricky for a discovered host that is never actually provisioned.

## References

None
