<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# metamorph-provisioner

## Status

implementable

## Summary

This document proposes to add an additional provisioner(metamorph) to current 
metal3 BMH implementation.

## Motivation

The current implementation based on ironic has limited usage in a WAN based 
network particularly in usecases involving edge node deployment. Ironic based
provisioner requires a DHCP setup in place for the initial IPA setup phase.

Metamorph proposes to fill in the gap for non-DHCP environment using a full 
fledged Redfish API based provisioner.

### Goals
- Compliance to Kubernetes Cluster API w.r.t Infrastructure Provisioner.
- Use of Redfish based API for supporting the entire BMH lifecycle.
- The Redfish based provisioner will extend the current metal3 implementation
with an additional choice of new provisioner.
- Ensure user have an option of choosing either of the provisioner that 
is best suited for the case at hand.
- Most of the hardware vendors are supporting Redfish API and the 
implementation is more or less standardised.

### Non-Goals

- No addition to current Metal3 Ironic provisioner capability.

## Proposal
### What is Metamorph

MetaMorph is a tool introduced to provision baremetal nodes in the kubernetes
native way.

MetaMorph uses native Redfish APIs to provision the baremetal nodes thus 
eliminating complex traditional pre-requisties like DHCP, TFTP, PXE booting etc.
ISO used to provision the OS will be mounted from an HTTP share using VirtualMedia 
feature of Redfish.

####  Metamorph Features
- Minimum Pre-requisties/Dependencies : The only Pre-requisties Metamorph has 
is the Redfish Protocal support on the node to be provisioned.
- Edge Node Deployment : Since Metamorph eliminates the complex pre-requisties 
like DHCP, TFTP, PXE booting etc, Its very easy and reliable to deploy edge nodes.
- Vendor Independence : Servers manufactored by any vendor can be deployed 
(provided it supports Redfish protocol)
- Boot Actions : Boot Actions are jobs that will be executed on the first boot of the 
deployed node. It can be used to deploy any kind of software on the target node. 
Boot Actions can be written in any languages.
- Plugin Support : Plugins can do variety of things. It can extend default 
features/functionlity,Add support for old hardware that doesn't support 
Redfish protocol (eg: HP iLO4 RAID Config),

This document proposes to add Metamorph tool into metal3 by adding an new 
Baremetal Provisioner alongside the current ironic provisioner.



### User Stories
#### Story 1
As a User, I want a fast provisioning mechanism based on K8s with minimal 
configuration to deploy hosts at edge sites.

#### Story 2
As a User, I should be able to configure hosts with less steps using only 
Redfish Virtual Media in a non DHCP environment

## Design Details

- A new provisioner (metamorph provisioner) will be introduced. 
- The new provisioner will align with the state machine that manages the current 
ironic baremetal provisioner.
- Hardware inspection will be handled using Redfish API calls directly into the 
node in question.

### Implementation Details/Notes/Constraints

These new features could be incorporated in the existing baremetal provisioner.
- Metamorph has support for additional infrastructure setup functionalities like 
software upgrade/RAID setup etc implemented via the Redfish API.
- Boot Action helps in post installation activities.

### Risks and Mitigations

None


### Dependencies

The metamorph implementation uses the following libraries.

- https://github.com/go-resty/resty

### Test Plan

New unit tests to be added for the metamorph provisioner. 

New integration tests to be added as required.

### Upgrade / Downgrade Strategy

None

### Version Skew Strategy

None 

## Drawbacks

None

## References
- [Reference implementation of Metamorph](https://github.com/bm-metamorph/MetaMorph)
- [Refernce Documentation for Metamorph](https://metamorph.readthedocs.io/en/latest)

