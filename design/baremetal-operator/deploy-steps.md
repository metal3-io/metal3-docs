<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Customizable deployment procedure

<!-- cSpell:ignore configdrive,footgun -->

## Status

implemented

## Summary

This design proposes customizing the deployment procedure by providing a high
level abstraction around Ironic [deploy steps][deploy-steps], as well as
allowing per-host deployment (IPA) images.

[deploy-steps]: https://docs.openstack.org/ironic/latest/admin/node-deployment.html#deploy-steps

## Motivation

By default the Ironic agent downloads a provided image via HTTP(s), converts it
(if needed) and writes directly to the disk. This procedure works for many
distributions, but may not suit some cases well. A prominent example is CoreOS,
which has its own installer ([coreos-installer][coreos-installer]).

[coreos-installer]: https://github.com/coreos/coreos-installer

### Goals

- A way to replace the default deploy procedure with a custom action.

### Non-Goals

- Expose the full functionality of Ironic deploy steps.
- Add a way to execute custom actions during deployment.
- A way to provide a link to the Ironic agent image per host.

## Proposal

### User Story

As a CoreOS user I want to use `coreos-installer` to write the CoreOS image
without losing any functionality that Ironic offers (unlike the live ISO
workflow).

## Design Details

Additions to `BareMetalHost`:

- New structure field `CustomDeploy` with the only field `Method` to engage
  a non-default deployment procedure as described below.
- The `Image.URL` field will become optional if `CustomDeploy` is set
  since we don't know if the deploy method actually requires a separate image.

Setting `CustomDeploy` to a non-empty value will trigger deployment even if
`Image.URL` is empty. To be able to detect changes, the same `CustomDeploy`
field will be added to the host status.

### Implementation Details: CustomDeploy

When `CustomDeploy` is set, BMO will set the new [custom-agent deploy
interface][custom-agent] on the node so that the default deploy steps do not
apply. Then we request a deploy step with the name provided in the
`CustomDeploy.Method` field. This step has to be provided in the agent image
and is responsible for the whole deployment process.

The `Image.URL` will no longer be required since some images (such as CoreOS)
already include the root filesystem.

NOTE: `CustomDeploy` is a single-field structure to allow potential extensions
in the future. The `UserData` and `NetworkData` will be available to a deploy
step implementation as part of the Node's `instance_info["configdrive"]`.
Any required customization is expected to be provided via `UserData` and
`NetworkData` or be built into the image itself.

The expected workflow is as follows:

1. A user sets `CustomDeploy.Method = "step_name"` and optionally `Image.URL`,
   `UserData` and `NetworkData`.
1. BMO sets `Node.DeployInterface = "custom-agent"` and requests deployment
   with a custom deploy step `step_name`.
1. Ironic boots the agent (if not booted for inspection/cleaning already).
1. Ironic requests the agent to execute the deploy step `step_name` (it is
   an error to provide a non-existing step), providing it the complete Node
   object, including `configdrive`.
1. Ironic waits for the step to finish.
1. Ironic configures the Node's boot device and clean ups the deployment
   environment.
1. Ironic reboots the node into the instance.

On failure (including unsupported deploy step) the node will be moved to the
`deploy failed` state, and the `LastError` field will be populated.

NOTE: There is currently no way to validate the provided deploy step before
the deployment starts.

[custom-agent]: https://review.opendev.org/c/openstack/ironic/+/786033

### Risks and Mitigations

The new functionality will be easy to misuse, especially if you're not familiar
with Ironic. We will need to write the documentation accordingly.

### Work Items

- Add support for accepting a custom deploy step on `BareMetalHost`.
- Implement [custom-agent][custom-agent] in Ironic.

### Dependencies

- [custom-agent deploy interface in Ironic][custom-agent]

Soft dependencies:

- Fix boot interface validation in Ironic that makes `image_source` always
  required, even if the deploy interface does not use it
  ([bug 2008874](https://storyboard.openstack.org/#!/story/2008874)).
- Delay configdrive rendering in Ironic, so that the deploy step can access
  the original JSON data, not just the final ISO image
  ([bug 2008875](https://storyboard.openstack.org/#!/story/2008875)).

### Test Plan

We could potentially add CI jobs with Fedora CoreOS and test that it boots
successfully. However, this requires deploy ISO support, which is outside of
the scope of this proposal.

### Upgrade / Downgrade Strategy

N/A

### Version Skew Strategy

N/A

## Drawbacks

- A potential footgun.

## Alternatives

- [Explicit CoreOS support](https://github.com/metal3-io/metal3-docs/pull/177)
- Expose deploy steps more fully. Would allow greater customization at the
  expense of a more complex API.
- Do nothing, keep using live ISO.

## References
