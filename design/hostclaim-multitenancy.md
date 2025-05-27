<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

<!-- cSpell:ignore Sylva Schiff Kanod ArgoCD GitOps -->
# HostClaim: Sharing BareMetalHost between Multiple Tenants

## Status

Provisional

## Summary

We introduce a new Custom Resource (named HostClaim) which will facilitate
the creation of multiple clusters for different tenants. A HostClaim decouples
the client need from the actual implementation of the
compute resource: it establishes a security boundary.

A HostClaim expresses that one wants to start a given
OS image with an initial configuration (typically cloud-init or ignition
configuration files) on a compute resource that meets a set of requirements
(host selectors).
The status and metadata of the HostClaim provide the necessary information
for the end user to define and manage his workload on the compute resource,
but they do not grant full control over the resource (typically, BMC
credentials of servers are not exposed to the tenant).

## Motivation

The standard approach to implementing multi-tenancy in Cluster API is to follow the
[multi-tenancy contract](https://cluster-api.sigs.k8s.io/developer/architecture/controllers/multi-tenancy#contract).

To adhere to this contract with cluster-api-provider-metal3, the clusters must
be placed in different namespaces, and the BareMetalHost objects must be defined
in those namespaces. In this setup, the tenants are the owners of the servers,
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
in the same namespace, but we also need a solution that provides sufficient control
and visibility over the workload deployed on those servers so that tenants
can maintain the level of information they have had so far.

This proposal tackles the objective through three changes:

* It introduces a new resource called HostClaim that decouples
  the definition of the workload performed by
  the Metal3 machine controller from the actual compute resource.
  This resource acts as a security boundary.
* It uses the HardwareData resource as the only visible resource for end-users,
  containing both hardware details and metadata used for selection and template
  specialization.
* It introduces a HostDeployPolicy resource that describes the namespaces that contain
  the HostClaims authorized to be bound to BareMetalHosts in the namespace of the
  HostDeployPolicy resource.

### Goals

* Split responsibilities between infrastructure teams (role *infrastructure manager*),
  who manage servers, and cluster administrators (role *cluster manager*),
  who create update and scale bare-metal clusters deployed
  on those servers, using traditional Kubernetes RBAC to ensure isolation.
* Define a resource where a user can request a compute resource to execute
  an arbitrary workload described by an OS image and an initial configuration.
  The user (role *end-user*, a cluster manager is an end-user) does not need
  to know exactly which BareMetalHost is used and does not control its BMC.
* Use BareMetalHosts defined in other clusters. Support, as described here,
  will be limited to use with Cluster API as it will be handled at the
  level of the Metal3Machine.

### Non-Goals

* Compute resource quotas. The HostClaim resource should make it possible to
  develop a framework to limit the number and size of compute resources allocated
  to a tenant, similar to how quotas work for pods. However, the specification
  of such a framework will be addressed in another design document.
* Implementing network isolation between tenant clusters using a common set
  of BareMetalHosts.

## Proposal

### User Stories

#### Deployment of Simple Workloads

##### User Point of View

As an *end-user*, I would like to execute a workload on an arbitrary server.
Servers are managed by a hardware administrator.

The OS image is available in qcow format on a remote server at ``url_image``.
It supports cloud-init, and a script can launch the workload at boot time
(e.g., a systemd service).

The cluster offers bare-metal as a service using the Metal3 baremetal-operator.
However, as a regular user, I am not allowed to directly access the definitions
of the servers, but I can read the result of the inspection (HardwareData).
The HardwareData resource also contains a copy of the metadata (labels and
annotations of the resource) of the BareMetalHost visible to the end-user.

All HardwareData are labeled with an ``infra-kind`` label whose
value depends on the characteristics of the hardware. This label was set
by the hardware administrator on the BareMetalHost when it was defined.

* I can read HardwareData in the namespace ``infra``. I can find which selector
  I should use to locate a machine with the right hardware details.
* I create a resource with the following content:

  ```yaml
  apiVersion: metal3.io/v1alpha1
  kind: HostClaim
  metadata:
    name: my-host
    namespace: myns
  spec:
    online: false

    hostSelector:
      matchLabels:
        infra-kind: medium
  ```

* After a while, the system associates the claim with a real server, and
  the resource's status is populated with the following information:

  ```yaml
  status:
    bareMetalHost:
      name: server-123
      namespace: infra
    conditions:
    - lastTransitionTime: "2024-03-29T14:33:19Z"
      status: "True"
      type: Ready
    - lastTransitionTime: "2024-03-29T14:33:19Z"
      status: "True"
      type: AssociateHost
    lastUpdated: "2024-03-29T14:33:19Z"
  ```

  The BareMetalHost resource is updated so that the consumerRef field points
  to the HostClaim resource.

* I create three secrets in the same namespace: ``my-user-data``,
  ``my-metadata``, and ``my-network-data``. I use the information from the
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
    hostSelector:
      matchLabels:
        infra-kind: medium
  ```

  Note: customDeploy must be supported as an alternative to images.
* The workload is launched. When the machine is fully provisioned, the boolean
  field ready in the status becomes true. I can stop the server by changing
  the online status. I can also perform a reboot by adding a
  ``reboot.metal3.io`` annotation on the HostClaim as I would do on the
  BareMetalHost resource.
* When I destroy the host, the association is broken and another user can take
  over the server.

##### Server Administrator Point of View

As the owner of the bare-metal servers, I would like to easily control the users
that can use my servers and manage the information I share about the servers.

In each namespace hosting BareMetalHosts, I define one
or several HostDeployPolicy resources. Each resource defines a filter on the
namespaces of the HostClaims in the field ``hostClaimNamespaces``.

The specification of the HostDeployPolicy contains one or several of the
optional fields:

* ``namespaces``: the content of this field is a list of namespaces. The name of
  the namespace where the HostClaim is must be a member of the list.
* ``nameMatches``: the content of this field is a regular expression
  (in Golang re2 syntax). The name of the namespace where the HostClaim is located
  must match this regular expression.
* ``withLabels``: the content of the field is a list of strings representing
  labels. The namespace of the HostClaim must have a label belonging to the
  list.

To successfully match, the namespace must fulfill the constraints of all the
defined fields. An empty HostDeployPolicy authorizes all namespaces.
A HostClaim is authorized to bind a BareMetalHost if and only if the namespace
of the HostClaim is successfully filtered by at least one HostDeployPolicy in
the namespace of the BareMetalHost. In that case, the binding between the
HostClaim and the BareMetalHost is authorized.

A HostDeployPolicy specification also contains a field ``metadataCopy``. It defines
rules for which annotations are copied (``annotationsMatch``) and which
labels are copied (``labelsMatch``). Both fields contain regular expressions.

For example,

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostDeployPolicy
metadata:
  name: policy
  namespace: infra
spec:
  hostClaimNamespaces:
    namespaces:
    - cluster1
    - cluster2
  metadataCopy:
    annotationsMatch: 'mydomain/.*'
    labelsMatch: 'selectors/.*'
```

will make the BareMetalHosts in the namespace ``infra`` available to HostClaims
in the namespaces ``cluster1`` and ``cluster2``. All labels in the domain ``selectors``
will be available for selection as annotations in ``mydomain`` for constructing
cloud-init ``metadata``.

#### Multi-tenancy

As an infrastructure administrator I would like to host several isolated
clusters.

All the servers in the data-center are registered as BareMetalHost in one or
several namespaces under the control of the infrastructure manager. Namespaces
are created for each tenant of the infrastructure. They create
standard cluster definitions in those namespaces.

When the cluster is started, a HostClaim is created for each Metal3Machine
associated with the cluster. The ``hostSelector`` is inherited from the
Metal3Machine. As in the original workflow, it is used to choose the BareMetalHost
associated with the cluster, but the associated BareMetalHost is not in the same
namespace as the HostClaim. The exact definition of the BareMetalHost remains
hidden from the cluster user; only a small parts of its status is copied
back to the HostClaim resource (actual power state). The status of the HostClaim
contains a reference to the BareMetalHost and so to the HardwareData that is
readable by the end user.

With the help of HardwareData, the data template controller has enough details to
compute the different secrets (userData, metaData and networkData) associated to
the Metal3Machine. These secrets are linked to the HostClaim and, ultimately, to
the BareMetalHost.

When the cluster is modified, new Machine and Metal3Machine resources replace
the previous ones. The HostClaims follow the life-cycle of the Metal3Machines
and are destroyed with them. The BareMetalHosts are recycled and are bound to
new HostClaims, potentially belonging to other clusters.

#### Compute Resources in Another Cluster

As a user, I would like to describe my cluster within a specific management
cluster. However, the resources I intend to use (such as BareMetalHosts or
KubeVirt virtual machines) will be defined in a separate cluster.

The [multi-tenancy extension](./cluster-api-provider-metal3/multi-tenancy_contract.md)
for BareMetalHost is extended to HostClaims. The Metal3Machine field ``identityRef`` points to a
secret containing a kubeconfig object. This kubeconfig will be utilized instead
of the HostClaim controller service account to create and manage HostClaim
resources on the remote cluster.

HostClaims do not have an identityRef field; they must be located on the same
cluster as the BareMetalHost.

#### Bootstrap of the Management Cluster

As a cluster administrator, I would like to install a new bare-metal cluster from
a transient cluster.

The bootstrap process can be performed as usual from an ephemeral cluster
(e.g., a KinD cluster). The constraint that all resources must be in the same
namespace (Cluster and BareMetalHost resources) must be respected. The
BareMetalHost should be marked as movable.

The only difference with the behavior without a HostClaim is the presence of an
intermediate Host resource, but the chain of resources is maintained during the
transfer and the pause annotation is used to stop Ironic.

Because this operation is only performed by the administrator of a cluster
manager, the fact that the cluster definition and the BareMetalHosts are in
the same namespace should not be an issue.

Tenant clusters using BareMetalHosts in other namespaces cannot be pivoted. This
is expected from a security point of view, as it would give the bare-metal
servers credentials to the tenants.

When servers are managed on a separate cluster using the identityRef field in
the machine template to access the BareMetalHost resources,
pivoting can be performed as usual, but the tenant cluster will still need the
cluster hosting Ironic.

## Design Details

### Implementation Details/Notes/Constraints

#### Split between cluster-api-provider-metal3 and baremetal-operator

The HostClaim controller is part of the baremetal-operator project. A
BareMetalHost controller must create the HardwareData with the correct metadata
and update those metadata when they are modified on the BareMetalHost. To
reduce the load, it may be interesting to have a different set of events
that trigger the main BareMetalHost controller from those that trigger
the synchronization of metadata.

The introduction of HostClaims transfers the BareMetalHost selection process
from the cluster-api-provider-metal3 project to the baremetal-operator project

As we need to maintain the legacy behavior, this will not simplify the code of
the provider.

#### Impact on Metal3Data controller

The Metal3Data controller must target either BareMetalHost or HostClaims
(specifically the HardwareData pointed to by the HostClaim) for some template fields:

* ``fromLabel`` and ``fromAnnotation`` where object is ``baremetalhost``.
* ``fromHostInterface`` and ``fromAnnotation`` in the network data definition

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
combining the namespace of the HostClaim and the value of the ``nodeReuse`` field.

When a new HostClaim is created, if the ``nodeReuse`` field is set, the
claim will attempt to bind to a BareMetalHost with the label
``infrastructure.cluster.x-k8s.io/node-reuse`` set to the correct value.

### Risks and Mitigations

#### Handling of Roles and HostDeployPolicy

Roles and HostDeployPolicy have complementary roles but must be
maintained in a coordinated manner.
Each cluster manager must have a namespace for his HostClaims. This can
be the cluster namespace or another one if the cluster description
and the BareMetalHosts are not in the same management cluster. In this
namespace, he must have full rights on HostClaims and the associated secrets.

He should also have read rights (but no modification permissions) on HardwareData
in at least all the namespaces that allow his own HostClaim namespace for
binding with BareMetalHost. HostDeployPolicy should be consistent with those
rights but nothing will ensure the coherence. Deployment may then fail as the remote
user will not be able to access the HardwareData resource to build cloud-init metadata.

#### Security Impact of Making BareMetalHost Selection Cluster-wide

The main difference between Metal3 machines and HostClaims is the
selection process, where a HostClaim can be bound to a BareMetalHost
in another namespace. We must ensure that the binding is expected
by both the owner of BareMetalHost resources and the HostClaim resource,
especially when we upgrade the metal3 Cluster API provider to a version
supporting HostClaim.

Choosing between HostClaims and BareMetalHost is done at the level of
the Metal3Machine controller through a configuration flag. When the HostClaim
mode is activated, all clusters are deployed with HostClaim resources.

For the server administrator, the HostDeployPolicy restricts the BareMetalHosts
that can be used by HostClaims and the namespaces of those resources.

The owner of the HostClaim restricts the server through the use of selectors.
There can be only one server administrator, and the tenants must trust the
semantics of the labels used for selection, so a new mechanism is not necessary
on the tenant side.

#### Tenants Trying to Bypass the Selection Mechanism

The fact that a HostClaim is bound to a specific BareMetalHost will appear
in the status of the HostClaim and the HostClaim controller will use it to find
the associated BareMetalHost. It could be modified by a malicious tenant if the
RBAC privileges are too lenient on the HostClaim namespace.

But the BareMetalHost has also a consumer reference. The HostClaim status is only an
indication of the binding. If the consumer reference and the HostClaim status
differ, priority is given to the consumer reference on the BareMetalHost.

#### Performance Impact

The proposal introduces a new resource with an associated controller between
the Metal3Machine and the BareMetalHost. There will be some duplication
of information between the BareMetalHost and the HostClaim status. The impact
for each node should still be limited especially when compared to the cost of
each Ironic action.

#### Impact on Other Cluster Api Components

There should be none: other components should mostly rely on Machine and Cluster
objects. Some tools may look at Metal3Machine conditions where some condition
names may be modified but the semantics of the Ready condition will be preserved.

### Work Items

### Dependencies

### Test Plan

### Upgrade / Downgrade Strategy

### Version Skew Strategy

## Drawbacks

## Alternatives

### Multi-Tenancy Without HostClaim

We assume that we have a Kubernetes cluster managing a set of clusters for
cluster administrators (referred to as tenants hereafter). Multi-tenancy
is a way to ensure that tenants have control only over their clusters.

There are at least two other ways to implement multi-tenancy without
HostClaim. These methods either proxy the entire definition of the cluster
or proxy the BareMetalHost itself.

#### Isolation Through Overlays

A solution for multi-tenancy is to hide all cluster resources from the end
user. In this approach, clusters and BareMetalHosts are defined within a single
namespace, but the cluster creation process ensures that resources
from different clusters do not overlap.

This approach was explored in the initial versions of the Kanod project.
Clusters must be described by the tenant in a Git repository, and the
descriptions are imported by a GitOps framework (ArgoCD). The definitions are
processed by an ArgoCD plugin that translates the YAML expressing the user's
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
are needed. This solution was explored in a research project named Kanod.

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
retain the credentials that provide full control over the server.
This can be resolved if those credentials are temporary. In Kanod, a BareMetalPool
obtains new servers from a REST API implemented by a
[BareMetalHost broker](https://gitlab.com/Orange-OpenSource/kanod/brokerdef).
The broker implementation utilizes either the fact that Redfish is, in fact, an
HTTP API to implement a proxy, or the capability of Redfish to create new users
with a Redfish ``operator`` role to implement BareMetalHost resources with
a limited lifespan.

A pool is implemented as an API that is protected by a set of credentials that
identify the user.

The advantages of this approach are:

* Support for pivot operation, even for tenant clusters, as it provides a
  complete bare-metal-as-a-service solution.
* Cluster administrators have full access to the BMC and can configure servers
  according to their needs using custom procedures that are not exposed by
  standard Metal3 controllers.
* Network isolation can be established before the BareMetalHost is created within
  the scope of the cluster. There is no transfer of servers from one network
  configuration to another, which could invalidate parts of the introspection.

The last drawback can be mitigated by having different network configurations
for the provisioning of servers and for their use as cluster node.

The disadvantages of the BareMetalPool approach are:

* The implementation of the broker with its dedicated server is quite complex.
* To have full dynamism over the pool of servers, a new type of autoscaler is
  needed.
* Unnecessary inspection of servers are performed when they are transferred
  from one cluster (tenant) to another.
* The current implementation of the proxy is limited to the Redfish protocol
  and would require significant work for IPMI.

### Alternative Implementations of HostClaims

#### Not Using HardwareData

The first proof of concept of HostClaims copied inspection data from the BareMetalHost
to the HostClaim. There was no inventory of available hardware visible to the end-user.
The code was also more complex especially because of metadata synchronization (details in
the next section).

#### Alternative Handling of Metadata

Here are some alternative methods for handling metadata associated with BareMetalHosts
and used by the Metal3 provider (selection and construction of cloud-init/ignition
data):

* **Keep metadata in BareMetalHost. Copy to HostClaims** : the purpose of HostClaims is to hide
  BareMetalHost from users. Selectors and important metadata values would be
  hidden from their user. Even if infrastructure managers can convey information
  through other means, this is awkward. The proof of concept had complex rules to maintain
  HostClaim metadata synchronized with BareMetalHosts.
* **Metadata in HardwareData without synchronization** : infrastructure managers
  must then create empty HardwareData to define the metadata visible to end users. This simplifies
  HostDeployPolicy. The main drawback is that it is a non-compatible change with current deployments
  of BareMetalHosts. Process annotating BareMetalHosts automatically would require modifications.
* **Metadata in a new custom resource** : This custom resource would only exist for this purpose.
  Having too many custom resources for a single concept is not a good idea.
* **Keep some metadata on HardwareData not automatically synchronized with BareMetalHost metadata** :
  metadata on HardwareData with keys that are not explicitly handled by the HostDeployPolicy would
  be preserved. This is complex. The only purpose would be for automatic processes labeling HardwareData
  based on their content, but they can always label BareMetalHost instead of HardwareData. The cost
  of maintaining such partial synchronization is high.

## References
