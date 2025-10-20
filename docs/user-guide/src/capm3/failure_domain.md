# Failure Domains in Metal3

## What is Failure Domain?

Failure Domain: A topology label (e.g., row-a, rack-12) grouping hosts that
share a common failure domains.

## Why Failure Domain?

Baremetal environments often have racks, rows, or sites with different network
setups. The Failure Domain (FD) feature allows users to distribute
control-plane nodes across these different locations for improved resilience
and fault isolation.

Cluster API (CAPI) supports FD for control-plane nodes through the
KubeadmControlPlane (KCP) controller. KCP reads the set of FDs from
`ProviderCluster.Spec.FailureDomains`. If defined, these values are copied to
`Cluster.Status.FailureDomains`. KCP then selects an FD from this set
and places its value in `Machine.Spec.FailureDomain`. CAPM3 machine controller
reads `Machine.Spec.FailureDomain` and sets to
`metal3Machine.Spec.FailureDomain`. By default, KCP attempts to balance Control
Plane Machines evenly across all defined FDs.

## How to use?

In public clouds, FDs are pre-defined. But in Metal3, users need to manually
define and assign FDs to BareMetalHosts.

1. Label BareMetalHosts with their FD:

    ```yaml
    metadata:
      labels:
        infrastructure.cluster.x-k8s.io/failure-domain: rack-2
    ```

1. Define these FDs in the Metal3Cluster specification:

    ```yaml
    kind: Metal3Cluster
    spec:
      failureDomains:
        my-fd-1:
          controlPlane: true
          attributes:
            datacenter: hki-dc1
            row: A
            rack: 1
            powerFeed: pf-1a
        my-fd-2:
          controlPlane: true
          attributes:
            switch: 10Gbps
    ```

CAPM3 checks the `Metal3Machine.Spec.FailureDomain` field. If it is set, CAPM3
tries to associate a BMH from the specified FD. If no BMH is
available in that domain, it will select another available host in any
other FD.

**Note:** User can populate FD labels to kubernetes node level using [label
synchronization feature](./label_sync.md).
