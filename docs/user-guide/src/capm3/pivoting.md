# CAPM3 Pivoting

<!-- cSpell:ignore cakcp -->

## What is pivoting

Cluster API Provider Metal3 (CAPM3) implements support for CAPI's
'move/pivoting' feature.

CAPI Pivoting feature is a process of moving the provider components and
declared Cluster API resources from a source management cluster to a target
management cluster by using the `clusterctl` functionality called "move". More
information about the general CAPI "move" functionality can be found
[here](https://cluster-api.sigs.k8s.io/clusterctl/commands/move.html).

In Metal3, pivoting is performed by using the CAPI `clusterctl` tool provided
by Cluster-API project. `clusterctl` recognizes pivoting as move. During the
pivot process `clusterctl` pauses any reconciliation of CAPI objects and this
gets propagated to CAPM3 objects as well. Once all the objects are paused, the
objects are created on the other side on the target cluster and deleted from
the bootstrap cluster.

## Prerequisite

1. **It is mandatory to use `clusterctl` for both the bootstrap and target cluster.**

   If the provider components are not installed using `clusterctl`, it will not
   be able to identify the objects to move. Initializing the cluster using
   `clusterctl` essentially adds the following labels in the CRDs of each
   related object.

   ```yaml
   labels:
   - clusterctl.cluster.x-k8s.io: ""
   - cluster.x-k8s.io/provider: "<provider-name>"
   ```

   So if the clusters are not initialized using `clusterctl`, all the CRDS of
   the objects to be moved to target cluster needs to have these labels both in
   bootstrap cluster and target cluster before performing the move.

   **Note**: This is not recommended, since the way `clusterctl` identifies
   objects to manage might change in the future, so it's always safe to install
   CRDs and controllers through the `clusterctl init` sub-command.

1. **BareMetalHost objects have correct status annotation.**

   Since BareMetalHost (BMH) _status_ holds important information regarding the
   BMH itself, BMH with status has to be moved and it has to be reconstructed
   with correct status in target cluster before it is being reconciled. This is
   now done through BMH status annotation in [BMO](../bmo/introduction.md).

1. **Maintain connectivity towards provisioning network.**

   Baremetal machines boot over a network with a DHCP server. This requires
   maintaining a fixed IP end points towards the provisioning network. This is
   achieved through _keepalived_. A new container is added namely
   _ironic-endpoint-keepalived_ in the ironic deployment which maintains the
   Ironic Endpoint using keepalived. The motivation behind maintaining Ironic
   Endpoint with Keepalived is to ensure that the Ironic Endpoint IP is also
   passed onto the target cluster control plane. This also guarantees that once
   moving is done and the management cluster is taken down, target cluster
   controlplane can re-claim the Ironic endpoint IP through keepalived. The end
   goal is to make Ironic endpoint reachable in the target cluster.

1. **BMO is deployed as part of CAPM3.**

   If not, it has to be deployed before the `clusterctl init` and the BMH CRDs
   need to be labeled accordingly manually. Separate labeling for BMH CRDs is required
   because since CAPM3 release [v0.5.0](https://github.com/metal3-io/cluster-api-provider-metal3/releases/tag/v0.5.0)
   BMO/BMH CRDs are not deployed as part of CAPM3 deployment anymore.
   This is a prerequisite for both the management and the target cluster.

1. **Objects should have a proper owner reference chain.**

   `clusterctl move` moves all the objects to the target cluster following the
   [owner reference chain](https://cluster-api.sigs.k8s.io/developer/providers/contracts/clusterctl#ownerreferences-chain).
   So, it is necessary to verify that all the desired objects that needs to
   be moved to the target cluster have a proper owner reference chain.

## Important Notes

The following requirements are essential for the move process to run
successfully:

1. The move process should be done when the BMHs are in a steady state. BMHs
   should not be moved while any operation is on-going i.e. BMH is in
   provisioning state. This will result in failure since the interaction between
   IPA and Ironic gets broken and as a result Ironic's database might not be
   repopulated and eventually the cluster will end up in an erroneous state.
   Moreover, the IP of the BMH might change after the move and the DHCP-leases
   from the management cluster are not moved to target cluster.

1. Before the move process is initialized, it is important to delete the Ironic
   pod/Ironic containers. If Ironic is deployed in cluster the deployment is named
   `metal3-ironic`, if it is deployed locally outside the cluster then the user
   has to make sure that all of the ironic related containers are correctly deleted.
   If Ironic is not deleted before move, the old Ironic might interfere with
   the operations of the new Ironic deployed in target cluster since the
   database of the first Ironic instance is not cleaned when the BMHs are moved.
   Also there would be two dnsmasq existent in the deployment if there would be
   two Ironic deployment which is undesirable.

1. The provisioning bridge where the `ironic-endpoint-IP` is supposed to be
   attached to should have a static IP assignment on it before the Ironic
   pod/containers start to operate in the target cluster. This is important since
   `ironic-endpoint-keepalived` container will only assign the `ironic-endpoint-IP`
   on the provisioning bridge in target cluster when it has an IP on it. Otherwise
   it will fail to attach the IP and Ironic will be unreachable. This is crucial
   because this interface is used to host the DHCP server and so it cannot be
   configured to use DHCP.

## Step by step pivoting process

As described in
[clusterctl](https://cluster-api.sigs.k8s.io/clusterctl/commands/move.html)
the whole process of bootstrapping a management cluster to moving
objects to target cluster can be described as follows:

The move process can be bounded with the creation of a temporary bootstrap
cluster used to provision a target management cluster.

This can now be achieved with the following procedure:

1. Create a temporary bootstrap cluster, the temporary bootstrap cluster could
   be created tools like e.g. using Kind or Minikube using and after the
   bootstrap cluster is up and running then the CAPI and provider components
   can be installed with `clusterctl` to the bootstrap cluster.

1. Install Ironic components, namely: ironic, ironic-endpoint-keepalived, httpd
   and dnsmasq.

1. Use clusterctl init to install the provider components

   Example:

   ```bash
   clusterctl init --infrastructure metal3{{#releasetag owner:"metal3-io" repo:"cluster-api-provider-metal3" }}
   --target-namespace metal3 --watching-namespace metal3
   ```

   This command will create the necessary CAPI controllers (CAPI, CABPK, CAKCP)
   and CAPM3 as the infrastructure provider. All of the controllers will be installed
   on namespace `metal3` and they will be watching over objects in namespace `metal3`.

1. Provision target cluster:

   Example:

   ```bash
   clusterctl config cluster ... | kubectl apply -f -
   ```

1. Wait for the target management cluster to be up and running and once it is up
 get the kubeconfig for the new target management cluster.

1. Use the new cluster's kubeconfig to install the ironic-components in the
 target cluster.

1. Use `clusterctl` init with the new cluster's kubeconfig to install the provider
 components.

    Example:

    ```bash
    clusterctl init --kubeconfig target.yaml --infrastructure metal3{{#releasetag owner:"metal3-io" repo:"cluster-api-provider-metal3" }}
    --target-namespace metal3 --watching-namespace metal3
    ```

1. Use `clusterctl` move to move the Cluster API resources from the bootstrap
 cluster to the target management cluster.

    Example:

    ```bash
    clusterctl move --to-kubeconfig target.yaml -n metal3 -v 10
    ```

1. Delete the bootstrap cluster
