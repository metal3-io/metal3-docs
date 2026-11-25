# High Availability

[IrSO](../irso/introduction.md) can install Ironic in an HA configuration,
where every replica handles its share of hosts and can respond to API requests
for any of them.

**WARNING:** while HA mode has existed in Ironic since its early days, the HA
support in IrSO is relatively new and is considered experimental.

## Requirements

- [Feature gate](introduction.md#feature-gates) `HighAvailability` must be
  enabled in the operator configuration.

- [External MariaDB](database.md) must be used as a database. All replicas will
  share this database, so it must handle the expected load.

- TLS certificates must be valid for all IP addresses on which Ironic may be
  running. Keep in mind that HA mode relies on an internal RPC bus, which also
  uses TLS. If TLS validation is not possible, you'll have to set
  `tls.insecureRPC`.

Limitations:

- DHCP and most networking settings are not available in the HA mode. You must
  use virtual media for provisioning.

- Using Keepalived to manage the provisioning IP address is not supported as
  well. If you use a dedicated network, you must manage IP addresses on it
  yourself.

- Since each Ironic replica has an independent image cache, [external
  access](external-access.md) may not work correctly in this case.

**NOTE:** there are plans to lift all of these restrictions eventually.

## Enabling HA mode

After enabling the corresponding feature gate, set the `highAvailability` flag
to `true`:

```yaml
apiVersion: ironic.metal3.io/v1alpha1
kind: Ironic
metadata:
  name: ironic
  namespace: test-ironic
spec:
  database:
    credentialsName: secret-with-user-password
    host: mariadb.hostname.example.com
    name: database-name
  deployRamdisk:
    sshKey: "ssh-ed25519 AAAAC3..."
  highAvailability: true
  tls:
    certificateName: ironic-tls
    insecureRPC: false
  version: "39.0"
```

This configuration installs an Ironic replica on every Kubernetes node. You may
want to limit which nodes get a replica:

```yaml
apiVersion: ironic.metal3.io/v1alpha1
kind: Ironic
metadata:
  name: ironic
  namespace: test-ironic
spec:
  # ...
  highAvailability: true
  nodeSelector:
    nodes.example.com/ironic: "true"
  # To run on control plane nodes you may need to set up tolerations.
  # NOTE: tolerations require feature gate Overrides.
  overrides:
    tolerations:
    - key: node-role.kubernetes.io/control-plane
      effect: NoSchedule
      operator: Exists
    - key: node-role.kubernetes.io/master
      effect: NoSchedule
      operator: Exists
```
