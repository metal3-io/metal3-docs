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

On every source code change, a new IrSO image is built and published at
`quay.io/metal3-io/ironic-standalone-operator`. To install it in your cluster,
you can use the Kustomize templates provided in the source repository:

```console
git clone https://github.com/metal3-io/ironic-standalone-operator
cd ironic-standalone-operator
git checkout -b <DESIRED BRANCH OR main>

make install deploy
kubectl wait --for=condition=Available --timeout=60s \
  -n ironic-standalone-operator-system deployment/ironic-standalone-operator-controller-manager
```

## API resources

IrSO uses two Custom Resources to manage an Ironic installation:

[Ironic](https://github.com/metal3-io/ironic-standalone-operator/blob/main/config/crd/bases/ironic.metal3.io_ironics.yaml)
manages Ironic itself and all of its auxiliary services.

[IronicDatabase](https://github.com/metal3-io/ironic-standalone-operator/blob/main/config/crd/bases/ironic.metal3.io_ironicdatabases.yaml)
manages a MariaDB instance for Ironic (if required).

See [installing Ironic with IrSO](./install-basics.md) for information on how
to use these resources.

## How is Ironic installed?

By default, IrSO installs Ironic as a single pod on a **control plane** node.
This is because Ironic currently requires *host networking*, and thus it's not
advisable to let it co-exist with tenant workload.

### Installed services

An Ironic deployment always contains these three services:

- `ironic` is the main API service, as well as the conductor process that
  handles actions on bare-metal machines.
- `httpd` is the web server that serves images and configuration for iPXE and
  virtual media boot, as well as works as the HTTPS frontend for Ironic.
- `ramdisk-logs` is a script that unpacks any ramdisk logs and outputs them
  for consumption via `kubectl logs` or similar tools.

There is also a standard init container:

- `ramdisk-downloader` downloads images of the deployment/inspection ramdisk
  and stores them locally for easy access.

When network boot (iPXE) is enabled, another service is deployed:

- `dnsmasq` serves DHCP and functions as a PXE server for bootstrapping iPXE.

With Keepalived support enabled:

- `keepalived` manages the IP address on the provisioning interface.