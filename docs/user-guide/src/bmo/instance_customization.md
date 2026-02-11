# Instance Customization

<!-- cSpell:ignore diskimage -->

When provisioning bare-metal machines, it is usually required to customize the
resulting instances. Common use cases include injecting SSH keys, adding
users, installing software, starting services or configuring networking.

It is recommended to use [UserData](#userdata) or [NetworkData](#networkdata)
together with a first-boot configuration software such as
[cloud-init][cloud-init], [Glean][glean] or [Ignition][ignition]. Most cloud
images already come with one of these programs installed and configured.

**Note:** all customizations described in this document apply only to the final
instance provisioned by Metal3 and do not apply during the inspection,
preparing and provisioning phases.

[cloud-init]: https://cloudinit.readthedocs.io/en/latest/index.html
[glean]: https://opendev.org/opendev/glean/
[ignition]: https://coreos.github.io/ignition/

## Modified images

Rather than using an official cloud image, a user may build a custom image per
cluster or even per host. There are numerous tools to achieve that, the one
that the Metal3 community often employs is
[diskimage-builder](https://docs.openstack.org/diskimage-builder/latest/).

This approach has two major downsides:

1. Per-host images take a lot of disk space, especially since Ironic has a
   local image cache.
1. *diskimage-builder* allows only basic customization out of box, code will
   need to be written for anything complex.

It is recommended to use [UserData](#userdata) or [NetworkData](#networkdata)
instead when possible.

## NetworkData

*Network data* describes the desired networking configuration for the deployed
operating system, and is typically applied on first-boot via tools such as
*cloud-init*.

The data is specified in the [OpenStack network_data.json][network_data] format
supported by *cloud-init* and *Glean*.  The format is not very well documented,
but you can consult the [network_data JSON schema][network_data schema]
shipped with OpenStack.

Usually, one network data secret is created per host and should be linked to
it. For example, given a local file `host-0-network.json`, you can create a
secret:

```bash
kubectl create secret generic host-0-networkdata --from-file=networkData=host-0-network.json
```

Then you can attach it to the host during its enrollment or when starting
provisioning:

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
    address: ipmi://192.168.1.13
    credentialsName: host-0-bmc
  image:
    checksum: http://192.168.0.150/SHA256SUMS
    url: http://192.168.0.150/jammy-server-cloudimg-amd64.img
    checksumType: auto
  networkData:
    name: host-0-networkdata
```

[network_data]: https://docs.openstack.org/nova/latest/user/metadata.html#openstack-format-metadata
[network_data schema]: https://docs.openstack.org/nova/latest/_downloads/9119ca7ac90aa2990e762c08baea3a36/network_data.json

### NetworkData examples

Configure one NIC to use DHCP over IPv4, use Google DNS:

```json
{
  "links": [
    {
      "id": "enp130s0f0",
      "type": "phy",
      "ethernet_mac_address": "11:22:33:44:55:66"
    }
  ],
  "networks": [
    {
      "id": "enp130s0f0",
      "link": "enp130s0f0",
      "type": "ipv4_dhcp"
    }
  ],
  "services": [
    {
      "type": "dns",
      "address": "8.8.8.8"
    }
  ]
}
```

Configure a bond between two physical NICs, use DHCP over IPv4 for it:

```json
{
    "links": [
        {
            "id": "link0",
            "type": "phy",
            "ethernet_mac_address": "00:00:00:00:00:01",
            "mtu": 9000
        },
        {
            "id": "link1",
            "type": "phy",
            "ethernet_mac_address": "00:00:00:00:00:02",
            "mtu": 9000
        },
        {
            "id": "bond0",
            "type": "bond",
            "bond_links": [
                "link0",
                "link1"
            ],
            "bond_mode": "802.3ad",
            "bond_xmit_hash_policy": "layer3+4",
            "mtu": 9000
        }
    ],
    "networks": [
        {
            "id": "network0",
            "link": "bond0",
            "network_id": "data",
            "type": "ipv4_dhcp"
        }
    ],
    "services": []
}
```

**Hint:** you can use the inspection data from a `HardwareData` resource to
learn the NIC names and their MAC addresses:

```console
$ kubectl get hardwaredata -n my-cluster host-0 -o jsonpath='{.spec.hardware.nics}' | jq .
[
  {
    "ip": "192.168.111.25",
    "mac": "00:f8:a8:a0:d0:d2",
    "model": "0x1af4 0x0001",
    "name": "enp2s0"
  },
  {
    "ip": "fd2e:6f44:5dd8:c956::19",
    "mac": "00:f8:a8:a0:d0:d2",
    "model": "0x1af4 0x0001",
    "name": "enp2s0"
  },
  {
    "mac": "00:f8:a8:a0:d0:d0",
    "model": "0x1af4 0x0001",
    "name": "enp1s0"
  }
]
```

## UserData

*User data* describes the desired configuration of the instance in a format
specific to the first-boot software:

* *cloud-init* supports two [formats][cloud-config]: *cloud-config* YAML and
  a shell script (distinguished by the header).
* *Ignition* uses its own [format][ignition-config].
* *Glean* does not support user data at all.

For example, you can create a *cloud-config* file `host-0.yaml`:

```yaml
#cloud-config
users:
- name: metal3
  ssh_authorized_keys:
  - ssh-ed25519 ABCD... metal3@example.com
```

```bash
kubectl create secret generic host-0-userdata -n my-cluster --from-file=userData=host-0.yaml
```

Then you can attach it to the host during its enrollment or when starting
provisioning:

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
    address: ipmi://192.168.1.13
    credentialsName: host-0-bmc
  image:
    checksum: http://192.168.0.150/SHA256SUMS
    url: http://192.168.0.150/jammy-server-cloudimg-amd64.img
  userData:
    name: host-0-userdata
```

[cloud-config]: https://cloudinit.readthedocs.io/en/latest/explanation/format.html
[ignition-config]: https://coreos.github.io/ignition/specs/

## Implementation notes

User and network data are passed to the instance via a so called *config
drive*, which is a small additional disk partition created on the root device
during provisioning. This partition contains user and network data, as well as
*meta data* with a host name, as files.

Ironic is responsible for creating a partition image (usually, in the ISO 9660
format) and passing it to the [IPA](../ironic/ironic-python-agent.md) ramdisk
together with the rest of the deployment information. Once the instance boots,
the partition is mounted by the first boot software and the configuration
loaded from it.

Both *cloud-init* and *Ignition* support various data sources, from which
user and network data are fetched. Depending on the image type, different
sources may be enabled by default:

* In case of *cloud-init*, make sure that the [config drive data
  source][configdrive] is enabled. This is not the same as the OpenStack data
  source, although both are used with OpenStack.

* For *Ignition* to work, you must use an OpenStack Platform image (see
  [supported platforms][platforms]).

[configdrive]: https://cloudinit.readthedocs.io/en/latest/reference/datasources/configdrive.html#datasource-config-drive
[platforms]: https://coreos.github.io/ignition/supported-platforms/
