# Install Ironic

**WARNING:** this document covers the direct installation of Ironic using shell
scripts and Kustomize configuration from the BareMetal Operator repository.
This process is being phased out in favour of [Ironic Standalone
Operator](../irso/introduction.md). You should consider using the latter for
any new installations.

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

See [IrSO Prerequisites](../irso/install-basics.md#prerequisites).

## Environmental variables

See [ironic-image
README](https://github.com/metal3-io/ironic-image/blob/main/README.md) for an
up-to-date list of supported environment variables and their default values.

## Ironic in-cluster installation

For in-cluster Ironic installation, we will run a set of containers within
a single pod in a Kubernetes cluster. You can enable TLS or basic auth or even
disable both for Ironic and Inspector communication. Below we will see kustomize
folders that will help us to install Ironic for each mentioned case. In each
of these deployments, a ConfigMap will be created and mounted to the Ironic pod.
The ConfigMap will be populated based on environment variables from
[ironic-deployment/default/ironic_bmo_configmap.env](https://github.com/metal3-io/baremetal-operator/blob/main/ironic-deployment/default/ironic_bmo_configmap.env).
As such, update `ironic_bmo_configmap.env` with your custom values before
deploying the Ironic.

**WARNING:** Ironic normally listens on the host network of the control plane
nodes. If you do not enable authentication, anyone with access to this network
can use it to manipulate your nodes. It's also highly advised to use TLS to
prevent eavesdropping.

### Installing with Kustomize

In the quickstart guide, we have demonstrated
[how to install ironic with kustomize](../quick-start.md#deploy-ironic),
by creating an ironic kustomization overlay.
While that is still what you should follow if you have specific requirements for
your ironic deployment, we do provide an already-made overlay for the
most-common use case, ironic with basic authentication and TLS.

We assume you are inside the local baremetal-operator path, if not you need to
clone it first and `cd` to the root path.

```bash
 git clone https://github.com/metal3-io/baremetal-operator.git
 cd baremetal-operator
```

The overlay in interest is located at `ironic-deployment/overlay/basic-auth_tls`.
To make this overlay work, we still need to set up
[Authentication](../quick-start.md#authentication-configuration) and
[Ironic Environment Variables](../quick-start.md#ironic-environment-variables),
as instructed in the quickstart guide.

Next, check the [Ironic kustomization](../quick-start.md#ironic-kustomization)
section in the quickstart guide to see how to generate the necessary configMap
and Secrets for the deployment.

Also, `cert-manager` should have been installed in the cluster before deploying
Ironic. If you haven't installed `cert-manager` yet:

```bash
 kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml
```

Wait a few minutes for all `cert-manager` deployments to achieve `Ready` state.

We can then deploy Ironic with basic authentication and TLS enabled:

```bash
 kustomize build ironic-deployment/overlays/basic-auth_tls | kubectl apply -f -
```

Alternatively, you can use the `deploy.sh` script to deploy Ironic with custom
elements. Checkout
[detailed instruction](../bmo/install_baremetal_operator.md#deployment-commands),
and the script itself, for more information.

## Ironic out-of-cluster installation

For out-of-cluster Ironic installation, we will run a set of docker containers
outside of a Kubernetes cluster. To pass Ironic settings, you can export
corresponding [environmental variables](#environmental-variables) on the current
shell before calling
[run_local_ironic.sh](https://github.com/metal3-io/baremetal-operator/blob/main/tools/run_local_ironic.sh)
installation script. This will start below containers:

- ironic
- ironic-endpoint-keepalived
- ironic-log-watch
- ipa-downloader
- dnsmasq
- httpd
- mariadb; if `IRONIC_USE_MARIADB` = "true"

If in-cluster ironic installation, we used different manifests for TLS and
basic auth, here we are exporting environment variables for enabling/disabling
TLS & basic auth but use the same script.

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
