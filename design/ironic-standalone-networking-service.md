<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Add support for Ironic Networking service

## Status

provisional

## Summary

This design proposes adding support for the Ironic Networking service to
Metal³, enabling automatic configuration of Top-of-Rack (ToR) switch ports
during the lifecycle of bare metal nodes. The Ironic Networking service
provides a pluggable framework for managing switch port configurations such as
VLAN assignments, port modes (access/trunk/hybrid), and port channel settings.
This integration will allow Metal³ users to define network configurations
declaratively through Kubernetes CRDs, which will be automatically applied to
physical switch ports as nodes are provisioned and deprovisioned.  Switch ports
will be identified using LLDP information collected during initial inspection
of nodes during enrollment.

## Motivation

Currently, Metal³ users must manually configure ToR switch ports before
provisioning bare metal hosts, which creates operational overhead and
opportunities for misconfiguration. The Ironic Networking service provides a
standardized way to automate switch port configuration, but Metal³ lacks
integration with this service. By adding support for Ironic Networking, Metal³
can provide a fully automated, declarative workflow for both server and network
provisioning.

### Goals

- Enable optional support for Ironic Networking service in Metal³ deployments
- Allow users to declaratively define switch configurations through Kubernetes
  CRDs
- Automatically configure switch ports during node provisioning and
  deprovisioning
- Maintain backward compatibility for deployments not using Ironic Networking

### Non-Goals

- Supporting all possible switch vendor-specific features beyond the base
  capabilities provided by networking-generic-switch
- Implementing custom switch drivers (users will use existing drivers from
  networking-generic-switch)
- Managing switch infrastructure itself (firmware updates, switch provisioning,
  etc.)
- Supporting dynamic network reconfiguration after node deployment (initial
  scope is provisioning-time configuration only)

## Proposal

This proposal introduces four main components:

1. **New CRDs**: `IronicSwitch` and `HostNetworkAttachment` to define
   switch configurations and network interface configurations respectively
2. **Enhanced Ironic CRD**: Add service enablement flag and service
   network configuration to the `ironic.metal3.io` CRD
3. **Enhanced BareMetalHost CRD**: Add `networkInterfaces` field to reference
   network configurations for each network interface
4. **Ironic Networking container**: Deploy the Ironic Networking service
   alongside the existing metal3-ironic container

### User Stories

#### Story 1

As a Metal³ operator, I want to define my ToR switch configurations once in
Kubernetes CRDs so that Metal³ can automatically manage switch port
configurations without manual intervention.

The operator creates `IronicSwitch` resources for each ToR switch:

```yaml
apiVersion: metal3.io/v1alpha1
kind: IronicSwitch
metadata:
  name: rack1-tor1
  namespace: default-ironic-namespace
spec:
  driverType: generic-switch
  deviceType: dell_os10
  address: 192.168.1.10
  credentials:
    type: "password"
    secretName: switch-credentials
  macAddress: 3e:c5:c0:cb:fa:f6
```

Metal³ automatically generates the Ironic Networking switch configuration file
and restarts the service when switches are added or modified.

The credentials Secret is expected to contain keys for the `username`,
`password`, and (optionally) `enable-secret`.

#### Story 2

As a Metal³ user, I want to define network configurations for my bare metal
hosts declaratively so that switch ports are automatically configured when nodes
are provisioned.

The user creates a `HostNetworkAttachment` defining the desired network
configuration for an access mode port for the primary network interface:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostNetworkAttachment
metadata:
  name: machine-network-VLAN100
  namespace: some-cluster-namespace
spec:
  mode: access
  nativeVLAN: 100
```

The user optionally creates other `HostNetworkAttachment` instances
defining the desired network configuration for trunk ports for the secondary
network interface(s):

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostNetworkAttachment
metadata:
  name: data-network-VLANs-200-202
  namespace: some-cluster-namespace
spec:
  mode: trunk
  allowedVLANs: [200, 201, 202]
```

Then references them in the `BareMetalHost`:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: worker-1
  namespace: some-host-namespace
spec:
  # ... other fields ...
  networkInterfaces:
  - macAddress: "aa:bb:cc:dd:ee:01"
    networkAttachment:
      namespace: some-cluster-namespace
      name: machine-network-VLAN100
  - macAddress: "aa:bb:cc:dd:ee:02"
    networkAttachment:
      namespace: some-cluster-namespace
      name: data-network-VLANs-200-202
```

When the host is provisioned, Metal³ automatically configures the corresponding
switch port for the primary interface to access mode on VLAN 100, and the
secondary interface to trunk mode with tagged VLANs 200-202.

Ideally, `HostNetworkAttachment` instances should only be referenced by
`BareMetalHost` instances after initial inspection so that NIC information is
present in the `HardwareData` object and available for validation of the
network interface info by a validation webhook. If inspection has not yet run
the validation webhook _could_ defer validation until the end of the initial
inspection phase.

#### Story 3

As a Metal³ operator, I want to configure a service network VLAN that allows
bare metal hosts to communicate with Ironic during inspection and provisioning,
separate from their final tenant network configuration.

The operator configures the service network in the Ironic resource:

```yaml
apiVersion: metal3.io/v1alpha1
kind: Ironic
metadata:
  name: default
  namespace: default-ironic-namespace
spec:
  networkingService:
    enabled: true
    networkDriver: standalone-experimental
    serviceNetwork:
      mode: access
      nativeVLAN: 10
```

Ironic will ensure that switch ports are always reset to this VLAN
configuration whenever a node is deprovisioned or whenever the final networking
configuration of a port (the tenant network) must be cleared.  This
ensures that it is always possible to delete the BMH and re-add it without any
manual intervention required on the switch.

## Design Details

### New CRDs

#### IronicSwitch

The `IronicSwitch` CRD represents a physical ToR switch managed by Ironic
Networking:

```go
// SwitchCredentialType defines the type of credential used for switch authentication.
type SwitchCredentialType string

const (
    // SwitchCredentialTypePassword indicates password-based authentication
    SwitchCredentialTypePassword SwitchCredentialType = "password"
    // SwitchCredentialTypePublicKey indicates SSH public key-based authentication
    SwitchCredentialTypePublicKey SwitchCredentialType = "publicKey"
)

// SwitchCredentials defines the credentials used to access the switch.
type SwitchCredentials struct {
    // Type specifies the type of credential used for authentication.
    // +kubebuilder:validation:Enum=password;publicKey
    Type SwitchCredentialType `json:"type"`

    // The name of the secret containing the switch credentials.
    // For password authentication, requires key "password".
    // For SSH key authentication, requires keys "username", "privateKey", and optionally "publicKey".
    SecretName string `json:"secretName"`
}

// IronicSwitchSpec defines the desired state of IronicSwitch.
type IronicSwitchSpec struct {
    // Important: Run "make generate manifests" to regenerate code
    // after modifying this file

    // Address is the network address of the TOR switch (IP address or hostname).
    // +kubebuilder:validation:Required
    Address string `json:"address"`

    // MACAddress is the MAC address of the switch management interface.
    // +kubebuilder:validation:Pattern=`[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}`
    MACAddress string `json:"macAddress,omitempty"`

    // DriverType specifies the type of driver to use for switch management.
    // Examples: "cisco", "arista", "juniper", "dell", "generic"
    // +kubebuilder:validation:Required
    DriverType string `json:"driverType"`

    // DeviceType specifies the specific device type or model of the switch.
    // This helps with driver-specific functionality.
    DeviceType string `json:"deviceType,omitempty"`

    // Credentials defines how to authenticate with the switch.
    // +kubebuilder:validation:Required
    Credentials SwitchCredentials `json:"credentials"`

    // Port specifies the management port to connect to (e.g., SSH port 22, HTTPS port 443).
    // If not specified, the driver will use its default port.
    // +kubebuilder:validation:Minimum=1
    // +kubebuilder:validation:Maximum=65535
    // +optional
    Port *int32 `json:"port,omitempty"`

    // DisableCertificateVerification disables verification of server 
    // certificates when using HTTPS to connect to the switch. This is 
    // required when the server certificate is self-signed, but is insecure 
    // because it allows a man-in-the-middle to intercept the connection.
    // +optional 
    DisableCertificateVerification *bool `json:"disableCertificateVerification,omitempty"`
}
```

#### HostNetworkAttachment

The `HostNetworkAttachment` CRD defines how a switch port should be
configured:

```go
// SwitchportMode defines the switchport mode for network interfaces.
// +kubebuilder:validation:Enum=access;trunk;hybrid
type SwitchportMode string

const (
    // SwitchportModeAccess sets the interface to access mode (single VLAN)
    SwitchportModeAccess SwitchportMode = "access"
    // SwitchportModeTrunk sets the interface to trunk mode (multiple VLANs)
    SwitchportModeTrunk SwitchportMode = "trunk"
    // SwitchportModeHybrid sets the interface to hybrid mode (access + trunk)
    SwitchportModeHybrid SwitchportMode = "hybrid"
)

// HostNetworkAttachmentSpec defines the desired switchport configuration.
type HostNetworkAttachmentSpec struct {
    // Mode defines the switchport mode (access, trunk, or hybrid)
    // +kubebuilder:validation:Enum=access;trunk;hybrid
    // +kubebuilder:default=access
    Mode SwitchportMode `json:"mode,omitempty"`

    // NativeVLAN is the untagged VLAN ID for the port
    // +kubebuilder:validation:Minimum=1
    // +kubebuilder:validation:Maximum=4094
    NativeVLAN int32 `json:"nativeVLAN,omitempty"`

    // AllowedVLANs is a list of VLAN IDs allowed on trunk/hybrid ports
    // Only valid for trunk and hybrid modes
    // +optional
    AllowedVLANs []int32 `json:"allowedVLANs,omitempty"`
}
```

### Enhanced Ironic CRD

Add the following fields to the `IronicSpec`:

```go
type ServiceNetworkConfig struct {
    // Mode specifies the switch port mode for service operations
    Mode PortMode `json:"mode"`

    // NativeVLAN specifies the native VLAN ID for service operations
    NativeVLAN int `json:"nativeVLAN"`

    // AllowedVLANs specifies the list of allowed VLANs for trunk/hybrid modes
    AllowedVLANs []int `json:"allowedVLANs,omitempty"`
}

type NetworkingService {
    // Enabled enables the Ironic Networking Service integration
    Enabled  bool `json:"enabled,omitempty"`

    // NetworkDriver sets the Ironic network interface on nodes to this value
    // if provided.  This defaults to "standalone-experimental".
    // +optional
    NetworkDriver *string `json:"networkDriver,omitempty""`

    // ServiceNetwork defines the network configuration for Ironic service 
    // operations. This configuration is applied during inspection, cleaning, 
    // provisioning, etc. 
    ServiceNetwork *ServiceNetworkConfig `json:"serviceNetwork,omitempty"`
}

type IronicSpec struct {
    // ... existing fields ...

    // NetworkingService provides configuration attributes for the Networking
    // Service if it is required.
    // +optional
    NetworkingService *NetworkingService `json:"networkingService,omitempty"`
}
```

### Enhanced BareMetalHost CRD

Add the following field to the `BareMetalHostSpec`:

```go
type BareMetalHostSpec struct {
    // ... existing fields ...

    // NetworkInterfaces defines the network configuration for each NIC
    NetworkInterfaces []NetworkInterface `json:"networkInterfaces,omitempty"`
}

// NetworkInterface defines the network configuration for a specific interface.
type NetworkInterface struct {
    // Name of the network interface (e.g., "eth0", "ens1f0")
    // This must match the name of a NIC in status.hardware.nics.
    // If MACAddress is set then this field is ignored.
    // +optional
    Name string `json:"name"`

    // MAC address of the network interface.  This must match the MAC address
    // of the network interface in status.hardware.nics.
    // +optional
    // +kubebuilder:validation:Pattern=`[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}`
    MACAddress string `json:"macAddress,omitempty"`

    // NetworkAttachment references the HostNetworkAttachment for this interface
    // +optional
    NetworkAttachment *NetworkAttachmentRef `json:"networkAttachment,omitempty"`
}

type NetworkAttachmentReference struct {
    // Name of the HostNetworkAttachment
    Name string `json:"name"`

    // Namespace of the HostNetworkAttachment (defaults to BMH namespace)
    Namespace string `json:"namespace,omitempty"`
}
```

### Ironic Configuration

When `Ironic.NetworkingService.Enabled` is true, Metal³ will configure
Ironic with the following sections:

```ini
...

[networking_json_rpc]
host_ip = <IRONIC_NETWORKING_SERVICE_IP>
port = 6190
auth_strategy = http_basic
auth_type = http_basic
http_basic_auth_user_file = /etc/ironic/htpasswd
username = admin
password = <GENERATED_PASSWORD>

[networking]
rpc_transport = json-rpc
idle_network = <SERVICE_NETWORK_MODE>/<SERVICE_NETWORK_NATIVE_VLAN>
provisioning_network = <SERVICE_NETWORK_MODE>/<SERVICE_NETWORK_NATIVE_VLAN>
```

For nodes with network configurations defined, the network interface driver
should be set to `standalone-experimental`.

### Ironic Networking Service Configuration

Metal³ will generate a configuration file for the Ironic Networking service:

```ini
[DEFAULT]
debug = <DEBUG_SETTING>
rpc_transport = json-rpc
auth_strategy = http_basic
http_basic_auth_user_file = /etc/ironic/htpasswd

[service_catalog]
auth_type = http_basic
username = admin
password = <GENERATED_PASSWORD>
endpoint_override = http://<IRONIC_API_INTERNAL_IP>:6385

[networking_json_rpc]
host_ip = <IRONIC_NETWORKING_SERVICE_IP>
port = 8090
auth_strategy = http_basic
auth_type = http_basic
http_basic_auth_user_file = /etc/ironic/htpasswd
username = admin
password = <GENERATED_PASSWORD>

[networking]
switch_config_file = /etc/ironic/networking/switch-configs.conf
driver_config_dir = /etc/ironic/drivers
enabled_switch_drivers = generic-switch
serialize_switch_operations = True
allowed_VLANs =
denied_VLANs =
allow_port_channels = False
```

### Switch Configuration File

For each `IronicSwitch` resource, Metal³ will generate an entry in the
switch configuration file:

```ini
[switch:<SWITCH_NAME>]
driver_type = <DRIVER_TYPE>
device_type = <DEVICE_TYPE>
address = <ADDRESS>
username = <USERNAME>
password = <PASSWORD>
enable_secret = <ENABLE_SECRET>
mac_address = <MAC_ADDRESS>
```

This file will be stored in a Secret and mounted to the Ironic Networking
container. When any `IronicSwitch` is created, updated, or deleted, the
Secret will be regenerated and the Ironic Networking service will be restarted.

### Ironic Port Configuration

When a `BareMetalHost` has `networkInterfaces` defined, Metal³ will update the
corresponding Ironic Port's `extra` field with a `switchport` dictionary
conforming to the schema:

```json
{
  "extra": {
    "switchport": {
      "mode": "access",
      "native_VLAN": 100,
      "allowed_VLANs": [200, 300, 400]
    }
  }
}
```

This information represents one half of the details required to configure the
switch port.  The identity of the switch and the attached port are obtained
from LLDP and stored in the port's `local_link_connection` field, which is
populated during initial inspection.

### Implementation Details/Notes/Constraints

1. **Service Network Setup**: Before creating `BareMetalHost` resources, users
   must ensure that server switch ports are manually configured to the service
   VLAN to allow initial communication with Ironic. This enables the initial
   inspection to complete which provides LLDP information for the Node. This
   is a one-time setup requirement. (This is known as the "idle" VLAN in
   Ironic terminology.)

2. **Validation Timing**: Network interface validation can only occur after
   inspection completes, as network interface information is not available
   before that point. A condition in the `BareMetalHost` status field will be
   updated after inspection to indicate if Network interfaces are valid.

3. **HostNetworkAttachment Immutability**: To prevent accidental
   misconfiguration, users cannot modify or delete a `HostNetworkAttachment`
   while it is referenced by any `BareMetalHost`. The validation webhook will
   reject such operations.

4. **Switch Configuration Changes**: When `IronicSwitch` resources are
   modified, the entire switch configuration Secret is regenerated and the
   Ironic Networking service is restarted. This may cause brief service
   interruptions.

5. **Credential Management**: Switch credentials are stored in Kubernetes
   Secrets and referenced by `IronicSwitch` resources. The Metal³ controller
   will read these Secrets to populate the switch configuration file.

6. **Container Deployment**: The Ironic Networking service will run as a
   separate container in the metal3 pod, alongside the existing metal3-ironic
   container. It will share the `/etc/ironic` volume for configuration files
   and the htpasswd file.

7. **Network Driver Selection**: The Baremetal Operator will automatically set
   the Ironic node's network interface driver to `standalone-experimental`
   when:
   - `enabled` is true in the `Ironic.NetworkingService.Enabled` resource
     attribute, AND
   - The `BareMetalHost` has `networkInterfaces` defined

8. **Service Network Scope**: The service network configuration applies to a
   subset of the Ironic provider networks. Specifically, it configures only
   the idle and inspection networks. All other provider networks (provisioning,
   cleaning, rescuing, servicing) will default to the tenant VLAN configured on
   each port. This means only two VLANs are needed: the service VLAN for
   Ironic operations, and the tenant VLAN(s) configured per-port.

9. **Generic Switch Device Types**: The `deviceType` field in `IronicSwitch`
   must be one of the device types supported by networking-generic-switch.
   Valid values include, but are not limited to, `cisco_ios`, `dell_force10`,
   `juniper_junos`.  The full list can be found in the
    [setup.cfg](https://github.com/openstack/networking-generic-switch/blob/8c0f1ec30bd0d765cd539de068a0c02cd9c8d699/setup.cfg#L35)
    of the networking-generic-switch project.

### Risks and Mitigations

**Risk**: If Metal³'s instantiation of Ironic is not configured to use
persistent storage for the Ironic database, and the Ironic Pod is restarted
then all node and port information is lost, including the LLDP information
and switch port configuration derived from the BMH configuration.

**Mitigation**: The BMH reconciler can be modified to restore the last known
set of Port objects including their `port.extra.switchport` and
`port.local_link_connection` attributes using information from the
`HardwareData` object.

**Risk**: Switch configuration errors could render hosts unreachable or prevent
provisioning.

**Mitigation**: Implement thorough validation of `IronicSwitch` and
`HostNetworkAttachment` resources. Add status conditions to report
configuration errors. Ensure service network is properly configured before
attempting to provision hosts.

**Risk**: Credential exposure in switch configuration files.

**Mitigation**: Store the switch configuration file in a Kubernetes Secret with
appropriate RBAC restrictions. Use Secret references for credentials in the
`IronicSwitch` CRD rather than embedding them directly.

**Risk**: Ironic Networking service failures could impact provisioning
workflows.

**Mitigation**: Make the feature optional via the
`Ironic.NetworkingService.Enabled` flag. Implement health checks for the
Ironic Networking service. Add detailed status reporting and error messages.

### Work Items

1. Define and implement the `IronicSwitch` CRD and controller
2. Define and implement the `HostNetworkAttachment` CRD and controller
3. Extend the `Ironic` CRD with `NetworkingService` information
4. Extend the `BareMetalHost` CRD with `networkInterfaces` field
5. Implement switch configuration Secret generation in the IronicSwitch
   controller
6. Populate `HardwareData` with LLDP information from inspection results
7. Implement Ironic Networking service container deployment
8. Implement Ironic configuration updates for networking support
9. Implement Ironic Port `extra.switchport` population in the BMH controller
10. Implement validation logic for network interface configurations
11. Add status reporting for network configuration state
12. Implement re-population of Ironic Node/Port information if database is
    is not persistent
13. Update Metal³ documentation with Ironic Networking setup instructions
14. Create example manifests for common switch configurations

### Dependencies

- **Ironic Networking service**: Requires the Ironic Networking service
  container image to be available. This is part of the Ironic image; therefore,
  the only requirement is to use a version of Ironic that supports the new
  service.  Version `TBD` supports the required service.

- **networking-generic-switch**: The generic-switch driver depends on the
  networking-generic-switch Python library, which must be installed in the
  Ironic Networking container.

- **Switch firmware**: Switches must be supported by the
  `networking-generic-switch` driver.

### Test Plan

**Unit Tests**:

- CRD validation logic for `IronicSwitch` and `HostNetworkAttachment`

- Switch configuration file generation

- Ironic configuration generation with networking sections

- Ironic Port `extra.switchport` field population

- Network interface validation logic

**Integration Tests**:

- TBD

### Upgrade / Downgrade Strategy

**Upgrade**:

- The feature is opt-in via `Ironic.NetworkingService.Enabled` flag, so
  existing deployments are unaffected

- Users can enable the feature by:
  1. Updating to a Metal³ version with Ironic Networking support
  2. Creating `IronicSwitch` resources for their switches
  3. Setting `Ironic.NetworkingService.Enabled: true` in the Ironic resource
  4. Defining `Ironic.NetworkingService.ServiceNetwork` configuration
  5. Creating `HostNetworkAttachment` resources
  6. Adding `networkInterfaces` to new `BareMetalHost` resources

**Downgrade**:

- Disabling the feature requires:
  1. Removing `networkInterfaces` from all `BareMetalHost` resources
  2. Setting `Ironic.NetworkingService.Enabled: false` in the Ironic resource
  3. Optionally deleting `IronicSwitch` and `HostNetworkAttachment`
     resources

- Downgrading to a Metal³ version without Ironic Networking support requires
  removing all new CRDs first

### Version Skew Strategy

**Metal³ Components**:

- The Baremetal Operator must be updated to understand the new CRDs and fields

- The Ironic container must be updated to a version supporting the networking
  service integration

- Both components should be updated together to ensure compatibility

**Ironic and Ironic Networking**:

- These are part of the same project; therefore, they should always be deployed
  together.

## Drawbacks

1. **Increased Complexity**: Adding Ironic Networking support increases the
   complexity of Metal³ deployments, requiring additional configuration and
   understanding of network concepts.

2. **Additional Resource Requirements**: Running the Ironic Networking service
   requires additional CPU and memory resources in the metal3 pod.

3. **Switch Compatibility**: The feature's usefulness depends on switch vendor
   support in networking-generic-switch. Users with unsupported switches cannot
   use the feature.

4. **Operational Overhead**: Managing switch configurations through Kubernetes
   CRDs requires learning new abstractions and may be less familiar than direct
   switch management.

5. **Initial Manual Setup**: Users must still manually configure the service
   VLAN on switch ports before bootstrapping, which doesn't fully eliminate
   manual switch configuration.  However, this should be a one-time operation.

## Alternatives

1. **External Network Automation Tools**: Users could use external tools like
   Ansible, Terraform, or vendor-specific automation to configure switches
   separately from Metal³. This keeps Metal³ simpler but requires users to
   coordinate two systems.

2. **Pre-configured Switches**: Require switches to be pre-configured with all
   necessary VLANs. This is simpler but less flexible and assumes a static
   configuration of servers used to deploy clusters.

3. **Direct Switch API Integration**: Build switch management directly into
   Metal³ without using Ironic Networking. This provides more control but
   requires implementing and maintaining switch drivers ourselves.

## Future Considerations

1. **Link Aggregation Support**: A future version of the Ironic Networking
   service may support Link Aggregation.

2. **Ironic API Evolution**: The approach to configuring switch port attributes
   onto Ironic Port is by using the `extra.switchport` attribute.  This is
   expected to evolve into a more structured part of the API, but the timeline
   for this work is unknown.  When it does evolve, Metal³ will have to
   evolve as well.

3. **Additional Switch Port Attributes**: A future version of the Ironic
   Networking Service may support the ability to set other switch port
   attributes such as, but not limited to, MTU and PTP configurations.

4. **Decoupling of the Ironic Networking Service**: In some contexts, operators
   may require exclusive control over the operation of the Ironic Networking
   Service -- meaning that they may want to run this process
   separate from the Metal³ deployment in such a way that they have exclusive
   control over the process and its configuration file.  In such a deployment,
   it would be unnecessary for Metal³ to directly manage the Ironic Networking
   service or the `IronicSwitch` CRDs.

## References

- [Ironic Networking Specification](https://specs.openstack.org/openstack/ironic-specs/specs/backlog/standalone-networking.html)
- [networking-generic-switch Project](https://github.com/openstack/networking-generic-switch)
- [networking-generic-switch Device Types](https://github.com/openstack/networking-generic-switch/blob/8c0f1ec30bd0d765cd539de068a0c02cd9c8d699/setup.cfg#L35)
