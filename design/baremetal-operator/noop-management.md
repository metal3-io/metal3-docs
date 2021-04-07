<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Add support for Ironic noop management driver in metal3

## Status

implementable

## Summary

This design aims to provide the operator with a metal3 interface
to disable Ironic BIOS settings management for a specific baremetal node.
This feature is already available in Ironic for `IPMI` and `Redfish` drivers
and is implemented as `noop` `management_interface` for those drivers. Metal3
currently doesn't support this feature.

## Motivation

Ironic management interface features include (but are not limited to) making
changes to the boot order of a node which is being provisioned. In some
circumstances it is desired to disable this functionality and ensure that the
BIOS settings (and specifically the boot sequence) on the node do not change.

On certain hardware types, requesting PXE boot via the BMC gives different
results than expected. For example, PXE boot request may always result in boot
attempt on the first port of the on-board NIC only, independently of the boot
order defined by the operator who may wish to boot off a port on an add-on PCI
network card. If the hardware behaves in such a way, it may be better to have
a static boot order configuration, hence it is important to provide the
operators with such capability.

Another use case for this feature is a scenario where the operator wants to
deploy a certain BIOS configuration and ensure that it remains unchanged.
This may be imposed by a security policy, a need for a workaround to
a specific problem or perhaps another reason.

### Goals

Add an extra attribute to `IPMI` and `Redfish` BMC definitions allowing
creation of Ironic nodes with noop management interface through metal3.

### Non-Goals

- Managing the boot sequence of the node.
- Ensuring that the node correctly follows operator's configuration.

## Proposal

### User Stories

#### Story 1

As a user, I want to be able to statically configure boot sequence of a node:

- boot from local storage device first
- if this fails, boot from the desired network interface

So that I can control exactly which NIC and which port will be used for
network boot independently on how BMC network boot request works on
a particular machine.

#### Story 2

As a user, I want to have full control of BIOS settings in use, so that I can
ensure compliance with security requirements and/or ensure I use the exact
settings that suit my needs.

## Design Details

Add a new `NoopManagement` attribute to the definitions of BMCs which support
noop management interface. Similar changes will be required in the Custom
Resource Definition, `baremetalhost_types`, `make-bm-worker` and BMO
templates so that the request to create the node with `noop`
`management_interface` is passed to Ironic.

For example, the BareMetalHost CRD with this proposal implemented would gain
an optional `noop` field in the `bmc` section and would look like this:

```yaml
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: hostname
spec:
  online: true
  bmc:
    address: bmcAddress
    credentialsName: hostname-bmc-secret
    noop: true
```

A work-in-progress proposal can be found [here](https://github.com/rhjanders/baremetal-operator/tree/noop_mgmt)

Currently only `IPMI` and `Redfish` Ironic drivers support noop management
interface.

### Implementation Details/Notes/Constraints

- the fact that some BMCs support `NoopManagement` needs to be handled
  appropriately - perhaps through a new `SupportsNoopManagement` call
  to `AccessDetails`?
- this call could return true for `redfish://` and `ipmi://`

### Risks and Mitigations

If noop management interface is used and the operator wishes to remove the
deployment, he or she may need to take additional steps prior to un-deploying.

For example, overwriting the boot sector of the storage device that the node in
question is booting from will typically resolve this by making the statically
defined boot sequence can fall back from local storage to network boot.

### Work Items

- add `NoopManagement` attribute to `IPMI` and `RedFish` BMC types.
- identify what changes need to be made in the Installer to expose the new attribute.

### Dependencies

Changes to the OpenShift Installer may be required.

### Test Plan

TBA

### Upgrade / Downgrade Strategy

None

### Version Skew Strategy

None.

## Drawbacks

None.

## Alternatives

Two new BMC types  - `IPMINoop` and `RedFishNoop` - can be created as an alternative.

Work in progress [example](https://github.com/metal3-io/baremetal-operator/compare/master...rhjanders:noop_mgmt_2)

## References

In my experience as an operator, I've encountered cases where it was not
possible to successfully provision the nodes over the designated provisioning
network interface while relying on Ironic managing the boot sequence.

In a scenario where operator manually configured boot sequence as:

1) desired NIC,
2) local storage,

provisioning worked. However when provisioning was reliant
on sending a network boot command to the BMC (e.g. by using `ipmitool chassis
bootdev pxe` call), the node would disregard the NIC priority in the boot
sequence and always attempt boot from the first port of the first on-board
NIC even if it was intended to be left unused. This posed a problem where
the servers came with embedded 1G or 10G in addition to higher-bandwidth
NICs (40G/100G/200G) which the operator may want to use for all classes of
traffic (with provisioning network on the native VLAN and other classes of
traffic on other, tagged VLANs).

Sample BZs:

[efibootmgr has wrong BootOrder causing cluster expansions to timeout](https://bugzilla.redhat.com/show_bug.cgi?id=1767227)

[Add the noop management interface to RedFish Ironic driver](https://bugzilla.redhat.com/show_bug.cgi?id=1840087)

[\[RFE\] provide the ability to control if ironic sets boot order or not during provisioning](https://bugzilla.redhat.com/show_bug.cgi?id=1684988)
