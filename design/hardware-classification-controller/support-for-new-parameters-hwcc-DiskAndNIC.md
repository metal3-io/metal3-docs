# add support for extra hardware parameters in Disk and NIC

## Status

Implementable

## Summary

Implement support for more parameters in HWCC which will help to
classify a baremetal host on more possible configurations.

## Motivation

The current HWCC allows user to identify the ideal host by
specifying minimal parameters.
We would like to add Disk and NIC parameters which helps user to
identify the ideal host. This feature helps user to avoid runtime failures
and also increases the performance for workload deployments.

### Goals

To make classification more useful by incorporating additional parameters
to get the matching host.
Introduce `diskSelector` under Disk which provide the `hctl` pattern and
`rotational` to filter the disk as per user requirement.
Introduce `vendorSelector` under NIC which provide `vendor` list to
filter the NIC type as per user requirement.

### Non-Goals

This proposal is for Disk's additional parameter `diskSelector` and NIC's
additional parameter `nicSelector` not for any other parameters.

## Proposal

We are submitting proposal based on the issue raised in HWCC:
[Issue 53](https://github.com/metal3-io/hardware-classification-controller/issues/53)

* In Disk, supported parameters are only size and count,
  in addition to these user can identify types of Disk (for eg:
  HDDs, SSDs, RAID or NVMes).

* If user is interested in particular NIC vendor, then NIC vendor
  can be added as parameter.

### Investigation Details

Add support for new parameters:

1. `hardwareCharacteristics.disk.diskSelector`

   Under `diskSelector`, new parameters `hctl` and `rotational` will be
   added. `diskSelector` will be declared as an array.

   Note: Example patterns combination of `hctl` and `rotational` for all
   disk type (SSD/HDD/NVMe/RAID) will be documented in the
   hardware-classification-controller repository under docs.

   For selection of NVMe disk, user can provide `rotational` parameter
   as false and `hctl` parameter should be blank.

   For example: For HDD disk, user can provide `hctl` value as "0:0:N:0"
   and `rotational` flag as "True".

   YAML rules for single Disk:

   User can provide `minimumCount` as 1 and `minimumIndividualSizeGB`
   according to requirement. Then specify the disk type using combination
   of `hctl` and `rotational` parameters using Rule Book.
   Below YAML example indicates that user want 1 disk1 with pattern given in
   `diskSelector` field with size of 2200 GB.

     ```yaml
     spec:
     hardwareCharacteristics:
       Disk:
          minimumCount: 1
          minimumIndividualSizeGB: 2200
          diskSelector:
            - hctl: "0:0:N:0"
              rotational: false
     ```

   YAML rules for multiple Disks:

   User can provide `minimumCount` and `minimumIndividualSizeGB`
   according to requirement. Then specify the disk type using combination
   of `hctl` and `rotational` parameters using Rule Book for multiple disks
   as shown in example.
   Below YAML example indicates that user want 4 disks with pattern given in
   `diskSelector` field with individual size of 2200 GB.

     ```yaml
     spec:
     hardwareCharacteristics:
       Disk:
          minimumCount: 4
          minimumIndividualSizeGB: 2200
          diskSelector:
            - hctl: "0:0:N:0"
              rotational: false
            - hctl: "0:0:N:0"
              rotational: true
     ```

   User have to provide `hctl` value in pattern format only.
   For example: if user specify 0:0:N:0 then every value have third
   octet non-zero would match "0:0:N:0".

1. `hardwareCharacteristics.nic.vendorSelector`

   `model` field under `status.hardwareDetails.nics` contains
   combination of Vendor ID and Product ID.

   Vendor ID will be extracted from `status.hardwareDetails.nics.model`
   and compared against new `vendor` fields under
   `hardwareCharacteristics.nic.vendorSelector`.
   Example: Intel's vendor ID is "0x8086".

   User can provide multiple vendors under `vendorSelector`.
   Dell supported NIC Vendor name and ID are present in rule book.

   The classification of `vendor` will be done using exact match
   of the values provided by user in profile.

   Investigation details: Below is sample introspection data for NICs.

      ```yaml
     hardware:
       nics:
       - ip: ""
         mac: 24:6e:96:aa:bb:cc
         model: 0x8086 0x1234
         name: eth3
         pxe: false
     ```

### Implementation Details/Notes/Constraints

Link for Existing HWCC Specs
[Existing YAML](https://github.com/metal3-io/hardware-classification-controller/blob/master/config/samples/metal3.io_v1alpha1_hardwareclassification.yaml)

* Below is sample yaml for additional parameters in HardwareClassification.

   ```yaml

   apiVersion: metal3.io.sigs.k8s.io/v1alpha1
   kind: HardwareClassification
   metadata:
     name: profile1
   spec:
     hardwareCharacteristics:
       Disk:
          minimumCount: 5
          minimumIndividualSizeGB: 2200
          diskSelector:
            - hctl: "0:0:N:0"
              rotational: false
            - hctl: "0:0:N:0"
              rotational: true
            - hctl: "0:N:0:0"
              rotational: true
            - hctl: "N:0:0:0"
              rotational: false
       NIC:
          minimumCount: 2
          vendorSelector:
            - vendor: 0x8086
            - vendor: 0x15b3
   ```

* Update the existing Schema `HardwareClassification` by adding new
  parameters "diskSelector" and "vendor" under Disk and NIC respectively.

* Add validation for "diskSelector" and "vendor" parameters.

* Under classification, from the `diskSelector` list we will filter
  out the disk by using the `hctl` and `rotational` parameter. Then we
  will compare the filtered disk for count and size parameter.
  Classification of NVMe disk will be done using `rotational` and `model`
  parameter. `model` parameter will contain NVMe keyword.
  For "vendor" parameter under `hardwareCharacteristics.nic.vendorSelector`,
  we will use exact string match to classify host and if all vendors
  present in host than host is classified.

* Once the classification is completed, will add label if user has
  provided any, otherwise will add default label as
  `hardwareclassification.metal3.io/<profile-name>: matches`.

### Risks and Mitigations

This adds some complexity for user to define the rules in CR.
Proper documentation will help to solve this issue.

## Design Details

### Work Items

1. Add new parameters "diskSelector" under Disk and "vendor" under NIC
   in file /api/v1alpha1/hardwareClassification_types.go.
1. Update existing validation logic for new parameters introduced in
   Disk and NIC.
1. Extend existing comparison framework to support new parameters introduced
   in Disk and NIC.
1. Write unit tests for above implementation.

### Dependencies

Baremetal-Operator - To fetch BareMetal-host for classification.

### Test Plan

* Additional Unit tests for modified modules will be implemented.
* Functional testing will be performed with respect to implemented
  HardwareClassification CRD and controller.
* Deployment & integration testing will be done.
* We will carry out testing of HWCC on Dell hardware.

## Alternatives

In `diskSelector` field we are adding `hctl` and `rotational` fields
only. For now disk type can be easily found only using these two
parameters, so there is no need of other parameters.

In future if other parameters from `rootDeviceHints` are needed,
we can add those in `disk` structure for further use cases.
As it will be helpful to mirroring the structure for consistency.

## References

* <https://github.com/metal3-io>
* <https://github.com/metal3-io/hardware-classification-controller>
