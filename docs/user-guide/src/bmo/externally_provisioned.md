# Adopting Externally Provisioned Hosts

BareMetal Operator allows enrolling hosts that have been previously provisioned
by a 3rd party without making them go through inspection, cleaning and
re-provisioning. Hosts are enrolled as usual, additionally setting the
`externallyProvisioned` field to `true`:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: host-0
  namespace: my-cluster
spec:
  online: true
  bootMACAddress: 80:c1:6e:7a:e8:10
  bmc:
    address: ipmi://192.168.1.13
    credentialsName: host-0-bmc
  externallyProvisioned: true
```

Such hosts move from the `registering` provisioning state directly into
`externally provisioned` as shows in the [state machine](./state_machine.md):

```yaml
status:
  # ...
  operationalStatus: OK
  provisioning:
    ID: 8799e0d2-d2ca-4681-9385-e8bd69f6f441
    bootMode: UEFI
    image:
      url: ""
    state: externally provisioned
```

**Note:** while it's currently not possible to get a host out of the
`externally provisioned` state, it's better to future-proof your hosts by
adding a real `image` field so that your externally provisioned hosts look
exactly like normal ones.

## Available actions

Currently, only a limited set of actions is possible on externally provisioned
hosts:

- Powering on and off using the `online` field.
- Rebooting using the [reboot annotation](./reboot_annotation.md).
- [Live updates (servicing)](./live_updates_servicing.md).
- Deletion without cleaning (the host is only powered off).

**Warning:** changing the `externallyProvisioned` field back to `false` is
currently not supported (see the [tracker
bug](https://github.com/metal3-io/baremetal-operator/issues/2465)).
