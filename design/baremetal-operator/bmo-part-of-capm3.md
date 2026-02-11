# Make Bare Metal Operator as part of Cluster API Provider Metal3

<!-- cSpell:ignore bmopath -->

The end goal behind making Bare Metal Operator(BMO) as part of Cluster
API Provider Metal3(CAPM3) is to use
[clusterctl](https://cluster-api.sigs.k8s.io/clusterctl/commands/move.html)
provided by Cluster API(CAPI) to deploy BMO, so that it can take care of moving
the BaremetalHost during the pivoting.

**There are four use cases of deployment, that will be covered in this proposal document:**

1. Production.

1. Local developer.

1. Ironic running outside of the cluster.

1. Pivoting.

As a starting point, we decided to have a cleaner structure of the
`baremetal-operator/deploy` folder and make it as simple as possible and it will
cover first three use cases from the list provided above. Until now, there are
three deployment use cases exist, i.e. production - `default`, local-developer -
`ironic-keepalived-config`, ironic running outside of the cluster -
`ironic-outside-config` as visualized in tree structure below.

## Current structure of baremetal-operator deployment folder

```diff
tree deploy/

deploy/
├── bmo-capm3
│   ├── ironic_bmo_configmap.env
│   ├── kustomization.yaml
│   └── README.md
├── crds
│   ├── kustomization.yaml
│   └── metal3.io_baremetalhosts_crd.yaml
├── default
│   ├── ironic_bmo_configmap.env
│   └── kustomization.yaml
├── ironic_ci.env
├── ironic-keepalived-config
│   ├── image_patch.yaml
│   ├── ironic_bmo_configmap.env
│   └── kustomization.yaml
├── ironic-outside-config
│   ├── ironic_bmo_configmap.env
│   └── kustomization.yaml
├── namespace
│   ├── kustomization.yaml
│   └── namespace.yaml
├── operator
│   ├── ironic
│   │   ├── kustomization.yaml
│   │   └── operator_ironic.yaml
│   ├── ironic_keepalived
│   │   ├── kustomization.yaml
│   │   └── operator_ironic_keepalived.yaml
│   └── no_ironic
│       ├── kustomization.yaml
│       └── operator.yaml
├── rbac
│   ├── kustomization.yaml
│   ├── role_binding.yaml
│   ├── role.yaml
│   └── service_account.yaml
└── role.yaml -> rbac/role.yaml

```

Our main goal is to bring back deploy scripts as close to operator-sdk tools to
be able to smoothly migrate to the new layout (to generate new API versions) as
well as leaving only BMO deployments in deploy folder, while taking ironic
deployments outside of the folder and moving them to the root of the repository
to the newly created `baremetal-operator/ironic-deployment` folder. The following
directory tree visualize new structure of deploy folder in more detail:

## Proposed structure of baremetal-operator deployment folder

```diff
tree deploy/

deploy/
├── crds
│   ├── kustomization.yaml
│   └── metal3.io_baremetalhosts_crd.yaml
├── default
│   ├── ironic_bmo_configmap.env
│   ├── kustomization.yaml
│   └── kustomizeconfig.yaml
├── ironic_ci.env
├── namespace
│   ├── kustomization.yaml
│   └── namespace.yaml
├── operator
│   ├── bmo.yaml
│   └── kustomization.yaml
├── rbac
│   ├── kustomization.yaml
│   ├── role_binding.yaml
│   ├── role.yaml
│   └── service_account.yaml
└── role.yaml -> rbac/role.yaml

```

As we can see, the `deploy` directory has one top level folder for deployment,
namely `default` and it deploys only baremetal-operator through kustomization
file and uses kustomization config file for teaching kustomize where to look at
when substituting variables. In addition, `crds`, `namespace` and `rbac` folders
have their own kustomization and yaml files. The following directory tree
visualizes a new structure of ironic-deployment folder in more detail:

## Proposed structure of ironic-deployment folder

```diff
tree ironic-deployment/

ironic-deployment/
├── default
│   ├── ironic_bmo_configmap.env
│   └── kustomization.yaml
├── ironic
│   ├── ironic.yaml
│   └── kustomization.yaml
└── keepalived
    ├── ironic_bmo_configmap.env
    ├── keepalived_patch.yaml
    └── kustomization.yaml

```

In the above provided tree, ironic-deployment folder has three top level folders
for deployments, namely `default`, `ironic` and `keepalived`. `default` and
`ironic` folders will deploy only ironic, whereas, `keepalived` folder deploys
the ironic with keepalived. As the name implies, `keepalived/keepalived_patch.yaml`
patches the default image URL through kustomization. The user should run the
following commands to be able to meet requirements of each use case as provided
below:

### Commands to deploy "production" use case after structural changes

```diff
kustomize build $BMOPATH/deploy/default | kubectl apply -f-
kustomize build $BMOPATH/ironic-deployment/default | kubectl apply -f-

```

### Command to deploy "local developer" use case after structural changes

```diff
kustomize build $BMOPATH/ironic-deployment/default | kubectl apply -f-

```

### Command to deploy "ironic outside of the cluster" use case after structural changes

```diff
kustomize build $BMOPATH/deploy/default | kubectl apply -f-

```

where $BMOPATH points to the baremetal-operator path.

To this end, "production", "local developer" and "ironic outside of the cluster"
use cases will be met, as new structure will fulfill the needs of those cases
with cleaner and leaner organization of deployments in place.

## Pivoting use case

Once above outlined folder structural changes are made, we can deploy BMO using
kustomization file which will be residing in CAPM3 repository referencing to
baremetal-operator deployment file in BMO repository and Ironic independently
to meet the use case of pivoting, where BMO should be deployed as part of CAPM3.
The main concern here is that, BMO and Ironic are separated and as a
consequence,it will result in breaking the chain of workflow, where, previously,
BMO could use localhost to talk to ironic without any authentication. However,
considering that Ironic runs in host network, BMO would be able to interact with
it, from anywhere that is connected or routed to the provisioning network.
Therefore, separating Ironic in its own pod should not impact BMO in this case.

Furthermore, to support above provided statement, CAPM3  needs to embed BMO in a
way that it is deployed and modified properly by `clusterctl` without having to
embed ironic as part of the clusterctl. Thus, we created
`cluster-api-provider-metal3/config/bmo/` folder to be able to deploy BMO in
CAPM3. The following directory tree and kustomization file will give more
explanation on what are we trying to achieve as an end-goal.

```diff
tree config/bmo/

config/bmo/
├── bmo_image_patch.yaml
├── bmo_pull_policy.yaml
├── kustomization.yaml
├── kustomizeconfig.yaml
└── README.md

```

where `kustomization.yaml` file contains:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: capm3-system
resources:
- github.com/metal3-io/baremetal-operator/deploy/operator/?ref=main
- github.com/metal3-io/baremetal-operator/deploy/crds/?ref=main
- github.com/metal3-io/baremetal-operator/deploy/rbac/?ref=main
configMapGenerator:
- behavior: create
  literals:
  - DEPLOY_KERNEL_URL=${DEPLOY_KERNEL_URL}
  - DEPLOY_RAMDISK_URL=${DEPLOY_RAMDISK_URL}
  - IRONIC_ENDPOINT=${IRONIC_URL}
  - IRONIC_INSPECTOR_ENDPOINT=${IRONIC_INSPECTOR_URL}
  name: ironic-bmo-configmap
patchesStrategicMerge:
- bmo_image_patch.yaml
- bmo_pull_policy.yaml
configurations:
- kustomizeconfig.yaml
```

The kustomization file deploys `operator`, `rbac` and `crds` defined in
`resources` section using cross repository referencing link.
`bmo_image_patch.yaml` patches the default image URL through kustomization,
`bmo_pull_policy.yaml` determines if the image should be pulled prior to
starting the container and `kustomizeconfig.yaml` teaches the kustomize where to
look at when substituting variables. When the baremetal-operator is deployed
through CAPM3, operator container creates the following environment variables
through the configMapGenerator:

### DEPLOY_KERNEL_URL

This is the URL of the kernel to deploy. For example:

`DEPLOY_KERNEL_URL="http://X.X.X.X:6180/images/ironic-python-agent.kernel"`

### DEPLOY_RAMDISK_URL

This is the URL of the ramdisk to deploy. For example:

`DEPLOY_RAMDISK_URL="http://X.X.X.X:6180/images/ironic-python-agent.initramfs"`

### IRONIC_URL

This is the URL of the ironic endpoint. For example:

`IRONIC_URL="http://X.X.X.X:6385/v1/"`

### IRONIC_INSPECTOR_URL

This is the URL of the ironic inspector endpoint.
For example:

`IRONIC_INSPECTOR_URL="http://X.X.X.X:5050/v1/"`

where `X.X.X.X` is an IP address of Ironic.

The reason why embedding ironic is impossible is that mainly because of the
duplication of `dnsmasq` in the network. Saying that, two of them will be
running during the pivoting, one residing in the management and the other in
the target cluster. To get an instance of the ironic in the target cluster,
successful pivoting state should be met and it further needs manually shutting
down the ephemeral node and deploying ironic.

At this point, BMO will be deployed as part of CAPM3 through `clusterctl` while
Ironic needs to be deployed as provided below:

### Command to deploy Ironic in CAPM3

```diff
kustomize build $BMOPATH/ironic-deployment/keepalived | kubectl apply -f-

```

where $BMOPATH points to the baremetal-operator path.
