<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# unmanaged-state

## Status

implemented

## Summary

This design proposes adding a new state to the state machine to be
applied to hosts that are known but cannot be managed because the BMC
credentials are not.

## Motivation

As a precursor to being able to provision hosts without their BMC
credentials, we want to be able to define hosts without BMC
credentials so that the credentials can be added at a later
time. Consumers of the hosts, including the
`cluster-api-provider-metal3`, need to be able to recognize such hosts
and treat them differently.

### Goals

1. Define a new `Unmanaged` state and the changes in each component to
   support it.

### Non-Goals

1. Discuss the full host discovery design.

## Proposal

We had previously discussed a `Discovered` state but never implemented
it, choosing to use the `OperationalStatus` value of `Discovered`
instead. This proposal adds a new state, but uses `Unmanaged` instead
of `Discovered`.

A host will only enter the `Unmanaged` state after being created
without any BMC details. If the host has partial details, it will move
to `Registering` and try to register until it fails. If the host has
all BMC details when it is created and the details are removed, it
will enter an error state.

### User Stories

#### Story 1

As a user, I want to define host resources without providing the BMC
credentials on day 1 so I can work with externally provisioned hosts
without having to give metal3 extra details.

#### Story 2

As a user, I want to add BMC credentials to an existing host resource
to allow power management features to be enabled after the cluster is
running.

## Design Details

### Implementation Details/Notes/Constraints

The `baremetal-operator` state machine code should be updated to
support the new steady state of `Unmanaged` and the controller should
no longer report an error when there are no BMC details.

Besides the changes in the `baremetal-operator`, we need to consider
consumers of the API. The `cluster-api-provider-metal3` controller
looks at host state in two places: during provisioning and when
deleting the host.

The provisioning code already ignores hosts that are not `Ready` or
`Available`. The new state will keep hosts from entering either of
those states, so no changes are needed to that section of the provider
code.

The delete code for a machine waits for a host to be deprovisioned
before the machine is deleted. This code will have to be updated to
also look for the new `Unmanaged` state. We can safely update the
`baremetal-operator` first because no hosts will be in the `Unmanaged`
state in any existing clusters and no new `Unmanaged` hosts should be
associated with a `Machine` through an automated process like
provisioning.

### Risks and Mitigations

See the discussion of `cluster-api-provider-metal3` in the previous
section.

### Work Items

1. Define the new state:
   <https://github.com/metal3-io/baremetal-operator/pull/571>
1. Update `cluster-api-provider-metal3` delete code
1. Update `baremetal-operator` to implement the new state:
   <https://github.com/metal3-io/baremetal-operator/pull/569/>

### Upgrade / Downgrade Strategy

Upgrades should work with either the `baremetal-operator` or
`cluster-api-provider-metal3` being updated first because no hosts
will use the new state.

Downgrades will be a problem if there is a host in the `Unmanaged`
state attached to a `Machine` at the time of the downgrade.

### Version Skew Strategy

No guarantees

## Drawbacks

Why should this design _not_ be implemented.

## Alternatives

Another approach we could take is to allow hosts to be in the
externally provisioned state without any BMC credentials. We wouldn't
need any new states for that, but we would rearrange the existing
states and hosts would continue resting in the `Error` state if they
weren't externally provisioned and didn't have credentials.

If we did that, we would have to add a status field to reflect whether
the host could be managed or not, based on whether the BMC credentials
are present and valid.

It is not clear that approach gives us a better user experience, over
adding the new steady state early. And it would complicate the rest of
the controller code, because we would have to check any time we wanted
to do something that required power control to see if we could.

## References

- Update `baremetal-operator`:
  <https://github.com/metal3-io/baremetal-operator/pull/569/>
