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
IRSO_VERSION=0.12.0
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

### Feature gates

IrSO supports *feature gates* as a means for enabling (or disabling)
experimental, less stable, or recently added features. The most up-to-date list
of feature gates can be obtained from the built-in help of the controller
manager. For example, if you have access to source code:

```console
$ make build
$ ./bin/manager -h
...
  -feature-gates value
        A set of key=value pairs that describe feature gates:
        AllAlpha=true|false (ALPHA - default=false)
        AllBeta=true|false (BETA - default=false)
        HighAvailability=true|false (BETA - default=false)
        Overrides=true|false (BETA - default=false)
...
```

Feature gates can be enabled or disabled using the `-feature-gates` flag or the
`FEATURE_GATES` environment variable. For example, you can update the
controller deployment with

```yaml
spec:
  template:
    spec:
      containers:
      - name: manager
        env:
        - name: FEATURE_GATES
          value: HighAvailability=true,Overrides=true
```

to enable container overrides and the HA architecture.

**WARNING:** disabling a feature gate does not automatically disables the
corresponding feature in existing Ironic resources. These resources will enter
an error state and must be fixed manually. It is recommended to update all
resources before disabling a previously enabled feature gate.

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

An Ironic installation always contains these three components installed by a
deployment called `<Ironic Name>-service`:

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

When networking service is enabled, it is started as a separate deployment
called `<Ironic Name>-networking`. Ironic service accesses it via JSON RPC.

### Supported versions

See the [supported release versions](../version_support.md#ironic-standalone-operator)
page for information on which versions of IrSO are currently supported.
