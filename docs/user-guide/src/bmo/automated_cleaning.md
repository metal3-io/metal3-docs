# Automated Cleaning

One of the Ironic's feature exposed to Metal3 Baremetal Operator is [node automated cleaning](https://docs.openstack.org/ironic/latest/admin/cleaning.html#automated-cleaning). When enabled, automated cleaning kicks off when a node is provisioned first time and on every time deprovisioned.

There are two automated cleaning modes available which can be set via `automatedCleaningMode` field of a BareMetalHost `spec`.

- `metadata` to enable the disk cleaning
- `disabled` to disable the disk cleaning

We named enabling mode `metadata` instead of simply `enabled` because we expect that in the future we will expand the feature to allow
selecting certains disks (specified via metadata) of a node to be cleaned, which is currently out of scope.

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: example-node
spec:
  automatedCleaningMode: metadata
  online: true
  bootMACAddress: 00:8a:b6:8e:ac:b8
  bootMode: legacy
  bmc:
    address: ipmi://192.168.111.1:6230
    credentialsName: example-node-bmc-secret
  automatedCleaningMode: metadata
```

For a node with `disabled` value, no cleaning will be performed during deprovisioning. Note that this might introduce security
vulnerabilities in case there is sensitive data which must be wiped out from the disk when the host is being recycled.

If `automatedCleaningMode` is not set by the user, it will be set to the default mode `metadata`. To know more about cleaning
steps that Ironic performs on the node, see the [cleaning steps](https://docs.openstack.org/ironic/latest/admin/cleaning.html#cleaning-steps).

If you are using Cluster-api-provider-metal3 on top of Baremetal Operator, then please see [this](../capm3/automated_cleaning.md).