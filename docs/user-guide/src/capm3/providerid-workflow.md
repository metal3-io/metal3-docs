# ProviderID Workflow

This document describes how CAPM3 assigns a `ProviderID` to a `Metal3Machine`
and how it propagates that ID to the corresponding Kubernetes `Node` on the
workload cluster.

## Background: What is a ProviderID?

In Cluster API, every infrastructure provider (i.e. CAPM3) must set `spec.providerID`
on the infrastructure machine object (here, `Metal3Machine`) once provisioning
is complete. CAPI then copies that value to `Machine.spec.providerID` and uses it
to correlate the `Machine` with the Kubernetes `Node` that the workload kubelet
registers. Without a matching `providerID` on both the `Machine` and the `Node`,
CAPI never sets `Machine.status.nodeRef` and the cluster never transitions to
`Running`.

## CAPM3 ProviderID Formats

**Legacy format** — built from the BareMetalHost UID:

```yaml
metal3://<BMH-UID>
```

Example: `metal3://d668eb95-5df6-4c10-a01a-fc69f4299fc6`

> **Deprecation notice:** The legacy ProviderID format **will be deprecated
> in CAPM3 v1.13** and **removed in CAPM3 v1.14**. New clusters should always
> use the new format below. Existing clusters using the legacy format must
> migrate before upgrading to v1.14.

**New format** — built from Kubernetes object names:

```yaml
metal3://<namespace>/<bmh-name>/<m3m-name>
```

Example: `metal3://metal3/node-0/test-m3m`

**This is the only format supported from CAPM3 v1.14 onwards.**

The new format is used for all freshly provisioned nodes. The legacy format
is still accepted in v1.13 so that clusters provisioned with older CAPM3 versions
continue to work after an upgrade — but this compatibility window closes in v1.14.

## The `metal3.io/uuid` Node Label

### What it is

`metal3.io/uuid` is a Kubernetes node label whose value is the **BareMetalHost
`metadata.uid`** — the Kubernetes-assigned UID of the `BareMetalHost` object,
not an Ironic-internal UUID. CAPM3 uses it as the primary mechanism to find the
workload-cluster `Node` that corresponds to a given `BareMetalHost`.

### Who sets it

**CAPM3 does not set this label.** It only reads it.

The label must be applied by the **kubelet at node-registration time**, which
means it must be declared in the `kubeadm` node registration configuration
before the node boots. Ironic passes the BMH UID to cloud-init under the key
`ds.meta_data.uuid`. The `KubeadmControlPlane` or `KubeadmConfig` must forward
that value to kubelet using `kubeletExtraArgs`.

```yaml
nodeRegistration:
  name: '{{ ds.meta_data.name }}'
  kubeletExtraArgs:
  - name: node-labels
    value: 'metal3.io/uuid={{ ds.meta_data.uuid }}'
```

This snippet must appear in **both** `initConfiguration` (the first control
plane node) and `joinConfiguration` (every subsequent node that joins the
cluster).

## Reconciliation workflow

The ProviderID logic is triggered only after the `BareMetalHost` has reached
`Provisioned` state. Once that condition is met, the reconciler walks through
the following steps in order and returns as soon as one succeeds.

---

### Step 1 — Check for an existing matching Node

The reconciler computes both the legacy and new ProviderID values for this
machine, then lists all nodes on the workload cluster and compares each node's
`spec.providerID` against both values. If a matching node is found, the machine
is marked ready and the reconciler returns — nothing more needs to be done
except wait for CAPI to set `Machine.status.nodeRef`.

The two IDs are derived as follows:

- The BMH name comes from the `metal3.io/BareMetalHost` annotation on the
  `Metal3Machine`, which takes the form `<namespace>/<name>`.
- The BMH UID comes from a live lookup of the `BareMetalHost` object.

---

### Step 2 — Cloud provider path

This step is taken when `Metal3Cluster.spec.cloudProviderEnabled` is `true`, or
`Metal3Cluster.spec.noCloudProvider` is explicitly `false`.

When a cloud provider is present, it is responsible for setting `spec.providerID`
on the workload-cluster node before CAPM3 runs. CAPM3 searches for a node whose
`spec.providerID` matches either the legacy format (`metal3://<bmh-uuid>`) or
the new format (`metal3://<namespace>/<bmh-name>/<m3m-name>`). When a matching
node is found, CAPM3 copies the node's `spec.providerID` value verbatim to
`Metal3Machine.spec.providerID` and marks the machine ready.

This means the ProviderID on the `Metal3Machine` will be in whatever format the
cloud provider chose. CAPM3 itself does not set or override a different format in
this path.

---

### Step 3 — Node label path (standard path without a cloud provider)

This is the path taken in the vast majority of Metal3 deployments.

1. The BMH UID is read from the associated `BareMetalHost` object.
1. The workload-cluster node list is filtered by the label selector
   `metal3.io/uuid=<BMH-UID>`.
1. If zero nodes are found and a bootstrap `ConfigRef` is defined, the
   reconciler requeues — the node has either not yet joined or cloud-init has
   not finished setting the label.
1. If more than one node is found with the same label, a hard error is returned
   — this is a misconfiguration.
1. If exactly one node is found:
   - If the node has no `spec.providerID` yet: sets
     `Metal3Machine.spec.providerID` to the **new format**, marks the machine
     ready, then patches `node.spec.providerID` on the workload cluster.
   - If the node already has a ProviderID matching the new format: copies it to
     `Metal3Machine.spec.providerID` and marks the machine ready (covers the
     CAPI pivot / move scenario).
   - If the node already has a ProviderID matching the legacy format: copies it
     to `Metal3Machine.spec.providerID` and marks the machine ready.
   - Any other ProviderID format on the node is an error.

Only `node.spec.providerID` is patched on the workload-cluster node. No node
labels are modified.

---

### Step 4 — Fallback: set ProviderID by hostname

This path is taken when Step 3 found no node with the `metal3.io/uuid` label —
for example, when the label was not configured in the kubeadm bootstrap, or when
the node was provisioned without a bootstrap `ConfigRef`. It is a best-effort
fallback.

If `Metal3Machine.spec.providerID` is not yet set, it is first assigned the
new-format value `metal3://<namespace>/<bmh-name>/<m3m-name>`.

The reconciler then attempts to find the correct workload-cluster node by
hostname:

1. Hostname is read from `Metal3Machine.status.addresses`.
1. All nodes on the workload cluster are listed.
1. Each node's `kubernetes.io/hostname` label (set automatically by kubelet) is
   compared against the Metal3Machine's hostname list.
1. If no match or multiple matches are found, the reconciler requeues.
1. If exactly one node matches, its `spec.providerID` is patched with the value
   assigned to `Metal3Machine.spec.providerID` above.

---

## Summary of Responsibilities

**You must configure** (before the node boots):

```yaml
# In KubeadmControlPlane.spec.kubeadmConfigSpec and/or KubeadmConfig.spec
initConfiguration:
  nodeRegistration:
    name: '{{ ds.meta_data.name }}'
    kubeletExtraArgs:
    - name: node-labels
      value: 'metal3.io/uuid={{ ds.meta_data.uuid }}'
joinConfiguration:
  nodeRegistration:
    name: '{{ ds.meta_data.name }}'
    kubeletExtraArgs:
    - name: node-labels
      value: 'metal3.io/uuid={{ ds.meta_data.uuid }}'
```

**CAPM3 sets automatically** (no user action needed):

- `Metal3Machine.spec.providerID` — set by the reconciler in Steps 2, 3, or 4.
- `Metal3Machine.status.ready = true` — set in the same step that sets the
  ProviderID.
- `node.spec.providerID` on the workload-cluster Node — patched in Steps 3 and 4.
