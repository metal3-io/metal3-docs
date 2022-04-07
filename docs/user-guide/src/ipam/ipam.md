# IPAM (IP Address Manager)

The IPAM project provides a controller to manage static IP address allocations
in [Cluster API Provider Metal3](https://github.com/metal3-io/cluster-api-provider-metal3/).

In CAMP3, the Network Data need to be passed to ironic through the BMH (Bare
Metal Host). CAPI addresses the deployment of Kubernetes clusters and nodes, using the
Kubernetes API. As such, it uses objects such as Machine Deployments (similar
to deployments for pods) that takes care of creating the requested number of
machines, based on templates. The replicas can be increased by the user,
triggering the creation of new machines based on the provided templates.
Considering the Kubeadm Control Plane and machine deployment features in
Cluster API, it is not possible to provide static IP addresses
for each machine before the actual deployments.

In addition, all the resources from the source cluster must support the CAPI
pivoting, i.e. being copied and recreated in the target cluster. This means
that all objects must contain all needed information in their spec field to
recreate the status in the target cluster without losing information. All
objects must, through a tree of owner references, be attached to the cluster
object, for the pivoting to proceed properly.

Moreover, there are use cases
that the users want to specify multiple non-continuous ranges of IP addresses,
use the same pool across multiple Template objects, or rule out some IP
addresses that might be in use for any reason after the deployment.

The IPAM is introduced to manages the allocations of IP subnets according to
the requests without handling any use of those addresses. The IPAM adds the
flexibility by providing the address right before provisioning the node. It can
share a pool across machine deployments or KCP, allow non-continuous pools
and external IP management by using IPAddress CRs, offer predictable IP
addresses, and it is resilient to the clusterctl move operation.

In order to use IPAM, both the CAPI controller and IPAM controller are
required, since the IPAM controller has a dependency on Cluster API *Cluster*
objects.

## IPAM components

* **IPPool**: a set of IP addresses pools to be used for IP address allocations
* **IPClaim**: a request for an IP address allocation
* **IPAddress**: an IP address allocation

## Deployment

You can deploy IPAM using `make deploy` or deploy an example pool using
`make deploy-examples`. You can also run IPAM controller locally using
`make run`.

For more information about this controller and related repositories, see
[metal3.io](http://metal3.io/).
