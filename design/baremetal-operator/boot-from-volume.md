<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# boot-from-volume 

## Status 

in-progress 

## Summary 

This document explains the implementation of  boot from remote volume (namely diskless boot) in baremetal-operator. 

## Motivation 

We need to document how we going to specify the boot from volume of the baremetal, including how to configure the remote volume,  the connector of baremetal and this remote volume. 

### Goals 

1. To agree on boot from volume specification system, including the configuration format and the architecture of the implementation. 

### Non-Goals 

1. To list all kinds of baremetal remote volume connectors.  

## Proposal 

### Implementation Details/Notes/Constraints 

For boot from remote volume, you should specify the "BootVolume" attributes in BareMetalHostSpec,   these include: 

1. VolumeId: the volume identification of your remote volume in your VolumeDriver system; 

2. VolumeDriver: the volume driver name, now ironic only support noop, cinder or external, where only cinder or external driver can support boot from volume. 

3. ConnectorId:  the identification of connection with target, format like "iqn.2010-10.openstack.org.nodeId".

4. TargetType: the target type of baremetal and volume, it can be iscsi(implemented) or fibre-channel(not included now). 

5. IscsiTarget: the details of iscsi attributes, include AuthUser, AuthPasswd, AuthMethod, Iqn, Lun, Portal, IType and so on, in which AuthMethod is "CHAP",  IType is "iqn". 

6. IscsiCredentialsName:  the credential in k8s for baremetal-operator to replace AuthUser and AuthPasswd in iscsi attributes for safety (not implemented in controller now).


If VolumeId and VolumeDriver are configured, it will go to the boot from volume logic implementation, so please do not speicify them if you don't want this to happen. 


### Risks and Mitigations 

Risks lie in other dependent project, e.g. ironic and gophercloud.  Some versions of ironic do not support external,  and there is no api interface in gophercloud to deal with baremetal volume (this has been solved in new pull request, but it still needs time to wait for test and merge). 

## Design Details

### Work Items

Most of the work is completed, some tasks are still outstanding:

- Credentials to replace AuthUser and AuthPasswd for iscsi in baremetal operator.
- Other volume connective targets (not only iscsi) implementation.

### Dependencies

N/A

### Test Plan

First i should include some unit test, then acceptance test should happen in real environment for different volume driver cinder and external respectively.

### Upgrade / Downgrade Strategy

N/A

### Version Skew Strategy

N/A

## Alternatives

## References

- [PR in baremetal-operator to enable boot from volume](https://github.com/metal3-io/baremetal-operator/pull/1147)

- [DOC in Openstack-ironic to explain boot from volume](https://docs.openstack.org/ironic/rocky/admin/boot-from-volume.html)








