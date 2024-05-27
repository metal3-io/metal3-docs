# Inspect annotation

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
  ...
```

## Disabling inspection

If you do not need the HardwareData collected by inspection, you can disable it
by setting the `inspect.metal3.io` annotation to `disabled`, for example:

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

For advanced use cases, such as providing externally gathered inspection data,
see [external inspection](./external_inspection.md).
