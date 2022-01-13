# Support external introspection

## Status

implemented

## Summary

A declarative API is proposed to disable inspection of a BareMetalHost
and optionally allow external sources of inspection data to update the
hardware status data.

## Motivation

Related to the work to enable booting of a
[LiveImage](https://github.com/metal3-io/metal3-docs/pull/150),
there is the requirement to optionally disable inspection on initial
registration of a BareMetalHost (so that the live image can boot
more quickly, ref user stories below).

### Goals

- A declarative API to disable inspection on BMH registration
- Provide an interface to update hardware status data at an arbitrary time
  after BMH creation.

### Non-Goals

- There are no plans for any mechanism to trigger or consume data from any out
  of band inspection process, other than providing hardware data via an annotation.

## Proposal

### Disable inspection proposal

To align with the [inspection API proposal](https://github.com/metal3-io/metal3-docs/blob/main/design/baremetal-operator/inspection-api.md),
the `inspect.metal3.io` annotation will be reused, with the addition of a value.

The optional `inspect.metal3.io: disabled` annotation will be used to describe
the situation where we wish to disable the default inspection behavior.

When the BMO finds this annotation, it will skip performing inspection
during the
[Inspecting state](https://github.com/metal3-io/baremetal-operator/blob/main/docs/BaremetalHost_ProvisioningState.png)

### Hardware status update proposal

In the current implementation, when `baremetalhost.metal3.io/status` is
provided, it can set any status field, and thus is only evaluated on the
very first reconcile (primarily to support externally provisioned hosts,
where we collect the inspection data prior to creating the BMH resources).

In the case where metal3 is booting a live-image that contains code that
can collect hardware details, it's desirable to have a way to update the
hardware status after the image is booted.

To enable this safely, we can add a new `inspect.metal3.io/hardwaredetails`
annotation, which will allow updating the status/hardware field:

- At any time when inspect.metal3.io=disabled
- When there is no existing HardwareDetails data in the Status

In the latter case, it may be a potentially safer/more constrained interface
than the current `baremetalhost.metal3.io/status` API.

Given that the primary use-case for this is live-boot images (where no disk
image is written to disk), and that profile matching is no longer the preferred
interface for specifying root-disk hints, if `inspect.metal3.io/hardwaredetails`
is updated and the BMH is in the `Ready` state, we will not attempt to match
profiles based on this data.

In the event that both `baremetalhost.metal3.io/status` and
`inspect.metal3.io/hardwaredetails` are specified on BMH creation,
`inspect.metal3.io/hardwaredetails` will take precedence and overwrite any
hardware data specified via `baremetalhost.metal3.io/status`.

### User stories

#### Fast-boot appliance live-image

Where the LiveImage booted is an appliance that must be running as quickly as
possible, it may be desirable to skip the time taken for inspection
(and also cleaning which is discussed in an [existing proposal](https://github.com/metal3-io/metal3-docs/pull/151)

#### Live-image installer does inspection

[Installer ISO images](https://docs.fedoraproject.org/en-US/fedora-coreos/bare-metal/#_installing_from_live_iso)
may be booted which can include their own inspection tooling.

In this case, it is desirable to avoid the extra reboot and have the live-iso
collect the required data (and update the BMH via the status annotation).

## Alternatives

The main alternative is to provide a status annotation at the point of
creating the BMH, which might be enough for the fast-boot appliance use-case,
but isn't ideal for the case where there is data collected by the live-iso
which can be used to subsequently update the hardware status.

We could also enable evaluation of the existing annotation at any arbitrary time
but this is potentially unsafe, given that the BMO stores data in some other
status fields.

## References

- Inspection API [proposal](https://github.com/metal3-io/metal3-docs/blob/main/design/baremetal-operator/inspection-api.md)
- Live Image [proposal](https://github.com/metal3-io/metal3-docs/pull/150)
- Live Image [implementation](https://github.com/metal3-io/baremetal-operator/pull/754)
