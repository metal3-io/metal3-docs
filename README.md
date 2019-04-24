# Metal³ Documentation

![Metal³ Logo](images/metal3.png)

The Metal³ project (pronounced: Metal Kubed) exists to provide components that
allow you to do bare metal host management for Kubernetes.  Metal³ works as a
Kubernetes application, meaning it runs on Kubernetes and is managed through
Kubernetes interfaces.

## Social Media

* [twitter.com/metal3_io](https://twitter.com/metal3_io)

## Project Discussion

* [Metal³ Development Mailing List](https://groups.google.com/forum/#!forum/metal3-dev)
* [#cluster-api-baremetal](https://kubernetes.slack.com/messages/CHD49TLE7) on Kubernetes Slack

## Metal³ Component Overview

### Machine API Integration

Another set of components is being designed and built to provide integration
with the Kubernetes [Machine
API](https://github.com/kubernetes-sigs/cluster-api).

This first diagram represents the high level architecture:

![High Level Architecture](images/high-level-arch.png)

#### Machine API Actuator

The first component is the [Bare Metal
Actuator](https://github.com/metal3-io/cluster-api-provider-baremetal), which
is an implementation of the Machine Actuator interface defined by the
cluster-api project.  This actuator reacts to changes to Machine objects and
acts as a client of the `BareMetalHost` custom resources managed by the Bare
Metal Operator.

#### Bare Metal Operator

The architecture also includes a new [Bare Metal
Operator](https://github.com/metal3-io/baremetal-operator), which includes the
following:

* A Controller for a new Custom Resource, `BareMetalHost`.  This custom resource
  represents an inventory of known (configured or automatically discovered)
  bare metal hosts.  When a Machine is created the Bare Metal Actuator will
  claim one of these hosts to be provisioned as a new Kubernetes node.
* In response to `BareMetalHost` updates, will perform bare metal host
  provisioning actions as necessary to reach the desired state.  It will do so
  by managing and driving a set of underlying bare metal provisioning
  components.
* The implementation will focus on using Ironic as its first implementation of
  the Bare Metal Management Pods, but aims to keep this as an implementation
  detail under the hood such that alternatives could be added in the future if
  the need arises.

The creation of the `BareMetalHost` inventory can be done in two ways:

1. Manually via creating `BareMetalHost` objects.
2. Optionally, automatically created via a bare metal host discovery process.
   Ironic is capable of doing this, which will also be integrated into
   Metal³ as an option.

For more information about Operators, see the
[operator-sdk](https://github.com/operator-framework/operator-sdk).

## APIs

1. Enroll nodes by creating `BareMetalHost` resources.  This would either be
   manually or done by a component doing node discovery and introspection.

   See the documentation in the
   [baremetal-operator](https://github.com/metal3-io/baremetal-operator/blob/master/docs/api.md) repository for details.

2. Use the machine API to allocate a machine.

```
apiVersion: "cluster.k8s.io/v1alpha1"
kind: Machine
metadata:
    generateName: baremetal-master-
    labels:
        set: master
spec:
    providerSpec:
        value:
            apiVersion: "baremetalproviderconfig/v1alpha1"
            kind: "BareMetalProviderConfig"
            selector:
                node-profile: master


apiVersion: "cluster.k8s.io/v1alpha1"
kind: Machine
metadata:
    generateName: baremetal-node-
    labels:
          set: node
spec:
    providerSpec:
        value:
            apiVersion: "baremetalproviderconfig/v1alpha1"
            kind: "BareMetalProviderConfig"
            selector:
                node-profile: node
```

3. Machine is associated with an available `BareMetalHost`, which triggers
   provisioning of that host to join the cluster.  This association is done by
   the Actuator when it sets the `MachineRef` field on the `BareMetalHost`.

## Design Documents

### Overall Architecture

- [nodes-machines-and-hosts](design/nodes-machines-and-hosts.md)
- [use-ironic](design/use-ironic.md)

### Implementation Details

- [bmc-address](design/bmc-address.md)
- [how-ironic-works](design/how-ironic-works.md)
- [image-ownership](design/image-ownership.md)
- [worker-config-drive](design/worker-config-drive.md)
