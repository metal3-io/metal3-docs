<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

<!-- cSpell:ignore Sylva Schiff Kanod argocd GitOps -->
# HostClaim: sharing BareMetalHost between multiple tenants

## Status

provisional

## Summary

We introduce a new Custom Resource (named HostClaim) which will facilitate
the creation of multiple clusters for different tenants. A HostClaim decouples
the client need from the actual implementation of the
compute resource: it establishes a security boundary

A HostClaim expresses that one wants to start a given
OS image with an initial configuration (typically cloud-init or ignition
configuration files) on a compute resource that meets a set of requirements
(host selectors).
The status and meta-data of the HostClaim provide the necessary information
for the end user to define and manage his workload on the compute resource,
but they do not grant full control over the resource (typically, BMC
credentials of servers are not exposed to the tenant).

## Motivation

The standard approach to implementing multi-tenancy in cluster-api is to follow the
[multi tenancy contract](https://cluster-api.sigs.k8s.io/developer/architecture/controllers/multi-tenancy#contract).

To adhere to this contract with cluster-api-provider-metal3, the clusters must
be put in different namespaces and the BareMetalHost objects must be defined
in those namespaces. In this setup, the tenants are the owners of the servers
and it becomes difficult to share the same server between different clusters if
they belong to different tenants.

In order to improve server usage, we would like to have a pool of servers that
clusters can lease depending on their workload. If we maintain the Metal3
constraints, all clusters must be defined in the same namespace where the
BareMetalHosts are defined.
Unless very complex access control rules are defined, cluster administrators
have visibility and probably control over all clusters and servers as the server
credentials are stored with the BareMetalHost resource.

We need to relax the constraint that the cluster and the BareMetalHosts are
in the same namespace but we also need a solution that give sufficient control
and visibility over the workload deployed on those servers so that tenants
can maintain the level of information they have had so far.

This proposal introduces a new resource called HostClaim that decouples
the definition of the workload performed by
the Metal3 machine controller from the actual compute resource.
This resource acts as a security boundary.

### Goals

* Split responsibilities between infrastructure teams, who manage servers, and
  cluster administrators, who create/update/scale baremetal clusters deployed
  on those servers, using traditional Kubernetes RBAC to ensure isolation.
* Define a resource where a user can request a compute resource to execute
  an arbitrary workload described by an OS image and an initial configuration.
  The user does not need to know exactly which BareMetalHost is used and does
  not control its BMC.
* Using BareMetalHosts defined in other clusters. Support as described here
  will be limited to the use with cluster-api as it will be handled at the
  level of the Metal3Machine.

### Non-Goals

* Discovery of which capabilities are exposed by the cluster.
  Which kind of compute resources are available and the semantics of the
  selectors are not handled.
* Compute resource quotas. The HostClaim resource should make it possible to
  develop a framework to limit the number/size of compute resources allocated
  to a tenant, similar to how quotas work for pods. However, the specification
  of such a framework will be addressed in another design document.
* Implementing network isolation between tenant clusters using a common set
  of BareMetalHosts.

## Proposal

### User Stories

#### Deployment of Simple Workloads

##### User point of view

As a user I would like to execute a workload on an arbitrary server.

The OS image is available in qcow format on a remote server at ``url_image``.
It supports cloud-init and a script can launch the workload at boot time
(e.g., a systemd service).

The cluster offers bare-metal as a service using Metal3 baremetal-operator.
However, as a regular user, I am not allowed to directly access the definitions
of the servers. All servers are labeled with an ``infra-kind`` label whose
value depends on the characteristics of the computer.

* I create a resource with the following content:

  ```yaml
  apiVersion: metal3.io/v1alpha1
  kind: HostClaim
  metadata:
    name: my-host
  spec:
    online: false
    kind: baremetal

    hostSelector:
      matchLabels:
        infra-kind: medium
  ```

* After a while, the system associates the claim with a real server, and
  the resource's status is populated with the following information:

  ```yaml
  status:
    addresses:
      - address: 192.168.133.33
        type: InternalIP
      - address: fe80::6be8:1f93:7f65:59cf%ens3
        type: InternalIP
      - address: localhost.localdomain
        type: Hostname
      - address: localhost.localdomain
        type: InternalDNS
      bootMACAddress: "52:54:00:01:00:05"
      conditions:
      - lastTransitionTime: "2024-03-29T14:33:19Z"
        status: "True"
        type: Ready
      - lastTransitionTime: "2024-03-29T14:33:19Z"
        status: "True"
        type: AssociateBMH
      lastUpdated: "2024-03-29T14:33:19Z"
      nics:
      - MAC: "52:54:00:01:00:05"
        ip: 192.168.133.33
        name: ens3
  ```

* I also examine the annotations and labels of the HostClaim resource. They
  have been enriched with information from the BareMetalHost resource.
* I create three secrets in the same namespace ``my-user-data``,
  ``my-meta-data``, and ``my-network-data``. I use the information from the
  status and meta data to customize the scripts they contain.
* I modify the HostClaim to point to those secrets and start the server:

  ```yaml
  apiVersion: metal3.io/v1alpha1
  kind: HostClaim
  metadata:
    name: my-host
  spec:
    online: true
    image:
      checksum: https://url_image.qcow2.md5
      url: https://url_image.qcow2
      format: qcow2
    userData:
      name: my-user-data
    networkData:
      name: my-network-data
    kind: baremetal
    hostSelector:
      matchLabels:
        infra-kind: medium
  ```

* The workload is launched. When the machine is fully provisioned, the boolean
  field ready in the status becomes true. I can stop the server by changing
  the online status. I can also perform a reboot by targeting specific
  annotations in the reserved ``host.metal3.io`` domain.
* When I destroy the host, the association is broken and another user can take
  over the server.

##### Server administrator point of view

As the owner of the bare metal servers, I would like to easily control the users
that can use my servers.
The BareMetalHost resource is extended with a field ``hostClaimNamespaces`` with
two optional subfields:

* ``matches``: the content of this field is a regular expression
  (in Golang re2 syntax). The name of the namespace where the HostClaim is located
  must match this regular expression.
* ``withLabel``: the content of the field is a list of strings representing
  labels. The namespace of the HostClaim must have a label belonging to the
  list.

#### Multi-tenancy

As an infrastructure administrator I would like to host several isolated
clusters.

All the servers in the data-center are registered as BareMetalHost in one or
several namespaces under the control of the infrastructure manager. Namespaces
are created for each tenant of the infrastructure. They create
standard cluster definitions in those namespaces.

When the cluster is started, a HostClaim is created for each Metal3Machine
associated to the cluster. The ``hostSelector`` is inherited from the
Metal3Machine. As in the original workflow, it is used to choose the BareMetalHost
associated with the cluster, but he associated BareMetalHost is not in the same
namespace as the HostClaim. The exact definition of the BareMetalHost remains
hidden from the cluster user, only parts of its status and metadata are copied
back to the HostClaim resource. With this information,
the data template controller has enough details to compute the different
secrets (userData, metaData and networkData) associated to the Metal3Machine.
Those secrets are linked to the HostClaim and, ultimately, to the
BareMetalHost.

When the cluster is modified, new Machine and Metal3Machine resources replace
the previous ones. The HostClaims follow the life-cycle of the Metal3Machines
and are destroyed with them. The BareMetalHosts are recycled and are bound to
new HostClaims, potentially belonging to other clusters.

#### Compute Resources in Another Cluster

As a user I would like to describe my cluster within a specific management
cluster. However the resources I intend to use (such as BareMetalHosts or
KubeVirt virtual machines) will be defined in a separate cluster.

The multi-tenancy extension for BareMetalHost is extended to HostClaims.
Metal3Machine field ``identityRef`` points to a
secret containing a kubeconfig object. This kubeconfig will be utilized instead
of the HostClaim controller service account to create and manage HostClaim
resources

```yaml
  apiVersion: metal3.io/v1alpha1
  kind: HostClaim
  metadata:
    name: host-claim-yyyy
    namespace: user1-ns
  spec:
    kind: baremetalhost
    credentials: bmh-cluster-credentials
    userData:
      name: user-data-yyyy
    hostSelector:
      ...
    image:
      checksum: https://image_url.qcow2.md5
      format: qcow2
      url: https://image_url.qcow2.md5
    online: true
---
apiVersion: v1
kind: Secret
metadata:
  name: user-data-yyyy
stringdata:
  format: cloud-config
  value: ....
```

#### Manager Cluster Bootstrap

As a cluster administrator I would like to install a new baremetal cluster from
a transient cluster.

The bootstrap process can be performed as usual from an ephemeral cluster
(e.g., a KinD cluster). The constraint that all resources must be in the same
namespace (Cluster and BareMetalHost resources) must be respected. The
BareMetalHost should be marked as movable.

The only difference with the behavior without Host is the presence of an
intermediate Host resource but the chain of resources is kept during the
transfer and the pause annotation is used to stop Ironic.

Because this operation is only performed by the administrator of a cluster
manager, the fact that the cluster definition and the BareMetalHosts are in
the same namespace should not be an issue.

Tenant clusters using BareMetalHosts in other namespaces cannot be pivoted. It
can be expected from a security point of vue as it would give the bare-metal
servers credentials to the tenants.

When servers are managed on a separate cluster using the identityRef field in
the machine template to access the BareMetalHost resources,
pivot can be performed as usual but the tenant cluster will still need the
cluster hosting Ironic.

## Design Details

### Implementation Details/Notes/Constraints

#### MetaData transfer between HostClaim and BareMetalHost resources

Most meta-data will be synchronized from the BareMetalHost to the HostClaim.

Two annotations (one for labels, one for annotations) on the HostClaim are
used to keep the knowledge of which meta-data were imported, so that we can
delete them when they disappear on the BareMetalHost.

Some specific annotations must be synchronized from the HostClaim to the
BareMetalHost (reboot, refresh inspection). A dedicated domain must be used.

#### Impact on Metal3Data controller

The Metal3Data controller must target either BareMetalHost or HostClaims
for some template fields:

* ``fromLabel`` and ``fromAnnotation`` where object is ``baremetalhost``.
* ``fromHostInterface`` and ``fromAnnotation`` in network definition

The solution is to introduce an intermediate abstract object.

#### Impact on NodeReuse

NodeReuse is implemented in the HostClaim controller with the same algorithm
as in the original workflow, but the content of the label on the BareMetalHost
is slightly different.

When a machine template is marked for node reuse, the generated HostClaim
``nodeReuse`` field contains a string identifying the deployment or the
control-plane it belongs to (using the algorithm that was used at the time of
BareMetalHost deletion).

When the HostClaim is deleted, the BareMetalHost is tagged with the node reuse
label ``infrastructure.cluster.x-k8s.io/node-reuse`` with a value
joining the namespace of the HostClaim and the value of the ``nodeReuse`` field.

When a new HostClaim is created, if the ``nodeReuse`` field is set, the
claim will try to bind a BareMetalHost with the label
``infrastructure.cluster.x-k8s.io/node-reuse`` set to the right value.

### Risks and Mitigations

#### Security Impact of Making BareMetalHost Selection Cluster-wide

The main difference between Metal3 machines and HostClaims it the
selection process where a HostClaim can be bound to a BareMetalHost
in another namespace. We must make sure that the binding is expected
from both the owner of BareMetalHost resources and the HostClaim resource,
especially when we upgrade the metal3 cluster api provider to a version
supporting HostClaim.

Choosing between HostClaims and BareMetalHost is done at the level of
the Metal3Machine controller through a configuration flag. When the HostClaim
mode is activated, all clusters are deployed with HostClaim resources.

For the server administrator, the solution is to enforce that BareMetalHost
that can be bound to a HostClaim have the field ``hostClaimNamespaces``
restricting authorized HostClaims to specific namespaces:

* ``.*`` lifts any restriction,
* ``n1|n2`` allow HostClaims from either ``n1``namespace or ``n2``,
* ``p-.*`` allow HostClaims from namespaces begining with prefix ``p-``

The owner of the HostClaim restricts the server through the use of selectors.
There can be only one server administrator and the tenants must trust the
semantic of the labels used for selection so a new mechanism is not necessary
on the tenant side.

#### Tenants Trying to Bypass the Selection Mechanism

The fact that a HostClaim is bound to a specific BareMetalHost will appear
as a label in the HostClaim and the HostClaim controller will use it to find
the associated BareMetalHost. This label could be modified by a malicious
tenant.

But the BareMetalHost has also a consumer reference. The label is only an
indication of the binding. If the consumer reference is invalid (different
from the HostClaim label), the label MUST be erased and the HostClaim
controller MUST NOT accept the binding.

#### Performance Impact

The proposal introduces a new resource with an associated controller between
the Metal3Machine and the BareMetalHost. There will be some duplication
of information between the BareMetalHost and the HostClaim status. The impact
for each node should still be limited especially when compared to the cost of
each Ironic action.

#### Impact on Other Cluster Api Components

There should be none: other components should mostly rely on Machine and Cluster
objects. Some tools may look at Metal3Machine conditions where some condition
names may be modified but the semantic of Ready condition will be preserved.

### Work Items

### Dependencies

### Test Plan

### Upgrade / Downgrade Strategy

### Version Skew Strategy

## Drawbacks

## Alternatives

### Multi-Tenancy Without HostClaim

We assume that we have a Kubernetes cluster managing a set of clusters for
cluster administrators (referred to as tenants in the following). Multi-tenancy
is a way to ensure that tenants have only control over their clusters.

There are at least two other ways for implementing multi-tenancy without
HostClaim. These methods proxy the entire definition of the cluster
or proxy the BareMetalHost itself.

#### Isolation Through Overlays

A solution for multi-tenancy is to hide all cluster resources from the end
user. In this approach, clusters and BareMetalHosts are defined within a single
namespace, but the cluster creation process ensures that resources
from different clusters do not overlap.

This approach was explored in the initial versions of the Kanod project.
Clusters must be described by the tenant in a git repository and the
descriptions are imported by a GitOps framework (argocd). The definitions are
processed by an argocd plugin that translates the YAML expressing the user's
intent into Kubernetes resources, and the naming of resources created by
this plugin ensures isolation.

Instead of using a translation plugin, it would be better to use a set of
custom resources. However, it is important to ensure that they are defined in
separate namespaces.

This approach has several drawbacks:

* The plugin or the controllers for the abstract clusters are complex
  applications if we want to support many options, and they become part of
  the trusted computing base of the cluster manager.
* It introduces a new level of access control that is distinct from the
  Kubernetes model. If we want tooling or observability around the created
  resources, we would need custom tools that adhere to this new policy, or we
  would need to reflect everything we want to observe in the new custom
  resources.

#### Ephemeral BareMetalHost

Another solution is to have separate namespaces for each cluster but
import BareMetalHosts in those namespaces on demand when new compute resources
are needed.

The cluster requires a resource that acts as a source of BareMetalHosts, which
can be parameterized on servers requirements and the number of replicas. The
concept of
[BareMetalPool](https://gitlab.com/Orange-OpenSource/kanod/baremetalpool)
in Kanod is similar to ReplicaSets for pods. This concept is also used in
[this proposal](https://github.com/metal3-io/metal3-docs/pull/268) for a
Metal3Host resource. The number of replicas must be synchronized with the
requirements of the cluster. It may be updated by a
[separate controller](https://gitlab.com/Orange-OpenSource/kanod/kanod-poolscaler)
checking the requirements of machine deployments and control-planes.

The main security risk is that when a cluster releases a BareMetalHost, it may
keep the credentials that provide full control over the server.
This can be resolved if those credentials are temporary. In Kanod BareMetalPool
obtain new servers from a REST API implemented by a
[BareMetalHost broker](https://gitlab.com/Orange-OpenSource/kanod/brokerdef).
The broker implementation utilizes either the fact that Redfish is in fact an
HTTP API to implement a proxy or the capability of Redfish to create new users
with a Redfish ``operator`` role to implemented BareMetalHost resources with
a limited lifespan.

A pool is implemented as an API that is protected by a set of credentials that
identify the user.

The advantages of this approach are:

* Support for pivot operation, even for tenant clusters, as it provides a
  complete bare-metal-as-a-service solution.
* Cluster administrators have full access to the BMC and can configure servers
  according to their needs using custom procedures that are not exposed by
  standard Metal3 controllers.
* Network isolation can be established before the BareMetalHost is created in
  the scope of the cluster. There is no transfer of servers from one network
  configuration to another, which could invalidate parts of the introspection.

The last drawback can be mitigated by having different network configurations
for the provisioning of servers and for their use as cluster node.

The disadvantages of the BareMetalPool approach are:

* The implementation of the broker with its dedicated server is quite complex.
* To have full dynamism over the pool of servers, a new type of autoscaler is
  needed.
* Unnecessary inspection of servers are performed when they are transferred
  from a cluster (tenant) to another.
* The current implementation of the proxy is limited to the Redfish protocol
  and would require significant work for IPMI.

## References
