# External inspection

Similar to the [status annotation](status_annotation.md), external inspection
makes it possible to skip the inspection step. The difference is that the
status annotation can only be used on the very first reconcile and allows
setting all the fields under `status`. In contrast, external inspection limits
the changes so that only HardwareDetails can be modified, and it can be used at
any time when inspection is disabled (with the `inspect.metal3.io: disabled`
annotation) or when there is no existing HardwareDetails data.

External inspection is controlled through an annotation on the BareMetalHost.
The annotation key is `inspect.metal3.io/hardwaredetails` and the value is a
JSON representation of the BareMetalHosts `status.hardware` field.

Here is an example with a BMH that has inspection disabled and is using the
external inspection feature to add the HardwareDetails.

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: node-0
  namespace: metal3
  annotations:
    inspect.metal3.io: disabled
    inspect.metal3.io/hardwaredetails: |
      {"systemVendor":{"manufacturer":"QEMU", "productName":"Standard PC (Q35 + ICH9, 2009)","serialNumber":""}, "firmware":{"bios":{"date":"","vendor":"","version":""}},"ramMebibytes":4096, "nics":[{"name":"eth0","model":"0x1af4 0x0001","mac":"00:b7:8b:bb:3d:f6", "ip":"172.22.0.64","speedGbps":0,"vlanId":0,"pxe":true}], "storage":[{"name":"/dev/sda","rotational":true,"sizeBytes":53687091200, "vendor":"QEMU", "model":"QEMU HARDDISK","serialNumber":"drive-scsi0-0-0-0", "hctl":"6:0:0:0"}],"cpu":{"arch":"x86_64", "model":"Intel Xeon E3-12xx v2 (IvyBridge)","clockMegahertz":2494.224, "flags":["foo"],"count":4},"hostname":"hwdAnnotation-0"}
spec:
  ...
```

Why is this needed?

- It allows avoiding an extra reboot for live-images that include their own
  inspection tooling.
- It provides an arguably safer alternative to the status annotation in some cases.

Caveats:

- If both `baremetalhost.metal3.io/status` and
  `inspect.metal3.io/hardwaredetails` are specified on BareMetalHost creation,
  `inspect.metal3.io/hardwaredetails` will take precedence and overwrite any
  hardware data specified via `baremetalhost.metal3.io/status`.
- If the BareMetalHost is in the `Available` state the controller will not
  attempt to match profiles based on the annotation.
