# Metal3Cluster

The metal3Cluster object contains information related to the deployment of the
cluster on Baremetal. It currently has two specification fields :

- **controlPlaneEndpoint**: contains the target cluster API server address and
  port
- **noCloudProvider(Deprecated use CloudProviderEnabled)**: (true/false) Whether
  the cluster will not be deployed with an external cloud provider. If set to
  true, CAPM3 will patch the target cluster node objects to add a providerID.
  This will allow the CAPI process to continue even if the cluster is deployed
  without cloud provider.
- **CloudProviderEnabled**: (true/false) Whether the cluster will be deployed
  with an external cloud provider. If set to false, CAPM3 will patch the target
  cluster node objects to add a providerID. This will allow the CAPI process to
  continue even if the cluster is deployed without cloud provider.

Example metal3cluster :

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3Cluster
metadata:
  name: m3cluster
  namespace: metal3
spec:
  controlPlaneEndpoint:
    host: 192.168.111.249
    port: 6443
  cloudProviderEnabled: false
```