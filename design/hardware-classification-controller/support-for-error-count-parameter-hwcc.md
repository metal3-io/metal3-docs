# add support for matched, unmatched and error hosts count parameter

## Status

Implementable

## Summary

Implement support for parameters to identify the count of host failed in
different states in addition to matched, unmatched and error host after
applying the hardware profile.

## Motivation

The current HWCC allows user to get the list of ideal hosts after applying
specifications, However it still does not show count of failed host due to
specific failures (listed in next section- `Goals`). Adding new parameters
in the status, user will get the information of failed hosts.
This will help users to debug and troubleshoot such hosts for bringing up
those to ready state.

### Goals

To make classification more useful by incorporating additional parameters
to get the count of matched, unmatched and error host.

Use the parameters below,

* `matchedCount`
* `unmatchedCount`
* `errorHosts`

Along with Introduction of following parameters

* `registrationErrorCount`
* `introspectionErrorCount`
* `provisioningErrorCount`
* `powerMgmtErrorCount`
* `detachErrorCount`
* `preparationErrorCount`
* `provisionedRegistrationErrorCount`

(Please refer section- `Investigation Details` for functionality of above parameters)

### Non-Goals

These parameters are for matched, unmatched and error host count.
HWCC only supports error state which are defined in Baremetal host.

## Proposal

* In HWCC Status, introduce new fields to show the count of
  matched, unmatched and failedhost.

* In addition to get the count of host failed due to specific failure.

### Investigation Details

Add support for new fields:

1. `matchedCount`

     Under `hwcc.Status`, new parameter  `matchedCount` will be added
     After applying user profile once resulted matched host found, count of
     matched host will be updated in `matchedCount`

2. `unmatchedCount`

     Under `Status`, new parameter  `unmatchedCount` will be added
     After applying user profile once resulted matched host found,
     count of unmatched host will be updated in `unmatchedCount`

3. `errorHosts`

     Under `hwcc.Status`, new parameter  `errorHosts` will be added
     After applying user profile, Once baremetal host are fetched, will add a
     function which returns the failed host which contains OperationalStatus
     as error. Update the count of failed host in the  `errorHosts`

4. `registrationErrorCount`

     Under `hwcc.Status`, new parameter  `registrationErrorCount` will be
     added. After applying user profile, Once list of failed baremetal host
     are identified, filter out the registration error host using host error
     type. Update the count of host failed due to registration error in the
     `registrationErrorCount`.

     RegistrationError is an error condition occurring when the
     controller is unable to connect to the Host's baseboard management
     controller.

5. `introspectionErrorCount`

     Under `hwcc.Status`, new parameter  `introspectionErrorCount` will be
     added After applying user profile, Once list of failed baremetal host are
     identified, filter out the introspection error host using host error type.
     Update the count of host failed due to introspection error in the
     `introspectionErrorCount`

     InspectionError is an error condition occurring when an attempt to
     obtain hardware details from the Host fails.

6. `provisioningErrorCount`

     Under `hwcc.Status`, new parameter  `provisioningErrorCount` will be added
     After applying user profile, Once list of failed baremetal host are
     identified, filter out the provisioned error host using host error type.
     Update the count of host failed due to provisioned error in the
     `provisioningErrorCount`.

     ProvisioningError is an error condition occurring when the controller
     fails to provision or deprovision the Host.
7. `powerMgmtErrorCount`

     Under `hwcc.Status`, new parameter  `powerMgmtErrorCount` will be added
     After applying user profile, Once list of failed baremetal host are
     identified, filter out the power management error host using host
     error type.
     Update the count of host failed due to power management error in the  `powerMgmtErrorCount`.

     PowerManagementError is an error condition occurring when the
     controller is unable to modify the power state of the Host.

8. `detachError`

     Under `hwcc.Status`, new parameter `detachErrorCount` will be added
     After applying user profile, Once list of failed baremetal host are
     identified, filter out the detach error host using host error type.
     Update the count of host failed due to detach error
     in the `detachErrorCount`.

     DetachError is an error condition occurring when the
     controller is unable to detach the host from the provisioner.

9. `preparationErrorCount`

     Under `hwcc.Status`, new parameter `preparationErrorCount` will be added
     After applying user profile, Once list of failed baremetal host are
     identified, filter out the preparation error host using host error type.
     Update the count of host failed due to preparation error in the
     `preparationErrorCount`.

     PreparationError is an error condition occurring when do
     cleaning steps failed.

10. `provisionedRegistrationErrorCount`

     Under `hwcc.Status`, new parameter `provisionedRegistrationErrorCount`
     will be added After applying user profile, Once list of failed baremetal
     host are identified, filter out the provisioned registration error host
     using host error type.Update the count of host failed due to provisioned
     registration error in the `provisionedRegistrationErrorCount`.

     ProvisionedRegistrationError is an error condition occurring when
     the controller is unable to re-register an already provisioned host.

### Implementation Details/Notes/Constraints

* Update these existing schema `HardwareClassification` by adding new
  parameter in the Status.

    * `matchedCount`
    * `unmatchedCount`
    * `errorHosts`
    * `registrationErrorCount`
    * `introspectionErrorCount`
    * `provisioningErrorCount`
    * `powerMgmtErrorCount`
    * `detachErrorCount`
    * `preparationErrorCount`
    * `provisionedRegistrationErrorCount`

* Add function to filter the failed host from the baremetal host list.

* Once list of failed host is identified, Add a new function to identify
  the error count of below parameter by iterating over failed host list and
  find the count using error type of each host

    * `registrationErrorCount`
    * `introspectionErrorCount`
    * `provisioningErrorCount`
    * `powerMgmtErrorCount`
    * `detachErrorCount`
    * `preparationErrorCount`
    * `provisionedRegistrationErrorCount`

* Once the classification is completed, count of matched and unmatched host
  can be found from the filtered hosts.

* Update the count of above parameter in the hardware classification
  status before reconciliation ends.

* Total number of hosts is equal to sum of matched, unmatched and error hosts.

### Risks and Mitigations

None

## Design Details

### Work Items

1. Add new parameters
   in the file /api/v1alpha1/hardwareClassification_types.go.

     * "MatchedCount"
     * "UnmatchedCount"
     * "ErrorHosts"
     * "RegistrationErrorCount"
     * "IntrospectionErrorCount"
     * "ProvisioningErrorCount"
     * "PowerMgmtErrorCount"
     * "DetachErrorCount"
     * "PreparationErrorCount"
     * "ProvisionedRegistrationErrorCount"

1. Add new function which filters the failed host from the fetched
   baremetal host list

1. Add function to identify the count of respective failed host state
   from host error type

1. Update count of all parameter before reconciliation ends

### Dependencies

Baremetal-Operator - To fetch BareMetal-host for classification.
(Baremetal host must have states mentioned in section- Goals)

### Test Plan

* Additional Unit tests for modified modules will be implemented.
* Functional testing will be performed with respect to implemented
  HardwareClassification CRD and controller.
* Deployment & integration testing will be done.
* We will carry out testing of HWCC on Dell hardware.

## Alternatives

None

## References

* <https://github.com/metal3-io>
* <https://github.com/metal3-io/hardware-classification-controller>
* <https://github.com/metal3-io/baremetal-operator>
