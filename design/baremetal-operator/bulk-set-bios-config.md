<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# bulk-set-bios-config

## Status

implementable

## Summary

Provide the ability to get and set the BIOS Configuration. Retrieve the current
BIOS Configuration settings from the host via Ironic and use that as a template.
Allow a user to set new values for the BIOS Configuration. Validate the values
before sending to Ironic via the clean-steps API. The values from the CRD on
one host can be manually copied to other hosts of the same vendor and model,
effectively doing a `bulk set`.

## Motivation

When provisioning a large amount of machines with identical settings, our
customers want to provide a known, validated payload with all the desired BIOS
configuration. This ensures all the machines will have the identical settings,
reducing issues caused by unexpected configuration differences.

The challenge that BIOS configuration presents is that no two hardware vendors
use the same names for settings that control the same behavior, and the
available settings often overlap but have significant differences. There
currently is an approach that would abstract these differences for individual
vendors where the common names are converted to vendor names by the BMC driver
[individual set](https://github.com/metal3-io/baremetal-operator/pull/302).
This new proposal would not require BareMetalHost to map the vendor specific
names to a common set of names to manage the settings. It will be entirely
transparent and inherently support all vendors. This new proposal could also
work in conjunction with the individual settings approach. A user could
initially set up a machine using that method and then copy the configuration
to multiple machines as described here.

Most hardware vendors support a way to apply bulk settings, often by manually
configuring one host, exporting those settings in a vendor-specific file
format, and then importing that file on the BMCs of other hosts. Accepting that
the format for these profiles is vendor-specific eliminates a lot of the
implementation complexity, at the risk of moving that complexity to the
end-user. This requirement is similar to something Dell has proposed in the
Ironic community
([hw config](https://review.opendev.org/c/openstack/ironic-specs/+/740721))
to export and import an entire system iDRAC inventory including RAID and
networking requirements. Compared to that approach, this proposal attempts
a more lightweight approach just for BIOS configuration.

### Goals

- Allow updating BIOS configuration using the vendor's BIOS names and not
  require a mapping layer to a common set of names
- Create a template for the current BIOS configurations settings cached on a
  server
- Give access to the BIOS registry which can be used as documentation so a
  user can easily update the BIOS settings to desired values
- Validate the BIOS Configuration values based on the vendor's BIOS Registry
  before sending to the BMC
- Provide ability to manually transfer the settings in a bulk manner across
  similar hardware in the cluster using `kubectl` commands. Its possible to
  use scripts to help automate this `bulk set`

### Non-Goals

This proposal does not attempt to fulfill the following goals:

- Allow the transfer of BIOS configuration between different vendor’s
  servers or different vendor models
- Support bulk set of other configurations besides BIOS
- Provide storage mechanism for BIOS settings
- Keep the BIOS settings on similar hardware in sync automatically
  using an additional operator, although that functionality is planned
  for a follow-on
- A future feature is planned to make use of this funtionality to
  automatically keep BIOS settings in sync on similar hardware using
  a new operator. This future will require a separate proposal and is out
  of scope for this proposal.

## Proposal

### User Stories

#### Story 1

When provisioning a large amount of machines with identical settings, our
customers want to provide a known, validated payload with all the desired
firmware configuration.

This ensures all the machines will have the identical settings, reducing issues
caused by unexpected configuration differences.

Since the name/value pair mapping is vendor specific and not intuitive, it
doesn’t lend itself to creating the input by hand using existing vendor
documentation, except for potentially a small subset of names. It’s desirable
to take an existing BIOS config set and modify the current settings to the
desired settings. The BIOS Registry can be used as a source of documentation
to modify the settings.

## Design Details

This proposes a new Custom Resource Definition (CRD) to store the settings
read from Ironic along with the modified settings to write to Ironic. Since
each vendor provides 100 or more BIOS Settings, its not practical to store
these in the BareMetalHost CRD. The new CRD will be named
`HostFirmwareSettings` and will consist of the following:

- `settingsData` - the current BIOS Settings (names and values) retrieved
  from Ironic via the BIOS API (`v1/nodes/{node_ident}/bios?detail=True`)
  [BIOS API](https://docs.openstack.org/api-ref/baremetal/?expanded=#node-bios-nodes)
  will be stored in the Status section along with the BIOS Registry
  information which provides a schema for the settings.
- `vendorSettings` - BIOS Settings to write to the host via Ironic will be
  stored in the Spec section. It will be initially populated with the
  name/value pairs from `settingsData` that do not have the `read-only` or
  `unique` schema flag set. Existing values will not be overwritten.

A second CRD `FirmwareSchema` will be added to store schema data (aka BIOS
Registry) received from Ironic via the BIOS API. This schema provides
additional info about each BIOS setting along with limits that can be used
both by a user when changing the settings or as a part of input validation.
The BIOS Registry support was recently added to Ironic (see the Ironic proposal
[BIOS Registry](https://review.opendev.org/c/openstack/ironic-specs/+/774681).
This schema is the same for each vendor's model so it will not need to be
updated when stored. More info for the BIOS registry data can be found in the
[Redfish Registry](https://redfish.dmtf.org/schemas/v1/AttributeRegistry.v1_3_5.json)

The schema fields returned via the BIOS API include:

- Type (e.g. enum, string, integer, boolean, or password)
- ReadOnly (a boolean indicating whether the attribute is read only)
- Unique (indicating the value is specific to the host where it was
  retrieved)
- Allowable values for enum type attributes
- Minimum and maximum values (for numeric attributes)
- Minimum and maximum character lengths (for string attributes)

The BIOS Settings are retrieved from the BMC by Ironic and cached
whenever the node moves to `manageable` or `cleaning`, or when the settings
are updated. The baremetal-operator will manage the data as follows:

- The node first transitions to manageable during the `Registering` state, so
  at the end of that state `settingsData` will be populated.
- Settings can be updated during the `Preparing` state, so at the end of that
  state the settings will also be retrieved and used to update
  `settingsData`.

Upon retrieving the BIOS Settings from Ironic, the baremetal-operator will
copy the name/value pairs to the `vendorSettings` field in
`HostFirwareSettingsSpec` if that field is empty. Settings that have the
`read-only` flag set will not be copied as these settings cannot be written
to the BMC. Likewise, settings that have the `unique` flag set will also not
be copied, these are settings like serial numbers or product ids for example,
that should not be written to other servers.

A user can update `vendorSettings` to the desired values for the
settings using the limits from the `FirmwareSchema` section as a guide.

The baremetal-operator will detect when `vendorSettings` changes by comparing
the name/value pairs to `settingsData`. When a change is detected, the BMO
will add the new values to the Ironic clean-steps API in the Preparing state,
when building the manual clean steps. Before adding it though, the BMO will
do validation checks on the new values using the schema. For example, integer
types will checked against minimum and maximum parameters and enumeration types
will be compared against allowable values. A failure will be returned from the
clean steps stage if any errors are detected in order to avoid pushing a
partial configuration to Ironic.

As a follow-on, a validation webhook for the HostFirmwareSettings CRD can be
leveraged to add the validations. This webhook would reject the update before
it is stored in the resource, removing the need to do the validations in
manual clean steps. Since there could be some scenarios where the webhook would
not be available, the same validation checks will be done in the controller
before adding the settings to the clean steps.

When valid settings are added to the Ironic clean-steps API, Ironic will set
the BIOS Configuration in the BMC as part of the manual cleaning process which
requires a reboot. Manual clean occurs in the Preparing state of the
BaremetalHost, the Host will re-enter this state from Ready/Available state
whenever its config differs from the last one it stored.

After applying the new BIOS Configuration, Ironic will then read and cache the
new BIOS Settings, which can be retrieved by the BMO and used to update
`settingsData`.

Once a known good set of values are stored in the `vendorSettings` it can be
used to update the spec section of other hosts using the `kubectl` commands,
effectively cloning the settings from a reference host and ensuring that all
similar systems have the same BIOS configuration. External scripts can be
used with `kubectl` to help automate this manual configuration.

### Implementation Details/Notes/Constraints

One of the primary drivers of his design was that each vendor uses different
names and values for similar BIOS Configuration settings. This design does not
rely on vendor specific checks but instead uses common mechanisms to ensure
the BIOS Settings are valid:

- copying the names and values from `settingsData` to
  `vendorSettings` ensures initial values are correct
- when updating the values in `vendorSettings`, the user can use the
  limitations in the `settingsData`, e.g. minimum and maximum values
- before writing to the Ironic clean-steps API, the BMO runs validation checks
  against the `settingsData` to ensure updated values are valid

In order to interoperate with the individual BIOS Configuration set
approach the BMO must ensure that the same settings don't get added twice
to the Ironic clean-steps API. In addition, as each clean step requires a
reboot the number of clean steps that are added must be managed.

The use of a second set of CRs to store schema data instead of storing
the schema in `HostFirmwareSettings` is to reduce storing duplicate
schema information. As hosts of the same vendor and model will use
the same schema, its not necessary to cache it each time for similar hardware.
When BIOS data is read from the Ironic API for each host the following
actions will be taken:

- If the `HostFirmwareSettings` already has a reference to a  `FirmwareSchema`
  resource, then the schema data in the BIOS API will be ignored.
- If there is no reference, the schema data for all BIOS settings for the
  host will be stored locally.
- As the same schema names and values will be used for systems of the
  same vendor and model number, there is an opportunity to conserve
  creating multiple copies of the schema.
- A hash will be generated from names in the schema, if a corresponding hash
  does not exist in the `FirmwareSchema` CRs, a new CR will be created and
  the schema data will be copied to it.
- The reference to the `FirmwareSchema` resource in `HostFirmwareSettings`
  will be updated with the hash.
- Using the hash will ensure that the schemas match. In the case of
  hardware from the same vendor and model, but with a different firmware
  version, it is possible that the schemas would differ. In this case a new
  `FirmwareSchema` will be created.
- The name of the `FirmwareSchema` resource will be added to the
  `HostFirmwareSettings` resource so that it can be used to delete the
  `FirmwareSchema` resource when it is no longer being used.
- It is possible that the hosts will be in different namespaces (and the
  `FirmwareSchema` will be in same namespace as host). For this case,
  a `namespace` hint will be added to the BMO to specify the namespace to
  use for the schema. These BMO changes will be described in a follow-on
  doc.
- It is recommended that the refererence to the schema not use
  corev1.ObjectReference, but instead define a separate struct, see
  [ObjectReference](https://github.com/kubernetes-sigs/cluster-api/issues/2318)

An example of the proposed CRD for `HostFirmwareSettings` is as follows:

```yaml
---
kind: CustomResourceDefinition
metadata:
  name: hostfirmwaresettings.metal3.io
spec:
  group: metal3.io
  names:
    kind: HostFirmwareSettings
    listKind: HostFirmwareSettingsList
  scope: Namespaced
  versions:
  - name: v1alpha1
    schema:
          spec:
            description: HostFirmwareSettingsSpec defines the desired state
            properties:
              vendorSettings:
                items:
                  description: describes a setting whose value can be changed
                  properties:
                    name:
                      description: Identifier for the Firmware setting.
                      type: string
                    value:
                      description: Value of the Firmware setting.
                      type: string
                  required:
                  - name
                  - value
                  type: object
                type: array
            type: object
          status:
            description: defines the observed state of HostFirmwareSettings
            properties:
              schemaReference:
                  description: Reference to resource containing schema
                  type: string
              schemaNamespace:
                  description: The namespace where the schema resource resides
                  type: string
              settingsData:
                items:
                  description: describes current settings and their schema
                  properties:
                    name:
                      description: Identifier for the Firmware setting.
                      type: string
                    value:
                      description: Value of the Firmware setting.
                      type: string
                type: array
            type: object
```

An example of the proposed CRD for `FirmwareSchema` is as follows:

```yaml
---
kind: CustomResourceDefinition
metadata:
  name: firmwareschema.metal3.io
spec:
  group: metal3.io
  names:
    kind: FirmwareSchema
    listKind: FirmwareSchemaList
  scope: Namespaced
  versions:
  - name: v1alpha1
    schema:
          status:
            description: The schema to use for HostFirmwareSettings
            properties:
                schemaIdentifier:
                  description: Unique identifier for this schema, derived
                               from a hash of the schema contents
                  type: string
                schemaVendor:
                  description: The vendor that corresponds to this schema
                  type: string
                schemaModel:
                  description: The model that corresponds to this schema
                  type: string
                schema:
                      description: Vendor specific data describing each setting
                  items:
                    properties:
                      name:
                        description: Identifier for the Firmware setting.
                        type: string
                      allowable_values:
                        description: The allowable value for Enumeration type
                        items:
                          type: string
                          type: array
                      attribute_type:
                        description: The type of setting.
                        enum:
                        - Enumeration
                        - String
                        - Integer
                        - Boolean
                        - Password
                        type: string
                      lower_bound:
                        description: The lowest value for an Integer type
                        type: integer
                      max_length:
                        description: Maximum length for a String type
                        type: integer
                      min_length:
                        description: Minimum length for a String type
                        type: integer
                      read_only:
                        description: Whether or not this setting is read only
                        type: boolean
                      reset_required:
                        description: Whether or not a reset is required
                        type: boolean
                      unique:
                        description: Whether or not setting's value is unique
                        type: boolean
                      upper_bound:
                        description: The highest value for an Integer type
                        type: integer
                    type: object
```

### Risks and Mitigations

There is no risk in exposing the majority of the BIOS settings even if these
values are ReadOnly, such as `NumCores` or `CoreSpeed`. However, some vendors
use the `Password` AttributeType defined in
[Registry](https://redfish.dmtf.org/schemas/v1/AttributeRegistry.v1_3_5.json)
and include settings like `SysPassword`. Although the current values are not
included, or set to "", for these types, the values should not be stored in
the status section and they should not be allowed to be set via the spec
section.

### Work Items

Ironic

- Cache BIOS Registry
- Add support for BIOS Registry information in the Ironic API

Gophercloud

- Add support for nodes/{node}/bios endpoint.  The microversion
  should be 1.74 in order to use the ``?detail=True`` field to
  get the bios registry information.

Baremetal-operator

- Add a new CRD for `HostFirmwareSettings`
- Add a new CRD for `FirwmareSchema``
- Get BIOS Settings via the Ironic API at the end of the Registration state and
  store the name/value pairs in `settingsData`
- Determine if a schema already exists for the BIOS registry data received
  in the Ironic API. Create a new `FirmwareSchema` CR if one doesn't exist
  and update the reference in `settingsData`
- Copy name/value pairs from `settingsData` to
 `vendorSettings` for settings that are not `read-only` or `unique`
- Check for changes to `vendorSettings` and when detected, validate
  values and add updated name/value pairs to Ironic clean-steps API

### Test Plan

- Unit test for changes to provisioner and baremetal-controller
- metal3-dev-env integration test
- Test on running cluster
- Verify that new Custom Resources for HostFirmwareSettings and
  schema are created and match the Ironic settings
- Verify that the settings can be updated
- Verify that after the host goes through cleaning the settings have
    been updated

## Alternatives

- Rely on the granular approach for setting BIOS configuration for a few
  individual values in a vendor-specific way as proposed.
- Support the Configuration Mold approach in the installer as proposed in Ironic

## References

[individual set](https://github.com/metal3-io/baremetal-operator/pull/302)
[ironic hw config](https://review.opendev.org/c/openstack/ironic-specs/+/74071)
[BIOS API](https://docs.openstack.org/api-ref/baremetal/?expanded=#node-bios-nodes)
[BIOS Registry](https://review.opendev.org/c/openstack/ironic-specs/+/774681)
[Redfish Registry](https://redfish.dmtf.org/schemas/v1/AttributeRegistry.v1_3_5.json)
[ObjectReference](https://github.com/kubernetes-sigs/cluster-api/issues/2318)
