# Automatic secure boot

The automatic secure boot feature allows enabling and disabling UEFI (Unified
Extensible Firmware Interface) secure boot when provisioning a host. This
feature requires supported hardware and compatible OS image. The current
hardwares that support enabling UEFI secure boot are `iLO`, `iRMC` and
`Redfish` drivers.

Check also:

- [Ironic UEFI secure boot](https://docs.openstack.org/ironic/latest/admin/security.html#uefi-secure-boot-mode)
- [Wikipedia UEFI secure boot](https://en.wikipedia.org/wiki/UEFI#SECURE-BOOT)

## Why do we need it

We need the Automatic secure boot when provisioning a host with high security
requirements. Based on checksum and signature, the secure boot protects the
host from loading malicious code in the boot process before loading the
provisioned operating system.

## How to use it

To enable Automatic secure boot, first check if hardware is supported and then
specify the value `UEFISecureBoot` for `bootMode` in the BareMetalHost custom
resource. Please note, it is enabled before booting into the deployed instance
and disabled when the ramdisk is running and on tear down. Below you can check
the example:

```YAML
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: node-1
spec:
  online: true
  bootMACAddress: 00:5c:52:31:3a:9c
  bootMode: UEFISecureBoot
  ...
```

This will enable UEFI before booting the instance and disable it when
deprovisioned. Note that the default value for `bootMode` is `UEFI`.
