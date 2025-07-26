# Metal3DataTemplate

The `Metal3DataTemplate` resource defines templates for generating metadata and
network configuration for bare metal hosts in a Cluster API Provider Metal3
(CAPM3) cluster. It serves as a blueprint for creating host-specific
configuration data that will be rendered into Kubernetes secrets.

## Overview

A `Metal3DataTemplate` contains:

- **Metadata templates**: Templates for generating host-specific metadata
- **Network data templates**: Templates for generating network configuration
- **Index management**: Configuration for managing host indexes and naming

The template is reconciled by its own controller, which adds labels pointing to
the `Metal3Cluster` that has nodes linking to this object.

## API Reference

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3DataTemplate
metadata:
  name: <template-name>
  namespace: <namespace>
  ownerReferences:
  - apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    controller: true
    kind: Metal3Cluster
    name: <cluster-name>
spec:
  templateReference: <reference-name>  # Optional
  metaData:
    # Metadata template configuration
  networkData:
    # Network data template configuration
status:
  indexes:
    "<index>": "<machine-name>"
  dataNames:
    "<machine-name>": "<data-name>"
  lastUpdated: "<timestamp>"
```

## Metadata Specifications

The `metaData` field contains templates that will render data in different ways.
The following types of objects are available:

### Strings

Renders the given string as a value in the metadata.

```yaml
metaData:
  strings:
  - key: hostname
    value: worker-node
```

### Object Names

Renders the name of the object that matches the specified type.

```yaml
metaData:
  objectNames:
  - key: machine_name
    object: machine
  - key: bmh_name
    object: baremetalhost
```

### Indexes

Renders the index of the current object with configurable offset and step.

```yaml
metaData:
  indexes:
  - key: node_index
    offset: 0
    step: 1
    prefix: "worker-"
    suffix: "-node"
```

### IP Pool References

Renders values from IP Pool objects defined in the
[IP Address Manager](https://github.com/metal3-io/ip-address-manager).

```yaml
metaData:
  ipAddressesFromIPPool:
  - key: ip_address
    Name: pool-1
  prefixesFromIPPool:
  - key: network_prefix
    Name: pool-1
  gatewaysFromIPPool:
  - key: gateway
    Name: pool-1
  dnsServersFromIPPool:
  - key: dns_servers
    Name: pool-1
```

### Host Interface References

Renders the MAC address of a BareMetalHost interface.

```yaml
metaData:
  fromHostInterfaces:
  - key: primary_mac
    interface: "eth0"
```

### Label and Annotation References

Renders content from labels or annotations on objects.

```yaml
metaData:
  fromLabels:
  - key: environment
    object: machine
    label: env
  fromAnnotations:
  - key: rack_location
    object: machine
    annotation: rack
```

## Network Data Specifications

The `networkData` field defines network configuration templates that follow the
[Nova network_data.json format](https://docs.openstack.org/nova/latest/user/metadata.html#openstack-format-metadata).

### Links Configuration

Defines layer 2 interfaces including ethernets, bonds, and VLANs.

```yaml
networkData:
  links:
    ethernets:
    - type: "phy"
      id: "enp1s0"
      mtu: 1500
      macAddress:
        fromAnnotation:
          object: machine
          annotation: primary-mac
    bonds:
    - id: "bond0"
      mtu: 1500
      macAddress:
        string: "XX:XX:XX:XX:XX:XX"
      bondMode: "802.3ad"
      bondLinks:
        - enp1s0
        - enp2s0
    vlans:
    - id: "vlan1"
      mtu: 1500
      macAddress:
        string: "YY:YY:YY:YY:YY:YY"
      vlanID: 1
      vlanLink: bond0
```

#### Ethernet Types

- `bridge`
- `dvs`
- `hw_veb`
- `hyperv`
- `ovs`
- `tap`
- `vhostuser`
- `vif`
- `phy`

#### Bond Modes

- `802.3ad`
- `balance-rr`
- `active-backup`
- `balance-xor`
- `broadcast`
- `balance-tlb`
- `balance-alb`

#### MAC Address Sources

- `string`: Direct MAC address string
- `fromAnnotation`: MAC from object annotation
- `fromHostInterface`: MAC from BareMetalHost interface

### Networks Configuration

Defines layer 3 networks with various IP addressing schemes.

```yaml
networkData:
  networks:
    ipv4DHCP:
    - id: "provisioning"
      link: "bond0"
    ipv4:
    - id: "Baremetal"
      link: "vlan1"
      IPAddressFromIPPool: pool-1
      routes:
      - network: "0.0.0.0"
        netmask: 0
        gateway:
          fromIPPool: pool-1
        services:
          dns:
          - "8.8.4.4"
          dnsFromIPPool: pool-1
    ipv6DHCP:
    - id: "provisioning6"
      link: "bond0"
    ipv6SLAAC:
    - id: "provisioning6slaac"
      link: "bond0"
    ipv6:
    - id: "Baremetal6"
      link: "vlan1"
      IPAddressFromIPPool: pool6-1
      routes:
      - network: "0::0"
        netmask: 0
        gateway:
          string: "2001:0db8:85a3::8a2e:0370:1"
        services:
          dns:
          - "2001:4860:4860::8844"
          dnsFromIPPool: pool6-1
```

### Services Configuration

Defines DNS services.

```yaml
networkData:
  services:
    dns:
    - "8.8.8.8"
    - "2001:4860:4860::8888"
    dnsFromIPPool: pool-1
```

## Template Reference Management

The `templateReference` field enables template versioning and updates:

- **Immutable Templates**: Data template parts are immutable since BareMetalHost
  references the secrets
- **Update Process**: Updates require creating a new template and referencing it
  in the Metal3MachineTemplate
- **Backward Compatibility**: Supports transition from old templates without
  `templateReference` to new ones

### Template Linking

Metal3Data objects are linked to Metal3DataTemplate by:

1. Direct reference in the `template` field
2. Matching `templateReference` key
3. Template's `templateReference` matching the Metal3Data's template name
   (backward compatibility)

## Complete Example

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3DataTemplate
metadata:
  name: worker-template
  namespace: default
  ownerReferences:
  - apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    controller: true
    kind: Metal3Cluster
    name: my-cluster
spec:
  templateReference: worker-v1
  metaData:
    strings:
    - key: hostname
      value: worker
    indexes:
    - key: node_index
      offset: 0
      step: 1
      prefix: "worker-"
      suffix: "-node"
    ipAddressesFromIPPool:
    - key: ip
      Name: worker-pool
    fromHostInterfaces:
    - key: mac
      interface: "eth0"
  networkData:
    links:
      ethernets:
      - type: "phy"
        id: "eth0"
        mtu: 1500
        macAddress:
          fromHostInterface: "eth0"
    networks:
      ipv4:
      - id: "provisioning"
        link: "eth0"
        IPAddressFromIPPool: worker-pool
        routes:
        - network: "0.0.0.0"
          netmask: 0
          gateway:
            fromIPPool: worker-pool
    services:
      dns:
      - "8.8.8.8"
      - "8.8.4.4"
status:
  indexes:
    "0": "worker-0"
    "1": "worker-1"
  dataNames:
    "worker-0": worker-template-0
    "worker-1": worker-template-1
  lastUpdated: "2023-01-01T00:00:00Z"
```

## Best Practices

1. **Use Template References**: Always set `templateReference` for better
   template management
2. **Plan Indexing**: Consider your indexing strategy for consistent naming
3. **Validate Network Config**: Test network configurations before deployment
4. **Use IP Pools**: Leverage IP pools for dynamic address allocation
5. **Document Templates**: Keep templates well-documented for team
   collaboration

## Related Resources

- [Metal3Data](metal3data.md) - The rendered data instances
- [IP Address Manager](https://github.com/metal3-io/ip-address-manager) - IP pool
  management
- [Nova Network Data Format](https://docs.openstack.org/nova/latest/) - Network
  configuration format
