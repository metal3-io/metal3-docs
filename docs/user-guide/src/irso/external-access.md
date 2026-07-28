# External Access

By default, Ironic is started with host networking access. The assumption is
that hosts being provisioned will call back to Ironic API using its host IP.
All [basic examples](install-basics.md) install this architecture. There are
two ways to modify it:

- [External IP](#external-ip)
- [Ingress](#ingress)

Both approaches apply **only to virtual media** provisioning! Network boot
always rely on host networking. They're also not compatible with the HA
architecture because there is no way to balance access to instance-local image
servers.

## External IP

This feature allows providing an externally managed IP address that will be
used for API callbacks and fetching images during virtual media deployments:

```yaml
apiVersion: ironic.metal3.io/v1alpha1
kind: Ironic
metadata:
  name: ironic
  namespace: test-ironic
spec:
  networking:
    externalIP: 192.0.2.42
  version: "37.0"
```

**WARNING:** the IP address must be accessible from one of the host's NIC as
well as from the BMC. This is because the provisioning ISO is downloaded by the
BMC itself.

## Ingress

Starting with version 0.10, IrSO can manage an Ingress route automatically:

```yaml
apiVersion: ironic.metal3.io/v1alpha1
kind: Ironic
metadata:
  name: ironic
  namespace: test-ironic
spec:
  ingress:
    host: myironic.example.com
  version: "37.0"
```

**WARNING:** the ingress host must be accessible from one of the host's NIC as
well as from the BMC.
