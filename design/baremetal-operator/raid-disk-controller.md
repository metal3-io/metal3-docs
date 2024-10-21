<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# raid-extension-for-physical-disks-and-controller

## Status

provisional

## Summary

This document provide a way to express the physical disks and controller sections
for the (hardware) RAID configuration of a baremetal host.

## Motivation

The user should be able to specify exactly which physical disks and RAID
controllers are to be used to construct the hardware RAID volume(s).

### Goals

The primary goal is to depict the physical disk and RAID controller names in
the baremetal-host `hardware-raid` section.

Afterwards, implementation of the same will be done within the
`baremetal-operator` by extending the `baremetal-host` specification.

### Non-Goals

- This specification does not deal with `software-raid` and extension for it.
- It does not attempt to cover any generic (vendor agnostic)  naming convention
  for disks or controllers.
- It does not cover testing for hardware from all the vendors. It will only be
  tested on Dell EMC hardware, and other vendors will have to test it on their
hardware.

## Proposal

The proposal is to allow specifying the physical disks and RAID controller
names in the hardware RAID section. For this purpose, new YAML attributes are
to added in the BareMetalHost spec, namely `physicalDisks` and `controller`.

In terms of the CRD, the current implementation of the RAID has the following
sections in it, for hardware RAID:

```yaml
spec:
  raid:
    hardwareRAIDVolumes:
      - sizeGibiBytes: 1000
        level: 1
        name: <volume-name>
        rotational: true
        numberOfPhysicalDisks: 2
```

We propose to add fields into the CRD, in the following manner:

```yaml
spec:
  raid:
    hardwareRAIDVolumes:
      - sizeGibiBytes: 1000
        level: 1
        name: <volume-1-name>
        rotational: true
        numberOfPhysicalDisks: 2
        physicalDisks:
          - <disk-1-name>
          - <disk-2-name>
        controller: <controller-1-name>
      - sizeGibiBytes: 2000
        level: 0
        name: <volume-2-name>
        rotational: false
        numberOfPhysicalDisks: 2
        physicalDisks:
          - <disk-3-name>
          - <disk-4-name>
        controller: <controller-2-name>
```

The disk and RAID controller names are vendor-specific. Examples disk names
include: "Disk.Bay.0:Enclosure.Internal.0-1:RAID.Slot.6-1",
"Disk.Bay.1:Enclosure.Internal.0-1:RAID.Slot.6-1". Example controller names
include: "RAID.Slot.5-1", "RAID.Slot.6-1".

### User Stories

The following user story appertains to the proposal in question:

#### Story 1

As an operator, I'd like to be able to specify the physical disks and/or RAID
controllers I want to use when defining my `hardware-raid` configuration, or
both.

## Design Details

- The CRD spec will have to be extended to add fields for `physicalDisks` and
  `controller` under the `hardware_raid` section.
- The provisioner will then be extended to process these fields.
- The provisioner will make Ironic API calls with the RAID configuration, as
  before, but including the physical disks and controller names this time (if
  specified by the user).
- The status field will mirror these fields after a successful configuration.
  This will provide the operator with information about the current RAID
  configuration.

Note: gophercloud already supports these new fields, no extension is required
there.

### Implementation Details/Notes/Constraints

- Two new fields: `Controller` and `PhysicalDisks` fields will be added to
  the `HardwareRAIDVolume` struct in baremetalhost_types.go.
- Two new fields: `Controller` and `PhysicalDisks` fields will be added to
  the `nodes.logicalDisk` struct being constructed in the
  `buildTargetHardwareRAIDCfg` function in pkg/provisioner/ironic/raid.go.
- A pointer to the `RAIDConfig` struct will be added to the
  `BareMetalHostStatus` field in baremetalhost_types.go.
- Unit test cases will be added for the `buildTargetHardwareRAIDCfg`
  function, in a function called `TestBuildTargetHardwareRAIDCfg` in
  pkg/provisioner/ironic/raid_test.go.

### Risks and Mitigations

Since we will be specifying physical disks to be used, care needs to be taken
to not accidentally erase media with sensitive data on them. It is very easy to
undesirably remove data from disks.

### Work Items

- Extend the BMH CRD spec and status, adding fields for `physicalDisks`and
  `controller` under the `hardware_raid` section.
- Extend the provisioner to process these fields.
- Ensure the provisioner adds the new fields to the Ironic API call made for
  raid configuration.
- Ensure the status field mirrors these fields after successful configuration.
- Unit testing of the above (See test plan below)

### Dependencies

- gophercloud; the dependency is satisfied. It has the functionality we need.
- ironic; the dependency is satisfied. It has the functionality we need.

### Test Plan

The code will be tested in a development environment with a stand-alone
deployment of the `baremetal-operator` and `ironic`.  A number of
deployments will be performed with various combinations of `physicalDisks`
and `controller` fields, and RAID levels; to test maximum possibilities.  The
RAID levels 0, 1, 5, 6, 1+0, 5+0 and 6+0 will be tested with the extended
parameters.

Unit testing will be performed to ensure that the physical disks and
controllers added to the BMH YAML RAID configuration are added correctly to the
`logicalDisks` field of the `nodes` object.

Testing will only be performed for `idrac-wsman`, since only that is
available at the moment. (i.e. with Dell EMC hardware). Other vendors will have
to test the code accordingly.

### Upgrade / Downgrade Strategy

The Ironic API changes that break backwards compatibility are going to require
changes to the provisioner logic to construct the API call accordingly. This is
highly unlikely and therefore upgrading should be fine.  The user interfacing
part (the API fields in the BMH) are not changing in any case. The upgrades to
the operator can be performed safely without breaking any functionality.

### Version Skew Strategy

None.

## Drawbacks

None.

## Alternatives

Rely on the current `hardware-raid` configuration which does not allow for
specifying physical disks and RAID controllers, but works well in use cases
where such a functionality is not desired.

## References

<!-- markdownlint-disable link-image-reference-definitions -->

[1]: (https://i.dell.com/sites/doccontent/shared-content/data-sheets/en/Documents/Dell-PowerEdge-Boot-Optimized-Storage-Solution.pdf)

[2]: (https://docs.openstack.org/ironic/latest/admin/raid.html)

<!-- markdownlint-enable link-image-reference-definitions -->
