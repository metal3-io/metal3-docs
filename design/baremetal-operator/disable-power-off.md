<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

<!-- cSpell:ignore fakefish -->

# Support hardware that cannot be powered off

## Status

One of: implementable

## Summary

This design document proposes a new BareMetalHost API field that makes sure
that the underlying hardware is never powered off.

## Motivation

Power off is a fundamental operation that is used in many places in Ironic and
is exposed in the BareMetalHost API via the `online` field. However, there are
cases where the hardware must never end up in the powered off state except for
a brief moment during reboots. The motivating case here is the [NC-SI][ncsi]
technology, which allows the BMC to share one of the "normal" physical network
interfaces rather than having a separate one just for it. In at least some
implementations of this technology, network access to the BMC is not possible
when the hardware is powered off.

See [the Ironic specification][ironic-ncsi-spec] for a more detailed breakdown
of the use cases and an explanation of challenges related to powering off and
rebooting machines in Ironic.

[ncsi]: https://en.wikipedia.org/wiki/NC-SI
[ironic-ncsi-spec]: https://specs.openstack.org/openstack/ironic-specs/specs/approved/nc-si.html

### Goals

- A user can configure a BareMetalHost so that implicit power off actions never
  happen and explicit actions are rejected.

### Non-Goals

- Changing the default behavior.

## Proposal

## Design Details

Add a new field `DisablePowerOff` (boolean, default `false`) to the
BareMetalHost `spec` object. This field will directly correspond to the
Ironic's `disable_power_off` Node field.

### Implementation Details/Notes/Constraints

Setting the `online` field to `false` will not be possible if
`disable_power_off` is `true`. The webhook will reject such a change, the
controller code will ignore the `online` field in this case (e.g. if the
webhook is disabled).

Rebooting via the reboot annotation will be implemented via the Ironic reboot
API instead of a power off followed by power on. We'll mark the action as
successful once the Ironic call has been issued.

The `PoweringOffBeforeDelete` state will be skipped for hosts with
`DisablePowerOff` set to `true`.

Check the [Ironic specification][ironic-ncsi-spec] for more implementation
details.

### Risks and Mitigations

The code paths without power off will be less tested than the normal path and
may not behave correctly in the presence of BMC bugs (e.g. we won't be able to
detect that a reboot had no effect). We will mark this feature as advanced and
recommend that operators don't use unless they understand all implications.

### Work Items

- Add a new field to the API.
- Update the webhook.

### Dependencies

This proposal depends on the [Ironic feature][ironic-ncsi-spec] tracked in
[bug 2077432](https://bugs.launchpad.net/ironic/+bug/2077432).

### Test Plan

While we're planning on sushy-tools support for this feature, it won't be
trivial to test it as part of the normal end-to-end tests, so we'll rely on
unit tests and manual testing.

### Upgrade / Downgrade Strategy

None

### Version Skew Strategy

If the version of Ironic is not enough to set the `disable_power_off` field,
the host will fail reconciling, and the error message will be set in the status
until Ironic is upgraded or the `DisablePowerOff` field is unset.

## Drawbacks

This is a rather exotic feature for a very specific hardware setup.
Unfortunately, this setup seems to be gaining popularity in the *edge* world,
so we cannot simply ignore it.

## Alternatives

Users who currently need this feature with Metal3 are using
[fakefish](https://github.com/openshift-metal3/fakefish) to prevent power off
actions from working. This approach is very fragile and makes certain Ironic
features broken. We cannot recommend it to the general user base.

## References

[Ironic specification: Hardware that cannot be powered off][ironic-ncsi-spec]
