<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Expected Hardware Configuration Validation

## Table of Contents

<!--ts-->
   * [Expected Hardware Configuration Validation](#title)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
      * [Proposal](#proposal)
         * [Implementation Details/Notes/Constraints ](#implementation-detailsnotesconstraints-optional)
         * [Risks and Mitigations](#risks-and-mitigations)
      * [Design Details](#design-details)
         * [Work Items](#work-items)
         * [Dependencies](#dependencies)
         * [Test Plan](#test-plan)
      * [References](#references)

## Summary

Code with the ability to perform the comparison in the baremetal-operator and put the host in an error state if the
requirements do not match what is discovered.

This should be a unique error state that indicates the inventory failed to match requirements, as opposed to, for instance, an IPMI Authentication Error, or a Memory Test Error (future).

## Motivation

We need to validate and compare expected hardware configuration against ironic introspection data.

### Goals

Purpose is to add a new section “ExpectedHardwareConfiguration” in `metal3.io_baremetalhosts_crd.yaml` which will be
compared with user’s requirements and if the hardware details doesn’t match, will report a unique error.

## Proposal

We are creating proposal based on the discussion with metal3 community on issue #351:
https://github.com/metal3-io/baremetal-operator/issues/351

We compared introspection data of Ironic with metal3 schema and we found that default minimum expected hardware
configuration needs to be added in  `metal3.io_baremetalhosts_crd.yaml` by introducing new section called
‘ ExpectedHardwareConfiguration’.

“ExpectedHardwareConfiguration” is different than existing HardwareProfile. Existing HardwareProfile are hardcoded and
can not be customized, so as an operator or infrastructure provider I would like to define desired hardware configuration
for specific workloads. This functionality will help reduce time to provision a host, because if the host is not found
matching to expected hardware configuration it means that given host is not capable to run such workloads. If host
matches to expected configuration, then host is available for use from node pool which can be flagged through
inventory/label.
  
For validating the expected hardware configuration, there will be corresponding code in BMO.
Any provisioning of nodes will be out of scope for this effort. 

### Implementation Details/Notes/Constraints

Link for Existing Metal3 Specs
Please refer metal3 spec for bare-metal:
https://github.com/metal3-io/baremetal-operator/blob/master/deploy/crds/metal3.io_baremetalhosts_crd.yaml

1. Add schema for ‘ExpectedHardwareConfiguration’ in  `metal3.io_baremetalhosts_crd.yaml` under ‘Spec’ for BaremetalHost.

    ```yaml
    ExpectedHardwareConfiguration:
        default:
        properties:
           cpu:
               properties:
                   count:
                       type : Integer
           type: Object
           disk:
               properties:
                   sizeBytesGB:
                       type: Integer
                   numberOfDisks:
                       type: Integer
           type: Object
           nics:
               properties:
                  numberofNICS:
                     type: Integer
           type: Object
           ram:
               properties:
                   sizeBytesGB:
                       type: Integer
           type: Object
           systemVendor:
              properties:
                  name:
                      type: String
           type: Object
           Firmware:
              Properties:
                  Version:
                      RAID:
                          type: String
                      BasebandManagement:
                          type: String
                      BIOS: 
                          type: String
                     IDRAC: 
                          type: String
            type: Object
        required:
        - cpu
        - nics
        - ram
        - disk
        - systemVendor
        - firmware
    ```

2. Define struct in baremetalhost_types.go to store values for ‘HardwareExpectedConfiguration’ after extracting it
from `bmhosts_crs.yaml`.

    ```yaml
    type ExpectedHardwareConfiguration struct {
     ExpectedCpu           ExpectedCpu          `json:"expectedCpu"`
     ExpectedDisk          ExpectedDisk         `json:"expectedDisk"`
     ExpectedNics          ExpectedNics         `json:"expectedNics"`
     ExpectedRam           int                  `json:"expectedRam"`
     ExpectedSystemVendor  ExpectedSystemVendor `json:"expectedsystemVendor"`
    }
    
    type ExpectedCpu struct {
     Count  int `json:"count"`
    }
    
    type ExpectedDisk struct {
     SizeBytesGB    int  `json:"sizeBytesGB"`
     NumberOfDisks  int  `json:"numberOfDisks"`
    }
    
    type ExpectedNics struct {
     NumberOfNics   int  `json:"numberOfNics"`
    }
    
    type ExpectedSystemVendor struct {
     Name  string  `json:"name"`
    }
    ```

* Changes In host_state_machine.go: 

    Add "handleMatchDesiredHardwareProfile handler for''StateMatchDesiredProfile after "StateInspecting", where
    handleMatchDesiredHardwareProfile() will call actionMatchDesiredHardwareProfile() from baremetalhost_controller.go 

* Add Validation and Comparison logic in baremetalhost_controller.go:

    Create a function "actionMatchDesiredHardwareProfile()" which gets called after "actionInspecting()" to compare and
    check the hardware details received from the ironic introspection data with DesiredHardwareProfile.
    
    In actionMatchDesiredHardwareProfile() function:
    - The extracted “ExpectedHardwareConfiguration” from `bmhosts_crs.yaml` gets stored in a struct
      (ExpectedHardwareConfiguration) which then gets converted into json object.
    - Compare “ExpectedHardwareConfiguration” with “HardwareDetails” which contains details of node hardware after
      introspection.
     
    This function returns ‘Valid’ string if introspection data fulfills ExpectedHardwareConfiguration else returns
    ‘Invalid’.

* Node status after validation will be added to metadata annotation section.

    Annotations is an unstructured key value map stored with a resource that may be set by external tools to store and
    retrieve arbitrary metadata. They are not queryable and should be preserved when modifying objects.
    
    Our investigation on existing BMO code led to the realization that there is a method SetMetaDataAnnotation() which
    takes key and value as arguments and sets that annotation and value.

    e.g.
    
        metav1.SetMetaDataAnnotation(&cm.ObjectMeta, HostStatus, valid/invalid)
        
    ```yaml
            kind: BareMetalHost
            metadata:
              annotations:
                kubectl.kubernetes.io/last-applied-configuration: |
                  {"apiVersion":"metal3.io/v1alpha1","kind":"BareMetalHost","metadata":{"annotations":
                  {"HostStatus":"valid/invalid"},"name":"node-1","namespace":"metal3"},"spec":{"bmc":{"address":
                  "ipmi://192.168.111.1:6231","credentialsName":"node-1-bmc-secret"},"bootMACAddress":"00:a0:6c:c1:02:ea","online":true}}
    ```    


### Risks and Mitigations

None

## Design Details

All required design details are mentioned in the Implementation section.


### Work Items

1. Introduce new section called "EXpectedHardwareConfiguration" in schema `metal3.io_baremetalhosts_crd.yaml`.
2. Define structure for new section in baremetalhosts_types.go.
3. Add new state and handler in host_state_machine.go.
4. Add validation and comparison logic in baremetalhosts_controller.go.
5. Node status after validation should be added to metadata annotation section.
6. Write unit tests for above implementation.


### Dependencies

Ironic

### Test Plan

The test objective is to deliver the defect free quality product.

**Testing Method:**

All the testing procedures will be manual. The setup, deployment, testing and verification parts will be done manually. 

**Types of testing:**

Following types of testing will be covered:

1. Functional Testing:

    This section will mainly focus on testing the changes made in Metal3. 

2. Regression Testing:

    This part will cover the impact on existing workflow of Metal3.

**Features to be tested:**

* Metal3

**Software Requirements:**

* Metal3

All the testing procedures will be manual. The setup, deployment, testing and verification parts will be done manually. 

**Test cases:**

We need to add test cases as per the implementation points mentioned in the above heading (Design Details).
Some of the use cases are mentioned below:

1. Test the BareMetal host requirements (bmhosts_crs.yaml) are received in expected format.
2. Test the updated Desired Hardware Profile in metal3.io_baremetalhosts_crd.yaml. The desired Hardware Profile includes
CPU, NICS, Firmware and Storage.
3. Compare the new added sections (yaml format) with the fetched Ironic Introspection data (JSON format).
4. Test the annotations created for BareMetal host. This will cover the error state of the host.
5. Test the existing functionality mentioned in the link:
https://github.com/metal3-io/baremetal-operator/blob/master/pkg/apis/metal3/v1alpha1/baremetalhost_types_test.go 


## References

* https://github.com/metal3-io