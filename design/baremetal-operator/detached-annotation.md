<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Add support for Detached annotation

## Status

implemented

## Summary

Provide a way to prevent management of BaremetalHost resources
after provisioning is completed, to facilitate the pivot of
BaremetalHost resources in a multi-tier deployment.

## Motivation

In a multi-tier deployment where one cluster deploys another, the "parent"
cluster will contain BMH resources for initial provisioning,
but the "child" cluster will later contain BMH resources that reference the
same physical hosts.

In this scenario it's necessary to prevent management operations from the
parent cluster such as asserting power state, or BMH actions on the child
cluster such as the [reboot annotation](reboot-interface.md) may fail due
to unwanted BMC interactions from the parent cluster.

There is an existing
[pause annotation](https://github.com/metal3-io/baremetal-operator/blob/master/docs/api.md#pausing-reconciliation)
which pauses reconciliation of the BMH resources, but this does not remove
the underlying Ironic host, so power management actions may be performed
even when the BMH is marked as `paused`.

### Goals

* Add an API to disable management of a BMH on the parent cluster, including
  all power management actions
* Make it possible to delete a BMH resource in this "detached" without
  triggering deprovisioning
* Ensure it is possible to restart management of BMH resources (in the case
  where they are not deleted from the parent cluster)
* Avoid changing behavior of the existing `paused` annotation since that
  behavior is necessary as part of the CAPI pivot process.

### Non-Goals

* Any coordination between the tiers of BMH resources, that has to be handled externally

## Proposal

### Expected workflow

* User creates BMH resource(s) in parent cluster
* Provisioning of BMH triggered, which results in a running child cluster
* Parent cluster BMH resources annotated as detached
* Child cluster BMH resources created, with BMC credentials, but marked
  externallyProvisioned: true

At this point, the physical hosts are owned by the child cluster BMH, but the
inventory still exists in the parent cluster.

In the event that all of the child cluster hosts require reprovisioning, it
would be necessary to remove the detached annotation on the parent BMH resources,
so that management of those resources can resume, e.g for reprovisioning.

### API changes

Add support for a new annotation, where the key is `baremetalhost.metal3.io/detached`

```yaml
baremetalhost.metal3.io/detached: ""
```

The value is ignored, similar to the `paused` annotation and could optionally
include context from the system/user which applies the annotation.

This annotation will only be consumed while the BMH is in either `Provisioned`,
`ExternallyProvisioned` or `Ready`/`Available` state, in all other cases it is ignored.

This annotation will be evaluated early in the `Reconcile()` loop, but after the
`paused` `status` and `hardwaredetails` annotations are evaluated.

When the `detached` annotation is set, we will check the `status.provisioning.ID`
and if necessary delete the corresponding host from Ironic (without triggering
deprovisioning)

When the `detached` annotation is removed, we will re-create the host in Ironic
via the existing `ensureRegistered` state machine logic.

If a BMH resource is deleted while the `detached` annotation is set, we will
move directly to the `Deleting` state, without performing any `Deprovisioning`.

## Alternatives

It would be possible to modify the behavior of the
[pause annotation](https://github.com/metal3-io/baremetal-operator/blob/master/docs/api.md#pausing-reconciliation)
such that Ironic hosts are removed while paused, however
this means that we cannot reflect any error via the status
or increment the errorCount for the retry backoff.

We could add an API that sets the Ironic
[maintenance mode flag](https://docs.openstack.org/api-ref/baremetal/?expanded=set-maintenance-flag-detail#set-maintenance-flag)
but this means hosts could potentially permanently be in this state
and there are concerns about corner-cases such as adoption when an
ephemeral Ironic is used and a rechedule occurs.

## References

