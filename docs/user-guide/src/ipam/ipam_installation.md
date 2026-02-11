# Installing IPAM as Deployment

This section will show how  IPAM can be installed as a deployment in a cluster.

## Deploying controllers

CAPI and IPAM controllers need to be deployed at the beginning. The IPAM
controller has a dependency on Cluster API *Cluster* objects. CAPI CRDs and
controllers must be deployed and the cluster objects should exist for
successful deployments.

## Deployment

The user can create the **IPPool** object independently. It will wait for its
cluster to exist before reconciling. If the user wants to create **IPAddress**
objects manually, they should be created before any claims. It is highly
recommended to use the *preAllocations* field itself or have the reconciliation
paused.

After an **IPClaim** object creation, the controller will list all existing
**IPAddress** objects. It will then select randomly an address that has not
been allocated yet and is not in the *preAllocations* map. It will then create
an **IPAddress** object containing the references to the **IPPool** and
**IPClaim** and the address, the prefix from the address pool or the default
prefix, and the gateway from the address pool or the default gateway.

### Deploy IPAM

Deploys IPAM CRDs and IPAM controllers. We can run Makefile target from inside
the cloned IPAM git repo.

```sh
    make deploy
```

### Run locally

Runs IPAM controller locally

```sh
    kubectl scale -n capm3-system deployment.v1.apps/metal3-ipam-controller-manager \
      --replicas 0
    make run
```

### Deploy an example pool

```sh
    make deploy-examples
```

### Delete the example pool

```sh
    make delete-examples
```

## Deletion

When deleting an **IPClaim** object, the controller will simply delete the
associated **IPAddress** object. Once all **IPAddress** objects have been
deleted, the **IPPool** object can be deleted. Before that point, the finalizer
in the **IPPool** object will block the deletion.

## References

1. [IPAM](https://github.com/metal3-io/ip-address-manager/).
1. [IPAM deployment workflow](https://github.com/metal3-io/ip-address-manager/blob/main/docs/deployment_workflow.md).
1. Custom resource (CR) examples in
   [metal3-dev-env](https://github.com/metal3-io/metal3-dev-env), in the
   [templates](https://github.com/metal3-io/metal3-dev-env/tree/main/tests/roles/run_tests/templates).
