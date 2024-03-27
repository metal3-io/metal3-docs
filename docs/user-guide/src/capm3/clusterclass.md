# Using ClusterClass with CAPM3

ClusterClass is a feature of Cluster API that enables the cluster operators to
create multiple clusters using a single general template. You can find detailed
explanation of how to use a `ClusterClass` in the
[Cluster API documentation](https://github.com/kubernetes-sigs/cluster-api/blob/main/docs/proposals/20210526-cluster-class-and-managed-topologies.md)

## Prerequisites

### ClusterClass support enabled in CAPI

To use ClusterClass with CAPM3, experimental feature `ClusterClass` has to be
enabled in CAPI deployment. You can find more info on how to enable ClusterClass
support [in The Cluster API Book](https://cluster-api.sigs.k8s.io/tasks/experimental-features/cluster-class/).

## Deploying cluster using ClusterClass

### Deploying a ClusterClass

To create ClusterClass for CAPM3 a few objects has to be deployed in the
management-cluster:

- Metal3ClusterTemplate - a template that will be used by ClusterClass
controller to instantiate the cluster.

- KubeadmControlPlaneTemplate - a template used to create Kubeadm Control Plane
for the instantiated cluster.

- Metal3MachineTemplate - templates that will be used to create Metal3Machine
objects. Can be defined saparately for control plane and worker nodes.

- KubeadmConfigTemplate - a template for Kubeadm config.

- ClusterClass - the final object that references above objects and consolidates
them into single cluster template definition.

You can find example of those objects
[in the example file available on the CAPM3 repository](https://github.com/metal3-io/cluster-api-provider-metal3/blob/main/examples/templates/clusterclass.yaml).

### Deploying a Cluster

Definitions described above can be used to deploy multiple clusters. However
some resources has to be deployed specifically for the cluster:

- Metal3DataTemplate - should be created for both worker and control plane nodes
in the cluster

- IPPools - should be created per cluster if required.

- Cluster - used to instantiate cluster using `ClusterClass`. You can change
cluster behavior by overriding variables defined in the `ClusterClass`.

Example definitions of those resources
[can be found in the CAPM3 repository](https://github.com/metal3-io/cluster-api-provider-metal3/blob/main/examples/templates/cluster.yaml).

## Tilt based development environment

If you want to further develop or test ClusterClass support you can use Tilt
environment.

1. Clone CAPM3 repository.

    ```shell
    git clone https://github.com/metal3-io/cluster-api-provider-metal3.git
    ```

1. Generate Tilt settings that will enable ClusterClass support in CAPI.

    ```shell
    make tilt-settings-clusterclass
    ```

1. Start Tilt.

    ```shell
    make tilt-up
    ```

1. Generate ClusterClass based example.

    ```shell
    make generate-examples-clusterclass
    ```

1. Deploy example `ClusterClass`, `Cluster` and all the dependencies.

    ```shell
    make deploy-examples-clusterclass
    ```
