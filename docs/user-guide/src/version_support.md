# Supported release versions

The Cluster API Provider Metal3 (CAPM3) team maintains the following branches for CAPM3 for different API versions.

- CAPM3
    - main
        - v1beta1
    - release-0.5
        - v1alpha5

Currently, in Metal³ organization only CAPM3 and IPAM follow CAPI release cycles. The supported versions for CAPM3 and
IPAM releases are as follows:

- CAPM3
    - v1beta1
        - v1.1.1, v1.1.0
    - v1alpha5
        - v0.5.5, v0.5.4, v0.5.3, v0.5.2, v0.5.1, v0.5.0
- IPAM
    - v1alpha1
        - v1.1.2, v1.1.1, v1.1.0, v0.1.2, v0.1.1, v0.1.0

The compatability of IPAM and CAPM3 API versions with CAPI is discussed [here](https://github.com/metal3-io/ip-address-manager#compatibility-with-cluster-api).

Since BMO and Ironic do not follow similar release cycles they are backward compatible. However, we always tag the BMO and Ironic code base whenever we do a release in CAPM3. The tags have a prefix **capm3-** and the suffix is always the corresponding capm3- release version. So for example if we cut a `v1.0.0` release for CAPM3 we create a tag in the BMO and Ironic code base with `capm3-v1.0.0`. Following the same trend, the following tags for BMO and Ironic are available and supported (image tags):

- capm3-v1.1.1
- capm3-v1.1.0
- capm3-v0.5.5
- capm3-v0.5.4
- capm3-v0.5.3
- capm3-v0.5.2
- capm3-v0.5.1
- capm3-v0.5.0

## Supported Image tags

Supported container images for BMO and Ironic can be found in quay. Examples are:

- quay.io/metal3-io/ironic:capm3-v1.1.1
- quay.io/metal3-io/baremetal-operator:capm3-v1.1.1

Supported container images for CAPM3 and IPAM will always follow the supported release version tags. Examples are:

- quay.io/metal3-io/cluster-api-provider-metal3:v1.1.1
- quay.io/metal3-io/ip-address-manager:v1.1.2