# Add Support for extra hardware parameters in Disk, RAM, CPU and NIC
 
## Table of Contents
 
<!--ts-->
   * [Hardware Classification](#title)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
      * [Proposal](#proposal)
         * [Investigation Details](#investigation-details)
         * [Implementation Details/Notes/Constraints ](#implementation-detailsnotesconstraints-optional)
         * [Risks and Mitigation](#risks-and-mitigations)
      * [Design Details](#design-details)
         * [Work Items](#work-items)
         * [Dependencies](#dependencies)
         * [Test Plan](#test-plan)
      * [References](#references)

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

Automatically classify bare metal hosts based on user-provided rules
in a way that other controllers can use, without having to evaluate
all of those rules themselves.

We will carry testing of HWCC only on Dell hardware. Testing of HWCC on 
hardware from other vendors will not be goal of this proposal.

## Proposal
 
We are submitting proposal based on the issue raised in HWCC: 
[Issue 53](https://github.com/metal3-io/hardware-classification-controller/issues/53)

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

2. Disk

    `type` will come under disk parameter.

    User can provide multiple disk type (RAID/HDD/SSD/NVMe), count and
     individual size based on requirement.

    Investigation Details: Below is sample introspection data for Disk.

     1. HDD - Identified using `rotational` parameter's value as true
      and `hctl` value as "0:0:N:0".  
     2. SSD - Identified using `rotational` parameter's value as false
      and `hctl` value as "0:0:N:0" or "N:0:0:0".
     3. NVMe - Identified with the combination of `model` name and
      `rotational` parameter's value as false.
     4. RAID - Identified with the combination of

        a) `rotational` parameter's value as true.

        b) If `hctl` have value as "N:0:0:0" or "0:N:0:0".

     ```yaml
     hardware:
        disks:
          - name: "/dev/sda"
            model: "KPM5XVUG3T84"
            rotational: "true"
            hctl: "0:0:N:0"
     ```
3. NIC

     Adding new parameter `vendorName` under NIC. User can provide NIC
      requirement in the form of `vendor`.

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
4. Firmware

    Firmware is new parameter to be introduced in HardwareClassification
     which contains BIOS information. User can specify BIOS requirements
     by providing `vendor` and `version` details.

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
5. SystemVendor 

    SystemVendor is new parameter to be introduced which helps user to 
    classify hosts of certain manufacturer and product. User needs to 
    provide `manufacturer` and `productName` in yaml.
     
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
    
 - Update the existing Schema `HardwareClassification` by adding new 
   parameters "arch", "type" and "vendor" under CPU, Disk and NIC 
   respectively.
   
 - Create the new Schema struct for "firmware" and "systemVendor" parameters 
   inside `HardwareClassificationSpec`.

 - Add validation and classification for "arch", "type", "vendor", "firmware"
   and "systemVendor" parameters.

 - Once the classification is completed, will add label if user has
   provided any, otherwise it will be added as
   `hardwareclassification.metal3.io/<profile-name>: matches`.
  

### Risks and Mitigations
 
None.
 
## Design Details
 
No change required.
 
### Work Items

1. Add new parameters "arch" under CPU, "type" under Disk and
   "vendor" under NIC in file /api/v1alpha1/hardwareClassification_types.go.
2. Add new schema under hardware-classification for "firmware" and 
   "systemVendor" in file /api/v1alpha1/hardwareClassification_types.go.
3. Update existing validation logic for new parameters introduced in CPU, 
   Disk and NIC.
4. Implement validation logic for "firmware" and "systemVendor".
5. Extend existing comparison framework to support new parameters introduced 
   in CPU, Disk and NIC.
6. Add classification logic for "firmware" and "systemVendor". 
7. Write unit tests for above implementation.
 
### Dependencies
 
- Baremetal-Operator - To fetch BareMetal-host for classification.

### Test Plan
 
- Additional Unit tests for modified modules will be implemented.
 
- Functional testing will be performed with respect to implemented 
  HardwareClassification CRD and controller.
 
- Deployment & integration testing will be done.
 
## References
 
* https://github.com/metal3-io
* https://github.com/metal3-io/hardware-classification-controller