# Detaching Hosts from Provisioner

The detached annotation provides a way to prevent management of a
BareMetalHost. It works by deleting the host information from Ironic without
triggering deprovisioning. The BareMetal Operator will recreate the host in
Ironic again once the annotation is removed. By default, this annotation only
takes effect on BareMetalHosts in `Provisioned`, `ExternallyProvisioned` or
`Available` states, but detachment can also be
[forced](#forcing-detachment) in other states.

Normally, deleting a BareMetalHost will always trigger deprovisioning. This can
be problematic and unnecessary if we just want to, for example, move the
BareMetalHost from one cluster to another. By applying the annotation before
removing the BareMetalHost from the old cluster, we can ensure that the host is
not disrupted by this (normally it would be deprovisioned). The next step is
then to recreate it in the new cluster without triggering a new inspection.
See the [status annotation page](./status_annotation.md) for how to do this.

The detached annotation is also useful if you want to move the host under
control of a different management system without fully removing it from
BareMetal Operator. Particularly, detaching a host stops Ironic from trying to
enforce its power state as per the `online` field.

For more details, please see the [design proposal](https://github.com/metal3-io/metal3-docs/blob/main/design/baremetal-operator/detached-annotation.md).

## How to detach

The annotation key is `baremetalhost.metal3.io/detached` and the value can be
left empty or contain optional [arguments](#annotation-arguments). Here is an
example:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: example
  annotations:
    baremetalhost.metal3.io/detached: ""
spec:
  online: true
  bootMACAddress: 00:8a:b6:8e:ac:b8
  bootMode: legacy
  bmc:
    address: ipmi://192.168.111.1:6230
    credentialsName: example-bmc-secret
...
```

Now wait for the `operationalStatus` field to become `detached`.

If the host is in a different provisioning state, for example `inspecting` or
`provisioning`, BareMetal Operator waits for the current operation to finish
before detaching the host, unless detachment is
[forced](#forcing-detachment).

## Annotation arguments

Instead of an empty value, the annotation can contain a JSON object with
the following optional fields:

- `force` -- detach the host regardless of its current provisioning state, see
  [Forcing detachment](#forcing-detachment). Defaults to `false`.
- `deleteAction` -- what to do when a detached BareMetalHost is deleted, see
  [Deleting detached hosts](#deleting-detached-hosts). Either `delete`
  (the default) or `delay`.

For example:

```yaml
metadata:
  annotations:
    baremetalhost.metal3.io/detached: '{"force": true, "deleteAction": "delay"}'
```

For compatibility, a value that is not a valid JSON object is still accepted:
the host is detached as if the annotation had no arguments.

## Forcing detachment

Starting with BMO 0.13, detachment can be forced by setting the `force`
argument:

```yaml
metadata:
  annotations:
    baremetalhost.metal3.io/detached: '{"force": true}'
```

With this argument, BareMetal Operator does not wait for the current operation
to finish. If Ironic is waiting for the host during inspection, cleaning,
deployment or servicing, the operation is aborted and the host is removed from
Ironic. If Ironic is actively processing a step at that moment, the host is
detached as soon as the step finishes. Forcing has no effect on hosts that are
already being deleted.

This is useful when a long-running or stuck operation prevents a host from
being detached, for example, when the host has to be moved to another cluster
in the middle of provisioning.

Forced detachment interrupts the operation without any cleanup, so keep the
following in mind:

- The provisioning state of the BareMetalHost is not changed. For example, a
  host detached during provisioning remains in the `provisioning` state with
  its `operationalStatus` set to `detached`.
- The machine may be left in an intermediate state, for example, still running
  the ramdisk or with a partially written disk. Ironic does not manage its
  power state while the host is detached.
- Aborting a deployment requires Ironic 35.0 or newer (API version 1.110).
  With older versions of Ironic, BareMetal Operator has to deprovision the host
  in Ironic first, so the state of the machine is not preserved. This also
  runs [automated cleaning](./automated_cleaning.md) if it is enabled.
- When the annotation is removed, the host is registered in Ironic again and
  the interrupted operation starts over. For example, a host detached during
  provisioning is provisioned again from the beginning.

## Deleting detached hosts

Deleting a detached BareMetalHost removes it without powering it off or
deprovisioning it, regardless of its provisioning state. This is what allows
moving hosts between clusters as described above.

The `deleteAction` argument changes this behavior:

- `delete` (the default) -- the BareMetalHost is removed right away.
- `delay` -- the deletion is postponed for as long as the host stays detached.
  Once the annotation is removed and the host is attached again, the deletion
  proceeds as for any other host, including deprovisioning. To remove the host
  without deprovisioning it instead, change `deleteAction` to `delete`.

## How to attach again

If you want to attach a previously detached host, remove the annotation and
wait for the `operationalStatus` field to become `OK`.
