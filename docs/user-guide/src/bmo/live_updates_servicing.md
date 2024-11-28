# Live updates (servicing)

Live updates (servicing) enables baremetal-operator to conduct certain actions
on already provisioned BareMetalHosts. These actions currently include:

- [configuring firmware settings](./firmware_settings.md)
- [updating BIOS and/or BMC firmware](./firmware_updates.md)

Live updates (servicing) is an opt-in feature. Operators may enable this
feature by creating a `HostUpdatePolicy` custom resource.

## HostUpdatePolicy custom resource definition

HostUpdatePolicy is the custom resource which controls applying live updates.
Each part of the functionality can be controlled separately by setting the
respective entry in the HostUpdatePolicy spec:

- `firmwareSettings` - controls changes to firmware settings
- `firmwareUpdates` - controls BIOS and BMC firmware updates

### Allowed values for firmwareSettings and firmwareUpdates fields

Each of the fields can be set to one of the two values:

- `onReboot` - enables performing the requested change on next reboot, or
- `onPreparing` - (default setting) limits applying this type of change to
Preparing state (which only applies to nodes which are being provisioned)

### Example HostUpdatePolicy definition

Here is an example of a HostUpdatePolicy CRD:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostUpdatePolicy
metadata:
  name: ostest-worker-0
  namespace: openshift-machine-api
spec:
  firmwareSettings: onReboot
  firmwareUpdates: onReboot
```

## How to perform Live updates on a BareMetalHost

- create a HostUpdatePolicy resource with the name matching the BMH to be
updated
- use the format above, ensure `firmwareSettings` and/or `firmwareUpdates` is
set to `onReboot`
- make changes to [HostFirmwareSettings](./firmware_settings.md) and/or [HostFirmwareComponents](./firmware_updates.md) as required
- make sure the modified resources are considered valid (see `Conditions`)
- if you're updating a Kubernetes node, make sure to drain it and mark as
not schedulable
- issue a reboot request via the [reboot annotation](./reboot_annotation.md)
- wait for the `operationalStatus` to become `OK` again
- if you're updating a Kubernetes node, make it schedulable again

### Example commands

Below commands may be used to perform servicing operation on a bareMetalHost:

```yaml
cat << EOF > hup.yaml
apiVersion: metal3.io/v1alpha1
kind: HostUpdatePolicy
metadata:
  name: ostest-worker-0
  namespace: openshift-machine-api
spec:
  firmwareSettings: onReboot
  firmwareUpdates: onReboot
EOF
```

```console
kubectl apply -f hup.yaml

kubectl patch hostfirmwaresettings ostest-worker-0 --type merge -p \
    '{"spec": {"settings": {"QuietBoot": "true"}}}'

kubectl patch hostfirmwarecomponents ostest-worker-0 --type merge -p \
    '{"spec": {"updates": [{"component": "bios",
                        "url": "http://10.6.48.30:8080/firmimgFIT.d9"}]}}'

kubectl cordon worker-0

kubectl annotate bmh ostest-worker-0 reboot.metal3.io=""
```

Once the operation is complete, the node can be un-drained with the below command:

```console
kubectl uncordon worker-0
```

### Resulting workflow

Once changes similar to the above are made to the relevant CRDs, the following
will occur:

- BMO will generate [servicing steps](https://docs.openstack.org/ironic/latest/admin/servicing.html) (similar to manual cleaning steps)
required to perform the requested changes
- BMH will transition to `servicing` operationalStatus
- BMO will make calls to Ironic which will perform the servicing operation
- Ironic will reboot the BMH into the IPA image and perform requested changes
- depending on the hardware, more than one reboot may be required
- once servicing completes, BMO will update the operationalStatus to `OK`
- in case errors are encountered, BMO will set operationalStatus to `error`,
set errorMessage to the explanation of the error, and retry the operation after
a short delay
