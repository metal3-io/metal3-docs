<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# resetting BMC through Ironic prior to BMH deployment

This document proposes running driver-specific out-of-band clean
steps.

## Status

implementable

## Summary

Depending on the selected driver, BMO will run zero or more out-of-band clean
steps to ensure the node and the BMC are in the right state. Out-of-band clean
steps are executed via BMC (e.g. using Redfish protocol) without booting the
ironic agent (IPA).

The first drivers to receive such handling will be `idrac` and
`idrac-virtualmedia`. For them we will run the `management.known_good_state`
clean step that resets iDRAC and clears its job queue.

It is important that these actions run before we try to boot anything on the
target node, be it the inspection ramdisk or a 3rd party installer ISO.

## Motivation

iDRAC will refuse to create a job if there is already a pending job of the same
type. To make sure we start in a coherent state, we will reset iDRAC before
doing anything else to it.

### Goals

* Provide a mechanism to run out-of-band clean steps before inspection.
* Run `known_good_state` clean step for iDRAC.

### Non-Goals

* Run any in-band (i.e. using a ramdisk) clean steps.
* Allow a user to provide the steps to run.

## Proposal

## Design Details

All clean steps run asynchronously in the ironic API, even out-of-band steps
that are reasonable fast (an order of seconds). When entering the `Registering`
state, we will check if the driver supplies any reset clean steps. If yes, we
will start manual cleaning and wait. Otherwise we'll move on.

### Implementation Details/Notes/Constraints

The `AccessDetails` interface will be extended with a new call:

```go
ResetSteps() []CleanStep
```

where `CleanStep` is a copy of the corresponding type from gophercloud:

```go
type CleanStep struct {
    Interface string                 `json:"interface" required:"true"`
    Step      string                 `json:"step" required:"true"`
    Args      map[string]interface{} `json:"args,omitempty"`
}
```

The new `NeedsReset` call will return `true` if `ResetSteps()` is not empty and
the host is not externally provisioned.

### Rejected Ideas

We could use `nodes.CleanStep`, but it would require `pkg/bmc` to depened on
gophercloud. In turn, downstream users of `pkg/bmc` would have to depend on
exactly the same version as we, which was deemed undesirable.

We could move the logic of determining the right clean steps for a node
completely to `pkg/provisioner/ironic`. That would require introducing
driver-specific logic, which currently lives only in `pkg/bmc`.

### Risks and Mitigations

None?

### Work Items

* Extend the BMC interface with `ResetSteps`, implement `NeedsReset`
* Add the iDRAC implementation

### Dependencies

* Ironic needs an ability to skip booting the ramdisk:
  [RFE 2008491](https://storyboard.openstack.org/#!/story/2008491).

* iDRAC resetting clean steps:
  [RFE 2007617](https://storyboard.openstack.org/#!/story/2007617).

### Test Plan

Unfortunately, this change can only be tested on real hardware.

### Upgrade / Downgrade Strategy

None?

### Version Skew Strategy

None?

## Drawbacks

A new action will make the deployment slightly longer and is a new potential
point of failure.

## Alternatives

Document that the operators must reset iDRAC manually.

## References

