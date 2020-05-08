# Custom Resource Reference

This document explains the relationship between all the Custom Resources (CRs)
required to create the target Kubernetes cluster on bare metal machine and how
they reference to each other. To see the example CRs check
[cluster-api-provider-baremetal](https://github.com/metal3-io/cluster-api-provider-baremetal/tree/release-0.2/examples)

## Environment Variables

The user is required to set the following environment variables before applying
the [CRs](https://github.com/metal3-io/metal3-dev-env/tree/master/crs)

```console
CLUSTER_NAME
IMAGE_CHECKSUM
IMAGE_URL
KUBERNETES_VERSION
SSH_PUB_KEY_CONTENT

```

### Cluster and Machine

#### CAPI v1alpha2

This diagram describes object's relationship based on CAPI v1alpha2 and how
they reference to each other.
![crs](images/v1a2_crs.svg)
