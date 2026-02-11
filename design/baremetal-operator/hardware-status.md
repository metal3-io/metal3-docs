<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# hardware-status

<!-- cSpell:ignore smartmontools -->

## Status

provisional

## Summary

This document explains how information about hardware components (drives, power
supplies, fans, etc.) including health data, will be retrieved, collected and
monitored to provide constant up-to-date status on hardware devices present in
a server.
The base idea behind this is having a service running in each active host that
will regularly collect the data and post it to ironic-inspector, from where it
can be consumed as part of the regular polling for status.

## Motivation

We need to be able to collect and update enough information about hardware
devices in a server to monitor their status and identify them for
maintenance and replacement.
Valuable information are for example the current status, type, serial number,
physical location, part number.
We need to be able to refresh the information about the status of the hardware
devices and, if a device has been replaced, we need to be able to retrieve the
new information and update the hardware inventory to provide a constant
up-to-date vision on the status of the devices.

### Goals

1. Decide which information on the devices to retrieve.
1. Agree on how to retrieve such information.
1. Provide a way to manually/automatically collect and update the
   devices information.

### Non-Goals

1. Any update on device data should not trigger any reaction from ironic.

## Proposal

### Implementation Details/Notes/Constraints

- Depending on the device, we need to collect the following
  information, when applicable:
   - Capacity
   - Location
   - Manufacturer
   - Model
   - Part Number
   - Serial Number
   - Status
   - SMART details

- NVMe drives require special tools to get SMART data (e.g. nvme-cli),
  although
  [smartmontools](https://www.smartmontools.org/wiki/NVMe_Support)
  supports NVMe devices since version 6.5.

- [Hdparm](https://en.wikipedia.org/wiki/Hdparm) can provide SMART
  data for most of drives. It doesn't work with NVMe devices.

- [python-hardware](https://github.com/redhat-cip/hardware) can
  collect SMART data, although it requires code changes to detect and
  provide info on NVMe devices, for example relying directly on nvme
  tools instead of smartmontools.

- [Ironic Python Agent
  (IPA)](https://github.com/openstack/ironic-python-agent) is already
  able to collect most of this information.  Using a subset of the IPA
  code running inside a container in the hosts where we want to
  collect the drives data from can also allow to provide periodic
  updates on all the required info.  The container may require
  privileged permissions to be able to access and collect all the
  needed information.  The new containerized service will talk to
  Ironic Inspector.

- [Ironic
  Inspector](https://docs.openstack.org/ironic-inspector/latest/)
  needs to be able to publish up-to-date data at any time, including
  from active and available nodes.  This feature requires changes in
  the inspector code that currently accept data updates only from
  nodes in manageable state.

### Risks and Mitigations

1. Upstream Ironic community may reject changes in Ironic Inspector code.

## Design Details

### Work Items

- Add option to detect and provide info on NVMe drives to python-hardware.
- Extract and modify part of the IPA code to be able to run it in a
  container as a new service.
- Modify Ironic Inspector code to accept data from active nodes.
- Package (containerize) the new service based on IPA and the
  necessary tools, specifically for NVMe compatibility.
- Distribute the new service to the hosts.  This point requires to
  take decisions on different operations and might need a separate
  discussion on possible approaches, and includes at least the
  following aspects:
   - Ensure correct deployment of the new service to all the members of a
    cluster.
   - Correct configuration of the service, that needs to be aware of the
    ironic inspector api.
   - Verify the service is correctly running and regularly reporting up-to-date
    data to ironic inspector.

  One possible approach would be building a new element (as part of
  this or a different design) that is able to both coordinate
  deployment and configuration using current components, such as the
  baremetal-operator.

### Dependencies

- python-hardware
- SMART tools
- NVMe utils

### Test Plan

TBD

### Upgrade / Downgrade Strategy

N/A

### Version Skew Strategy

N/A

## References

- [Ironic Python Agent Documentation](https://docs.openstack.org/ironic-python-agent/latest/)

- [Ironic Inspector Documentation](https://docs.openstack.org/ironic-inspector/latest/)
