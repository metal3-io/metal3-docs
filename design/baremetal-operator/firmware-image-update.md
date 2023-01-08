# Firmware Image Update

## Status

provisional

## Summary

Provide the ability to get and update vendor firmware version.

## Motivation

It desired to update vendor firmware before deploying the OS image of the host.

### Goals

- Agree on the format of the vendor neutral API and attributes
- Implemented Nvidia firmware update for NICs

### Non-Goals

- Implemented OOB firmware update for ILO and redfish

## Proposal

### User Stories

#### Story 1

Cloud admin wants to update Nvidia NICS firmware before OS deployed on bare-metal host.

## Design Details

### New API (CRD) Proposal

We propose to introduce a new Custom Resource Definition (CRD) `HostFirmwareImage`. `HostFirmwareImage` will store a list of firmware images to be applied (if required) on the bare-metal host. The `HostFirmwareImage` will be mapped to Baremetal Host object by namespace and name. The spec section will introduce the following attributes:

- url - location to download the firmware image.
- checksum - checksum of the firmware image. Optional attribute.
- checksumType - checksum algorithm for the firmware image can be md5, sha256, sha512. Optional attribute.
- vendor – The hardware vendor which is responsible for that firmware. Current proposal it will be only nvidia and can be extended in future proposals for other vendors.
- component – The hardware component which this firmware matches. Hardware vendor may have several types of hardware for example Nvidia has NiC’s and GPU. Current proposal will be only `net` and can be extended in future proposals for other vendors.
- componentFlavor- indicate the component flavor. Optional attribute. For Nvidia NICs it will be the PSID.
- version - the requested firmware version of the firmware image.

example of the HostFirmwareImage spec section:

```yaml
spec:
  firmwareImages:
    - url: http://firmware_images/fw1.bin
      checksum: a94e683ea16d9ae44768f0a65942234d
      checksumType: md5
      vendor: nvidia
      component: net
      componentFlavor: MT_1090120019
      version: 24.34.1002
    - url: http://firmware_images/fw2.bin
      checksum: e07da4de09e9a2ab836bd7e23378f8e45afd5400f0f1cf7da5ecefce45333d5d
      checksumType: sha1
      vendor: nvidia
      component: net
      componentFlavor: MT_0000000652
      version: 22.35.1012
```

The `HostFirmwareImage` status section will introduce the following attributes:

- Firmwares – list of all hardware devices with the following information:
    - componentID – unique identifier for the hardware. For NICs the unique identifier will be in the following format “`<interface name>_<MAC>”.`
    - vendor – The hardware vendor which is responsible for that firmware.
    - component – The hardware component type.
    - componentFlavor - indicate the component flavor if such exist.
    - version - the actual firmware version of the hardware.
- lastUpdated – The timestamp of the last update.
- Conditions – we introduce 2 conditions:
    - FirmwareImageChangeDetected - Indicates that the firmware images version in the spec are different than status.
    - FirmwareImageValid - Indicates that firmware images are valid and can be configured on the host.

```yaml
status:
  firmwares:
    - componentID: enp216s0f0np0_08_c0_eb_70_74_62
      vendor: nvidia
      component: net
      componentFlavor: MT_1090120019
      version: 24.34.1002
    - componentID: enp216s0f1np1_08_c0_eb_70_74_63
      vendor: nvidia
      component: net
      componentFlavor: MT_1090120019
      version: 24.34.1002
    - componentID: enp59s0f0np0_b8_ce_f6_8d_c8_62
      vendor: nvidia
      component: net
      componentFlavor: MT_0000000652
      version: 22.35.1012
  lastUpdated: 2022-12-27T01:12:17Z
  conditions: ...
```

### HostFirmwareSettings Controller Changes

The proposal is to extend the `HostFirmwareSettings` controller which was introduced in the `bulk-set-bios-config` proposal. The controller will be extended to track the `HostFirmwareImage` CRD. The HostFirmwareImage.spec is the desired firmware version and the HostFirmwareImage.status contain the actual firmware. Please note that the correct proposal addresses Nvidia NICs but can be extended to other vendors too as well.

The NIC firmware version exists today in the data.Extra.Network struct. We will also extend `HardwareData` with the NIC firmware by adding firmware attribute to the details.NIC. BIOS version already exists in `HardwareData` but other devices which do not firmware version is not exposed will required to provide mechanism to retrieve actual firmware and store it in the `HardwareData`.

The reconcile loop of the `HostFirmwareSettings` controller will do the following:

- Validate the `HostFirmwareImage` attributes (e.g., vendor name, component …). We will try to validate at match as we can. If valid set condition to FirmwareImageValid to true.
- Fetch the corresponding HardwareData and get the Nvidia NIC firmware. The Nvidia firmware contains firmware version and componentFlavor "24.34.1002 (MT_0000000540)" other NIC vendors can extend the parsing according to their NIC firmware string.
- Fetch `HostFirmwareImage` and append missing componentID and its corresponding vendor, component and componentFlavor to the firmwares field.
- Compare the actual componentID firmware version with the desired version
- If not equal set `FirmwareImageChangeDetected` condition to true.

The reconcile loop in the BMO:

- Fetch the `HostFirmwareImage`.
- Check if the `FirmwareImageChangeDetected` and `FirmwareImageValid` set true.
- Add the prepareData.ActualFirmwareImage and prepareData.TargetFirmwareImage.
- Call the prov.Prepare with the prepareData.
- The ironic provisioner will translate the TargetFirmwareImage to manual cleaning steps.
- On success update the `HardwareData` NIC firmware.

Note: The controller will not reconcile a vendor component in the following cases:

- Vendor, component or componentID in the spec section do not exist in the bare metal.
- Actual firmware version exists in the status but no matching component or componentFlavor in the spec.

### Implementation Details/Notes/Constraints

The `HostFirmwareImage` spec section will be translated to ironic manual cleaning steps in the ironic provisioner as following:

```shell
baremetal node clean control-0 --clean-steps nvidia_nic_firmware_image.json

[{
    "interface": "deploy",
    "step": "update_nvidia_nic_firmware_image",
    "args": {
        "images": [{
            "url": "http://192.168.24.1:8787/fw/fw-ConnectX5-rel-16_35_1012-MCX556A-ECA_VASTDATA_Ax-UEFI-14.28.15-FlexBoot-3.6.804.bin",
            "checksum": "8f2caf0f6d2a80fb64c6e5454243bcba",
            "checksumType": "md5",
            " componentFlavor": "MT_0000000008",
            "version": "16.35.1012"
        }]
    }
}]
```

### Risks and Mitigations

What are the risks of this proposal and how do we mitigate? Think broadly. For example, consider both security and how this will impact the larger Kubernetes ecosystem.

### Work Items

- Add a new CRD `HostFirmwareImage`
- Extend BarematalHost NIC object with firmware
- Extend HostFirmwareSettings Controller to Reconcile `HostFirmwareImage`
- Extend ironic provisioner prepare method to build cleaning steps to update Nvidia NICs firmware

### Dependencies

- Ironic python agent - support Nvidia update firmware images
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

Similar to the `Drawbacks` section the `Alternatives` section is used to highlight and record other possible approaches to delivering the value proposed by a design.

## References

[IPA Hardware Managers](https://docs.openstack.org/ironic-python-agent/latest/contributor/hardware_managers.html)

[Nvidia firmware support in IPA](https://review.opendev.org/c/openstack/ironic-python-agent/+/566544)

[bulk-set-bios-config](https://github.com/metal3-io/metal3-docs/blob/main/design/baremetal-operator/bulk-set-bios-config.md)
