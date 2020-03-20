<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Generating Metadata per node in CAPM3 down to Ironic

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
or in a control plane kubeadm object. This design proposal introduces a new
metadata object that contains a list of items to provide metadata to Ironic for
each node of a machine deployment or control plane.

This proposal introduces a new metadata field in BareMetalHost and in
Metal3Machine, and a metadataTemplate field in Metal3machine that allows
generating the metadata content. It also introduces a new Metadata object that
stores the list of metadata items for each node.

## Motivation

When deploying a machine deployment or a control plane with CAPI (v1alpha3), the
KubeadmConfig applied is the same for all the nodes. However, we would want
control on some fields, such as the node name for example. This can be a
variable in the cloud-init template, but it needs to be provided through Ironic
as metadata. And the metadata needs to be different for each of the nodes.
For example we would want the nodes of a machine deployment to have names like
`worker-np1-0`, `worker-np1-1`, `worker-np1-2` etc. and those names to be
unrelated with the BareMetalHost names (that might be `machine-xyz`, reflecting
some hardware related information, not Kubernetes node information).
Hence we want a way to generate a node-specific metadata for a machine
deployment and pass it down to Ironic as metadata.

### Goals

The goals are :

- to add a metadata field in BareMetalHost to have it configurable
  for Ironic, and in the Metal3Machine for CAPM3 to be able to pass it down to
  BareMetalHost.
- introduce new objects containing information to get the metadata per node,
  or generate it, and store the values in use to not duplicate them.
- The reconciliation of the Metal3Machine would use those metadata objects to
  properly fill the metadata field of BareMetalHost


### Non-Goals

TBA

## Proposal

### User Stories [optional]

#### Story 1

As a user, I want to define a set of node-specific element to give as metadata
through ironic to fill the cloud-init template. Those elements should be used
for one node only, and be re-used during upgrade.

#### Story 2

As a user, I want to give my own metadata to Ironic as a field on BareMetalHost.

### Implementation Details/Notes/Constraints

- The metadata field should contain some required element, such as UUID, that is
  required by cloud-init.
- Not providing any metadata object and any content in the metadata fields of
  Metal3Machine should result in the same behaviour as before this proposal is
  implemented
- the metadata template field would be a list of objects giving the key of the
  metadata and information on how to retrieve the value, such as an object
  reference to the metadata object and the key in that object to use.
- Documentation of this feature would be very important.
- The controllers must be able to recreate all status objects, i.e. no
  necessary information should be stored in the status without being recoverable

### Risks and Mitigations

From a user point of view, if this is not well documented or understood, it
could lead to unexpected errors or behaviours. The errors should be easily
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
  metaData:
    ghi: jkl
  metaData:
    configRef:
      name: nodepool-1
      namespace: default
    dataSecret:
      name: machine-1-0
      namespace: default
```

A `metaData` field would be added, consisting of an object reference called
`configRef` referencing a new object type Metal3Metadata, and an object
reference named `dataSecret` containing the name and the namespace of the secret
containing the metaData for this Metal3Machine. If configRef is set but the
dataSecret is not, then the Metal3Machine controller will wait until dataSecret
is set.

The secret containing the metaData could be provided by the user directly.

When CAPM3 controller will select a BaremetalHost and set the different
fields there, it will reference the metadata secret in the BareMetalHost. If
both `configRef` and `dataSecret` fields are unset, no metadata will be
provided to the BareMetalHost.

When the Metal3Machine gets deleted, the CAPM3 controller will remove its
references from the metadata secret, removing the finalizer if no other
Metal3Machines are listed in the owner references, and then deleting it.

A new object would be created, a Metal3Metadata type.

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3Metadata
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
    abc: def
    local-hostname: worker-np1-{{ getIndex }}
status:
  indexes:
    "0": "machine-1"
  secrets:
    "machine-1":
        name: machine-1-0
        namespace: default
  lastUpdated: "2020-03-25T12:33:25Z"
```

This object will be reconciled by its own controller. When reconciled,
the controller will add an OwnerReference to the Metal3Cluster that has nodes
linking to this object. The spec contains a metaData field that contains a map
of key and values that will be rendered for all nodes.

The values will be [go templates](
https://golang.org/pkg/text/template/). A function `getIndex` will return
the lower int that is not yet in use, and a function `getIndexWithOffset` will
return the sum of the index and the given offset.

The output of the controller would be secrets, one per node linking to the
Metal3Metadata object.

If the Metal3Metadata object is updated, the reconciliation loop will update all
the secrets that have this object in their OwnerReferences.

The reconciliation of the Metal3Metadata object will also be triggered by
changes on Metal3Machines. In the case that a Metal3Machine gets created, if the
`configRef` references a Metal3Metadata, that object will be reconciled. If the
dataSecret is set, that will be a no-op reconciliation loop. If it is unset,
there will be two cases:

- An already generated secret exists with an ownerReference to this
  Metal3Machine. In that case, the reconciler will update it and fill the
  `dataSecret` field on the Metal3Machine with the secret name.
- if no secret exists with an ownerReference to this Metal3Machine, then the
  reconciler will create one and fill the `dataSecret` with the secret name.

To create a metadata secret, the controller will generate the metaData content
based on the metaData field of the Metal3Metadata Specs. It will render the
metaData, selecting the lowest available index from the status indexes map. If
that map is empty, it will build it by making a list of the already
existing secrets with an ownerReference to this Metal3Metadata object, building
a map of names of the machines and index used by the machine, extracting the
index from the secret names. Once the next available index is found, it will
update the Metal3Metadata object. Upon conflict, it will immediately requeue to
consider the new state of Metal3Metadata. Upon success, it will render
the metaData values, and create a secret containing the rendered metaData. The
name of the secret will be made of a prefix and the index. The Metal3Machine
object name will be used as the prefix. A `-metadata-` will be added between the
prefix and the index.

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

The secret will contain the generated metaData for the host. Once the
`dataSecret` field on the Metal3Machine is set, the Metal3Machine controller
will proceed with the provisioning.

### Work Items

Here are the different steps :

- Add the metadata field in BareMetalHost (On-going)
- Add the CAPM3 logic for the metadata reconciler
- Modify the Metal3Machine reconciler to make use of the metadata and set it on
  the BareMetalHost.

### Dependencies

* [go templates](https://golang.org/pkg/text/template/)

### Test Plan

This can be added to our e2e tests. The Metal3Metadata object would be added as
part of the deployment and cloud-config modified to add variables to make use of
it.

### Upgrade / Downgrade Strategy

If none of the new fields are set, the behavior will be identical to the current
way the components work. In order to take this feature in use, the users must
take the fields in use.

During an upgrade, nothing is required to be done to keep things working as they
were. In order to start using this feature, the user would need to create the
Metal3Metadata object, and then do a rolling upgrade to change the
Metal3Machines (or Metal3MachineTemplates), and the KubeadmConfigs (or
KubeadmConfigTemplates or KubeadmControlPlane). Entries in the
Metal3MetadataStatus should be created for the existing Metal3Machine before the
upgrade to prevent conflicts.

### Version Skew Strategy

This will require that both CAPM3 and BMO support this feature.

## Drawbacks [optional]

This is using the api-server somehow as a database with the
Metal3MetadataStatus. It is not the best design with that regard.

## Alternatives [optional]

It would be possible to store the content of Metal3MetadataStatus in an
annotation of Metal3Metadata. In that case it would also be possible to use
a ConfigMap, but using our own object enables to do early validation.

## References

[metadata PR in Bare Metal Operator](https://github.com/metal3-io/baremetal-operator/pull/448)
