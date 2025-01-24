<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# CAPM3 Multi-Tenancy Contract

## Status

implementable

## Summary

Implement the CAPI multi-tenancy contract for the Metal3 infrastructure provider
by adding a new field to the Metal3Cluster and Metal3MachineTemplate resource.
The new field will be a reference to a secret that contains the credentials for
accessing the BareMetalHosts.

## Motivation

It is currently hard to use the Metal3 infrastructure provider in a multi-tenant
environment. Some options are available (separate namespaces, separate
CAPM3/BMO/Ironic instances), but they all come with drawbacks. Considering that
there is a well defined CAPI contract for multi-tenancy, we should implement it.

### Goals

- Implement the CAPI multi-tenancy contract for the Metal3 infrastructure
  provider
- Allow CAPM3 to work with BareMetalHosts in another cluster or namespace than
  where the Metal3Machine is.
- To propagate back the relevant information to the Metal3Machine from the
  BareMetalHost.

### Non-Goals

- Removing or changing how CAPM3 is associating Metal3Machines with the
  BareMetalHosts.
- Solving issues related to multiple CAPM3 instances working with the same
  BareMetalHosts. This should be handled separately, e.g. by introducing a
  [claim resource](https://github.com/metal3-io/metal3-docs/pull/408).
- Limiting the scope of the credentials that CAPM3 needs to access the
  BareMetalHosts. This should be handled separately, e.g. by introducing a
  [claim resource](https://github.com/metal3-io/metal3-docs/pull/408).

## Proposal

Add a new field to the Metal3Cluster and Metal3MachineTemplate resource that
will be a reference to a secret that contains the credentials for accessing the
BareMetalHosts. The new field would also propagate from the
Metal3MachineTemplate to the Metal3Machine. CAPM3 should use the credentials for
associating Metal3Machines with the BareMetalHosts and for propagating back the
relevant information to the Metal3Machine from the BareMetalHost.

### User Stories

#### Story 1

As an administrator of bare-metal resources, I want to be able to create
separate pools of BareMetalHosts for different users so that they cannot
interfere with each other.

#### Story 2

As an administrator of bare-metal resources, I want to be able to create common
pools of BareMetalHosts that two or more users can collaborate on.

#### Story 3

As a user of CAPM3, I want to make use of the BareMetalHosts that another team
has created and made available to me, without necessarily sharing the same
cluster.

#### Story 4

As a one-man-show, I want to continue using the current single-tenant setup with
in-cluster credentials for accessing the BareMetalHosts. This is especially
important for bootstrapping a self-hosted management cluster.

#### Story 5

As an advanced user of CAPM3, I want to be able to build clusters spanning over
multiple sets of BareMetalHosts, each with their own credentials, for improved
resilience.

### Implementation Details

The new Metal3Cluster field will be `.spec.identityRef` with sub-fields `name`
and `context` (optional). The `name` should point to a secret in the same
namespace as the Metal3Cluster, containing a kubeconfig file. The optional
`context` should point to a context in the kubeconfig file. If the `context` is
not specified, the current context will be used.

For the Metal3MachineTemplate, the new field will be
`.spec.template.spec.identityRef` with the same sub-fields as the Metal3Cluster.
This will propagate to the Metal3Machine's `.spec.identityRef`.

If the `identityRef` is not specified, CAPM3 should use in-cluster credentials
for accessing the BareMetalHosts (current behavior). If the `identityRef` is
specified on the Metal3Cluster, but not on the Metal3MachineTemplate, CAPM3
should use the credentials specified in the Metal3Cluster for all
Metal3Machines.

CAPM3 should make use of the kubeconfig file to access the BareMetalHosts
related to the Metal3Cluster. The kubeconfig file can point to a namespace in
the same cluster or to a remote cluster. Secrets for metadata, networkdata and
userdata must also be created next to the BareMetalHosts.

Example:

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3Cluster
metadata:
  name: cluster-1
spec:
  identityRef:
    name: cluster-1-kubeconfig
    context: cluster-1-context
---
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3MachineTemplate
metadata:
  name: cluster-1-controlplane-template
spec:
  template:
    spec:
      identityRef:
        name: control-plane-bmh-kubeconfig
        context: default
```

The status of the Metal3Machine should be extended with the information from the
BareMetalHost. This is similar to how other providers work, as they propagate
the relevant information from cloud resources back the the InfraMachine. For the
Metal3Machine, we should add the following fields from the BareMetalHost:

- `.status.provisioning` on the BMH would become
  `.status.bareMetalHost.provisioning` (ID is omitted)
- `.status.poweredOn` on the BMH would become `.status.bareMetalHost.poweredOn`
- `.status.errorMessage` on the BMH would become
  `.status.bareMetalHost.errorMessage`
- `.status.operationalStatus` on the BMH would become
  `.status.bareMetalHost.operationalStatus`

Fields related to the BMC credentials are not included, since they are only
relevant for managing the BareMetalHost. Hardware details are also avoided since
they are about to be removed from the BareMetalHost status now that we have a
separate CRD (HardwareData) for them. We could think about propagating the
information from the HardwareData or even copy the whole thing if deemed useful.

The status of the Metal3Cluster does not need to change. However, the Ready
condition should be set only when CAPM3 has verified that the identityRef
credentials are valid. Invalid credentials should result in an error on the
Metal3Cluster.

Example Metal3Machine status:

```yaml
status:
  # New fields
  bareMetalHost:
    provisioning:
      bootMode: legacy
      image:
        checksum: bed6ff0f7cde1edfd07e20aab324e406a9027b5cbf05c93fc10d7a7391ea0343
        checksumType: sha256
        format: raw
        url: http://192.168.222.1/ubuntu-2204-kube-v1.28.2.raw
      rootDeviceHints:
        deviceName: /dev/vda
      state: provisioned
    operationalStatus: OK
    errorMessage: ""
  # Existing fields
  addresses:
  - address: 192.168.222.100
    type: InternalIP
  - address: fe80::b331:705:526f:c2d8%enp1s0
    type: InternalIP
  - address: bmo-e2e-0
    type: Hostname
  - address: bmo-e2e-0
    type: InternalDNS
  conditions:
  - lastTransitionTime: "2024-05-17T11:01:35Z"
    status: "True"
    type: Ready
  - lastTransitionTime: "2024-05-17T10:59:02Z"
    status: "True"
    type: AssociateBMH
  - lastTransitionTime: "2024-05-17T11:01:35Z"
    status: "True"
    type: KubernetesNodeReady
  - lastTransitionTime: "2024-05-17T10:59:03Z"
    status: "True"
    type: Metal3DataReady
  lastUpdated: "2024-05-17T10:59:03Z"
  metaData:
    name: test-1-5jt87-metadata
    namespace: default
  ready: true
  renderedData:
    name: test-1-controlplane-template-0
    namespace: default
  userData:
    name: test-1-5jt87
    namespace: default
```

#### Meta data, user data and network data

Metal3DataTemplates, Metal3DataClaim and Metal3Data objects would not change
with the implementation of this proposal, with the exception that the resulting
secrets would be located next to the BareMetalHosts. The custom resources would
be with the Metal3Machines, but the secrets must be with the BareMetalHosts so
that the Bare Metal Operator can make use of them.

Note that the `.status.metaData` and `.status.userData` of a Metal3Machine would
be located in the same namespace and cluster as the BareMetalHost. The
`.status.renderedData` on the other hand would be located in the same namespace
as the Metal3Machine.

### Risks & Mitigations

Considering that BareMetalHosts could be in a different cluster entirely, the
move operation will be more complex. BareMetalHosts in external clusters should
not be moved at all. BareMetalHosts in the same namespace and cluster should be
handled as usual. An open question is how to handle BareMetalHosts in a
different namespace.

In practice this is not really a Metal3 concern since it is a CAPI feature that
we are using. CAPI will only move the CAPI/CAPM3 resources and other resources
that are labeled to be moved. We will need to document it properly though so
that users knows what to expect and in which cases the move operation will work.

### Work Items

- Add the new `identityRef` field to the Metal3Cluster, Metal3MachineTemplate,
  and Metal3Machine resource and update CAPM3 to make use of it.
- Add E2E test (or modify existing test to use the new field).
- Update documentation.

## Dependencies

None

## Test Plan

- Unit tests
- At least one E2E test should use the new field and at least one E2E test
  should use in-cluster credentials.

## Upgrade / Downgrade Strategy

It will not be possible to downgrade to a version without support for the new
field when making use of the new field.

## Drawbacks

None

## Alternatives

- Handle multi-tenancy through namespace isolation with a single cluster-wide
  CAPM3 instance. Users cannot share a BMH pool without working in the same
  namespace. The cluster-wide CAPM3 instance would have access to all the
  BareMetalHosts.
- Handle multi-tenancy through namespace isolation with per namespace CAPM3
  instances. This is impractical since all CAPM3 instances would need to be of
  the same version (since CRDs are global). The same issue goes for per
  namespace BMO instances. Users cannot share a BMH pool without working in the
  same namespace.

None of these alternatives provide any way of separating the BareMetalHosts from
the Metal3Machines.

- The `identityRef` field could allow referencing different kinds of credentials
  also. For example, a service account token. This may be simpler for users
  sharing a cluster, but it would not be possible to reference other clusters. A
  kubeconfig file covers all the use cases with a slight increase in complexity
  for same-cluster access and is therefore preferred.

## References

1. [CAPI multi-tenancy
   contract](https://cluster-api.sigs.k8s.io/developer/architecture/controllers/multi-tenancy#contract)
