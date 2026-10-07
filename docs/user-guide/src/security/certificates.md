<!-- cSpell:ignore openssl keepalived cacert -->
# Certificate supply and lifecycle

Enabling TLS across a Metal3 deployment is only half of the job: each TLS
surface needs a certificate supplied to it, and each client needs to be told
which certificate authority (CA) to trust. This page covers how to provide the
Ironic API certificate, the Subject Alternative Names it must carry, rotation
and renewal, and the separate CA-trust settings for the connections Metal3
makes and receives. The TLS protocol, cipher and curve tuning is a separate
concern, covered in [TLS configuration and hardening](./tls.md).

## What needs a certificate, and who verifies it

A hardened deployment involves four distinct trust relationships. They are easy
to conflate, but each is configured independently:

- **Ironic API certificate** — presented by Ironic, verified by BMO and by the
  Ironic Python Agent (IPA). You supply this one.
- **Virtual-media server certificate** — presented to the BMCs by the server
  that hosts virtual-media images. With IrSO this is not a separate,
  auto-generated certificate: the API certificate you supply
  (`spec.tls.certificateName`) is reused for the virtual-media server too,
  unless `disableVirtualMediaTLS` is set.
- **BMC certificate** — presented by each BMC over Redfish HTTPS, verified by
  Ironic. You supply the BMC CA (or disable verification per host).
- **Image server certificate** — presented by the disk/IPA image server,
  verified by Ironic. You supply that server's CA.

## Supplying the Ironic API certificate

How you supply the certificate is a deployment-specific step. With the
Ironic Standalone Operator you reference a TLS secret from the Ironic
resource; see [Install Ironic with IrSO](../irso/install-basics.md)
for the secret format, the required label, and a worked example.

### Required Subject Alternative Names

The certificate **must** include, as Subject Alternative Names, both:

- the DNS name derived from the service, `ironic.<namespace>.svc` (for example
  `ironic.test-ironic.svc`), and
- the IP address the hosts use to reach Ironic.

Missing either one forces an insecure fallback somewhere in the chain. Note
that without a dedicated provisioning interface you would have to add every
cluster IP address to the certificate, which is usually undesirable — another
reason to use a dedicated interface with Keepalived.

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
files mounted into the Ironic pod update in place. For Ironic to load a rotated
certificate, the ironic-image container supports the
`RESTART_CONTAINER_CERTIFICATE_UPDATED` environment variable (default `false`).
When set to `true`, the container watches its certificate files and restarts the
affected service when they change, so a renewed certificate is picked up without
manual intervention. Without it, a rotated certificate is only loaded on the
next pod restart. Enable it when you rely on automated renewal.

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
- `IRONIC_INSECURE` (`True`/`False`) — skips Ironic certificate validation. It
  is strongly recommended **not** to set this to `True`; it exists only as an
  escape hatch.
- Mutual TLS (optional): set both `IRONIC_CLIENT_CERT_FILE` and
  `IRONIC_CLIENT_PRIVATE_KEY_FILE` to have BMO present a client certificate.
  `IRONIC_SKIP_CLIENT_SAN_VERIFY` skips the client SAN check.

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
per the API, it "allows a man-in-the-middle to intercept the connection." A BMC
connection is effectively physical-equivalent control of the machine, so prefer
supplying the BMC CA over disabling verification.

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
