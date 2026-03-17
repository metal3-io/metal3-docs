# CAPM3 controller pod placement

By default, the CAPM3 controller manager deployment is aligned with
upstream Cluster API:

- The pod has **toleration** so it can run on control-plane nodes, which
   are typically tainted:
   - `node-role.kubernetes.io/master:NoSchedule`
   - `node-role.kubernetes.io/control-plane:NoSchedule`
- It does **not** set any node affinity. This keeps the manifests
   environment agnostic and lets cluster administrators decide where
   controllers should run.

This means that, unless additional scheduling constraints are configured,
CAPM3 controller pods may run on either control-plane or worker nodes,
depending on node labels, taints and the cluster's scheduling policies.

## Hardening pod placement

In many environments it is desirable to keep infrastructure controllers
away from regular workloads, for example by running them only on
control-plane or dedicated infra nodes. CAPM3 does not enforce this by
default, but you can add your own scheduling constraints via:

- **CAPI Operator** – configure provider specs as documented in the
   [Cluster API Operator provider configuration docs](https://cluster-api-operator.sigs.k8s.io/topics/configuration/provider-spec-configuration#provider-spec).
- **clusterctl** – use
   [`clusterctl` configuration overrides](https://cluster-api.sigs.k8s.io/clusterctl/configuration#overrides-layer)
   or
   [`clusterctl generate provider`](https://cluster-api.sigs.k8s.io/clusterctl/commands/generate-provider)
   to customize the rendered manifests.
- **kustomize** – patch the CAPM3 manager `Deployment` to add
   `spec.template.spec.affinity.nodeAffinity` and any extra toleration's.

## Example: affinity for control-plane / infra nodes

The CAPM3 repository includes example kustomize patches under
`examples/provider-components/`, such as
`manager_node_affinity_patch.yaml`. This patch demonstrates how to:

- Require pods to schedule only on nodes labelled as control-plane or
   infra, and
- Prefer infra nodes first, then control-plane nodes when both exist.

You can use this example as a starting point and adapt it to match the
labels and policies used in your own clusters. For example, you might
replace `node-role.kubernetes.io/infra` with a custom label that marks
dedicated infrastructure nodes in your environment.
