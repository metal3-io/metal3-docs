# Migration Guide: v1beta1 to v1beta2

This guide covers the breaking changes introduced when migrating from
Cluster API Provider Metal3 (CAPM3) v1beta1 to v1beta2 API.

## Overview

The v1beta2 API introduces several breaking changes including field renames,
type changes, and structural modifications. This guide will help you update
your manifests and configurations.

The primary driver for these changes is the migration of conditions from
Cluster API's `clusterv1beta1.Conditions` to Kubernetes native
`metav1.Condition` to align with standard Kubernetes patterns. Additionally,
the [kube-api-linter](https://github.com/kubernetes-sigs/kube-api-linter) was
adopted in v1beta2 to enforce Kubernetes API conventions and best practices,
resulting in many of the field renames, type changes, and structural
improvements documented below.

## Breaking Changes

### Metal3Machine

#### Field Renames

The JSON field name for `DiskFormat` in `spec.image` has been renamed:

| v1beta1 Field Name | v1beta2 Field Name |
|--------------------|-------------------|
| `format` | `diskFormat` |

**Example migration:**

```yaml
# v1beta1
spec:
  image:
    url: http://example.com/image.qcow2
    checksum: http://example.com/image.qcow2.sha256
    format: qcow2
```

```yaml
# v1beta2
spec:
  image:
    url: http://example.com/image.qcow2
    checksum: http://example.com/image.qcow2.sha256
    diskFormat: qcow2
```

#### NoCloudProvider Removed

The deprecated `NoCloudProvider` field has been removed from the v1beta2 API.

**Migration:**

- Replace all usages of `NoCloudProvider` with `CloudProviderEnabled`
- Note that the logic is inverted: to keep the same behavior, change
  `NoCloudProvider: false` to `CloudProviderEnabled: true`

**Example migration:**

```yaml
# v1beta1
spec:
  noCloudProvider: true
```

```yaml
# v1beta2
spec:
  cloudProviderEnabled: false
```

```yaml
# v1beta1
spec:
  noCloudProvider: false
```

```yaml
# v1beta2
spec:
  cloudProviderEnabled: true
```

#### Metal3Machine Type Changes (Pointer vs Value)

| Field | Type Change |
|-------|-------------|
| `spec.hostSelector` | HostSelector → *HostSelector |
| `spec.automatedCleaningMode` | *string → string |

#### Metal3Machine Fields with Added omitzero

| Field |
|-------|
| `spec.image` |
| `spec.customDeploy` |

#### Metal3Machine Status Changes

| v1beta1 Field | v1beta2 Field | Notes |
|--------------|---------------|-------|
| `status.ready` | `status.initialization.provisioned` | Bool → *bool pointer |
| `status.phase` | Removed | No longer available |
| `status.conditions` | `status.conditions` | Type changed (see Conditions section) |
| `status.failureReason` | `status.deprecated.v1beta1.failureReason` | Moved to deprecated, no longer terminal |
| `status.failureMessage` | `status.deprecated.v1beta1.failureMessage` | Moved to deprecated, no longer terminal |

**Note:** In v1beta1, `failureReason` and `failureMessage` represented terminal errors
that required manual intervention. In v1beta2, these fields are deprecated and moved
to `status.deprecated.v1beta1`. They no longer represent terminal errors - error
information should now be obtained from the `status.conditions` field.

**Example v1beta2 Metal3Machine status structure:**

```yaml
status:
  initialization:
    provisioned: true
  conditions:
  - type: Ready
    status: "True"
    reason: Ready
  - type: AssociateBareMetalHost
    status: "True"
    reason: AssociateBareMetalHostSuccess
  - type: AssociateMetal3MachineMetaData
    status: "True"
    reason: AssociateMetal3MachineMetaDataSuccess
  - type: Metal3DataReady
    status: "True"
    reason: Metal3DataSecretsReady
  deprecated:
    v1beta1:
      conditions:  # Legacy v1beta1 conditions for backwards compatibility
      - type: AssociateBMH
        status: "True"
        severity: Info
        reason: AssociateBMHSuccess
        lastTransitionTime: "2026-01-01T00:00:00Z"
      - type: KubernetesNodeReady
        status: "True"
        severity: Info
        reason: KubernetesNodeReady
        lastTransitionTime: "2026-01-01T00:00:00Z"
      - type: Metal3DataReady
        status: "True"
        severity: Info
        reason: Metal3DataReady
        lastTransitionTime: "2026-01-01T00:00:00Z"
      failureReason: null
      failureMessage: null
```

#### Metal3Machine Condition Type Name Changes

| v1beta1 Condition Type | v1beta2 Condition Type |
|-----------------------|------------------------|
| `AssociateBMH` | `AssociateBareMetalHost` |
| `KubernetesNodeReady` | `AssociateMetal3MachineMetaData` |
| `Metal3DataReady` | `Metal3DataReady` (unchanged) |

#### Metal3Machine Condition Reason Name Changes

| v1beta1 Reason | v1beta2 Reason |
|---------------|----------------|
| `WaitingForClusterInfrastructure` | `WaitingForClusterInfrastructureReady` |
| `WaitingForBootstrapReady` | `WaitingForBootstrapData` |
| `AssociateBMHFailed` | `AssociateBareMetalHostFailed` |
| `PauseAnnotationRemoveFailed` | `BareMetalHostPauseAnnotationRemoveFailed` |
| `PauseAnnotationSetFailedReason` | `BareMetalHostPauseAnnotationSetFailed` |
| `AssociateM3MetaDataFailed` | `AssociateMetal3MachineMetaDataFailed` |
| N/A | `AssociateBareMetalHostSuccess` (new) |
| N/A | `AssociateBareMetalHostViaNodeReuseSuccess` (new) |
| N/A | `AssociateMetal3MachineMetaDataSuccess` (new) |
| N/A | `Metal3DataSecretsReady` (new) |
| N/A | `SecretsSetExternally` (new) |

### Metal3MachineTemplate

#### Metal3MachineTemplate Type Changes (Pointer vs Value)

| Field | Type Change |
|-------|-------------|
| `spec.nodeReuse` | bool → *bool |

### Metal3Cluster

#### Metal3Cluster Status Changes

| v1beta1 Field | v1beta2 Field | Notes |
|--------------|---------------|-------|
| `status.ready` | `status.initialization.provisioned` | Bool → *bool pointer |
| `status.conditions` | `status.conditions` | Type changed (see Conditions section) |
| `status.failureReason` | `status.deprecated.v1beta1.failureReason` | Moved to deprecated, no longer terminal |
| `status.failureMessage` | `status.deprecated.v1beta1.failureMessage` | Moved to deprecated, no longer terminal |

**Example v1beta2 Metal3Cluster status structure:**

```yaml
status:
  initialization:
    provisioned: true
  conditions:
  - type: Ready
    status: "True"
    reason: Ready
  - type: BaremetalInfrastructureReady
    status: "True"
    reason: Ready
  deprecated:
    v1beta1:
      conditions:  # Legacy v1beta1 conditions for backwards compatibility
      - type: BaremetalInfrastructureReady
        status: "True"
        severity: Info
        reason: Ready
        lastTransitionTime: "2026-01-01T00:00:00Z"
      failureReason: null
      failureMessage: null
```

#### Metal3Cluster Condition Type Name Changes

| v1beta1 Condition Type | v1beta2 Condition Type |
|-----------------------|------------------------|
| `BaremetalInfrastructureReady` | `BaremetalInfrastructureReady` (unchanged) |

### Metal3DataTemplate

#### Metal3DataTemplate Field Renames

The following JSON field names in `spec.metaData` have been renamed:

| v1beta1 Field Name | v1beta2 Field Name |
|--------------------|-------------------|
| `ipAddressesFromIPPool` | `ipAddressesFromPool` |
| `prefixesFromIPPool` | `prefixesFromPool` |
| `gatewaysFromIPPool` | `gatewaysFromPool` |
| `dnsServersFromIPPool` | `dnsServersFromPool` |

**Example migration:**

```yaml
# v1beta1
spec:
  metaData:
    ipAddressesFromIPPool:
    - key: node_ip
      name: pool-1
```

```yaml
# v1beta2
spec:
  metaData:
    ipAddressesFromPool:
    - key: node_ip
      name: pool-1
```

#### Metal3DataTemplate Type Changes (int to int32)

The following JSON field types have been changed from `int` to `int32`:

| Field Path | Type Change |
|-----------|-------------|
| `spec.metaData.index.offset` | int → int32 |
| `spec.metaData.index.step` | int → int32 |
| `spec.metaData.ipaddress.step` | int → int32 |
| `spec.networkData.links.ethernet.mtu` | int → int32 |
| `spec.networkData.links.bond.mtu` | int → int32 |
| `spec.networkData.links.vlan.vlanID` | int → int32 |
| `spec.networkData.links.vlan.mtu` | int → int32 |
| `spec.networkData.routes.ipv4.prefix` | int → int32 |
| `spec.networkData.routes.ipv6.prefix` | int → int32 |

These type changes should be transparent for most users as the YAML
representation remains the same.

#### Metal3DataTemplate Type Changes (Pointer vs Value)

Value to Pointer:

| Field | Type Change |
|-------|-------------|
| `spec.metaData.index.offset` | int32 → *int32 |
| `spec.metaData.fromHostInterfaces[].fromBootMAC` | bool → *bool |
| `spec.networkData.routes.ipv4[].prefix` | int32 → *int32 |
| `spec.networkData.routes.ipv4[].services` | NetworkDataServicev4 → *NetworkDataServicev4 |
| `spec.networkData.routes.ipv6[].prefix` | int32 → *int32 |
| `spec.networkData.routes.ipv6[].services` | NetworkDataServicev6 → *NetworkDataServicev6 |
| `spec.networkData.links` | NetworkDataLink → *NetworkDataLink |
| `spec.networkData.networks` | NetworkDataNetwork → *NetworkDataNetwork |
| `spec.networkData.services` | NetworkDataService → *NetworkDataService |

Pointer to Value:

| Field | Type Change |
|-------|-------------|
| `spec.networkData.services.dnsFromIPPool` | *string → string |
| `spec.networkData.services.dns[].dnsFromIPPool` | *string → string |

#### Metal3DataTemplate Fields with Added omitzero

| Field |
|-------|
| `spec` |
| `spec.networkData.links.ethernets[].macAddress.fromAnnotation` |
| `spec.networkData.networks.ipv4[].fromPoolAnnotation` |
| `spec.networkData.networks.ipv6[].fromPoolAnnotation` |
| `spec.networkData.networks.ipv4DHCP[].fromPoolAnnotation` |
| `spec.networkData.networks.ipv6DHCP[].fromPoolAnnotation` |

#### Map to Array Conversions

The following fields have been converted from untyped maps to structured
arrays:

##### NetworkDataLinkBond.parameters

v1beta1 structure:

```json
"parameters": {
  "key1": "value1",
  "key2": "value2"
}
```

v1beta2 structure:

```json
"parameters": [
  {
    "name": "key1",
    "value": "value1"
  },
  {
    "name": "key2",
    "value": "value2"
  }
]
```

YAML migration example:

```yaml
# v1beta1
spec:
  networkData:
    links:
      bonds:
      - id: bond0
        parameters:
          mode: "802.3ad"
          xmit_hash_policy: "layer3+4"
```

```yaml
# v1beta2
spec:
  networkData:
    links:
      bonds:
      - id: bond0
        parameters:
        - name: mode
          value: "802.3ad"
        - name: xmit_hash_policy
          value: "layer3+4"
```

##### status.indexes

v1beta1 structure:

```json
"indexes": {
  "machine1": 0,
  "machine2": 1
}
```

v1beta2 structure:

```json
"indexes": [
  {
    "name": "machine1",
    "index": 0
  },
  {
    "name": "machine2",
    "index": 1
  }
]
```

#### Metal3DataTemplate TemplateReference Removed

The `TemplateReference` field was removed from `Metal3DataTemplate`.

**Migration:** Remove all usage of the `TemplateReference` field from your
manifests.

#### New Types

**IndexEntry** - Used in `Metal3DataTemplate.status.indexes`:

```go
Name  string // required
Index int32  // required
```

**NetworkDataLinkBondParam** - Used in
`Metal3DataTemplate.spec.networkData.links.bond.parameters`:

```go
Name  string                   // required
Value apiextensionsv1.JSON     // optional
```

### Metal3Data

#### Metal3Data Type Changes (Pointer vs Value)

Value to Pointer:

| Field | Type Change |
|-------|-------------|
| `spec.index` | int32 → *int32 |
| `status.ready` | bool → *bool |

Pointer to Value:

| Field | Type Change |
|-------|-------------|
| `status.errorMessage` | *string → string |

#### Metal3Data Fields with Added omitzero

| Field |
|-------|
| `spec` |

#### Metal3Data TemplateReference Removed

The `TemplateReference` field was removed from `Metal3Data`.

**Migration:** Remove all usage of the `TemplateReference` field from your
manifests.

### Metal3Remediation

#### Metal3Remediation Type Changes (int to int32)

The following JSON field types have been changed from `int` to `int32`:

| Field Path | Type Change |
|-----------|-------------|
| `spec.strategy.retryLimit` | int → int32 |
| `status.retryCount` | int → int32 |

#### Timeout Field Change

The `timeout` field in `RemediationStrategy` has been replaced with
`timeoutSeconds`:

| v1beta1 Field | v1beta2 Field |
|--------------|---------------|
| `timeout` (*metav1.Duration) | `timeoutSeconds` (int32) |

- v1beta1 `timeout` field: accepts duration strings (e.g., `"600s"`, `"10m"`)
- v1beta2 `timeoutSeconds` field: accepts integer seconds only (e.g., `600`)

The minimum allowed value is 100 seconds. The default is 600 seconds.

**Example migration:**

```yaml
# v1beta1
spec:
  strategy:
    timeout: 600s
```

```yaml
# v1beta2
spec:
  strategy:
    timeoutSeconds: 600
```

```yaml
# v1beta1
spec:
  strategy:
    timeout: 10m
```

```yaml
# v1beta2
spec:
  strategy:
    timeoutSeconds: 600
```

### Metal3RemediationTemplate

#### Metal3RemediationTemplate Fields with Added omitzero

| Field |
|-------|
| `spec` |
| `status` |

### Conditions Format Change

The conditions type has changed from Cluster API's `clusterv1beta1.Conditions`
to Kubernetes native `metav1.Condition` for Metal3Cluster and Metal3Machine:

| v1beta1 Condition Type | v1beta2 Condition Type |
|-----------------------|------------------------|
| `clusterv1beta1.Conditions` | `[]metav1.Condition` |

This means:

- v1beta1: Conditions use CAPI-specific format with `severity` field
- v1beta2: Conditions use standard Kubernetes format

See the
[CAPI proposal](https://github.com/kubernetes-sigs/cluster-api/blob/main/docs/proposals/20240916-improve-status-in-CAPI-resources.md)
for more context.

### CLI Flag Rename

The CAPM3 CLI flag was renamed:

| v1beta1 Flag | v1beta2 Flag |
|-------------|--------------|
| `enableBMHNameBasedPreallocation` | `enable-bmh-name-based-preallocation` |

**Migration:** Update your deployment manifests or command-line arguments to
use the new flag name.

## Non-Breaking Changes

### Unhealthy Annotation Update

The unhealthy annotation has been updated from `capi.metal3.io/unhealthy`
to `capm3.metal3.io/unhealthy`.

The old annotation is still kept for the migration period but is deprecated.
Users are advised to update their deployments to use the new annotation.

**Example migration:**

```yaml
# v1beta1 (deprecated, still works)
metadata:
  annotations:
    capi.metal3.io/unhealthy: ""
```

```yaml
# v1beta2 (recommended)
metadata:
  annotations:
    capm3.metal3.io/unhealthy: ""
```

## Migration Steps

1. **Backup your current resources**: Before migrating, ensure you have
   backups of all your Metal3 custom resources.

1. **Update Metal3DataTemplate resources**:
   - Rename `ipAddressesFromIPPool` to `ipAddressesFromPool`
   - Rename `prefixesFromIPPool` to `prefixesFromPool`
   - Rename `gatewaysFromIPPool` to `gatewaysFromPool`
   - Rename `dnsServersFromIPPool` to `dnsServersFromPool`
   - Convert `parameters` in bond configurations from map to array format
   - Remove any `TemplateReference` fields

1. **Update Metal3Machine resources**:
   - Rename `format` to `diskFormat` in `spec.image`
   - Replace `noCloudProvider` with `cloudProviderEnabled` (inverted logic)

1. **Update Metal3Remediation resources**:
   - Replace `timeout` with `timeoutSeconds` (convert duration to seconds)

1. **Update CAPM3 deployment**:
   - Change CLI flag from `enableBMHNameBasedPreallocation` to
     `enable-bmh-name-based-preallocation`

1. **Update annotations** (optional but recommended):
   - Update `capi.metal3.io/unhealthy` to `capm3.metal3.io/unhealthy`

1. **Update automation/tooling that reads conditions**:
   - Update code that checks `status.ready` to use
     `status.initialization.provisioned` (affects Metal3Cluster, Metal3Machine)
   - Update code that reads `status.conditions` to handle
     `metav1.Condition` format (affects Metal3Cluster, Metal3Machine)
   - Update condition type checks from `AssociateBMH` to
     `AssociateBareMetalHost` (affects Metal3Machine)
   - Update condition type checks from `KubernetesNodeReady` to
     `AssociateMetal3MachineMetaData` (affects Metal3Machine)
   - Remove any code that depends on `status.phase` (affects Metal3Machine,
     no longer available)
   - Note that `status.failureReason` and `status.failureMessage` are now
     at `status.deprecated.v1beta1.*` and no longer represent terminal errors
     (affects Metal3Cluster, Metal3Machine).
     Use `status.conditions` for error information instead
