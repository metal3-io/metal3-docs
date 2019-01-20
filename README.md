# MetalKube Documentation

The MetalKube project exists to provide components that allow you to do bare
metal hardware management for Kubernetes.

A key element to the MetalKube project is providing bare metal hardware
management as a Kubernetes Application, which is an application that both runs
on Kubernetes and is managed through Kubernetes interfaces.

[Operators](https://github.com/operator-framework/operator-sdk) are a key piece
of the MetalKube architecture as the method used to manage kubernetes
applications.

## MetalKube Components

### Ironic Operator

* https://github.com/metalkube/ironic-operator

The Ironic Operator can be used to run a standalone instance of Ironic on
Kubernetes.  The management of the Ironic instance is done via CRDs.

This component can be used if your use case is to use the Ironic project to do
bare metal management, and you intend to write applications that interact with
the Ironic API directly.

### Machine API Integration

Another set of components is being designed and built to provide integration
with the Kubernetes [Machine
API](https://github.com/kubernetes-sigs/cluster-api).

Further details on this integration will be provided here as those components
are created.
