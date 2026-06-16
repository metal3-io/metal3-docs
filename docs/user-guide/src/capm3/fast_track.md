# Fast Track Mode

## Overview

Fast Track mode is an optimization feature in CAPM3 that keeps BareMetalHosts
powered on during machine deletion when certain conditions are met. This can
significantly speed up cluster upgrades and node replacements by avoiding an
extra power cycle before the host is re-used.

CAPM3 Fast Track is different from Ironic Fast Track. Ironic Fast Track reuses
an already-running agent ramdisk across Ironic inspection, cleaning, and
deployment. CAPM3 Fast Track controls whether CAPM3 leaves the BareMetalHost
`Online` during Metal3Machine deletion. These features are commonly used
together in Metal3, but enabling one does not enable the other.

## How It Works

When a Metal3Machine is deleted, CAPM3 normally lets the BareMetalHost power off
as part of deprovisioning. With Fast Track enabled, CAPM3 can keep the host
powered on when automated cleaning is set to any value other than `disabled`.

When automated cleaning is enabled, the physical machine boots into the Ironic
Python Agent to run cleaning. CAPM3 Fast Track keeps the machine running with
the agent after cleaning completes, which saves one reboot when the host is
re-provisioned.

The behavior is controlled by three factors:

1. **BareMetalHost.Spec.DisablePowerOff**: If `true`, the host always stays
   online (highest priority)
1. **CAPM3_FAST_TRACK environment variable**: Set to `true` or `false`
1. **BareMetalHost.Spec.AutomatedCleaningMode**: Set to `disabled` or a
   cleaning-enabled mode such as `metadata`

### Behavior Matrix

| DisablePowerOff | CAPM3_FAST_TRACK | AutomatedCleaningMode         | BMH Online Status        |
| --------------- | ---------------- | ----------------------------- | ------------------------ |
| true            | any              | any                           | **On** (DisablePowerOff) |
| false           | false            | disabled                      | Off                      |
| false           | true             | disabled                      | Off                      |
| false           | false            | not disabled (metadata today) | Off                      |
| false           | true             | not disabled (metadata today) | **On** (Fast Track)      |

Starting with CAPM3 v1.13.0, `DisablePowerOff=true` can be combined with
`AutomatedCleaningMode=metadata`. In that case, `DisablePowerOff` still takes
priority and keeps the host online.

The host remains online when:

- `DisablePowerOff` is `true` (takes priority over all other settings), or
- `AutomatedCleaningMode` is not `disabled` AND
  `CAPM3_FAST_TRACK` is set to `true`

When both conditions are met, the BareMetalHost remains powered on after the
Metal3Machine is deleted, allowing it to be quickly re-claimed by a new
Metal3Machine without waiting for a full power cycle.

## When to Use Fast Track

Fast Track is beneficial in use cases where BareMetalHosts are expected to be
re-used eventually and power consumption is not a factor, for example:

- **Rolling upgrades**: Nodes are being replaced one at a time, and speed is
  important
- **Development/testing**: Quick iteration cycles where full deprovisioning
  adds unnecessary delay
- **Predictable host reuse**: Reusing the same physical hosts is part of the
  normal operating model

Fast Track is less useful, or should be disabled, when:

- **Hosts should remain powered off**: Power consumption, cooling, or rack
  operations require unused machines to be off
- **Physical maintenance is planned**: Hardware replacement or other service
  work requires the machine to be powered off
- **Automated cleaning is disabled intentionally**:
  `AutomatedCleaningMode=disabled` makes CAPM3 power off the host

## Configuration

### Enabling Fast Track

Fast Track is configured via the `CAPM3_FAST_TRACK` environment variable on the
CAPM3 controller. It defaults to `false`.

#### Via clusterctl

Add to your clusterctl configuration file:

```yaml
variables:
  CAPM3_FAST_TRACK: "true"
```

#### Via Environment Variable

If deploying the controller directly, set the environment variable:

```bash
export CAPM3_FAST_TRACK=true
```

### Configuring AutomatedCleaningMode

For Fast Track to work, automated cleaning must not be disabled. Today the
documented CAPM3 cleaning-enabled value is `metadata`, and CAPM3's deletion
logic treats any value other than `disabled` as eligible for Fast Track.

In CAPM3 workflows, configure automated cleaning through the
Metal3MachineTemplate or Metal3Machine fields described in the
[CAPM3 automated cleaning documentation](./automated_cleaning.md), and let CAPM3
replicate the setting to the BareMetalHost. This can also be combined with
`DisablePowerOff=true`; in that case `DisablePowerOff` remains the deciding
factor for keeping the host online.

## Behavior During Machine Deletion

When a Metal3Machine is being deleted:

1. CAPM3 clears the BareMetalHost's image, customDeploy, userData, metaData,
   and networkData references
1. Based on the DisablePowerOff, AutomatedCleaningMode, and CAPM3_FAST_TRACK
   values, CAPM3 sets the BMH's `Online` field:
   - **Fast Track active**: The host stays online (`Online: true`) while
     deprovisioning and cleaning complete
   - **Fast Track inactive**: The host is powered off (`Online: false`) as part
     of deprovisioning
1. CAPM3 waits for the host to reach an available state before fully releasing
   it
1. The ConsumerRef and other association data are cleared

Fast Track does not skip BMO or Ironic deprovisioning. It avoids the extra
power-off and power-on cycle when a cleaned host will be re-used.

## Monitoring

When Fast Track is active, CAPM3 produces log messages like:

```text
Set host Online field based on DisablePowerOff, AutomatedCleaningMode, and Capm3FastTrack host=node-0 automatedCleaningMode=metadata hostSpecOnline=true
```

When Fast Track keeps a host online, the BareMetalHost still deprovisions and
runs cleaning. The difference is that the host remains `Online`, so the next
Metal3Machine can claim it without waiting for another power-on boot.

## Troubleshooting

### Host Not Staying Online

If hosts are being powered off despite Fast Track being enabled:

1. Verify `CAPM3_FAST_TRACK` is set to `true` (not `True` or `1`)
1. Check that `AutomatedCleaningMode` is not `disabled` (`metadata` in current
   CAPM3 documentation)
1. Review controller logs for the decision logic

### Host Stuck in Deprovisioning

If a host appears stuck, it may be waiting for cleaning to complete. Check:

1. The Ironic conductor logs for cleaning status
1. The BareMetalHost status for any error messages
1. Whether the host's BMC is accessible

## Related Documentation

- [Automated Cleaning](./automated_cleaning.md) - Details on automated cleaning
  modes
- [Baremetal Operator Automated Cleaning](../bmo/automated_cleaning.md) - BMH
  lifecycle and cleaning modes
