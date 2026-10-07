<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# FirmwareInventory: Centralized Firmware Image Registry

## Status

provisional

## Summary

We introduce a new Custom Resource, FirmwareInventory, that serves as a
centralized registry mapping firmware versions to their download URLs for
a given hardware component. A FirmwareInventory resource targets a
specific component type (such as `bmc`, `bios`, or `nic`) and can
optionally select applicable hosts based on their hardware properties.

## Motivation

Today, requesting a firmware update through HostFirmwareComponents
requires the user to specify both the component name and the full
download URL for each update. This has several drawbacks:

- **No version tracking.** There is no structured way to record which
  firmware versions are available for a given component or hardware
  class. Administrators must maintain this information externally.

- **No hardware-aware scoping.** A firmware image that applies only to
  Dell BMCs cannot currently be distinguished from one that applies to
  HPE BMCs at the API level. The administrator must rely on conventions
  or external tooling to prevent misapplication.

- **Future multi-tenancy issue.** Eventually, we'll need to support firmware
  updates via HostClaims. Infrastructure administrators may decide to prevent
  arbitrary images from being applied to their machines, limiting users to
  a curated list of compatible ones.

### Goals

- Provide a Kubernetes-native resource for declaring available firmware
  versions and their download locations per component type.

- Allow HostFirmwareComponents to request updates by version alone,
  with the controller resolving the URL from a matching
  FirmwareInventory.

### Non-Goals

- Defining how firmware images are built, signed, or distributed.
  FirmwareInventory only records the mapping from version to URL.

- Automatic firmware update orchestration across fleets. Rollout
  strategies are the responsibility of external tooling, not
  FirmwareInventory itself.

- Multi-tenant firmware update policy. Integration with HostClaims,
  and HostDeployPolicy is out of scope for this proposal and will be addressed
  separately.

- All NICs will be grouped under the same generic `nic` component, there won't
  be supported for specific devices (`nic:<ID>`). Given that Redfish `Targets`
  property is not consistently implemented across vendors, Ironic updates all
  suitable NICs anyway.

## Proposal

### User Stories

#### Story 1: Infrastructure Admin Publishes Firmware Catalog

As an infrastructure administrator, I manage a fleet of Dell and HPE
servers. I want to declare the available BMC and BIOS firmware versions
for each vendor in a structured way, so that my team can request
updates by version without managing URLs.

I create two FirmwareInventory resources in the infrastructure
namespace:

```yaml
apiVersion: metal3.io/v1alpha1
kind: FirmwareInventory
metadata:
  name: dell-bmc
  namespace: infra
spec:
  component: bmc
  hostSelector:
    matchHardwareData:
      systemVendor.manufacturer: 'Dell'
  versions:
  - version: 1.2.3
    url: https://firmware.example.com/dell/bmc-1.2.3.img
  - version: 2.0.0
    url: https://firmware.example.com/dell/bmc-2.0.0.img
---
apiVersion: metal3.io/v1alpha1
kind: FirmwareInventory
metadata:
  name: hpe-bmc
  namespace: infra
spec:
  component: bmc
  hostSelector:
    matchHardwareData:
      systemVendor.manufacturer: 'HPE'
  versions:
  - version: 3.0.1
    url: https://firmware.example.com/hpe/bmc-3.0.1.img
```

When an HFC for a Dell host requests BMC version `2.0.0`, the
controller automatically resolves the URL from `dell-bmc`. The HPE
inventory is not considered because its selector does not match.

**NOTE:** this example relies on [matchHardwareData
RFE](https://github.com/metal3-io/baremetal-operator/issues/3284), which is not
required for this proposal but can make the user experience better.

#### Story 2: Requesting a Firmware Update by Version

As a host operator, I want to update the BMC firmware on a specific
host. I know the target version but do not want to look up or hardcode
the download URL.

I edit the HostFirmwareComponents resource for the host:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostFirmwareComponents
metadata:
  name: myhost
  namespace: infra
spec:
  updates:
  - component: bmc
    version: 2.0.0
```

The HFC controller finds a matching FirmwareInventory (based on
the host's HardwareData and the component name), resolves the URL, and
populates the status:

```yaml
spec:
  updates:
  - component: bmc
    version: 2.0.0
status:
  resolvedUpdates:
  - component: bmc
    version: 2.0.0
    url: https://firmware.example.com/dell/bmc-2.0.0.img
  inventory:
  - component: bmc
    name: dell-bmc
    namespace: infra
```

If no matching inventory is found or the requested version does not
exist in any matching inventory, the HFC `Valid` condition is set to
`False` with an appropriate message. `ChangeDetected` and `Valid` are not
both set to `True` until the URL is resolved successfully.

#### Story 3: Wildcard Inventory Without Host Selector

As an administrator of a homogeneous fleet, all my hosts use the same
BMC firmware. I create a FirmwareInventory without a host selector,
making it a fallback for any host in the namespace:

```yaml
apiVersion: metal3.io/v1alpha1
kind: FirmwareInventory
metadata:
  name: generic-bmc
  namespace: infra
spec:
  component: bmc
  versions:
  - version: 5.0.0
    url: https://firmware.example.com/generic/bmc-5.0.0.img
```

If a host-specific inventory with a selector also matches, it takes
precedence over this wildcard inventory.

## Design Details

### FirmwareInventory Resource

A new namespaced Custom Resource Definition:

```yaml
apiVersion: metal3.io/v1alpha1
kind: FirmwareInventory
metadata:
  name: <name>
  namespace: <namespace>
spec:
  # Required. The firmware component type this inventory covers.
  # Does not support specific devices (like nic:ABCD in case of NICs).
  component: bmc|bios|nic

  # Optional. When present, this inventory only applies to hosts
  # that match all specified selectors. Inventories with a non-empty selector
  # take precedence over those without.
  hostSelector:
    matchLabels: {}
    matchExpressions: []
    # matchHardwareData: {}

  # Required. At least one version entry.
  versions:
  - version: <semver or vendor string>
    url: <https://URL>
```

**Field details:**

- `component`: Follows the same validation rules as HostFirmwareComponents.
  Currently must be `bmc`, `bios`, or `nic` (which also covers prefixed
  components `nic:abcd`).

- `hostSelector`: Selects hosts based on labels, expressions and in the future
  also HardwareData fields (if approved in the corresponding RFE).

- `versions`: An ordered list of version-to-URL mappings. Versions are
  opaque strings; no ordering is implied.

### Changes to HostFirmwareComponents

The existing `FirmwareUpdate` struct gains an optional `version` field:

```yaml
spec:
  updates:
  - component: bmc
    # Existing field: direct URL (still supported for backwards
    # compatibility)
    url: <string>
    # New field: version to resolve via FirmwareInventory
    version: <string>
```

When `version` is set and `url` is empty, the HFC controller resolves
the URL from the first matching FirmwareInventory (see matching rules
below). The resolved URL is stored in a new `resolvedUpdates` field in
the HFC status. The spec is never modified by the controller.

New fields are added to HFC status:

```yaml
status:
  # The spec updates with resolved URLs. When an update in the spec
  # uses version-based resolution, the corresponding entry here
  # includes the URL resolved from the matching FirmwareInventory.
  # The BMH controller reads this field (instead of the spec) to
  # determine which firmware images to apply.
  resolvedUpdates:
  - component: <bmc|bios|nic>
    url: <string>
    version: <string>

  # Reference to the FirmwareInventory used for URL resolution.
  # Set when at least one update was resolved via an inventory.
  inventory:
  - component: <bmc|bios|nic>
    name: <string>
    namespace: <string>
```

### FirmwareInventory Matching Rules

When the HFC controller needs to resolve a version for a given
component on a given host:

1. Check if a FirmwareInventory for the given component is already linked in
   the status, exists and still matches the host. If so, use it for URL
   resolution and skip the rest of the steps.

1. List all FirmwareInventory resources in the same namespace as the HFC.

1. Filter to those whose `component` field matches the requested component.

1. For each remaining inventory, if `hostSelector` is present, evaluate it
   against the host (and in the future also HardwareData). Discard inventories
   whose selector does not match.

1. Among the matching inventories, prefer those with a non-empty
   selector over those without one. If multiple inventories with
   selectors match, the first one (by name, alphabetically) is used.
   This deterministic ordering avoids ambiguity.

1. In the selected inventory, look up the requested version. If found,
   use its URL. If not found, report an error via the HFC `Valid`
   condition.

Importantly, inventory resolution only runs when the `url` field in an
HFC update entry is empty. Once a version has been resolved and the
URL written into `status.resolvedUpdates`, subsequent inventory changes
(including removal of that version from the inventory) do not affect
the already-resolved entry. The controller does not re-resolve a
version that already has a URL in the status. This means an
administrator can safely remove old versions from a FirmwareInventory
without disrupting in-progress or completed firmware updates that
reference them.

### Implementation Details/Notes/Constraints

**Namespace scoping.** Only FirmwareInventory resources in the same
namespace as the HFC are considered during matching. This limits
complexity and aligns with the existing pattern where HFC, HFS,
HardwareData, and BareMetalHost all share a namespace. Cross-namespace
inventory references are not supported.

**Inventory is declarative, not imperative.** FirmwareInventory does
not trigger updates on its own. It is a passive registry. Updates are
triggered by changes to the HFC spec.

**Inventory is loaded lazily.** To avoid unnecessary reconciliations of
potentially many HostFirmwareComponents resources, the inventory is only
verified when it's used.

**Backwards compatibility.** The existing `url`-only mode in HFC
continues to work. When both `url` and `version` are set in an HFC
update, the explicitly provided URL takes precedence and no inventory
lookup is performed. This allows a gradual migration path.

**Interaction with HostUpdatePolicy.** FirmwareInventory is orthogonal
to HostUpdatePolicy. The inventory controls *what* can be updated and
*where* to get the image. HostUpdatePolicy controls *when* updates are
applied (on preparing vs. on reboot). Both policies are evaluated
independently.

### Risks and Mitigations

**Risk: Selector evaluation performance at scale.**
In a namespace with many FirmwareInventory resources and many hosts,
evaluating selectors on every HFC reconciliation could become expensive.
*Mitigation:* Caching the matched inventory in HFC status avoids
repeated evaluation. The cache is only invalidated on relevant changes
(see matching rules above). Additionally, the namespace-scoped design
bounds the number of inventories to evaluate.

**Risk: Ambiguous inventory matches.**
Multiple FirmwareInventory resources could match the same host and
component, potentially with different URLs for the same version.
*Mitigation:* Deterministic ordering (prefer selector over no-selector,
then alphabetical by name) ensures consistent results. Administrators
should avoid overlapping inventories for the same component and hardware
class. A future enhancement could add a priority field, but so far we'll
report warnings on overlapping matches.

**Risk: Version removed from inventory while in use.**
An administrator removes a version from a FirmwareInventory while one
or more HFC resources still reference it.
*Mitigation:* By design, inventory resolution is a one-shot operation:
once the URL is resolved and written into `status.resolvedUpdates`, the
controller does not re-resolve it. Removing the version from the
inventory has no effect on existing HFC resources that already carry
the resolved URL in their status.
New HFC resources requesting that version will fail validation (the
`Valid` condition is set to `False`), giving the administrator clear
feedback that the version is no longer available.

**Risk: Large FirmwareInventory resources.**
An inventory with hundreds of versions could become unwieldy.
*Mitigation:* In practice, the number of firmware versions for a
given component is modest (typically tens, not hundreds). If needed,
administrators can split inventories by hardware generation or model.
Kubernetes object size limits (1.5 MB for etcd) provide a natural
upper bound.

### Scalability and Performance Considerations

**Number of FirmwareInventory resources.** In a typical deployment, the
number of inventories is proportional to the number of distinct
(component, hardware class) combinations --- not the number of hosts.
A fleet of 1,000 hosts from 3 vendors with 3 firmware component types
might need only 9 FirmwareInventory resources. This scales well.

**Selector evaluation cost.** Each selector evaluation requires reading the
host and potentially its HardwareData and comparing field values. This is a
lightweight in-memory operation. The caching strategy (storing the matched
inventory reference in HFC status) ensures that this evaluation happens at most
once per relevant change, not on every reconciliation loop.

### Work Items

1. **Define the FirmwareInventory CRD** in the baremetal-operator API
   types, including validation webhooks for component name and version
   list constraints.

1. **Add `version` field to FirmwareUpdate struct** in the HFC API
   types. Add `inventory` field to HFC status.

1. **Implement FirmwareInventory matching logic** in the HFC controller.

1. **Documentation and examples** for the new resources and workflows.

### Dependencies

- **matchHardwareData selector**: The host selector can reuse the
  `matchHardwareData` mechanism proposed in
  [baremetal-operator#3284](https://github.com/metal3-io/baremetal-operator/issues/3284).
  This is a soft dependency, the feature can be implemented without it first.

### Test Plan

**Unit tests:**

- FirmwareInventory validation (component name rules, non-empty
  versions list, URL format).
- Selector matching logic against HardwareData fixtures.
- Precedence rules (selector vs. no-selector, alphabetical tiebreak).
- FirmwareUpdate version resolution with and without inventory.

**Integration tests:**

- End-to-end flow: create FirmwareInventory, create HFC with
  version-only update, verify URL resolution and status caching.
- Cache invalidation: modify a FirmwareInventory, verify that
  affected HFC resources are re-evaluated on the next firmware upgrade.
- Backwards compatibility: verify that HFC with explicit URL (no
  version) continues to work unchanged (this test should be created
  even before this work is done).

### Upgrade / Downgrade Strategy

**Upgrade:**

- The FirmwareInventory CRD is new and does not affect existing
  resources. Existing HFC resources with explicit URLs continue to
  work without modification.
- The `version` field in FirmwareUpdate is optional. Existing HFC
  resources without it are valid.
- The `inventory` field in HFC status is optional and will be empty
  for HFC resources that do not use inventory-based resolution.

**Downgrade:**

- Removing the FirmwareInventory CRD does not affect HFC resources
  that have already resolved their URLs (the resolved URL is in the
  HFC status and does not depend on the inventory at runtime).
- HFC resources with a `version` field but no resolved URL will fail
  validation on a downgraded controller that does not understand the
  `version` field. Administrators should ensure all HFC resources
  have explicit URLs before downgrading.

### Version Skew Strategy

If the HFC controller is upgraded to support `version`-based resolution but the
FirmwareInventory CRD has not been installed, the controller should treat
missing inventories gracefully (set `Valid` condition to `False` with a clear
message).

## Drawbacks

- **Additional CRD complexity.** FirmwareInventory adds a new resource
  type that administrators must learn and manage. However, this is
  offset by the reduction in per-host URL management.

- **Indirect relationship chain.** The path from FirmwareInventory to
  a firmware update action traverses several resources
  (FirmwareInventory -> HardwareData -> BareMetalHost -> HFC). This
  indirection can make debugging harder. Good status reporting and
  conditions on HFC are essential.

- **Selector expressiveness.** The expressiveness of the
  `matchHardwareData` selector depends on the design of the
  [matchHardwareData
  RFE](https://github.com/metal3-io/baremetal-operator/issues/3284).
  FirmwareInventory reuses the same selector and inherits its
  limitations.

## Alternatives

**Embed version-to-URL mapping directly in HFC.** Rather than a
separate resource, the HFC spec could include a versions list inline.
This was rejected because it duplicates the mapping across every HFC
resource and makes fleet-wide updates (e.g. publishing a new firmware
version) require editing every host's HFC.

**Use ConfigMaps or Secrets for firmware catalogs.** Generic Kubernetes
resources could store the version-to-URL mapping. This was rejected
because it lacks schema validation, component-type awareness, and
hardware-based selectors. A purpose-built CRD provides better
ergonomics and integration with the Metal3 controller ecosystem.

**Cluster-scoped FirmwareInventory.** Making the resource
cluster-scoped would allow sharing inventories across namespaces. This
was rejected to maintain consistency with the namespace-scoped model
used by all other Metal3 infrastructure resources and to avoid
cross-namespace permission complexities.

## References
