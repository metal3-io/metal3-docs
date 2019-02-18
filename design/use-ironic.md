<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# use-ironic

## Status

implementable

## Table of Contents

<!--ts-->
   * [use-ironic](#use-ironic)
      * [Status](#status)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
         * [Non-Goals](#non-goals)
      * [Proposal](#proposal)
         * [User Stories [optional]](#user-stories-optional)
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

<!-- Added by: stack, at: 2019-02-18T16:27-05:00 -->

<!--te-->

## Summary

Part of being a bare metal provisioning system is having the ability
to control and provision images to bare metal hosts. Many such systems
exist, so rather than build a new one we want to select an existing on
that supports our needs. Initially this will be
[Ironic](https://docs.openstack.org/ironic/latest/).

## Motivation

We want to choose a tool that has an API to drive, provides good
community support, can handle a variety of hardware, and can run in a
Kubernetes environment. Ironic meets all of those criteria.

### Goals

1. Choose an existing provisioning/deployment tool to be used to
   configure hosts and their images.
2. Create an architecture that allows us to choose a different tool
   later, if we have some reason to do that.

### Non-Goals

1. Build a new provisioning/deployment tool for the sake of having one
   written in golang.
2. Integrate with every provisioning/deployment tool potential users
   of MetalKube might have in their data centers.

## Proposal

Package Ironic as an image in a way that allows us to drive it from an
operator, but hide its use from the end user. Maintain and access
state using the Kubernetes API, with the operator calling Ironic as
needed to refresh that information or make changes to the Host. Hide
Ironic from the end-user as completely as possible (it might be
exposed through error messages relayed from the back end service, for
example).

### User Stories [optional]

None

### Implementation Details/Notes/Constraints [optional]

- We want to eliminate the need for a MySQL database. Ironic needs a
  database, but it is not the source of truth for what Hosts exist or
  what their status should be, so there is no need for the complexity
  of a MySQL database.
- We want to eliminate the need for a RabbitMQ message bus by
  deploying Ironic using an all-in-one configuration or using an
  alternative messaging system that removes the complexity of running
  Rabbit.
- We need to include Ironic Inspector as well as the main Ironic API
  so we can perform hardware introspection.
- Both services should run inside the same Pod as the
  baremetal-operator.
- The Pod containing the services will need host network access to be
  able to run a PXE service on the provisioning network.

### Risks and Mitigations

Giving the Pod host network access gives it the ability to see much
more of the host on which it is running. On the other hand, this is a
provisioning tool, and it's going to be writing images to hosts. So it
already has quite a lot of power. As a future enhancement, we can
investigate using multus to manage the networks the Pod needs to
access.

## Design Details

We are running the Ironic inside the same Pod as the operator because
it encapsulates it in a way that lets us treat Ironic as an
implementation detail and avoids needing to write logic in the
operator to ensure that there is a Deployment created to manage a
separate pod to host them, and secure the API from access by anything
other than the operator.

### Work Items

- The YAML file with the specification for the Pod to run the operator
  to be expanded to include the other container(s) needed for Ironic.

### Dependencies

- Ironic image
- Ironic Inspector image

### Test Plan

We will eventually run end-to-end tests using Ironic and the operator.

Ironic itself will be tested using the standard OpenStack testing
resources.

### Upgrade / Downgrade Strategy

TBD

### Version Skew Strategy

Version skew should not apply if the operator and ironic services run
in the same Pod.

## Drawbacks [optional]

Ideally we would not need a long running service at all, but until we
have a tool compatible with the Job API we cannot avoid that.

## Alternatives [optional]

We could run Ironic and Ironic Inspector in their own Pod, outside of
the one containing the baremetal-operator. This would make local
development of the operator a little simpler, because developers would
not need to run the services on their local host. On the other hand,
it means we have to somehow tell the operator where the two services
are so it can build a URL to communicate with them. It also means
something needs to manage the Pod running the services to ensure it is
present in the cluster when it is needed, and secure the service in
that Pod from unauthorized access.

We talked about building a simpler program based on the Ironic code
base that would perform a single operation. We could then invoke it
via the Kubernetes Job API. This may still happen, but since the tool
is hidden from the user it will not affect users.

## References

- [Ironic Documentation](https://docs.openstack.org/ironic/latest/)
- [Ironic Inspector Documentation](https://docs.openstack.org/ironic-inspector/latest/)
- [MetalKube Ironic image](https://quay.io/repository/metalkube/metalkube-ironic)
- [MetalKube Ironic Inpsector image](https://quay.io/repository/metalkube/metalkube-ironic-inspector)
