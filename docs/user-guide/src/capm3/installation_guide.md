# Install Cluster-api-provider-metal3

You can either use clusterctl (recommended) to install Metal³ infrastructure provider
or kustomize for manual installation. Both methods install provider CRDs,
its controllers and [Ip-address-manager](https://github.com/metal3-io/ip-address-manager).
Please keep in mind that Baremetal Operator and Ironic are decoupled from CAPM3
and will not be installed when the provider is initialized. As such, you need to
install them yourself.

## Prerequisites

1. Install `clusterctl`, refer to Cluster API
   [book](https://cluster-api.sigs.k8s.io/user/quick-start.html#install-clusterctl)
   for installation instructions.
1. Install `kustomize`, refer to official instructions
   [here](https://kubectl.docs.kubernetes.io/installation/kustomize/).
1. Install Ironic, refer to [this page](../ironic/ironic_installation.html).
1. Install Baremetal Operator, refer to
   [this page](../bmo/install_baremetal_operator.html).
1. Install Cluster API core components i.e., core, bootstrap and control-plane
   providers. This will also install cert-manager, if it is not already
   installed.

    ```bash
     clusterctl init --core cluster-api{{#releasetag owner:"kubernetes-sigs" repo:"cluster-api"}} --bootstrap kubeadm{{#releasetag owner:"kubernetes-sigs" repo:"cluster-api"}} \
     --control-plane kubeadm{{#releasetag owner:"kubernetes-sigs" repo:"cluster-api"}} -v5
    ```

## With clusterctl

This method is recommended. You can specify the CAPM3 version you want to
install by appending a version tag, e.g.
`{{#releasetag owner:"metal3-io" repo:"cluster-api-provider-metal3" }}`. If the
version is not specified, the latest version available will be installed.

```bash
clusterctl init --infrastructure metal3{{#releasetag owner:"metal3-io" repo:"cluster-api-provider-metal3"}}
```

## With kustomize

To install a specific version, checkout the
`github.com/metal3-io/cluster-api-provider-metal3.git` to the tag with the
desired version

```bash
git clone https://github.com/metal3-io/cluster-api-provider-metal3.git
cd cluster-api-provider-metal3
git checkout v1.1.2 -b v1.1.2

```

Then, edit the controller-manager image version in `config/default/capm3/manager_image_patch.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: controller-manager
  namespace: system
spec:
  template:
    spec:
      containers:
      # Change the value of image/tag to your desired image URL or version tag
      - image: quay.io/metal3-io/cluster-api-provider-metal3:v1.1.2
        name: manager
```

Apply the manifests

```bash
cd cluster-api-provider-metal3
kustomize build config/default | kubectl apply -f -
```
