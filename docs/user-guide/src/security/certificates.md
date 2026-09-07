<!-- cSpell:ignore openssl keepalived cacert httpd mariadb rpc -->
# Certificate supply and lifecycle

Enabling TLS across a Metal3 deployment is only half of the job: each TLS
surface needs a certificate supplied to it, and each client needs to be told
which certificate authority (CA) to trust. This page covers how to provide the
Ironic API certificate, the Subject Alternative Names it must carry, rotation
and renewal, and the separate CA-trust settings for the connections Metal3
makes and receives. The TLS protocol, cipher and curve tuning is a separate
concern, covered in [TLS configuration and hardening](./tls.md).

## What needs a certificate, and who verifies it

A hardened deployment involves several distinct trust relationships. They are
easy to conflate, but each is configured independently:

- **Ironic API certificate** — presented by Ironic itself, or by the `httpd`
  in front of it once you supply a certificate (Ironic then listens on a Unix
  socket and `httpd` terminates TLS). Verified by BMO. It is **not** verified
  by the Ironic Python Agent (IPA) by default: ironic-image boots the ramdisk
  with `ipa-insecure=1` unless `IRONIC_IPA_INSECURE=0` is set, and IrSO never
  sets it. You supply this certificate.
- **Virtual-media server certificate** — presented to the BMCs by the server
  that hosts virtual-media images. With IrSO this is not a separate,
  auto-generated certificate: the API certificate you supply
  (`spec.tls.certificateName`) is reused for the virtual-media server too,
  unless `disableVirtualMediaTLS` is set.
- **BMC certificate** — presented by each BMC over Redfish HTTPS, verified by
  Ironic (`[redfish] verify_ca`). You supply the BMC CA (or disable
  verification per host).
- **Image server certificate** — presented by the disk/IPA image server,
  verified by Ironic (`[DEFAULT] webserver_verify_ca`), and by IPA too when
  `IRONIC_IPA_INSECURE=0`. You supply that server's CA.
- **Internal JSON-RPC certificate** (highly available deployments only) — the
  conductor replicas talk to each other over JSON-RPC with TLS, reusing the
  API certificate. It must then be valid for every address a replica may run
  on, unless `spec.tls.insecureRPC` is set.
- **Database certificate** — with an external MariaDB database, Ironic
  verifies it against a CA you supply separately
  (`spec.database.tlsCertificateName`, mounted at `/certs/ca/mariadb`).

## Supplying the Ironic API certificate

How you supply the certificate is a deployment-specific step. With the
Ironic Standalone Operator you reference a TLS secret from the Ironic
resource; see [Install Ironic with IrSO](../irso/install-basics.md)
for the secret format, the required label, and a worked example.

### Required Subject Alternative Names

The certificate **must** include, as Subject Alternative Names, both:

- the DNS name of the Ironic service. With IrSO the `Service` is named after
  the `Ironic` resource, so it is `<ironic-name>.<namespace>.svc` — for an
  `Ironic` named `ironic` in namespace `test-ironic`, that is
  `ironic.test-ironic.svc`.
- the IP address the hosts and the BMCs use to reach Ironic.

Nothing falls back automatically when a name or an address is missing from the
certificate: verification simply fails, and the only way around it is an
explicit insecure setting. Note that without a dedicated provisioning
interface you would have to add every cluster IP address to the certificate,
which is usually undesirable — another reason to use a dedicated interface
with Keepalived.

In a highly available deployment the same certificate is used for the internal
JSON-RPC connections between replicas, so it must also be valid for every
address a replica may run on. When that is impractical, set
`spec.tls.insecureRPC` on the `Ironic` resource, which disables validation for
those internal connections only.

### Test versus production

For evaluation, a self-signed certificate generated with `openssl` is
sufficient; the exact commands (including the secret creation and the required
label) are in [Install Ironic with IrSO](../irso/install-basics.md) under
"Scenario 2: dedicated networking and TLS".

For production, use [cert-manager](https://cert-manager.io/) to issue the
certificate so that renewal is automated (see below). The
[quick-start](../quick-start.md) deploys Ironic with a cert-manager
`Certificate` for exactly this reason.

## Certificate rotation and renewal

cert-manager renews certificates automatically by rewriting the TLS secret; the
files mounted into the Ironic pod update in place. Neither Ironic nor `httpd`
reloads a certificate on its own, so something has to restart them.

In ironic-image that something is the
`RESTART_CONTAINER_CERTIFICATE_UPDATED` environment variable (default
`false`). When set to `true`, the entry point starts a watcher on each
certificate file in use and signals the service when that file is **deleted**,
which is what the atomic secret update performed by the kubelet looks like.
Ironic gets a `TERM` signal, `httpd` a `WINCH` signal. Watchers are set up for
the API certificate (in both the Ironic and the `httpd` containers), the
virtual-media certificate, and the image server CA. Without the variable, a
renewed certificate is only loaded on the next pod restart, so enable it when
you rely on automated renewal.

The BMC CA is handled differently and needs no configuration: the Ironic entry
point always watches the `/certs/ca/bmc` directory and rebuilds its CA bundle
when the contents change, with no restart involved.

IrSO uses a different mechanism for the same goal: it stamps the pod with an
annotation holding a hash of the certificate secret, so the pod is rolled
automatically when the certificate changes.
`RESTART_CONTAINER_CERTIFICATE_UPDATED` is the lower-level ironic-image approach
for deployments not managed by IrSO.

## Trusting the Ironic API from BMO

These settings live on Bare Metal Operator and control how BMO verifies the
Ironic API certificate:

- `IRONIC_CACERT_FILE` — path to the CA certificate BMO uses to verify Ironic's
  API certificate. Point it at the CA that signed the Ironic certificate.
  Beware that a path that does not exist is silently ignored: BMO then falls
  back to the system trust store instead of failing, so a typo here can look
  like a working secure setup.
- `IRONIC_INSECURE` (`True`/`False`) — skips Ironic certificate validation. It
  is strongly recommended **not** to set this to `True`; it exists only as an
  escape hatch.

Note that ironic-image has its own, unrelated variable with the same
`IRONIC_CACERT_FILE` name. There it is the CA that Ironic itself trusts for
the internal JSON-RPC connections, and it defaults to
`/certs/ca/ironic/tls.crt`.

When BMO is pointed at an `Ironic` resource with `IRONIC_NAME` — the usual
arrangement with IrSO — it takes this configuration from the resource instead:
the endpoint becomes `https://<ironic-name>.<namespace>.svc` (`IRONIC_ENDPOINT`
is ignored) and the trusted CA is read from `tls.crt` in the TLS secret
referenced by the resource, which overrides `IRONIC_CACERT_FILE`.
`IRONIC_INSECURE` is still read from the environment.

Mutual TLS deserves a warning. BMO can be told to present a client certificate
by setting both `IRONIC_CLIENT_CERT_FILE` and
`IRONIC_CLIENT_PRIVATE_KEY_FILE`, but that does not give you mutual TLS
against an Ironic deployed from ironic-image: its `httpd` never requests or
validates a client certificate, so the certificate is never asked for. These
settings are only useful in front of an external Ironic that does request one.
`IRONIC_SKIP_CLIENT_SAN_VERIFY` has no effect on BMO as a client.

See the
[Bare Metal Operator configuration reference](https://github.com/metal3-io/baremetal-operator/blob/main/docs/configuration.md)
for the full list.

## Trusting the BMC (Ironic to BMC over Redfish)

When Ironic talks to a BMC over HTTPS (Redfish), it verifies the BMC's
certificate against a supplied CA:

- ironic-image: mount the BMC CA at `/certs/ca/bmc`. When that path exists and
  the host's `verify_ca` is `True` or unset, those certificates are used.
- IrSO: set `spec.tls.bmcCA` to a reference to a ConfigMap or Secret containing
  the CA (supported on Ironic 32.0 or newer). The older `spec.tls.bmcCAName` is
  deprecated.

If a BMC uses a self-signed certificate and you cannot supply its CA, the
per-host escape hatch is to set `disableCertificateVerification: true` on the
BareMetalHost:

```yaml
spec:
  bmc:
    address: redfish://192.0.2.10/redfish/v1/Systems/1
    credentialsName: bmc-secret
    disableCertificateVerification: true
```

This disables verification of the BMC's server certificate. It is insecure —
per the API, it "allows a man-in-the-middle to intercept the connection." BMC
access is effectively physical access to the machine, so prefer supplying the
BMC CA over disabling verification.

## Trusting the image server (Ironic and IPA to HTTPS images)

This is a separate trust path from the BMC one: it governs how Ironic and the
IPA ramdisk verify the HTTPS server that hosts disk and IPA images.

- ironic-image: `WEBSERVER_CACERT_FILE` — the CA or CA bundle Ironic uses to
  verify disk and IPA images fetched over HTTPS. It is also injected into the
  IPA ramdisk, which uses it to verify disk images and its connection back to
  Ironic when `IRONIC_IPA_INSECURE=0`.
- IrSO: set `spec.tls.trustedCA` to a reference to a ConfigMap or Secret
  containing the CA(s) used to validate image servers and other services. The
  older `spec.tls.trustedCAName` is deprecated.
