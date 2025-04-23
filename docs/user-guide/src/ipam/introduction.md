# IPAM (IP Address Manager)

The IPAM project provides a controller to manage static IP address allocations
in [Cluster API Provider Metal3](https://github.com/metal3-io/cluster-api-provider-metal3/).

In CAPM3, the Network Data need to be passed to Ironic through the BareMetalHost. CAPI addresses the deployment of Kubernetes clusters and nodes, using the Kubernetes API. As such, it uses objects such as MachineDeployments (similar to deployments for pods) that takes care of creating the requested number of machines, based on templates. The replicas can be increased by the user, triggering the creation of new machines based on the provided templates. Considering the KubeadmControlPlane and MachineDeployment features in Cluster API, it is not possible to provide static IP addresses for each machine before the actual deployments.

In addition, all the resources from the source cluster must support the CAPI pivoting, i.e. being copied and recreated in the target cluster. This means that all objects must contain all needed information in their spec field to recreate the status in the target cluster without losing information. All objects must, through a tree of owner references, be attached to the cluster object, for the pivoting to proceed properly.

Moreover, there are use cases that the users want to specify multiple non-continuous ranges of IP addresses, use the same pool across multiple Template objects, or rule out some IP addresses that might be in use for any reason after the deployment.

The IPAM is introduced to manage the allocations of IP subnet according to the requests without handling any use of those addresses. The IPAM adds the flexibility by providing the address right before provisioning the node. It can share a pool across MachineDeployment or KubeadmControlPlane, allow non-continuous pools and external IP management by using IPAddress CRs, offer predictable IP addresses, and it is resilient to the *clusterctl move* operation.

In order to use IPAM, both the CAPI and IPAM controllers are required, since the IPAM controller has a dependency on Cluster API *Cluster* objects.

## IPAM components

* **IPPool**: A set of IP addresses pools to be used for IP address allocations
* **IPClaim**: Request for an IP address allocation
* **IPAddress**: IP address allocation

### IPPool

Example of IPPool:

```yaml
apiVersion: ipam.metal3.io/v1alpha1
kind: IPPool
metadata:
  name: pool1
  namespace: default
spec:
  clusterName: cluster1
  namePrefix: test1-prov
  pools:
    - start: 192.168.0.10
      end: 192.168.0.30
      prefix: 25
      gateway: 192.168.0.1
    - subnet: 192.168.1.1/26
    - subnet: 192.168.1.128/25
  prefix: 24
  gateway: 192.168.1.1
  preAllocations:
    claim1: 192.168.0.12
```

The *spec* field contains the following fields:

* **clusterName**: Name of the cluster to which this pool belongs, it is used to verify whether the resource is paused.
* **namePrefix**: The prefix used to generate the IPAddress.
* **pools**: List of IP address pools
* **prefix**: Default prefix for this IPPool
* **gateway**: Default gateway for this IPPool
* **preAllocations**: Default preallocated IP address for this IPPool

The *prefix* and *gateway* can be overridden per pool. Here is the pool definition:

* **start**: IP range start address and it can be omitted if **subnet** is set.
* **end**: IP range end address and can be omitted.
* **subnet**: Subnet for the allocation and can be omitted if **start** is set. It is used to verify that the allocated address belongs to this subnet.
* **prefix**: Override of the default prefix for this pool
* **gateway**: Override of the default gateway for this pool

### IPClaim

An IPClaim is an object representing a request for an IP address allocation.

Example of IPClaim:

```yaml
apiVersion: ipam.metal3.io/v1alpha1
kind: IPClaim
metadata:
  name: test1-controlplane-template-0-pool1
  namespace: default
  annotations:
    ipAddress: <optional-annotation-for-specific-ip-request>
spec:
  pool:
    name: pool1
    namespace: default
```

The *spec* field contains the following:

* **pool**: This is a reference to the IPPool that is requested for

The *annotations* field contains the following optional parameter:

* **ipAddress**: This can be populated to acquire a specific IP from a given pool
* Note: In case of incorrect IP or conflict, error will be stamped on the IPClaim.

### IPAddress

An IPAddress is an object representing an IP address allocation. It will be created by IPAM to fill an IPClaim, so that user does not have to create it manually.

Example IPAddress:

```yaml
apiVersion: ipam.metal3.io/v1alpha1
kind: IPAddress
metadata:
  name: test1-prov-192-168-0-13
  namespace: default
spec:
  pool:
    name: pool1
    namespace: default
  claim:
    name: test1-controlplane-template-0-pool1
    namespace: default
  address: 192.168.0.13
  prefix: 24
  gateway: 192.168.0.1
```

The *spec* field contains the following:

* **pool**: Reference to the IPPool this address is for
* **claim**: Reference to the IPClaim this address is for
* **address**: Allocated IP address
* **prefix**: Prefix for this address
* **gateway**: Gateway for this address
