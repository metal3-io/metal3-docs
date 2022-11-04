# Inspect annotation

The inspect annotation can be used to request the baremetal operator to (re-)inspect a `Ready` BareMetalHost.
This is useful in case there were hardware changes for example.
Note that it is only possible to do this when BareMetalHost is in `Ready` state.
If an inspection request is made while BareMetalHost is any other state than Ready, the request will be ignored.

To request a new inspection, simply annotating the host with `inspect.metal3.io` is enough.
Once inspection is requested, you should see the BMH in inspecting state until inspection is completed, and by the end of inspection the `inspect.metal3.io` annotation will be removed automatically.

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
  online: true
  bootMACAddress: 00:8a:b6:8e:ac:b8
  bootMode: legacy
  bmc:
    address: ipmi://192.168.111.1:6230
    credentialsName: example-bmc-secret
...
```

Why is this needed?

- For re-inspecting BareMetalHosts after hardware changes.

Caveats:

- It is only possible to inspect a BareMetalHost when it is in `Ready` state.

Note: For other use cases, like disabling inspection or providing externally gathered inspection data, see [external inspection](./external_inspection.md).
