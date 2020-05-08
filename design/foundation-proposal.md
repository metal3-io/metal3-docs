<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Community Future - Proposal to Move to the CNCF Sandbox

## Status

provisional

## Summary

metal3-io was created to enable collaboration on the provisioning of bare metal
hosts using Kubernetes.  The project was bootstrapped without much formal
community governance.  Now that the project is a year old and has contributors
from several companies, it is time to revisit some of the community structure
and its future.

This proposal is to apply to become a [CNCF Sandbox
Project](https://www.cncf.io/sandbox-projects/).

## Motivation

When we started the metal3-io project in early 2019, we skipped over doing much
to formalize governance.  We felt focusing on building something useful was
more important.  If the project worked out and we started building a community,
then we would revisit formalizing project governance for the future.

After a year, we have produced useful code and a community involving multiple
companies has formed to collaborate.  It’s a good time to consider what changes
might best support this community for the future.

Some changes have already started happening, such as formalizing the process
for adding and removing maintainers to repositories. This document suggests
a next step of applying as a CNCF Sandbox project.

### Goals

- Align with other CNCF ecosystem projects in terms of policies and processes.
- Assets are transferred to a neutral third party (i.e. domains)
- Gain more visibility in the CNCF ecosystem to attract others who may be
  interested in collaborating on bare metal host provisioning with Kubernetes.

### Non-Goals

- No changes to the metal3-io code are in scope of this proposal.  This
  proposal is only about the community future.
- No changes to committer processes are proposed here.  We already have a
  documented [process for adding and removing
  maintainers](../maintainers/README.md).

## Proposal

Apply to become a [CNCF Sandbox
project](https://www.cncf.io/sandbox-projects/).

The [Goals](#goals) section discusses some of the immediate changes we should
expect, but as the project continues to mature, many of the other services
provided by the CNCF would be very beneficial to metal3-io.  The CNCF web site
does a nice job discussing what services they offer projects on the
[Services for CNCF Projects](https://www.cncf.io/services-for-projects/) page.

## Design Details

### Work Items

- (russellb) Write this proposal.
- (everyone) Provide feedback on initial proposal, reach consensus.
- (russellb) If approved, draft the [CNCF Sandbox
  application](https://github.com/cncf/toc/blob/master/process/project_proposals.adoc)
  first as a draft in this repository.
- (everyone) Provide feedback on application text, reach consensus.
- (russellb) Submit Application.
- (russellb + others) Prepare and deliver a presentation to the CNCF TOC.
  Invite metal3 community members to attend.
- (russellb) If accepted, transfer project assets as appropriate to CNCF.

## Alternatives

### No Foundation

We could stick with the status quo, where one person or organization owns
certain assets (like domains), and evolve our governance as needed to support
the collaboration among many different teams at different organizations.  While
we seem to be working well together so far, we would also miss out on some of
the benefits of being more closely aligned with the CNCF ecosystem.

### OSF (OpenStack Foundation)

The baremetal-operator makes use of Ironic, which came out of OpenStack.
Ironic is hidden as an implementation detail, though.  In terms of where we
expect the metal3 components to be used, it’s really more closely aligned with
the Kubernetes ecosystem and the CNCF.

### Kubernetes Cluster Lifecycle SIG

One of the components of metal3-io is a provider for
[cluster-api](https://github.com/kubernetes-sigs/cluster-api).  While the
provider itself could fall under this SIG, the scope of metal3-io is larger
than supporting cluster-api.  metal3-io provides a Kubernetes API for generic
bare metal host provisioning and cluster-api integration is just one use case.
Since the scope of metal3-io is more broadly about bare metal host
provisioning, we decided to organize it as an independent project.  It’s also
convenient to keep the cluster-api provider along side the other related git
repositories as part of metal3-io.  metal3-io community members do continue to
collaborate with the cluster-api project.

## References

- Sample application: [KubeVirt sandbox
  application](https://github.com/cncf/toc/pull/265)
- [CNCF Graduation
  Criteria](https://github.com/cncf/toc/blob/master/process/graduation_criteria.adoc)
