# Automated Cleaning

<!-- cSpell:ignore unsetting -->

Before reading this page, please see
[Baremetal Operator Automated Cleaning](../bmo/automated_cleaning.md) page.

If you are using only Metal3 Baremetal Operator, you can skip this page and
refer to Baremetal Operator automated cleaning
[page](../bmo/automated_cleaning.md) instead.

For deployments following Cluster-api-provider-metal3 (CAPM3) workflow,
automated cleaning can be (recommended) configured via CAPM3 custom resources
(CR).

There are two automated cleaning modes available which can be set via
`automatedCleaningMode` field of a Metal3MachineTemplate `spec` or
Metal3Machine `spec`.

- `metadata` to enable the cleaning
- `disabled` to disable the cleaning

When enabled (`metadata`), automated cleaning kicks off when a node is in the
first provisioning and on every deprovisioning. There is no default value for
`automatedCleaningMode` in Metal3MachineTemplate and Metal3Machine. If user
doesn't set any mode, the field in the `spec` will be omitted. Unsetting
`automatedCleaningMode` in the Metal3MachineTemplate will block the
synchronization of the cleaning mode between the Metal3MachineTemplate and
Metal3Machines. This enables the selective operations described below.

## Bulk operations

CAPM3 controller ensures to replicate automated cleaning mode to all
Metal3Machines from their referenced Metal3MachineTemplate. For example, one
controlplane and one worker Metal3Machines have `automatedCleaningMode` set to
`disabled`, because it is set to `disabled` in the template that they both are
referencing.

**Note**: CAPM3 controller replicates the cleaning mode from
Metal3MachineTemplate to Metal3Machine only if `automatedCleaningMode` is set
(not empty) on the Metal3MachineTemplate resource. In other words, it
synchronizes either `disabled` or `metadata` modes between Metal3MachineTemplate
and Metal3Machines.

## Selective operations

Normally automated cleaning mode is replicated from Metal3MachineTemplate `spec`
to its referenced Metal3Machines' `spec` and from Metal3Machines `spec` to
BareMetalHost `spec` (if CAPM3 is used). However, sometimes you might want to
have a different automated cleaning mode for one or more Metal3Machines than
the others even though they are referencing the same Metal3MachineTemplate. For
example, there is one worker and one controlplane Metal3Machine created from
the same Metal3MachineTemplate, and we would like the automated cleaning to be
enabled (`metadata`) for the worker while disabled (`disabled`) for the
controlplane.

Here are the steps to achieve that:

1. Unset `automatedCleaningMode` in the Metal3MachineTemplate. Then CAPM3
   controller unsets it for referenced Metal3Machines. Although it is unset in
   the Metal3Machine, BareMetalHosts will get their default automated cleaning
   mode `metadata`. As we mentioned earlier, CAPM3 controller replicates
   cleaning mode from Metal3MachineTemplate to Metal3Machine ONLY when it is
   either `metadata` or `disabled`. As such, to block synchronization between
   Metal3MachineTemplate and Metal3Machine, unsetting the cleaning mode in the
   Metal3MachineTemplate is enough.
1. Set `automatedCleaningMode` to `disabled` on the worker Metal3Machine `spec`
   and to `metadata` on the controlplane Metal3Machine `spec`. Since we don't
   have any mode set on the Metal3MachineTemplate, Metal3Machines can have
   different automated cleaning modes set even if they reference the same
   Metal3MachineTemplate. CAPM3 controller copies cleaning modes from
   Metal3Machines to their corresponding BareMetalHosts. As such, we end up
   with two nodes having different cleaning modes regardless of the fact that
   they reference the same Metal3MachineTemplate.

![alt](images/object-ref.svg)
