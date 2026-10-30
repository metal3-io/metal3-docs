<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Network Multi-Tenancy with HostClaims and ToR Switch Management

## Status

One of: implementable

## Summary

This design proposes API changes require for HostClaims to cooperate with ToR
switch management API. It is considered an MVP: the minimum possible scope will
be implemented with the goal of expanding it further.

## Motivation

Two features are being developed that tackle multi-tenancy from two different
perspectives:

1. HostClaims enable tenants to claim BareMetalHosts
1. Networking API allows dynamically place BareMetalHosts on different VLANs

This design proposes an MVP for the full story: integration between HostClaims
and HostNetworkAttachments for complete tenant isolation.

### Goals

- Users of HostClaim API have their traffic isolated from each other
- Tenant traffic is isolated from system traffic (provisioning, etc)

### Non-Goals

- Full networking API. The goal of networking API in Metal3 remains the same:
  to place machines on the right networks at the right moment of time.
- Self-service networking for tenants. This proposal focuses on limited choices
  for consumers.
- Lack of proper data cleaning is the last missing piece for a full
  multi-tenancy. It will be covered separately.

## Proposal

Depending on site policies, there are many ways for HostClaims to interact with
networking API. I can list a few possibilities:

1. HNA are pre-configured on BareMetalHosts.
1. HNA are configured per tenant.
1. Each tenant receives a curated list of HNA to use.
1. Tenants can bring their own HNA.

Option 1 is status quo. This RFE focuses on option 2, keeping option 3 as a
future possibility.

### User Stories

#### Story 1

As an infrastructure operator, I want to ensure that tenants cannot see or
interact with the provisioning traffic. For instance, they cannot see running
IPA instances.

#### Story 2

As an infrastructure operator, I want to put all my tenants on separate
networks to isolate their traffic from each other. I want to do it in a
prescriptive way, where each tenants has a few choices, depending on which role
a certain host must play in their cloud.

### Example Workflow

I'm an infrastructure operator, and I'm onboarding tenant *blue* that uses
namespace `tenant-blue`. The tenant will deploy two kinds of instances:
``worker`` and ``ctlplane`` with corresponding policies ``tenant-blue-worker``
and ``tenant-blue-ctlplane``.

I'll focus on BareMetalHosts and policies in the hardware pool in the namespace
``infra-pool42``.

#### Hosts and deploy policies

Before onboarding any tenants, I populate `networkInterfaces` on each
BareMetalHost with NICs that I want the policies to control and label them
according to their role. For example:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: host03
  namespace: infra-pool42
spec:
  # ...
  networkInterfaces:
  - macAddress: "11:22:33:44:55:66"
    labels: [embedded]
  - macAddress: "66:55:44:33:22:11"
    labels: [trunk-100g]
  - macAddress: "33:22:11:66:55:44"
    labels: [internal]
    hostNetworkAttachment:
      name: internal-network
```

The new tenant follows an existing HostDeployPolicy. It marks having a network
policy as required, so that no HostClaims can match this HostDeployPolicy
without also matching a HostClaimNetworkPolicy.

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostDeployPolicy
metadata:
  name: tenants
  namespace: infra-pool42
spec:
  hostClaimNamespaces:
    nameMatches: "^tenant-.*"
  networkPolicies: required
```

#### Switch configuration

Before proceeding, I configure the overlay network for this tenant. This is
not done by Metal3, I may do it manually or use 3rd party automation. For each
ToR switch, I allocate a VLAN and configure VLAN-to-VNI mapping.

I create HostNetworkAttachments for all networks available to each of two
policies for this tenant. For example:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostNetworkAttachment
metadata:
  name: tenant-blue-worker-external
  namespace: infra-pool42
spec:
  mode: access
  nativeVLAN: 100
```

#### Network policies

Now I create two policies for two kinds of nodes. They need to be designed in a
way that is applicable to all hosts from the current pool.

This is the policy for workers:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostClaimNetworkPolicy
metadata:
  name: tenant-blue-worker
  namespace: infra-pool42
spec:
  # Only applicable to HostClaims from these namespaces
  hostClaimNamespaces: [tenant-blue]
  # Hosts must declare compatibility with these policy. In this example,
  # the selector is not tenant-specific.
  hostSelector:
    matchLabels:
      hostclaimnetworkpolicy.example.com/worker: "true"
  networkInterfaces:
  # NIC with label "embedded" must exist and will get the linked HNA
  - label: embedded
    hostNetworkAttachment:
      name: tenant-blue-worker-external
  # Same here, but the process won't fail if the NIC with label "trunk-100g"
  # is missing on the host.
  - label: trunk-100g
    hostNetworkAttachment:
      name: tenant-blue-worker-trunk
    optional: true
  # NIC with label "internal" is kept intact: it represents are
  # pre-configured network.
  - label: internal
    keep: true
```

Finally, I label all BareMetalHosts that can support the created policies. This
is because a HostClaim with a network policy will fail to bind to a host if the
host cannot use the requested policy. For example:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: host03
  namespace: infra-pool42
  labels:
    hostclaimnetworkpolicy.example.com/ctlplane: "true"
    hostclaimnetworkpolicy.example.com/worker: "true"
```

#### Host claims

Now the tenant is onboarded and can create HostClaims. To use hosts from this
pool, they must provide the policy they want to apply from the list of allowed:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostClaim
metadata:
  name: worker1
  namespace: tenant-blue
spec:
  networkPolicy: tenant-blue-worker
```

## Design Details

### BareMetalHost additions

- New NetworkInterface.Labels: TODO
- Optional NetworkInterface.HostNetworkAttachment: TODO

### HostDeployPolicy additions

- New NetworkPolicies: TODO

### HostClaimNetworkPolicy resource

TODO

### HostClaim additions

- New NetworkPolicy: TODO

### Implementation Details/Notes/Constraints

#### Changes to how HostClaims are matched to hosts

- HostClaims without `networkPolicy` field do not match HostDeployPolicies
  with `networkPolicies` set to `required`.

If a HostClaim specifies a HostClaimDeployPolicy...

- ... that doesn't exist in the HostDeployPolicy namespace, hosts in this
  namespace don't match.

- ... which doesn't match the HostClaim's namespace in its
  `hostClaimNamespaces`, hosts in this namespace don't match.

- ... the policy's `hostSelector` is merged into the HostClaim's
  `hostSelector`, so that only hosts that match both selectors can be claimed.

- ... hosts with labels on its `networkInterfaces` not matching the policy's
  non-optional `networkInterfaces` are skipped.

### Risks and Mitigations

TODO

### Work Items

TODO

### Dependencies

- Requires HostClaims and HostNetworkAttachments to be fully implemented.

### Test Plan

TODO

### Upgrade / Downgrade Strategy

TODO

### Version Skew Strategy

TODO

## Drawbacks

TODO

## Alternatives

- Leave network management to 3rd party software. Coordinating network
  switching with Ironic is difficult, and I'm aware of at least one downstream
  project already that is struggling with this problem.

- Full network automation. While there are existing solutions we could reuse
  (e.g. ansible-networking), the scope of such a feature would be too large for
  our community to handle.

## References
