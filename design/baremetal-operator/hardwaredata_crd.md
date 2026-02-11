# hardwareData custom resource for host inspection data

<!-- cSpell:ignore multipath -->

## Status

implemented

## Summary

Introduce HardwareData Custom Resource (CR) to store host inspection data.

## Motivation

Currently inspection data is written to baremetalhost status subresource. When
pivoting to a target cluster, with *`clusterctl move`*, status subresource is
not copied with the host, because from Cluster-API perspective, it's
controllers' job to rebuild the status in the target cluster. Also, according
to the
[Kubernetes API convention](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md#spec-and-status),
status is expected to be reconstructed by controllers if it's lost for any
reason. Baremetal Operator (BMO) is capable of reconstructing host status by
re-inspecting the host, but it will force the already provisioned host to go
through another round of provisioning, which eventually reboots the host after
IPA steps are completed. To have the inspection data available in the target
cluster and to avoid unnecessary provisioning after pivoting, we currently copy
inspection data to baremetalhost.metal3.io/status annotation so that BMO in the
target cluster can reconstruct the BareMetalHost from the annotation with the
appropriate inspection data and as such the reconciliation of the BMH can
continue from the same state as it was in the source cluster.

However, there is a limitation with the current approach, because when
inspection data is very large (e.g. when the host has 1000 multipath disks), it
is easy to hit the global limit of `metadata.annotations`
[262144](https://github.com/kubernetes/kubernetes/blob/master/test/integration/controlplane/synthetic_controlplane_test.go#L313)
bytes and once the limit is hit the move process will fail to pivot
BareMetalHosts successfully.

### Goals

- Store host inspection data into Spec of HardwareData CR
- Adjust pivoting workflow to restore inspection data from HardwareData
- Make the HardwareData CR immutable
- Don't write `status.hardware` data to the status annotation

### Non-Goals

- Remove `status.hardware` from BareMetalHost CR
- Drop status annotation

## Proposal

### User Stories

As an operator, from an ephemeral cluster I would like to pivot/move all the
Cluster API, CAPM3 and BMO objects to a target cluster successfully.

## Design Details

Apart from writing hardware details into the status of BareMetalHost, write it
to a HardwareData CR spec. BareMetalHost and HardwareData will be parent and
child objects respectively, and this relationship is controlled via
ownerReferences chain. As such, the same name and namespace will be used for
HardwareData as its owning object BareMetalHost. The spec of HardwareData will
contain the same fields & hardware information as currently under
`status.hardware` of BareMetalHost.

OwnerReferences refers to the linked BareMetalHost and is added by the
operator. To see all the available fields of ObjectReference type, check
[core/v1](https://pkg.go.dev/k8s.io/api/core/v1#ObjectReference) package.

There will be duplication of inspection data, i.e.,in the HardwareData spec and
BareMetalHost status, for the purpose of avoiding breaking API changes.
However, we plan to drop
[hardware](https://github.com/metal3-io/baremetal-operator/blob/05d12b6768a9989a9a4e61dad6cd1f9e84a6e078/apis/metal3.io/v1alpha1/baremetalhost_types.go#L721)
field from the status of BareMetalHost in the first version bump of the API.

### Pivoting

To pivot objects excluded from Cluster API chain to a target cluster, one can
set `clusterctl.cluster.x-k8s.io=""` label on HardwareData and BareMetalHost
CRDs. Current status annotation based pivoting workflow will stay as it is.
However, CAPM3 machine controller will no longer copy `status.hardware` of
BareMetalHost to the annotation. Because that part will be available in the
form of HardwareData CR in the target cluster.

### Implementation Details/Notes/Constraints

The life of HardwareData is dependent on BareMetalHost. When BareMetalHost is
entering inspection state, the HardwareData will be created. Failure in
reaching inspection state or having `inspect.metal3.io: disabled` (without
`inspect.metal3.io/hardwaredetails` annotation) annotation on BareMetalHost
will force the operator to not create the HardwareData. Deleting a
BareMetalHost will result in deletion of a HardwareData respectively.

HardwareData should be immutable and this will be controlled via
[Validating Webhook](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#validatingadmissionwebhook)
and with RBAC permissions. In case, when
[re-inspection](https://github.com/metal3-io/baremetal-operator/blob/main/docs/inspectAnnotation.md)
of a `available` BareMetalHost is requested, new HardwareData will be
re-created, because updating the old HardwareData will be blocked by the
Validating Webhook.

Deprovisioning of the BareMetalHost must not delete the HardwareData. It can
be deleted either when BareMetalHost is being deleted or when re-inspection
is requested. To ensure HardwareData availability while BareMetalHost is
provisioned, a finalizer should be set on the HardwareData.

Only operator will be granted with create permissions for HardwareData and
everyone else will be given no write permissions. If the BareMetalHost was
inspected but HardwareData is missing, operator acts differently depending on
the current state of the BareMetalHost.

- host is provisioned: we expect that HardwareData never existed. Even if it
    was existed but user deleted it, then it is user's fault. Normally
    finalizer blocks HardwareData deletion until BareMetalHost exists.
- host is available:
    1. copy inspection data from the status of BareMetalHost if exists;
    1. re-inspect the host if inspection data doesn't exist in the BareMetalHost
        status. This will be the first and only option in the future when
        `status.hardware` is removed;

As mentioned above, we will have two copies of inspection data available for
the time being. One in the Spec of HardwareData and the other in the Status of
BareMetalHost. In the future, when new API version of BareMetalHost is
introduced, `status.hardware` will be removed from BareMetalHost. As such,
missing HardwareData for available BareMetalHost will result in another
inspection before starting provisioning.

**Note:**
[cross-namespace owner references are not allowed](https://kubernetes.io/docs/concepts/overview/working-with-objects/owners-dependents/#owner-references-in-object-specifications).
Thus, HardwareData and BareMetalHost must be in the same namespace.

#### Example of HardwareData lifecycle

- BareMetalHost is created
- BareMetalHost is in inspecting state
- Operator creates a HardwareData with the same name and namespace as
    BareMetalHost, fills out the HardwareData with the host inspection data and
    sets ownerReferences
- Provisioning is requested
- Pivoted to a target cluster, operator restores host inspection data from
    HardwareData and the rest from status annotation (e.g.
    `status.Provisioning`, `status.poweredOn` and etc)
- Deprovisioning is requested
- BareMetalHost deletion requested, operator deletes the HardwareData and BareMetalHost

The spec of HardwareData:

```go
// Adding HardwareDetails struct here for visibility. During implementation,
// we don't have to duplicate it, but use from baremetalhost_types.go.
type HardwareDetails struct {

    SystemVendor HardwareSystemVendor `json:"systemVendor,omitempty"`
    Firmware     Firmware             `json:"firmware,omitempty"`
    RAMMebibytes int                  `json:"ramMebibytes,omitempty"`
    NIC          []NIC                `json:"nics,omitempty"`
    Storage      []Storage            `json:"storage,omitempty"`
    CPU          CPU                  `json:"cpu,omitempty"`
    Hostname     string               `json:"hostname,omitempty"`

}

type HostDataSpec struct {
    // The hardware discovered on the host.
    HardwareDetails *HardwareDetails `json:"hardware,omitempty"`
}
```

Example CR:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HardwareData
metadata:
  finalizers:
  - baremetalhost.metal3.io
  name: hostdata-sample
  ownerReferences:
  - apiVersion: metal3.io/v1alpha1
    controller: true
    kind: BareMetalHost
    name: bmh-sample
    uid: 546392e0-66b1-45c0-8d3d-6994ff82b477
spec:
  # inspection data
  cpu:
  firmware:
  hostname:
  nics:
  ramMebibytes:
  storage:
  systemVendor:
```

### Risks and Mitigations

Existing deployments will require installation of the HardwareData CRD and necessary
RBAC permissions when bumping the operator version. This needs to be clearly
documented.

### Work Items

- Add HardwareData API
- Modify the operator code
- Adjust CAPM3 machine controller to exclude writing `status.hardware` into the statusAnnotation
- Add unit tests
- Update documentation

### Dependencies

None

### Test Plan

Unit tests should be added. Integration test doesn't require any change.

### Upgrade / Downgrade Strategy

From a user perspective, this feature doesn't introduce any breaking changes
to existing deployments, because `status.hardware` field will stay until is
decided otherwise and this feature is only an addition to the current APIs.
For now, there will be two copies of inspection data available, in the
`spec.hardware` of HardwareData and `status.hardware` of BareMetalHost.

### Version Skew Strategy

To mitigate version skew issues, we plan to keep BaremetalHost and HardwareData
synchronized by bi-directional copying of inspection data.

## Drawbacks

None

## Alternatives

- Use k8s built in objects like ConfigMap/Secret. From security point of view, although,
    it is possible to restrict permissions to edit ConfigMaps (only to those
    storing inspection data) based on the name (i.e. `resourceNames`), but it
    will add complexity to the operator.
- Increase metadata global limit. However, this does not always work as it is hard
    to know the maximum length of inspection data.
- Add filters to filter-out unn inspection data?

## References

- [Discussion issue CAPM3](https://github.com/metal3-io/cluster-api-provider-metal3/issues/266)
- [Discussion issue BMO](https://github.com/metal3-io/baremetal-operator/issues/952)
- [Status annotation](https://github.com/metal3-io/baremetal-operator/blob/main/docs/statusAnnotation.md)
- [clusterctl move](https://cluster-api.sigs.k8s.io/clusterctl/commands/move.html#clusterctl-move)
- [Pause annotation](https://github.com/metal3-io/baremetal-operator/blob/master/docs/api.md#pausing-reconciliation)
- [Disable inspection](https://github.com/metal3-io/metal3-docs/blob/master/design/baremetal-operator/external-introspection.md#disable-inspection-proposal)
- [ObjectReference type](https://pkg.go.dev/k8s.io/api/core/v1#ObjectReference)
