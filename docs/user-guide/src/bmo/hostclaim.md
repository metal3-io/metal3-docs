# Multi Tenancy with Hostclaim

The goal of the `Hostclaim` resource is to establish a clear separation between
the management of compute resources (involving the access to sensitive data like BMC credentials)
and the usage of these resources by customer (or tenant).

It enforces the servers access security when computer resources are used in multi-tenant environment.

The `Hostclaim` custom resource expresses the client need for a compute resource.
This need is specified by:

- an OS image used for provisioning the compute resource
- an initial configuration (typically cloud-init or ignition configuration files)
  associated with this image
- a set of requirements (labels) that the compute resource should meet

In particular, the Hostclaim resources do not contain any information (url or credentials)
to access the BMC of the servers.

The Hostclaim resources and the BareMetalHost resources are hosted in separate namespaces,
and the association between a Hostclaim resource and a BareMetalHost resource is managed
by the Baremetal Operator controller.

From the server management side, the authorized association between BareMetalHost
and Hostclaim resources are managed with the `HostDeployPolicy` custom resource.

This HostDeployPolicy resource is created in the namespace of the BareMetalHost.
It specifies the constraints the Hostclaim namespace should satisfy
in order for the Hostclaim to be associated with one of these BareMetalHost resources.

For more details on Hostclaim, please check the
[Hostclaim proposal](https://github.com/metal3-io/metal3-docs/blob/main/design/hostclaim-multitenancy.md).

## How to use Hostclaim

We assume that a set of BareMetalHost resources (named for example `bm-01`and `bm-02`)
already exists in the namespace `infrahost`
and these resources contain a label `infra-kind` that will be used
for the Hostclaim association process.

### HostDeployPolicy

In the `infrahost` namespace, a HostDeployPolicy resource is created
with this minimum content:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostDeployPolicy
metadata:
  name: policy
  namespace: infrahost
spec:
  hostclaimNamespaces: {}
```

This HostDeployPolicy resource allows the association between the BareMetalHost and Hostclaim
without constraint on the Hostclaim namespace.

For more details on HostDeployPolicy configuration, please check [Server Administrator Point of View](https://github.com/metal3-io/metal3-docs/blob/main/design/hostclaim-multitenancy.md#server-administrator-point-of-view) in the Hostclaim proposal.

### Provisioning

To start the provisioning process with Hostclaim, we create a Hostclaim resource
in a dedicated namespace `cluster-ns` with this minimal content:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostClaim
metadata:
  name: my-hostclaim
  namespace: cluster-ns
spec:
  hostSelector:
    matchLabels:
      infra-kind: medium
  image:
    checksum: http://172.18.0.1:8080/images/jammy/img.md5
    format: qcow2
    url: http://172.18.0.1:8080/images/jammy/img.qcow2
  online: false
  userData:
    name: my-userdata
    namespace: cluster-ns
```

This resource specifies a compute resource with an ``image``
and a configuration stored in the ``userData`` secret.

A ``networkData`` field with a reference to a secret containing
a network configuration can also be used in the Hostclaim spec
(same semantic as in the BareMetalHost resource).

The ``hostSelector`` field specifies the constraints on the labels of the BareMetalHost
to be associated with this Hostclaim resource.

Once the association is done, the Hostclaim status contains these information:

```yaml
status:
  conditions:
    - lastTransitionTime: "xxx-xx-xxTxx:xx:xx"
      message: '* Provisioned: available'
      observedGeneration: 1
      reason: IssuesReported
      status: "False"
      type: Ready
    - lastTransitionTime: "xxx-xx-xxTxx:xx:xx"
      message: ""
      observedGeneration: 1
      reason: BareMetalHostAssociated
      status: "True"
      type: Association
    - lastTransitionTime: "xxx-xx-xxTxx:xx:xx"
      message: ""
      observedGeneration: 1
      reason: available
      status: "False"
      type: Provisioned
    - lastTransitionTime: "xxx-xx-xxTxx:xx:xx"
      message: ""
      observedGeneration: 1
      reason: ConfigurationSynced
      status: "True"
      type: Synchronization
  hardwareData:
    name: bm-01
    namespace: infrahost
```

Note the condition ``Association`` is set at ̀`true`
and the name/namespace of the associated BareMetalHost is stored in the ``hardwareData`` field.

The `my-userdata` secret references in the Hostclaim resource is copied in the `infrahost` namespace
of the BareMetalHost resources with the name `bm-01-userdata` (as the Hostclaim
is associated here with the BareMetalHost `bm-01`).

During the provisioning process, if the want to use `metadata` specialized for the associated server,
we can create a secret containing this metadata in the `cluster-ns` namespace and update the Hostclaim resource
in consequence:

```shell
kubectl create secret generic -n cluster-ns my-metadata --from-file=metaData=<metadata.txt>

kubectl patch hostclaim -n cluster-ns my-hostclaim --type=merge -p '{"spec": {"metaData": {"name": "my-metadata", "namespace": "cluster-ns"}}}'
```

As for the `userdata` secret, the `my-metadata` secret is copied in the `infrahost` namespace
of the BareMetalHost resources with the name `bm-01-metadata`.

The provisioning process is launched when the value ``.spec.online`` is set to ``true`` in the Hostclaim resource.

```shell
kubectl patch hostclaim  -n cluster-ns my-hostclaim --type=merge -p '{"spec": {"online": true}}'
```

Once the server is provisioned, the Hostclaim status contains these information:

```yaml
status:
  conditions:
    - lastTransitionTime: "xxx-xx-xxTxx:xx:xx"
      message: ""
      observedGeneration: 3
      reason: InfoReported
      status: "True"
      type: Ready
    - lastTransitionTime: "xxx-xx-xxTxx:xx:xx"
      message: ""
      observedGeneration: 3
      reason: BareMetalHostAssociated
      status: "True"
      type: Association
    - lastTransitionTime: "xxx-xx-xxTxx:xx:xx"
      message: ""
      observedGeneration: 3
      reason: provisioned
      status: "True"
      type: Provisioned
    - lastTransitionTime: "xxx-xx-xxTxx:xx:xx"
      message: ""
      observedGeneration: 3
      reason: ConfigurationSynced
      status: "True"
      type: Synchronization
  hardwareData:
    name: bm-01
    namespace: infrahost
  hostUID: 6675cc9f-3c19-476d-8a8e-757e58d93d65
  poweredOn: true

```

Note the condition with type ``Provisioned`` in the status is at `True`.

The server can be stopped by changing the ``online`` field in the spec to `false`.

And a reboot of the server can be launched by adding a ``reboot.metal3.io`` annotation on the HostClaim.

### Deprovisioning

There are two options to deprovision a server associated with a Hostclaim:

- remove the ``.spec.image`` field in the Hostclaim resource

  When the ``.spec.image`` field in the Hostclaim resource is removed,
  the associated BareMetalHost resource is deprovisioned.

  At the end of the deprovisioning process, the BareMetalHost resource is in ``available`` state.
  The Hostclaim resource is still associated with this BareMetalHost.

- delete the Hostclaim resource

  When the Hostclaim resource (associated with a BareMetalHost resource) is deleted,
  the server is deprovisioned and the association between the Hostclaim
  and the BareMetalHost resources is broken.

  After deprovisioning, this BareMetalHost becomes available for association with another Hostclaim.
