# Firmware Updates

Metal3 supports updating firmware and retrieving the current firmware versions
of the bare metal hosts.
This feature can be used to update the system firmware (e.g. BIOS) or BMC
firmware.

Updating the firmware components is only supported for Redfish-based drivers
(see [supported hardware](./supported_hardware.md)).

## HostFirmwareComponents Resources

A `HostFirmwareComponents` resource can be created manually or automatically
for each host that supports firmware components with the same name and in the
same namespace as host.  BareMetal Operator puts the current components
information in the `status.components` field:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostFirmwareComponents
metadata:
  creationTimestamp: "2024-08-08T16:44:34Z"
  generation: 1
  name: worker-0
  namespace: my-cluster
  ownerReferences:
  - apiVersion: metal3.io/v1alpha1
    kind: BareMetalHost
    name: worker-0
    uid: bef07c46-0674-4c65-8613-d29920e207b1
  resourceVersion: "21527"
  uid: 1f9d5b76-5b17-44a1-84f8-7242daafc51d
spec:
  updates: []
status:
  components:
  - component: bios
    currentVersion: 2.3.5
    initialVersion: 2.3.5
  - component: bmc
    currentVersion: 6.10.30.00
    initialVersion: 6.10.30.00
  conditions:
  - lastTransitionTime: "2024-08-08T16:44:35Z"
    message: ""
    observedGeneration: 1
    reason: OK
    status: "True"
    type: Valid
  - lastTransitionTime: "2024-08-08T16:44:35Z"
    message: ""
    observedGeneration: 1
    reason: OK
    status: "False"
    type: ChangeDetected
  lastUpdated: "2024-08-08T16:44:35Z"
```

This example was taken from a real hardware and was automatically generated:

- The `spec.updates` list is empty - no change is requested by the user.

- The `status.updates` will only be present when `spec.updates` is not empty
  and an update was executed.

- The `status.components` information is populated with the current values
  detected by Ironic. If an update is executed, the updated information will
  be available when the host transitions from `available` state.

- The `Valid` condition is `True`, which means that `spec.updates` are valid,
  since it was automatically generated. We allow the `spec.updates` to be an
  empty list. The condition will be set to `False` if any value in
  `spec.updates` fails validation.

- The `ChangeDetected` condition is `False`, which means that the information
  provided in status matches the information from Ironic and from
  `spec.updates`. This condition will be set to `True` after you modify
  `spec.updates` until the change is reflected in `status.updates`.

**Warning:** The components in status are only updated on
enrollment and provisioning. We do not periodically retrieve
firmware versions unless an update is executed.

**Note:** When manually creating the `HostFirmwareComponent` resource,
the information for `status` and `metadata` will be updated during
`inspecting`.

## How to change firmware components

To change one or more components for a host, update the corresponding
`HostFirmwareComponents` resource, changing or adding the required components
to `spec.updates`. For example:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostFirmwareComponents
metadata:
  name: worker-0
  namespace: my-cluster
  # ...
spec:
  updates:
  - component: <bmc or bios>
    url: https://newfirmwareforcomponent/file
status:
  # ...
```

The firmware update for the components are only executed when the host is in
`preparing` state. When adding a new `BareMetalHost` and manually creating the
`HostFirmwareComponents` resource for it, you can specify the updates that
must occur for that host before it goes to `available`.

In case you have a host that is `provisioned`, and you would like to execute a
firmware update, you will need to edit the `HostFirmwareComponents` CR and
then trigger [deprovisioning](./provisioning.md) so it can go to `preparing`
to execute the updates.

The newer information about the firmware for the host will only be available
in the CRD after the host moves to `preparing`.

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostFirmwareComponents
metadata:
  name: worker-0
  namespace: my-cluster
  # ...
spec:
  updates:
  - component: <bmc or bios>
    url: https://newfirmwareforcomponent/file
status:
  # ...
  components:
  - component: bios
    currentVersion: 2.13.3
    initialVersion: 2.13.3
  - component: bmc
    currentVersion: 6.10.30.00
    initialVersion: 6.10.80.00
    lastVersionFlashed: 6.10.30.00
    updatedAt: "2024-08-06T16:54:16Z"
  # ...
```

A new update is applied when the URL for a component changes, not when
a version change is detected.

## See also

The functionality described here can be used either on newly provisioned nodes
(Day 1 operation, as described here) or on already provisioned nodes (Day 2
operation, utilizing [Live Updates / Servicing feature](./live_updates_servicing.md)).

The corresponding functionality in Ironic is called
[Firmware Updates][1].

[1]: https://docs.openstack.org/ironic/latest/admin/firmware-updates.html
