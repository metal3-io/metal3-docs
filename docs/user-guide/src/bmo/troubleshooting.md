# Troubleshooting FAQ

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

If you force deletion of a host after registration, BareMetal Operator will not
be able to delete the corresponding record from Ironic. If you try to enroll
the same host again, you will see the following error:

```text
Normal  RegistrationError  4m36s  metal3-baremetal-controller  MAC address 11:22:33:44:55:66 conflicts with existing node namespace~name
```

Currently, the only way to get rid of this error is to re-create the Ironic's
internal database. If your deployment uses SQLite (the default), it is enough
to restart the pod with Ironic. If you use MariaDB, you need to restart its
pod, clearing any persistent volumes.
