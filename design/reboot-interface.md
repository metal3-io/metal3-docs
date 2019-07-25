<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# reboot-interface

## Status

implementable

## Table of Contents

<!--ts-->
   * [reboot-interface](#reboot-interface)
      * [Status](#status)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
         * [Non-Goals](#non-goals)
      * [Proposal](#proposal)
      * [Drawbacks](#drawbacks)
      * [Future Enhancements](#future-enhancements)
      * [Alternatives](#alternatives)

<!--te-->

## Summary

A declarative API is proposed to request the baremetal operator to reboot a
provisioned Host in an atomic step (i.e. without the need to make multiple
sequential changes to the spec).

## Motivation

We require a non-destructive way to fence a Kubernetes node. Some nodes cannot
be replaced (it is currently not possible for a new master to join a cluster),
or are expensive to replace (e.g. if this would require rebalancing Ceph data).
A solution to this is for fencing to reboot the Host, thus ensuring that
running processes are stopped to avoid a split-brain scenario while still
allowing the node to rejoin the cluster with its data intact (albeit stale)
after the reboot.

The expected implementation of this on the fencing side is a Custom Resource
Definition that requests a Machine be rebooted. The actual reboot will be
effected either by the Machine Actuator itself (if the Cluster-API SIG can be
persuaded that this should be part of the API in the long term), or some
equivalent of the Machine Actuator limited to just this purpose.

### Goals

The Machine (Reboot) Actuator will require from the BareMetalHost:

* A declarative API to perform the reboot
* The ability to determine a point where all processes running on the Host at
  the time of the fencing decision are guaranteed to have been stopped
* Rapid convergence to a state where all running processes are stopped,
  independent of other happenings in the system

### Non-Goals

There is no requirement to implement a scheduled reboot. In the Kubernetes
context, reboot decisions should generally be made in realtime by some higher
level of the Node/Machine hierarchy, to take into account such questions as the
overall health of the cluster and the effect of a reboot on that. The best
implementation for this would be a RebootSchedule CRD that waits until the
appointed time before issuing an immediate reboot request to the BareMetalHost.
This allows multiple reboots to be scheduled, scheduled reboots to be
manipulated or cancelled, and a record to be left behind of past scheduled
reboots. The proposed design could easily be extended to accomodate this
requirement should it arise in future.

There is no requirement to hold the power off for any particular length of
time. For fencing purposes we only need to be sure when the node is powered
off.

This API is not responsible for managing unprovisioned hosts, e.g. to recover
from state inconsistencies in Ironic prior to provisioning. Any such
inconsistencies that are not handled internally by the BareMetalHost will
likely need manual intervention to recover anyway.

## Proposal

A new date-time field, ``lastPoweredOn``, will be added to the ``provisioning``
section of the BareMetalHost status. This records a time after which the Host
was last booted using the current image. Processes running prior to this time
may be assumed to have been stopped.

To provide a declarative interface for performing a reboot, a new
BareMetalHostRebootRequest CRD will be created. The spec of this custom
resource will contain only a reference to a BareMetalHost. The status will
contain timestamps for when the Host was powered off and on again. Once the
power off time is present in the status, the host has been stopped. Each
RebootRequest will be owned by the Host it refers to, so that if the Host is
deleted all associated RebootRequest CRs will be cleaned up.

The actual power management will be performed by the Host controller. This is
necessary to avoid race conditions by ensuring that the ``Online`` flag and any
reboot requests are managed in the same place. The Host controller
will watch RebootRequest objects and trigger a reconciliation of the linked
Host when one appears or changes.

For simplicity, we will try to avoid creating a separate controller for the
RebootRequest at all, but instead perform all operations on it in the course of
reconciling the BareMetalHost object that it references. However, it may yet
prove necessary to also create a trivial controller for the purposes of basic
housekeeping (e.g. setting the owner of the resource).

The creation timestamp of the request resource will be interpreted as the time
of the reboot request. Requests that predate the last booted time will be
immediately marked as complete without taking any further action. The Host
controller will timestamp all pending reboot requests as having completed the
power off stage whenever any of the following occur:

* The Host has been deprovisioned (in this case the ``lastPoweredOn`` field
  will be empty)
* The ``lastPoweredOn`` time is after the time of the reboot request
* The ``poweredOn`` status is ``false``

Whenever there are pending reboot requests, the Host controller will respond by
powering off the Host (if it is not already) and timestamping all pending
requests as having completed the power off stage. Power will then be restored
only if/when the ``Online`` spec of the Host is true. Once Hosts are powered up
again, any satisfied reboot requests will be timestamped as having completed
the power on stage, with this timestamp matching the ``lastPoweredOn`` time of
the Host.

## Drawbacks

This approach entails a whole new custom resource definition to maintain, and
the instances of this resource must be managed by the Host controller, which
adds a degree of complexity.

If large numbers of requests are created but never deleted, searching for
pending requests may start to consume significant resources.

## Future Enhancements

### Labelling

Adding labels to partially completed and completed requests would allow us to
exclude them when querying for pending requests. That would eliminate the
performance concerns associated with allowing old requests to accumulate. This
would be best performed by a RebootRequest-specific controller.

### Automatic deletion

The operator could automatically delete requests once they have been fulfilled
(either immediately or after a predefined timeout). This would both eliminate
performance concerns and reduce clutter. Clients wishing to observe data from
the resource could set a finalizer that keeps the resource around only until
they are done with it. This might best be performed by a RebootRequest-specific
controller.

### Custom Timestamps

The resource could allow the user to specify a timestamp, which may of course
be in the future. The operator would ignore these requests until the appointed
time, and only then effect the reboot. The request could safely be deleted at
any point prior to the requested time.

### Soft Reboots

The resource could accept a "soft" reboot option, in which we would attempt to
reboot the Host without switching the power off. Since these requests may fail,
more error reporting would likely be required. In the event that a mix of hard
and soft reboot requests were pending, the host would be hard-rebooted and all
of the pending requests marked complete.

## Alternatives

The Machine (Reboot) Actuator could perform the reboot in an imperative, rather
than declarative, manner by manipulating the ``Online`` spec of the Host in
sequence to ``false`` and then back to ``true`` again once the ``poweredOn``
status was seen to be ``false``. However, in the presence of multiple actors
this approach is prone to race conditions or controller fights.

The request could simply be a timestamp field in the Host spec. The Host would
coalesce multiple requests into one at the time they are received (rather than
at the point of action). This would be simpler, but requires the client to
provide a meaningful timestamp (i.e. in the recent past), forcing us to make
awkward decisions about what to do with bogus data. In contrast, with a CRD we
can use the creation timestamp provided by the system. This option also makes
it more difficult to add further reboot-related API features in the future.

The request could be made by adding to a list of client-chosen strings in the
Host spec. This would be again be simpler than adding a new CRD at the cost of
future flexibility, but requires clients to co-operate (by only adding to the
list, and never replacing it), so one misbehaving client could cause another to
act erratically.
