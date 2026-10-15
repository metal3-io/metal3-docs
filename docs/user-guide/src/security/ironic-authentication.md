# Ironic authentication

<!-- cSpell:ignore noauth Keystone -->

Hosts under Metal3's control contact the Ironic API during inspection and
provisioning, and they remain connected to the provisioning network while
running user workloads afterwards. If that API is unauthenticated, anyone with
access to the provisioning network can use it to manipulate your nodes.
Requiring authentication on the Ironic API is therefore strongly advised.
Authentication is independent of TLS (covered in
[TLS configuration and hardening](./tls.md)); a hardened deployment uses both.

## Authentication strategy

Metal3 authenticates the Ironic API with HTTP Basic Authentication, and Bare
Metal Operator (BMO) is configured with matching credentials to reach Ironic.

Ironic also has a `noauth` (no-authentication) mode, but it is discouraged
and is expected to be phased out as part of the Ironic Standalone Operator
migration, so you should not rely on it. OpenStack Identity (Keystone)
authentication is not supported.

## How it fits together

Authentication has two sides that must agree: Ironic is configured to
require credentials, and BMO is configured to present matching ones.
The username and password BMO sends must match what Ironic accepts.

With the Ironic Standalone Operator this is wired up for you (see below).
For the credential settings BMO reads and how to configure them, see the
[Bare Metal Operator authentication guide](https://github.com/metal3-io/baremetal-operator/blob/main/docs/ironic-authentication.md).

## With the Ironic Standalone Operator (recommended)

When installing with the Ironic Standalone Operator (IrSO), credentials are
handled for you: IrSO generates a random API password unless you supply your
own. The credentials secret is referenced by `spec.apiCredentialsName` on the
`Ironic` resource, and a new secret is created automatically if that field is
empty.

To provide your own credentials instead, create the secret, set
`spec.apiCredentialsName` on the `Ironic` resource to its name, and give it the
label `environment.metal3.io/ironic-standalone-operator=true` so that IrSO
recognizes it. You can read the effective credentials back from the referenced
secret; see [Install Ironic with IrSO](../irso/install-basics.md) for the exact
commands.

## Manual and script-based installation

For the older script/Kustomize-based installation, Ironic enables HTTP basic
auth when an htpasswd file is present: the `basic-auth` Kustomize component
mounts an `ironic-htpasswd` secret at `/auth/ironic`, and Ironic then sets
`auth_strategy = http_basic`. The baremetal-operator repository ships a
ready-made `basic-auth_tls` overlay for the common case of basic auth plus TLS.

For the out-of-cluster deployment driven by `run_local_ironic.sh`, the
equivalent switch is the `IRONIC_BASIC_AUTH` environment variable.
See [the old installation process](../ironic/ironic_installation.md) for
details; note that this path is being phased out in favour of IrSO.
