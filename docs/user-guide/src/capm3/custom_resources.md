# Custom Resources

Cluster API Provider Metal3 (CAPM3) extends the Kubernetes API with several custom
resources that enable the management of bare metal infrastructure through the
Cluster API framework. These resources provide the necessary abstractions for
defining, configuring, and managing bare metal hosts and their associated
metadata.

## Overview

The custom resources in CAPM3 are designed to work together to provide a complete
solution for bare metal cluster management:

- **Metal3DataTemplate**: Defines templates for generating metadata and network
  configuration for bare metal hosts
- **Metal3Data**: Represents the rendered data instances created from templates
- **Metal3Machine**: Represents a bare metal machine in the cluster
- **Metal3Cluster**: Represents a bare metal cluster

## Resource Relationships

```mermaid
Metal3Cluster
    ↓
Metal3MachineTemplate
    ↓
Metal3Machine
    ↓
Metal3DataClaim
    ↓
Metal3Data ← Metal3DataTemplate
```

## Usage Patterns

### Basic Usage

1. Create a `Metal3DataTemplate` with your desired metadata and network
   configuration
2. Reference the template in your `Metal3MachineTemplate`
3. CAPM3 automatically creates `Metal3Data` instances and renders the
   configuration

### Advanced Usage

- Use IP pools for dynamic IP address allocation
- Configure complex network topologies with bonds, VLANs, and multiple
  interfaces
- Implement custom metadata generation based on host properties
