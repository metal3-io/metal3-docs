<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# prototype-a-physical-network-api

## Status

implementable

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
         * [User Stories [optional]](#user-stories-optional)
            * [Story 1](#story-1)
            * [Story 2](#story-2)
         * [Implementation Details/Notes/Constraints [optional]](#implementation-detailsnotesconstraints-optional)
         * [Risks and Mitigations](#risks-and-mitigations)
      * [Design Details](#design-details)
         * [Work Items](#work-items)
         * [Dependencies](#dependencies)
         * [Test Plan](#test-plan)
         * [Upgrade / Downgrade Strategy](#upgrade--downgrade-strategy)
         * [Version Skew Strategy](#version-skew-strategy)
      * [Drawbacks [optional]](#drawbacks-optional)
      * [Alternatives [optional]](#alternatives-optional)
      * [References](#references)

<!-- Added by: stack, at: 2019-02-15T11:41-05:00 -->

<!--te-->

## Summary

The Metal³ project is currently centered around an API for managing physical
hosts.  This proposal is to explore expanding the scope to also include an API
for managing physical network devices.  This exploration would be done by
starting with a prototype that can configure some aspects of a top-of-rack
(ToR) switch.

## Motivation

Metal³ follows the paradigm of Kubernetes Native Infrastructure (KNI), which is
an approach to use Kubernetes to manage underlying infrastructure.  Managing
the configuration of some physical network devices is closely related to
managing physical hosts.

As bare metal hosts are provisioned or later repurposed, there may be
corresponding physical network changes that must be made, such as reconfiguring
a ToR switch port.  If the provisioning of the physical host is managed through
a Kubernetes API, it would be convenient to be able to reconfigure related
network devices using a similar API.

### Goals

Produce a `physical-network-api` prototype, which includes the following:

* A `Switch` CRD with one or more fields that corresponding to switch
  configuration, ideally with a vendor neutral definition.  Note that the CRD
  definition may be simplified for PoC purposes and the data model would likely
  be revisited in more detail post-PoC.
* A demonstration of using this prototype API to configure a switch
* A documented retrospective that includes lessons learned and proposed next
  steps
* Evaluate the re-use of a single existing network device configuration
  technology

### Non-Goals

Out of scope:

* Testing with anything more than a single switch model
* Prototyping an API for anything beyond a Switch
* Full configuration possibilities of a switch
* Evaluation of all potential technologies that could be re-used for network
  device configuration.  Future prototypes can be done to consider other
  alternatives if desired.

These items may become in scope after a prototype is reviewed and next steps
discussed.

## Proposal

The prototype should explore the re-use of [Ansible
Networking](https://docs.ansible.com/ansible/latest/network/index.html) to
perform device configuration.  Ansible includes modules for managing the
configuration of many different network devices.  Creation of CRDs in this new
API can use modeling from Ansible as inspiration, particularly if there is any
vendor neutral modeling already done there.

Another project that could be used as inspiration is the [Ansible Networking
Neutron ML2 Driver](https://networking-ansible.readthedocs.io/en/latest/) which
created a Python API to abstract generic switch configuration on top of Anisble
networking modules.  Note that the relevant part of the driver was split out
into the
[ansible-network/network-runner](https://github.com/ansible-network/network-runner)
repository.

The [operator-sdk](https://github.com/operator-framework/operator-sdk) project
includes some support for Ansible operators.  One approach could be to use an
ansible operator to run playbooks that use the roles from the [network-runner
repository](https://github.com/ansible-network/network-runner). Another
approach could be to build a new API (gRPC, for example) around
`network-runner`, and have a controller written in golang call that. Other
approaches to Ansible networking re-use can be considered and discussed in the
read-out from the prototype.

### User Stories [optional]

#### Story 1

As a consumer of Metal³, when creating or updating a `BareMetalHost` resource,
I would also like to create or update a `Switch` resource to re-configure a
switch port that is attached to one of the network interfaces on the
`BareMetalHost`.

### Implementation Details/Notes/Constraints [optional]

None

### Risks and Mitigations

None

## Design Details

* To be determined during prototype implementation

### Work Items

* Define enough of a `Switch` CRD for a prototype
* Explore approaches to driving ansible from a golang based Kubernetes
  controller
* Implement `Switch` controller which uses Ansible to drive reconciliation

### Dependencies

None

### Test Plan

TBD

It would be desirable to have a way to test this in `metal3-dev-env` for simple
development and testing.  This would also be needed for CI purposes in the
future if this project is pursued.

As part of wrapping up the prototype, it is desirable to demonstrate the
resulting code against a real switch.

### Upgrade / Downgrade Strategy

None for the prototype

### Version Skew Strategy

None for the prototype

## Drawbacks [optional]

None

## Alternatives [optional]

There are certainly alternative prototypes that could be developed, but the
proposal is to start with the one described in this document.  Summaries of
possible future prototypes can be added to this section.

## References

* https://docs.ansible.com/ansible/latest/network/index.html
* https://networking-ansible.readthedocs.io/en/latest/
* https://github.com/operator-framework/operator-sdk
