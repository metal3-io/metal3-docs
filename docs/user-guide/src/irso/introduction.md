# Ironic Standalone Operator

Ironic Standalone Operator (IrSO) is a Kubernetes controller that installs and
manages Ironic in a configuration suitable for Metal3. IrSO has the following
features:

- Flexible networking configuration, support for Keepalived.
- Using SQLite or MariaDB as the database backend.
- Optional support for a DHCP service (dnsmasq).
- Optional support for automatically downloading an
  [IPA](../ironic/ironic-python-agent.md) image.

IrSO uses [ironic-image](../ironic/ironic-container-images.md) under the hood.

## Installing Ironic Standalone Operator

The official installation process requires
[cert-manager](https://cert-manager.io/), please make sure to install it first
and wait for it to fully initialize.

On every source code change, a new IrSO image is built and published at
`quay.io/metal3-io/ironic-standalone-operator`. Starting with release 0.5.1,
we also publish a manifest for each release. You can install it this way:

```console
IRSO_VERSION=0.8.0
kubectl apply -f \
    https://github.com/metal3-io/ironic-standalone-operator/releases/download/v${IRSO_VERSION}/install.yaml
kubectl wait --for=condition=Available --timeout=120s \
  -n ironic-standalone-operator-system deployment/ironic-standalone-operator-controller-manager
```

For older versions (or to use an unreleased checkout) you can use the Kustomize
templates provided in the source repository:

```console
git clone https://github.com/metal3-io/ironic-standalone-operator
cd ironic-standalone-operator
git checkout -b <DESIRED BRANCH OR main>

make install deploy
kubectl wait --for=condition=Available --timeout=60s \
  -n ironic-standalone-operator-system deployment/ironic-standalone-operator-controller-manager
```

## API resources

IrSO uses the [Ironic][api-ref] custom resource to manage Ironic itself and all
of its auxiliary services.

See [installing Ironic with IrSO](./install-basics.md) for information on how
to use these resources.

[api-ref]: https://github.com/metal3-io/ironic-standalone-operator/blob/main/docs/api.md#ironic

## How is Ironic installed?

By default, IrSO installs Ironic as a single pod on a **control plane** node.
This is because Ironic currently requires *host networking*, and thus it's not
advisable to let it co-exist with tenant workload.

### Installed components

An Ironic installation always contains these three components:

- `ironic` is the main API service, as well as the conductor process that
  handles actions on bare-metal machines.
- `httpd` is the web server that serves images and configuration for iPXE and
  virtual media boot, as well as works as the HTTPS frontend for Ironic.
- `ramdisk-logs` is a script that unpacks any ramdisk logs and outputs them
  for consumption via `kubectl logs` or similar tools.

There is also a standard init container:

- `ramdisk-downloader` downloads images of the deployment/inspection ramdisk
  and stores them locally for easy access.

When network boot (iPXE) is enabled, another component is deployed:

- `dnsmasq` serves DHCP and functions as a PXE server for bootstrapping iPXE.

With Keepalived support enabled:

- `keepalived` manages the IP address on the provisioning interface.

### Supported versions

A major and minor version can be supplied to the `Ironic` resource to request
a specific branch of ironic-image (and thus Ironic). Here are supported version
values for each branch and release of the operator:

| Operator version | Ironic version(s)                    | Default version | Support status |
| ---------------- | ------------------------------------ | --------------- | -------------- |
| latest (main)    | latest, 34.0, 33.0, 32.0             | latest          | Supported      |
| 0.8.0            | 34.0, 33.0, 32.0                     | 34.0            | Supported      |
| 0.7.0            | 33.0, 32,0, 31.0                     | 33.0            | Supported      |
| 0.6.0            | 32.0, 31.0, 30.0                     | 32.0            | EOL            |
| 0.5.0            | 31.0, 30.0, 29.0, 28.0, 27.0         | 31.0            | EOL            |
| 0.4.0            | 30.0, 29.0, 28.0, 27.0               | 30.0            | EOL            |
| 0.3.0            | 29.0, 28.0, 27.0                     | latest          | EOL            |
| 0.2.0            | 28.0, 27.0                           | latest          | EOL            |
| 0.1.0            | 27.0                                 | latest          | EOL            |

**NOTE:** the special version value `latest` always installs the latest
available version of ironic-image and Ironic. This version value is
supported by all releases of IrSO but only works reliably in the
latest release.
