<!--
This work is licensed under a Creative Commons Attribution 3.0
Unported License.

http://creativecommons.org/licenses/by/3.0/legalcode
-->

# allow disabling automated cleaning

<!-- cSpell:ignore dtantsur -->

## Status

implemented

## Summary

Configurable automated cleaning interface in Metal³ to allow users to
disable/enable automated cleaning for nodes.

## Motivation

Currently, when provisioning & de-provisioning Ironic nodes go
through the [automated-cleaning](https://docs.openstack.org/ironic/latest/admin/cleaning.html#automated-cleaning)
operation by default. This operation wipes out all the available
disks on every node. While upgrade operations in Kubernetes,
we want to ensure we don't lose the data on the disks attached to
the nodes. As such, we need a way to disable automated cleaning per
node so that we can avoid disk cleaning while upgrading the cluster node(s).

### User Stories

#### Story 1

As a cluster admin, I would like my node's disks data kept untouched
while I'm upgrading my Kubernetes cluster node(s).

#### Story 2

As a cluster admin, I would like my node's disks to be cleaned
while provisioning/de-provisioning (i.e. not upgrade scenario)
operations.

### Goals

- Add a filtering mechanism in Cluster-api-provider-metal3 (CAPM3) to find out Machines
   that should/not experience disk cleaning

- To Baremetal-operator (BMO), instruct whether a BareMetalHost should have its disk
   cleaned or not

- To Ironic, instruct whether an Ironic node should have its disk cleaned or not

### Non-Goals

During the upgrade, a mechanism to select the exact same nodes after de-provisioning.
In other words, nodes re-use logic.

## Proposal

Ironic supports enabling & disabling automated cleaning globally
and on the node level. As such, Metal³ needs to be able to identify the nodes
for which the disk cleaning should be disabled and communicate to Ironic to request
disabling the disk cleaning for those specific nodes.

### Metal³

In the Metal³, we will need changes both in CAPM3 and BMO as follows

#### Cluster-api-provider-metal3

##### Metal3MachineTemplate object

We introduce a new field `automatedCleaningMode` in the spec of the
Metal3MachineTemplate object. `automatedCleaningMode` store a enum type
of value. Setting it to Disabled means don't perform automated cleaning, while
Metadata value enables automated cleaning. By default, `automatedCleaningMode` will
be set to Metadata (i.e. do perform automated cleaning as it is now).

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3MachineTemplate
metadata:
spec:
  template:
  spec:
    automatedCleaningMode: Disabled   # default value is Metadata
```

A new Metal3MachineTemplate controller will be introduced to reconcile
Metal3MachineTemplate objects. When a user modifies `automatedCleaningMode`
field on a Metal3MachineTemplate, CAPM3 Metal3MachineTemplate controller
will update `automatedCleaningMode` field value on all the respective
Metal3Machines referenced by that Metal3MachineTemplate.

##### Metal3Machine object

We introduce a new field `automatedCleaningMode` in the spec of the
Metal3Machine object. `automatedCleaningMode` store a enum type
of value. Setting it to Disabled means do not perform automated
cleaning, while Metadata value enables automated cleaning. By default
`automatedCleaningMode` will be set to Metadata (i.e. do perform automated
cleaning as it is now).

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3Machine
metadata:
spec:
  template:
  spec:
    automatedCleaningMode: Disabled   # default value is Metadata
```

#### Baremetal Operator

We introduce a new field `automatedCleaningMode` in the spec of the
BaremetalHost object. `automatedCleaningMode` store a enum type
of value. If set to Disabled, the Baremetal Operator instructs Ironic
to disable automated cleaning for an Ironic node, while if
set to Metadata, the Baremetal Operator instructs Ironic to enable automated
cleaning. By default `automatedCleaningMode` will be set to Metadata
(i.e. do perform automated cleaning as it is now).

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: worker-0
spec:
  automatedCleaningMode: Disabled   # default value is Metadata
```

## Design Details

**Example flow including CAPM3:**

1. User wants to disable disk cleaning before upgrading the nodes that are part
   of the same KCP/MD.

1. User sets Disabled for the `automatedCleaningMode` field on a
   Metal3MachineTemplate which is referenced by `infrastructureTemplate` field
   in the KCP/MD.

1. Metal3MachineTemplate controller keeps reconciling the Metal3MachineTemplate objects.
   Once the update is seen on the Metal3MachineTemplate, Metal3MachineTemplate controller
   starts mapping all the Metal3Machines referenced by that particular Metal3MachineTemplate,
   and updates the `automatedCleaningMode` field to Disabled on all the referenced
   Metal3Machines.

1. Metal3Machine controller keeps reconciling the Metal3Machine objects.
   Once the update is seen on the Metal3Machine, Metal3Machine controller starts
   mapping the BareMetalHosts referenced by the Metal3Machines, and updates the
   `automatedCleaningMode` field to Disabled on all the referenced BaremetalHosts.

1. Since the `automatedCleaningMode` field is set to Disabled on the BaremetalHosts,
   Baremetal Operator instructs the Ironic to disable disk cleaning for Ironic
   nodes referenced by the BaremetalHosts.

**Example flow when running only BMO:**

1. User wants to disable disk cleaning for a single host

1. User sets Disabled for the `automatedCleaningMode` field on a
   BareMetalHost spec.

1. Baremetal Operator keeps reconciling the BareMetalHost, and after the update on
   the BareMetalHost, BMO instructs the Ironic to disable disk cleaning
   for the node.

### Implementation Details/Notes/Constraints

- As a user, you can still modify `automatedCleaningMode` field directly
   on a BareMetalHost to disable/enable automatic cleaning for the host that
   is not managed by the CAPM3.

- `automatedCleaningMode` can be updated on a BareMetalHost either before the provisioning
   (i.e. `Ready` state) or deprovisioning (i.e. `Provisioned` state) takes place.

- Updating `automatedCleaningMode` field on a Metal3MachineTemplate will ensure to
    have the same value on all the corresponding Metal3Machines and BareMetalHosts
    no matter what the current value is.

### Risks and Mitigations

None

### Work Items

- Implement a new field `automatedCleaningMode` in the spec of the Metal3MachineTemplate
- Implement a new field `automatedCleaningMode` in the spec of the Metal3Machine
- Implement a new field `automatedCleaningMode` in the spec of BareMetalHost
- Implement a new Metal3MachineTemplate controller in Cluster-api-provider-metal3

### Dependencies

None

### Test Plan

- Unit tests should be added in Baremetal Operator
- Unit tests should be added in Cluster-api-provider-metal3

### Upgrade / Downgrade Strategy

None

### Version Skew Strategy

None

## Drawbacks

It may present some security issues since anyone can edit the `automatedCleaningMode`
field. However, these operations can be restricted by proper RBAC rules.

## Alternatives

Automated cleaning can be disabled globally (by setting `automated_clean=False` for
the conductor in [ironic.conf](https://github.com/metal3-io/ironic-image/blob/168207c1c2bdfa8761269bdf6434883b05647036/ironic.conf.j2#L62)
and then enabled on the node level for nodes that require disk
cleaning. However, this option introduces a couple of issues:

1. As mentioned by @dtantsur in [2008113](https://storyboard.openstack.org/#!/story/2008113)
   there could be some security concerns if we disable automated cleaning globally.

1. Upgrade operations do not happen as frequently as provisioning & de-provisioning.
   As such, this would require admins to always enable node automated
   cleaning whenever they perform normal provisioning/de-provisioning.

## References

- Configurable disk cleaning options issue in BMO: <https://github.com/metal3-io/baremetal-operator/issues/626>
- Make `node.automated_clean` work in both directions - story in Ironic: <https://storyboard.openstack.org/#!/story/2008113>
- Make `node.automated_clean` work in both directions commit in Ironic: <https://review.opendev.org/#/c/762343/>
