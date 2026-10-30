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
administrators, using Ironic's IPMI serial-over-LAN (SOL) support. Automatic
Redfish discovery and tenant authentication are separate work. The
[prototype PR][implementation] includes broader functionality; this proposal
seeks agreement on a smaller core and its lifecycle guarantees.

## Motivation

A host with boot or networking failures may still be reachable through its
BMC's serial console. A Kubernetes request lets administrators use BMO's
existing host/provisioner relationship without direct management-network
access or knowledge of the backend console API.

### Goals

- Request and revoke access without changing host power or provisioning state.
- Preserve sessions across reconciliation and BMO restarts.
- Revoke backend access before the next workload begins.
- Keep console controllers, watches, and permissions optional.
- Support IPv4-only and IPv6-only Service networks.

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

Status reports readiness and a connection URL. Deletion waits for cleanup
through a finalizer. The request contains neither connection settings nor
credentials; permission to request access is separate from permission to
configure a host.

The initial implementation uses Ironic's `ipmitool-socat` interface. Ironic
owns listener allocation and BMC communication. BMO creates a selectorless
ClusterIP Service on TCP port 2023 and an EndpointSlice targeting the listener.
No public LoadBalancer or NodePort is created automatically.

## Design Details

The request is owned by the corresponding BMH. Admission and reconciliation
validate that the host exists and is not deleting or detached. Cleanup remains
possible after the host or its Secret disappears.

Status includes a Ready condition, Service name, URL, and backend cleanup
checkpoints. Exact checkpoint fields remain subject to API review; clients
must not need Ironic-specific knowledge. Status never contains credentials.

Connection configuration belongs to the BMH, not the request:

- IPMI-managed hosts reuse their management endpoint and credentials.
- Other hosts use an administrator-supplied `spec.bmc.serialConsoleAddress`,
   an IPMI URL without embedded credentials.
- Optional `serialConsoleUsername` and `serialConsolePassword` entries in the
   existing BMC Secret supply separate SOL credentials for non-IPMI-managed
   hosts. Otherwise management credentials are used.

### Implementation Details/Notes/Constraints

#### Optional deployment and bounded watches

An operator flag, disabled by default, enables the controller and admission
handler. Supply routing RBAC as an opt-in deployment component. Disabled
installations must not start console caches or require routing permissions.
Filter Service/EndpointSlice caches by a dedicated ownership label; ownership
watches alone do not limit cached objects. Never adopt foreign routing objects.

Console management is an optional provisioner capability. Unsupported
providers report a console-specific condition without acquiring cleanup work.

#### Backend observation and routing

Persist cleanup identity before enabling access. Ironic's console-show
operation can interrupt SOL sessions, so checkpoint the endpoint and monitor
ordinary node state afterward. Select routing compatible with the Service's
IP family without unnecessarily replacing live endpoints.

Transient observation failures or host pause retain established routing and
report readiness as Unknown. Explicit deletion still cleans up. Ready confirms
backend/routing setup, not successful guest login.

#### Revocation and workload boundaries

Delete owned routing and disable the backend independently, retaining the
finalizer until both complete. Removing a Service alone does not terminate
established TCP sessions.

Requests expire on deprovisioning, detachment, or host deletion and must not
follow a replacement host. Tracking must survive missed transitions. The
prototype binds requests to a persistent BMH deprovisioning generation, but
this gives eventual invalidation, not synchronous revocation.

The proposed requirement is confirmed revocation before BMO provisions the
next workload, even if the console controller is unavailable. Power management
and deprovisioning itself remain possible.

**Decision for review:** agree whether BMH reconciliation waits for request
cleanup or the provisioner revokes access with a durable acknowledgement.
Determine whether the generation field is also needed. The prototype does not
implement this barrier; workload changes outside BMO remain the administrator's
responsibility.

#### Discovery is separate work

Explicit endpoints avoid requiring BMO's own BMC network access and certificate
trust. A follow-up can compare discovery in Ironic versus BMO, including the
risk of discovered destinations redirecting credentials to another host.

### Risks and Mitigations

- **Unauthorized access:** request RBAC does not authenticate TCP clients.
   Restrict requests to trusted administrators and control network access to
   both Services and conductor listeners. Tenant access needs a gateway.
- **Workload isolation:** require restart-safe, confirmed revocation, not only
   request deletion or a generation comparison.
- **Stuck cleanup:** report failures and retain the finalizer; document safe
   administrator recovery rather than silently abandoning backend access.

### Work Items

1. Agree the API, deployment model, and workload revocation mechanism.
1. Deliver API, provisioner, and controller changes in focused PRs with tests.
1. Coordinate ironic-image support and integration coverage.
1. Evaluate discovery and authenticated gateways separately.

### Dependencies

Ironic needs `ipmitool`, `socat`, an enabled and selected `ipmitool-socat`
interface, and a reachable listener range configured through
`[console] port_range`. Stock Metal3 image/configuration support requires
coordinated changes; a BMO upgrade alone is insufficient. Do not force a global
interface unsupported by other hardware types.

[VirtualBMC SOL support][virtualbmc] has already merged for virtual-hardware
testing. No new production library is required.

### Test Plan

Cover admission, backend operations, credential changes, and cleanup failures
with unit tests. API-server tests validate CRDs and routing in IPv4-only and
IPv6-only configurations. CI must run them on controller/API changes.

Integration tests verify disabled startup, bounded caches, and revocation
before the next workload despite controller outages. VirtualBMC/Ironic tests
exercise guest output, restart survival, and cleanup/reconnection.

The prototype passed live OpenShift login, restart, pause, cleanup, and
reconnection tests. The proposed provisioning barrier still needs validation.

### Upgrade / Downgrade Strategy

Existing installations remain unchanged while disabled. Enabling requires the
CRD, admission configuration, RBAC, and backend prerequisites. Before disabling
or downgrading, delete requests and confirm cleanup. Test accidental rollback
so outstanding revocation cannot be bypassed.

### Version Skew Strategy

Install schemas before controllers that use them; preserve lifecycle tracking
across served API versions. Unsupported backends report console-specific
conditions without breaking ordinary host management. Capability loss must
not discard existing cleanup obligations.

## Drawbacks

This adds a sensitive management API and lifecycle coordination. Operators
still need backend configuration and network controls. Explicit endpoints
are less convenient than discovery but keep the initial trust boundary smaller.

## Alternatives

- **Direct backend access:** no new API, but requires management connectivity.
- **Separate operator:** isolates permissions and dependencies, but still needs
   a host/backend interface and revocation contract. Placement remains open.
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
