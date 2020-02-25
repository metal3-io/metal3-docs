<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Minimum Hardware Configuration Validation

## Table of Contents

<!--ts-->
   * [Minimum Hardware Configuration Validation](#title)
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

Code with the ability to perform the comparison on inspected hosts and update the host with labels containing matched profiles.

## Motivation

We need to validate and compare minimum hardware configuration against host hardware details-section.

### Goals

Purpose is to add a new CRD `HardwareClassificationController` to hold the minimum hardware details, and write a controller that reconciles those by looking for host 
CRs that matches with multiple hardware classification profiles and add label of matched profile into baremetal host baremetalHost_crd.yaml.

## Proposal

We are creating proposal based on the discussion with metal3 community on issue #351:
https://github.com/metal3-io/baremetal-operator/issues/351

We compared introspection data of Ironic with metal3 schema and we found that default minimum hardware
configuration needs to be added by introducing a new CRD `HardwareClassificationController`.

We will write a controller that checks inspected baremetal hosts against minimum hardware configuration and add label of matched profile into baremetal host baremetalHost_crd.yaml.
  
### Implementation Details/Notes/Constraints

Link for Existing Metal3 Specs
Please refer metal3 spec for bare-metal:
https://github.com/metal3-io/baremetal-operator/blob/master/deploy/crds/metal3.io_baremetalhosts_crd.yaml

* Write a below schema for new CRD under folder deploy/crds for Kind HardwareClassificationController.

    ```yaml
    expectedHardwareConfiguration:
        default:
        properties:
           minimumCPU:
               properties:
                   count:
                       type : Integer
           type: Object
           minimumDisk:
               properties:
                   sizeBytesGB:
                       type: Integer
                   numberOfDisks:
                       type: Integer
           type: Object
           minimumNICS:
               properties:
                  numberofNICS:
                     type: Integer
           type: Object
           minimumRAM:
               properties:
                   sizeBytesGB:
                       type: Integer
           type: Object
           systemVendor:
              properties:
                  name:
                      type: String
           type: Object
           firmware:
              properties:
                  version:
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
        - minimumCPU
        - minimumNICS
        - minimumRAM
        - minimumDisk
    ```
* Write a new API as hardware-classification-controller/api/v1alpha1 and new kind(CRD) HardwareClassificationController.
    e.g.
        
       kubebuilder create api --group metal3.io --version v1alpha1 --kind HardwareClassificationController
    
    - This will create the files api/v1alpha1/hardwareClassificationController_types.go where the API is defined and the
      controller/hardwareClassificationController_controller.go where the reconciliation business logic is implemented for this Kind(CRD).
    - Implement a new function fetchHost() which will fetch all baremetal hosts from Baremetal-Operator. This function will return a list of filtered hosts(hosts in status 'ready' or 'inspecting'). 
    - In hardwareClassificationController_controller.go, reconcile function will call fetchHost()        function to fetch all baremetal hosts and also extract
      minimum hardware configuration from `metal3.io_HardwareClassificationController_crd.yaml`.
    - Create a Comparison() function which will have fetched baremetalhost list and extracted hardware profile in validate.go file.
    - Comparison function will check each host against multiple profiles and add profiles in list which will be added as value against key host in a map.
    - Map containing hosts and profiles will be returned to the reconciler function for label updating.
    - According to map returned by validate function, will update the label for all hosts.


* Create the Schema struct for `ExpectedHardwareConfiguration` inside `HardwareClassificationControllerSpec`,
in file /api/v1alpha1/hardwareClassificationController_types.go.

    ```yaml
    type ExpectedHardwareConfiguration struct {
     MinimumCpu           MinimumCpu          `json:"minimumCPU"`
     MinimumDisk          MinimumDisk         `json:"minimumDisk"`
     MinimumNics          MinimumNics         `json:"minimumNICS"`
     MinimumRam           int                 `json:"minimumRAM"`
     SystemVendor         SystemVendor        `json:"systemVendor"`
     Firmware             Firmware            `json:"firmware"`
    }
    
    type MinimumCpu struct {
     Count  int `json:"count"`
    }
    
    type MinimumDisk struct {
     SizeBytesGB    int  `json:"sizeBytesGB"`
     NumberOfDisks  int  `json:"numberOfDisks"`
    }
    
    type MinimumNics struct {
     NumberOfNics   int  `json:"numberOfNics"`
    }
    
    type SystemVendor struct {
     Name  string  `json:"name"`
    }

    type Firmware struct {
      Version Version `json:"version"`
    }

    type Version struct {
      RAID string `json:"RAID"`
      BasebandManagement string `json:"baseBandManagement"`
      BIOS string `json:"BIOS"`
      IDRAC string `json:"IDRAC"`
    }
    ```

### Risks and Mitigations

None

## Design Details

All required design details are mentioned in the Implementation section.


### Work Items

1. Implement CRD for `HardwareClassificationController`.
2. Create the Schema struct for MinimumHardwareConfiguration inside HardwareClassificationControllerSpec,
in file pkg/api/metal3/v1alpha1/hardwareClassificationController_types.go
3. Fetch baremetal host list from the baremetal operator running in the metal3 cluster.
4. Extract the multiple profile from the yaml file passed to the CRD.
5. Create a Comparison function to check the valid host against multiple profile and return the map containing host as key and matched profiles as values.
6. Add profile labels for baremetal host CR.
7. Write unit tests for above implementation.

### Dependencies

- Ironic

- Cluster-Api-Baremetal-Provider

- Baremetal-Operator

### Test Plan
 
- Unit tests will be implemented.

- Functional testing will be performed with respect to implemented HardwareClassificationController CRD and controller.

- Deployment & integration testing will be done.

## References

* https://github.com/metal3-io
* https://github.com/metal3-io/hardware-classification-controller

