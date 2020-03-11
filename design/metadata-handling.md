<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Generating Metadata per node in CAPM3 down to Ironic

## Status

provisional

## Table of Contents

A table of contents is helpful for quickly jumping to sections of a
design and for highlighting any additional information provided beyond
the standard template.

[Tools for generating][] a table of contents from markdown are available.

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

- Baremetal Operator should set some default metadata in case they are not
  provided by the use (Like UUID that is required).
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
with added default key/value pairs if not present to Ironic.

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
  values:
    node-0:
      abc: def
    node-1:
      abc: ghi
  templates:
    local-hostname: worker-np1-{{ getIndex }}
```

This object will be reconciled by the Metal3machine controller. When reconciled,
the controller will add an OwnerReference to the Metal3Cluster that has nodes
linking to this object. The spec contains two fields:

- `values` contains a map of id and map of key and values. The id is merely an
  identifier of the map of key and values.
- `templates` contains a map of key and values that will be reused for all.

In both cases, the values will be [go templates](
https://golang.org/pkg/text/template/). A function `getIndex` will return
the lower int that is not yet in use.

A second object
would be created, a Metal3MetadataStatus type, linked to a Metal3Cluster.

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3MetadataStatus
metadata:
  name: nodepool-1
  namespace: default
  ownerReferences:
  - apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
    controller: true
    kind: Metal3Metadata
    name: nodepool-1
spec:
  values:
    "node-0": default/machine-1
  indexes:
    "0": default/machine-1
  machines:
    "default/machine-1":
      index: "0"
      value: "node-0"
```

This object would store the list of values used for each Metal3Metadata object.
The rationale behind not including it as a status of the previous object is to
be able to go through the move phase without information loss. This object would
only be used by the controller and should not be edited by the user.

The name of this status object will be identical to the Metal3Metadata object.
The `spec` field will contain fields that keeps track of which Metal3Machine is
using each of the values or indexes.

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
  metaDataTemplate:
    name: nodepool-1
    namespace: default
```

When CAPM3 controller will fill select a BaremetalHost and set the different
fields there, it will generate the metaData content based on the static metaData
and then render the metadata from the metaDataTemplate. It will
get the referenced Metal3Metadata and render metadata from the templates,
selecting the lowest available index, and from the values, selecting the first
available id. It will save the index and id in the Metal3MetadataStatus. If the
Metal3Machine already has an index and an id in the Metal3MetadataStatus, it
will re-use those.

When the Metal3Machine gets deleted, the CAPM3 controller will remove its
references from the Metal3MetadataStatus, making it available for other
Metal3Machines.

### Work Items

Here are the different steps :

- Add the metadata field in BareMetalHost (On-going)
- Add the CAPM3 logic for the metadata part
- Add the logic to cover the template value part, adding the Metal3Metadata
  and Metal3MetadataStatus object
- Extend the logic to also cover the template part of the Metal3Metadata object.

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
