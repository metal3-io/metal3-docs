<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# serial-console

## Status

provisional

## Summary

Provide on-demand serial console access through a namespaced
`HostSerialConsole` resource. Creating the request opens access to the matching
BareMetalHost; deleting it closes access. A dedicated controller manages the
backend and exposes its TCP listener through a Kubernetes Service.

The initial scope is an opt-in feature for trusted infrastructure
administrators, using Ironic's IPMI serial-over-LAN (SOL) support.

## Motivation

A host with boot or networking failures may still be reachable through its
BMC's serial console. A Kubernetes request lets administrators use BMO's
existing host/provisioner relationship without direct management-network
access or knowledge of the backend console API.

### Goals

- Request and revoke access without changing host power or provisioning state.
- Preserve sessions across reconciliation and BMO restarts.
- Revoke backend access before the next workload begins.
- Keep the console controller and its permissions optional.

### Non-Goals

- Tenant authorization, authenticated gateways, or encrypted client transport.
- Web terminals, session recording, or simultaneous clients.
- Automatic Redfish discovery or support for every provisioner/BMC protocol.
- Configuring the guest operating system's serial console.

## Proposal

Introduce `HostSerialConsole` in `metal3.io/v1alpha1`. A request has the same
name and namespace as its BareMetalHost and an empty spec:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostSerialConsole
metadata:
  name: worker-0
  namespace: metal3
spec: {}
```

The request contains neither connection settings nor credentials, so
permission to request access is separate from permission to configure a host.
Deletion waits for cleanup through a finalizer.

The initial implementation uses Ironic's `ipmitool-socat` interface. Ironic
owns listener allocation and BMC communication. BMO gives each console a
stable in-cluster name: a ClusterIP Service on TCP port 2023 without a pod
selector, and an EndpointSlice pointing at Ironic's listener. No public
LoadBalancer or NodePort is created automatically.

## Design Details

The request is owned by the corresponding BMH. Admission and reconciliation
validate that the host exists and is not deleting or detached. Cleanup remains
possible after the host or its Secret disappears.

Status includes a Ready condition, the Service name, the connection URL, and
the Ironic node ID used for cleanup. It never contains credentials.

The initial implementation adds no connection settings to the BMH:

- IPMI-managed hosts reuse their management endpoint and credentials.
- Redfish-managed hosts use IPMI on the Redfish hostname, at the standard
   port, with the Redfish credentials.

For Redfish hosts, administrators must enable IPMI over LAN on the BMC and
ensure the account may use it; some BMCs disable it by default. BMCs exposing
IPMI on another address, port, or account are not supported initially. An
explicit override can be proposed later if needed.

### Implementation Details/Notes/Constraints

#### Optional deployment

A `HostSerialConsoles` feature gate, alpha and disabled by default, enables
the controller and admission handler, following the pattern used for
HostClaims.

The only new operator permissions are create, get, update, and delete on
Services and EndpointSlices in the watched namespaces. Ship them as an
optional Kustomize component with an additional role, so installations that do
not enable the feature are unchanged.

Console support is optional for provisioners. If a host's provisioner does not
support consoles, the request's status says so and nothing else happens.

#### Ironic node configuration

The Ironic node must use the `ipmitool-socat` console interface. BMO does not
set it: listing `ipmitool-socat` first among Ironic's enabled console
interfaces makes Ironic select it at enrollment for hardware types that
support it. This is part of the deployment's Ironic configuration.

Nodes enrolled before this configuration keep their existing console
interface, and an administrator must change it. Ironic only allows changing
an active node's interfaces in maintenance mode, and BMO does not put running
hosts into maintenance to open a console. Hosts that are already provisioned
therefore cannot get a console until they are deprovisioned or an
administrator puts them into maintenance. User documentation must state this.

When the feature is enabled, BMO adds the `ipmi_*` driver settings for
Redfish hosts during registration, derived from the current Redfish address
and credentials. Registration already rewrites the driver settings when
credentials change, so the IPMI password stays in sync and nothing needs to
be preserved separately.

#### Backend and routing

The controller only enables a console for a host in a stable state, such as
provisioned or available. The controller works from a cached copy of the host,
which can be slightly out of date, so it re-reads the host directly from the
API server immediately before enabling. Enabling is rare, so this costs little.

Before enabling access, the controller records the Ironic node ID in the
request status, so cleanup disables the right node. Asking Ironic for the
console address can interrupt an open session, so the controller fetches it
once when enabling and afterwards only reads ordinary node state.

The controller creates the Service and EndpointSlice with the request as
their owner, so Kubernetes deletes them with the request. Their names include
the request's UID, and the controller only updates objects it owns. It updates
the EndpointSlice when Ironic moves the listener. It does not watch Services or
EndpointSlices, so BMO does not cache them.

Ironic's listener address must be an IP address. Its address family sets the
Service's IP family and the EndpointSlice's address type.

Temporary errors and paused hosts leave existing routing in place, with
readiness reported as Unknown. Ready means the console and routing are set up,
not that the guest has printed anything.

#### Revocation and workload boundaries

Deleting a request disables the console in Ironic and removes the routing.
The finalizer stays until both are done, because removing the Service alone
would not close an open connection.

Ironic stops the console listener during teardown, but keeps the node's
`console_enabled` flag set and restarts the listener at the end of the next
deployment. Without intervention, access opened for one workload would reopen
for the next one.

BMO therefore closes console access as part of deprovisioning, without
waiting for the console controller:

1. The BMH controller deletes the host's `HostSerialConsole`. The console
   controller never enables a request that is being deleted, and the
   request's finalizer removes the routing.
1. Before requesting teardown, the Ironic provisioner disables the node's
   console and waits until Ironic reports it disabled. Hosts without an
   enabled console are unaffected. Ironic stores this state durably, so it
   holds even if the console controller is not running.
1. Before deprovisioning completes, the provisioner checks again that the
   console is disabled. If it has been re-enabled, for example by a
   controller acting on stale data, it disables it again and retries.

Deleting the request first means no live request exists while the console is
being disabled; the final check covers any remaining race.

The host becomes available as usual once deprovisioning completes; it does
not wait for any other controller. No BMH API change is needed.

An administrator may also open a console on an available host, for example
to debug it. If that host is then provisioned, the console stays open into
the new workload. This is allowed: the administrator opened it deliberately
and deletes the request to close it.

Consoles do not persist across detachment. Detaching a host deletes its
Ironic node, which stops the console, so BMO also deletes the request. Users
must create a new request after reattaching the host. Deleting a host closes
its console the same way. User documentation must state this explicitly.

### Risks and Mitigations

- **Unauthorized access:** request RBAC does not authenticate TCP clients.
   Restrict requests to trusted administrators and control network access to
   both Services and conductor listeners. Tenant access needs a gateway.
- **Access leaking to the next workload:** handled by disabling the console
   during deprovisioning, as described above.
- **Stuck cleanup:** if Ironic cannot disable the console, the finalizer stays
   and the status reports the error. Documentation describes how an
   administrator can recover safely.

### Work Items

1. Agree the API, deployment model, and deprovisioning behavior.
1. Deliver API, provisioner, and controller changes in focused PRs with tests.
1. Coordinate ironic-image support and integration coverage.
1. Evaluate connection overrides and authenticated gateways separately.

### Dependencies

Ironic needs `ipmitool`, `socat`, an enabled and selected `ipmitool-socat`
interface, and a reachable listener range configured through
`[console] port_range`. Stock Metal3 image/configuration support requires
coordinated changes; a BMO upgrade alone is insufficient. Do not force a global
interface unsupported by other hardware types.

[VirtualBMC SOL support][virtualbmc] has already merged for virtual-hardware
testing. No new production library is required.

### Test Plan

Cover admission, backend operations, and cleanup failures with unit tests.
API-server tests validate the CRD and the generated Service and EndpointSlice
for IPv4 and IPv6 listeners. CI must run them on controller and API changes.

Integration tests verify disabled startup and that deprovisioning disables
the console while the console controller is stopped.
End-to-end tests use IPMI-managed hosts with VirtualBMC, avoiding the need for
connection overrides, and exercise guest output, restart survival,
cleanup/reconnection, and closed access after reprovisioning.

The prototype passed live OpenShift login, restart, pause, cleanup, and
reconnection tests. The deprovisioning behavior still needs validation.

### Upgrade / Downgrade Strategy

Existing installations are unchanged while the feature is disabled. Enabling
it requires the CRD, admission configuration, RBAC component, and Ironic
prerequisites. Before disabling the feature or downgrading, delete all
requests and wait for them to disappear.

### Version Skew Strategy

Install the CRD before enabling the controller. If Ironic lacks the console
interface, the request reports an error; ordinary host management is not
affected.

## Drawbacks

This adds a sensitive management API and a small change to deprovisioning.
Operators still need backend configuration and network controls. Redfish
hosts are supported only when IPMI shares their hostname and credentials.

## Alternatives

- **Direct backend access:** no new API, but requires management connectivity.
- **Separate operator:** isolates permissions and dependencies, but would need
   its own access to Ironic and coordination with BMO during deprovisioning.
- **BMH field or annotation:** mixes temporary requests with persistent host
   configuration and weakens permission separation.
- **Authenticated proxy:** enables tenant access but requires a broader design.

## References

- [Serial console API discussion][discussion].
- [Prototype implementation and review][implementation].
- [Merged VirtualBMC serial-over-LAN support][virtualbmc].
- [Metal3 API design principles](../api-design-principles.md).
- [HostClaim multi-tenancy proposal](../hostclaim-multitenancy.md).
- [Ironic console documentation][ironic-console].

[discussion]: https://github.com/orgs/metal3-io/discussions/3728
[implementation]: https://github.com/metal3-io/baremetal-operator/pull/3768
[virtualbmc]: https://review.opendev.org/c/openstack/virtualbmc/+/1008259
[ironic-console]: https://docs.openstack.org/ironic/latest/admin/console.html
