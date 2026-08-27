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
  version: "38.0"
```

**WARNING:** the IP address must be accessible from one of the host's NIC as
well as from the BMC. This is because the provisioning ISO is downloaded by the
BMC itself.

Starting with version 0.11, you can also provide separate URL overrides for
Ironic API and its image server:

```yaml
apiVersion: ironic.metal3.io/v1alpha1
kind: Ironic
metadata:
  name: ironic
  namespace: test-ironic
spec:
  networking:
    externalCallbackURL: https://proxy.example.com/ironic/api
    imageServerExternalURL: https://proxy.example.com/ironic/images
  version: "38.0"
```

**NOTE:** this image server is the internal server from which Ironic serves
images to the BMC and to the agent on the machine. It's **not** the server that
hosts user's images.

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
  version: "38.0"
```

**WARNING:** the ingress host must be accessible from one of the host's NIC as
well as from the BMC.

Starting with version 0.11, you can also override API URL or image server URL
separately as shown in the previous section.

## Disabling host network

By default, the Ironic pod runs with host networking to ensure that bare-metal
machines can reach its API and its DHCP server. Starting with IrSO 0.11, you
can disable host networking, provided that only virtual media is used.  This
feature must be combined with [external IP](#external-ip) or
[ingress](#ingress) to make sure that Ironic API is still accessible by BMCs
and the machines themselves:

```yaml
apiVersion: ironic.metal3.io/v1alpha1
kind: Ironic
metadata:
  name: ironic
  namespace: test-ironic
spec:
  ingress:
    host: myironic.example.com
  networking:
    disableHostNetworking: true
  version: "38.0"
```

```yaml
apiVersion: ironic.metal3.io/v1alpha1
kind: Ironic
metadata:
  name: ironic
  namespace: test-ironic
spec:
  networking:
    disableHostNetworking: true
    externalIP: 192.0.2.42
  version: "38.0"
```

**WARNING:** most `networking` fields cannot be set together with
`disableHostNetworking`.
