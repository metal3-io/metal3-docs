<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# raid-extension-for-physical-disks-and-controller

## Status

provisional

## Summary

This document provides the naming convention adopted to express
``physical_disks`` and ``controller`` sections of a RAID configuration of
a baremetal-host. The aim is to provide a uniform way of representation for
hardware from various vendors, in a way that enhances operator experience.
It also proposes an implementation for the same.

## Motivation

Vendors have different ways of defining the names for their physical disks
and RAID controllers within Ironic. This leads to a complication for the
operator where user experience is affected. There needs to be a uniform
naming convention that abstracts this and increases convenience.

### Goals

The primary goal is to reach consensus on one naming convention to depict
disk and RAID controller names in the baremetal-host ``hardware-raid``
section.

Afterwards, implementation of the same will be done within the
``baremetal-operator`` by extending the ``baremetal-host`` specification.

### Non-Goals

This specification does not deal with ``software-raid`` and extension for it.

## Proposal

The crux of the proposal is the naming convention that is to be adopted
for interfacing with the user. Currently, we have the following options

### Controller Naming

For controllers that are installed specifically for the operating system,
for example the [BOSS Card](1) by DellEMC, they are almost always used with
two disks/drives in ``RAID-1``, and can be refered to as
``primary-controller``. Similar method can be adopted to address such
controllers by other vendors.

Other controllers that are installed in the server can be used in any order,
and thus can be named ``secondary-controller-x`` where x can be an integer
greater than or equal to 1, e-g ``secondary-controller-1``,
``secondary-controller-2`` and so on.

### Physical Disk/Drive Naming

With physical disks, the primary issue is disk enumeration. We can address
it this way:

- Start from the front bay, and count drives in the order that they are
  listed by vendors. For instance, vendors would list them as XXXXX-1-XXX,
  XXXXX-2-XXX and so on. We can use these 1 and 2 to specify ordering and
  provide a simpler naming convention as ``Disk-1``, ``Disk-2`` and so on.
- The drives inserted in the backplane can be counted _afterwards_ using
  the same convention.

This will provide the user with a simpler way of listing controllers
and disks and it should suffice for a significant majority of use-cases.

### User Stories

The following user stories appertain to the proposal in question

#### Story 1

As an operator, I should be able to focus on defining my RAID configurations
without having to deal with intricacies of individual vendor's naming
conventions.

#### Story 2

As an operator, I'd like to be able to specify the physical disks I want
to use for my RAID configuration. Or, in case of multiple controllers, I
should be able to choose from them in defining my ``hardware-raid``
configuration, or both.

## Design Details

- The CRD spec will have to be extended to add fields for ``physical_disks``
  and ``controller`` under the ``hardware_raid`` section.
- The provisioner will then be extended to process these fields.
- There needs to be a map to transform user-interfacing names to the
  vendor-specific names (like in case of ``firmware`` config).
- The provisioner logic will perform lookups, and make Ironic API calls
  accordingly.
- The status field will mirror these fields after successful configuration.
  This is to provide the operator with the information regarding current config.

Note: gophercloud already supports these new fields, no extension is required
there.

In terms of the CRD, the current implementation of the RAID has the following
sections in it, for hardware RAID:

```yaml
spec:
  raid:
    hardwareRAIDVolumes:
      - sizeGibiBytes: 1000
        level: 1
        name: volume-name
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
        name: volume-1
        rotational: true
        numberOfPhysicalDisks: 2
        physicalDisks:
          - diskName: Disk-1
          - diskName: Disk-2
        controller: primary-controller
      - sizeGibiBytes: 2000
        level: 0
        name: volume-2
        rotational: false
        numberOfPhysicalDisks: 2
        physicalDisks:
          - diskName: Disk-3
          - diskName: Disk-4
        controller: secondary-controller-2
```

### Implementation Details/Notes/Constraints

The CRD will be extended to add fields to ``spec`` and ``status`` sections.
A map will be created in ``raid.go`` which will map user interfacing names
to the vendor-specific names.
The current RAID API call logic will be appended to process these new fields
and populate them in the ``target_configuration`` structure.
Other vendors will have to extend the provisioner logic accordingly.

### Risks and Mitigations

Since we will be specifying physical disks to be used, care needs to be taken
to not accidently erase media with sensitive data on them. It is very easy
to undesirably remove data from disks.

### Work Items

- Extend the CRD with agreed naming convention.
- Implement provisioner logic to process those fields to make Ironic API
  calls.
- Testing of the code (see test plan below).

### Dependencies

- gophercloud; the dependency is satisfied. It has the functionality we need.
- ironic; the dependency is satisfied. It has the functionality we need.

### Test Plan

The code will be tested in a development environment with a
stand-alone deployment of the ``baremetal-operator`` and ``ironic``.
A number of deployments will be performed with various combinations of
``physical_disks`` and ``controller`` fields to exercise complete capability.

Testing will only be performed for ``idrac-wsman``, since that is the only
availability at the moment. That is to say, with DellEMC hardware.

Other vendors will have to test the code accordingly.

### Upgrade / Downgrade Strategy

The Ironic API changes that break backwards compatibility are going to require
changes to the provisioner logic to construct the API call accordingly. This
is highly unlikely and therefore upgrading should be fine.
The user interfacing part (the API fields in the BMH) are not changing in any
case. The upgrades to the operator can be performed safely without breaking
any functionality.

### Version Skew Strategy

None.

## Drawbacks

None.

## Alternatives

Rely on the current ``hardware-raid`` configuration which does not allow
for specifying physical disks and RAID controllers, but works well in
use cases where such a functionality is not desired.

## References

[1]: (https://i.dell.com/sites/doccontent/shared-content/data-sheets/en/Documents/Dell-PowerEdge-Boot-Optimized-Storage-Solution.pdf)

[2]: (https://docs.openstack.org/ironic/latest/admin/raid.html)
