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
being [cleaned](bmo/automated_cleaning.md), you can edit the BareMetalHost resource
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

## Power requests are issued for deleted hosts

Similarly to the previous question, a host is not deleted from Ironic in case
of a forced deletion of its BareMetalHost object. If valid BMC credentials were
provided, Ironic will keep checking the power state of the host and enforcing
the last requested power state. The only solution is again to delete the
Ironic's internal database.

## BMH registration errors

BMC credentials may be incorrect or missing. These issues appear in the
BareMetalHost’s status and in Events.

Check both `kubectl describe bmh <name>` and recent Events for details.

Example output:

```text
Normal  RegistrationError  23s   metal3-baremetal-controller  Failed to get 
power state for node 67ac51af-a6b3. Error: Redfish exception occurred. 
Error: HTTP GET https://192.168.111.1:8000/redfish/v1/Systems/... returned code 401.
```

## BMH inspection errors

### The host is not able to communicate back results to Ironic

If the host cannot communicate with Ironic, it will result in a timeout.
Accessing serial logs is necessary to determine the exact issue.

Example output from `kubectl get bmh -A`:

```text
NAMESPACE   NAME     STATE        CONSUMER   ONLINE   ERROR              AGE
metal3      node-1   inspecting             true     inspection error   46m
```

BareMetalHost's events from `kubectl describe bmh <name> -n <namespace>`:

```text
Events:
  Type    Reason              Age    From                         Message
  ----    ------              ----   ----                         -------
  Normal  InspectionStarted   37m    metal3-baremetal-controller  Hardware inspection started
  Normal  InspectionError     7m12s  metal3-baremetal-controller  timeout reached while inspecting the node
```

### Error setting boot mode

Example `kubectl get bmh -A`:

```text
NAMESPACE   NAME     STATE        CONSUMER   ONLINE   ERROR              AGE
metal3      node-1   inspecting              true     inspection error   8m17s
```

BareMetalHost's events:

```text
Normal  InspectionError     5s     metal3-baremetal-controller  Failed to inspect hardware. Reason: unable to start inspection:
Redfish exception occurred. Error: Setting boot mode to bios failed for node ceec28f5-cedb.rror: HTTP PATCH 
https://192.168.111.1:8000/redfish/v1/Systems/... returned code 500.
```

There are two possible causes:

- Hardware does not support the requested boot mode. Really old machines may
  not support UEFI, while really new machines gradually start phasing out
  legacy boot.
- Hardware does not support switching between boot modes using Redfish API.
  This is the case for some iLO 5 machines.

You have options:

- Log into the BMC's UI and change the boot mode to the preferred value.
- Update your BareMetalHost definition with the `bootMode` value that matches
  what your hardware supports.

## Provisioning errors

Errors during provisioning will be visible when listing the BareMetalHosts:

```text
NAMESPACE   NAME     STATE          CONSUMER      ONLINE   ERROR                AGE
metal3      node-1   provisioning   test1-dt8j2   true     provisioning error   149m
```

Check BareMetalHost's events for the specific reason.

Wrong image checksum example:

```text
Normal  ProvisioningError   10m    metal3-baremetal-controller  Image provisioning failed: Deploy
step deploy.write_image failed on node df880558-09da. Image failed to verify against checksum.
location: CENTOS_9_NODE_IMAGE.img; image ID: /dev/sda; image checksum: abcd1234; verification checksum: ...
```

No root device found example:

```text
Normal  ProvisioningStarted  15s    metal3-baremetal-controller  Image provisioning started for http://172.22.0.1/images/CENTOS_9_NODE_IMAGE.img
Normal  ProvisioningError    1s     metal3-baremetal-controller  Image provisioning failed: Deploy step deploy.write_image failed on node d25ce8de-914e-4146-a0c0-58825274572d. No suitable device was found for deployment using these hints {'name': 's== /dev/vdb'}
```

## No BareMetalHost available or matching

This appears in the Metal3Machine status:

```text
Status:
  Conditions:
    Last Transition Time:  2025-08-15T10:53:05Z
    Message:               No available host found. Requeuing.. Object will be requeued after 30s
    Reason:                AssociateBMHFailed
    Severity:              Error
    Status:                False
    Type:                  AssociateBMH
```

CAPM3 controller logs when there is no available hosts:

```text
I0815 11:10:35.699004   1 metal3machine_manager.go:332] "No available host found. Requeuing." logger="controllers.Metal3Machine.Metal3Machine-controller" metal3-machine="metal3/test-no-match-2" machine="test-no-match-2" cluster="test1" metal3-cluster="test1"
```

CAPM3 controller logs when the annotated host is not found:

```text
I0815 06:08:54.687380   1 metal3machine_manager.go:788] "Annotated host not found" logger="controllers.Metal3Machine.Metal3Machine-controller" metal3-machine="metal3/test1-zxzn7-qvl6n" machine="test1-zxzn7-qvl6n" cluster="test1" metal3-cluster="test1" host="metal3/node-0"
```

## Provider ID is missing

This occurs if `cloudProviderEnabled` is set to `true` on Metal3Cluster when no
external cloud provider is used. The Metal3Machine will remain stuck in the
Provisioning phase.

Example output from `kubectl get metal3machine -A`:

```text
NAMESPACE   NAME                AGE    PROVIDERID                           READY   CLUSTER   PHASE
metal3      test1-82ljr         160m   metal3://metal3/node-0/test1-82ljr   true    test1     
metal3      test1-bv9mv-2f8th   35m                                                 test1
```

Metal3Machine's status:

```text
Status:
  Conditions:
    Reason:   NotReady
    Status:   False
    Type:     Available
    Message:  * NodeHealthy: Waiting for Metal3Machine to report spec.providerID
```

## `nodeRef` missing

A CAPI-level issue. This can be caused by a failure to boot the image or join it
to the cluster. Access to the node or serial logs is needed to determine the
exact cause. In particular, cloud-init logs can help pinpoint the issue.

CAPM3 controller logs:

```text
I0815 11:10:36.545990   1 metal3labelsync_controller.go:150] "Could not find Node Ref on Machine object, will retry" logger="controllers.Metal3LabelSync.metal3-label-sync-controller" metal3-label-sync="metal3/node-0"
```
