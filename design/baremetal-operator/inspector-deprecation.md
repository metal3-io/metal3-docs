<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Remove ironic-inspector in favor of ironic alone

## Status

implementable

## Summary

The Ironic project has decided to [deprecate
ironic-inspector][inspector-merge], merging most of its functionality into
the main Ironic service. This design covers how Metal3 will handle the
transition.

[inspector-merge]: https://specs.openstack.org/openstack/ironic-specs/specs/approved/merge-inspector.html

## Motivation

The [spec][inspector-merge] covers the reasons in detail, and many of the
arguments apply to Metal3 as well, for instance:

- Lower maintenance
- Less configuration code in [ironic-image][ironic-image]
- Removing the potential point of failure between the two services
- Probably most importantly, paving a way for easier active-active HA setup

To elaborate on the last point, while Ironic has been designed with high
availability and load splitting in mind, Inspector was single-process with
some HA capabilities added as an afterthought.

[ironic-image]: https://github.com/metal3-io/ironic-image/

### Goals

- No separate ironic-inspector container is started.
- All existing functionality is preserved.

### Non-Goals

- Upgrade process for clouds that don't use [ironic-image][ironic-image] falls
  under the upstream Ironic project responsibilities.

## Proposal

BMO will be updated to not assume the presence of ironic-inspector. The
[ironic-image][ironic-image] will be updated to configure Ironic for inspection
without ironic-inspector.

## Design Details

### Implementation Details/Notes/Constraints

BMO scope:

- Use the new [inventory API][inventory API] instead of accessing
  ironic-inspector. This API functions both with ironic-inspector and without
  it, delegating to ironic-inspector if necessary.

- Use only fields on the `Node` object to determine the inspection status
  and error message.

- Stop creating the ironic-inspector client and validating the service.

- Adjust the hardware data code to support both inspection data formats.
  They are different between ironic-inspector and the new inspection, but
  they still provide the same information.

[inventory API]: https://docs.openstack.org/api-ref/baremetal/#show-node-inventory

ironic-image scope:

- Enable the new inspection implementation, make sure the configuration
  stays largely the same. Some hooks are called differently, we may need
  to account for that.

- Stop configuring Ironic to talk to ironic-inspector.

- Drop the ironic-inspector scripts, including WSGI support.

### Risks and Mitigations

- Minor configuration differences may affect operators that have non-default
  configuration. We will need to document these.

- Operators not using ironic-image will need to use upstream migration
  procedures. They have to be in place by the time we pull the trigger.

- The new inspection work will be finished in the upcoming (as of writing this
  proposal) Ironic release 2024.1 "Caracal". To accommodate operators wishing
  to use stable releases, we will provide a particularly long-term support
  branch of BMO with ironic-inspector support. We also won't remove
  the ironic-inspector support from BMO immediately since we don't expect
  a lot of maintenance burden in this area.

  We will also create a branch of ironic-image with ironic-inspector support,
  but it will not be an LTS branch. We develop ironic-image as an opinionated
  way to deploy Ironic.

- There may be no procedure for migrating inspection data. This should not be
  a problem for Metal3 since the data is stored in Kubernetes and only updated
  on new inspections.

### Work Items

- Adjust BMO to remove a hard requirement on ironic-inspector.

- Introduce support for new inspection to [ironic-image][ironic-image]
  behind a flag. Make ironic-inspector optional.

- Make releases of BMO and ironic-image. Consider making the BMO branch
  supported as an LTS.

- After a graceful period, remove ironic-inspector support from ironic-image.

This is the point where we can leave it for some time. Operators following
stable releases will be able to keep using ironic-inspector because its support
in BMO won't be removed just yet. Operators using ironic-image will either stay
on the branch for some time or migrate to the new inspection right away.

The Ironic community expects to be able to deprecate ironic-inspector in the
2024.1 "Caracal" release. If that happens (and when that actually happens),
we will decide the point when we stop supporting ironic-inspector at all.

### Dependencies

- GopherCloud needs to be updated with new features. They will come into
  the future 2.0.0 major branch.

- Ironic needs to add all missing inspection hooks. We don't need to wait
  until other features (inspection rules API, PXE filters) are added since
  they are not relevant for us.

### Test Plan

Inspection is currently covered by integration tests and will be tested
further. It's unclear if we keep testing new BMO with ironic-inspector. We'll
probably only do it on a branch.

### Upgrade / Downgrade Strategy

Operators using [ironic-image][ironic-image] will need to change the way
Ironic is deployed and stop deploying ironic-inspector. They'll be able
to stay on a stable branch for some time to avoid rushing this change.

The rough upgrade plan will be:

1. Upgrade BMO to the version that supports both ironic-inspector and the new
   inspection.
1. Update ironic-image to the version that allows disabling ironic-inspector.
1. Change the Ironic deployment to enable the new inspection and disable
   ironic-inspector.
1. Further upgrades are possible at this point.

Operators not using ironic-image will need to decide on their strategy.
They will be able to use new BMO for the time being, but will be encouraged
to migrate since ironic-inspector support will receive less testing and
no new development.

There will be no impact on BareMetalHost or other resources.

### Version Skew Strategy

We will release a version of BMO that will be able to handle both
ironic-inspector and a deployment without ironic-inspector.

## Drawbacks

- This change requires explicit actions from the operators without necessarily
  bringing them immediate benefits.

## Alternatives

We cannot really not do this work: the Ironic community will stop maintaining
ironic-inspector eventually. Maintaining ironic-inspector ourselves is neither
feasible nor beneficial.

## References

- [Main proposal for Ironic][inspector-merge]
- [GopherCloud tracker](https://github.com/gophercloud/gophercloud/issues/2612)
