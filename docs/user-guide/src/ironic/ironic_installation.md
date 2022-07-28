# Install Ironic

Metal3 runs Ironic as a set of containers. Those containers
can be deployed either in-cluster and out-of-cluster. In both scenarios,
there are a couple of containers that must run in order to provision
baremetal nodes.

- ironic
- ironic-inspector
- ironic-endpoint-keepalived
- ironic-log-watch
- ipa-downloader
- dnsmasq
- httpd

To know more about each container's functionality check the documentation
[here](https://github.com/metal3-io/ironic-image#description).

## Prerequisites

Container runtime (e.g., docker, podman). Here we use docker.

## Environmental variables

{{#include ironic_variables.md}}

## Ironic in-cluster installation

For in-cluster Ironic installation, we will run a set of containers within
a single pod in a Kubernetes cluster. You can enable TLS or basic auth or even
disable both for Ironic and inspector communication. Below we will see kustomize
folders that will help us to install Ironic for each mentioned case. In each
of these deployments, a ConfigMap will be created and mounted to the Ironic pod.
The ConfigMap will be populated based on environment variables from
[ironic-deployment/default/ironic_bmo_configmap.env](https://github.com/metal3-io/baremetal-operator/blob/main/ironic-deployment/default/ironic_bmo_configmap.env). As such, update
`ironic_bmo_configmap.env` with your custom values before deploying the Ironic.

We assume you are inside the local baremetal-operator path, if not you need to
clone it first and `cd` to the root path.

```bash
 git clone https://github.com/metal3-io/baremetal-operator.git
 cd baremetal-operator
```

Basic authentication enabled:

```bash
 kustomize build ironic-deployment/basic-auth | kubectl apply -f -
```

TLS enabled:

```bash
 kustomize build ironic-deployment/basic-auth/tls | kubectl apply -f -
```

## Ironic out-of-cluster installation

For out-of-cluster Ironic installation, we will run a set of docker containers outside
of a Kubernetes cluster. To pass Ironic settings, you can export corresponding [environmental
variables](#environmental-variables) on the current shell before calling [run_local_ironic.sh](https://github.com/metal3-io/baremetal-operator/blob/main/tools/run_local_ironic.sh)
installation script. This will start below containers:

- ironic
- ironic-inspector
- ironic-endpoint-keepalived
- ironic-log-watch
- ipa-downloader
- dnsmasq
- httpd
- mariadb; if `IRONIC_USE_MARIADB` = "true"

If in-cluster ironic installation, we used different manifests for TLS and basic auth,
here we are exporting environment variables for enabling/disabling TLS & basic auth
but use the same script.

TLS and Basic authentication disabled

```bash
 export IRONIC_FAST_TRACK="false"  # Example of manipulating Ironic settings
 export IRONIC_TLS_SETUP="false"   # Disable TLS
 export IRONIC_BASIC_AUTH="false"  # Disable basic auth
 ./tools/run_local_ironic.sh
```

Basic authentication enabled

```bash
 export IRONIC_TLS_SETUP="false"
 export IRONIC_BASIC_AUTH="true"
 ./tools/run_local_ironic.sh
```

TLS enabled

```bash
 export IRONIC_TLS_SETUP="true"
 export IRONIC_BASIC_AUTH="false"
 ./tools/run_local_ironic.sh
```