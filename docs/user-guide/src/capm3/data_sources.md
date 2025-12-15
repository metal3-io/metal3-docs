# Using CAPM3 Data Sources

## Resource Relationships Overview

Assuming you've deployed Baremetal Operator and CAPM3, you will likely provision
a cluster and control-plane/worker nodes. This process creates several
interconnected resources and this document aims to explain those. As Metal3 is
an infrastructure provider for Cluster API (CAPI), it necessarily references
also other CAPI resources, however, this will focuses on Metal3 resources.

For more details about CAPI resources and to get the big picture, refer to
CAPI [docs](https://cluster-api.sigs.k8s.io/user/concepts). **Please note that the
following CAPI examples are only to illustrate how metal3 resources fit into the
big picture, so for up to date documentation of CAPI resources, refer to the
official docs.**

Visualization of relationships between Metal3 resources can be found in this 
[CAPM3 isssue](https://github.com/metal3-io/cluster-api-provider-metal3/issues/1358).
**Note that the graph is not perfect and there can be missing information.**

The example values in this document are from a cluster deployed with
[metal3 dev env](https://github.com/metal3-io/metal3-dev-env).

### 1. `Cluster`

The `Cluster` resource is **CAPI resource** and includes a reference to the control
plane via the `controlPlaneRef` field:

```yaml
controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1beta1
    kind: KubeadmControlPlane
    name: test1
    namespace: metal3
```

This object defines the cluster and links it to the control plane configuration.

### 2. `KubeadmControlPlane`

This is the main entry point for configuring the control plane. This **CAPI
resource** directly references CAPM3 resources used to manage the life cycle of
bare metal machines running under the controlplane nodes.

- Refers to a `KubeadmConfigTemplate`, which defines kubeadm configuration
- Refers to a `Metal3MachineTemplate`, which defines the infrastructure for
  control plane nodes

``` yaml
machineTemplate:
   infrastructureRef:
     apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
     kind: Metal3MachineTemplate
     name: test1-controlplane
     namespace: metal3
```

### 3. `KubeadmConfigTemplate`

`KubeadmConfigTemplate` is a **CAPI resources** and defines the `kubeadm`
configuration to use when initializing new nodes in the cluster. This template
contains multiple important fields, such as (but not limited to)

- `initConfiguration`
- `joinConfiguration`
- `postKubeadmCommands` commands to run after `kubeadm init`
- `preKubeadmCommands` commands to run before `kubeadm init`

Please refer to official docs for more details.

### 4. `Metal3MachineTemplate` → `Metal3Machine`

The `Metal3MachineTemplate` is **Metal3 resource** and it is used to generate
`Metal3Machine` resources on demand when `KubeadmControlPlane` or
`MachineDeployment` triggers the creation (for example when scaling up). Each
`Metal3Machine`:

- Is linked to a CAPI `Machine` resource.
- Consumes a `BareMetalHost` BMH instances on the cluster.
- **Refers to a `Metal3Data`** resource which holds specific node configuration

CAPI resource `Machine` is infrastructure agnostic resource. `Metal3Machine` is
metal3 specific resource which is used internally in CAPM3 to represent
machines. `BareMetalHost` represents bare metal server, and hence
`Metal3Machines` occupy those servers.

``` yaml
status:
...
  renderedData:
    name: test1-controlplane-template-0
    namespace: metal3
```

### 5. `Metal3DataTemplate` → `Metal3Data`

The `Metal3DataTemplate` is **Metal3 resource** and it is used to
create `Metal3Data` objects. These objects contain machine-specific
configuration, such as:

- Static IP settings
- Network interfaces (NICs)

> **Important**: This is one of the more complex parts of CAPM3
> configuration because CAPM3 does some preprocessing with the networking data.
> With other templates the data is mostly just copied over to deployed resources
> but the networking template supports convenience features like matching NICs
> (see [NIC matching](### NIC matching). Misconfiguration here can lead to
> provisioning errors:
>
> ```text
> "msg"="Reconciler error"
> "error"="Failed to create secrets: NIC name not found enp1s0".
> ```
>
> For example, see:
> [CAPM3 Issue #1998](https://github.com/metal3-io/cluster-api-provider-metal3/issues/1998)

The relevant fields in `Metal3Data` are

``` yaml
spec:
  claim:
    name: test1-jzktd
    namespace: metal3
  metaData:
    name: test1-jzktd-metadata
    namespace: metal3
  networkData:
    name: test1-jzktd-networkdata
    namespace: metal3
  template:
    name: test1-controlplane-template
    namespace: metal3
```

- `claim` refers to `Metal3DataClaim`
- `metaData` refers to `test1-jzktd-metadata` named secret
- `networkData` refers to `test1-jzktd-networkdata` named secret
- `template` refers to `Metal3DataTemplate`

Example content of `networkData` secret is

``` yaml
links:
- ethernet_mac_address: 00:fe:8d:20:55:35
  id: enp1s0
  mtu: 1500
  type: phy
- ethernet_mac_address: 00:fe:8d:20:55:36
  id: enp2s0
  mtu: 1500
  type: phy
networks:
- id: externalv4
  ip_address: 192.168.111.100
  link: enp2s0
  netmask: 255.255.255.0
...
```

#### NIC matching

If we continue the example above, the corresponding configuration in
`Metal3DataTemplate` is

``` yaml
  networkData:
    links:
      ethernets:
      - id: enp1s0
        macAddress:
          fromHostInterface: enp1s0
        mtu: 1500
        type: phy
      - id: enp2s0
        macAddress:
          fromHostInterface: enp2s0
        mtu: 1500
        type: phy
    networks:
      ipv4:
      - id: externalv4
        ipAddressFromIPPool: externalv4-pool
        link: enp2s0
...
```

Notice that the `links` are configured by interface ID `fromHostInterface: enp1s0`.
This is an example of preprocessing made by CAPM3.

CAPM3 matches the NICs in the template (or resolves the `fromHostInterface:
enp1s0`) by *reaching out* and reading `BaremetalHost` inspection data.

The `networks` section in the template defines an IP pool from which to take an
IP address (and with which NIC to associate it with). CAPM3 reserves the IP
address by creating an IP claim *for IPAM* and then inserts the IP address into
the secret which is referenced by the `Metal3Data`.

**Important!** CAPM3 utilizes both BMO and IPAM resources to generate the
machine specific data.

## Template vs. Concrete Resource

Each key resource in CAPM3 (and often in CAPI) typically has a matching
`Template` resource. These templates are used to create real resources on
demand, and users generally only need to configure the templates.

Once these templates are set, CAPM3 will render the actual resources during
cluster creation and updates.
