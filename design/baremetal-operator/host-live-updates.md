<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Live updates of hosts

## Status

One of: implementable

## Summary

This proposal enables baremetal-operator to conduct certain actions on already
provisioned BareMetalHosts.

## Motivation

Currently, all preparation actions, such as BIOS settings, hardware RAID
configuration and newly firmware updates, happen in the `preparing` state
before a host is provisioned. While it makes perfect sense for RAID, firmware
updates can normally happen for already provisioned hosts.

We already have a precedent of modifying running hosts: a `DataImage` can
be attached on reboot. This proposal extends the same to other actions,
including potential future ones. This new feature will be called *live updates*
throughout this document.

### Goals

- Firmware updates and BIOS settings changes are possible for already
  provisioned hosts.
- Operators can opt out of live updates using RBAC.

### Non-Goals

- Changing hardware RAID configuration.
- Covering data images in the same proposal (we may add them later).
- Supporting actions from inside the running operating system.
- Live updates without rebooting.

## Proposal

A new auxiliary CRD `HostUpdatePolicy` will define policies for different
actions (initially, firmware updates and firmware settings).
The defaults will match the current ones. A policy object will be matched to
a BMH by its name (similarly to other resources). RBAC can be used to prevent
a certain user from creating/changing policies.

### User Stories

#### Story 1

As a BareMetalHost user, I want to be able to update system firmware or change
firmware settings without de-provisioning my hosts.

#### Story 2

As a cluster operator, I want to control whether certain users can run live
updates on BareMetalHosts.

## Design Details

### Custom Resource Definitions

A new auxiliary CRD `HostUpdatePolicy` will be added with the following Go
definition (shortened):

```go
type HostUpdatePolicySpec struct {
    FirmwareSettings HostUpdatePolicyType
    FirmwareUpdates HostUpdatePolicyType
}
```

`HostUpdatePolicyType` is an enumeration with the following values:

- `onPreparing` (the default) - updates will only happen in the `preparing`
  state (no live updates).
- `onReboot` - updates will happen on the next reboot.

In all cases, detached hosts will need to be attached first. Hosts not in the
`provisioned` state will not be affected.

### New Operational Status

A new operational status `servicing` will be added to designate hosts that are
undergoing a live update. Once the update finishes, the operational status will
become `OK` or `error`.

### Example workflow

As an operator, I want to update firmware on my Kubernetes worker node. My
actions:

1. Mark the affected node as non-schedulable, drain the workloads from it.
1. Find the corresponding `HostFirmwareComponents` resource, edit it to put
   an HTTP link to the expected firmware image(s).
1. Edit the `BareMetalHost` resource to add the reboot annotations.
1. Wait for the host's `operationalStatus` field to first change to
   `servicing`, then back to `OK`.
1. Wait for the node's status to become `Ready` again.
1. Mark the node as schedulable.

### Implementation Details/Notes/Constraints

- The power management code for provisioned hosts will be updated with a logic
  to check servicing on each power on. If the policy allows servicing, and
  there is a change in the corresponding resources (`HostFirmwareSetting` etc),
  the [servicing](https://docs.openstack.org/ironic/latest/admin/servicing)
  operation will be invoked.

  Servicing is technically very similar to cleaning, but runs on already
  provisioned hosts. It reboots into the IPA ramdisk (if needed) and runs
  a sequence of requested steps. As with cleaning, BMO will be responsible for
  creating a list of steps to execute. Unlike cleaning, the end state of the
  host is provisioned and powered on.

  In case of firmware updates, Ironic downloads the requested images into the
  local HTTP server and provides links to them to the machine via Redfish. Then
  the machine is rebooted.

- Although the BMO's reboot annotation will be used as a trigger,
  the actual reboot will not be handled by BMO in this case. All reboots
  (at least two in most cases) will be orchestrated by Ironic in reality.
  BMO will simply remove the reboot annotation after triggering servicing.

- Draining hosts will not be handled by BMO. It will be entirely up to the user
  to ensure that the hosts can be updated.

  In case of a Kubernetes cluster, the workloads will need to be drained and
  the node cordoned before doing the reboot. After the host returns to the
  operational status `OK`, the node will need to be brought back into the
  cluster.

- The policy resources will have neither a status nor a controller.

### Risks and Mitigations

- Adding new operational status is potentially breaking for consumers that
  expect to always see `OK`. Since BMH API is still v1alpha1, it's probably
  acceptable. On the other hand, adding a new state would be too risky.

### Work Items

- Add new CRD to the API.
- Update gophercloud to a version supporting servicing.
- Implement a `Service` call in the provisioners (similarly to `Prepare`).
- Modify the power management code to enable servicing.
- Write an end-to-end test of changing firmware settings using the redfish
  emulator.

### Dependencies

- Modifying provisioned hosts relies on the Ironic servicing feature
  introduced in API version 1.87. It functions very similarly to cleaning
  but acts on nodes in the ``active`` state.

- GopherCloud support for servicing will be introduced in the next version
  after 2.0-beta3.

- Ironic will need to be extended to support firmware updates during servicing.

### Test Plan

- The redfish emulator supports changing BIOS settings. Thus, we can write
  an e2e test that exercises this feature.

### Upgrade / Downgrade Strategy

- The feature is completely opt-in.

### Version Skew Strategy

- Ironic API version 1.87 will be required for live updates to function. Live
  updates will be ignored without it.

## Drawbacks

- The implementation will complicate the BMO code quite significantly since
  we'll have to check the Ironic's state machine for already provisioned hosts
  and react to errors.

## Alternatives

- Recommend operators to use in-band firmware update / settings tooling. It may
  or may not exist for given hardware.

## References

[Proof of concept (without firmware
updates)](https://github.com/metal3-io/baremetal-operator/pull/1689)
