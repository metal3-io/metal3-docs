<!-- cSpell:ignore Apache -->
# TLS configuration and hardening

Transport Layer Security (TLS, [RFC 8446](https://www.rfc-editor.org/rfc/rfc8446))
encrypts and authenticates the network connections to Ironic's services. Ironic
in Metal3 terminates TLS on more than one TCP port (see
[RFC 6335](https://www.rfc-editor.org/rfc/rfc6335) for the meaning of "port"),
each served by Apache inside the ironic-image container. This page describes
those ports, the ironic-image settings that enable and tune TLS on each, how the
Ironic Standalone Operator (IrSO) drives the same settings at a higher level,
and a recommended hardened baseline.

Running Ironic without TLS is not recommended.

## The TLS ports

A Metal3 Ironic deployment can expose up to three externally reachable TLS
ports. Each is served by an Apache virtual host with its own certificate slot,
and a port only becomes HTTPS once its certificate is mounted:

- **Ironic API (TCP `6385`).** The REST API that Bare Metal Operator (BMO) and
  administrators talk to. Apache terminates TLS on this port and proxies
  requests to the Ironic API server over a pod-local unix socket
  (`/shared/ironic.sock`), so there is no internal TCP connection to Ironic. The
  exception is the `/images` path, which Apache serves directly from local
  storage rather than proxying — this is how the OS/node images that the Ironic
  Python Agent (IPA) downloads during provisioning are hosted, over the same
  port and certificate. Its certificate comes from `/certs/ironic`; its clients
  are BMO, the IPA in the ramdisk, and any operator tooling.
- **Virtual-media image server (HTTPS plus a plain-HTTP listener).** The HTTP
  server that presents boot and configuration images to a host's BMC when
  provisioning over virtual media. It has its own Apache virtual host and
  certificate slot (`/certs/vmedia`), though under IrSO it is populated with the
  same certificate as the API. Its clients are the BMCs, whose TLS support
  varies widely between vendors and firmware versions. The TLS port defaults to
  `8083` in ironic-image (`VMEDIA_TLS_PORT`) and to `6183` under IrSO
  (`imageServerTLSPort`); the companion plain-HTTP port defaults to `80`
  (`HTTP_PORT`) and `6180` (`imageServerPort`) respectively.
- **iPXE network boot (TLS, default TCP `8084`).** This listener is optional and
  only active when its certificate slot is populated; a standard IrSO TLS
  deployment does not expose it unless you configure iPXE TLS explicitly (see
  below). When network boot is served over HTTPS, iPXE has its own Apache
  virtual host (`IPXE_TLS_PORT`, default `8084`) and certificate slot
  (`/certs/ipxe`). Its clients are the iPXE firmware images, which must be built
  with the matching trust anchor — building that firmware is covered separately
  in the network-boot material and is out of scope here. iPXE negotiates TLS 1.2
  at most; it has no TLS 1.3 support.

Because the clients differ, the three ports are tuned independently. The API
port faces software you control (BMO, IPA) and can be hardened aggressively. The
virtual-media port faces BMC firmware you often do not control, so overly strict
settings there can break provisioning on older hardware. The iPXE port is
limited by what the iPXE firmware supports.

## Enabling and tuning TLS in ironic-image

TLS is implemented in the ironic-image container. On each port it is enabled by
providing a certificate and key for that port: `/certs/ironic` for the API (and
the node-image path), `/certs/vmedia` for virtual media, and `/certs/ipxe` for
iPXE. When a certificate is present, Apache serves that port over HTTPS.

The protocol, cipher and curve tuning is controlled by environment variables
consumed by Apache — they are not `ironic.conf` options.

### API TLS flags

These tune the Ironic API port (and the HTTPS node-image path that shares its
certificate):

**NOTE:** these flags are read by the Apache virtual host that fronts the API,
so they only take effect when Apache is terminating TLS on that port, i.e. when
`IRONIC_REVERSE_PROXY_SETUP=true`. IrSO sets that automatically whenever
`spec.tls.certificateName` is set. In a plain ironic-image deployment it
defaults to `false`, in which case Ironic's own WSGI server terminates TLS
(`enable_ssl_api`) and none of the protocol, cipher or curve settings below
apply.

| Variable | Purpose | Default |
|---|---|---|
| `IRONIC_SSL_PROTOCOL` | Allowed TLS protocol versions (Apache `SSLProtocol` directive) | `-ALL +TLSv1.2 +TLSv1.3` |
| `IRONIC_TLS_12_CIPHERS` | Ordered cipher list for TLS 1.2 and below, in OpenSSL format | OpenSSL default |
| `IRONIC_TLS_13_CIPHERS` | Ordered cipher list for TLS 1.3, in OpenSSL format | OpenSSL default |
| `IRONIC_TLS_CURVES` | Ordered list of allowed groups/curves, in OpenSSL format | OpenSSL default |
| `IRONIC_TLS_ENFORCE_SERVER_CIPHER_ORDER` | Make the server, not the client, choose the cipher (Apache `SSLHonorCipherOrder`; applies to TLS 1.2 and 1.3) | unset (client's order wins) |

### Virtual-media TLS flags

These mirror the API flags but apply to the virtual-media virtual host (which,
under IrSO, uses the same certificate as the API):

| Variable | Purpose | Default |
|---|---|---|
| `IRONIC_VMEDIA_SSL_PROTOCOL` | Allowed TLS protocol versions (Apache `SSLProtocol` directive) | `ALL` |
| `IRONIC_VMEDIA_TLS_12_CIPHERS` | Ordered cipher list for TLS 1.2 and below, in OpenSSL format | OpenSSL default |
| `IRONIC_VMEDIA_TLS_13_CIPHERS` | Ordered cipher list for TLS 1.3, in OpenSSL format | OpenSSL default |
| `IRONIC_VMEDIA_CURVES` | Ordered list of allowed groups/curves, in OpenSSL format | OpenSSL default |
| `IRONIC_VMEDIA_TLS_ENFORCE_SERVER_CIPHER_ORDER` | Make the server choose the cipher (Apache `SSLHonorCipherOrder`; applies to TLS 1.2 and 1.3) | unset (client's order wins) |

`IRONIC_VMEDIA_SSL_PROTOCOL` defaults to `ALL`, which permits every protocol
version the underlying OpenSSL build supports, including legacy ones. This is
deliberately permissive because BMC TLS stacks are often old, but it means the
virtual-media port is *not* hardened by default. Tightening it is worthwhile,
but do so carefully and test against your hardware (see the caveats below).

### iPXE TLS flag

The iPXE virtual host exposes only a protocol knob; it sets no cipher or curve
directives:

| Variable | Purpose | Default |
|---|---|---|
| `IPXE_SSL_PROTOCOL` | Allowed TLS protocol versions (Apache `SSLProtocol` directive) | `-ALL +TLSv1.2 +TLSv1.3` |

Because iPXE has no TLS 1.3 support, this port effectively negotiates TLS 1.2
regardless of the `+TLSv1.3` in the default.

## Configuring TLS with IrSO

The Ironic Standalone Operator drives the same certificates at a higher level of
abstraction. TLS is enabled by referencing a certificate secret from the
`Ironic` resource:

```yaml
spec:
  tls:
    certificateName: ironic-tls
```

The certificate must include the DNS name derived from the service (for example
`ironic.test-ironic.svc`) and the IP address the hosts use to reach Ironic, as a
Subject Alternative Name. See
[Install Ironic with IrSO](../irso/install-basics.md) for a complete self-signed
test example, including generating the secret and its required label. In
production, use a certificate manager such as
[cert-manager](https://cert-manager.io/) to issue and rotate the certificate.

IrSO enables TLS on the virtual-media image server by default, reusing the same
certificate rather than a separately managed one; set
`spec.tls.disableVirtualMediaTLS` to turn it off for BMCs that cannot use HTTPS.

Two limitations are worth noting:

- IrSO does **not** currently expose the protocol, cipher and curve flags above
  as dedicated fields, and `spec.extraConfig` only sets `ironic.conf` options,
  which is a different layer. An IrSO-managed deployment therefore runs with the
  ironic-image defaults unless you inject the environment variables yourself by
  replacing the `httpd` container through the experimental `spec.overrides`
  field.
- IrSO has no dedicated setting for iPXE TLS; that port is configured at the
  container level (by mounting `/certs/ipxe`, for example through
  `spec.overrides`).

## Recommended hardened baseline

The following is a reasonable modern baseline that keeps TLS 1.2 for
compatibility, restricts cipher suites to forward-secret authenticated-encryption
suites, and lets the server dictate the ordering. Cipher and curve strings use
the OpenSSL format.

For the API port:

```bash
export IRONIC_SSL_PROTOCOL="-ALL +TLSv1.2 +TLSv1.3"
export IRONIC_TLS_13_CIPHERS="TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256"
export IRONIC_TLS_12_CIPHERS="ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"
export IRONIC_TLS_CURVES="x25519:secp256r1:secp384r1"
export IRONIC_TLS_ENFORCE_SERVER_CIPHER_ORDER="true"
```

For the virtual-media port, start from the same protocol, cipher, curve and
ordering values, but treat them as a starting point and test against your BMCs:

```bash
export IRONIC_VMEDIA_SSL_PROTOCOL="-ALL +TLSv1.2 +TLSv1.3"
export IRONIC_VMEDIA_TLS_13_CIPHERS="TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256"
export IRONIC_VMEDIA_TLS_12_CIPHERS="ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256"
export IRONIC_VMEDIA_CURVES="x25519:secp256r1:secp384r1"
export IRONIC_VMEDIA_TLS_ENFORCE_SERVER_CIPHER_ORDER="true"
```

The iPXE port has only `IPXE_SSL_PROTOCOL`; leave it at the default (it will
negotiate TLS 1.2 with current iPXE firmware).

Notes and caveats:

- **Test virtual-media hardening against your BMCs.** BMC TLS stacks are often
  older than the software clients of the API. If provisioning over virtual media
  fails after tightening these values, relax the virtual-media cipher list (or
  keep TLS 1.2 suites) while leaving the API port strict.
- **Cipher order is a separate decision from the cipher list.** Setting
  `IRONIC_TLS_ENFORCE_SERVER_CIPHER_ORDER=true` emits `SSLHonorCipherOrder on`,
  which makes the server's preference win for both TLS 1.2 and TLS 1.3: the
  first entry in your `IRONIC_TLS_12_CIPHERS` / `IRONIC_TLS_13_CIPHERS` list
  that the peer also supports is the one negotiated. Leave it unset and the
  client's preference wins instead. Enforcing server order is the safer choice
  on a provisioning network, where a BMC may advertise weak suites first.
- **TLS 1.3-only is rarely safe here.** The IPA is a client of the API port and
  cannot natively be restricted to TLS 1.3 only (only custom IPA builds can,
  depending on the host OS and software stack), so keep TLS 1.2 enabled on the
  API port. iPXE has no TLS 1.3 support at all — it negotiates up to TLS 1.2 —
  so its port cannot be TLS 1.3-only either. Restrict a port to TLS 1.3
  (`-ALL +TLSv1.3`) only where every client of that port is known to support it.
- **Validate the result** with a tool such as `openssl s_client` or a TLS
  scanner against the TLS ports after applying changes: `6385` (Ironic API,
  which also serves node images), the virtual-media TLS port (`6183` under IrSO,
  `8083` in ironic-image), and the iPXE TLS port (`8084`). The plain-HTTP
  virtual-media listener (`6180` under IrSO, `80` in ironic-image) has no TLS to
  scan.
