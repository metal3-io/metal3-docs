# Remove a Host from a Cluster

At some point you will need to remove a host from a cluster. You may be
removing failed hardware, downsizing a healthy cluster, or have some other
reason.

Since removal involves a BareMetalHost, Machine, and MachineSet, it can be
non-obvious how best to accomplish host removal. This document provides
guidance on how to do so.

## Steps

These steps are both safe and compatible with automation that scales
MachineSets to match the number of BareMetalHosts.

### Annotate the Machine

Find the Machine that corresponds to the BareMetalHost that you want to remove.
Add the annotation `cluster.k8s.io/delete-machine` with any value that is not
an empty string.

This ensures that when you later scale down the MachineSet, this Machine is the
one that will be removed.

### Delete the BareMetalHost

Delete the BareMetalHost resource. This may take some time.

### Scale down MachineSet

Find the corresponding MachineSet and scale it down to the correct level. This
will cause the host's Machine to be deleted.

## Other Approaches

### Delete the Machine First

If you delete the Machine first, that will cause the BareMetalHost to
be deprovisioned. You would still need to issue a subsequent delete of the
BareMetalHost. That opens the possibility that for some period of time, the
BareMetalHost could be fully deprovisioned and show as "available";
another Machine without a host could claim it before it gets deleted.

Additionally, by deleting the Machine before scaling down the MachineSet, the
MachineSet will try to replace it with a new Machine resource. That new
resourse could match a BareMetalHost if one is available and cause it to start
provisioning. For this reason, it is better to not directly delete a Machine.

### Scale down the MachineSet

You could annotate the Machine and then directly scale down the MachineSet
without first deleting the BareMetalHost. This will cause the Machine to be
deleted, but then the same downsides apply as described above; the
BareMetalHost could be in an "available" state for some period of time.
