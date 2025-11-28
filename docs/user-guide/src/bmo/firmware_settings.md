# Firmware Settings

<!-- cSpell:ignore sriov -->

Metal3 supports modifying firmware settings of the hosts before provisioning
them. This feature can be used, for example, to enable or disable CPU
virtualization extensions, huge pages or SRIOV support. The corresponding
functionality in Ironic is called [BIOS
settings](https://docs.openstack.org/ironic/latest/admin/bios.html).

Reading and modifying firmware settings is only supported for drivers based on
Redfish, iRMC or iLO (see [supported hardware](./supported_hardware.md)). The
commonly used IPMI driver does not support this feature.

## HostFirmwareSettings Resources

A `HostFirmwareSettings` resource is automatically created for each host that
supports firmware settings with the same name and in the same namespace as
host.  BareMetal Operator puts the current settings in the `status.settings`
field:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostFirmwareSettings
metadata:
  creationTimestamp: "2024-05-28T16:31:06Z"
  generation: 1
  name: worker-0
  namespace: my-cluster
  ownerReferences:
  - apiVersion: metal3.io/v1alpha1
    blockOwnerDeletion: true
    controller: true
    kind: BareMetalHost
    name: worker-0
    uid: 663a1453-d4d8-43a3-b459-64ea94d1435f
  resourceVersion: "20653"
  uid: 46fc9ccb-0717-4ced-93aa-babbe1a8cd5b
spec:
  settings: {}
status:
  conditions:
  - lastTransitionTime: "2024-05-28T16:31:06Z"
    message: ""
    observedGeneration: 1
    reason: Success
    status: "True"
    type: Valid
  - lastTransitionTime: "2024-05-28T16:31:06Z"
    message: ""
    observedGeneration: 1
    reason: Success
    status: "False"
    type: ChangeDetected
  lastUpdated: "2024-05-28T16:31:06Z"
  schema:
    name: schema-f229959d
    namespace: my-cluster
  settings:
    BootMode: Uefi
    EmbeddedSata: Raid
    L2Cache: 10x256 KB
    NicBoot1: NetworkBoot
    NumCores: "10"
    ProcTurboMode: Enabled
    QuietBoot: "true"
    SecureBootStatus: Enabled
    SerialNumber: QPX12345
```

In this example (taken from a virtual testing environment):

- The `spec.settings` mapping is empty - no change is requested by the user.

- The `status.settings` mapping is populated with the current values detected
  by Ironic.

- The `Valid` condition is `True`, which means that `spec.settings` are valid
  according to the host's `FirmwareSchema`. The condition will be set to
  `False` if any value in `spec.settings` fails validation.

- The `ChangeDetected` condition is `False`, which means that the desired
  settings and the real settings do not diverge. This condition will be set
  to `True` after you modify `spec.settings` until the change is reflected
  in `status.settings`.

- The `schema` field contains a link to the firmware schema (see below).

**Warning:** Ironic does not constantly update the current settings to avoid an
unnecessary load on the host's BMC. The current settings are updated on
enrollment, provisioning and deprovisioning only.

## FirmwareSchema resources

One or more `FirmwareSchema` resources are created for hosts that support
firmware settings. Each schema object represents a list of possible settings
and limits on their values.

```yaml
apiVersion: metal3.io/v1alpha1
kind: FirmwareSchema
metadata:
  creationTimestamp: "2024-05-28T16:31:06Z"
  generation: 1
  name: schema-f229959d
  namespace: my-cluster
  ownerReferences:
  - apiVersion: metal3.io/v1alpha1
    kind: HostFirmwareSettings
    name: worker-1
    uid: bd97a81c-c736-4a6d-aee5-32dccb26e366
  - apiVersion: metal3.io/v1alpha1
    kind: HostFirmwareSettings
    name: worker-0
    uid: d8fb3c8a-395e-4c0a-9171-5928a68305b3
spec:
  hardwareModel: KVM (8.6.0)
  hardwareVendor: Red Hat
  schema:
    BootMode:
      allowable_values:
      - Bios
      - Uefi
      attribute_type: Enumeration
      read_only: false
    NumCores:
      attribute_type: Integer
      lower_bound: 10
      read_only: true
      unique: false
      upper_bound: 20
    QuietBoot:
      attribute_type: Boolean
      read_only: false
      unique: false
```

The following fields are included for each setting:

- `attribute_type` -- The type of the setting (`Enumeration`, `Integer`,
  `String`, `Boolean`, or `Password`).
- `read_only` -- The setting is read-only and cannot be modified.
- `unique` -- The setting's value is unique in this host (e.g. serial numbers).

For type `Enumeration`:

- `allowable_values` -- A list of allowable values.

For type `Integer`:

- `lower_bound` -- The lowest allowed integer value.
- `upper_bound` -- The highest allowed integer value.

For type `String`:

- `min_length` -- The minimum length that the string value can have.
- `max_length` -- The maximum length that the string value can have.

**Note:** the `FirmwareSchema` has a unique identifier derived from its
settings and limits. Multiple hosts may therefore have the same
`FirmwareSchema` identifier so its likely that more than one
`HostFirmwareSettings` reference the same `FirmwareSchema` when hardware of the
same vendor and model are used.

## How to change firmware settings

To change one or more settings for a host, update the corresponding
`HostFirmwareSettings` resource, changing or adding the required settings to
`spec.settings`. For example:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostFirmwareSettings
metadata:
  name: worker-0
  namespace: my-cluster
  # ...
spec:
  settings:
    QuietBoot: true
status:
  # ...
```

**Hint:** you don't need to copy over the settings you don't want to change.

If the host is in the `available` state, it will be moved to the `preparing`
state and the new settings will be applied. After some time, the host will move
back to `available`, and the resulting changes will be reflected in the
`status` of the `HostFirmwareSettings` object. Applying firmware settings
requires 1-2 reboots of the machine and thus may take 5-20 minutes.

**Warning:** if the host is not in the `available` state, the settings will be
pending until it gets to this state (e.g. as a result of deprovisioning).

Alternatively, you can create a `HostFirmwareSettings` object together with
the `BareMetalHost` object. In this case, the settings will be applied after
inspection is finished.

## See also

The functionality described here can be used either on newly provisioned nodes
(Day 1 operation, as described here) or on already provisioned nodes (Day 2
operation, utilizing [Live Updates / Servicing feature](./live_updates_servicing.md)).
