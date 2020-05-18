# Move

In the context of Metal3 Provider, _Move_ or _Pivoting_ is the process of moving
CAPI and CAPM3 objects from one management k8s cluster to another. In Metal3,
this process is performed using the
[clusterctl](https://cluster-api.sigs.k8s.io/clusterctl/commands/move.html) tool
provided by CAPI. For the rest of the document we will refer this process as
_Move_.

The following objects are moved during this process:

**Main Objects:** Cluster, Machine, MachineSet, MachineDeployment,
KubeadmControlplane, Metal3Cluster, Metal3Machine, and BareMetalHost

**Related Objects:** Cluster Secrets, BareMetalHost Secrets, Configmaps,
KubeadmConfig, Metal3MachineTemplate

## Prerequisite

* **`clusterctl` is used to initialize both the bootstrap and target cluster.**

  If the provider components are not installed using `clusterctl`, it will not
  be able to identify the objects to move.  Initializing the cluster using
  `clusterctl` essentially adds the following labels in the CRDs of each object
  related.

  ```yaml
  labels:
  - clusterctl.cluster.x-k8s.io: ""
  - cluster.x-k8s.io/provider: "<provider-name>"
  ```

  So if the clusters are not initialized using `clusterctl`, all the CRDS of the
  objects to be moved to target cluster needs to have these labels both in
  bootstrap cluster and target cluster.

* **BMH objects have correct status annotation.**

  Since BMH _status_ holds important information regarding the BMH itself, we
  have to move BMH with status and reconstruct the BMH with correct status in
  target  cluster before it is being reconciled. This is now done through BMH
  status annotation in BMO.

* **Maintain connectivity towards provisioning network.**

  Baremetal machines boot over a network with a DHCP server. This requires
  maintaining a fixed IP end points towards the provisioning network. This is
  achieved through _keepalived_. A new container is added namely
  _ironic-endpoint-keepalived_ which maintains the Ironic Endpoint using
  keepalived. The motivation behind maintaining Ironic Endpoint with Keepalived
  is to ensure that the Ironic Endpoint IP is also passed onto the target
  cluster control plane. This also guarantees that once moving is done and the
   management cluster is taken down, target cluster controlplane can re-claim
   the ironic endpoint IP through keepalived. The end goal is to make ironic
   endpoint reachable in the target cluster.

* **BMO is deployed as part of CAPM3.**

  If not, it has to be deployed before the `clusterctl init` and the BMH CRDs
  need to be labeled accordingly manually. This is a prerequisite for both the
  management and the target cluster.

* **Objects should have a proper owner reference chain.**

  `clusterctl move` moves all the objects to the target cluster following the
[owner reference chain](https://cluster-api.sigs.k8s.io/clusterctl/provider-contract.html#ownerreferences-chain).
So, it is necessary to verify that all the desired objects that needs to
be moved to the target cluster have a proper owner reference chain.

## Move process

As described in
[clusterctl](https://cluster-api.sigs.k8s.io/clusterctl/commands/move.html)
the whole process of bootstrapping a management cluster to moving
objects to target cluster can be described as follows:

The move process can be bounded with the creation of a temporary bootstrap
cluster used to provision a target Management cluster.

This can now be achieved with the following procedure:

1. Create a temporary bootstrap cluster, e.g. using Kind or Minikube using
  clusterctl.

2. Install ironic  components namely: ironic, ironic-inspector, ironic-database,
   ironic-endpoint-keepalived, httpd and dnsmasq.

3. Use clusterctl init to install the provider components

    Example:

    `clusterctl init --infrastructure metal3:v0.3.1
--target-namespace metal3 --watching-namespace metal3`

    This command will create the necessary CAPI controllers (CAPI, CABPK, CAKCP)
  and CAPM3 as the infrastructure provider which also includes the Baremetal
  Operator (BMO). All of the controllers will be installed on namespace `metal3`
  and they will be watching over objects in namespace `metal3`.

   In `metal3-dev-env` steps 1 and 2 are part of `make` command.
4. Provision target cluster:

    Example:

    `clusterctl config cluster ... | kubectl apply -f -`

    In `metal3-dev-env` this is done through the scripts in `scripts/v1alphaX/`
  directory.

5. Wait for the target management cluster to be up and running and once it is up
  get the kubeconfig for the new target management cluster.

6. Use the new cluster’s kubeconfig to install the ironic-components in the
  target cluster.

7. Use clusterctl init with the new cluster’s kubeconfig to install the provider
  components.

    Example:

    `clusterctl init --kubeconfig target.yaml --infrastructure metal3:v0.3.1
  --target-namespace metal3 --watching-namespace metal3`

8. Use clusterctl move to move the Cluster API resources from the bootstrap
  cluster to the target management cluster.

    Example:

    `clusterctl move --to-kubeconfig target.yaml -n metal3 -v 10`

9. Delete the bootstrap cluster

**Important Note** The move process should be done when the BMHs are
in a steady state. BMHs should not be moved while any operation is on-going i.e.
BMH is in provisioning state. This will result in failure since the IP of the
BMH might change after the move and the DHCP-leases from the management cluster
are not moved to target cluster.

Here is a small video to show the whole process. Note that, in this video BMO is
not part of CAPM3 so we manually install it on the target cluster and also label
the BMH CRDs.

![Alt Text](move.gif)
