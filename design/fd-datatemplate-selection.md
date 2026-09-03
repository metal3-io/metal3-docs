# FailureDomain DataTemplate and BMH Namespace Selection

This proposal extends the
[FD Support for Control-Plane Nodes](fd-support-kcp.md) design in two
complementary ways: (1) per-FD `Metal3DataTemplate` mapping for network
configuration, and (2) per-FD BareMetalHost (BMH) namespace placement so
that physical site boundaries (rack, row, AZ) map directly to Kubernetes
namespace boundaries. Both are independently opt-in. (2) depends on PR
[metal3-io/cluster-api-provider-metal3#2506][pr-2506], which removes the
BMH `ownerReference`.

## Motivation

The current FD support only addresses **BMH selection** — CAPM3 picks a BMH
from the correct FD. However, all control-plane nodes still share the **same
network configuration** because KCP references a single
`Metal3MachineTemplate`, which embeds a single `dataTemplate` pointing to one
`Metal3DataTemplate`.

```text
KCP
 └── 1 Metal3MachineTemplate
      └── spec.template.spec.dataTemplate → 1 Metal3DataTemplate
                                              └── networkData (single config)
```

This creates two problems:

- **No per-node subnet differentiation**: All CP nodes receive the same
   subnet configuration, preventing true network-level HA across different
   L2/L3 segments.
- **Static VLAN tagging**: `NetworkDataLinkVlan` in `Metal3DataTemplate` is
   defined once. There is no way to assign different VLAN IDs to different
   CP nodes (e.g. VLAN 100 for rack1, VLAN 200 for rack2).

### Namespace-based site separation

Separately, the existing FD design places all BMHs in a single namespace
(typically `metal3`) and uses labels to distinguish failure domains.
Representing each FD as its own Kubernetes namespace makes the boundary of a
physical site (rack, row, AZ) coincide with the namespace boundary:

- A physical site (e.g. `rack1`) maps one-to-one to a Kubernetes namespace.
  No separate label scheme is required to identify which BMHs belong to
  which site — the namespace already encodes it.
- BMH inventory can be managed and queried by namespace
  (`kubectl -n rack1 get bmh`), and management actions can be scoped to a
  single site through standard Kubernetes namespace tooling.

## User Stories

As an operator who has placed their baremetal infrastructure across different
FDs with **different network segments** (subnets, VLANs, IP pools), I would
like each control-plane node to receive the correct network configuration
matching its FD.

## Goals

- Support selection of different `Metal3DataTemplate` per FD for control-plane
  nodes deployed via KCP.
- Maintain backward compatibility — clusters without this feature are
  unaffected.
- Add an optional `bmhNamespace` field per FD entry on `Metal3Cluster` —
  scope a given FD's BMH selection to the named namespace. Independently
  opt-in from the per-FD `DataTemplate` selection above.

## Non-Goals

- Changing the `Metal3DataTemplate`, `Metal3DataClaim`, `Metal3Data`, or
  secret rendering pipeline.
- Many-to-many FD ↔ namespace mapping. Each FD points to at most one
  namespace (many-to-many is discussed under
  [Alternatives Considered](#alternatives-considered)).
- Replacing the
  [HostClaim multi-tenancy design](hostclaim-multitenancy.md). HostClaim
  addresses cross-tenant security boundaries; this proposal is scoped to
  failure-domain placement within a single tenant.
- Cross-namespace placement for cluster-level objects other than BMH.
  `Cluster`, `Metal3Cluster`, `KubeadmControlPlane`, `MachineDeployment`,
  `Metal3Machine`, and template resources all remain co-located in a
  single namespace (typically `metal3`).

## Proposal

Add a new optional field `failureDomainDataTemplates` to
`Metal3MachineTemplateSpec`. This field maps FD names to specific
`Metal3DataTemplate` references. When a `Metal3Machine` is assigned to an FD
that exists in this mapping, the controller overrides
`Metal3Machine.Spec.DataTemplate` with the FD-specific reference. If the
assigned FD is not found in the mapping, the default
`template.spec.dataTemplate` is used as fallback.

The rest of the data pipeline (`Metal3DataClaim` → `Metal3DataTemplate`
controller → `Metal3Data` → secret rendering) remains **unchanged**.

### Flow

```text
                                 ┌─────────────────────┐
                                 │  KubeadmControlPlane │
                                 └──────────┬──────────┘
                                            │ infrastructureRef
                                 ┌──────────▼──────────┐
                                 │ Metal3MachineTemplate│
                                 │                      │
                                 │ template.spec:       │
                                 │   dataTemplate:      │
                                 │     m3dt-default     │
                                 │                      │
                                 │ failureDomainData-   │
                                 │ Templates:           │
                                 │  rack1 → m3dt-rack1  │
                                 │  rack2 → m3dt-rack2  │
                                 │  rack3 → m3dt-rack3  │
                                 └──────────┬──────────┘
                                            │
              ┌─────────────────────────────┼─────────────────────────────┐
              │                             │                             │
   ┌──────────▼──────────┐      ┌──────────▼──────────┐      ┌──────────▼──────────┐
   │  Machine (fd=rack1) │      │  Machine (fd=rack2) │      │  Machine (fd=rack3) │
   └──────────┬──────────┘      └──────────┬──────────┘      └──────────┬──────────┘
              │                             │                             │
   ┌──────────▼──────────┐      ┌──────────▼──────────┐      ┌──────────▼──────────┐
   │   Metal3Machine     │      │   Metal3Machine     │      │   Metal3Machine     │
   │ fd=rack1            │      │ fd=rack2            │      │ fd=rack3            │
   │ dataTemplate:       │      │ dataTemplate:       │      │ dataTemplate:       │
   │  → m3dt-rack1       │      │  → m3dt-rack2       │      │  → m3dt-rack3       │
   └──────────┬──────────┘      └──────────┬──────────┘      └──────────┬──────────┘
              │                             │                             │
   ┌──────────▼──────────┐      ┌──────────▼──────────┐      ┌──────────▼──────────┐
   │  Metal3DataClaim    │      │  Metal3DataClaim    │      │  Metal3DataClaim    │
   │  → m3dt-rack1       │      │  → m3dt-rack2       │      │  → m3dt-rack3       │
   └──────────┬──────────┘      └──────────┬──────────┘      └──────────┬──────────┘
              │                             │                             │
   ┌──────────▼──────────┐      ┌──────────▼──────────┐      ┌──────────▼──────────┐
   │ networkData secret  │      │ networkData secret  │      │ networkData secret  │
   │ subnet: 10.0.1.0/24 │      │ subnet: 10.0.2.0/24 │      │ subnet: 10.0.3.0/24 │
   │ VLAN: 100           │      │ VLAN: 200           │      │ VLAN: 300           │
   └─────────────────────┘      └─────────────────────┘      └─────────────────────┘
```

### bmhNamespace field

Add an optional `bmhNamespace` field (string, DNS-1123 namespace name) to
each entry of `Metal3Cluster.Spec.FailureDomains`. When set, the BMH
selection for that FD is restricted to the named namespace; when empty, it
falls back to the `Metal3Machine`'s own namespace (the existing behavior).

**Behavior:**

- The CAPM3 controller uses `Machine.Spec.FailureDomain` as the key to look
  up the matching entry in `Metal3Cluster.Spec.FailureDomains`.
- If that entry has `bmhNamespace` set, the BMH search is scoped to that
  namespace; otherwise the `Metal3Machine`'s namespace is used.
- The FD label match from
  [fd-support-kcp.md](fd-support-kcp.md) applies on top of the resolved
  namespace, unchanged.

**IPAM:** `Metal3DataClaim`, `Metal3Data`, `IPClaim`, and `IPPool`
continue to live in the `Metal3Machine`'s namespace; this side is
unaffected.

**Multiple controller lookup paths must honor the BMH namespace.** Once
the BMH may live in a different namespace, every controller path that
references the BMH must follow its actual namespace:

- **Metal3Machine BMH selection** — choosing a host from the candidate
  pool.
- **Metal3Machine post-selection lookup** — re-fetching the already
  selected BMH on subsequent reconciles. Directives such as
  `Metal3DataTemplate`'s `fromHostInterface` use this path to read the
  BMH's `Status.HardwareDetails`.
- **Metal3Remediation BMH lookup** — a distinct lookup path used to
  start the remediation lifecycle (PowerOff annotation, reboot
  sequence, etc.).

All three paths today scope the lookup to the Metal3Machine's own
namespace and must be updated together. The Metal3Cluster-driven
label-sync fan-out path shares the same assumption and is a secondary
audit item (a direct BMH watch path exists alongside it, so the impact
is limited).

#### Flow (BMH selection)

```text
                                 ┌─────────────────────┐
                                 │   Metal3Cluster      │
                                 │   ns=metal3          │
                                 │                      │
                                 │ failureDomains:      │
                                 │  rack1: ns=rack1     │
                                 │  rack2: ns=rack2     │
                                 │  rack3: ns=rack3     │
                                 └──────────┬──────────┘
                                            │ FD entry lookup
              ┌─────────────────────────────┼─────────────────────────────┐
              │                             │                             │
   ┌──────────▼──────────┐      ┌──────────▼──────────┐      ┌──────────▼──────────┐
   │   Metal3Machine     │      │   Metal3Machine     │      │   Metal3Machine     │
   │ ns=metal3           │      │ ns=metal3           │      │ ns=metal3           │
   │ fd=rack1            │      │ fd=rack2            │      │ fd=rack3            │
   └──────────┬──────────┘      └──────────┬──────────┘      └──────────┬──────────┘
              │ chooseHost                  │ chooseHost                  │ chooseHost
              │ (ns=rack1,                  │ (ns=rack2,                  │ (ns=rack3,
              │  fd label=rack1)            │  fd label=rack2)            │  fd label=rack3)
              ▼                             ▼                             ▼
   ┌─────────────────────┐      ┌─────────────────────┐      ┌─────────────────────┐
   │   BareMetalHost     │      │   BareMetalHost     │      │   BareMetalHost     │
   │ ns=rack1            │      │ ns=rack2            │      │ ns=rack3            │
   │ label fd=rack1      │      │ label fd=rack2      │      │ label fd=rack3      │
   │ consumerRef:        │      │ consumerRef:        │      │ consumerRef:        │
   │  → metal3/m3m-1     │      │  → metal3/m3m-2     │      │  → metal3/m3m-3     │
   └─────────────────────┘      └─────────────────────┘      └─────────────────────┘
```

## Example Scenario

Building on the same 3-rack scenario from the
[original design](fd-support-kcp.md#example-scenario) (Metal3Cluster and
BareMetalHosts are already defined), each rack has its own network segment:

| Rack | Subnet | VLAN | IP Pool |
|------|--------|------|---------|
| rack1 | 10.0.1.0/24 | 100 | pool-rack1 |
| rack2 | 10.0.2.0/24 | 200 | pool-rack2 |
| rack3 | 10.0.3.0/24 | 300 | pool-rack3 |

### Metal3DataTemplates — one per failure domain

Each `Metal3DataTemplate` defines the network configuration specific to its
rack, including the VLAN ID, IP pool, and subnet.

```yaml
kind: Metal3DataTemplate
metadata:
  name: m3dt-rack1
spec:
  clusterName: my-cluster
  networkData:
    links:
      ethernets:
      - id: enp1s0
        type: phy
        macAddress:
          fromHostInterface: enp1s0
      vlans:
      - id: enp1s0.100
        vlanID: 100
        vlanLink: enp1s0
        mtu: 1500
        macAddress:
          fromHostInterface: enp1s0
    networks:
      ipv4:
      - id: rack1-net
        link: enp1s0.100
        ipAddressFromIPPool: pool-rack1
        routes:
        - network: "0.0.0.0"
          prefix: 0
          gateway:
            fromIPPool: pool-rack1
    services:
      dnsFromIPPool: pool-rack1
---
kind: Metal3DataTemplate
metadata:
  name: m3dt-rack2
spec:
  clusterName: my-cluster
  networkData:
    links:
      ethernets:
      - id: enp1s0
        type: phy
        macAddress:
          fromHostInterface: enp1s0
      vlans:
      - id: enp1s0.200
        vlanID: 200
        vlanLink: enp1s0
        mtu: 1500
        macAddress:
          fromHostInterface: enp1s0
    networks:
      ipv4:
      - id: rack2-net
        link: enp1s0.200
        ipAddressFromIPPool: pool-rack2
        routes:
        - network: "0.0.0.0"
          prefix: 0
          gateway:
            fromIPPool: pool-rack2
    services:
      dnsFromIPPool: pool-rack2
---
kind: Metal3DataTemplate
metadata:
  name: m3dt-rack3
spec:
  clusterName: my-cluster
  networkData:
    links:
      ethernets:
      - id: enp1s0
        type: phy
        macAddress:
          fromHostInterface: enp1s0
      vlans:
      - id: enp1s0.300
        vlanID: 300
        vlanLink: enp1s0
        mtu: 1500
        macAddress:
          fromHostInterface: enp1s0
    networks:
      ipv4:
      - id: rack3-net
        link: enp1s0.300
        ipAddressFromIPPool: pool-rack3
        routes:
        - network: "0.0.0.0"
          prefix: 0
          gateway:
            fromIPPool: pool-rack3
    services:
      dnsFromIPPool: pool-rack3
```

### IPPools — one per rack

```yaml
apiVersion: ipam.metal3.io/v1alpha1
kind: IPPool
metadata:
  name: pool-rack1
spec:
  clusterName: my-cluster
  namePrefix: rack1
  pools:
  - start: 10.0.1.10
    end: 10.0.1.50
    prefix: 24
    gateway: 10.0.1.1
    dnsServers: [8.8.8.8]
---
apiVersion: ipam.metal3.io/v1alpha1
kind: IPPool
metadata:
  name: pool-rack2
spec:
  clusterName: my-cluster
  namePrefix: rack2
  pools:
  - start: 10.0.2.10
    end: 10.0.2.50
    prefix: 24
    gateway: 10.0.2.1
    dnsServers: [8.8.8.8]
---
apiVersion: ipam.metal3.io/v1alpha1
kind: IPPool
metadata:
  name: pool-rack3
spec:
  clusterName: my-cluster
  namePrefix: rack3
  pools:
  - start: 10.0.3.10
    end: 10.0.3.50
    prefix: 24
    gateway: 10.0.3.1
    dnsServers: [8.8.8.8]
```

### Metal3MachineTemplate — with failureDomainDataTemplates

```yaml
kind: Metal3MachineTemplate
metadata:
  name: my-cluster-cp
spec:
  template:
    spec:
      image:
        url: https://example.com/ubuntu-22.04.qcow2
        checksum: https://example.com/ubuntu-22.04.qcow2.sha256sum
        checksumType: sha256
        format: qcow2
      dataTemplate:
        name: m3dt-rack1          # default fallback
        namespace: metal3
      hostSelector:
        matchLabels:
          cluster-role: control-plane
  failureDomainDataTemplates:     # NEW FIELD
  - failureDomain: rack1
    dataTemplate:
      name: m3dt-rack1
      namespace: metal3
  - failureDomain: rack2
    dataTemplate:
      name: m3dt-rack2
      namespace: metal3
  - failureDomain: rack3
    dataTemplate:
      name: m3dt-rack3
      namespace: metal3
```

### KubeadmControlPlane — unchanged

```yaml
kind: KubeadmControlPlane
metadata:
  name: my-cluster-cp
spec:
  replicas: 3
  version: v1.30.0
  machineTemplate:
    infrastructureRef:
      apiVersion: infrastructure.cluster.x-k8s.io/v1beta2
      kind: Metal3MachineTemplate
      name: my-cluster-cp
  kubeadmConfigSpec:
    initConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-provider: external
    joinConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-provider: external
```

### Result — Metal3Machines with per-FD DataTemplates

KCP automatically creates 3 Machine objects (distributed across the 3 failure
domains), and each Machine triggers the creation of a corresponding
Metal3Machine. The CAPM3 controller then:

- Syncs `Machine.Spec.FailureDomain` → `Metal3Machine.Spec.FailureDomain`
- Looks up `failureDomainDataTemplates` in the Metal3MachineTemplate
- Overrides `Metal3Machine.Spec.DataTemplate` with the FD-specific reference

The resulting Metal3Machines (auto-populated by the controllers) look like:

```yaml
# Auto-generated by KCP + CAPM3 controller — not user-created
# Machine 1: assigned to rack1 by KCP
kind: Metal3Machine
metadata:
  name: my-cluster-cp-xxxxx
spec:
  failureDomain: rack1            # ← synced from Machine.Spec.FailureDomain
  dataTemplate:
    name: m3dt-rack1              # ← overridden by controller (rack1 mapping)
    namespace: metal3
status:
  networkData:
    name: my-cluster-cp-xxxxx-networkdata
    # → secret contents: VLAN 100, subnet 10.0.1.0/24
---
# Machine 2: assigned to rack2 by KCP
kind: Metal3Machine
metadata:
  name: my-cluster-cp-yyyyy
spec:
  failureDomain: rack2            # ← synced from Machine.Spec.FailureDomain
  dataTemplate:
    name: m3dt-rack2              # ← overridden by controller (rack2 mapping)
    namespace: metal3
status:
  networkData:
    name: my-cluster-cp-yyyyy-networkdata
    # → secret contents: VLAN 200, subnet 10.0.2.0/24
---
# Machine 3: assigned to rack3 by KCP
kind: Metal3Machine
metadata:
  name: my-cluster-cp-zzzzz
spec:
  failureDomain: rack3            # ← synced from Machine.Spec.FailureDomain
  dataTemplate:
    name: m3dt-rack3              # ← overridden by controller (rack3 mapping)
    namespace: metal3
status:
  networkData:
    name: my-cluster-cp-zzzzz-networkdata
    # → secret contents: VLAN 300, subnet 10.0.3.0/24
```

### bmhNamespace usage

Building on the 3-rack scenario above, add `bmhNamespace` per FD and place
each rack's BMHs in its own namespace. The Metal3DataTemplate, IPPool,
Metal3MachineTemplate, and KubeadmControlPlane definitions above remain
unchanged.

```yaml
kind: Metal3Cluster
metadata:
  name: my-cluster
  namespace: metal3
spec:
  controlPlaneEndpoint:
    host: 192.168.0.100
    port: 6443
  failureDomains:
  - name: rack1
    controlPlane: true
    bmhNamespace: rack1     # NEW
  - name: rack2
    controlPlane: true
    bmhNamespace: rack2
  - name: rack3
    controlPlane: true
    bmhNamespace: rack3
```

BMHs move into per-rack namespaces (labels unchanged):

```yaml
# namespace: rack1
kind: BareMetalHost
metadata:
  name: bmh-cp-01
  namespace: rack1
  labels:
    infrastructure.cluster.x-k8s.io/failure-domain: rack1
spec:
  online: true
  bootMACAddress: "AA:BB:CC:DD:01:01"
  bmc:
    address: ipmi://192.168.0.11
    credentialsName: bmh-cp-01-credentials   # in namespace rack1
```

(rack2 and rack3 follow the same pattern.)

## Backward Compatibility

`failureDomainDataTemplates`:

- Optional field. Omitting it preserves the existing behavior — all
  machines use the single `dataTemplate` from the template spec.
- No changes are required to `Metal3DataTemplate`, `Metal3DataClaim`,
  `Metal3Data`, or the secret rendering pipeline.
- Existing clusters without failure domains or without this field are
  completely unaffected.

`bmhNamespace`:

- Optional field. Omitting it preserves the existing same-namespace BMH
  selection behavior.
- Requires PR [#2506][pr-2506]. The earliest CAPM3 release that can
  carry it is the same release that ships the BMH `ownerReference`
  removal.

## Alternatives Considered

### Per-FailureDomain NetworkData inside Metal3DataTemplate

Embed FD-specific `networkData` overrides directly in
`Metal3DataTemplateSpec`. Rejected because it requires changes across the
entire data rendering pipeline (`Metal3DataClaim` → `Metal3Data` → secret)
and makes the `Metal3DataTemplate` object significantly more complex.

### Convention-based via FailureDomain.Attributes

Use `FailureDomain.Attributes["dataTemplate"]` to reference a
`Metal3DataTemplate` by name. Rejected because it relies on string-based
conventions without type safety or webhook validation, making it error-prone
and harder to discover.

### `HostSelector.{Namespaces,NamespaceSelector}` (bmhNamespace alternative)

Add namespace selection directly on `HostSelector` of
`Metal3MachineTemplate`. Allows many-to-many FD ↔ namespace mapping but
bypasses CAPI's standard FD spread, repeats the namespace list on every
template, and introduces xor validation surface. Rejected as the primary
mechanism; kept as a possible future extension if many-to-many requirements
emerge.

## Related

- [FD Support for Control-Plane Nodes](fd-support-kcp.md) — the original
  proposal for FD-based BMH selection
- [CAPV FD support](https://github.com/kubernetes-sigs/cluster-api-provider-vsphere/blob/main/docs/proposal/20201103-failure-domain.md)
- [PR metal3-io/cluster-api-provider-metal3#2506 — Remove Metal3Machine owner reference from BMH][pr-2506]
- [Kubernetes #94631 — ownerReference cross-namespace](https://github.com/kubernetes/kubernetes/issues/94631)

[pr-2506]: https://github.com/metal3-io/cluster-api-provider-metal3/pull/2506
