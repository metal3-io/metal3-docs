# Security best practices

Metal3 provisions and manages bare-metal machines, which means a Metal3
deployment spans several trust boundaries at once: the Kubernetes control plane
that runs [Bare Metal Operator](../bmo/introduction.md) (BMO), the
[Ironic](../ironic/introduction.md) service that drives the hardware, and the
provisioning network that carries DHCP, PXE/iPXE, image downloads, and
out-of-band BMC traffic. Each of these boundaries can expose credentials, host
firmware, and the operating systems written to disk, so each deserves
deliberate hardening before a deployment leaves the lab.

The introductory material in this guide, most notably the
[quick-start](../quick-start.md), favors the shortest path to a working
deployment. It uses self-signed or minimal TLS, an unauthenticated image
server, and cluster-wide permissions. Those defaults are fine for evaluation
but are **not** intended for production. This section collects the
deployment-time practices that turn an evaluation setup into a hardened one.

## What you are securing

It helps to think about the deployment in terms of three planes, each with its
own exposure:

- **Control plane (BMO in Kubernetes).** BMO reads `BareMetalHost` resources and
  the Kubernetes Secrets holding BMC credentials, and talks to the Ironic API.
  Relevant concerns are how widely BMO's RBAC is scoped and how it
  authenticates to Ironic.
- **Provisioning service (Ironic).** Ironic exposes an API and serves boot
  artifacts and disk images. Relevant concerns are TLS on the API and the
  image/virtual-media HTTP servers, the cipher/protocol hardening applied to
  them, and the basic-auth credentials protecting the API.
- **Provisioning network (PXE/iPXE, DHCP, HTTP, BMC).** This is the path used to
  boot the Ironic Python Agent and to fetch images, plus the out-of-band channel
  to the BMC. Relevant concerns are TLS-enabled network boot, verifying the
  image server's certificate, and trusting the BMC's CA.

## In this section

Dedicated pages are being consolidated here from the component repositories.
Until each one lands, the list below points to the current authoritative source
for that topic.

- **TLS configuration and hardening flags.** Selecting the TLS protocol and
  cipher suites for the Ironic API and the virtual-media/image HTTP servers
  (`IRONIC_SSL_PROTOCOL`, `IRONIC_TLS_*`, and the `IRONIC_VMEDIA_*` equivalents),
  and the deployment-level switch when installing with the Ironic Standalone
  Operator. See the
  [ironic-image TLS configuration](https://github.com/metal3-io/ironic-image/blob/main/README.md)
  reference and [Install Ironic with IrSO](../irso/install-basics.md).
- **Certificate supply and lifecycle.** Providing certificates (self-signed for
  test, [cert-manager](https://cert-manager.io) for production), the required
  Subject Alternative Names (DNS name **and** IP), rotation and renewal, how BMO
  is told to trust Ironic, the BMC CA trust path, and the meaning of
  `disableCertificateVerification` on a `BareMetalHost`. See
  [Install Ironic with IrSO](../irso/install-basics.md) and the
  [quick-start](../quick-start.md).
- **Ironic authentication.** The Ironic `auth_strategy` modes (`noauth` versus
  `http_basic`), where BMO reads the credentials, and the fact that OpenStack
  Identity (Keystone) is not supported. See the
  [Bare Metal Operator Authentication guide](https://github.com/metal3-io/baremetal-operator/blob/main/docs/ironic-authentication.md).
- **TLS-enabled network boot (iPXE).** Running HTTPS iPXE end to end: building
  an iPXE binary with an embedded trust anchor, how it ties into the httpd TLS
  port, and the tradeoffs. See the
  [ipxe-builder image](https://github.com/metal3-io/utility-images#ipxe-builder-image),
  which builds custom iPXE firmware with the embedded trust anchor. The default
  built-in firmware is described in ironic-image's
  [build-ipxe.sh](https://github.com/metal3-io/ironic-image/blob/main/build-ipxe.sh)
  and [README](https://github.com/metal3-io/ironic-image/blob/main/README.md).
- **Namespace-scoped BMO (RBAC hardening).** Restricting BMO to a single
  namespace with `WATCH_NAMESPACE` and per-namespace `Role`/`RoleBinding`
  instead of cluster-wide permissions. See the
  [namespace-scoped BMO setup](https://github.com/metal3-io/baremetal-operator/blob/main/docs/namespace-scoped-setup.md).

## Reporting a vulnerability

This section is about hardening your own deployment. If instead you need to
report a suspected vulnerability in Metal3 itself, follow the
[project security policy](../security_policy.md).
