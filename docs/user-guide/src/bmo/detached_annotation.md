# Detached annotation

The detached annotation provides a way to prevent management of a BareMetalHost.
It works by deleting the host information from Ironic without triggering deprovisioning.
The BareMetal Operator will recreate the host in Ironic again once the annotation is removed.
This annotation can be used with BareMetalHosts in `Provisioned`, `ExternallyProvisioned` or `Available` states.

Normally, deleting a BareMetalHost will always trigger deprovisioning.
This can be problematic and unnecessary if we just want to, for example, move the BareMetalHost from one cluster to another.
By applying the annotation before removing the BareMetalHost from the old cluster, we can ensure that the host is not disrupted by this (normally it would be deprovisioned).
The next step is then to recreate it in the new cluster without triggering a new inspection.
See the [status annotation page](./status_annotation.md) for how to do this.

The detached annotation is also useful if you want to move the host under
control of a different management system without fully removing it from
BareMetal Operator. Particularly, detaching a host stops Ironic from trying to
enforce its power state as per the `online` field.

For more details, please see the [design proposal](https://github.com/metal3-io/metal3-docs/blob/main/design/baremetal-operator/detached-annotation.md).

## How to detach

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

Now wait for the `operationalStatus` field to become `detached`.

## How to attach again

If you want to attach a previously detached host, remove the annotation and
wait for the `operationalStatus` field to become `OK`.
