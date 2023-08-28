# Supported release versions

The Cluster API Provider Metal3 (CAPM3) team maintains the two most recent minor releases; older minor releases are immediately unsupported when a new major/minor release is available.
Test coverage will be maintained for all supported minor releases and for one additional release for the current API version in case we have to do an emergency patch release.
For example, if v1.3 and v1.4 are currently supported, we will also maintain test coverage for v1.2 for one additional release cycle.
When v1.5 is released, tests for v1.1 will be removed.

Currently, in Metal³ organization only CAPM3 and IPAM follow CAPI release cycles.
The supported versions (excluding release candidates) for CAPM3 and IPAM releases are as follows:

Cluster API Provider Metal3

| Minor release | API version | Status    |
| ------------- | ----------- | --------- |
| v1.5          | v1beta1     | Supported |
| v1.4          | v1beta1     | Supported |
| v1.3          | v1beta1     | Tested    |
| v1.2          | v1beta1     | EOL       |
| v1.1          | v1beta1     | EOL       |

IP Address Manager

| Minor release | API version | Status    |
| ------------- | ----------- | --------- |
| v1.5          | v1beta1     | Supported |
| v1.4          | v1beta1     | Supported |
| v1.3          | v1beta1     | Tested    |
| v1.2          | v1alpha1    | EOL       |
| v1.1          | v1alpha1    | EOL       |

The compatability of IPAM and CAPM3 API versions with CAPI is discussed [here](https://github.com/metal3-io/ip-address-manager#compatibility-with-cluster-api).

## Baremetal Operator

Since `capm3-v1.1.2`, BMO follows the semantic versioning scheme for its own release cycle, the same way as CAPM3 and IPAM. At the moment, we always cut rolling releases from the main branch of BMO and tag them with the release version (i.e: `v0.x.y`).

Please note that there are currently no release branches for BMO and no support for older releases.

| Minor release | Status    |
| ------------- | --------- |
| v0.4          | Supported |
| v0.3          | Tested    |
| v0.2          | Tested    |
| v0.1          | EOL       |

## Image tags

The Metal³ team provides container images for all the main projects and also many auxilary tools needed for tests or otherwise useful.
Some of these images are tagged in a way that makes it easy to identify what version of Cluster API provider Metal³ they are tested with.
For example, we tag Ironic and MariaDB container images with tags like `capm3-v1.4.0`, where `v1.4.0` would be the CAPM3 release it was tested with.
Prior to CAPM3 release v1.1.3 this also applied to the Baremetal Operator.

All container images are published through the [Metal³ organization in Quay](https://quay.io/organization/metal3-io).
Here are some examples:

- quay.io/metal3-io/cluster-api-provider-metal3:v1.4.0
- quay.io/metal3-io/baremetal-operator:v0.3.0
- quay.io/metal3-io/ip-address-manager:v1.4.0
- quay.io/metal3-io/ironic:capm3-v1.4.0
- quay.io/metal3-io/mariadb:capm3-v1.4.0

## CI Test Matrix

The table describes which branches/image-tags are tested in each periodic CI tests:

| INTEGRATION TESTS                                | CAPM3 branch | IPAM branch | BMO branch/tag | Keepalived tag | MariaDB tag | Ironic tag |
| ------------------------------------------------ | ------------ | ----------- | -------------- | -------------- | ----------- | ---------- |
| daily_main_integration_test_ubuntu/centos        | main         | main        | main           | latest         | latest      | latest     |
| daily_main_e2e_integration_test_ubuntu/centos    | main         | main        | main           | latest         | latest      | latest     |
| daily_release-1-5_integration_test_ubuntu/centos | release-1.5  | release-1.5 | v0.4.0         | v0.4.0         | latest      | latest     |
| daily_release-1-4_integration_test_ubuntu/centos | release-1.4  | release-1.4 | v0.3.0         | v0.3.0         | latest      | latest     |
| daily_release-1-3_integration_test_ubuntu/centos | release-1.3  | release-1.3 | v0.2.0         | v0.2.0         | latest      | latest     |

| FEATURE AND E2E TESTS                            | CAPM3 branch | IPAM branch | BMO branch/tag | Keepalived tag | MariaDB tag | Ironic tag |
| ------------------------------------------------ | ------------ | ----------- | -------------- | -------------- | ----------- | ---------- |
| daily_main_e2e_feature_test_ubuntu/centos        | main         | main        | main           | latest         | latest      | latest     |
| daily_release-1-5_e2e_feature_test_ubuntu/centos | release-1.5  | release-1.5 | v0.4.0         | v0.4.0         | latest      | latest     |
| daily_release-1-4_e2e_feature_test_ubuntu/centos | release-1.4  | release-1.4 | v0.3.0         | v0.3.0         | latest      | latest     |
| daily_release-1-3_e2e_feature_test_ubuntu/centos | release-1.3  | release-1.3 | v0.2.0         | v0.2.0         | latest      | latest     |
| daily_main_feature_tests_ubuntu/centos           | main         | main        | main           | latest         | latest      | latest     |

| EPHEMERAL TESTS                      | CAPM3 branch | IPAM branch | BMO branch/tag | Keepalived tag | MariaDB tag | Ironic tag |
| ------------------------------------ | ------------ | ----------- | -------------- | -------------- | ----------- | ---------- |
| daily_main_e2e_ephemeral_test_centos | main         | main        | main           | latest         | latest      | latest     |

All tests use latest images of VBMC and sushy-tools.
