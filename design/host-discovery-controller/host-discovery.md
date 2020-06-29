<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# host-discovery

## Status

implementable

## Summary

Ironic Inspector is capable of discovering new hosts. This should be
an optional capability of metal3. When we discover a new host, it
should result in automatically creating a corresponding
`BareMetalHost` resource.

## Motivation

There are several workflows for adding nodes to existing clusters that
would benefit from not forcing the user to register the hosts in
advance. Especially in large data centers, it may be desirable to
build a small cluster and then attach additional hosts to the
provisioning network and deploy them by simply powering them on and
using PXE to boot an agent that knows how to reach back to the
cluster.

### Goals

1. Describe how we can take advantage of Ironic’s existing discovery
   features to automatically add hosts to clusters.
2. Describe how the cluster can, and cannot, manage a host without BMC
   credentials.

### Non-Goals

1. Describe a way to set BMC credentials automatically for discovered
   hosts.
2. Attempt to make it possible to fully manage a host without BMC
   credentials.

## Proposal

### User Stories

#### Adding a host and automatically provisioning

*As a cluster admin, I want to add a node to a cluster without
pre-configuring the BMC and have the cluster automatically provision
the host as a node.*

Provisioning the hosts to make them nodes can take quite a while. It
would be nice to be able to start that process for a bunch of hosts,
then configure their BMC credentials later to enable full management
of the hosts. There are also situations where the BMC credentials
might never be added (proof-of-concept or test clusters that are never
going to be “production ready”).

By combining Ironic’s discovery feature, Ironic’s fast-track
provisioning feature, MachineSet scaling, and some new work in metal3
we should be able to make it possible for a user to:

1. Attach a host to the provisioning network
2. Power the host on
3. Have a `BareMetalHost` created with hardware inventory details
4. Optionally classify the host (using the
   `hardware-classification-controller`)
5. Automatically scale the appropriate MachineSet based on labels on
   the host
6. Automatically provision the host as a node in the cluster

#### Adding a host and not automatically provisioning

*As a cluster admin, I want to add a node to a cluster without
pre-configuring the BMC and NOT have the cluster automatically
provision the host as a node.*

This use case is different from the previous case because the
`MachineSet` would not scale automatically and so the host would not
be provisioned. This gives cluster admins an opportunity to review the
host before provisioning, to ensure that it should be a member of the
cluster and is not misconfigured (PXE booting from the wrong
environment) or a malicious actor.

#### Replacing a faulty node

*As a data center staff member, I want to replace a faulty node in a
cluster quickly.*

The idea here is to be able to take a “broken” host out of service and
replace it with a standby host without having access to the kubernetes
API or UI at all. If we assume the broken host is broken enough that
it is completely offline, it should be possible to remove it from the
rack and replace it with another physical host, which is then
provisioned automatically.

## Design Details

When Ironic is configured to support its existing discovery feature,
unknown hosts that boot the Ironic agent will have their hardware
details registered with `ironic-inspector` and have a node created in
the Ironic database. Typically this happens via the PXE boot
configuration, but in the future it could happen in other ways such as
having a bootable ISO image with the agent on it. How the agent ends
up on the host should not matter in the rest of the workflow.

The data collected for an unknown host includes the same inspection
data available for any other host, but does not include the BMC
credentials. We can use the data to partially create a `BareMetalHost`
resource for the host by polling the Ironic API to compare the list of
nodes it knows about with the list of host resources. A new
`host-discovery-controller` will manage this polling, using a new
`BareMetalHostDiscovery` API to control it.

The `BareMetalHostDiscovery` API will include a `resourceNameTemplate`
field to hold instructions for building a resource name for a new
node, including a prefix, suffix, and enum for selecting known
hardware details.

For a host with name `"the-host-name"`, this specification

```yaml
resourceNameTemplate:
  prefix: "string-literal1-"
  suffix: "-string-literal2"
  hardwareDetails: hostname
```

would produce a resource name
`"string-literal1-the-host-name-string-literal2"`.

The `hardwareDetails` field is required. The `prefix` and `suffix`
fields are ignored if not provided.

The `hardwareDetails` enum can be one of:

- `hostname` -- Using the discovered hostname for the host.
- `ip` -- The IP address of the first NIC for the host with `.`
  replaced by `-`.
- `serial-number` -- Using the hardware serial number for the host.
- `boot-mac` -- Using the boot MAC address of the host with `:`
  replaced by `-`.
- `provisioning-id` -- The identifier assigned by the underlying
  provisioning tool when the host was registered automatically.

Changing the a `BareMetalHostDiscovery` resource will have no effect
on previously discovered host resources.

For each host known to Ironic, the `host-discovery-controller` will
look for a `BareMetalHost` resource with the same `bootMACAddress`. If
any host resource is found matching the MAC, no further action will be
taken.

For any host known to Ironic but not represented by a `BareMetalHost`
resource, the `host-discovery-controller` will create a
`BareMetalHost` resource with the `bootMACAddress` filled in based on
the MAC of the first discovered NIC and using a name built from the
template values and with an annotation containing the hardware details
and provisioner ID that should be added to the status fields.

When a user adds BMC credentials to a host in the `Discovered` state
today it moves to `Registering` and the `Provisioner` is responsible
for configuring the host in Ironic. That logic may need to be modified
to support partial updates of existing nodes, to set the values that
were not not set when the node was discovered.

Because discovered hosts will already have hardware details, there is
no need to re-inspect them if they move out of the `Discovered`
state. The [state
machine](https://github.com/metal3-io/baremetal-operator/blob/master/docs/baremetalhost-states.md)
for the `baremetal-operator` will therefore need a new transition
between `Discovered` and `MatchProfile` when the condition
`!externallyProvisioned && !NeedsHardwareInspection()` is true. That
transition will bypass the `Inspecting` state and allow the host to
eventually move to the `Ready` state.

### Implementation Details/Notes/Constraints

The state management changes described above are likely to require
changes to the `Provisioner` API. The details of those changes will be
determined during implementation.

The changes to the state machine would not change the fact that many
of the metal3 features (fencing and power management) require BMC
credentials. Discovered hosts would not enter the states where those
features are allowed until BMC credentials are provided. The host
controller should skip trying to maintain the power state and should
not honor hard reboot requests for hosts without BMC credentials.

### Risks and Mitigations

If multiple `BareMetalHostDiscovery` resources exist, there may be
multiple attempts to create a host from discovered information by
different goroutines in the `host-discovery-controller`. If the name
template information is the same, the conflict will be caught. If the
name template information is different, then multiple hosts will be
created. Resolving this will require adding a webhook in the
`baremetal-operator` to be invoked when a resource is created and to
block duplicate hosts. See [the v1alpha2
migration](https://github.com/metal3-io/metal3-docs/pull/101) plans
for details related to allowing webhooks. In the future, we may add
rules to the `BareMetalHostDiscovery` API to control the naming
convention applied to hosts with different characteristics, but there
are no concrete plans to do so now.

Data on discovered hosts will be lost if automatic provisioning is
enabled. The feature is disabled by default, so the risk is mitigated
because users will be aware when it is turned on.

Ironic inspector creates discovered nodes with an `auto_discovered`
flag set in the introspection data. We could limit the polling in the
`baremetal-operator` to only look for hosts with the flag set. It
isn’t really clear how useful that would be, so the description above
does not assume such a limit.

Nodes are removed from Ironic when the host CR is deleted. A host may
be rediscovered if the data is deleted and the host is rebooted into
the Ironic agent image. This could cause confusion, if the users
intent was to remove the host completely. It could also be seen as a
feature, if it is considered a way to reprovision a host.

### Work Items

1. Create the new git repository for the controller and API and set up
   CI jobs.
2. Write the new controller
3. Update ironic-inspector-image to add unknown hosts using the `fake`
   driver instead of the `ipmi` driver so they can be provisioned
   without BMC credentials.
4. Update `IronicProvisioner` to allow it to update an existing node
   in Ironic so that discovered nodes will have their settings
   adjusted, as needed.
5. Update the state machine to add `Importing` state, and make the
   related changes to the `IronicProvisioner` API to allow it to look
   for inspection data without triggering the inspection process.
6. Update the state machine to support deleting hosts in the
   `Importing` state, including updating the enum for the host CRD to
   allow the new state.
7. Update `IronicProvisioner` so it will recognize a manually
   registered host that matches a discovered node in the Ironic
   database.
8. Document how to fully enable and disable the feature, including the
   fact that hosts need to be configured to boot from disk and only
   fall back to PXE if there is no image on the drive.
9. Extend the `DemoProvisioner` to support the new states.
10. Add a method to `BareMetalHost` to report whether power control
   operations are supported. For now, this will only look at whether
   there are BMC credentials.
11. Update the bare metal controller to skip trying to apply power
   state management operations to hosts that do not support them.

### Dependencies

[Ironic node discovery spec](https://specs.openstack.org/openstack/ironic-inspector-specs/specs/ironic-node-auto-discovery.html)

### Test Plan

Add unit tests for the new controller.

Add unit tests for the state transitions using the test provisioner.

Extend the integration test suite?

### Upgrade / Downgrade Strategy

Updating the host CRD to support the new state is a breaking
change. Downgrading a system with a host in the `Importing` state may
trigger failures in the `baremetal-operator` because it will not
recognize the new host state.

### Version Skew Strategy

N/A

## Drawbacks

N/A

## Alternatives

Instead of polling the Ironic API looking for new hosts, we could
watch the `dnsmasq` logs. However, in some configurations PXE may be
disabled or hosts may be booted in other ways even with PXE enabled,
so we would not see all discovered hosts.

Instead of polling the Ironic API we could add a feature to
ironic-inspector to invoke a callback when a new host is
discovered. This would be less compute intensive, but offers an
opportunity to "miss" the notification of a new host, and does not
provide an opportunity to configure the names for the new host
resources.

Instead of polling the Ironic API, we could use a notification plugin
to invoke a callback when a new host is discovered. This would be less
compute intensive, but offers an opportunity to "miss" the
notification of a new host, and does not provide an opportunity to
configure the names for the new host resources.

Instead of writing a new controller with a new API, we could add a
goroutine to the `baremetal-operator` to handle the polling. This does
not provide an opportunity to configure the names for the new host
resources.

Instead of writing a new controller in a new repository, we could add
a second controller to the `baremetal-operator` repository. This would
compound the API versioning problems we have with that repository,
making it more difficult for us to evolve the `BareMetalHostDiscovery`
API in the future. We should use kubebuilder to create a new
independent controller instead.

## References

- [early draft of this
  proposal](https://docs.google.com/document/d/1hlMSdim53CQtqlYOnx1ptq3qKHKhP9LhDrRxzCutGoM/edit)
- [baremetal-operator issue
  41](https://github.com/metal3-io/baremetal-operator/issues/41)
- [Ironic node discovery
  spec](https://specs.openstack.org/openstack/ironic-inspector-specs/specs/ironic-node-auto-discovery.html)
- [Ironic node discovery
  docs](https://specs.openstack.org/openstack/ironic-inspector-specs/specs/ironic-node-auto-discovery.html)
- [WIP changes for
  baremetal-operator](https://github.com/metal3-io/baremetal-operator/pull/545)
