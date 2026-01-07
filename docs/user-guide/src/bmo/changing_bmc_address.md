# Changing BMC Address

<!-- cSpell:ignore BMCs -->

There are situations where you may need to change the BMC (Baseboard Management
Controller) address of a BareMetalHost:

- The BMC hardware has failed and been replaced
- The BMC network configuration has changed (e.g., IP address reassignment)
- A mistake was made when initially setting the BMC address
- Network infrastructure changes require BMC address updates

This document explains how to update the BMC address of an existing
BareMetalHost.

## When Can the BMC Address Be Changed?

The BMC address can be updated in the following scenarios:

1. **When the host is in the `registering` state** - This is the initial state
when a BareMetalHost is first created and Ironic is attempting to register it.

1. **When the host is detached** - By using the detached annotation, you can
temporarily remove the host from Ironic's management, update the BMC address,
and then reattach it.

The BMC address **cannot** be changed while the host is actively managed by
Ironic in other states without first detaching it.

## Procedure for changing the BMC address

1. Check the current status of your BareMetalHost(s):

   ```console
   $ kubectl get baremetalhost -o wide
   NAME   STATUS     STATE         CONSUMER           BMC                                 ONLINE   ERROR     AGE
   bmh1   detached   provisioned   metal3-k8s-426jf   redfish-virtualmedia://192.168.1.32    true               108d
   bmh2   OK         registering                      redfish-virtualmedia://192.168.1.33    true               3s
   ```

1. If the state is `registering` or the status is `detached`, you can directly
   edit the BMC address.

1. If this is not the case, you need to detach the host first. **NOTE**: Make
   sure it is in a stable provisioning state, e.g. `Provisioned` or `Available`
   before this!

   ```bash
   kubectl annotate baremetalhost -n <namespace> <host-name> \
   baremetalhost.metal3.io/detached="updating-bmc"
   ```

1. Wait for the host to become detached:

   ```bash
   kubectl -n <namespace> wait baremetalhost <host-name> --for=jsonpath='{.status.operationalStatus}'=detached
   ```

1. Edit the BareMetalHost resource:

   ```bash
   kubectl edit baremetalhost -n <namespace> <host-name>
   ```

1. Update the `spec.bmc.address` field to the new BMC address:

   ```yaml
   spec:
     bmc:
       address: redfish://192.168.1.100  # Update to new address
       credentialsName: host-bmc-secret
   ```

1. If needed, also update the BMC credentials secret.

1. Remove the detached annotation to reattach the host:

   ```bash
   kubectl annotate baremetalhost -n <namespace> <host-name> \
     baremetalhost.metal3.io/detached-
   ```

   Note the trailing `-` which removes the annotation.

1. Wait for the host to be reattached:

   ```bash
   kubectl -n <namespace> wait baremetalhost <host-name> --for=jsonpath='{.status.operationalStatus}'=OK
   ```

## Important Considerations

- **Ensure stable state**: Do not try to change the BMC address in the middle of
  other operations, or if external processes or tools are interacting with the
  host. Make sure it is in a stable provisioning state, e.g. `Provisioned` or
  `Available` before considering a change.

- **Host state is preserved**: When you detach and reattach a host, the
  provisioning state is preserved. A `Provisioned` host will remain
  `Provisioned`, and an `Available` host will remain `Available`.

- **No deprovisioning occurs**: Using the detached annotation ensures that the
  host is not deprovisioned when you update the BMC address.

- **BMC credentials**: If the BMC replacement also changed the username or
  password, make sure to update the credentials secret before removing the
  detached annotation.

- **MAC address remains the same**: The `bootMACAddress` should remain unchanged
  even when the BMC is replaced, as it refers to the server's network interface,
  not the BMC.

## Related Documentation

- [Detaching Hosts from Provisioner](./detached_annotation.md) - Detailed
  information about the detached annotation

## References

- [PR #1549: Allow BMC address to be
  updated](https://github.com/metal3-io/baremetal-operator/pull/1549)
