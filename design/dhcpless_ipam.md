<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# DHCP-less network config templating

Discuss options and outline a proposal to enable DHCP-less network config templating,
leveraging existing CAPM3 IPAM support.

## Status

implementable

## Summary

Metal3 provides an IPAM controller which can be used to enable
deployment with static-IPs instead of DHCP, however currently it is not
possible to use this functionality in a fully DHCP-less environment because
it does not support network configuration in the pre-provisioning phase.

This proposal outlines some additional network config templating to enable
use of the existing IPAM solution for the pre-provisioning phase, using
a similar approach to the existing templating of `networkData`

## Motivation

Infrastructure management via Metal3 in DHCP-less environments
is common, but today our upstream features only partially solve for this use-case.

Since there are several groups in the community who require this functionality,
it makes sense to collaborate and ensure we can support this use-case.

### Goals

Enable e2e integration of the existing CAPM3 IPAM components such that it's
possible to deploy in a DHCP-less environment using static network configuration
managed via Metal3 resources.

Any API changes should not preclude future alternative IPAM/templating solutions
but any future alternatives are considered out-of-scope for this proposal.

### Non-Goals

Existing methods used to configure networking via downstream customizations (such
as a custom PreprovisioningImageController) are valid and will still sometimes
be required, this doesn't aim to replace such methods - the approach here may be
complementary for those users wishing to combine CAPM3 IPAM features with
a PreprovisioningImageController.

This proposal will focus on the Metal3 components only - there are
also OS dependencies and potential related areas of work in Ironic, these will
be mentioned in the Dependencies section but not covered in detail here.

This proposal will only consider the Metal3 IPAM controller -
there are other options but none are currently integrated via CAPM3.

This proposal will only consider the existing CAPM3 networkData templating
solution, but alternatives may be considered via a future proposal so design
choices here should be flexible enough to account for that possibility.

## Proposal

Implement a new CAPM3 template resource and associated controller to handle setting
the BareMetalHost `preProvisioningNetworkDataName` Secret in an automated way.

This will be achieved via an approach similar to the existing templating of `networkData`
but adjusted to account for the lack of any `Machine` at the pre-provisioning step
of the deployment flow.

To enable the required BareMetalHost behavior baremetal-operator support for
a new annotation will be introduced that serves two purposes:

* When the new annotation key exists, BMO logic will be adjusted to ensure we don't start inspection until the `preprovisioningNetworkDataName` Secret exists and is populated
* The new annotation value will contain a resource reference, which can be consumed by the controller generating the `preprovisioningNetworkDataName` Secret and links the BareMetalHost to a specific template resource

### User Stories

#### Static network configuration (no IPAM)

As a user I want to manage my networkConfiguration statically as part of my
BareMetalHost inventory.

In this case the network configuration is provided via a Secret which is
either manually created or templated outside the scope of Metal3

The BareMetalHost API already supports two interfaces for passing network configuration:

* `networkData` - this data is passed to the deployed OS via Ironic via a
  configuration drive partition.  It is then typically read on firstboot by
  a tool such as `cloud-init` which supports the OpenStack network data format.
* `preprovisioningNetworkDataName` - this data is designed to allow passing data
  during the pre-provisioning phase, e.g to configure networking for the IPA deploy
  ramdisk.

The `preprovisioningNetworkDataName` API was added initially to enable [image
building workflows](https://github.com/metal3-io/baremetal-operator/blob/main/docs/api.md#preprovisioningimage), and a [recent BMO change](https://github.com/metal3-io/baremetal-operator/pull/1380) landed to enable this flow without any custom PreprovisioningImage controller.

#### IPAM configuration

As a user I wish to make use use of the Metal3 IPAM solution, in a
DHCP-less environment.

Metal3 provides an [IPAM controller](https://github.com/metal3-io/ip-address-manager)
which can be used to allocate IPs used as part of the Metal3Machine lifecycle.

Some gaps exist which prevent realizing this flow in a fully DHCP-less environment,
so the main focus of the proposal will be how to solve for this use-case.

##### IPAM Scenario 1 - common IPPool

An environment where a common configuration is desired for the pre-provisioning
phase and the provisioned BareMetalHost (e.g scenario where hosts are permanently
assigned to specific clusters)

##### IPAM Scenario 2 - decoupled preprovisioning/provisioning IPPool

An environment where a decoupled configuration is desired for the pre-provisioning
phase and the provisioned BareMetalHost (e.g BMaaS scenario where end-user network configuration
differs from the commissioning phase where a different configuration is desired for inspection/cleaning)

## Design Details

### Baremetal Operator controller Design Details

To enable the required BareMetalHost behavior baremetal-operator support for
a new annotation will be introduced that serves two purposes:

* When the new annotation key exists, BMO logic will be adjusted to ensure we don't start inspection until the `preprovisioningNetworkDataName` Secret exists and is populated
* The new annotation value will contain a resource reference, which can be consumed by the controller generating the `preprovisioningNetworkDataName` Secret and links the BareMetalHost to a specific template resource

This approach allows us to avoid the problem of inspection starting then failing because no
`preprovisioningNetworkDataName` is yet specified to configure networking in the IPA ramdisk,
and by using an annotation we avoid coupling the BMH API to a specific template format, which
will make things easier in future if we want to enable alternative template resource types.

An example of the proposed annotation format:

```yaml
baremetalhost.metal3.io/preprovisioningnetworkdata-reference: metal3preprovisioningdatatemplates.infrastructure.cluster.x-k8s.io/a-template
```

### CAPM3 Design Details

`Metal3MachineTemplate` and `Metal3DataTemplate` are used to apply networkData to specific BareMetalHost resources,
but they are by design coupled to the CAPI Machine lifecycle.

This is a problem for the pre-provisioning use-case since at this point we're preparing the BareMetalHost for
use, there is not yet any Machine.

To resolve this below we outline a proposal to add a new DataTemplate resource with similar behavior
for pre-provisioning called `Metal3PreProvisioningDataTemplate`, along with an associated controller which:

* Consumes the BareMetalHost annotation described above to match each annotated BMH to a `Metal3PreProvisioningDataTemplate`
* Resolve the `networkData` template and generate a Secret using the same code/flow as exising `networkData` support in `Metal3DataTemplate`
* Update the BareMetalHost `preprovisioningNetworkDataName` spec field to reference the created Secret

Comparing with `Metal3DataTemplate` the new resource will only support `networkData` as `clusterName` is not
relevant at the pre-provisioning stage (when the BMH is not bound to any Machine/Cluster), and `metaData` is
not supported by the underlying Ironic node creation API.

### API overview

The current flow in the provisioning phase is as follows (only the most relevant fields are included for clarity):

```yaml
apiVersion: ipam.metal3.io/v1alpha1
kind: IPPool
metadata:
  name: pool-1
spec:
  clusterName: cluster

---

apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3DataTemplate
metadata:
  name: data-template
spec:
  clusterName: cluster
  networkData:
    networks:
      ipv4:
      - id: eth0
        ipAddressFromIPPool: pool-1

---

apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3MachineTemplate
metadata:
  name: machine-template
spec:
  template:
    spec:
      dataTemplate:
        name: data-template
      hostSelector:
        matchLabels:
          cluster-role: control-plane

---
apiVersion: cluster.x-k8s.io/v1beta1
kind: MachineDeployment
metadata:
  name: machine-deployment
spec:
  clusterName: cluster
  replicas: 1
  template:
    spec:
      clusterName: cluster
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
        kind: Metal3MachineTemplate
        name: machine-template
```

In this flow when a Metal3Machine is provisioned via the `MachineDeployment`, BareMetalHost resources labeled
`cluster-role: control-plane` will have `networkData` defined with an IP derived from the `pool-1` `IPPool`.

In CAPM3 an IPClaim is created to reserve and IP from the IPPool for each Machine, and an IPAddress resource
contains the data used for templating of the `networkData`

#### Preprovisioning - Common IPPool

```yaml
apiVersion: ipam.metal3.io/v1alpha1
kind: IPPool
metadata:
  name: pool-1
spec:
  clusterName: cluster

---

apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3PreprovisioningDataTemplate
metadata:
  name: preprov-data-template
spec:
  preprovisioningNetworkData:
    networks:
      ipv4:
      - id: eth0
        ipAddressFromIPPool: pool-1

---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  annotations:
    baremetalhost.metal3.io/preprovisioningnetworkdata-reference: metal3preprovisioningdatatemplates.infrastructure.cluster.x-k8s.io/preprov-data-template
...
```

In this flow there is no `MachineDeployment`, BareMetalHost resources are annotated to reference a specific
`Metal3PreprovisioningDataTemplate` which contains `networkData` which will be processed in the same way as
described above, with the new controller generating a Secret from the template, and updating the BareMetalHost
`preprovisioningNetworkDataName`, at which point the BMO starts inspection and other pre-provisioning operations.

The preprovisioningNetworkDataName is used by default for networkData in the baremetal-operator, so in this configuration it's not
strictly necessary to specify networkData via Metal3DataTemplate, however we'll want to delete the IPClaim after preprovisioning
in the decoupled flow below so it seems likely we'll want to behave consistently and rely on the IP Reuse functionality if a
consistent IP is required between pre-provisioning and provisioning phases.

#### Preprovisioning Decoupled IPPool

```yaml
apiVersion: ipam.metal3.io/v1alpha1
kind: IPPool
metadata:
  name: pool-1
spec:
  clusterName: cluster

---

apiVersion: ipam.metal3.io/v1alpha1
kind: IPPool
metadata:
  name: preprovisioning-pool

---

apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3PreprovisioningDataTemplate
metadata:
  name: preprov-data-template
spec:
  preprovisioningNetworkData:
    networks:
      ipv4:
      - id: eth0
        ipAddressFromIPPool: preprovisioning-pool

---

apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3DataTemplate
metadata:
  name: data-template
spec:
  clusterName: cluster
  networkData:
    networks:
      ipv4:
      - id: eth0
        ipAddressFromIPPool: pool-1

---

apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3MachineTemplate
metadata:
  name: machine-template
spec:
  template:
    spec:
      dataTemplate:
        name: data-template
      hostSelector:
        matchLabels:
          cluster-role: control-plane

---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  annotations:
    baremetalhost.metal3.io/preprovisioningnetworkdata-reference: metal3preprovisioningdatatemplates.infrastructure.cluster.x-k8s.io/preprov-data-template
...

```

In this flow we have `preprovisioning-pool` which is not associated with any cluster, this is used to provide an IPAddress during
the pre-provisioning phase as described above.  To reduce the required size of the pool, the IPClaim will be deleted after the
pre-provisioning phase is completed, e.g the BMH resource becomes available.

In the provisioning phase another pool, associated with a cluster is used to template networkData as in the existing process.

#### Assumptions and Open Questions

TODO

### Implementation Details/Notes/Constraints

#### IP Reuse

A related issue has been previously addressed via the [IP Reuse](https://github.com/metal3-io/cluster-api-provider-metal3/blob/main/docs/ip_reuse.md) functionality - this means we can couple IPClaims to the BareMetalHost resources which will enable consistent IP allocations for pre-provisioning and subsequent provisioning operations (provided the same IPPool is used for both steps)

### Risks and Mitigations

#### Potential config-drive conflict on redeployment

When a host is re-provisioned, there may be an existing `config-2` partition on the disk that is written as part of the
deployment process, but not cleaned at the early pre-provisioning stage where network configuration is required.

This could potentially result in the wrong configuration being read, or the firstboot tool may fail due to finding
multiple config-drives.

There are several potential workarounds for this situation, but it would be preferable for a common solution
to be found which can benefit both Metal3 and the broader Ironic community,  as such solving this problem is considered
outside the scope of this proposal, but we will follow and engage with the
[Ironic community spec related to this problem](https://review.opendev.org/c/openstack/ironic-specs/+/906324/1/specs/approved/fix-vmedia-boot-config.rst )

### Work Items

* BMO PR adding support for new annotation and adjusting state-machine behavior
* CAPM3 PR adding new resource and controller
* Add e2e coverage

### Dependencies

#### Firstboot agent support

An agent in the IPA ramdisk image is required to consume the network data provided via the processes outlined above.

The Ironic DHCP-less documentation describes using glean (a minimal python-based cloud-init alternative), and community
supported builds containing this tool [are available](https://artifactory.nordix.org/ui/repos/tree/General/metal3/images/ipa/staging/centos/9-stream)

There are several other options such as cloud-init, or even custom scripts/tooling which may be coupled to the OS, so we
do not define a specific solution as part of this proposal.

### Test Plan

* TODO - test coverage, is there any existing coverage for the IPAM flow we can extend?

### Upgrade / Downgrade Strategy

This will be a net-new API and controller so there should be no upgrade impact.

Downgrade of environments leveraging the new API will not be possible, but given provisioning is not currently
possible via this specific flow that seems unlikely to be an issue.

### Version Skew Strategy

N/A

## Drawbacks

### Not all disk formats are supported

This approach will not work in some configurations, and specifically it won't work with `format: live-iso`
since in that case Ironic doesn't build the virtualmedia image, so it can't inject any `network_data`

Additionally Ironic may not support injecting `network_data` in every configuration, when the IPA image is
supplied as kernel and initramfs combo then Ironic can convert it to an ISO and inject the node `network_data`
but in the case where a pre-built ISO ramdisk ISO is provided the image conversion won't happen thus there is
no way to inject the network data.

In practice this probably isn't a huge issue, since if the preprovisioning image workflow is used to generate
a customized ISO, it can embed the configuration instead of Ironic to achieve the same result.

### Network configuration failure can't be reflected in status

In the case of failure to configure the pre-provisioning interfaces, the provisioning agent can't reply to
indicate status/failure so the node inspection will just hang without an explicit/useful error message.

I don't think there is an obvious solution to this, other than potentially considering some kind of validation
but that's outside the scope of this proposal.

### OpenStack networkData format

This solution builds on our existing CAPM3 networkData templating, and as such is is limited to configuration
tools that can interpret OpenStack network,user or metadata formats.

In future it would be interesting to explore alternative options, for example using [nmstate](https://nmstate.io/)
as the DSL where the nmstate CLI tool could interpret the data independent of specific firstboot tool choice.

This proposal has tries to account for such a future direction, but such implementation would imply pluggable
templating which is outside the scope of this change, and may be considered via a future proposal.

## Alternatives

### BMO change alternatives

There are several alternative approaches to solve the problem of preventing BMO starting inspection immediately on BMH registration:

* Add a new BareMetalHost API `PreprovisioningNetworkDataRequired` which defaults to false, but when set to true will describe that the host cannot move from Registering -> Inspecting until `preprovisioningNetworkDataName` has been set.
* Create the BMH with a preprovisioningNetworkDataName pointing to an empty Secret. BMO refuses to start inspecting until the Secret contains some data.
* Require that the BareMetalHost resources are created with the existing [paused annotation](https://github.com/metal3-io/baremetal-operator/blob/main/docs/api.md#pausing-reconciliation), set to a pre-determined value (e.g `metal3.io/preprovisioning`) which can then be removed by the new controller after `preprovisioningNetworkDataName` has been set.

The disadvantage of all these approaches is that it only solves the "delay inspection" part of the problem, we'd still need a way to associate the template
resource with the BMH, but the proposed annotation can resolve both issues in a single API which should still be simple to implement and easier for users.

### CAPM3 change alternatives

One possibility is to manage the lifecycle of `preprovisioningNetworkDataName` outside of
the Metal3 core components - such an approach has been successfully demonstrated
in the [Kanod community](https://gitlab.com/Orange-OpenSource/kanod/) which is related to
the [Sylva](https://sylvaproject.org) project.

The design proposal here has been directly inspired by this work, but I think directly integrating
this functionality into CAPM3 has the following advantages:

* We can close a functional gap which potentially impacts many Metal3 users, not only those involved with Kanod/Sylva
* Directly integrating into CAPM3 means we can use a common approach for `networkData` and `preprovisioningNetworkData`

## References

TODO
