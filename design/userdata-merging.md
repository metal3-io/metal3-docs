<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Userdata handling in Metal3-io

In a baremetal deployment, some of the configuration needs to be tightly tied
to the physical node that is being provisioned (for example for networking).
Hence we foresee a need to enable the user to give node-specific configuration.

However, in CAPI v1alpha2, the userdata on the machine for provisioning is
created by CABPK, that is unaware of such constraint. Cluster-API implements
deployments, where all the BaremetalMachine and CABPK output are generated
from a template, that does not allow for node-specific configuration.

Hence we would need to merge the userdata coming from the Machine, the
BaremetalMachine and the BaremetalHost.


## Status

provisional

## Table of Contents

<!--ts-->
   * [Title](#title)
      * [Status](#status)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
         * [Non-Goals](#non-goals)
      * [Proposal](#proposal)
         * [User Stories](#user-stories)
            * [Story 1](#story-1)
            * [Story 2](#story-2)
         * [Implementation Details/Notes/Constraints](#implementation-detailsnotesconstraints)
         * [Risks and Mitigations](#risks-and-mitigations)
      * [Design Details](#design-details)
         * [Work Items](#work-items)
         * [Dependencies](#dependencies)
         * [Test Plan](#test-plan)
         * [Upgrade / Downgrade Strategy](#upgrade--downgrade-strategy)
         * [Version Skew Strategy](#version-skew-strategy)
      * [Drawbacks](#drawbacks-optional)
      * [Alternatives](#alternatives-optional)
      * [References](#references)

<!-- Added by: stack, at: 2019-02-15T11:41-05:00 -->

<!--te-->

## Summary

With v1alpha2, Cluster-API goal is to split the bootstrap provider from the
infrastructure provider. However, in the case of baremetal, such a split is not
straightforward. Some configuration is inherently tied to the physical node (for
example networking, with bonds, vlans etc. or hardware specific setup such as
drivers etc.). There is a need for giving the user the possibility to provide
a node-specific userdata. In this proposal we outline a solution that would
merge different userdata inputs.

## Motivation

### Goals

* Provide support for user-provided cloud-config per node
* Validate the user-provided cloud-config (to prevent conflict with CABPK
  output)
* Merge the inputs from CABPK and user
* Support later addition of further configurations (Ignition etc.).

### Non-Goals

 * Support other type of userdata, considering that Cluster-api only supports
   cloud-init based bootstrap provider (CABPK) we will focus on cloud-init only
   in this proposal.

## Proposal

### User Stories

#### Story 1

Considering a set of motley physical nodes, all with different networking
setup, the user will be able to specify a per-node network configuration. Hence
the BaremetalHost selection can be independent, not requiring to tie
BaremetalHost and BaremetalMachines through labels to give the networking
through a script passed to CABPK.

#### Story 2

Considering a CAPI deployment, it would be possible to specify some
node-specific configuration related to the physical node, offering the user the
possibility to fully use the deployment features such as scale-in/scale-out
independently. The deployment could then use physical nodes that are not
strictly identical.

### Implementation Details/Notes/Constraints

This does not require to modify the current CAPI workflow.
When selecting a baremetalHost for the BaremetalMachine, the controller would
merge the userdata from the machine with the user-provided input and the
load-balancer related input. The output would be written as userdata in the
BaremetalHost for deployment.

### Risks and Mitigations

There are several types of userData, such as cloud-init or ignition. This
proposal should not implement a feature for one that would be detrimental or not
consider another one.

The user could also give some input that directly conflict with the output of
the bootstrap provider. This needs to be handled carefully.

## Design Details

- A new field in the BaremetalHost spec would be added :

```yaml
  spec:
    userDataInput:
      type: cloud-init
      userDataAppend: <base64 userdata file>
      userDataPrepend: <base64 userdata file>
```
The type is compulsory, other fields are optional.

- When merging the different inputs, comes the question of the order of actions
  and the possible conflicts between the inputs. The user will be able to
  specify how the userdata given will be merged with the output from CABPK. In
  the case of cloud-init, the following applies.
- For all fields that are lists, the content of the list, if it exists, in
  userDataAppend will be appended to the content in this list from the
  bootstrap provider. The content of the list, if it exists, in userDataPrepend
  will be added at the beginning of the list from the bootstrap provider.
- For maps, they will be merged and a duplicated key would trigger an error.
- For other types, a duplicated key in the userdata would trigger an error too.
- Not specifically to cloud-init, another place where conflict could occur is
  in the files created by the bootstrap provider. If both the user input and the
  bootstrap provider output are modifying the same file, an error should be
  raised.

The workflow would hence be the following (excluding CAPI controllers steps)
when creating a cluster:

- The user creates the BaremetalHosts CRs with their own input UserDataInput
- The user creates the Cluster and BaremetalCluster
- The BaremetalCluster controller run
- The user create the Machines, the BaremetalMachines and the KubeadmConfigs
  (possibly through deployments)
- The bootstrap provider runs and generates a userdata in the data field of the
  machine
- The BaremetalMachine controller selects a BaremetalHost, gets the input
  userdata from BMH, BaremetalMachine and the userdata from the machine, and
  generates a merged userdata, populating the userdata secret and referencing it
  in the status of BaremetalMachine and in the spec of BMH (UserData).
  Along with having the correct image set, the provisioning will start.

In case of conflict in the userdata, an error will be raised.

An example UserDataInput structure is defined
[here](https://github.com/metal3-io/baremetal-operator/pull/325/files#diff-2336c3885f739a6a5c66bc71e72497b3R162)
It is added in the BMH
[specs](https://github.com/metal3-io/baremetal-operator/pull/325/files#diff-2336c3885f739a6a5c66bc71e72497b3R148)
and in the BaremetalMachine
[specs](https://github.com/metal3-io/cluster-api-provider-baremetal/pull/145/files#diff-af58a22b1a75b3b1a60685fcfa7d5651R46)
. The PoC function doing the merge for cloud-init is
[here](https://github.com/metal3-io/cluster-api-provider-baremetal/pull/145/files#diff-d872081cf5c1d3f4d83e417129c5501cR191)


### Work Items

- Create a new type in BaremetalHost API
- Add a new field in BaremetalHost and BaremetalMachine API spec fields
- Implement a merging feature for cloud-init
- Implement a function that calls the correct meging feature depending on the
  type of the userdata.

### Dependencies

* This is related to the v1alpha2 version of Cluster-api

* The userdata merging feature could be libraries.

### Test Plan

Unit tests and integration tests will be added for this feature. In addition,
this will be directly used in the end-to-end test with Metal3-dev-env for the
networking setup of the vms.

### Upgrade / Downgrade Strategy

Not applicable, for the BaremetalHost, the changes are transparent to existing
deployments, and CAPBM v1alpha2 is work in progress.

### Version Skew Strategy

Not applicable.

## Drawbacks

This will open a highway for users to do some misconfigurations on their
clusters.

## Alternatives

### Implement a new bootstrap provider

This bootstrap provider would be aware of the BaremetalHost, and the mapping
between BaremetalMachine and BaremetalHost would need to happen before the
bootstrap provider would run. The bootstrap provider could then write the
output directly into the baremetalHost.

This option goes against the decoupling of bootstrap and infrastructure provider
done by CAPI community. The bootstrap provider would be relying on
Infrastructure provider objects and not be independent.

### Use cloud-init merging capabilities.

This is problematic as we do not have any fine-grained control on how the
merging is actually performed and can’t easily get errors back.


## References

A PoC of the changes related to the BaremetalHost is
[here](https://github.com/metal3-io/baremetal-operator/pull/325)
A PoC for the implementation of the BaremetalMachineController is
[here](https://github.com/metal3-io/cluster-api-provider-baremetal/pull/145)
