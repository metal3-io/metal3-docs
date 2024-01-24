<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# prototype-a-physical-network-api

## Status

implemented

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

- A `Switch` CRD with one or more fields that corresponding to switch
  configuration, ideally with a vendor neutral definition.  Note that the CRD
  definition may be simplified for PoC purposes and the data model would likely
  be revisited in more detail post-PoC.
- A demonstration of using this prototype API to configure a switch
- A documented retrospective that includes lessons learned and proposed next
  steps
- Evaluate the re-use of a single existing network device configuration
  technology

### Non-Goals

Out of scope:

- Testing with anything more than a single switch model
- Prototyping an API for anything beyond a Switch
- Full configuration possibilities of a switch
- Evaluation of all potential technologies that could be re-used for network
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
`network-runner`, and have a controller written in golang call that. Another
relevant Python tool to consider is
[kopf](https://github.com/zalando-incubator/kopf).  Other approaches to Ansible
networking re-use can be considered and discussed in the read-out from the
prototype.

### User Stories

#### Story 1

As a consumer of Metal³, when creating or updating a `BareMetalHost` resource,
I would also like to create or update a `Switch` resource to re-configure a
switch port that is attached to one of the network interfaces on the
`BareMetalHost`.

### Implementation Details/Notes/Constraints

Notes by Brad P. Crochet <brad@redhat.com>

#### Approach

The main focus of this PoC is the feasibility of an operator to manage a physical
ToR switch. A number of technologies were considered. For this PoC, an Ansible
Operator was used, along with the network-runner role from Ansible Networking[^1].

The PoC was conducted locally with Minikube and the switch virtual appliance.

Creating an Ansible Operator was the natural choice. It also was a good choice.
It allowed me to get a working prototype up very quickly.

The first hurdle was the inventory. The Ansible Operator assumes that you are
running commands on the cluster node that is running the pod. As such, there
is no inventory file to be modified. This is just a small hurdle. Ansible has
modules to manage the inventory dynamically. This made it easy to create an
inventory entry for the target switch.

I started the PoC attempting to use the Cumulus Linux virtual switch. I did
not successfully set it up to be able to actually add a VLAN. I then moved
on to using an Arista vEOS device. I was able to then create a VLAN with
Ansible Networking as intended.

Finally, I was able to update the status of the custom resource. Typically,
Ansible Operator would manage the status. However, it would be ideal to keep
track of the current state of the resource, without having to query the switch.
Then support for full reconciliation should become possible, i.e. removing a
VLAN that is no longer listed in the custom resource.

A link to the PoC code is linked below. [^2] A demo is also linked below. [^3]

#### Limitations

- Network Runner not in Ansible Galaxy
   - Manual inclusion in operator
- Limited number of switches supported in Network Runner
   - Should be relatively simple to add new ones, as long as there is an
     Ansible Networking module supporting the target switch
- Limited number of operations in Network Runner
   - More are being developed
   - Create/delete VLAN, Create/delete access port, Create/delete trunk port

All of these limitations should be easy to remedy.

#### Examples

Here is a sample CR:

```yaml
apiVersion: metal3.io/v1alpha1
kind: Switch
metadata:
  name: example-switch
spec:
  ipAddress: 192.168.122.181
  port: 22
  credentialsName: my-eos-secret
  networkOS: eos
  vlans:
    - id: 10
      name: test-vlan
```

#### Conclusions

Overall, I would count this PoC as a success. A few things that were not
attempted during this PoC, but would be necessary for future development
would be:

- CI - Setting up a virtual switch for testing
- Unit tests - Usage of Molecule
- Full reconciliation of the resource - Deletion of VLANs, etc.
- Testing with an actual physical switch

Special thanks to Dan Radez for helping with the virtual switch setup.

#### Links

[^1]: <https://github.com/ansible-network/network-runner>

POC Code

[^2]: <https://github.com/bcrochet/physical-switch-operator/>

Demo

[^3]: <https://www.youtube.com/watch?v=zlJmao_qnrw&t=8sNone>

### Risks and Mitigations

None

## Design Details

- To be determined during prototype implementation

### Work Items

- Define enough of a `Switch` CRD for a prototype
- Explore approaches to driving ansible from a golang based Kubernetes
  controller
- Implement `Switch` controller which uses Ansible to drive reconciliation

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

## Drawbacks

None

## Alternatives

There are certainly alternative prototypes that could be developed, but the
proposal is to start with the one described in this document.  Summaries of
possible future prototypes can be added to this section.

## References

- <https://docs.ansible.com/ansible/latest/network/index.html>
- <https://networking-ansible.readthedocs.io/en/latest/>
- <https://github.com/operator-framework/operator-sdk>
- <https://github.com/zalando-incubator/kopf>
