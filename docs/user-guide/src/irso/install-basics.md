# Installing Ironic

This document covers installing Ironic in different scenarios. You need to
answer a few questions before you can pick the one that suits you:

- Which physical network interface will be used for provisioning? Without any
  configuration, Ironic will use the host cluster networking.

- If you use a dedicated network interface, are you going to use the built-in
  Keepalived service to configure the IP address on the control plane node
  where the Ironic pod is located? If not, you need to make sure the interface
  has a usable address on this node.

- Do you want to use network boot (iPXE) during provisioning? DHCP adds more
  requirements and requires explicit configuration. Without it, only virtual
  media provisioning is possible (see [supported
  hardware](../bmo/supported_hardware.md)).

- Are you going to use TLS for the Ironic API? It is not recommended to run
  without TLS. To enable it, you need to manage the TLS secret. [Cert
  Manager](https://cert-manager.io/) is the recommended service for it.

- Do you need persistence for the Ironic's internal database? The examples in
  this guide assume no persistence, i.e. that **all data is lost on the pod
  restart**! This ephemeral mode of operation suits Metal3 well, since BMO
  treats BareMetalHost resources as the primary source of truth. However, for
  use cases outside of Metal3, you need to configure an [external
  database](./database.md).

## Prerequisites

A separate provisioning network is required when network boot is used.

The following ports must be accessible by the hosts being provisioned:

- TCP 6385 (Ironic API)
- TCP 6180 (HTTP server serving OS and virtual media images)
- TCP 6183 (HTTP server with TLS)

The main Ironic service must be able to access the hosts' BMC addresses, as
well as port 9999 (ramdisk API) on the hosts.

When virtual media is used, the hosts' BMCs must be able to access ports 6180
or 6183 (depending on whether TLS is used).

**NOTE:** all ports can be changed on the Ironic resource.

### Network boot requirements

When network boot (iPXE) is used instead of virtual media, you need a dedicated
provisioning network. The following ports must be accessible:

- UDP 67/68/546/547 (DHCP and DHCPv6; when network boot is used)
- UDP 69 (TFTP; when network boot is used)

## Using Ironic

Regardless of the scenario you choose, you will need to create at least an
`Ironic` object and wait for it to become ready:

```bash
NAMESPACE="test-ironic"  # change to match your deployment
kubectl create -f ironic.yaml
kubectl wait --for=condition=Ready --timeout="10m" -n "$NAMESPACE" ironic/ironic
```

If the resource does not become `Ready`, check its status and the status of the
corresponding `Deployment`.

Once it is ready, get the credentials from the associated secret, e.g. with

```bash
SECRET=$(kubectl get ironic/ironic -n "$NAMESPACE" --template={{.spec.apiCredentialsName}})
USERNAME=$(kubectl get secrets/$SECRET -n "$NAMESPACE" --template={{.data.username}} | base64 -d)
PASSWORD=$(kubectl get secrets/$SECRET -n "$NAMESPACE" --template={{.data.password}} | base64 -d)
```

Now you can point BMO at the Ironic's service at `ironic.test-ironic.svc`.

## Scenario 1: no network boot, no dedicated networking

In this scenario, Ironic will use whatever networking is used by the cluster.
No DHCP will be available, bare-metal machines will be provisioned using
virtual media. Since there is no dedicated network interface, Keepalived is
also not needed.

It is enough to create the following resource:

```yaml
apiVersion: ironic.metal3.io/v1alpha1
kind: Ironic
metadata:
  name: ironic
  namespace: test-ironic
spec:
  version: "34.0"
```

**HINT:** there is no need to configure API credentials: IrSO will generate a
random password for you.

However, there is one option that you might want to set in all scenarios: the
public SSH key for the ramdisk. Configuring it allows an easier debugging if
anything goes wrong during provisioning.

```yaml
apiVersion: ironic.metal3.io/v1alpha1
kind: Ironic
metadata:
  name: ironic
  namespace: test-ironic
spec:
  deployRamdisk:
    sshKey: "ssh-ed25519 AAAAC3..."
  version: "34.0"
```

**WARNING:** the provided SSH key will **not** be installed on the machines
deployed by Ironic. See [instance
customization](../bmo/instance_customization.md) instead.

## Scenario 2: dedicated networking and TLS

In this scenario, a separate network interface is used (`em2` in the example).
The IP address on the interface will be managed by Keepalived, and the Ironic
API will be secured by TLS.

To make TLS work without resorting to insecure configuration, the certificate
must contain the DNS name derived from the service (e.g.
`ironic.test-ironic.svc`), as well as the provided IP address (`192.0.2.1` in
this example).

For simplicity, lets use the openssl CLI to generate a self-signed certificate
(use something like Cert Manager in production):

```console
openssl req -x509 -new -subj "/CN=ironic.test-ironic.svc" \
    -addext "subjectAltName = DNS:ironic.test-ironic.svc,IP:192.0.2.1" \
    -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes \
    -keyout ironic-tls.key -out ironic-tls.crt
kubectl create secret tls ironic-tls -n test-ironic --key=ironic-tls.key --cert=ironic-tls.crt
```

**NOTE:** without a dedicated interface we would have to add all cluster IP
addresses to the certificate, which is often not desired.

Now you can create your Ironic deployment:

```yaml
apiVersion: ironic.metal3.io/v1alpha1
kind: Ironic
metadata:
  name: ironic
  namespace: test-ironic
spec:
  deployRamdisk:
    sshKey: "ssh-ed25519 AAAAC3..."
  networking:
    interface: "em2"
    ipAddress: "192.0.2.1"
    ipAddressManager: keepalived
  tls:
    certificateName: ironic-tls
  version: "34.0"
```

Now you can access Ironic either via the service or at `192.0.2.1:6385`.

## Scenario 3: dedicated networking with DHCP and Keepalived

In this scenario, network booting will be available on the dedicated network
interface. Assuming the network CIDR is `192.0.2.0/24`:

```yaml
apiVersion: ironic.metal3.io/v1alpha1
kind: Ironic
metadata:
  name: ironic
  namespace: test-ironic
spec:
  deployRamdisk:
    sshKey: "ssh-ed25519 AAAAC3..."
  networking:
    dhcp:
      networkCIDR: "192.0.2.0/24"
    interface: "em2"
    ipAddress: "192.0.2.1"
    ipAddressManager: keepalived
  tls:
    certificateName: ironic-tls
  version: "34.0"
```

**NOTE:** when the DHCP range is not provided, IrSO will pick one for you. In
this example, it will be `192.0.2.10 - 192.0.2.253`.

## What's next?

Check the [API reference][api-ref] (switch to the branch you're using) for
all possible settings you can set on an Ironic object.

[api-ref]: https://github.com/metal3-io/ironic-standalone-operator/blob/main/docs/api.md#ironicspec
