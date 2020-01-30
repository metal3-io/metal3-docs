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

A new date-time field, ``pendingRebootSince``, will be added to the ``provisioning``
section of the BareMetalHost status. This records a time after which the Host
was last requested to reboot (because we cannot trust any value from the user,
who even if well intentioned, may have created the timestamp on a machine that 
was not synchronised with the cluster or has a different timezone).

Since the user interface requirements are still unclear, we will follow 
standard practices of using an annotation ( ``host.metal3.io/reboot`` ) to 
trigger reboots.  It shall contain the UID of the target Machine so that the
controller can validate that the associated Machine has not changed since the
annotation was created.

The actual power management will be performed by the Host controller. This is
necessary to avoid race conditions by ensuring that the ``Online`` flag and any
reboot requests are managed in the same place. 

If
* the value in ``host.metal3.io/reboot`` matches the associated Machine, and
* the value of ``pendingRebootSince`` is less than the ``lastPoweredOn``, and
* the ``Status.PoweredOn`` field is true
then it will update ``pendingRebootSince`` and attempt to power the host off 
regardless of the ``Spec.Online`` setting.

Once the Host is powered off ( ``Status.PoweredOn`` is false ), if/when
* the ``Spec.Online`` field is true, and
* the ``host.metal3.io/reboot`` annotation has been removed
* the ``lastPoweredOn`` time is before the ``pendingRebootSince`` time
then the Host will be powered on again and the ``lastPoweredOn`` timestamp will 
be updated accordingly.

The controller automatically removes the ``host.metal3.io/reboot`` annotation if
* the Host is deprovisioned

In the case of multiple clients, clients detecting that another entity has
already initiated a reboot can detect that the node has reached a safe state by
waiting for either:
* ``Status.PoweredOn`` is false, or
* ``lastPoweredOn`` is greater than the time the would have requested a reboot

## Drawbacks

## Future Enhancements

### Defining a Formal User Interface


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
