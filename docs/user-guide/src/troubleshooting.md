# Troubleshooting

## Verify that Ironic and Baremetal Operator are healthy

There is no point continuing before you have verified that the controllers are
healthy. A "standard" deployment will have Ironic and Baremetal Operator running
in the `baremetal-operator-system` namespace. Check that the containers are
running, not restarting or crashing:

```bash
kubectl -n baremetal-operator-system get pods
```

Note: If you deploy Ironic outside of Kubernetes you will need to check on it in
a different way.

Healthy example output:

```text
NAME                                                     READY   STATUS    RESTARTS       AGE
baremetal-operator-controller-manager-85b896f688-j27g5   1/1     Running   0              5m13s
ironic-6bcdcb99f8-6ldlz                                  3/3     Running   1 (2m2s ago)   5m15s
```

(There has been one restart, but it is not constantly restarting.)

Unhealthy example output:

```text
NAME                                                     READY   STATUS    RESTARTS      AGE
baremetal-operator-controller-manager-85b896f688-j27g5   1/1     Running   0             3m35s
ironic-6bcdcb99f8-6ldlz                                  1/3     Running   1 (24s ago)   3m37s
```

### Waiting for IP

Make sure to check the logs also since Ironic may be stuck on "waiting for IP".
For example:

```bash
kubectl -n baremetal-operator-system logs ironic-6bcdcb99f8-6ldlz -c ironic
```

If Ironic is waiting for IP, you need to check the network configuration.
Some things to look out for:

- What IP or interface is Ironic configured to use?
- Is Ironic using the host network?
- Is Ironic running on the expected (set of) Node(s)?
- Does the Node have the expected IP assigned?
- Are you using keepalived or similar to manage the IP, and is it working properly?

## Host is stuck in cleaning, how do I delete it?

First and foremost, avoid using forced deletion, otherwise you'll have [a
conflict](#mac-address-conflict-on-registration). If you don't care about disks
being [cleaned](automated_cleaning.md), you can edit the BareMetalHost resource
and disable cleaning:

```yaml
spec:
  automatedCleaningMode: disabled
```

Alternatively, you can wait for 3 cleaning retries to finish. After that, the
host will be deleted. If you do care about cleaning, you need to figure out why
it does not finish.

## MAC address conflict on registration

If you force deletion of a host after registration, Baremetal Operator will not
be able to delete the corresponding record from Ironic. If you try to enroll
the same host again, you will see the following error:

```text
Normal  RegistrationError  4m36s  metal3-baremetal-controller  MAC address 11:22:33:44:55:66 conflicts with existing node namespace~name
```

Currently, the only way to get rid of this error is to re-create the Ironic's
internal database. If your deployment uses SQLite (the default), it is enough
to restart the pod with Ironic. If you use MariaDB, you need to restart its
pod, clearing any persistent volumes.
