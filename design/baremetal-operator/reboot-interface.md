<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# reboot-interface

## Status

implemented

## Summary

A declarative API is proposed to request the baremetal operator to reboot a
provisioned Host in an atomic step (i.e. without the need to make multiple
sequential changes to the spec).

## Motivation

We require a non-destructive way to fence a Kubernetes node. Some nodes cannot
be replaced (it is currently not possible for a new controlplane to join a cluster),
or are expensive to replace (e.g. if this would require rebalancing Ceph data).
A solution to this is for fencing to reboot the Host, thus ensuring that
running processes are stopped to avoid a split-brain scenario while still
allowing the node to rejoin the cluster with its data intact (albeit stale)
after the reboot.

The expected implementation of this on the fencing side is an annotation on the
Machine resource that requests that it be remediated. The actual reboot will be
effected either by the Machine Actuator itself (if the Cluster-API SIG can be
persuaded that this should be part of the API in the long term), or some
equivalent of the Machine Actuator limited to just this purpose.

### Goals

The Machine (Reboot) Actuator will require from the BareMetalHost:

- A declarative API to perform the reboot
- The ability to determine a point where all processes running on the Host at
  the time of the fencing decision are guaranteed to have been stopped
- A guarantee that the Reboot Actuator can delete any Node associated with the
  Machine before the Host is able to complete booting (including in testing
  when the Host is simulated by a VM).
- Rapid convergence to a state where all running processes are stopped,
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

This API is not responsible for managing unprovisioned hosts, e.g. to recover
from state inconsistencies in Ironic prior to provisioning. Any such
inconsistencies that are not handled internally by the BareMetalHost will
likely need manual intervention to recover anyway.

## Proposal

A new date-time field, ``lastPoweredOn``, will be added to the ``provisioning``
section of the BareMetalHost status. This records a time after which the Host
was last booted using the current image. Processes running prior to this time
may be assumed to have been stopped.

A new date-time field, ``pendingRebootSince``, will be added to the
``provisioning`` section of the BareMetalHost status. This records a time
before which the Host was last requested to reboot (because we cannot trust any
value from the user, who even if well intentioned, may have created the
timestamp on a machine that was not synchronised with the cluster or has a
different timezone).

Since the user interface requirements are still unclear, we will follow
standard practices of using an annotation to trigger reboots.

The basic annotation form (``reboot.metal3.io``) triggers the controller to
power cycle the Host. This form has set-and-forget semantics and the controller
removes the annotation once it restores power to the Host.

An advanced form (``reboot.metal3.io/{key}``) instructs the controller hold the
Host in a ``PoweredOff`` state so that the caller can perform any required
actions while the node is in a known safe state. Callers indicate to the
controller that they are ready to continue by removing the annotation with
their unique ``{key}`` suffix.

In the case of multiple clients, the controller will wait for all annotations
of the form ``reboot.metal3.io/{key}`` to be removed before powering on the
Host.

If both ``reboot.metal3.io`` and ``reboot.metal3.io/{key}`` forms are in use,
the ``reboot.metal3.io/{key}`` form will take priority.

In all cases, the content of the annotation is ignored but preserved. This
ensures that whatever placed the annotation can have a way of tracing it back
to its source. In the case of remediation, the content will be the UID of the
Machine resource being remediated.

The actual power management will be performed by the Host controller. This is
necessary to avoid race conditions by ensuring that the ``Online`` flag and any
reboot requests are managed in the same place.

If:

- there is one or more annotations with the ``reboot.metal3.io`` prefix
  present, and
- the ``Status.PoweredOn`` field is true, and
- the value of ``pendingRebootSince`` is empty or earlier than the
  ``lastPoweredOn`` time

then the Host controller will update ``pendingRebootSince`` to the current
time.

Whenever ``pendingRebootSince`` is later than the ``lastPoweredOn`` time, the
Host controller will attempt to power the host off regardless of the
``Spec.Online`` setting.

Once the Host is powered off (``Status.PoweredOn`` is false), if/when

- the ``Spec.Online`` field is true, and
- the ``lastPoweredOn`` time is before the ``pendingRebootSince`` time

then the controller should remove the suffixless ``reboot.metal3.io``
annotation (if present). Once no reboot annotations are present (i.e. those of
the form ``reboot.metal3.io/{key}`` have been removed by their originators),
the existing logic for powering on the Host should execute and update the
``lastPoweredOn`` timestamp accordingly.

The controller automatically removes all annotations with the
``reboot.metal3.io`` prefix if

- the Host is deprovisioned

The annotation value should be a JSON map containing a key `'mode'` with values
of `'hard'` or `'soft'` to specify the reboot mode. The default reboot mode is
`'soft'`. These are a few examples of using the reboot API:

- `reboot.metal.io` -- immediate reboot via soft shutdown first,
  followed by a hard shutdown if the soft shutdown fails.
- `reboot.metal3.io: {'mode':'hard'}` -- immediate reboot via hard
  shutdown, potentially allowing for high-availability use-cases.
- `reboot.metal3.io/{key}` -- phased reboot, issued and managed by the
  client registered with the `key`, via soft shutdown first, followed
  by a hard reboot if the soft reboot fails.
- `reboot.metal3.io/{key}: {'mode':'hard'}` -- phased reboot, issued
  and managed by the client registered with the `key`, via hard
  shutdown.

It's important to note that as the API supports multiple clients, a hard
shutdown request takes priority over a soft shutdown request, allowing
workload recovery to take precedence over a graceful shutdown of a node.

## Drawbacks

This requires clients to be somewhat well-behaved - for example, only deleting
their own annotations and never deleting others' annotations.

It would be difficult to apply RBAC to the reboot operation specifically, since
it is triggered by simply adding an annotation (that doesn't even have a fixed
key).

## Future Enhancements

### Defining a Formal User Interface

Once we have experience with using this, we will have more information about
how to design a formal interface for it (rather than using annotations).

## Alternatives

The Machine (Reboot) Actuator could perform the reboot in an imperative, rather
than declarative, manner by manipulating the ``Online`` spec of the Host in
sequence to ``false`` and then back to ``true`` again once the ``poweredOn``
status was seen to be ``false``. However, in the presence of multiple actors
this approach is prone to race conditions or controller fights.

We could create a ``HostRebootRequest`` CRD and have the existing host
controller check for pending reboot requests, perform reboots when necessary,
and update the state of the request. This would be easier to apply RBAC to, and
indeed does not require clients to co-operate in any way. It would be a
flexible jumping off point for adding more advanced features should they become
required. However, it adds significant complexity (another CRD to deploy) and
would be a permanent, formal interface. It's also not clear how outdated
requests should be cleaned up.

The request could simply be a timestamp field in the Host spec. The Host would
coalesce multiple requests into one at the time they are received (rather than
at the point of action). This would be simpler, but requires the client to
provide a meaningful timestamp (i.e. in the recent past), forcing us to make
awkward decisions about what to do with bogus data. In contrast, allowing
multiple annotations allows the system to record the time at which it first
noticed them. Selecting this option would also make it more difficult to add
further reboot-related API features in the future.

The request could be made by adding to a list of client-chosen strings in the
Host spec. This effectively formalises the annotation-based system proposed
here and makes it a permanent part of the interface.
