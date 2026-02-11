<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# bmc-address

## Status

implemented

## Summary

This document explains the way users will provide the network location
of the bare metal management controller (BMC) on a host.

## Motivation

We need to document how we are going to specify the location of a BMC,
including how to tell its type, IP address, port number, and
potentially the path.

### Goals

1. To agree on an address specification system, including assumptions
   that can be made when parts of an address are left out.

### Non-Goals

1. To list the scheme to use for every type of controller.
1. To specify the user interface for entering address information.

## Proposal

### Implementation Details/Notes/Constraints

For each BMC, we need to know the type, IP, port, and optionally the
path to use to communicate with the controller.

We can collect all of this information using a single "address" field,
if we allow that field to contain partial or full URLs.

For each type of controller, we can often assume we know the protocol
used to communicate with it (HTTP, HTTPS, etc.). Therefore the scheme
in a URL provided by the user is redundant, and we can use that
portion of the URL to specify the controller type. For example:

    ipmi://192.168.111.1

In cases where we cannot assume the correct communication protocol, we
will need to combine the type and protocol. For example:

    redfish+https://IP/redfish/v1/Systems/42

Initially, we will only support IPMI controllers, so we do not need
users to specify the type or protocol.  If the field only contains a
network address, we can assume that the controller uses IPMI on the
standard port, 623. Therefore this would be equivalent to the previous
example:

    192.168.111.1

### Risks and Mitigations

One risk in this approach is that we would need to tell users how to
build the URLs, and this might be confusing.

## Design Details

### Work Items

- The `IP` field of the `BMCDetails` data structure needs to be
  renamed `Address`.
- A function to handle URL parsing and validation needs to be
  implemented, including understanding when the parsed URL needs to be
  interpreted has including default values.

### Dependencies

N/A

### Test Plan

We will have unit tests for the URL parsing logic.

### Upgrade / Downgrade Strategy

N/A

### Version Skew Strategy

N/A

## Alternatives

The primary alternative is to expand the data structure to have
separate fields for each value that would go into the URL. This
complicates the UI, even for the simplest cases, since we either have
to show all of the fields all of the time or include logic in the UI
to show specific fields based on the "type" selector.

## References

- [PR in baremetal-operator repo to change field name](https://github.com/metal3-io/baremetal-operator/pull/44)
