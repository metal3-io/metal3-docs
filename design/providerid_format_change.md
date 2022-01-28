<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# providerid_format_change

## Status

provisional

## Summary

The providerID is generated using BaremetalHost's uuid.
While the Baremetalhost's uuid is tied to the life of the BMH object,
the providerID should be related to provisioning a kubernetes cluster.

The current providerID has some limitations due to content and format.
The providerID uses Baremetalhost's uuid, making it static for the life of the
BMH. This essentially makes a providerID tied to a BaremetalHost's lifecycle
which is sometimes undesirable.

## Motivation

Currently, providerID has the `metal3://<BareMetalHost-uuid>` format. This value is
static for the life cycle of the BMH. Kubernetes deployments and subsequent
upgrades use the same providerID. This has caused issues with upgrades.
For example, two Kubernetes nodes could end up with the same providerID if
the deletion of the previous node did not happen properly. This causes
cluster API to fail, blocking the upgrade.

It could be made dynamic by including information from other resources that are generated uniquely for each kubernetes deployment.

The current providerID logic makes use of labels in
`metal3.io/uuid=<BareMetalHost-uuid>` format, also supplied via templates. This does not
provider extra information as provider-id (`metal3://<BareMetalHost-uuid>`) contains the
same information. In this regard, the label is redundant.

### Goals

- Add new implicit field to `metal3datatemplate`
- Change providerID format to include dynamic information
- Deprecate usage of node labels.

### Non-Goals

Making templates simpler.

## Proposal

The issues discussed above can be solved by introducing a new field in the
metal3datatemplate implicitly. This does not require a change in the API
(metal3datatemplate object) if CAPM3 always automatically populates this key in
the resulting secret for the node. But it should be a default only, so that it
could be overwritten by the user if they define this key explicitly.

```bash
providerid: "metal3://<namespace>/<BareMetalHost name>?owner=<metal3machine name>"
```

The new format is both dynamic and known in advance. Since this is added from
the code, there is no need of changing Spec or Status sections of the resource.

Also, since it is constructed in the code, there is no need for the users to
provide provider-id and label via templates. However, the users still refer to
the providerID variable in their templates to get it populated by cloud-init.

### User Stories

- As a user, I want my nodes' providerIDs to be unique per kubernetes deployment
 and be generated automatically by CAPM3 using metal3machine and baremetalhost resource names.

## Design Details

The following changes are required in the code:

- Searching nodes is no longer done using labels
- Searching nodes is done using implicitly set providerid
- Providerid field is introduced in metal3datatemplate in the code.
- Labels are no longer provided via templates

Concerning backwards compatibility, there are three scenarios:

1. backwards compatibility with legacy providerID in existing deployments,
  - During scale out, new nodes keep using legacy providerID
  - During upgrade, upgraded nodes keep using legacy providerID
2. backwards compatibility with legacy providerID for new deployments,
  - During provisioning, if user supplies template with legacy providerID and
  node label, then the nodes should be provisioned with the legacy providerID
  - This will be supported for the next two releases

3. transition from legacy to new providerID format for existing deployments.
  - Existing nodes with legacy providerID can be moved to the new format using
  upgrade. This can be achieved by creating new
  `kubeadmconfigtemplates.bootstrap.cluster.x-k8s.io` resource with the new provider-id
  set inside the `.spec.template.spec.joinConfiguration.nodeRegistration.kubeletExtraArgs`
  structure. An example is shown below:

```yaml
apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
kind: KubeadmConfigTemplate
metadata:
  name: test1-s54fx
  namespace: metal3
spec:
  clusterConfiguration: ....
  files: ...
  joinConfiguration:
    controlPlane:
      localAPIEndpoint: {}
    discovery: ...
    nodeRegistration:
      kubeletExtraArgs:
        provider-id: metal3://{{ ds.meta_data.providerid }}
      name: '{{ ds.meta_data.name }}'
```

### Implementation Details/Notes/Constraints

None

### Risks and Mitigations

None

### Work Items

None

### Dependencies

- Templates should be updated with the new format

### Test Plan

Existing upgrade tests can serve for verification of the new format. This includes
upgrading with templates that use the new providerID format.

### Upgrade / Downgrade Strategy

The code change on the providerID logic will be backward compatible
in that CAPM3 keeps populating the providerID from the label, if the providerID
is unset and the label is set.

### Version Skew Strategy

None

## Drawbacks

None

## Alternatives

There are possible formats:

1. ```metal3://<namespace>/<BareMetalHost name>?owner=<metal3machine name>```
2. ```metal3://<BareMetalHost uid>/<Metal3Machine uid>```

The second option requires an extension of the metal3datatemplate
to include the ```Metal3Machine uid```. The ```<BareMetalHost uid>``` is already included,
but is named as ```uuid```. If CAPM3 populates a providerID key automatically,
we don't need to extend the m3dt.

Due to these reason, the first option is preferred. Another reason for choosing
 option (1) is that the information is known in advance and is already in a
 string format increasing readability for the user.

## References

None
