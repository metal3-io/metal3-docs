<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# ironic-debuggability-improvement

## Status

provisional

## Summary

Ironic and Ironic-inspector ramdisk logs are currently hidden inside their
respective containers and never shown to the end user by default.
This document describes proposed changes in Ironic and Ironic-inspector
logs handling to make debugging easier for the end user.

## Motivation

We need to make Ironic logs accessible to the end user.

### Goals

1. Make it easier to understand what happened when a deployment fails.
1. Avoid old logs pile up and take all available space.

### Non-Goals

1. Modify Ironic logging events or log level.

## Proposal

The ironic-inspector-image includes a new script,
ironic-inspection-log-watch.sh, that can act as an entry point for a container
to dump host inspection logs. These logs are emitted by the ironic-inspector
service.

The script should watch for Ironic host inspection log files to appear in
`/shared/log/ironic-inspector/ramdisk`, decompress them, print their
contents with each line prefixed by the base file name, and then remove the
file.

The ironic-image includes a new script, ironic-provisioning-log-watch.sh,
that can act as an entry point for a container to dump host provisioning logs.
These logs are emitted by the ironic-conductor service.

The script should watch for Ironic host provisioning log files to appear in
`/shared/log/ironic/deploy` decompress them, print their contents with each
line prefixed by the base file name, and then remove the file.

 The logs are written all at once, which is not necessary atomic,
 but pretty close to. Log file names start from node UUID in the current
 Ironic implementation. There is a pending change on Ironic side to
 add a node name into the log file name.

The baremetal-operator repository contains a kustomize-based deployment for
Metal3 services. That should be updated to include a container based on the
ironic-inspector-image using the ironic-inspection-log-watch entry point to
show the logs collected during inspection.That also should be updated to
include a container based on the ironic-image using the
ironic-provisioning-log-watch entry point to show the logs collected during
deployment.

## Design Details

ironic-provisioning-log-watch.sh will be created in
<https://github.com/metal3-io/ironic-image>
ironic-inspection-log-watch.sh will be created in
<https://github.com/metal3-io/ironic-inspector-image>
Both scripts will be added as new container entry points to
<https://github.com/metal3-io/baremetal-operator/blob/dabe5e14bafa00db6ccb37f1169c74ee3dac4425/ironic-deployment/base/ironic.yaml>

### Implementation Details/Notes/Constraints

Proposed implementation includes two stages:

1. Print log contents with UUID reference.
1. Print log contents with node name reference.

The second stage is dependent on these Ironic changes:
<https://storyboard.openstack.org/#!/story/2008280>
Add node name to ironic-inspector ramdisk log filename
<https://storyboard.openstack.org/#!/story/2008281>
Add node name to ironic-conductor ramdisk log filename

### Risks and Mitigations

None

### Work Items

None

### Dependencies

None

### Test Plan

- Unit test
- metal3-dev-env integration test

### Upgrade / Downgrade Strategy

None

### Version Skew Strategy

None

## Drawbacks

None

## Alternatives

None

## References

None
