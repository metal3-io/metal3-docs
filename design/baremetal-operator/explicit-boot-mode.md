<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# explicit-boot-mode

## Status

implemented

## Summary

This design adds a field for the user to set the boot mode for a host
explicitly.

## Motivation

As was pointed out late in the [implicit-boot-mode
review](https://github.com/metal3-io/metal3-docs/pull/78), we cannot
always assume that old BMC protocols and old boot modes are
automatically combined. We still want to provide a reasonable default
behavior that encourages and assumes UEFI, but does not prevent the
use of legacy boot mode.

### Goals

- Describe an API change to allow the user to override the default
  boot mode of `UEFI`.

### Non-Goals

- Change the implicit boot mode selection design.

## Proposal

Add a new optional API input field, `spec.bootMode`, with possible
values `UEFI` or `legacy`. If no value is provided, the value from the
default `UEFI` will be used.

### User Stories

#### Story 1

As a user, I want to override the boot mode selected by metal3 because
I have hardware that does not match the assumptions made by the
implicit boot mode selection.

## Design Details

Add a new optional string field `BootMode` to `BareMetalHostSpec`,
with allowed values `"UEFI"` or `"legacy"`.

Update <https://github.com/metal3-io/baremetal-operator/pull/469/> so
that when `Spec.BootMode` has a valid value it overrides the default.

### Implementation Details/Notes/Constraints

The existing PR #469 needs to be rebased, and the work for this design
can be folded into that.

*Implementation moved to
<https://github.com/metal3-io/baremetal-operator/pull/602>.*

### Risks and Mitigations

Adding a new field provides a way for the user to specify the wrong
value. However, the boot mode is not something we can always assume we
can figure out. Making the field optional and trying to select the
right value automatically should at least give users a chance of not
having to know what to do but also allow them to correct our guess if
it is wrong.

### Work Items

- Rebase #469
- Extend it with the new field
- Ensure we are saving the boot mode as part of the other provisioning
  settings in the host controller

### Dependencies

N/A

### Test Plan

Manual testing, for now.

### Upgrade / Downgrade Strategy

The new field is optional so it is forward compatible.

Older versions of the software did not set a boot mode at all so
losing the setting during a downgrade may result in an unavoidable
change of behavior. That is mitigated by the fact that most old
systems were using DHCP, which is configured to deliver the right
information to the host based on the client request.

### Version Skew Strategy

N/A

## Drawbacks

We originally wanted to avoid exposing this field as it is one more
thing the user has to understand to use the API.

## Alternatives

Sticking with only the implicit boot mode implementation would leave
some users unable to use metal3.

## References

- PR #469 has the implicit boot mode implementation
- [implicit-boot-mode](implicit-boot-mode.md) has the original design
- PR #602 has the implementation for this design
