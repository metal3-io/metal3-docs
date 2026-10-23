# Hardware inspection

Inspection is a process of obtaining hardware information from the machine.
In the normal case, it runs automatically on enrollment after BMC credentials
have been verified. The BareMetalHost is in the `inspecting` state during
inspection and moves to `preparing` or `available` state on success.

On failure, inspection is retried until it succeeds or is disabled on the host
as described below.

See [Ironic inspection
documentation](https://docs.openstack.org/ironic/latest/admin/inspection/index.html)
for more details about the implementation.

## Hardware inventory

After successful inspection, the inventory is retrieved from Ironic and stored
as a `HardwareData` resource with the same name and namespace as the host. The
available information will depend on the type of inspection (fast or normal)
and on the hardware itself. Check [HardwareData
API](https://doc.crds.dev/github.com/metal3-io/baremetal-operator/metal3.io/HardwareData/v1alpha1)
for a list of all possible fields.

**WARNING:** hardware data is not updated automatically, unless a new
inspection is requested as described below.

## Fast (out-of-band) inspection

BMO 0.14 introduced a new *fast inspection* mode for Redfish-based drivers.
When this mode is configured, inspection is conducted by reading information
from the BMC instead of from the agent running on the machine. Thus, fast
inspection can be used to collect information before the host is first booted.

Set `inspectionMode` to `fast` to use this feature:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: example
spec:
  inspectionMode: fast
  # ...
```

**WARNING:** the GA release 0.14.0 contained severe issues preventing fast
inspection from working on many hardware models. Use version 0.14.2 or newer.

**NOTE:** there are no plans to make fast inspection work with the IPMI driver.

## Re-running inspection

The inspect annotation can be used to request the BareMetal Operator to
(re-)inspect an `available` BareMetalHost, for example, when the hardware
changes. If an inspection request is made while the host is any other
state than `available`, the request will be ignored.

To request a new inspection, simply annotate the host with `inspect.metal3.io`.
Once inspection is requested, you should see the BMH in `inspecting` state
until inspection is completed, and by the end of inspection the
`inspect.metal3.io` annotation will be removed automatically.

Here is an example:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: example
  annotations:
    # The inspect annotation with no value
    inspect.metal3.io: ""
spec:
  # ...
```

**NOTE:** The type of inspection (fast or normal) to re-run is defined by the
`inspectionMode` field. It must not be set to `disabled`!

## Disabling inspection

If you do not need the HardwareData collected by inspection, you can disable it
by setting the `inspectionMode` field to `disabled`, for example:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: example
spec:
  inspectionMode: disabled
  # ...
```

For BMO before version 0.12, you need to use the inspect annotation instead:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: example
  annotations:
    inspect.metal3.io: disabled
spec:
  ...
```

This approach is deprecated and will eventually be removed. In the future, the
inspect annotation will be used only for re-running inspection as described
above.

## See also

For advanced use cases, such as providing externally gathered inspection data,
see [external inspection](./external_inspection.md).
