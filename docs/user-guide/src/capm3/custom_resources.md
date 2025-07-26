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

## Key Concepts

### Data Templates and Instances

CAPM3 uses a template-based approach for generating host-specific configuration
data:

1. **Metal3DataTemplate**: Contains templates for metadata and network
   configuration that will be rendered for each host
2. **Metal3Data**: Represents the actual rendered data for a specific host,
   created from a template

### Metadata and Network Data

- **Metadata**: Contains host-specific information like hostnames, labels, and
  custom key-value pairs
- **Network Data**: Defines the network configuration including interfaces, IP
  addresses, routes, and DNS settings

### Index Management

CAPM3 automatically manages indexes for hosts to ensure unique identification and
proper resource allocation. Each Metal3Data instance gets a unique index that is
used in naming and resource allocation.

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

1. Create a Metal3DataTemplate with your desired metadata and network
   configuration
2. Reference the template in your Metal3MachineTemplate
3. CAPM3 automatically creates Metal3Data instances and renders the
   configuration

### Advanced Usage

- Use IP pools for dynamic IP address allocation
- Configure complex network topologies with bonds, VLANs, and multiple
  interfaces
- Implement custom metadata generation based on host properties

## Related Documentation

- [Metal3Data](metal3data.md) - Detailed documentation for the Metal3Data
  resource
- [Metal3DataTemplate](metal3datatemplate.md) - Detailed documentation for the
  Metal3DataTemplate resource
- [Cluster API Documentation](https://cluster-api.sigs.k8s.io/) - General
  Cluster API concepts and usage
