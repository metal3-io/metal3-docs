<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Generating Metadata and Network data per node in CAPM3

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
         * [User Stories [optional]](#user-stories-optional)
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

[Tools for generating]: https://github.com/ekalinin/github-markdown-toc

## Summary

Cloud-init templates offer a very powerful feature to render the configuration
at runtime based on metadata given by Ironic. We want to take advantage of this
feature to render node specific configuration for nodes in a machine deployment
or in a control plane kubeadm object. In addition, we want to be able to
generate node specific network configuration in CAPM3 based on a template.

This design proposal introduces a new data template object that contains
templates for network data and metadata secret generation per node. Once
generated, the secrets are passed to Ironic for each node of a machine
deployment or control plane.

This proposal introduces a new `metaData` field in BareMetalHost and in
Metal3Machine, a new `networkData` field in
Metal3Machine and a new `dataTemplate` field in Metal3machine that allows
generating the metadata and network data secrets content.

## Motivation

When deploying a machine deployment or a control plane with CAPI (v1alpha3), the
KubeadmConfig applied is the same for all the nodes. However, we would want
control on some fields, such as the node name for example. This can be a
variable in the cloud-init template, but it needs to be provided through Ironic
as metadata. And the metadata needs to be different for each of the nodes. We
might also want some varying network configuration per node.
For example we would want the nodes of a machine deployment to have names like
`worker-np1-0`, `worker-np1-1`, `worker-np1-2` etc. and those names to be
unrelated with the BareMetalHost names (that might be `machine-xyz`, reflecting
some hardware related information, not Kubernetes node information).
Hence we want a way to generate a node-specific metadata and network data for a
machine deployment or Kubeadm Control Plane and pass it down to Ironic.

### Goals

The goals are :

- to add a `metaData` field in BareMetalHost to have it configurable
  for Ironic, and in the Metal3Machine for CAPM3 to be able to pass it down to
  BareMetalHost.
- add a `networkData` field in Metal3Machine
- introduce new objects containing information to get the data per node,
  or generate it, and store the values in use to not duplicate them.
- The reconciliation of the Metal3Machine would use the data template object to
  properly fill the `metaData` and `networkData` field of BareMetalHost


### Non-Goals

TBA

## Proposal

### User Stories [optional]

#### Story 1

As a user, I want to define a template for node-specific metadata to pass
through ironic to fill the cloud-init template. This template should be rendered
for each node, and be re-used during upgrade.

#### Story 2

As a user, I want to give my own metadata to Ironic as a field on
Metal3Machine and BareMetalHost.

#### Story 3

As a user, I want to define a template for node-specific networking to pass
through ironic to cloud-init. This template should be rendered for each node,
and be re-used during upgrade.

#### Story 4

As a user, I want to give my own network configuration for cloud-init as a field
on Metal3Machine

### Implementation Details/Notes/Constraints

- The metadata field should contain some required element, such as UUID, that is
  required by cloud-init.
- It must be possible to give metadata and network data secrets without using
  the data template object
- Not providing any data template object and any content in the `metaData` and
  `networkData` fields of Metal3Machine should result in the same behavior as
  before this proposal is implemented
- the data template would contain templates to generate both the metadata and/or
  the network data.
- Generating the metadata or the networkdata should work regardless whether the
  other template was provided.
- Documentation of this feature would be very important.
- The controllers must be able to recreate all status objects, i.e. no
  necessary information should be stored in the status without being recoverable

### Risks and Mitigations

From a user point of view, if this is not well documented or understood, it
could lead to unexpected errors or behaviors. The errors have to be easily
understandable.

## Design Details

BareMetalHost would have an added field `metaData` in the `Spec` pointing to a
secret containing the metadata map. Bare Metal Operator would then pass this map
to Ironic.

The Metal3Machine will be modified as follow:

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3Machine
metadata:
  name: machine-1
  namespace: default
spec:
  dataTemplate:
    name: nodepool-1
    namespace: default
status:
  renderedData:
    name: nodepool-1-0
    namespace: default
  metaData:
    name: machine-1-metadata
    namespace: default
  networkData:
    name: machine-1-networkdata
    namespace: default
```

or alternatively

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3Machine
metadata:
  name: machine-1
  namespace: default
spec:
  metaData:
    name: machine-1-metadata
    namespace: default
  networkData:
    name: machine-1-networkData
    namespace: default
status:
  metaData:
    name: machine-1-metadata
    namespace: default
  networkData:
    name: machine-1-networkData
    namespace: default
```

A `metaData` field would be added in the spec and in the status, consisting of a
secret reference containing the name and the namespace of the secret containing
the metaData for this Metal3Machine. A `networkData` field would be added to the
spec and to the status objects, consisting of a secret
reference containing the name and the namespace of the secret containing the
network configuration for this Metal3Machine.

A `dataTemplate` field would be added, consisting of an object reference
to a Metal3DataTemplate object containing the templates for
the metadata and network data generation for this Metal3Machine.
A `renderedData` field will be added in the status and will be a reference to
the Metal3Data object created for this machine. If the dataTemplate field is set
but either the `renderedData`, `metaData` or `networkData` fields in the status
are unset, then the Metal3Machine controller will wait until it can find the
Metal3Data object and the rendered secrets. It will then populate those fields.

The secret containing the metaData or the network data could be provided by the
user directly using the `metaData` or `networkData` fields in the spec of the
object.

When CAPM3 controller will set the different fields in the BareMetalHost,
it will reference the metadata secret and the network data secret
in the BareMetalHost. If any of the `metaData` or `networkData` status fields
are unset, that field will also remain unset on the BareMetalHost.

When the Metal3Machine gets deleted, the CAPM3 controller will remove its
ownerreference from the data template object. This will trigger the deletion of
the generated Metal3Data object and the secrets generated for this machine.

A new object would be created, a Metal3DataTemplate type.

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
  metaData: |
    abc: def
    local-hostname: {{ machineName }}
    index: {{ index }}
  networkData: |
    {
        "links": [
            {
                "id": "enp1s0",
                "type": "phy",
                "ethernet_mac_address": "{{ bareMetalHostMACByName "eth0" }}"
            },
            {
                "id": "enp2s0",
                "type": "phy",
                "ethernet_mac_address": "{{ bareMetalHostMACByName "eth1" }}"
            }
        ],
        "networks": [
            {
                "id": "Provisioning",
                "type": "ipv4_dhcp",
                "link": "enp1s0"
            },
            {
                "id": "Baremetal",
                "type": "ipv4_dhcp",
                "link": "enp2s0",
            }
        ],
        "services": [
            {
                "type": "dns",
                "address": "8.8.8.8"
            }
        ]
    }
```

This object will be reconciled by its own controller. When reconciled,
the controller will add a label pointing to the Metal3Cluster that has nodes
linking to this object. The spec contains a `metaData` and a `networkData` field
that contain a template of the values that will be rendered for all nodes.

The `metaData` field should contain a map of strings in yaml format, while
`networkData` should contain a json string that fulfills the requirements of
[Nova network_data.json](https://docs.openstack.org/nova/latest/user/metadata.html#openstack-format-metadata).
The format definition can be found
[here](https://docs.openstack.org/nova/latest/_downloads/9119ca7ac90aa2990e762c08baea3a36/network_data.json).
Those formats must be respected

The values will be [go templates](
https://golang.org/pkg/text/template/). Multiple functions would be available :

- **machineName** : returns the Machine name
- **metal3MachineName** : returns the Metal3Machine name
- **bareMetalHostName** : returns the BareMetalHost name
- **index** : returns the Metal3Machine index for the Metal3Metadata object.
  The index starts from 0.
- **indexWithOffset** : takes an integer as parameter and returns the sum of
  the index and the offset parameter
- **indexWithStep** : takes an integer as parameter and returns the
  multiplication of the index and the step parameter
- **indexWithOffsetAndStep** OR **indexWithStepAndOffset**: takes two
  integers as parameters, order depending on the function name, and returns the
  sum of the offset and the multiplication of the index and the step.
- **index*Hex** : All the `index` functions can be suffixed with `Hex` to
  get the same value in hexadecimal format.
- **bareMetalHostMACByName**: takes a string as parameter and returns the MAC
  address of the nic with the name matching the parameter. This function
  operates over the list of NICs in the `status.hardwareDetails.NIC` field of
  the BareMetalHost.


The output of the controller would be a Metal3Data object,one per node linking to the
Metal3DataTemplate object and the associated secrets

The Metal3Data object would be:

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3Data
metadata:
  name: nodepool-1-0
  namespace: default
  ownerReferences:
  - apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
    controller: true
    kind: Metal3DataTemplate
    name: nodepool-1
spec:
  index: 0
  metaData:
    name: machine-1-metadata
    namespace: default
  networkData:
    name: machine-1-metadata
    namespace: default
  metal3Machine:
    name: machine-1
    namespace: default
```
The Metal3Data will contain the index of this node, and links to the secrets
generated and to the Metal3Machine using this Metal3Data object.

If the Metal3DataTemplate object is updated, the generated secrets will not be
updated, to allow for reprovisioning of the nodes in the exact same state as
they were initially provisioned. Hence, to do an update, it is necessary to do
a rolling upgrade of all nodes.

The reconciliation of the Metal3DataTemplate object will also be triggered by
changes on Metal3Machines. In the case that a Metal3Machine gets modified, if
the `dataTemplate` references a Metal3DataTemplate, that object will be reconciled.
There will be two cases:

- An already generated Metal3Data object exists with an ownerReference to this
  Metal3Machine. In that case, the reconciler will verify that the required
  secrets exist. If they do not, they will be created.
- if no secret exists with an ownerReference to this Metal3Machine, then the
  reconciler will create one and fill the respective field with the secret name.

To create a Metal3Data object, the controller will select an index for that
Metal3Machine. The selection happens by selecting the lowest available index.
The controller will list all existing Metal3Data object linked to this
Metal3DataTemplate and create a list of unavailable indexes. It will fill it by
extracting the index from the Metal3Data names.

Once the next available index is found, it will create the Metal3Data object.
The name would be a concatenation of the Metal3DataTemplate name and index.
Upon conflict, it will fetch again the list to consider the new list of 
Metal3Data. Upon success, it will render the content values, and create
the secrets containing the rendered data. The controller will generate the
content based on the `metaData` or `networkData` field of the Metal3DataTemplate
Specs.

The name of the secret will be made of a prefix and the index. The Metal3Machine
object name will be used as the prefix. A `-metadata-` or `-networkdata-` will
be added between the prefix and the index.

The generated secret will be similar to :

```yaml
apiVersion: v1
kind: Secret
type: infrastructure.cluster.k8s.io/secret
metadata:
  name: nodepool-1-metadata-0
  namespace: default
  ownerReferences:
  - apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
    controller: true
    kind: Metal3Machine
    name: machine-1
spec:
  metaData: |
    abc: def
    local-hostname: worker-np1-0
```

The secret will contain the generated data for the host. Once the
secret reference field on the Metal3Machine is set, the Metal3Machine controller
will proceed with the provisioning.

### Work Items

Here are the different steps :

- Add the metadata field in BareMetalHost (On-going)
- Add the metal3DataTemplate object
- Add the CAPM3 logic for the dataTemplate reconciler
- Modify the Metal3Machine reconciler to make use of the metadata and network
  data and set it on the BareMetalHost.
- update the documentation
- ensure that the tests are created / updated accordingly

### Dependencies

* [go templates](https://golang.org/pkg/text/template/)

### Test Plan

This can be added to our e2e tests. The Metal3DataTemplate object would be
added as part of the deployment and cloud-config modified to add variables to
make use of it.

### Upgrade / Downgrade Strategy

If none of the new fields are set, the behavior will be identical to the current
way the components work. In order to take this feature in use, the users must
take the fields in use.

During an upgrade, nothing is required to be done to keep things working as they
were. In order to start using this feature, the user would need to create the
Metal3DataTemplate object, and then do a rolling upgrade to change the
Metal3Machines (or Metal3MachineTemplates), and the KubeadmConfigs (or
KubeadmConfigTemplates or KubeadmControlPlane).

### Version Skew Strategy

This will require that both CAPM3 and BMO support this feature.

## Drawbacks [optional]

Even though they can be set separately, this brings the metadata and network
data in the same object.

## Alternatives [optional]

It would be possible to duplicate the templates to separate metadata and network
data. But this would add complexity.

## References

[metadata PR in Bare Metal Operator](https://github.com/metal3-io/baremetal-operator/pull/448)
