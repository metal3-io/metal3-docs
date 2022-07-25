<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Add API to support vendor firmware burn and config

## Status

provisional

## Summary

Add a new interface to allow burn and config vendor firmware.

## Motivation

It desired to burn and config vendor firmware before deploying the OS image.
With hardware manager framework vendor can extend IPA to burn and configure its firmware.
Burning and configuring firmware is done in the manual cleaning step. It desired to expose this
functionality to BMO API.

### Goals

1. Agree on the format of the API and attributes
2. Agree on Nvidia vendor format

### Non-Goals

1. Agree on others vendor’s format.

## Proposal

### User Stories

#### Story 1

Cloud admin wants to burn and configure vendor firmware before OS deployed on bare-metal host.

## Design Details

### Implementation Details/Notes/Constraints


IPA HardwareManagers allows vendors to add firmware burn and config
in the manual cleaning stage.

The ironic command to trigger the manual cleaning would be in
the following syntax:

```shell
baremetal node clean node --clean-steps \
[{"interface": "deploy", "step": <vendor function>, \
   "args": {<vendor_arg1>: <vendor_value1>, \
   <vendor_arg2>: <vendor_value2>, ...}}]
```

IPA HardwareManagers framework defines the following attributes:
1. `step` - A function on the vendor hardware manager
2. `argsinfo` - Arguments that can be required or optional to the step function
3. `interface` - Should always be the deploy interface

The proposal is to extend the BareMetalHost with VendorFirmware field.
The VendorFirmware field includes the `step` name and `args` that can be required or optional.

Nvidia hardware manager support `step` - update_nvidia_firmware with `args` - firmware_config and firmware_url

The VendorFirmwareConfig for Nvidia should be the following:

```yaml
vendor_firmware:
   update_nvidia_firmware:
      firmware_config: "http://10.7.12.161/07_2022/config.yaml"
      firmware_url: "http://10.7.12.161/fw/07_2022"
```

This yaml will translated to the following ironic command:

``` console
baremetal node clean node --clean-steps \
[{"interface": "deploy", "step": "update_nvidia_firmware","args": \
{"firmware_config": "http://10.7.12.161/07_2022/config.yaml", \
"firmware_url": "http://10.7.12.161/fw/07_2022"}}]
```

Please note that VendorFirmware defines vendor clean steps that existing IPA upstream.
Other vendors can extend IPA to support their firmware as Nvidia did. They may extend the VendorFirmware
according to their "step" and "args" defined in IPA.

### Risks and Mitigations

None

### Work Items

- Extend the BareMetalHost CRD with the new parameters for VendorFirmware.

- Validation of input values in the YAML parameters

- A function to handle the manual cleaning steps related to Nvidia firmware.

- Unit tests for all the work above

### Dependencies

- Ironic
- BareMetal-operator

### Test Plan

- Unit tests for the functions
- Integration testing with actual hardware

### Upgrade / Downgrade Strategy

None

### Version Skew Strategy

None

## Drawbacks

None

## Alternatives

Another approch is to define VendorFirmware to contains a string. The string describes
the manual cleaning steps in json format. For example:
```yaml
vendor_firmware:
   config: '{
      "interface": "deploy",
      "step": "update_nvidia_firmware",
      "args": {
         "firmware_config": "http://10.7.12.161/07_2022/config.yaml",
         "firmware_url": "http://10.7.12.161/fw/07_2022"
   }'
```

The downside of this approch is that we don't have validate control on the user input.

## References

- [IPA Hardware Managers]
  (https://docs.openstack.org/ironic-python-agent/latest/contributor/hardware_managers.html)

- [Nvidia firmware support in IPA]
  (https://review.opendev.org/c/openstack/ironic-python-agent/+/566544)
