<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Update Firmware of BMHs

## Status

implementable

## Summary

This design document describes a Metal3 API for using the Firmware Interface
feature added to Ironic, this will allow updates of firmware of bmc and bios
in BMH that are compatible with Redfish.

## Motivation

When provisioning new machines to clusters, it may be necessary to upgrade
or downgrade the servers BIOS and firmware to specific versions to ensure
the server is configured as it is in their validated pattern.

Redfish has a common API that allow users to execute a firmware update, the
[proposal](https://specs.openstack.org/openstack/ironic-specs/priorities/2023-2-workitems.html#firmware-updates)
was accepted in the Ironic community, and is already implemented.

### Goals

This proposal does not attempt to fulfill the following goals:

- Allow firmware updates for the BMC and BIOS in hardware only compatible
  with Redfish.

### Non-Goals

- Update firmware using non Redfish means
- Update firmware that are not for BMC and BIOS

## Proposal

### User Stories

#### Story 1

As an operator I want to install specific versions of firmware in my
machines before installing the Operating System.

## Design Details

This proposes a new Custom Resource Definition (CRD) to store the information
about the firmware components from Ironic. The initial version stores only
the firmware information about BMC and BIOS, we may expand this to other
components in the future.
The new CRD is named `HostFirmwareComponents` and will consist of the
following:

- `components` - the current firmware components and their information,
  retrieved from Ironic via the [Firmware API](https://docs.openstack.org/api-ref/baremetal/#node-firmware-nodes)
  will be stored in the `Status` section.
- `updates` - firmware components to be updated via Ironic will be
  stored in the `Spec` section. It will be empty when the CRD is created.

The firmware components are retrieved from the BMC by Ironic and cached
whenever the node moves to `manageable` or `cleaning`, or when the components
are updated. The BMO manages the data as follows:

- The node first transitions to manageable during the `Registering` state, so
  at the end of that state `components` will be populated.
- Firmware components can be updated during the `Preparing` state, so at the
  end of that state the components will also be retrieved and used to update
  `components`.

A user can  update `updates` to specify the desired firmware of each
component. The BMO will detect changes on it by comparing the name/url pairs
to the values in `Status`. When a change is detected, the BMO will add the
new values to the Ironic clean-steps API in the Preparing state, when building
the manual clean steps, the Host will re-enter this state from Ready/Available
state whenever its config differs from the last stored one.

After executing the cleaning, Ironic will re-read the information about the
firmware components and cache them, the new information can be retrieved by
the BMO and used to update `components`.

If the update fails we won’t keep trying to reconcile, the BMO will put the
node in a `FirmwareUpdateError` state. We will allow deletion of the BMH when
in this state. When in `FirmwareUpdateError` state the following actions can
be executed:

- BMH can be moved to `Preparing` state again, this can be done by deleting
  `updates` from the `spec` in the CRD, or changing the urls in it. This will
  trigger another manual cleaning.
- BMH can be moved to `Deleting` state.

### Implementation Details/Notes/Constraints

Each Host should have their own `HostFirmwareComponents` CRD.

An example of the resource before applying:

```yaml
---
apiVersion: metal3.io/v1alpha1
kind: HostFirmwareComponents
metadata:
  namespace: host3firmwarecomponents.metal3.io
spec:
  updates:
  - name: bios
    url: https://myurl.with.firmware.for.bios
  - name: bmc
    url: https://myurl.with.firmware.for.bmc
status:
  components:
  - component: bios
    initialVersion: "v1.0.0"
    currentVersion: "v1.0.0"
    lastVersionFlashed: null
    updatedAt: null
  - component: bmc
    initialVersion: "v1.0.5"
    currentVersion: "v1.0.5"
    lastVersionFlashed: null
    updatedAt: null
  lastUpdated: "2023-10-13T13:34:06Z"
```

Example of the Resource after applied:

```yaml
---
apiVersion: metal3.io/v1alpha1
kind: HostFirmwareComponents
metadata:
  namespace: host3firmwarecomponents.metal3.io
spec:
  updates:
  - name: bios
    url: https://myurl.with.firmware.for.bios
  - name: bmc
    url: https://myurl.with.firmware.for.bmc
status:
  components:
  - component: bios
    initialVersion: "v1.0.0"
    currentVersion: "v1.5.0"
    lastVersionFlashed: "v1.5.0"
    updatedAt: "2023-10-13T13:50:06Z"
  - component: bmc
    initialVersion: "v1.0.5"
    currentVersion: "v1.2.0"
    lastVersionFlashed: "v1.2.0"
    updatedAt: "2023-10-13T13:50:06Z"
  updates:
  - name: bios
    url: https://myurl.with.firmware.for.bios
  - name: bmc
    url: https://myurl.with.firmware.for.bmc
  lastUpdated: "2023-10-13T13:50:06Z"
```

#### Fields Description

- `component`: the name of the firmware component
- `initialVersion`: the initial firmware version of the component, Ironic
  retrieves this information when creating the BMH and it can't be changed.
- `currentVersion`: the current firmware version of the component, initially
  the value will match the one in `initialVersion`, unless there was a
  firmware update for the BMH.
- `lastVersionFlashed`: the last firmware version of the component that was
  flashed in the BMH, this field will only have a value when a firmware update
  is executed.
- `updatedAt`: when the firmware component information was updated by Ironic.

### Risks and Mitigations

- In case of failure when executing the firmware update, BMO will put the BMH
  in a failed state.
- New firmware may have fixed a few bugs, but it can also introduce new ones.
  We will try to mitigate this by providing some versions of tested firmware
  when possible.

### Work Items

BMO

- Add new CRD for `HostFirmwareComponents`
- Get the firmware information from Ironic API at the end of the Registration
  state and store all the information in the `components`
- Check for changes to `updates` and when detected, call manual cleaning

### Dependencies

- Ironic (support already exists)
- Gophercloud (support already exists)

### Test Plan

- Test on running cluster
- Verify that updates can be executed on two type of hardware that supports
  Redfish.
- Verify that the information about the desired version is available after
  cleaning.
- e2e tests for firmware updates via sushy-tools.

### Upgrade / Downgrade Strategy

Not required as this is a new API being introduced

### Version Skew Strategy

None

## Drawbacks

Recovering from a failure may be quite difficult, at least through Metal3 means only.

## Alternatives

Operators can do the updates manually.

## References

- [Firmware Interface](https://review.opendev.org/c/openstack/ironic-specs/+/878505)
- [Firmware Interface API reference](https://docs.openstack.org/api-ref/baremetal/#node-firmware-nodes)
- [Gophercloud Support](https://github.com/gophercloud/gophercloud/pull/2795)
- [Metal3 Ironic Image](https://github.com/metal3-io/ironic-image/pull/438)
