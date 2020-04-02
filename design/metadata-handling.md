<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Generating Metadata and Network data per node in CAPM3

## Status

provisional

## Table of Contents

<!--ts-->
   * [Title](#title)
      * [Status](#status)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
         * [Non-Goals](#non-goals)
      * [Proposal](#proposal)
         * [User Stories [optional]](#user-stories-optional)
            * [Story 1](#story-1)
            * [Story 2](#story-2)
         * [Implementation Details/Notes/Constraints [optional]](#implementation-detailsnotesconstraints-optional)
         * [Risks and Mitigations](#risks-and-mitigations)
      * [Design Details](#design-details)
         * [Work Items](#work-items)
         * [Dependencies](#dependencies)
         * [Test Plan](#test-plan)
         * [Upgrade / Downgrade Strategy](#upgrade--downgrade-strategy)
         * [Version Skew Strategy](#version-skew-strategy)
      * [Drawbacks [optional]](#drawbacks-optional)
      * [Alternatives [optional]](#alternatives-optional)
      * [References](#references)

<!-- Added by: stack, at: 2019-02-15T11:41-05:00 -->

<!--te-->

[Tools for generating]: https://github.com/ekalinin/github-markdown-toc

## Summary

Cloud-init templates offer a very powerful feature to render the configuration
at runtime based on metadata given by Ironic. We want to take advantage of this
feature to render node specific configuration for nodes in a machine deployment
or in a control plane kubeadm object dynamically, where this kind of objects
cannot be created beforehand. In addition, we want to be
able to generate node specific network configuration in CAPM3 based on a
template for nodes that are part of a machine deployment or or a control plane
provider object.

This design proposal introduces a new data template object that contains
templates for network data and metadata secret generation per node. Once
generated, the secrets are passed to Ironic for each node of a machine
deployment or control plane.

This proposal introduces a new `metaData` field in BareMetalHost and in
Metal3Machine, a new `networkData` field in
Metal3Machine and a new `dataTemplate` field in Metal3machine that allows
generating the metadata and network data secrets content.

## Motivation

When deploying a machine deployment or a control plane with CAPI (v1alpha3), the
KubeadmConfig applied is the same for all the nodes. However, we would want
control on some fields, such as the node name for example. This can be a
variable in the cloud-init template, but it needs to be provided through Ironic
as metadata. And the metadata needs to be different for each of the nodes. We
might also want some varying network configuration per node.
For example we would want the nodes of a machine deployment to have names like
`worker-np1-0`, `worker-np1-1`, `worker-np1-2` etc. and those names to be
unrelated with the BareMetalHost names (that might be `machine-xyz`, reflecting
some hardware related information, not Kubernetes node information).
Hence we want a way to generate a node-specific metadata and network data for a
machine deployment or Kubeadm Control Plane and pass it down to Ironic.

In addition, the network data might require static ip addresses configuration.
The controller must be able to provide a unique IP address. Hence the controller
should keep track of the index of the node to be able to render consistently ip
addresses.

### Goals

The goals are :

- to add a `metaData` field in BareMetalHost to have it configurable
  for Ironic, and in the Metal3Machine for CAPM3 to be able to pass it down to
  BareMetalHost.
- add a `networkData` field in Metal3Machine
- introduce new objects containing information to get the data per node,
  or generate it, and store the values in use to not duplicate them.
- The reconciliation of the Metal3Machine would use the data template object to
  properly fill the `metaData` and `networkData` field of BareMetalHost


### Non-Goals

- Implement a new DSL to render the data. All configuration should be done
  through API.

## Proposal

### User Stories [optional]

#### Story 1

As a user, I want to define a template for node-specific metadata to pass
through ironic to fill the cloud-init template. This template should be rendered
for each node, and be re-used during upgrade.

#### Story 2

As a user, I want to give my own metadata to Ironic as a field on
Metal3Machine and BareMetalHost.

#### Story 3

As a user, I want to define a template for node-specific networking to pass
through ironic to cloud-init. This template should be rendered for each node,
and be re-used during upgrade.

#### Story 4

As a user, I want to give my own network configuration for cloud-init as a field
on Metal3Machine

### Implementation Details/Notes/Constraints

- The metadata field should contain some required element, such as UUID, that is
  required by cloud-init.
- It must be possible to give metadata and network data secrets without using
  the data template object
- Not providing any data template object and any content in the `metaData` and
  `networkData` fields of Metal3Machine should result in the same behavior as
  before this proposal is implemented
- the data template would contain templates to generate both the metadata and/or
  the network data.
- Generating the metadata or the networkdata should work regardless whether the
  other template was provided.
- Documentation of this feature would be very important.
- The controllers must be able to recreate all status objects, i.e. no
  necessary information should be stored in the status without being recoverable

### Risks and Mitigations

From a user point of view, if this is not well documented or understood, it
could lead to unexpected errors or behaviors. The errors have to be easily
understandable.

## Design Details

### BareMetalHost changes

BareMetalHost would have an added field `metaData` in the `Spec` pointing to a
secret containing the metadata map. Bare Metal Operator would then pass this map
to Ironic.

Some values would be set by default to maintain compatibility:

- **uuid**: This is the BareMetalHost UID
- **metal3-namespace**: the name of the BareMetalHost
- **metal3-name**: The name of the BareMetalHost
- **local-hostname**: The name of the BareMetalHost
- **local_hostname**: The name of the BareMetalHost

However, setting any of those values in the metaData secret will override those
default values.

### Metal3Machine changes

The Metal3Machine will be modified as follow:

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3Machine
metadata:
  name: machine-1
  namespace: default
spec:
  dataTemplate:
    name: nodepool-1
    namespace: default
status:
  renderedData:
    name: nodepool-1-0
    namespace: default
  metaData:
    name: machine-1-metadata
    namespace: default
  networkData:
    name: machine-1-networkdata
    namespace: default
```

or alternatively

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3Machine
metadata:
  name: machine-1
  namespace: default
spec:
  metaData:
    name: machine-1-metadata
    namespace: default
  networkData:
    name: machine-1-networkData
    namespace: default
status:
  metaData:
    name: machine-1-metadata
    namespace: default
  networkData:
    name: machine-1-networkData
    namespace: default
```

A `metaData` field would be added in the spec and in the status, consisting of a
secret reference containing the name and the namespace of the secret containing
the metaData for this Metal3Machine. A `networkData` field would be added to the
spec and to the status objects, consisting of a secret
reference containing the name and the namespace of the secret containing the
network configuration for this Metal3Machine.

The secret containing the metaData or the network data could be provided by the
user directly using the `metaData` or `networkData` fields in the spec of the
Metal3Machine.

The `metaData` and `networkData` field in the `spec` section are for the user
to give directly a secret to use as metaData or networkData. The `userData`,
`metaData` and `networkData` fields in the `status` section are for the
controller to store the reference to the secret that is actually being used,
whether it is from one of the spec fields, or somehow generated. This is aimed
at making a clear difference between the desired state from the user (whether
it is with a DataTemplate reference, or direct `metaData` or `userData` secrets)
and what the controller is actually using.

A `dataTemplate` field would be added, consisting of an object reference
to a Metal3DataTemplate object containing the templates for
the metadata and network data generation for this Metal3Machine.
A `renderedData` field will be added in the status and will be a reference to
the Metal3Data object created for this machine. If the dataTemplate field is set
but either the `renderedData`, `metaData` or `networkData` fields in the status
are unset, then the Metal3Machine controller will wait until it can find the
Metal3Data object and the rendered secrets. It will then populate those fields.

When CAPM3 controller will set the different fields in the BareMetalHost,
it will reference the metadata secret and the network data secret
in the BareMetalHost. If any of the `metaData` or `networkData` status fields
are unset, that field will also remain unset on the BareMetalHost.

When the Metal3Machine gets deleted, the CAPM3 controller will remove its
ownerreference from the data template object. This will trigger the deletion of
the generated Metal3Data object and the secrets generated for this machine.

### The Metal3DataTemplate object

A new object would be created, a Metal3DataTemplate type.

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3DataTemplate
metadata:
  name: nodepool-1
  namespace: default
  ownerReferences:
  - apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
    controller: true
    kind: Metal3Cluster
    name: cluster-1
spec:
  metaData:
    - key: abc
      string: def
    - key: name_m3m
      objectName:
        object: metal3machine
    - key: name_machine
      objectName:
        object: machine
    - key: name_bmh
      objectName:
        object: baremetalhost
    - key: index
      index:
        offset: 0
        step: 1
    - key: ip
      ip:
        start: 192.168.0.10
        end: 192.168.0.100
        subnet: 192.168.0.0/24
        step: 1
    - key: mac
      fromHostInterface: "eth0"
  networkData:
    links:
      - ethernet:
          type: "phy"
          id: "enp1s0"
          mtu: 1500
          macAddress:
            fromHostInterface: "eth0"
      - ethernet:
          type: "phy"
          id: "enp2s0"
          mtu: 1500
          macAddress:
            fromHostInterface: "eth1"
      - bond:
          id: "bond0"
          mtu: 1500
          macAddress:
            string: "XX:XX:XX:XX:XX:XX"
          bondMode: "802.1ad"
          bondLinks:
            - enp1s0
            - enp2s0
      - vlan:
          id: "vlan1"
          mtu: 1500
          macAddress:
            string: "YY:YY:YY:YY:YY:YY"
          vlanId: 1
          vlanLink: bond0
    networks:
      - ipv4DHCP:
          id: "provisioning"
          link: "bond0"

      - ipv4:
          id: "Baremetal"
          link: "vlan1"
          ipAddress:
            start: "192.168.0.10"
            end: "192.168.0.100"
            subnet: "192.168.0.0/24"
            step: 1
          netmask: 24
          routes:
            - network: "0.0.0.0"
              netmask: 0
              gateway: "192.168.0.1"
              services:
                - type: "dns"
                  address: "8.8.4.4"
      - ipv6DHCP:
          id: "provisioning6"
          link: "bond0"
      - ipv6SLAAC:
          id: "provisioning6slaac"
          link: "bond0"
      - ipv6:
          id: "Baremetal6"
          link: "vlan1"
          ipAddress:
            start: "2001:0db8:85a3::8a2e:0370:a"
            end: "2001:0db8:85a3::8a2e:0370:fff0"
            subnet: "2001:0db8:85a3::8a2e:0370:0/64"
            step: 10
          netmask: 64
          routes:
            - network: "0::0"
              netmask: 0
              gateway: "2001:0db8:85a3::8a2e:0370:1"
              services:
                - dns: "2001:4860:4860::8844"
    services:
      - dns: "8.8.8.8"
      - dns: "2001:4860:4860::8888"
```

This object will be reconciled by its own controller. When reconciled,
the controller will add a label pointing to the Metal3Cluster that has nodes
linking to this object. The spec contains a `metaData` and a `networkData` field
that contain a template of the values that will be rendered for all nodes.

The `metaData` field will be rendered into a map of strings in yaml format,
while `networkData` will be rendered into a json string that fulfills the
requirements of
[Nova network_data.json](https://docs.openstack.org/nova/latest/user/metadata.html#openstack-format-metadata).
The format definition can be found
[here](https://docs.openstack.org/nova/latest/_downloads/9119ca7ac90aa2990e762c08baea3a36/network_data.json).

#### Metadata Specifications

The `metaData` field contains a list of items that will render data in different
ways. The following objects are available:

- **key**: This is compulsory and is the key used for the rendered value in
  the metadata map.
- **string**: renders the given string as value in the metadata
- **objectName** : renders the name of the object that matches the type given in
  the `object` field.
- **index**: renders the index of the current object, with the offset from the
  `offset` field and using the step from the `step` field. The following
  conditions must be matched :

    - `offset` >= 0
    - `step` >= 1

  if the step is unspecified (default value being 0), the controller will
  automatically change it for 1.
- **ip**: renders an ip address based on the index, based on the `start` value
  if given or using `subnet` to calculate the start value, and checking that
  the rendered value is not over the `end` value. The increment is the `step`
  value. If the computed value goes out of bounds, the error status will be set
  with the error in the error message.
- **fromHostInterface**: renders the MAC address of the BareMetalHost that
  matches the name given as value.

The **key** is required and one of the object is required. If there are multiple
objects, the priority order will apply as listed above.

#### networkData specifications

The `networkData` field will contain three items :

- **links**: a list of layer 2 interface
- **networks**: a list of layer 3 networks
- **services** : a list of services (DNS)

##### Links specifications

The object for the **links** section list can be one of:

- **ethernet**: an ethernet interface
- **bond**: a bond interface
- **vlan**: a vlan interface

The **links/ethernet** object contains the following:

- **type**: Type of the ethernet interface
- **id**: Interface name
- **mtu**: Interface MTU
- **macAddress**: an object to render the MAC Address

The **links/ethernet/type** can be one of :

- bridge
- dvs
- hw_veb
- hyperv
- ovs
- tap
- vhostuser
- vif
- phy

The **links/ethernet/macAddress** object can be one of:

- **string**: with the desired Mac given as a string
- **fromHostInterface**: with the interface name from BareMetalHost
  hardware details.

The **links/bond** object contains the following:

- **id**: Interface name
- **mtu**: Interface MTU
- **macAddress**: an object to render the MAC Address
- **bondMode**: The bond mode
- **bondLinks** : a list of links to use for the bond

The **links/bond/bondMode** can be one of :

- 802.1ad
- balance-rr
- active-backup
- balance-xor
- broadcast
- balance-tlb
- balance-alb

The **links/vlan** object contains the following:

- **id**: Interface name
- **mtu**: Interface MTU
- **macAddress**: an object to render the MAC Address
- **vlanId**: The vlan ID
- **vlanLink** : The link on which to create the vlan

##### The networks specifications

The object for the **networks** section list can be one of:

- **ipv4**: an ipv4 static allocation
- **ipv4DHCP**: an ipv4 DHCP based allocation
- **ipv6**: an ipv6 static allocation
- **ipv6DHCP**: an ipv6 DHCP based allocation
- **ipv6SLAAC**: an ipv6 SLAAC based allocation

The **networks/ipv4** object contains the following:

- **id**: the network name
- **link**: The name of the link to configure this network for
- **ipAddress**: the IP address object
- **netmask**: the netmask, in an integer format
- **routes**: the list of route objects

The **networks/ipv4/ipAddress** is an address object containing:

- **start**: the start IP address
- **end**: The end IP address
- **subnet**: The subnet in a CIDR notation "X.X.X.X/X"
- **step**: the step between IP addresses

If the **subnet** is specified, then **start** and **end** are not required and
reverse, if **start** and **end** are specified, then **subnet** is not required

The **networks/ipv4/routes** is a route object containing:

- **network**: the subnet to reach
- **netmask**: the mask of the subnet as integer
- **gateway**: the gateway to use
- **services**: a list of services object as defined later

The **networks/ipv4Dhcp** object contains the following:

- **id**: the network name
- **link**: The name of the link to configure this network for
- **routes**: the list of route objects

The **networks/ipv6** object contains the following:

- **id**: the network name
- **link**: The name of the link to configure this network for
- **ipAddress**: the IP address object
- **netmask**: the netmask, in an integer format
- **routes**: the list of route objects

The **networks/ipv6Dhcp** object contains the following:

- **id**: the network name
- **link**: The name of the link to configure this network for
- **routes**: the list of route objects

The **networks/ipv6Slaac** object contains the following:

- **id**: the network name
- **link**: The name of the link to configure this network for
- **routes**: the list of route objects

##### the services specifications

The object for the **services** section list can be one of:

- **dns**: a dns service with the ip address of a dns server

### The Metal3Data object

The output of the controller would be a Metal3Data object,one per node linking to the
Metal3DataTemplate object and the associated secrets

The Metal3Data object would be:

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
kind: Metal3Data
metadata:
  name: nodepool-1-0
  namespace: default
  ownerReferences:
  - apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
    controller: true
    kind: Metal3DataTemplate
    name: nodepool-1
spec:
  index: 0
  metaData:
    name: machine-1-metadata
    namespace: default
  networkData:
    name: machine-1-metadata
    namespace: default
  metal3Machine:
    name: machine-1
    namespace: default
status:
  ready: true
  error: false
  errorMessage: ""
```
The Metal3Data will contain the index of this node, and links to the secrets
generated and to the Metal3Machine using this Metal3Data object.

If the Metal3DataTemplate object is updated, the generated secrets will not be
updated, to allow for reprovisioning of the nodes in the exact same state as
they were initially provisioned. Hence, to do an update, it is necessary to do
a rolling upgrade of all nodes.

The reconciliation of the Metal3DataTemplate object will also be triggered by
changes on Metal3Machines. In the case that a Metal3Machine gets modified, if
the `dataTemplate` references a Metal3DataTemplate, that object will be reconciled.
There will be two cases:

- An already generated Metal3Data object exists with an ownerReference to this
  Metal3Machine. In that case, the reconciler will verify that the required
  secrets exist. If they do not, they will be created.
- if no secret exists with an ownerReference to this Metal3Machine, then the
  reconciler will create one and fill the respective field with the secret name.

To create a Metal3Data object, the Metal3DataTemplate controller will select an
index for that Metal3Machine. The selection happens by selecting the lowest
available index. The controller will list all existing Metal3Data object linked
to this Metal3DataTemplate and create a list of unavailable indexes. It will
fill it by extracting the index from the Metal3Data names. The indexes always
start from 0 and increment by 1. The lowest available index is to be used next.

Once the next lowest available index is found, it will create the Metal3Data
object. The name would be a concatenation of the Metal3DataTemplate name and
index. Upon conflict, it will fetch again the list to consider the new list of
Metal3Data and try to create the new object with the new index, this will happen
until the new object is created successfully. Upon success, it will render the
content values, and create the secrets containing the rendered data. The
controller will generate the content based on the `metaData` or `networkData`
field of the Metal3DataTemplate Specs.

Once the generation is successful, the status field `ready` will be set to True.
If any error happens during the rendering, an error message will be added.

### The generated secrets

The name of the secret will be made of a prefix and the index. The Metal3Machine
object name will be used as the prefix. A `-metadata-` or `-networkdata-` will
be added between the prefix and the index.

The generated secret will be similar to :

```yaml
apiVersion: v1
kind: Secret
type: infrastructure.cluster.k8s.io/secret
metadata:
  name: nodepool-1-metadata-0
  namespace: default
  ownerReferences:
  - apiVersion: infrastructure.cluster.x-k8s.io/v1alpha4
    controller: true
    kind: Metal3Machine
    name: machine-1
spec:
  metaData: |
    abc: def
    local-hostname: worker-np1-0
```

The secret will contain the generated data for the host. Once the
secret reference field on the Metal3Machine is set, the Metal3Machine controller
will proceed with the provisioning.

### Deployment flow

#### Manual secret creation

In the case where the Metal3Machine is created without a `dataTemplate` value,
if the `metaData` or `networkData` fields are set (one or both), the
Metal3Machine reconciler will fetch the secret, set the status field and
directly start the provisioning of the BareMetalHost using the secrets if given.
If one of the secrets does not exist, the controller will wait to start the
provisioning of the BareMetalHost until it exists.

#### Dynamic secret creation

In the case where the Metal3Machine is created with a `dataTemplate` value, the
Metal3Machine reconciler will fetch that object (or wait until it exists if it
does not exist yet) and add the Metal3Machine in the ownerReferences of the
Metal3DataTemplate.

The Metal3DataTemplate would then be reconciled, and its controller will create
an index for this Metal3Machine if it does not exist yet, and create a
Metal3Data object with the index and the Metal3Machine in the ownerReference.

The Metal3Data reconciler will then generate the secrets, based on the index,
the Metal3DataTemplate and the machine. Once created, it will set the status
field `ready` to True.

Once the metal3Data object is ready, the Metal3Machine controller will fetch
the secrets that have been created (one or both) and use them to start
provisioning the BareMetalHost.

#### Hybrid configuration

If the Metal3Machine object is created with a `dataTemplate` field set, but one
of the `metaData` or `networkData` is also set in the spec, this one will
override the template generation for this specific secret. i.e. if the user sets
the three fields, the controller will use the user input secret for both.

This means that some hybrid scenarios are supported, where the user can give
directly the `metaData` secret and let the controller render the `networkData`
secret through the Metal3DataTemplate object.

## Implementation structure

### Work Items

Here are the different steps :

- Add the metadata field in BareMetalHost (On-going)
- Add the metal3DataTemplate object
- Add the CAPM3 logic for the dataTemplate reconciler
- Modify the Metal3Machine reconciler to make use of the metadata and network
  data and set it on the BareMetalHost.
- update the documentation
- ensure that the tests are created / updated accordingly

### Dependencies

### Test Plan

This can be added to our e2e tests. The Metal3DataTemplate object would be
added as part of the deployment and cloud-config modified to add variables to
make use of it.

### Upgrade / Downgrade Strategy

If none of the new fields are set, the behavior will be identical to the current
way the components work. In order to take this feature in use, the users must
take the fields in use.

During an upgrade, nothing is required to be done to keep things working as they
were. In order to start using this feature, the user would need to create the
Metal3DataTemplate object, and then do a rolling upgrade to change the
Metal3Machines (or Metal3MachineTemplates), and the KubeadmConfigs (or
KubeadmConfigTemplates or KubeadmControlPlane).

### Version Skew Strategy

This will require that both CAPM3 and BMO support this feature.

## Drawbacks [optional]

Even though they can be set separately, this brings the metadata and network
data in the same object.

## Alternatives [optional]

It would be possible to duplicate the templates to separate metadata and network
data. But this would add complexity.

## References

[metadata PR in Bare Metal Operator](https://github.com/metal3-io/baremetal-operator/pull/448)
