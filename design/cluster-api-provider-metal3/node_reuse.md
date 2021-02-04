<!--
This work is licensed under a Creative Commons Attribution 3.0
Unported License.

http://creativecommons.org/licenses/by/3.0/legalcode
-->

# node reuse

## Status

implementable

## Summary

Node reuse during the upgrade/remediation operation.

## Motivation

Sometimes it is necessary to make some upgrades to the Metal3 cluster. These
upgrades can happen when updates occur on `Metal3MachineTemplate` object; for
example, user modifies node image version via `spec.template.spec.image.url`
field, or on `KubeadmControlPlane`; for example, a user modifies Kubernetes
version via `spec.version` field. Once update takes place, owning controller
(e.g. KCP controller) starts rolling upgrade. As such, CAPI `Machines`, CAPM3
`Metal3Machines` will be re-created based on the KCP changes. And of course,
`BareMetalHosts` which are owned by `Metal3Machines`, will be deprovisioned.
Normally, when `BareMetalHost` is getting deprovisioned, Ironic cleans up root
and externally attached disks on the host. However, while performing upgrade
operation we don't want hosts external disk data to be cleaned so that when
`BareMetalHost` comes provisioned again, it has still the disk data untouched.
To achieve this, we need to

1. be able to disable disk cleaning while deprovisioning.
  This [feature](https://github.com/metal3-io/metal3-docs/blob/master/design/cluster-api-provider-metal3/allow_disabling_node_disk_cleaning.md)
  is WIP right now.

2. be able reuse the same pool of `BareMetalHost` so that we get the storage
  data back. Currently, there is no mechanism available in Metal³ to pick the
  same pool of hosts that were released while upgrading/remediation - for the
  next provisioning phase. And this proposal tries to solve this.

**NOTE:** This proposal focuses on upgrade use cases but it isn't limited to
only upgrade. Other use cases like remediation can also benefit from this
feature as well.

### User Stories

#### Story 1

As a cluster admin, I would like the same nodes to be used when they go for
reprovisioning (i.e. deprovisioning -> provisioning) during the upgrade operation.

#### Story 2

As a cluster admin, I would like the same nodes to be used when they go for
reprovisioning (i.e. deprovisioning -> provisioning) during the remediation
operation.

#### Story 3

As a cluster admin, I would like any available (i.e. state: `Ready`) BMH to be
selected randomly for a new CAPI Machine -> Metal3Machine(M3M) when nodeReuse is
False.

### Goals

Add a logic to mark, filter and pick those marked BMH(s) when going through a
re-provisioning cycle as part of the upgrade procedure.

### Non-Goals

Support node reuse for Machines which are created independently of Kubeadm
control plane controller/Machine Deployment(KCP/MD). Currently we are not trying
to support node reuse feature for the Machines not owned by higher level objects
like KCP/MD. Because, if there is no KCP/MD that Machine could point to, then
Cluster API Provider Metal3 (CAPM3) Machine controller will fail to first, set
the `consumerRef` in spec of the BMH(s) and second, to filter the BMH(s) based
on the `consumerRef`.

## Proposal

We would like to propose an interface to mark BMH(s) that we want to reuse after
deprovisioning and second, add a selection/filtering mechanism in CAPM3 Machine
controller that will pick those BMH(s) with a specific mark (to be exact, based
on the value of `consumerRef`).

## Design Details

Normally, before deprovisioning the host, the controller removes the M3M name
from the`consumerRef` field of the BMH when M3M is deleted.

In case of nodeReuse field is set to True, to make sure that a BMH(s) is not
utilized by other M3M(s) after it has been deprovisioned, the `consumerRef`
field will store the name of KCP/MD even when it is in `Ready` state. During the
upgrade, after KCP/MD creates new Machines, CAPM3 will create new M3M(s) and will
filter out BMH(s) that have the name of KCP/MD in the `consumerRef` field. If the
name of the KCP/MD matches the name set in `spec.consumerRef.name` field of BMH,
then CAPM3 Machine controller will associate that BMH to the M3M.

As such, even after deprovisioning we will keep the `consumerRef` on a BMH and
when M3M will be requesting a new BMH, CAPM3 will filter BMH(s) based on their
consumerRef and will pick up those that match the name of KCP/MD.

**Example flow:**

***User updates Metal3MachineTemplate(M3MTemplate):***

1. User has set `NodeReuse` field to True in the new M3MTemplate;
2. User applies new M3MTemplate (i.e with new image version);
3. User updates reference in KCP/MD to the newly created M3MTemplate;
4. Upgrade process starts in KCP/MD;
5. At this point, KCP/MD triggers a deletion of the old machines which results
    in the deletion and deprovisioning of machines and BMH(s) respectively by the
    CAPM3 controller;
6. While BMH(s) is/are deprovisioning, CAPM3 machine controller will read the
    `NodeReuse` field value from the new M3MTemplate that KCP is pointing to, and:
    * If it is set to **True:**
      * Apart from removing the M3M name from `consumerRef` in BMH, it will also
      re-create a new `consumerRef` which points to the name of the KCP/MD (where
      we find it from M3MTemplate). BMH becomes Ready again and is free with
      KCP/MD name set on `consumerRef`;
    * If it is set to **False:**
      * Normal operation continues, where M3M name from `consumerRef` in BMH will
      be removed and BMH becomes Ready with empty `consumerRef`.
7. KCP will create new machines, and at the same time new M3M(s) will be created.
    At this point, CAPM3 Machine controller will look in the newly created M3M(s)
    for annotation `clonedFrom` which will be always pointing to the M3MTemplate.
    In the following step, it will find the `NodeReuse` field in the M3MTemplate
    and:
    * If it is set to **True:**
      * CAPM3 Machine controller will filter out ready BMH(s) marked with
      `consumerRef` field set to KCP/MD name:
        * If BMH found:
          * Pick that BMH and attach that BMH to newly created M3M;
          * Update `consumerRef` field on BMH pointing to the corresponding
          M3M name instead of KCP/MD name;
        * Else if BMH is not found:
          * It will wait until a ready BMH with KCP/MD name in`consumerRef`
          field becomes available;
          * Once it is found, it updates `consumerRef` field on BMH
          pointing to the M3M name instead of KCP/MD name;
    * If it is set to **False:**
      * then CAPM3 Machine controller will filter out ready BMH(s) with `consumerRef`
      field set to empty.

***User updates KCP/MD:***

1. User updates `NodeReuse` field to True in the current M3MTemplate before
    he/she starts updating KCP/MD;
2. User updates KCP/MD field (i.e with new k8s version);
3. Upgrade process starts in KCP/MD;
4. At this point, KCP/MD triggers a deletion of the old machines which results
    in the deletion and deprovisioning of machines and BMH(s) respectively by the
    CAPM3 controller;
5. While BMH(s) is/are deprovisioning, CAPM3 Machine controller will read the
    `NodeReuse` field value from new M3MTemplate that KCP is pointing to, and:
    * If it is set to **True:**
      * Apart from removing the M3M name from `consumerRef` in BMH, it will also
      re-create a new `consumerRef` which points to the name of the KCP/MD (where
      we find it from M3MTemplate). BMH becomes Ready again and is free with
      KCP/MD name set on `consumerRef`;
    * If it is set to **False:**
      * Normal operation continues, where M3M name from `consumerRef` in BMH will
      be removed and BMH becomes Ready with empty `consumerRef`.
6. KCP will create new machines, and at the same time new M3M(s) will be created.
    At this point, CAPM3 Machine controller will look in the newly created M3M(s)
    for annotation `clonedFrom` which will be always pointing to the M3MTemplate.
    In the following step, it will find the `NodeReuse` field in the M3MTemplate
    and:
    * If it is set to **True:**
      * CAPM3 Machine controller will filter out ready BMH(s) marked with
      `consumerRef` field set to KCP/MD name:
        * If BMH found:
          * Pick that BMH and attach that BMH to newly created M3M;
          * Update `consumerRef` field on BMH pointing to the corresponding M3M
          name instead of KCP/MD name;
        * Else if BMH is not found:
          * It will wait until a ready BMH with KCP/MD name in `consumerRef`
          field becomes available;
          * Once it is found, it updates `consumerRef` field on BMH
          pointing to the M3M name instead of KCP/MD name;
    * If it is set to **False:**
      * then CAPM3 Machine controller will filter out ready BMH(s) with
      `consumerRef` field set to empty.

### Implementation Details/Notes/Constraints

```go
type Metal3MachineTemplateSpec struct {

    // When set to True, CAPM3 Machine controller tries to
    // pick the BMH that was released during the upgrade
    // operation.
    // +kubebuilder:default=false
    // +optional
    NodeReuse bool `json:"nodeReuse,omitempty"`
}
```

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3MachineTemplate
metadata:
spec:
  nodeReuse: False   # by default don't reuse the node.
  template:
    spec:
      image:
        checksum: ...
        checksumType: ...
        format: ...
        url: ...

```

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
spec:
  consumerRef: test1 # KCP/MD name
    ...
status:
  provisioning:
    state: ready
    ...
```

### Risks and Mitigations

None

### Work Items

* Modify CAPM3 controller to set the KCP/MD name in the `consumerRef` of
    BareMetalHost while it is deprovisioning;
* Implement a new NodeReuse field in the spec of the M3MTemplate.

### Dependencies

None

### Test Plan

* Unit tests should be added in CAPM3.

### Upgrade / Downgrade Strategy

None

### Version Skew Strategy

None

## Drawbacks

None

## Alternatives

None

## References

* Remediation proposal in Metal3: [Remediation](https://github.com/metal3-io/metal3-docs/blob/master/design/capm3-remediation-controller-proposal.md)
* Disable disk cleaning proposal in Metal3: [Disable disk cleaning](https://github.com/metal3-io/metal3-docs/blob/master/design/cluster-api-provider-metal3/allow_disabling_node_disk_cleaning.md)
