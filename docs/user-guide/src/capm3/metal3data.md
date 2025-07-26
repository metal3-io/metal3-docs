# Metal3Data

The `Metal3Data` resource represents the rendered data instances created from
`Metal3DataTemplate` objects. It contains the host-specific configuration data
that has been generated for a particular bare metal host and links to the
associated secrets.

## Overview

A `Metal3Data` object is created automatically by the CAPM3 controller when a
`Metal3Machine` references a `Metal3DataTemplate`. It contains:

- **Index**: A unique index assigned to the host
- **Claim reference**: Link to the `Metal3DataClaim` that requested this data
- **Secret references**: Links to the generated metadata and network data
  secrets
- **Template reference**: Link to the `Metal3DataTemplate` that was used

## API Reference

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3Data
metadata:
  name: <template-name>-<index>
  namespace: <namespace>
  ownerReferences:
  - apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    controller: true
    kind: Metal3DataTemplate
    name: <template-name>
spec:
  templateReference: <reference-name>  # Optional
  index: <index>
  claim:
    name: <machine-name>
    namespace: <namespace>
  metaData:
    name: <machine-name>-metadata-<index>
    namespace: <namespace>
  networkData:
    name: <machine-name>-networkdata-<index>
    namespace: <namespace>
  template:
    name: <template-name>
    namespace: <namespace>
status:
  ready: <boolean>
  error: <boolean>
  errorMessage: "<error-message>"
```

## Lifecycle

### Creation Process

1. **Claim Creation**: When a `Metal3Machine` references a `Metal3DataTemplate`,
   a `Metal3DataClaim` is created
2. **Index Assignment**: The controller selects the lowest available index for
   the new claim
3. **Data Generation**: A `Metal3Data` object is created with the assigned
   index
4. **Secret Generation**: The controller renders the template and creates
   metadata and network data secrets
5. **Status Update**: The `ready` status is set to `true` when all secrets are
   created successfully

### Index Management

Indexes are managed automatically by the controller:

- **Starting Point**: Indexes always start from 0
- **Increment**: Each new index increments by 1
- **Availability Check**: The controller selects the lowest available index not
  in use
- **Conflict Resolution**: If a conflict occurs during creation, the controller
  retries with a new index

### Naming Convention

The `Metal3Data` object name follows the pattern:

```text
<template-name>-<index>
```

For example:

- Template: `worker-template`
- Index: `0`
- Result: `worker-template-0`

## Secret Generation

The controller generates two types of secrets for each `Metal3Data` instance:

### Metadata Secret

Contains host-specific metadata in YAML format.

**Naming**: `<machine-name>-metadata-<index>`

**Content**: Rendered metadata based on the template configuration

### Network Data Secret

Contains network configuration in JSON format following the
[Nova network_data.json format](https://docs.openstack.org/nova/latest/user/metadata.html#openstack-format-metadata).

**Naming**: `<machine-name>-networkdata-<index>`

**Content**: Rendered network configuration based on the template

## Template Reference Management

The `templateReference` field enables linking to specific template versions:

- **Backward Compatibility**: If not set, the controller matches by template
  name
- **Version Control**: When set, enables template versioning and updates
- **Transition Support**: Allows migration from old templates to new ones

## Complete Example

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3Data
metadata:
  name: worker-template-0
  namespace: default
  ownerReferences:
  - apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    controller: true
    kind: Metal3DataTemplate
    name: worker-template
spec:
  templateReference: worker-v1
  index: 0
  claim:
    name: worker-0
    namespace: default
  metaData:
    name: worker-0-metadata-0
    namespace: default
  networkData:
    name: worker-0-networkdata-0
    namespace: default
  template:
    name: worker-template
    namespace: default
status:
  ready: true
  error: false
  errorMessage: ""
```

## Usage Patterns

### Basic Usage

1. **Create a Metal3DataTemplate** with your desired configuration
2. **Reference the template** in your Metal3MachineTemplate
3. **Create Metal3Machines** - CAPM3 automatically creates Metal3Data
   instances
4. **Access the secrets** for provisioning BareMetalHosts

### Manual Secret Creation

If a `Metal3Machine` is created without a `dataTemplate` but with `metaData` or
`networkData` fields set, the controller will:

- Look for existing secrets with the specified names
- Set the status fields accordingly
- Start BareMetalHost provisioning when secrets are available

### Dynamic Secret Creation

When a `Metal3Machine` references a `dataTemplate`:

1. A `Metal3DataClaim` is created automatically
2. The claim controller creates a `Metal3Data` instance
3. The `Metal3Data` controller generates the required secrets
4. The `Metal3Machine` controller uses the secrets for provisioning

### Hybrid Configuration

You can mix template-based and manual configuration:

- Set `dataTemplate` for one type of data (e.g., network data)
- Set `metaData` or `networkData` directly for the other type
- The manual configuration overrides the template for that specific secret

## Error Handling

### Common Error Scenarios

1. **Template Not Found**: The referenced `Metal3DataTemplate` doesn't exist
2. **Index Conflicts**: Multiple controllers try to use the same index
3. **Secret Creation Failure**: Unable to create the required secrets
4. **Template Rendering Errors**: Invalid template configuration

### Error Status

When errors occur, the status fields are updated:

```yaml
status:
  ready: false
  error: true
  errorMessage: "Failed to create metadata secret: template validation failed"
```

## Best Practices

1. **Monitor Status**: Check the `ready` and `error` status fields
2. **Handle Errors**: Implement proper error handling for failed data
   generation
3. **Use Indexing**: Leverage the automatic indexing for consistent naming
4. **Template Validation**: Validate templates before deployment
5. **Secret Management**: Ensure proper RBAC for secret access

## Troubleshooting

### Common Issues

**Issue**: Metal3Data stuck in "not ready" state

- **Check**: Template configuration and validation
- **Solution**: Verify template syntax and referenced resources

**Issue**: Index conflicts

- **Check**: Existing Metal3Data objects and their indexes
- **Solution**: Clean up orphaned objects or adjust indexing strategy

**Issue**: Secret creation failures

- **Check**: RBAC permissions and namespace access
- **Solution**: Ensure proper permissions for secret creation

### Debugging Commands

```bash
# Check Metal3Data status
kubectl get metal3data -n <namespace>

# View Metal3Data details
kubectl describe metal3data <name> -n <namespace>

# Check generated secrets
kubectl get secrets -n <namespace> | grep <machine-name>

# View secret content
kubectl get secret <secret-name> -n <namespace> -o yaml
```

## Related Resources

- [Metal3DataTemplate](metal3datatemplate.md) - Template definitions
- [Metal3Machine](../introduction.md) - Machine management
- [BareMetalHost](../bmo/introduction.md) - Host provisioning
- [IP Address Manager](../ipam/introduction.md) - IP pool management
