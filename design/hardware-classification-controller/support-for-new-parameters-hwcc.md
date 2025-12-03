# add support for extra hardware parameters in HWCC

## Status

Implementable

## Summary

Implement support for more parameters in HWCC which will help to
classify a baremetal host on more possible configurations.

## Motivation

We have hardware classification controller which validates and
classifies the hosts based on user hardware requirements.
We would like to add more parameters which helps user to
identify the ideal host. This feature helps user to avoid runtime failures
and also increases the performance for workload deployments.

### Goals

To make classification more useful by incorporating additional parameters
to get the matching host. It will help user to specify more rules by
introducing new parameters.

We will carry out testing of HWCC on Dell hardware.

## Proposal

We are submitting proposal based on the issue raised in HWCC:
[Issue 56](https://github.com/metal3-io/hardware-classification-controller/issues/56)

* CPU architecture will be useful if the user wants to have 32-bit
  or 64-bit processor as per their requirements.

* New parameters such as Firmware and SystemVendor will add
  advantage to identify matched hosts.
  System Vendor will be useful to add as a new parameter if the
  user is looking for particular vendor and their hardware for his
  application to support or deploy on.
  Firmware will be useful to add as a new parameter if user is looking
  for specific features in particular releases or versions.

### Investigation Details

Add support for new parameters:

1. `hardwareCharacteristics.cpu.arch`

   The new `arch` field will be compared against the host
   `status.hardwareDetails.cpu.arch` field for an exact string match.

   User can provide `arch` type based on requirement.

   Investigation Details: Below is sample introspection data for CPU.
   Types of architecture are 32-bit (x86) and 64-bit
   (x86-64, IA64, and AMD64).

   ```yaml
   hardware:
       cpu:
          arch: "x86_64"
   ```

1. `hardwareCharacteristics.firmware.bios`

   Firmware is new parameter to be introduced in HardwareClassification
   which contains BIOS information. User can specify BIOS requirements
   by providing `hardwareCharacteristics.firmware.bios.vendor` and
   `hardwareCharacteristics.firmware.bios.version`.

   The classification of `vendor` will be done using exact string
   match of the value provided by user in profile.

   The classification of `version` will be done by checking if host
   `version` is greater than equal to `minorVersion` and less than
   equal to `majorVersion`. `minorVersion` and `majorVersion` are
   provided by user in profile.

   Investigation details: Below is sample introspection data for firmware.
   `BIOS` field under firmware have two fields, `vendor` and `version`.

    ```yaml
    hardware:
        firmware:
             bios:
               date: "10/17/2018"
               vendor: "Dell Inc."
               version: "1.5.6"
    ```

1. `hardwareCharacteristics.systemVendor`

   SystemVendor is new parameter to be introduced which helps user to
   classify hosts of certain manufacturer and product. User can
   provide `hardwareCharacteristics.systemVendor.manufacturer` and
   `hardwareCharacteristics.systemVendor.productName` in yaml.

   The classification of `manufacturer` will be done using exact
   string match of the values provided by user in profile.

   `productName` from hardware details comes with SKU code and
   in YAML user will provide only name of product.
   The classification of `productName` will be done using sub
   string match of the values provided by user in profile.

   Investigation details: Below is sample introspection data for
   systemVendor. `systemVendor` field contains `manufacturer` and
   `productName`.

    ```yaml
    hardware:
        systemVendor:
          manufacturer: Dell Inc.
          productName: PowerEdge R640 (SKU=NotProvided;ModelName=PowerEdge R640)
    ```

### Implementation Details/Notes/Constraints

Link for Existing HWCC Specs
[Existing YAML](https://github.com/metal3-io/hardware-classification-controller/blob/main/config/samples/metal3.io_v1alpha1_hardwareclassification.yaml)

* Below is sample yaml for additional parameters in HardwareClassification.
  Units will be updated in User guide document of HWC.

   ```yaml

   apiVersion: metal3.io.sigs.k8s.io/v1alpha1
   kind: HardwareClassification
   metadata:
     name: profile1
   spec:
     hardwareCharacteristics:
       CPU:
          arch: x86_64
          minimumCount: 4
          minimumSpeedMHz: 4300
       Firmware:
          Bios:
            vendor: Dell Inc.
            minorVersion: 1.2.3
            majorVersion: 3.4.5
       SystemVendor:
           manufacturer: Dell Inc.
           productName: PowerEdge R640
   ```

* Update the existing Schema `HardwareClassification` by adding new
  parameters "arch" under CPU.

* Add validation and classification for "arch", "firmware"
  and "systemVendor" parameters.

* Once the classification is completed, will add label if user has
  provided any, otherwise it will be added as
  `hardwareclassification.metal3.io/<profile-name>: matches`.

### Risks and Mitigations

None.

## Design Details

No change required.

### Work Items

1. Add new parameters "arch" under CPU in file
   /api/v1alpha1/hardwareClassification_types.go.
1. Add new schema under hardware-classification for "firmware" and
   "systemVendor" in file /api/v1alpha1/hardwareClassification_types.go.
1. Update existing validation logic for new parameters introduced in CPU.
1. Implement validation logic for "firmware" and "systemVendor".
1. Extend existing comparison framework to support new parameters introduced
   in CPU.
1. Add classification logic for "firmware" and "systemVendor".
1. Write unit tests for above implementation.

### Dependencies

Baremetal-Operator - To fetch BareMetal-host for classification.

### Test Plan

* Additional Unit tests for modified modules will be implemented.
* Functional testing will be performed with respect to implemented
  HardwareClassification CRD and controller.
* Deployment & integration testing will be done.

## References

* <https://github.com/metal3-io>
* <https://github.com/metal3-io/hardware-classification-controller>
