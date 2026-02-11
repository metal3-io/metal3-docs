# Metal3MachineTemplate


The Metal3MachineTemplate contains following two specification fields:


- **nodeReuse**: (true/false) Whether the same pool of BareMetalHosts will be
  re-used during the upgrade/remediation operations. By default set to false, if
  set to true, CAPM3 Machine controller will pick the same pool of
  BareMetalHosts that were released while upgrading/remediation - for the next
  provisioning phase.
- **template**: is a template containing the data needed to create a
  Metal3Machine.


### Enabling nodeReuse feature


This feature can be desirable and enabled in scenarios such as upgrade or node
remediation. For example, the same pool of hosts need to be used after cluster
upgrade and no data of secondary storage should be lost. To achieve that:


1. `spec.nodeReuse` field of metal3MachineTemplate must be set to `True`. This
   tells that we want to reuse the same hosts after the upgrade, or to be exact
   same BareMetalHosts should be provisioned.


1. `spec.template.spec.automatedCleaningMode` field of metal3MachineTemplate
   must be set to `disabled`. This tells that we want secondary/hosted storage
   data to persist even after upgrade.


Above field changes need to be made before you start upgrading your cluster.


#### Node Reuse flow


When `spec.nodeReuse` field of metal3MachineTemplate is set to `True`, CAPM3
Machine controller:


- Sets `infrastructure.cluster.x-k8s.io/node-reuse` label to the
  corresponding CAPI object name (a `controlplane.cluster.x-k8s.io`
  object such as `KubeadmControlPlane` or a `MachineDeployment`) on the
  BareMetalHost during deprovisioning;
- Selects the BareMetalHost that contains
  `infrastructure.cluster.x-k8s.io/node-reuse` label and matches exact
  same CAPI object name set in the previous step during next
  provisioning.


Example Metal3MachineTemplate :


```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3MachineTemplate
metadata:
  name: m3mt-0
  namespace: metal3
spec:
  nodeReuse: false
  template:
    spec:
      automatedCleaningMode: metadata
      image:
        checksum: http://172.22.0.1/images/UBUNTU_22.04_NODE_IMAGE_K8S_v1.29.0-raw.img.sha256sum
        checksumType: sha256
        format: raw
        url: http://172.22.0.1/images/UBUNTU_22.04_NODE_IMAGE_K8S_v1.29.0-raw.img
      hostSelector:
        matchLabels:
          key1: value1
        matchExpressions:
          key: key2
          operator: in
          values: { ‘abc’, ‘123’, ‘value2’ }
      dataTemplate:
        Name: m3mt-0-metadata
```