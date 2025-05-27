# Rebooting hosts

The reboot annotation can be used for rebooting BareMetalHosts in the
`provisioned` state. The annotation key takes either of the following forms:

- `reboot.metal3.io`
- `reboot.metal3.io/{key}`

**Note:** use the `online` field to power hosts on/off instead of rebooting.

## Simple reboot

In its basic form (`reboot.metal3.io`), the annotation will trigger a reboot of
the BareMetalHost. The controller will remove the annotation as soon as it has
restored power to the host.

The annotation value should be a JSON map containing the key `mode` and a value
`hard` or `soft` to indicate if a hard or soft reboot should be performed. If
the value is an empty string, the default is to first try a soft reboot, and if
that fails, do a hard reboot.

## Phased reboot

The advanced form (`reboot.metal3.io/{key}`) includes a unique suffix
(indicated with `{key}`).  In this form the host will be kept in `PoweredOff`
state until the annotation has been removed.  This can be useful if some tasks
needs to be performed while the host is in a known stable state.  The purpose
of the `{key}` is to allow multiple clients to use the API simultaneously in a
safe way.  Each client chooses a key and touches only the annotations that has
this key to avoid interfering with other clients.

If there are multiple annotations, the controller will wait for all of them to
be removed (by the clients) before powering on the host.  Similarly, if both
forms of annotations are used, the `reboot.metal3.io/{key}` form will take
precedence.  This ensures that the host stays powered off until all clients are
ready (i.e. all annotations are removed).

Clients using this API must respect each other and clean up after themselves.
Otherwise they will step on each others toes by for example, leaving an
annotation indefinitely or removing someone else's annotation before they were
ready.

## Examples

Immediate reboot via soft shutdown first, followed by a hard power-off if the
soft shutdown fails:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: example
  annotations:
    reboot.metal3.io: ""
spec:
  ...
```

Immediate reboot via hard power-off action:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: example
  annotations:
    reboot.metal3.io: '{"mode": "hard"}'
spec:
  ...
```

Phased reboot, issued and managed by the client registered with the key
`cli42`, via soft shutdown first, followed by a hard reboot if the soft reboot
fails:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: example
  annotations:
    reboot.metal3.io/cli42: ""
spec:
  ...
```

Phased reboot, issued and managed by the client registered with the key, via
hard shutdown:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: example
  annotations:
    reboot.metal3.io/cli42: '{"mode": "hard"}'
spec:
  ...
```

## Implementation notes

The exact behavior of `hard` and `soft` reboot depends on the Ironic
configuration. Please see the [Ironic configuration
reference](https://docs.openstack.org/ironic/latest/configuration/config.html)
for more details on this, e.g. the `soft_power_off_timeout` variable is
relevant.

For more details please check the [reboot interface
proposal](https://github.com/metal3-io/metal3-docs/blob/main/design/baremetal-operator/reboot-interface.md).
