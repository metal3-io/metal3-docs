# Add Pool-Based IP Allocation for Metadata Strings and Control Plane Endpoint

## Status

Provisional.

## Summary

This proposal introduces the ability to allocate IP addresses from
IP pools in two new contexts:

1. As values in `Metal3DataTemplate.spec.metaData.strings` entries
1. As the `host` value in
   `Metal3Cluster.spec.controlPlaneEndpoint`

It also introduces a mechanism to share cluster-level IP values
into per-machine metadata.

This allows fully automated VIP management for kube-vip deployments
without manual IP bookkeeping.

## Motivation

Currently:

- `Metal3Cluster.spec.controlPlaneEndpoint.host` must be a
  hardcoded IP. Operators must manually select a free IP, and
  manually track allocations.
- `Metal3DataTemplate.spec.metaData.strings` only supports static
  values. There is no way to insert a dynamically allocated IP
  into machine metadata.
- There is no mechanism to share cluster-level information
  (like the VIP) to individual machines.

### Goals

- Allow `metaData.strings` entries to reference an IP pool,
  allocating one IP per machine.
- Allow `controlPlaneEndpoint` to reference an IP pool,
  allocating one VIP per cluster.
- Allow `metaData` entries to read values from the
  `Metal3Cluster` object, so every machine receives the same
  cluster-level value.

## Proposal

### API Changes

#### 1. MetaData.Strings Pool References (Metal3DataTemplate)

Modify `MetaDataString` by having it exclusively support either a
literal value or a pool reference. Reuse the existing `FromPool`
struct:

```go
type MetaDataString struct {
    Key   string `json:"key,omitempty"`
    Value string `json:"value,omitempty"`
    // NEW — pool reference for per-machine IP allocation
    FromPool *FromPool `json:"fromPool,omitempty"`
}
```

**Semantics:**

- Either `value` or `fromPool` must be set (this can be done
  with a webhook).
- `fromPool` reuses the existing `FromPool` struct (with `name`,
  `apiGroup`, `kind`). The `Key` field in `FromPool` is ignored
  here — the outer `MetaDataString.Key` takes precedence.
- When `fromPool` is set, the pool reference is registered in
  `getReferencedPools()` and the allocated IP address is rendered
  as the string value.
- The `apiGroup` and `kind` on `FromPool` determine the IPAM
  path used. It should be capi by default since metal3 is being
  phased out.
- Each machine gets a **unique** IP from the pool. This is
  per-machine allocation.

**Example:**

```yaml
metaData:
  strings:
  - key: "node_management_ip"
    fromPool:
      name: "mgmt-pool"
      apiGroup: "ipam.cluster.x-k8s.io"
      kind: "InClusterIPPool"
```

#### 2. APIEndpoint Pool Reference (Metal3Cluster)

Add an optional pool reference field to `APIEndpoint`:

```go
type APIEndpoint struct {
    Host     string          `json:"host,omitempty"`
    Port     int32           `json:"port,omitempty"`
    // NEW — pool reference for cluster-level VIP allocation
    FromPool *FromPool       `json:"fromPool,omitempty"`
}
```

**Semantics:**

- Either `host` or `fromPool` must be set (this can be done
  with a webhook).
- `port` is always required regardless of how `host` is provided.
- When `fromPool` is set, the Metal3Cluster controller creates a
  CAPI `IPAddressClaim` and waits for allocation. Once fulfilled,
  `host` is populated with the allocated address.
- The `apiGroup` and `kind` on `FromPool` determine pool type.
  For CAPI-only allocation, set them to a CAPI-compatible pool.
  The controller always uses the CAPI `IPAddressClaim` path for
  this field (regardless of apiGroup/kind), since the allocation
  is per-cluster and doesn't go through the Metal3Data manager's
  per-machine claim flow.
- This is **per-cluster** allocation. One IP for the entire
  cluster lifetime.

**Example:**

```yaml
kind: Metal3Cluster
spec:
  controlPlaneEndpoint:
    fromPool:
      name: "vip-pool"
      apiGroup: "ipam.cluster.x-k8s.io"
      kind: "InClusterIPPool"
    port: 6443
```

#### 3. MetaDataFromCluster (Metal3DataTemplate)

Add a new metadata source type and field:

```go
type MetaDataFromCluster struct {
    Key   string `json:"key,omitempty"`
    // +kubebuilder:validation:Enum=controlPlaneHost;controlPlanePort
    Field string `json:"field,omitempty"`
}
```

Add to `MetaData`:

```go
type MetaData struct {
    // ... existing fields ...
    FromCluster []MetaDataFromCluster `json:"fromCluster,omitempty"` // NEW
}
```

**Semantics:**

- Reads a value from the `Metal3Cluster` associated with the
  machine's cluster.
- Every machine gets the **same** value.
- The `field` enum is restricted to `controlPlaneHost` and
  `controlPlanePort`.
- If the Metal3Cluster's `controlPlaneEndpoint.host` is empty
  (pool allocation pending), rendering fails with a retryable
  error.

**Example:**

```yaml
metaData:
  fromCluster:
  - key: "kube_vip_address"
    field: "controlPlaneHost"
  - key: "kube_vip_port"
    field: "controlPlanePort"
```

---

### Behavioral Changes

#### Metal3Data Controller (renderMetaData & getReferencedPools)

| Current Behavior                                                                                         | New Behavior                                                                                           |
| -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `strings` entries only use `entry.Value`                                                                 | Checks `entry.FromPool` first; if set, resolves from `poolAddresses` map; otherwise uses `entry.Value` |
| `getReferencedPools()` scans IPAddressesFromPool, PrefixesFromPool, GatewaysFromPool, DNSServersFromPool | Also scans `strings` entries for `FromPool` references                                                 |
| No access to Metal3Cluster during rendering                                                              | Fetches Metal3Cluster by label when `fromCluster` entries exist                                        |

The `FromPool` reference in a `MetaDataString` entry is registered
in `getReferencedPools()` using the existing `poolRefs.addRef()`
machinery. The pool name from `FromPool.Name` becomes the key in
`poolAddresses`. Since `MetaDataString` only needs the IP address
(not prefix or gateway), `renderMetaData` extracts
`poolAddresses[entry.FromPool.Name].Address`.

The IPAM path selection (`isMetal3IPPoolRef()`) routes the claim
to the appropriate handler automatically.

#### Metal3Cluster Controller

| Current Behavior | New Behavior |
|------------------|--------------|
| `Create()` validates that `host` is non-empty | `Create()` validates that either `host` OR `fromPool` is set. If `fromPool` is set and `host` is empty, creates a CAPI `IPAddressClaim` and returns a transient error (requeue). |
| `IsValid()` requires `host != ""` | `IsValid()` accepts `host != ""` OR `fromPool != nil` |
| `Delete()` is a no-op | `Delete()` deletes the `IPAddressClaim` if one was created, releasing the IP back to the pool. |
| Cluster is marked ready immediately if endpoint is valid | Cluster is only marked ready once the IP is allocated and `host` is populated |

**IPAddressClaim lifecycle:**

- Name: `<metal3cluster-name>-controlplane-endpoint`
- Namespace: same as the Metal3Cluster
- OwnerReference: points to the Metal3Cluster (GC handles
  orphans)
- Labels: `cluster.x-k8s.io/cluster-name` for discoverability
- Spec.PoolRef: constructed from `FromPool.Name`,
  `FromPool.Kind`, `FromPool.APIGroup`
- Always uses the CAPI IPAddressClaim API
  (`ipam.cluster.x-k8s.io/v1beta1`), regardless of the pool's
  apiGroup/kind.

#### Webhook Validation

| Resource | New Validation |
|----------|---------------|
| Metal3DataTemplate | `metaData.strings[i]`: exactly one of `value` or `fromPool` must be set |
| Metal3DataTemplate | `metaData.strings[i].fromPool`: if set, `name` is required |
| Metal3DataTemplate | `metaData.fromCluster[i].field`: must be `controlPlaneHost` or `controlPlanePort` |
| Metal3Cluster | `controlPlaneEndpoint`: exactly one of `host` or `fromPool` must be set |
| Metal3ClusterTemplate | Delegates to `IsValid()` |

---

### Interaction with Existing Features

#### Existing Pool Fields (IPAddressesFromPool, etc.)

Fully backward compatible. The existing
`metaData.ipAddressesFromPool` field continues to work exactly as
before with the Metal3 IPClaim path. The new
`strings[].fromPool` field is a separate allocation path that
happens to reuse the same `FromPool` struct.

The key difference: `ipAddressesFromPool` entries consume
`Address` from the pool. `strings[].fromPool` also consumes only
`Address`. If an operator needs prefix or gateway, they should
use `prefixesFromPool` or `gatewaysFromPool` as before.

#### Pool Name Uniqueness

The existing `poolRefs` deduplication applies. If a
`strings[].fromPool` entry references the same pool name as an
`ipAddressesFromPool` entry, only one claim is created and both
metadata keys receive the same IP. This is intentional — one
machine gets one IP per pool.

#### Static controlPlaneEndpoint

Fully backward compatible. If `host` is set, the controller
behaves exactly as before. The `fromPool` field is optional and
defaults to nil.

---

## Alternatives Considered

### Adding fromIPPool/fromPoolRef to MetaDataString

Rejected: introduces a third way to reference pools alongside
`FromPool` and `IPPoolReference`. The codebase already has
`FromPool` with the right fields. Reusing it directly keeps the
API surface consistent and avoids new types.

### Using MetaDataString for cluster-value propagation

Rejected: overloads the `MetaDataString` struct with too many
mutually exclusive fields. The dedicated `fromCluster` field on
`MetaData` follows the existing pattern where each data source
gets its own top-level field.

### Supporting Metal3 IPClaim path for cluster VIP

Rejected: the cluster-level allocation is a single claim per
cluster, not per-machine. The Metal3 IPClaim path is tightly
coupled to the Metal3Data per-machine lifecycle (claim naming
uses `<data-name>-<pool>`, owner references point to
Metal3Data). Using CAPI `IPAddressClaim` directly with the
Metal3Cluster as owner is cleaner and forward-compatible.

### Putting pool reference at top-level on Metal3ClusterSpec

Rejected: separates source and destination into sibling fields,
making the relationship implicit. Nesting inside `APIEndpoint`
is self-contained.

---

## Risks/Drawbacks

### Cluster Readiness Depends on IPAM

When using pool-based allocation, the Metal3Cluster cannot
become ready until the IPAM controller allocates an address. If
the IPAM controller is down or the pool is exhausted, the
cluster remains pending.

**Mitigation:** Transient errors with requeue. Automatic
recovery when IPAM becomes available. Users can always fall back
to static `host`.

### Ordering Dependency

`fromCluster` reads
`Metal3Cluster.Spec.ControlPlaneEndpoint.Host`. If the cluster
uses pool-based allocation, host is empty until allocation
completes. Machines created before the cluster is ready will
fail metadata rendering and requeue.

**Mitigation:** By design — CAPI doesn't create machines until
infrastructure is ready. The Metal3Cluster only reports ready
after the endpoint is populated.

### Metal3Cluster Discovery in renderMetaData

Finding the Metal3Cluster requires listing by
`cluster.x-k8s.io/cluster-name` label.

**Mitigation:** Only performed when `fromCluster` entries exist.
The CAPI contract guarantees one infrastructure cluster per
Cluster. Log a warning if multiple results.

### APIEndpoint Spec Mutation

Writing back to `spec.controlPlaneEndpoint.host` from the
controller is unusual but consistent with the CAPI
infrastructure provider contract (providers populate the
endpoint on the infrastructure resource, CAPI copies it to
`Cluster.Spec`).

---

## Implementation Plan

### Phase 1: MetaDataString Pool References

1. Add `FromPool *FromPool` field to `MetaDataString` in both
   v1beta2 and v1beta1 apis
1. Update `getReferencedPools()` to scan `MetaData.Strings`
   entries for `FromPool`
1. Update `renderMetaData()`: for strings entries with
   `FromPool`, look up
   `poolAddresses[entry.FromPool.Name].Address` instead of
   using `entry.Value`
1. Add webhook validation: exactly one of `value` or `fromPool`
   must be set
1. Add conversion functions between v1beta1 and v1beta2
1. Run `make generate` and `make test`

The IPAM path is determined automatically by
`isMetal3IPPoolRef()`:

- `apiGroup: ipam.metal3.io` + `kind: IPPool` → existing
  Metal3 IPClaim flow
- Anything else (e.g.,
  `ipam.cluster.x-k8s.io/InClusterIPPool`) → CAPI
  IPAddressClaim flow

No new IPAM machinery needed — the existing
`getAddressesFromPool()` handles both paths.

### Phase 2: Pool-Based Control Plane Endpoint

1. Add `FromPool *FromPool` field to `APIEndpoint` in v1beta2
   and v1beta1
1. Update `IsValid()` to accept `fromPool != nil` as valid
   (even if host is empty)
1. Add CAPI `IPAddressClaim` creation in
   `ClusterManager.Create()` when `fromPool` is set
1. Add polling loop: on reconcile, check if the claim is
   fulfilled; if so, write the allocated IP to
   `spec.controlPlaneEndpoint.host`
1. Update `Delete()` to clean up the `IPAddressClaim`
1. Add webhook validation: exactly one of `host` or `fromPool`
1. Update conversion functions

### Phase 3: Cluster Value Propagation

1. Add `MetaDataFromCluster` type and `fromCluster` field to
   `MetaData`
1. Update `renderMetaData()` signature to accept
   `*Metal3Cluster`
1. Add helper to fetch Metal3Cluster by cluster name label
1. Resolve `fromCluster` entries during rendering
1. Add webhook validation for field enum
1. Only fetch Metal3Cluster when `fromCluster` entries exist

---

## References

- [Original issue](https://github.com/metal3-io/cluster-api-provider-metal3/issues/3498)
- [kube-vip deployment example](https://github.com/lentzi90/playground/blob/main/Metal3/cluster/kcp.yaml)
- [Metal3 IPAM migration tracking](https://github.com/metal3-io/cluster-api-provider-metal3/issues/2813)
