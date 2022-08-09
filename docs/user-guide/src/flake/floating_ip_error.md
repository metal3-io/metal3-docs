# CI infrastructure provider unable to attach floating IP

The IAAS provider used by the Metal3 community provides an Openstack based
cloud solution that is mainly used by the community to provide virtual machines (VMs).
There are 2 distinct regions (both geographic and logical) of the IAAS used by the Metal3
project and in one of the regions (Fra1) the CI needs to attach "floating IPs" to the
VMs in order to be usable.

The issue in question was present for at least a day and it was blocking the
attachment of "floating IPs" to the newly created VMs thus all the CI jobs that were reliant on
the Fra1 region were failing instantly even before the actual CI workload had a chance to run.

Error example:

```text
Running in region: Fra1
The option [tenant_id] has been deprecated. Please avoid using it.
Deleting executer floating IP 7629e843-9e4f-4234-a8f8-053058f850e9.
The option [tenant_id] has been deprecated. Please avoid using it.
Executer floating IP 7629e843-9e4f-4234-a8f8-053058f850e9 is deleted.
usage: openstack floating ip delete [-h] <floating-ip> [<floating-ip> ...]
openstack floating ip delete: error: the following arguments are required: <floating-ip>

Deleting executer VM ci-test-vm-20220720203103-nldz.
Executer VM ci-test-vm-20220720203103-nldz is deleted.
Deleting executer VM port ci-test-vm-20220720203103-nldz-int-port.
The option [tenant_id] has been deprecated. Please avoid using it.
Executer VM port ci-test-vm-20220720203103-nldz-int-port is deleted.
```

## Occurence and logs

- 20.07-2022 - No logs were possible to collect as the VM was terminated prematurely.
