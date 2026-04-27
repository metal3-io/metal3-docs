# IP Reuse (BMH Name-Based Preallocation)

## Overview

IP reuse, also known as BMH Name-Based Preallocation, is a feature that enables
predictable IP address assignment to BareMetalHosts. This is particularly useful
during rolling upgrades where you want nodes to retain their IP addresses even
as the underlying Metal3Machine and Metal3Data objects are recreated.

## Default Behavior (Without BMH Name-Based Preallocation)

As is now, IPPool is an object representing a set of IPAddress pools to be used
for IPAddress allocations. An IPClaim is an object representing a request for an
IPAddress allocation. Consequently, the IPClaim object name is structured as
following:

**IPClaimName** = **Metal3DataName** + **(-)** + **IPPoolName**

Example: metal3datatemplate-0-pool0

The `Metal3DataName` is derived from the `Metal3DataTemplateName` with an added
index (`Metal3DataTemplateName-index`), and the `IPPoolName` comes from the
IPPool object directly. (See the
[IP Address manager](../ipam/introduction.md)
for more details on these objects). In the CAPM3 workflow, when a Metal3Machine
is created and a Metal3Data object is requested, the process of choosing an
`index` to be appended to the name of the `Metal3DataTemplateName`, is random.
For example, let's imagine we have two Metal3Machines: `metal3machine-0` and
`metal3machine-1` which creates the following `metal3datatemplate-0` and
`metal3datatemplate-1` Metal3Data objects respectively. However, if two nodes
are being upgraded at a time, there is no guarantee that same indices will be
appended to the respective objects and in fact it can be in completely reverse
order (i.e. `metal3machine-0` will get `m3datatemplate-1` and `metal3machine-1`
will get `m3datatemplate-0`). In order to make it predictable, we structure
IPClaim object name using the BareMetalHost name, as following:

**IPClaimName** = **BareMetalHostName** + **(-)** + **IPPoolName**

Example: node-0-pool0

Now, the first part consists of `BareMetalHostName` which is the name of the
BareMetalHost object, and should always stay the same once created
(predictable). The second part of it is kept unchanged.

## What is the use of PreAllocations field

Once we have a predictable `IPClaimName`, we can make use of a
`PreAllocations map[string]IPAddressStr` field in the IPPool object to achieve
our goal.

We simply add the claim name(s) using the new format (BareMetalHost name
included) to the `preAllocations` field in the `IPPool`, i.e:

```yaml
apiVersion: ipam.metal3.io/v1alpha1
kind: IPPool
metadata:
  name: baremetalv4-pool
  namespace: metal3
spec:
  clusterName: test1
  gateway: 192.168.111.1
  namePrefix: test1-bmv4
  pools:
  - end: 192.168.111.200
    start: 192.168.111.100
  prefix: 24
  preAllocations:
    node-0-pool0: 192.168.111.101
    node-1-pool0: 192.168.111.102
status:
  indexes:
    node-0-pool0: 192.168.111.101
    node-1-pool0: 192.168.111.102
```

Since claim names include BareMetalHost names on them, we are able to predict an
IPAddress assigned to the specific node.

## How to Enable BMH Name-Based Preallocation

To enable the feature, a boolean flag called `enable-bmh-name-based-preallocation`
was added. It is configurable via clusterctl and it can be passed to the
clusterctl configuration file by the user.

### Via clusterctl Configuration

Add to your `"${XDG_CONFIG_HOME}"/.config/cluster-api/clusterctl.yaml`:

```yaml
variables:
  ENABLE_BMH_NAME_BASED_PREALLOCATION: "true"
```

### Via Controller Flag

The CAPM3 controller accepts a flag:

```bash
--enable-bmh-name-based-preallocation=true
```

This flag enables the BMH name-based IPClaim naming scheme.

## Use Cases

### Rolling Upgrades with Stable IPs

When performing a rolling upgrade of your cluster:

1. Each BareMetalHost has a stable name (e.g., `node-0`, `node-1`)
1. With preallocation enabled, IPClaims are named using the BMH name
1. Pre-populate the IPPool's `preAllocations` field with the desired mappings
1. As nodes are upgraded, they automatically receive their pre-assigned IPs

### DNS and Certificate Management

Stable IP addresses simplify:

- DNS record management (no need to update records after upgrades)
- Certificate provisioning (certificates tied to specific IPs remain valid)
- Firewall rules (static IP-based rules don't need updates)

### Multi-Cluster Deployments

When managing multiple clusters, predictable IPs help with:

- Network segmentation and planning
- Monitoring and alerting configurations
- Load balancer backend configurations

## Interaction with Metal3Data Labels

When BMH name-based preallocation is enabled, additional labels are added to
Metal3Data objects to track the association:

- `infrastructure.cluster.x-k8s.io/data-name` (`DataLabelName`) stores the
  Metal3Data name
- `infrastructure.cluster.x-k8s.io/pool-name` (`PoolLabelName`) stores the
  referenced pool name

These labels make it possible to track which Metal3Data object and pool were
used for a given allocation.

## Considerations

### BareMetalHost Naming

For this feature to work effectively:

- BareMetalHost names must be stable and predictable
- Avoid using generated names that change between deployments
- Use meaningful names that reflect the physical hardware (e.g., rack position)

### IPPool Configuration

When setting up preAllocations:

- The claim name format is: `{bmh-name}-{pool-name}`
- Ensure all expected BMH names are covered in the preAllocations map
- IPs in preAllocations are reserved and won't be allocated to other claims

### Cleanup

When a Metal3Machine is deleted:

- The IPClaim is released
- The preallocated IP remains reserved in the pool
- When a new Metal3Machine claims the same BMH, it gets the same IP

## Troubleshooting

### IP Not Being Reused

1. Verify `--enable-bmh-name-based-preallocation` or
   `ENABLE_BMH_NAME_BASED_PREALLOCATION` is enabled
1. Check that the IPPool `preAllocations` field includes the correct mapping
1. Verify the claim name format matches: `{bmh-name}-{pool-name}`

### IPClaim Name Mismatch

If IPClaims are not using BMH names:

1. Check controller logs for preallocation-related messages
1. Verify the `--enable-bmh-name-based-preallocation` flag is properly set on
   the controller deployment
1. Restart the controller after changing the configuration
