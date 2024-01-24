# Node Reuse

This feature brings a possibility of re-using the same BaremetalHosts (referred to as a host later)
during deprovisioning and provisioning mainly as a part of the rolling upgrade process in the cluster.

## Importance of scale-in strategy

The logic behind the reusing of the hosts, solely relies on the **scale-in** upgrade strategy utilized by
Cluster API objects, namely [KubeadmControlPlane](https://github.com/kubernetes-sigs/cluster-api/blob/main/docs/proposals/20191017-kubeadm-based-control-plane.md#rolling-update-strategy) and MachineDeployment.
During the upgrade process of above resources, the machines owned by KubeadmControlPlane or MachineDeployment are
removed one-by-one before creating new ones (delete-create method).
That way, we can fully ensure that, the intended host is reused when the upgrade is kicked in (picked up on the following provisioning for the new machine being created).

**Note:** To achieve the desired *delete first and create after* behavior in above-mentioned Cluster API objects,
user has to modify:

* MaxSurge field in KubeadmControlPlane and set it to 0 with minimum number of 3 control plane machines replicas
* MaxSurge and MaxUnavailable fields in MachineDeployment set them to 0 & 1 accordingly

On the contrary, if the scale-out strategy is utilized by CAPI objects during the upgrade, usually create-swap-delete
method is followed by CAPI objects, where new machine is created first and new host is picked up for that
machine, breaking the node reuse logic right at the beginning of the upgrade process.

## Workflow

Metal3MachineTemplate (M3MT) Custom Resource is the object responsible for enabling of the node reuse feature.

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3MachineTemplate
metadata:
  name: test1-controlplane
  namespace: metal3
spec:
  nodeReuse: True
  template:
    spec:
      image:
      ...
```

There could be two Metal3MachineTemplate objects, one referenced by KubeadmControlPlane for control plane nodes, and the other by MachineDeployment for worker node. Before performing an upgrade, user must set `nodeReuse` field to **true** in the desired Metal3MachineTemplate object where hosts targeted to be reused. If left unchanged, by default, `nodeReuse` field is set to **false** resulting in no host reusing being performed in the workflow. If you would like to know more about the internals of controller logic, please check the original proposal for the feature [here](https://github.com/metal3-io/metal3-docs/blob/main/design/cluster-api-provider-metal3/node_reuse.md)

Once `nodeReuse` field is set to **true**, user has to make sure that scale-in feature is enabled as suggested above, and proceed with updating the desired fields in KubeadmControlPlane or MachineDeployment to start a rolling upgrade.

**Note:** If you are creating a new Metal3MachineTemplate object (for control-plane or worker), rather than using the existing one
created while provisioning, please make sure to reference it from the corresponding Cluster API object (KubeadmControlPlane or MachineDeployment). Also keep in mind that, already provisioned Metal3Machines were created from the old Metal3MachineTemplate
and they consume existing hosts, meaning even though `nodeReuse` field is set to **true** in the new Metal3MachineTemplate,
it would have no effect. To use newly Metal3MachineTemplate in the workflow, user has to reprovision the nodes, which
should result in using new Metal3MachineTemplate referenced in Cluster API object and Metal3Machine created out of it.
