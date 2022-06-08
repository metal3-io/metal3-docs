# Detached annotation

The detached annotation provides a way to prevent management of a BareMetalHost.
It works by deleting the host information from Ironic without triggering deprovisioning.
The BareMetal Operator will recreate the host in Ironic again once the annotation is removed.
This annotation can be used with BareMetalHosts in `Provisioned`, `ExternallyProvisioned`, `Ready` or `Available` states.

Normally, deleting a BareMetalHost will always trigger deprovisioning.
This can be problematic and unnecessary if we just want to, for example, move the BareMetalHost from one cluster to another.
By applying the annotation before removing the BareMetalHost from the old cluster, we can ensure that the host is not disrupted by this (normally it would be deprovisioned).
The next step is then to recreate it in the new cluster without triggering a new inspection.
See the [status annotation page](./status_annotation.md) for how to do this.

The annotation key is `baremetalhost.metal3.io/detached` and the value can be anything (it is ignored).
Here is an example:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: example
  annotations:
    baremetalhost.metal3.io/detached: ""
spec:
  online: true
  bootMACAddress: 00:8a:b6:8e:ac:b8
  bootMode: legacy
  bmc:
    address: ipmi://192.168.111.1:6230
    credentialsName: example-bmc-secret
...
```

Why is this annotation needed?

- It provides a way to move BareMetalHosts between clusters (essentially deleting them in the old cluster and recreating them in the new) without going through deprovisioning, inspection and provisioning.
- It allows deleting the BareMetalHost object without triggering deprovisioning. This can be used to hand over management of the host to a different system without disruption.

For more details, please see the [design proposal](https://github.com/metal3-io/metal3-docs/blob/main/design/baremetal-operator/detached-annotation.md).
