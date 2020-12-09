# add support for extra hardware parameters in Disk, RAM, CPU and NIC

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
[Issue 53](https://github.com/metal3-io/hardware-classification-controller/issues/53)

* In Disk, supported parameters are only size and count,
  in addition to these user can identify types of Disk (for eg:
  HDDs, SSDs, RAID or NVMes). This will help the user for Day-1,
  Day-2 scenarios.
* CPU architecture will be useful if the user wants to have 32-bit
  or 64-bit processor as per his requirements.
  If user is interested in particular NIC vendor, then NIC vendor
  can be added as parameter.

* New parameters such as Firmware and SystemVendor will be added
  advantage to identify matched hosts.
  System Vendor will be useful to add as a new parameter if the
  user is looking for particular vendor and their hardware for his
  application to support or deploy on.
  Firmware will be useful to add as a new parameter if user is looking
  for specific feature/s in particular releases or versions.

### Investigation Details

Add support for new parameters:

1. CPU

   `arch` will come under CPU parameter.

   User can provide `arch` type based on requirement.

   Investigation Details: Below is sample introspection data for CPU.
   `arch` parameter will be added under `cpu` section.
   Types of architecture are 32-bit (x86) and 64-bit
   (x86-64, IA64, and AMD64).

   ```yaml
   hardware:
       cpu:
          arch: "x86_64"
   ```

1. Disk

   `type` will come under disk parameter.

   User can provide multiple disk type (RAID/HDD/SSD/NVMe), count and
   individual size based on requirement.

   Investigation Details: Disk type can be identified using combination
   of rotational and hctl parameters.
   Here `hctl` represents :

   1. SCSI adapter number [host]
   1. channel number [bus]
   1. id number [target]
   1. number of logical units [lun]

   and rotational value will be true if disk is HDD and false
   represents individual SSD, also software RAID can be SSD RAID or
   HDD RAID with rotational value true.

   We are taking example of Dell hardware here.

   1. Individual HDD/SSD : with `hctl` as 0:0:N:0 and rotational flag as
   True/False.
   1. PERC RAID of HDDs/SSDs : with `hctl` as 0:N:0:0/0:N:N:0 and rotational
   flag as True.
   1. Dell BOSS Controller Individual SSDs : with `hctl` as N:0:0:0 and
   rotational flag as False.
   1. Dell BOSS Controller Virtual Disk (RAID) : with `hctl` as N:0:0:0 and
   rotational flag as True.
   1. NVMe : No `hctl` Pattern, rotational flag as False and model name
   contains NVMe keyword.

   Below is sample introspection data for Disk.

     ```yaml
     hardware:
        disks:
          - name: "/dev/sda"
            model: "KPM5XVUG3T84"
            rotational: "true"
            hctl: "0:0:N:0"
     ```

1. NIC

   Adding new parameter `vendorName` under NIC. User can provide NIC
   requirement in the form of `vendor`.

   While classification of `vendor` parameter, use sub-string matching
   will be done.

   Investigation details: Below is sample introspection data for NICs.
   `model` field under `nics` contains combination of Vendor ID and
   Product ID.

     ```yaml
     hardware:
       nics:
       - ip: ""
         mac: 24:6e:96:aa:bb:cc
         model: 0x8086 0x1234
         name: eth3
         pxe: false
     ```

1. Firmware

   Firmware is new parameter to be introduced in HardwareClassification
   which contains BIOS information. User can specify BIOS requirements
   by providing `vendor` and `version` details.

   The classification of `vendor` and `version` will be done using
   exact match of the values provided by user in profile.

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

1. SystemVendor

   SystemVendor is new parameter to be introduced which helps user to
   classify hosts of certain manufacturer and product. User needs to
   provide `manufacturer` and `productName` in yaml.

   The classification of `manufacturer` and `productName` will be done
   using exact match of the values provided by user in profile.

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
[Existing YAML](https://github.com/metal3-io/hardware-classification-controller/blob/master/config/samples/metal3.io_v1alpha1_hardwareclassification.yaml)

* Below is sample yaml for additional parameters in HardwareClassification.

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
          minimumSpeed: 4.3
       Disk:
          - type: SSD
            minimumCount: 2
            minimumIndividualSizeGB: 2200
          - type: RAID
            minimumCount: 1
            minimumIndividualSizeGB: 2200
       NIC:
          vendor: Intel
          minimumCount: 4
       RAM:
          minimumSizeGB: 32
       Firmware:
          Bios:
            vendor: Dell Inc.
            version: 1.5.6
       SystemVendor:
           manufacturer: Dell Inc.
           productName: PowerEdge R640
   ```

* Update the existing Schema `HardwareClassification` by adding new
  parameters "arch", "type" and "vendor" under CPU, Disk and NIC
  respectively.

* Create the new Schema struct for "firmware" and "systemVendor" parameters
  inside `HardwareClassificationSpec`.

* Add validation and classification for "arch", "type", "vendor", "firmware"
  and "systemVendor" parameters.

* Once the classification is completed, will add label if user has
  provided any, otherwise it will be added as
  `hardwareclassification.metal3.io/<profile-name>: matches`.

### Risks and Mitigations

None.

## Design Details

No change required.

### Work Items

1. Add new parameters "arch" under CPU, "type" under Disk and
   "vendor" under NIC in file /api/v1alpha1/hardwareClassification_types.go.
1. Add new schema under hardware-classification for "firmware" and
   "systemVendor" in file /api/v1alpha1/hardwareClassification_types.go.
1. Update existing validation logic for new parameters introduced in CPU,
   Disk and NIC.
1. Implement validation logic for "firmware" and "systemVendor".
1. Extend existing comparison framework to support new parameters introduced
   in CPU, Disk and NIC.
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
