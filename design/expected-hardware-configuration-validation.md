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

Code with the ability to perform the comparison on inspected hosts and mark the host with label as 'Host match found' if
the requirements match with what is inspected.

## Motivation

We need to validate and compare expected hardware configuration against ironic introspection data.

### Goals

Purpose is to add a new CRD `HardwareValidator` to hold the expected hardware details, and write a controller
that reconciles those by looking for host CRs that match and adding labels to them.

## Proposal

We are creating proposal based on the discussion with metal3 community on issue #351:
https://github.com/metal3-io/baremetal-operator/issues/351

We compared introspection data of Ironic with metal3 schema and we found that default minimum expected hardware
configuration needs to be added by introducing a new CRD `HardwareValidator`.

We will write a controller that checks inspected baremetal hosts against expected hardware configurtion and add label
as 'Host match found' if match found.
  
### Implementation Details/Notes/Constraints

Link for Existing Metal3 Specs
Please refer metal3 spec for bare-metal:
https://github.com/metal3-io/baremetal-operator/blob/master/deploy/crds/metal3.io_baremetalhosts_crd.yaml

* Write a below schema for new CRD under folder deploy/crds for Kind HardwareValidator.

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
    ```
* Write a new API as baremetalhost/v1beta1 and new kind(CRD) HardwareValidator.
    e.g.
        
       kubebuilder create api --group baremetalhost --version v1beta1 --kind HardwareValidator
    
    - This will create the files api/v1beta1/hardwarevalidator_types.go where the API is defined and the
      controller/hardwarevalidator_controller.go where the reconciliation business logic is implemented for this Kind(CRD).
    - Implement a new function fetchHost() which will fetch all baremetal hosts.
    - In hardwarevalidator_controller.go, reconcile function will call fetchHost() function to fetch all baremetal hosts and also extract
      Expected hardware configuration from `metal3.io_hardwarevalidator_crd.yaml`.
    
        Create a new Validator.go file to write comparison and validation logic for inspected baremetal hosts.
        - Write a function which will have the expected hardware details and all the baremetal host list.
        - Will pass above two inputs to validator function defined in validator.go file.
	    - Write an algorithm to loop over all the hosts and check for comparison and validation of
	    specs against the expected hardware details.
	    - If host match found after execution of above algorithm, matched host will append to list.
        - Return list to caller function.
   
    - According to list returned by validator function, will update the label for all hosts.


* Create the Schema struct for `ExpectedHardwareConfiguration` inside `HardwareValidatorSpec`,
in file pkg/api/metal3/v1beta1/hardwarevalidator_types.go.

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

### Risks and Mitigations

None

## Design Details

All required design details are mentioned in the Implementation section.


### Work Items

1. Implement CRD for `HardwareValidator`.
2. Create the Schema struct for ExpectedHardwareConfiguration inside HardwareValidatorSpec,
in file pkg/api/metal3/v1beta1/hardwarevalidator_types.go
3. Implement a controller for HardwareValidator.
4. Add watch on hardware setting changes.
5. Create a validateAndCompare function to validate inspected hosts against the expected hardware configuration.
6. Matched host status will be added in the list after validation.
7. Add multiple labels to the returned list of hosts from validator function.
8. Write unit tests for above implementation.

### Dependencies

- Ironic

- Cluster-Api-Baremetal-Provider

- Baremetal-Operator

### Test Plan
 
- Unit tests will be implemented.

- Functional testing will be performed with respect to implemented hardwareValidator CRD and controller.

- Deployment & integration testing will be done.

## References

* https://github.com/metal3-io
