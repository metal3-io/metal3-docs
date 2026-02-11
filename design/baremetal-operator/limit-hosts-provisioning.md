<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# limit-hosts-provisioning

## Status

provisional

## Summary

This proposal aims to introduce a limit to the number of hosts that the
BareMetal Operator can provision or register simultaneously as a safety
measure to avoid overloading excessively the system

## Motivation

In the current implementation BMO takes care of handling the complete
provisioning cycle for a bare metal host without considering the pressure
level applied to the underlying Ironic services (DHCP included).
A user that desires to scale up several hundreds of nodes in a single step
could suffer issues produced from the sudden resources depletion

### Goals

1. Avoid any system instability due the excessive number of hosts being
   provisioned simultaneously

### Non-Goals

1. Optimize the deployment time of large batches of nodes
1. Allow the user to configure such behavior
1. Modify the current Ironic service layout

## Proposal

BMO reconciliation loop already checks for Ironic availability before
processing an update and the request gets rescheduled if Ironic is not ready.
After that, a new check will verify if Ironic is overloaded or not so that
the request could be rescheduled or processed as usual.

### Implementation Details/Notes/Constraints

The new check will verify the number of currently hosts being provisioned/
registered and, based on a configurable threshold (default set to 20), will
determine if the current update can be processed or needs to be rescheduled.
The difficult part consists in determining the number of hosts currently being
provisioned, since Ironic does not offer any way for querying about its
workload.
The basic idea is to identify those nodes that already passed DHCP/PXE -
considering it the most limiting factor for concurrent provisioning - by
selecting the nodes that are in a waiting state and have
_driver\_internal\_info_ field set by the agent.
Following a simplified pseudo-code:

```bash
provisioning_slots = GetEnv("MAX_CONCURRENT_PROVISIONING_HOSTS", 20)

for each Node
  if Node.provision_state in
    ("cleaning", "clean wait", "inspecting",
    "inspect wait", "deploying", "wait call-back", "rescuing",
    "rescue wait", "unrescuing", "deleting")
    &&
    Node.driver_internal_info.agent_url is present and not empty
  then
    provisioning_slots--

if provisioning_slots < 0 then
  reschedule current update

```

### Risks and Mitigations

- In a worst case scenario we could have a high number of "bad" hosts under
  provisioning but into an error state not recoverable. If such number is equal
  to the configured threshold, then the "bad" hosts could prevent other hosts
  to be correctly provisioned. A fair scheduling approach will be required
  to ensure that the available provisioning slots will be distributed evenly
  (the recently added _BMH ErrorCount_ field could be used for that)
- The operator concurrency level can be configured via the environment
  variable `BMO_CONCURRENCY` (default value set to 3). If the threads
  activity is not properly orchestrated, when this variable is set
  to a value greater than `MAX_CONCURRENT_PROVISIONING_HOSTS` then the operator
  could perform a number of requests to Ironic greater than the configured
  throttle limit - when a sufficient high number of hosts are provisioned
  simultaneously. A minimal approach could consist in at least tracing
  a log warning message when `BMO_CONCURRENCY` > `MAX_CONCURRENT_PROVISIONING_HOSTS`.

### Work Items

- Define a new configuration variable for the Ironic provisioner based on the
  environment variable `MAX_CONCURRENT_PROVISIONING_HOSTS`. Default value set
  to 20.
- Extend the Ironic provisioner `IsReady` method to include the check described in
  the Implementation Details section
- Add a warning log trace if `BMO_CONCURRENCY` > `MAX_CONCURRENT_PROVISIONING_HOSTS`,
  as described in the Risks and Mitigations section.
- Unit tests for the above work

### Dependencies

None

### Test Plan

- Unit test
- metal3-dev-env integration test
- Stress test with a number of simultaneous provisioning nodes greater than
  the configured threshold

### Upgrade / Downgrade Strategy

None

### Version Skew Strategy

None

## Drawbacks

None

## Alternatives

None

## References

- Ironic state diagram. <https://docs.openstack.org/ironic/latest/_images/states.svg>
- Ironic states. <https://docs.openstack.org/ironic/latest/contributor/api/ironic.common.states.html>
