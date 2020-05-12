<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# IP address management for networkdata

## Status

provisional

## Table of Contents

<!--ts-->

* [Title](#title)
  * [Status](#status)
  * [Table of Contents](#table-of-contents)
  * [Summary](#summary)
  * [Motivation](#motivation)
    * [Goals](#goals)
    * [Non-Goals](#non-goals)
  * [Proposal](#proposal)
    * [User Stories](#user-stories-optional)
      * [Story 1](#story-1)
      * [Story 2](#story-2)
    * [Implementation Details/Notes/Constraints [optional]](#implementation-detailsnotesconstraints-optional)
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

<!-- Added by: stack, at: 2019-02-15T11:41-05:00 -->

<!--te-->

## Summary

A Template has recently been introduced in CAPM3, allowing to specify
templates to generate the Network Data passed to ironic through the BMH. In the
case of a network without DHCP, the ip addresses must be statically allocated,
however, considering the Kubeadm Control Plane and machine deployment features
in Cluster API, it is not possible to do it before the actual deployment of the
nodes. Hence a template was introduced that had a possibility to specify a
pool of IP addresses to be statically allocated to the nodes referencing this
Template. However some limitations were hit in the current design.
In order to overcome them, we propose to introduce three new objects,
*IPPool*, *IPClaim* and *IPAddress* to provide more flexible IP address
management.

The *IPPool* would contain the list of IP addresses and ranges usable
to select an IP address for a Template referencing it, while
*IPAddress* would contain a representation of an IP address in use in order
to prevent conflicts efficiently. *IPClaim* would be a request for an
*IPAddress* from an *IPPool*

## Motivation

The current implementation of Template allows deploying clusters with
static ip address allocations provided in the Network Data section for
cloud-init. However, several issues are relating to the design :

* It is not possible to specify multiple non-continuous ranges of IP addresses.
  Hence, for example if the user has some public ip addresses available that are
  sparse, not in a continuous pool, this feature is not usable.
* It is not possible to use the same pool across multiple *Template* objects.
  For example, if a user wants to use a pool of IP addresses for multiple
  machine deployments (each deployment requiring its own *Template* object),
  he would need to split the pool into smaller non-overlapping pools, one per
  machine deployment. This is problematic in case the deployment replica sets
  are expected to vary in a substantial manner. For example, in order to allow
  scale out, one might have to reserve multiple IP addresses for a deployment
  that will not be used. This will result in large gaps and inefficiency in the
  addresses allocation, specifically if those are public IPv4 addresses.
* It is not possible to rule out some IP addresses that might be in use for any
  reason after the deployment.

In addition, the designed system must be compatible with Clusterctl move
operation. This means that all status on all objects will be discarded during
the move operation and all objects must be linked to the *Cluster* object they
belong to by a chain of owner references.

### Goals

* Introduce an IPPool, an IPClaim and an IPAddress CRDs.
* add flexibility in the IP address allocation
* enable sharing of a pool across machine deployments / KCP
* enable use of non-continuous pools
* enable external IP management by using IPAddress CRs
* offer a predictable way to assign addresses to some nodes
* be resilient to the clusterctl move operation

### Non-Goals

* provide a DHCP feature or any equivalent level feature.

## Proposal

### User Stories

#### Story 1

As a user deploying a target Kubernetes cluster, I want to be able to specify
a non-continuous range of public IP addresses to be used for the nodes static
allocation as those sparse addresses are all I got from my network admins.

#### Story 2

As a user deploying a target Kubernetes cluster, I want to be able to specify
the pool of public IP addresses available once, and have any machine deployment
or kubeadm control plane referencing it use it, effectively sharing it among
multiple machine deployments.

#### Story 3

As a user deploying a target Kubernetes cluster, I want to have an allocation
predictability. I want to be able to specify what IP address some claims will
get.

#### Story 4

As a user deploying a target Kubernetes cluster, I want that allocation of
IP addresses to be preserved during the pivoting operation towards the target
cluster to prevent future conflicts.

### Implementation Details/Notes/Constraints

* This proposal should be fully backwards compatible and not modify any existing
  behaviour.
* When shared among multiple machine deployment, the allocation would be
  random as much as possible to avoid conflicts and re-use as much as possible.
* If not needed, this feature should not require the user to modify anything
  existing in their CRs

### Risks and Mitigations

This adds some complexity to the Metal3 system. Proper documentation could solve
the issue, and for users not needing this feature, no change would be required.
This design may lead to a high number of objects, if there is a high number of
nodes.

## Design Details

A IPPool object would be created :

```yaml
apiVersion: ipam.metal3.io/v1alpha1
kind: IPPool
metadata:
  name: pool-1
  namespace: default
  ownerReferences:
  - apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
    kind: Metal3Cluster
    name: cluster-1
spec:
  clusterName: cluster-1
  pools:
    - start: 192.168.0.10
      end: 192.168.0.15
      subnet: 192.168.0.0/24
      gateway: 192.168.0.1
      prefix: 24
    - start: 192.168.1.10
      end: 192.168.1.15
      subnet: 192.168.1.0/24
      gateway: 192.168.1.1
      prefix: 24
  gateway: 192.168.1.1
  prefix: 24
  preAllocations:
    "RenderedData-10": 192.168.0.9
    "RenderedData-9": 192.168.0.8
  namePrefix: "provisioning"
status:
  lastUpdated: "2020-04-02T06:36:09Z"
  allocations:
    "RenderedData-1": "192.168.0.11"
    "RenderedData-10": 192.168.0.9
    "RenderedData-9": 192.168.0.8
```

In the *spec* of *IPPool*, there would be a *pools* list, that would
contain a list of IP address pools, with the *start* and *end* attributes
giving the start and end ip addresses of the pool. The *subnet* field allows to
verify that the allocated IP is in the pool and from which the start and end ip
addresses can be inferred. Specifying single ip addresses can be achieved by
setting the start and end ip address to that single ip address.

The *prefix* and *gateway* parameters can be given for each pool of the list,
or globally. If they are given for a pool they will override the global
settings, that are default values. The *prefix* and *gateway* will be set on
the *IPAddress* and can be fetched from a *Template*.

The *allocations* fields is a map of object name and ip address that allow a
user to specify a set of static allocations for some objects.

The *namePrefix* contains the prefix used to name the IPAddress objects
created. It must remain the same for a subnet, across updates or changes in the
IPPool object to keep the existing leases.

The *status* would contain a *lastUpdated* field with the timestamp of the last
update. In case of an error during the allocation (pool exhaustion for example),
the error would be reported on the Claim object, in the *errorMessage* field.
The *allocations* map will map the IP address to the *RenderedData* object it was
allocated for and the *addresses* will map the *RenderedData* objects with the
*IPAddress* objects.

The *IPAddress* object would be the following

```yaml
apiVersion: ipam.metal3.io/v1alpha1
kind: IPAddress
metadata:
  name: pool-1-192-168-0-11
  namespace: default
  ownerReferences:
  - apiVersion: ipam.metal3.io/v1alpha1
    kind: IPPool
    name: pool-1
  - apiVersion: ipam.metal3.io/v1alpha1
    kind: IPClaim
    name: RenderedData-1
spec:
  claim:
    Name: RenderedData-1
  Address: 192.168.0.11
  prefix: 24
  gateway: 192.168.0.1
  pool:
    Name: pool-1
status:
  ready: true
```

The *IPClaim* object would be the following

```yaml
apiVersion: ipam.metal3.io/v1alpha1
kind: IPClaim
metadata:
  name: RenderedData-1
  namespace: default
  ownerReferences:
  - apiVersion: metadata.metal3.io/v1alpha1
    kind: Data
    name: data-1
spec:
  owner:
    name: RenderedData-1
  pool:
    name: pool-1
status:
  ipAddress:
    name: pool-1-192-168-0-11
  errorMessage: ""
```

For each *IPClaim*, the controller reconciling the *IPClaim* will select an
available IP address randomly from the *IPPool*, if the object name is not in
the *preAllocations* map in the object *spec* or in an existing *IPAddress*
object, in that case it would select that IP address. An error would be
reflected on the claim.

The source of truth for allocations needs to be the IPAddress CR. That will
satisfy the requirement to have state in the spec for resources that pivot into
the cluster, while also addressing the concurrency issue with choosing an IP.
It is possible to create one of those atomically with the owner reference set to
the claim and the name constructed to produce a conflict if 2 claims pick the
same IP. That atomic operation will ensure a clean allocation.

The claim controller cannot rely on any data in the pool's status fields to
know which IPs are already allocated, because that information may be out of
date. So, the claim controller should get a list of IPAddress resources owned by
the pool mentioned in its claim, loop over them, and build a set of IPs that are
unavailable. It should then pick addresses randomly from its ranges until it
finds one not in use in that set.

After the claim controller picks an IP, it should create an IPAddress CR with
the owner reference set to the claim and using the naming scheme designed to
ensure conflict. If the claim controller fails to create the new IPAddress, it
should log the conflict and return immediately so the reconcile function is
called again for a fresh attempt. When the claim controller successfully creates
an IPAddress, it should update the claim's status fields with the reference to
the new IPAddress.

There may be instances where the claim controller can create an address resource
but then not update the claim resource. To address that case, before the claim
controller picks an IP it should first search for IPAddress resources owned by
the claim it is reconciling. If it finds one, it should update the claim's
status to refer to it instead of making a new one.

The pool controller should watch for new IPAddress resources to be created. When
one is created, the controller should reconcile the pool used by the IPAddress
and update the allocations listed in the status block. That gives the user a
convenient way to get the allocated IPs for a pool.

If the cluster to which the *IPClaim* belongs is paused, the reconciliation
of the *IPClaim* would be paused.

The *Template* would be modified this way:

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3DataTemplate
metadata:
  name: nodepool-1
  namespace: default
  ownerReferences:
  - apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
    controller: true
    kind: Metal3Cluster
    name: cluster-1
spec:
  metaData:
    ipAddressesFromIPPool:
      - Name: pool-1
        Key: "ip-address-1"
    prefixesFromIPPool:
      - Name: pool-1
        Key: "netmask-1"
    gatewaysFromIPPool:
      - Name: pool-1
        Key: "gateway-1"
  networkData:
    networks:
      ipv4:
        - id: "Baremetal"
          link: "vlan1"
          ipAddressfromIPPool: pool-1
          routes:
            - network: "0.0.0.0"
              prefix: 0
              gateway:
                fromIPPool: pool-1
              services:
                - type: "dns"
                  address: "8.8.4.4"
        - id: "Provisioning"
          link: "vlan2"
          ipAddressfromIPPool: pool-2
          routes:
            - network: "0.0.0.0"
              prefix: 0
              gateway:
                string: "192.168.1.1"
              services:
                - type: "dns"
                  address: "8.8.4.4"
status:
  indexes:
    "0": "machine-1"
  dataNames:
    "machine-1": nodepool-1-0
  lastUpdated: "2020-04-02T06:36:09Z"
```

When reconciling the *RenderedData* object, the reconciler would create an
*IPClaim* for the *IPPool* objects that are referenced in the
*Template*. It will then wait until the *IPClaim* has a reference to an
*IPAddress* object, it will then fetch the *IPAddress* and it will render the
templates, filling the IP addresses, prefixes and gateways based on the content
of the *IPAddress* objects.

### Work Items

* implement the additional controllers
* add the logic to create the claim, fetch the IP address and wait for it when
  rendering the templates
* Ensure all tests are present (unit and end to end tests)

### Dependencies

[MetaData and NetworkData implementation](https://github.com/metal3-io/metal3-docs/blob/master/design/metadata-handling.md)

### Test Plan

* All functions will have unit tests
* integration tests will also be added
* A specific setup will be added in the metal3-dev-env end to end tests.

### Upgrade / Downgrade Strategy

No change would be required to keep the existing behaviour (the ipaddress field
could be removed, but was never part of a released API). In order to start using
this feature, one will just need to modify the *Template* and create
*IPPool* objects.

### Version Skew Strategy

NA

## Drawbacks

* In case of large clusters, it might add many objects.

## Alternatives

No simple alternative would enable to share the addresses between machine
deployments. All approaches require a shared object to share the allocations
status.

## References

None
