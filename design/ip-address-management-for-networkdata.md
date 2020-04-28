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

A Metal3DataTemplate has recently been introduced in CAPM3, allowing to specify
templates to generate the Network Data passed to ironic through the BMH. In the
case of a network without DHCP, the ip addresses must be statically allocated,
however, considering the Kubeadm Control Plane and machine deployment features
in Cluster API, it is not possible to do it before the actual deployment of the
nodes. Hence a template was introduced that had a possibility to specify a
pool of IP addresses to be statically allocated to the nodes referencing this
Metal3DataTemplate. However some limitations were hit in the current design.
In order to overcome them, we propose to introduce two new objects,
*Metal3IPPool* and *Metal3IPAddress* to provide more flexible IP address
management.

The *Metal3IPPool* would contain the list of IP addresses and ranges usable
to select an IP address for a Metal3DataTemplate referencing it, while
Metal3IPAddress would contain a representation of an IP address in use in order
to prevent conflicts efficiently.


## Motivation

The current implementation of Metal3DataTemplate allows deploying clusters with
static ip address allocations provided in the Network Data section for
cloud-init. However, several issues are relating to the design :

* It is not possible to specify multiple non-continuous ranges of IP addresses.
  Hence, for example if the user has some public ip addresses available that are
  sparse, not in a continuous pool, this feature is not usable.
* It is not possible to use the same pool across multiple Metal3DataTemplate.
  For example, if a user wants to use a pool of IP addresses for multiple
  machine deployments (each deployment requiring its own Metal3DataTemplate),
  he would need to split the pool into smaller non-overlapping pools, one per
  machine deployment. This is problematic in case the deployment replica sets
  are expected to vary in a substantial manner. For example, in order to allow
  scale out, one might have to reserve multiple IP addresses for a deployment
  that will not be used. This will result in large gaps and inefficiency in the
  addresses allocation, specifically if those are public IPv4 addresses.
* It is not possible to rule out some IP addresses that might be in use for any
  reason after the deployment.

### Goals

- Introduce a Metal3IPPool and a Metal3IPAddress CRDs.
- add flexibility in the IP address allocation
- enable sharing of a pool across machine deployments / KCP
- enable use of non-continuous pools
- enable external IP management by using Metal3IPAddress CRs
- keep when possible the predictability of the IP address based on the
  Metal3Data index. When shared among multiple Metal3DataTemplate, the
  allocation will happen on a first come first served basis.

### Non-Goals

- provide a DHCP feature or any equivalent level feature.

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

As a user deploying a target Kubernetes cluster, I want to keep the allocation
predictability offered by the current feature, i.e. the ip address is the
start address + the index of the Metal3Data, when I use a pool for a single
machine deployment. This is to ensure that the current proposal adds a feature
without removing any existing feature and is fully backward compatible.

### Implementation Details/Notes/Constraints

- This proposal should be fully backwards compatible and not modify any existing
  behaviour.
- When shared among multiple machine deployment, the allocation would be
  random as much as possible to avoid conflicts and re-use as much as possible.
- If not needed, this feature should not require the user to modify anything
  existing in their CRs

### Risks and Mitigations

This adds some complexity to the Metal3 system. Proper documentation could solve
the issue, and for users not needing this feature, no change would be required.

## Design Details


A Metal3IPPool object would be created :

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3IPPool
metadata:
  name: pool-1
  namespace: default
  ownerReferences:
  - apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
    kind: Metal3Cluster
    name: cluster-1
  - apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
    kind: Metal3Data
    name: metal3data-1
spec:
  pools:
    - start: 192.168.0.10
      end: 192.168.0.15
      subnet: 192.168.0.0/24
      step: 1
    - start: 192.168.0.20
      end: 192.168.0.25
      subnet: 192.168.0.0/24
status:
  lastUpdated: "2020-04-02T06:36:09Z"
  allocations:
    "192.168.0.11": "metal3data-1"
  addresses:
    "metal3data-1": "pool-1-192-168-0-11"
  error: false
  errorMessage: ""
```

In the *spec* of *Metal3IPPool*, there would be a *pools* list, that would
contain a list of IP address pools, with the *start* and *end* attributes
giving the start and end ip addresses of the pool, the *subnet* allowing to
verify that the allocated IP is in the pool and from which the start and end ip
addresses can be inferred. The *step* item gives the interval between allocated
IP addresses. Specifying single ip addresses can be achieved by setting the
start and end ip address to that single ip address.

The *status* would contain a *lastUpdated* field with the timestamp of the last
update and and *error* boolean that is set to true if an error during allocation
happens. In that case, the *errorMessage* will contain the text of the error.
The *allocations* map will map the IP address to the *Metal3Data* object it was
allocated for and the *addresses* will map the *metal3Data* objects with the
*Metal3IPAddress* objects.

All IP addresses specified in a Metal3IPPool must be from the same subnet.

The *Metal3IPAddress* object would be the following

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3IPAddress
metadata:
  name: pool-1-192-168-0-11
  namespace: default
  ownerReferences:
  - apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
    kind: Metal3IPPool
    name: pool-1
  - apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
    kind: Metal3Data
    name: metal3data-1
spec:
  Metal3Data:
    Name: metal3data-1
  Address: 192.168.0.11
  Metal3IPPool:
    Name: pool-1
status:
  ready: true
```

For each owner reference added on a *Metal3IPPool* that is a *Metal3Data*, the
controller reconciling the *Metal3IPPool* will select an available IP address.
If all the *Metal3Data* owner references are from the same *Metal3DataTemplate*,
then the controller will use the index of the *Metal3Data* to compute the IP
address to allocate by sorting the addresses in incremental order and selecting
the IP address corresponding to the index. In case of conflict, (multiple
Metal3DataTemplate referencing the same *Metal3IPPool*, a random available IP
address will be selected.

Once the IP address is selected, the controller will create a *Metal3IPAddress*
for that address. In case of conflict, it will list all the *Metal3IPAddress*
objects that have an owner reference to this *Metal3IPPool* and update the
status with the mapping of IP addresses and *Metal3Data* object names. It will
then randomly select an available IP address. Once the *Metal3IPAddress* object
is created, the *Metal3IPPool* object status will be updated with the new map.

If the *lastUpdated* field of the *Metal3IPPool* is empty, the controller will
list all the *Metal3IPAddress* objects that have an owner reference to this
*Metal3IPPool* and update the status with the mapping of IP addresses and
*Metal3Data* object names. It will also update the *lastUpdated* field.

If the cluster to which the *Metal3IPPool* belongs is paused, the reconciliation
of both objects would be paused.

The *Metal3DataTemplate* would be modified this way:

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
    ipAddressFromIPPool:
      Name: pool-1
      Key: "ip-address-1"
  networkData:
    networks:

      ipv4:
        - id: "Baremetal"
          link: "vlan1"
          ipAddressFromIPPool:
            Name: pool-1
            Key: "ip-address-1"
          netmask: 24
status:
  indexes:
    "0": "machine-1"
  dataNames:
    "machine-1": nodepool-1-0
  lastUpdated: "2020-04-02T06:36:09Z"
```

When reconciling the *Metal3Data* object, the reconciler would fetch the
*Metal3IPPool* objects that are referenced in the *Metal3DataTemplate* and set
an ownerreference referencing the *Metal3Data* object. It will then wait until
the *Metal3IPAddress* object is created and has a status set to Ready. Once
ready, it will render the templates.

### Work Items

* implement the additional controllers
* add the logic to fetch the IP address and wait for it when rendering the
  templates
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
this feature, one will just need to modify the *Metal3DataTemplate* and create
*Metal3IPPool* objects.

If applicable, how will the component be upgraded and downgraded? Make
sure this is in the test plan.

### Version Skew Strategy

NA

## Drawbacks [optional]

* In case of large clusters, it might add many objects.

## Alternatives [optional]

No simple alternative would enable to share the addresses between machine
deployments. All approaches require a shared object to share the allocations
status.

## References

None