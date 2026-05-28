<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Add fast (out-of-band) inspection mode

## Status

provisional

## Summary

Ironic supports two types of hardware inspection: in-band (agent-based)
and out-of-band (Redfish-based). Metal3 currently only uses in-band
inspection, which requires booting a ramdisk with the Ironic Python
Agent (IPA) and takes several minutes to complete. Out-of-band
inspection uses the Redfish BMC API to collect hardware inventory
directly, completing in seconds without booting anything.

This proposal adds a new `InspectionMode` value that enables
out-of-band inspection in BareMetalHost. The feature requires a
Redfish-compatible BMC and provides a faster, lighter alternative to
agent-based inspection.

## Motivation

In-band inspection is thorough but slow: the host must boot a
ramdisk, run the Ironic Python Agent, collect data, and report back.
This takes minutes per host and requires a functioning provisioning
network. Out-of-band inspection avoids all of this by querying the
BMC directly via Redfish, returning results in seconds.

Beyond speed, out-of-band inspection is useful for preparation
workflows that need hardware information before booting anything.
For example, an operator might need to discover hardware
configuration or provide data for templates used in site-specific
PreprovisioningImages.

There is also a re-enrollment scenario: when the Ironic database is
lost, hosts without `bootMACAddress` are re-enrolled without any
ports and without re-inspecting them. Fast out-of-band inspection
could be used automatically during re-enrollment to restore port
information without the overhead of a full in-band inspection.

### Goals

- Allow users to select out-of-band (Redfish-based) inspection for
  BareMetalHost resources.
- Provide hardware details (system vendor, CPU, memory, NICs, storage)
  without booting the host.
- Support re-inspection via the existing `inspect.metal3.io` annotation
  in the new mode.
- Keep in-band (agent) inspection as the default behavior.

### Non-Goals

- Replacing in-band inspection entirely. Some data (e.g. DHCP-derived
  information, detailed storage attributes) is only available through
  in-band inspection.
- Supporting out-of-band inspection for IPMI-only hosts. The feature
  requires Redfish.
- Automatic fallback from out-of-band to in-band inspection if the
  BMC provides incomplete data.
- Automatic re-enrollment with fast inspection (this is a potential
  follow-up).

## Proposal

### User Stories

#### Story 1

As an infrastructure operator managing a large fleet, I want to run
quick hardware inspection (seconds, not minutes) so that I can get
HardwareData for newly enrolled hosts without waiting for ramdisk
boots.

#### Story 2

As a user building site-specific PreprovisioningImages using
templates, I need hardware details (e.g. NIC information, CPU
architecture) available before anything is booted, so that the
preprovisioning image can be customized for each host.

## Design Details

### API Changes

A new `InspectionMode` constant will be added to the BareMetalHost
API:

```go
const (
    InspectionModeDisabled InspectionMode = "disabled"
    InspectionModeAgent    InspectionMode = "agent"
    InspectionModeFast     InspectionMode = "fast"
)
```

The kubebuilder validation enum on the `InspectionMode` field will be
updated to include `fast`:

```go
// +kubebuilder:validation:Enum=disabled;agent;fast
InspectionMode InspectionMode `json:"inspectionMode,omitempty"`
```

The existing `inspect.metal3.io` annotation will continue to work for
triggering re-inspection. The annotation does not select an inspection
mode; the mode is always taken from the `inspectionMode` spec field.

### AccessDetails Interface Changes

A new method will be added to the `AccessDetails` interface in
`pkg/hardwareutils/bmc/access.go`:

```go
type AccessDetails interface {
    // ... existing methods ...

    // InspectInterface returns the Ironic inspect interface name
    // to use for this BMC type.
    InspectInterface() string
}
```

Implementations:

- **Redfish-based drivers** will return `"redfish"`.
- **IPMI** will return an empty string (no out-of-band inspection support).

### Behavior on Enrollment

New nodes will be configured with either `agent` or `redfish` depending on
their `InspectionMode`. This is to allow enrolling hosts in clouds where Ironic
does not support the agent inspection at all. The actual interface used will be
overridden based on the `InspectionMode` selected by the user (see below).

The `ManagementAccessData` struct will be extended to carry the inspection
mode. The implementation will use it to determine behavior:

- `InspectionModeFast`: use the BMC-native inspect interface (e.g.
  `redfish`). If the BMC's `AccessDetails.InspectInterface()` returns
  an empty string (i.e. the BMC does not support out-of-band inspection),
  the provisioner should return an error.
- Any other value: use `agent` inspect interface (current behavior).

**NOTE:** it seems logical to use the special interface `no-inspect` for hosts
with inspection disabled. However, this interface is not currently enabled in
ironic-image, so we'll stay with using `agent` by default for now. This issue
is tracked as [BMO issue
3283](https://github.com/metal3-io/baremetal-operator/issues/3283) and will be
resolved separately.

### Provisioner Interface Changes

The `InspectData` struct will be extended to carry the inspection mode. The
`Provisioner.InspectHardware` method signature remains unchanged.

When the inspection mode differs from what the Ironic node is
currently configured with, the provisioner will update the node's
`inspect_interface` before starting inspection.

### Ironic Configuration

The `redfish` inspect interface must be enabled in the Ironic
configuration. The ironic-image will need to include `redfish` in the
list of `enabled_inspect_interfaces`. This is purely a deployment
configuration change.

### Implementation Details/Notes/Constraints

#### Data Completeness

Out-of-band inspection via Redfish may return fewer details than
in-band inspection. Typical differences:

- NIC LLDP data: may be available via Redfish on some hardware, but
  not all.
- Storage details: some attributes (HCTL, WWN) may not be reported.
- Hostname: not available (derived from DHCP during in-band).

The `HardwareDetails` struct and `HardwareData` resource remain
unchanged. Fields not populated by out-of-band inspection will be
empty or zero-valued, matching the existing behavior for optional
fields.

#### Preprovisioning Image Not Required

A key advantage of `fast` mode is that no preprovisioning image
(ramdisk) is needed for inspection. The provisioner must not require
or wait for a `PreprovisioningImage` when operating in fast mode.

### Risks and Mitigations

**Risk:** Users set `fast` mode on IPMI-only hosts that don't
support Redfish-based inspection.
**Mitigation:** The BareMetalHost validation webhook will prevent this
situation. If the webhook is disabled, the provisioner will return a clear
error when fast inspection is requested but the BMC type doesn't support it.

**Risk:** Out-of-band inspection returns incomplete data, and users
expect the same level of detail as in-band inspection.
**Mitigation:** Document the differences in data completeness between
inspection modes. The `fast` name also signals that this is a
trade-off.

**Risk:** BMC firmware bugs cause incorrect or incomplete inventory
via Redfish.
**Mitigation:** This is an inherent risk of any BMC interaction.
Users who encounter issues can switch back to `agent` mode.

### Work Items

1. Enable the `redfish` inspect interface in ironic-image
   configuration.
1. Add `InspectInterface()` method to the `AccessDetails` interface
   and implement it for all BMC types.
1. Add `InspectionModeFast` constant to the BareMetalHost API and
   update kubebuilder validation.
1. Extend `InspectData` to include `InspectionMode`.
1. Update the enrollment code to configure the inspect interface according
   to the mode (if set).
1. Update the Ironic provisioner to select the inspect interface
   based on the inspection mode and update the Ironic node
   configuration accordingly.
1. Update the BareMetalHost controller to pass `InspectionMode` to
   `InspectData`.
1. Add e2e tests for out-of-band inspection with Redfish-based BMCs.
1. Update user documentation.

### Dependencies

- Ironic must support the `redfish` inspect interface (available in
  current versions).
- The ironic-image deployment must be configured to enable the
  `redfish` inspect interface.
- No new library dependencies are required.

### Test Plan

- **Unit tests:** Update existing provisioner tests to cover the new
  inspection mode, including error cases (e.g. IPMI host with fast
  mode).
- **E2e tests:** Add a BMO e2e test that creates a BareMetalHost
  with `inspectionMode: fast` using a Redfish-based BMC (sushy-tools
  or similar), verifies that inspection completes without booting,
  and checks that `HardwareData` is populated.
- **E2e tests:** Verify that re-inspection via the
  `inspect.metal3.io` annotation works in fast mode.

### Upgrade / Downgrade Strategy

The new `fast` value for `InspectionMode` is additive. Existing
hosts with no `inspectionMode` set or with `agent` will continue to
use in-band inspection with no changes required.

On downgrade, hosts with `inspectionMode: fast` will have an unrecognized
value. The older controller will ignore it and fall through to the default
(agent-based) behavior, since the default `InspectionMode` is treated as
`agent`. To avoid problems on further updates to the resource, we'll recommend
setting `InspectionMode` to a supported value before downgrading.

### Version Skew Strategy

The `InspectionMode` field is part of the BareMetalHost CRD. The
CRD must be updated before the controller to ensure the new enum
value is accepted by the API server. If the CRD is updated but the
controller is not, the controller will treat `fast` as an unknown
value and fall back to agent-based inspection.

## Drawbacks

- Adds complexity to the inspection code path with a new mode.
- Out-of-band inspection data quality depends on BMC firmware, which
  varies across vendors and models.
- Only useful for Redfish-compatible hardware, limiting applicability.

## Alternatives

**Use the `inspect.metal3.io` annotation to select the mode.**
This was considered but rejected because annotations are meant for
triggering operations, not for persistent configuration. The
`inspectionMode` spec field is the right place for this.

**Add a separate `outOfBandInspection: true` boolean field.**
This was considered but rejected in favor of extending the existing
`InspectionMode` enum, which is simpler and more consistent.

**Name the mode `redfish` or `outofband` instead of `fast`.**
Using `redfish` would tie the API to a specific protocol. Using
`outofband` is accurate but less intuitive for users. The name
`fast` describes the user-facing benefit and leaves room for
alternative fast inspection backends in the future.

## References

- [BMO issue 3138](https://github.com/metal3-io/baremetal-operator/issues/3138)
- [Ironic inspection documentation](https://docs.openstack.org/ironic/latest/admin/inspection.html)
- [Redfish standard](https://www.dmtf.org/standards/redfish)
