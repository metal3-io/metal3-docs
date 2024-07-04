# Automated Cleaning

One of the Ironic's feature exposed to Metal3 Baremetal Operator is [node
automated
cleaning](https://docs.openstack.org/ironic/latest/admin/cleaning.html#automated-cleaning).
When enabled, automated cleaning kicks off when a node is provisioned first
time and on every deprovisioning.

There are two automated cleaning modes available which can be configured via
`automatedCleaningMode` field of a BareMetalHost `spec`:

- `metadata` (the default) enables the removal of partitioning tables from all
  disks
- `disabled` disables the cleaning process

For example:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: example-host
spec:
  automatedCleaningMode: metadata
  bootMACAddress: 00:8a:b6:8e:ac:b8
  bmc:
    address: ipmi://192.168.111.1:6230
    credentialsName: example-node-bmc-secret
  online: true
```

**Note:** Ironic supports full data removal, which is not currently exposed in
Metal3.

For a host with cleaning disabled, no cleaning will be performed during
deprovisioning. This is faster but may cause conflicts on subsequent
provisionings (e.g. Ceph is known not to tolerate stale data partitions).

**Warning:** when disabling cleaning, consider setting [root device
hints](root_device_hints.md) to specify the exact block device to install to.
Otherwise, subsequent provisionings may end up with different root devices,
potentially causing incorrect configuration because of duplicated [config
drives](instance_customization.md).

If you are using Cluster-api-provider-metal3, please see [its cleaning
documentation](../capm3/automated_cleaning.md).
