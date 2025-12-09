# Remediation Controller and MachineHealthCheck

The Cluster API includes the
[remediation](https://cluster-api.sigs.k8s.io/tasks/automated-machine-management/healthchecking.html)
feature that implements an automated health checking of k8s nodes. It deletes
unhealthy Machine and replaces with a healthy one. This approach can be
challenging with cloud providers that are using hardware based clusters because
of slower (re)provisioning of unhealthy Machines. To overcome this situation,
CAPI remediation feature was extended to plug-in provider specific external
remediation. It is also possible to plug-in Metal3 specific remediation
strategies to remediate unhealthy nodes. In this case, the Cluster API MHC
finds unhealthy nodes while the CAPM3 Remediation Controller remediates those
unhealthy nodes.

## CAPI Remediation

A MachineHealthCheck is a Cluster API resource, which allows users to define
conditions under which Machines within a Cluster should be considered
unhealthy. Users can also specify a timeout for each of the conditions that
they define to check on the Machine's Node. If any of these conditions are met
for the duration of the timeout, the Machine will be remediated. CAPM3 will use
the MachineHealthCheck to create remediation requests based on
Metal3RemediationTemplate and Metal3Remediation CRDs to plug-in remediation
solution. For more info, please read the
[CAPI MHC](https://cluster-api.sigs.k8s.io/tasks/automated-machine-management/healthchecking.html)
link.

## External Remediation

External remediation provides remediation solutions other than deleting
unhealthy Machine and creating healthy one. Environments consisting of hardware
based clusters are slower to (re)provision unhealthy Machines. So there is a
growing need for a remediation flow that includes external remediation which
can significantly reduce the remediation process time. Normally the conditions
based remediation doesn't offer any other remediation than deleting an
unhealthy Machine and replacing it with a new one. Other environments and
vendors can also have specific remediation requirements, so there is a need to
provide a generic mechanism for implementing custom remediation logic. External
remediation integrates with CAPI MHC and support remediation based on power
cycling the underlying hardware. It supports the use of BMO reboot API and
CAPM3 unhealthy annotation as part of the automated remediation cycle. It is a
generic mechanism for supporting externally provided custom remediation
strategies. If no value for externalRemediationTemplate is defined for the
MachineHealthCheck CR, the condition-based flow is continued. For more info:
[External Remediation proposal](https://github.com/kubernetes-sigs/cluster-api/pull/3190/files)

## Metal3 Remediation

The CAPM3 remediation controller reconciles Metal3Remediation objects created
by CAPI MachineHealthCheck. It locates a Machine with the same name as the
Metal3Remediation object and uses BMO and CAPM3 APIs to remediate associated
unhealthy node. The remediation controller supports a reboot strategy specified
in the Metal3Remediation CRD and uses the same object to store states of the
current remediation cycle. The reboot strategy consists of three steps: power
off the Machine, apply a
[Out-of-Service Taint](https://kubernetes.io/docs/reference/labels-annotations-taints/#node-kubernetes-io-out-of-service)
on the related Node, and power the Machine on again. Applying the Out-of-Service
Taint is part of the (GA In Kubernetes 1.28)
[Non-Graceful node shutdown](https://kubernetes.io/docs/concepts/cluster-administration/node-shutdown/#non-graceful-node-shutdown)
handling which allows stateful workloads to restart on a different node.

### Enable remediation for worker nodes

Machines managed by a MachineSet (as identified by the `nodepool` label) can be
remediated. Here is an example MachineHealthCheck and Metal3Remediation for
worker nodes:

```yaml

apiVersion: cluster.x-k8s.io/v1beta1
kind: MachineHealthCheck
metadata:
  name: worker-healthcheck
  namespace: metal3
spec:
  # clusterName is required to associate this MachineHealthCheck with a particular cluster
  clusterName: test1
  # (Optional) maxUnhealthy prevents further remediation if the cluster is already partially unhealthy
  maxUnhealthy: 100%
  # (Optional) nodeStartupTimeout determines how long a MachineHealthCheck should wait for
  # a Node to join the cluster, before considering a Machine unhealthy.
  # Defaults to 10 minutes if not specified.
  # Set to 0 to disable the node startup timeout.
  # Disabling this timeout will prevent a Machine from being considered unhealthy when
  # the Node it created has not yet registered with the cluster. This can be useful when
  # Nodes take a long time to start up or when you only want condition based checks for
  # Machine health.
  nodeStartupTimeout: 0m
  # selector is used to determine which Machines should be health checked
  selector:
    matchLabels:
      nodepool: nodepool-0
  # Conditions to check on Nodes for matched Machines, if any condition is matched for the duration of its timeout, the Machine is considered unhealthy
  unhealthyConditions:
  - type: Ready
    status: Unknown
    timeout: 300s
  - type: Ready
    status: "False"
    timeout: 300s
  remediationTemplate: # added infrastructure reference
    kind: Metal3RemediationTemplate
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    name: worker-remediation-request

```

Metal3RemediationTemplate for worker nodes:

```yaml

apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3RemediationTemplate
metadata:
    name: worker-remediation-request
    namespace: metal3
spec:
  template:
    spec:
      strategy:
        type: "Reboot"
        retryLimit: 2
        timeout: 300s

```

### Enable remediation for control plane nodes

Machines managed by a KubeadmControlPlane are remediated according to the
[KubeadmControlPlane proposal](https://github.com/kubernetes-sigs/cluster-api/blob/main/docs/proposals/20191017-kubeadm-based-control-plane.md#remediation-using-delete-and-recreate).
It is necessary to have at least 2 control plane machines in order to use
remediation feature. Control plane nodes are identified by the
`cluster.x-k8s.io/control-plane` label. Here is an example MachineHealthCheck
and Metal3Remediation for control plane nodes:

```yaml

apiVersion: cluster.x-k8s.io/v1beta1
kind: MachineHealthCheck
metadata:
  name: controlplane-healthcheck
  namespace: metal3
spec:
  clusterName: test1
  maxUnhealthy: 100%
  nodeStartupTimeout: 0m
  selector:
    matchLabels:
      cluster.x-k8s.io/control-plane: ""
  unhealthyConditions:
    - type: Ready
      status: Unknown
      timeout: 300s
    - type: Ready
      status: "False"
      timeout: 300s
  remediationTemplate: # added infrastructure reference
    kind: Metal3RemediationTemplate
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    name: controlplane-remediation-request

```

Metal3RemediationTemplate for control plane nodes:

```yaml

apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3RemediationTemplate
metadata:
    name: controlplane-remediation-request
    namespace: metal3
spec:
  template:
    spec:
      strategy:
        type: "Reboot"
        retryLimit: 1
        timeout: 300s

```

## Limitations and caveats of Metal3 remediation

* Machines owned by a MachineSet or a KubeadmControlPlane can be remediated by
  a MachineHealthCheck

* If the Node for a Machine is removed from the cluster, CAPI MachineHealthCheck
  will consider this Machine unhealthy and remediates it immediately

* If there is no Node joins the cluster for a Machine after the
  `NodeStartupTimeout`, the Machine will be remediated

* If a Machine fails for any reason and the `FailureReason` is set, the Machine
  will be remediated immediately
