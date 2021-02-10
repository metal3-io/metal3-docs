<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# BareMetalHost detailed activity

## Status

implementable

## Summary

This design proposes a new field to specify more precisely at which point in
a BMH lifecycle it is.

## Motivation

The primary motivation is to enable operators an easier insight into what
is going on with their nodes. This simplifies debugging and makes people feel
better about long-running processes. It may also be helpful for UI tools
to be able to display some sort of progress information.

### Goals

* Provide a way to know what action is being executed right now without
  accessing Ironic API.
* Provide a rough estimate of the progress of execution.

### Non-Goals

* Provide access to the Ironic Node `provision_state` field.
* Establish a direct one-to-one mapping between provision states and the
  new field values.
* Provide more granularity than what the Ironic API can report.
* The values of the new field will not be a part of the API contract and can
  change as a result of backend changes.
* Define a non-empty detailed activity for each possible situation.

## Proposal

### User Stories

#### Story 1

As an operator reasonably familiar with the provisioning process, I would like
to know what action is being executed on a BMH right now.

## Design Details

* The `ProvisionStatus` structure is extended with a new string field
  `CurrentActivity` and a new integer field `Progress`.
* The `Progress` value is a number from 0 to 100 that corresponds to estimated
  percentage of the work that has been done so far.
* The values of the fields are re-calculated based on the result described
  below on each reconciliation.

### Ironic steps basics

This section explains the basics of Ironic clean/deploy steps. Feel free to
skip it if you're familiar with Ironic.

Ironic has three major processes that are of interest for us:

* *Inspection* is a process of populating hardware information.
* *Cleaning* is a process of preparing a node for being usable for deployment.
* *Deployment* is a process of provisioning of a node.

All three processes usually (with a few exceptions that are skipped for
brevity) work by booting a ramdisk on the target node and executing actions
from within it. When *fast track* mode is on, the ramdisk is booted only once
and inspection, cleaning and deployment happen in a sequence.

Cleaning and deployment processes are split into potentially pluggable *clean*
or *deploy steps*. The said steps can be defined both inside Ironic itself or
inside the ramdisk. When a process is running, the current step is stored in
the Node's `clean_step` or `deploy_step` fields. All steps that are currently
scheduled for execution are cached in
`Node.driver_internal_info["clean_steps"]` or
`Node.driver_internal_info["deploy_steps"]`.

**Warning:** deploy (and in the future also automated clean) steps are
populated on demand. Before the ramdisk is actually booted, not all steps may
be in the cache.

### Implementation Details/Notes/Constraints

The new fields will be populated based on the following rules, where `Node` is
an Ironic Node object. The rules are defined in pseudo-code.

The calculations of the progress are based on the assumption that automated
cleaning is enabled. It starts with the value of 0 and is updated based on the
current detected activity.

* IF `Node.provision_state` in "cleaning", "clean wait":

  * IF `Node.clean_step` is null:

    Activity is `Preparing to configure host`.

  * IF `Node.clean_step["interface"]` == "raid":

    Activity is `Configuring RAID`.

  * IF `Node.clean_step["interface"]` == "bios":

    Activity is `Configuring firmware settings`.

  * IF `Node.clean_step["step"]` == "erase\_devices\_metadata":

    Activity is `Deleting disk metadata`.

  * Progress is determined by looking at the clean steps cache and determining
    which of the step is currently executed, assuming that cleaning takes 30%
    of the total time. For example, if one and only step is being executed,
    Progress is 15.

* IF `Node.provision_state` in "deploying", "deploy call-back":

  * IF `Node.deploy_step` is null OR `Node.deploy_step["step"]` is "deploy":

    Activity is `Preparing to write image`. Progress is 30.

  * IF `Node.deploy_step["step"]` is "write\_image":

    Activity is `Writing image`. Progress is 50.

  * IF `Node.deploy_step["step"]` is "prepare\_instance\_boot":

    Activity is `Configuring boot`. Progress is 75.

  * IF `Node.deploy_step["step"]` in "tear\_down\_agent",
    "switch\_to\_tenant\_network", "boot\_instance":

    Activity is `Rebooting into operating system`. Progress is 90.

* ELSE Activity is an empty string and Progress is not changed.

### Risks and Mitigations

Since we don't provide compatibility guarantees for the values of the new
field, consumers may be broken on changes to them.

### Work Items

* Update `ProvisionStatus` with the new fields, add constants.
* Update `ironicProvisioner` to set the new field each time we synchronize
  with Ironic.

### Dependencies

None

### Test Plan

Unit testing is probably sufficient. Integration testing may be complicated by
the fact that some states will pass too quickly for either BMO or the test
itself to notice.

### Upgrade / Downgrade Strategy

No upgrade impact. It's fine for the new field to be empty.

### Version Skew Strategy

None

## Drawbacks

None

## Alternatives

* Expose Ironic Node `provision_state`, `clean_step` and `deploy_step` fields.
  Would be more granular, but would expose implementation details.
* Do nothing, let people rely on logs and access Ironic directly for debugging.

## References

* [Ironic state
  machine](https://docs.openstack.org/ironic/latest/contributor/states.html)
* [Deploy
  steps](https://docs.openstack.org/ironic/latest/admin/node-deployment.html#agent-steps)
