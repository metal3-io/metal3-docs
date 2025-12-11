# Instance Customization

Below we cover more advanced instance customization, more complex use-cases
and/or where customization of the metal3 deployment may be required.

For more general guidance around instance customization refer to the
[instance customization](./instance_customization.md) section.

## Pre-Provisioning NetworkData

*Pre-provisioning network data* describes the desired networking configuration
for the deploy ramdisk running `ironic-python-agent` (IPA).

Usage of this API requires an IPA ramdisk image with a tool capable of
interpreting and applying the data such as *cloud-init*, *Glean* or
alternative. The default community supported ramdisk does not currently contain
such a tool, but it is possible to build a custom image, for example using
[ironic-python-agent-builder][ipa_builder] with the [simple-init][simple_init]
element enabled.

Specifying pre-provisioning network data is useful in DHCP-less scenarios,
where we cannot rely on DHCP to provide network configuration for the IPA
ramdisk during the inspection and provisioning phases. In this situation we can
use redfish virtualmedia to boot the IPA ramdisk, and the generated virtualmedia
ISO will also serve as a configuration drive to provide the network
configuration.

The data is specified in the [OpenStack network_data.json][network_data] format
as described for *Network data* in the
[instance customization](./instance_customization.md) section.

Usually, one pre-provisioning network data secret is created per host and
should be linked to it like *Network data*. If you require the same
configuration for pre-provisioning and the deployed OS, it is only necessary to
specify pre-provisioning network data - the pre-provisioning secret is
automatically applied to networkData if no alternative secret is specified.

For example, given a local file `host-0-network.json`, you can create a secret:

```bash
kubectl create secret generic host-0-preprov-networkdata --from-file=networkData=host-0-network.json
```

Then you can attach it to the host during its enrollment:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: host-0
  namespace: my-cluster
spec:
  online: true
  bootMACAddress: 80:c1:6e:7a:e8:10
  bmc:
    address: redfish-virtualmedia://192.168.1.13
    credentialsName: host-0-bmc
  preprovisioningNetworkDataName: host-0-preprov-networkdata
```

[network_data]: https://docs.openstack.org/nova/latest/user/metadata.html#openstack-format-metadata
[ipa_builder]: https://docs.openstack.org/ironic-python-agent-builder/
[simple_init]: https://docs.openstack.org/diskimage-builder/latest/elements/simple-init/README.html
