# Install Ironic

Metal3 runs Ironic as a set of containers. Those containers
can be deployed either in-cluster and out-of-cluster. In both scenarios,
there are a couple of containers that must run in order to provision
baremetal nodes:

- ironic (the main provisioning service)
- ipa-downloader (init container to download and cache the deployment ramdisk
  image)
- httpd (HTTP server that serves cached images and iPXE configuration)

A few other containers are optional:

- ironic-endpoint-keepalived (to maintain a persistent IP address on
  the provisioning network)
- dnsmasq (to support DHCP on the provisioning network and to implement
  network boot via iPXE)
- ironic-log-watch (to provide access to the deployment ramdisk logs)
- mariadb (the provisioning service database; SQLite can be used as
  a lightweight alternative)
- ironic-inspector (the auxiliary inspection service - only used in older
  versions of Metal3)

## Prerequisites

### Networking

A separate provisioning network is required when network boot is used.

The following ports must be accessible by the hosts being provisioned:

- TCP 6385 (Ironic API)
- TCP 5050 (Inspector API; when used)
- TCP 80 (HTTP server; can be changed via the `HTTP_PORT` environment variable)
- UDP 67/68/546/547 (DHCP and DHCPv6; when network boot is used)
- UDP 69 (TFTP; when network boot is used)

The main Ironic service must be able to access the hosts' BMC addresses.

When virtual media is used, the hosts' BMCs must be able to access `HTTP_PORT`.

## Environmental variables

{{#include ironic_variables.md}}

## Ironic in-cluster installation

For in-cluster Ironic installation, we will run a set of containers within
a single pod in a Kubernetes cluster. You can enable TLS or basic auth or even
disable both for Ironic and Inspector communication. Below we will see kustomize
folders that will help us to install Ironic for each mentioned case. In each
of these deployments, a ConfigMap will be created and mounted to the Ironic pod.
The ConfigMap will be populated based on environment variables from
[ironic-deployment/default/ironic_bmo_configmap.env](https://github.com/metal3-io/baremetal-operator/blob/main/ironic-deployment/default/ironic_bmo_configmap.env). As such, update
`ironic_bmo_configmap.env` with your custom values before deploying the Ironic.

**WARNING:** Ironic normally listens on the host network of the control plane
nodes. If you do not enable authentication, anyone with access to this network
can use it to manipulate your nodes. It's also highly advised to use TLS to
prevent eavesdropping.

### Installing with Kustomize

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
- ironic-endpoint-keepalived
- ironic-log-watch
- ipa-downloader
- dnsmasq
- httpd
- mariadb; if `IRONIC_USE_MARIADB` = "true"

If in-cluster ironic installation, we used different manifests for TLS and basic auth,
here we are exporting environment variables for enabling/disabling TLS & basic auth
but use the same script.

TLS and Basic authentication disabled (not recommended)

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
