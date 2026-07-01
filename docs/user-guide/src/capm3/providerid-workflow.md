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

## CAPM3 ProviderID Format

The ProviderID format used by CAPM3 is built from Kubernetes object names:

```yaml
metal3://<namespace>/<bmh-name>/<m3m-name>
```

Example: `metal3://metal3/node-0/test-m3m`

This is the only format supported from CAPM3 v1.14 onwards. CAPM3 generates
this value automatically when a node is provisioned — no user configuration is
needed.

> **History:** Before the name-based format was introduced in release v1.1.1
> the ProviderID used a legacy format based on the BareMetalHost
> UID: `metal3://<BMH-UID>` (e.g.
> `metal3://d668eb95-5df6-4c10-a01a-fc69f4299fc6`). Support for this legacy
> format was deprecated in v1.13 and **removed in v1.14**. See
> [Migrating from Legacy ProviderID](#migrating-from-legacy-providerid) below
> for upgrade guidance.

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

The reconciler computes the ProviderID (`metal3://<namespace>/<bmh-name>/<m3m-name>`)
for this machine, then lists all nodes on the workload cluster and compares each
node's `spec.providerID` against this value. If a matching node is found, the
machine is marked ready and the reconciler returns — nothing more needs to be
done except wait for CAPI to set `Machine.status.nodeRef`.

The ProviderID is derived as follows:

- The BMH name comes from the `metal3.io/BareMetalHost` annotation on the
  `Metal3Machine`, which takes the form `<namespace>/<name>`.
- The Metal3Machine name and namespace come from the object itself.

---

### Step 2 — Cloud provider path

This step is taken when `Metal3Cluster.spec.cloudProviderEnabled` is `true`, or
`Metal3Cluster.spec.noCloudProvider` is explicitly `false`.

When a cloud provider is present, it is responsible for setting `spec.providerID`
on the workload-cluster node before CAPM3 runs. CAPM3 searches for a node whose
`spec.providerID` matches `metal3://<namespace>/<bmh-name>/<m3m-name>`. When a
matching node is found, CAPM3 copies the node's `spec.providerID` value verbatim
to `Metal3Machine.spec.providerID` and marks the machine ready.

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
     `Metal3Machine.spec.providerID` to `metal3://<namespace>/<bmh-name>/<m3m-name>`,
     marks the machine ready, then patches `node.spec.providerID` on the
     workload cluster.
   - If the node already has a ProviderID matching the expected format: copies
     it to `Metal3Machine.spec.providerID` and marks the machine ready (covers
     the CAPI pivot / move scenario).
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
value `metal3://<namespace>/<bmh-name>/<m3m-name>`.

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

---

## Migrating from Legacy ProviderID

### Who is affected

The legacy ProviderID format (`metal3://<BMH-UID>`) was the only format before
the name-based format was introduced in release v1.1.1
[PR #563](https://github.com/metal3-io/cluster-api-provider-metal3/pull/563)
(March 2022). It was still accepted by CAPM3 through v1.13. In CAPM3 v1.14,
all code supporting the legacy format has been removed.

**Most users are not affected.** The standard `clusterctl` templates generated
by CAPM3 do **not** include a `--provider-id` kubelet argument. Without that
argument, CAPM3 assigns the ProviderID automatically (in the correct format) and
no manual configuration is needed.

You **are** affected only if your `KubeadmControlPlane` or
`KubeadmConfigTemplate` manifests explicitly set the kubelet `--provider-id`
argument to the legacy format:

```yaml
kubeletExtraArgs:
- name: provider-id
  value: "metal3://{{ ds.meta_data.uuid }}"
```

This was never part of the official `clusterctl` template, but it may exist in
custom user configurations.

### What happens if you don't migrate

Upgrading CAPM3 to v1.14 alone does **not** cause immediate issues. Existing
nodes keep running with whatever ProviderID was previously set, and the CAPM3
controller is not triggered to re-check existing nodes.

The problem surfaces on the **next rolling update** (e.g. a Kubernetes version
upgrade or any change that triggers machine replacement). When new nodes are
provisioned:

1. The kubelet boots with `--provider-id=metal3://{{ ds.meta_data.uuid }}`,
   setting `node.spec.providerID` to `metal3://<BMH-UID>`.
1. The upgraded CAPM3 controller expects
   `metal3://<namespace>/<bmh-name>/<m3m-name>`.
1. The mismatch causes the controller to fail matching the node to the Machine,
   and new machines get stuck and never become ready.

### Migration steps

Perform this migration **before or during** the upgrade to CAPM3 v1.14, and
**before** triggering any rolling updates on your workload clusters.

#### 1. Identify affected templates

Check your `KubeadmControlPlane` and `KubeadmConfigTemplate` resources for
the legacy `provider-id` kubelet argument. If neither contains a `provider-id`
entry with `metal3://{{ ds.meta_data.uuid }}` you are not affected and no
action is needed.

#### 2. Remove the legacy provider-id argument

Remove the `provider-id` entry from `kubeletExtraArgs` in both
`initConfiguration` and `joinConfiguration` sections. CAPM3 will then
automatically assign the correct format when new nodes are provisioned.

The entry to remove looks like this:

```yaml
- name: provider-id
  value: "metal3://{{ ds.meta_data.uuid }}"
```

**Do not** remove the `node-labels` entry — the `metal3.io/uuid` label is still
required for CAPM3 to locate nodes:

```yaml
- name: node-labels
  value: "metal3.io/uuid={{ ds.meta_data.uuid }}"
```

Upgrade to CAPM3 v1.14. After the template change and CAPM3 upgrade, any rolling
update (Kubernetes version bump, machine template change, etc.) will create new
nodes without the explicit `--provider-id` flag. CAPM3 will automatically assign
`metal3://<namespace>/<bmh-name>/<m3m-name>` to each new node.

Existing nodes that were provisioned with the legacy ProviderID continue to
work — CAPM3 does not re-evaluate the ProviderID on already-running machines.
The old ProviderID value remains on those nodes and their corresponding
`Metal3Machine` objects until the machines are replaced through a rolling
update.

After a full rolling update completes, all nodes in the cluster will have the
new format.
