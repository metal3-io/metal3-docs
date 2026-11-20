<!-- cSpell:ignore mariadb rpc -->
# TLS and certificates

The Ironic Standalone Operator (IrSO) does not issue certificates for you: you
create the secrets and reference them from the `Ironic` resource, and IrSO
wires them into the Ironic pod. This page covers the TLS-related fields of the
`Ironic` resource, what each one changes in the running deployment, and how
rotation is handled.

For the basic installation flow, including a self-signed certificate suitable
for evaluation, see [Install Ironic with IrSO](./install-basics.md).

## The Ironic API certificate

Set `spec.tls.certificateName` to the name of a TLS secret in the same
namespace as the `Ironic` resource. The secret must carry `tls.crt` and
`tls.key`, and like every Secret or ConfigMap you hand to IrSO it needs the
`environment.metal3.io/ironic-standalone-operator: "true"` label:

```bash
kubectl label secret ironic-tls -n test-ironic \
    environment.metal3.io/ironic-standalone-operator=true
```

One consequence that is easy to miss: the `Service` then exposes the API on
port 443 instead of 80, and the image server on 8443 instead of 8080. The
container and host ports are unchanged (`spec.networking.apiPort`, default
6385, and `spec.networking.imageServerPort`, default 6180).

### Subject Alternative Names

The `Service` is named after the `Ironic` resource, so the certificate must
include `<ironic-name>.<namespace>.svc` as a DNS name — for an `Ironic` named
`ironic` in namespace `test-ironic`, that is `ironic.test-ironic.svc`. It must
also include the IP address that the hosts and their BMCs use to reach Ironic,
normally `spec.networking.ipAddress`.

## Trusting the BMCs

Ironic verifies the certificate each BMC presents over Redfish HTTPS. Point
`spec.tls.bmcCA` at a `ConfigMap` or a `Secret` holding the CA certificates:

```yaml
spec:
  tls:
    certificateName: ironic-tls
    bmcCA:
      kind: ConfigMap
      name: bmc-ca
```

IrSO mounts every key of that resource under `/certs/ca/bmc`, and Ironic
assembles them into one bundle. Changes to the contents are picked up without
restarting the pod. This requires Ironic 32.0 or newer; the older
`spec.tls.bmcCAName` field accepts a `Secret` name only and is deprecated.

When a BMC presents a certificate you cannot supply a CA for, the escape hatch
is per host rather than per deployment: `disableCertificateVerification: true`
on the `BareMetalHost`. It is insecure, and BMC access is effectively physical
access to the machine, so prefer supplying the CA.

## Trusting image servers and other services

`spec.tls.trustedCA` supplies the CA used to verify HTTPS image servers — the
ones hosting disk images and the IPA ramdisk — and other outbound connections:

```yaml
spec:
  tls:
    trustedCA:
      kind: Secret
      name: image-server-ca
      key: ca.crt
```

The resource is mounted at `/certs/ca/trusted` and the selected file becomes
Ironic's `WEBSERVER_CACERT_FILE`. When `key` is omitted, the first key in
alphabetical order wins and the others are ignored with a warning in the
operator log, so set it explicitly whenever the resource holds more than one
entry.

The same bundle reaches the ramdisk downloader init container as
`CURL_CA_BUNDLE`, which is what allows the IPA kernel and ramdisk to be
fetched from a server with a private CA.

The older `spec.tls.trustedCAName` field accepts a `ConfigMap` name only and
is deprecated.

## Highly available deployments

With `spec.highAvailability` enabled Ironic runs as a DaemonSet, and the
conductors talk to each other over JSON-RPC secured with the same API
certificate. The certificate therefore has to be valid for every address a
replica may run on. Where that is impractical, set:

```yaml
spec:
  tls:
    insecureRPC: true
```

which disables validation for those internal connections only. It has no
effect unless `spec.highAvailability` is set, and it requires the
`HighAvailability` feature gate.

IrSO also tells Ironic which CA to trust for those connections: when the TLS
secret contains a `ca.crt` entry, as it does when cert-manager issues the
certificate, that file is used; otherwise the `trustedCA` bundle is.

## Rotation

IrSO stamps the pod template with an annotation holding a hash of the TLS
secret contents, `ironic.metal3.io/tls-secret-version`. When cert-manager
renews the certificate and rewrites the secret, the hash changes and the pod
is rolled, so the new certificate is picked up without manual intervention.
The API credentials secret is tracked the same way.

A single-replica deployment uses the `Recreate` strategy, because two copies
of Ironic cannot run at once, so expect a short interruption while the pod
restarts.

## Issuing the certificate with cert-manager

For anything beyond evaluation, let [cert-manager](https://cert-manager.io/)
issue and renew the certificate. The requirements above translate directly
into a `Certificate`:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ironic-tls
  namespace: test-ironic
spec:
  secretName: ironic-tls
  secretTemplate:
    labels:
      environment.metal3.io/ironic-standalone-operator: "true"
  dnsNames:
  - ironic.test-ironic.svc
  ipAddresses:
  - 192.0.2.1
  issuerRef:
    name: my-issuer
    kind: Issuer
```

`secretTemplate` is the part that is easy to miss: without the label IrSO
cannot read the secret.

## Database connections

TLS for an external database is configured outside `spec.tls`, through
`spec.database.tlsCertificateName`, whose CA is mounted at
`/certs/ca/mariadb`. See [External Database for Ironic](./database.md).

## Reference

Every field above is documented in the IrSO [API reference][api-ref] (switch
to the branch you are using).

[api-ref]: https://github.com/metal3-io/ironic-standalone-operator/blob/main/docs/api.md#ironicspec
