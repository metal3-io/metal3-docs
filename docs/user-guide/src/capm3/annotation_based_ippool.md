# Annotation-based IPPool Reference

The `fromPoolAnnotation` field of a `Metal3DataTemplate` enables dynamic
IPPool name resolution from annotations on BareMetalHost, Machine, or
Metal3Machine objects. This allows flexible IPPool assignment
based on deployment-time decisions rather than static
template configuration.

## Use Cases

The `fromPoolAnnotation` field can be used in both IPv4 and IPv6 network
configurations:

- Network configuration to specify which IPPool to use for IP address allocation
- Gateway configuration to specify which IPPool to use for gateway IP resolution
- Route gateway configuration to specify which IPPool to use for route gateway
  IP resolution

## Field Specification

The `fromPoolAnnotation` field contains:

- **object**: The object type to read the annotation from (`baremetalhost`,
  `machine`, `metal3machine`)
- **annotation**: The annotation key containing the IPPool name

> **Note:** When `fromPoolAnnotation` is set, `fromIPPool` and `fromPoolRef`
> fields are ignored. The annotation-based reference takes priority.
>
> If you don't need dynamic IPPool resolution, use `fromIPPool` (reference by
> name in same namespace) or `fromPoolRef` (reference by name, namespace, and
> API group) for static IPPool assignment in your Metal3DataTemplate.

## Example

Example `IPPool` that will be referenced by the annotation:

```yaml
apiVersion: ipam.metal3.io/v1alpha1
kind: IPPool
metadata:
  name: provisioning-pool-zone-a
  namespace: metal3
spec:
  clusterName: my-cluster
  gateway: 172.22.0.1
  namePrefix: my-cluster-prov
  pools:
  - start: 172.22.0.100
    end: 172.22.0.200
  prefix: 24
```

Example `Metal3DataTemplate` using annotation-based IPPool reference:

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
kind: Metal3DataTemplate
metadata:
  name: nodepool-1
spec:
  networkData:
    networks:
      ipv4:
      - id: "provisioning"
        link: "vlan2"
        fromPoolAnnotation:
          object: baremetalhost
          annotation: ippool.metal3.io/provisioning
        routes:
        - network: "0.0.0.0"
          prefix: 0
          gateway:
            fromPoolAnnotation:
              object: baremetalhost
              annotation: ippool.metal3.io/provisioning
```

The corresponding BareMetalHost with the IPPool annotation:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: worker-1
  annotations:
    ippool.metal3.io/provisioning: "provisioning-pool-zone-a"
spec:
  online: true
```

When the template is rendered, CAPM3 reads the annotation value
`provisioning-pool-zone-a` from the BareMetalHost and uses it as the IPPool
name for IP address allocation.

> **Note:** If the annotation does not exist on the referenced object, the
> IPPool name is rendered as an empty string and the IP address allocation
> will fail.
