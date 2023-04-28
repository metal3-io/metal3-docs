# Supported release versions

The Cluster API Provider Metal3 (CAPM3) team maintains the following branches for CAPM3 for different API versions.

- CAPM3
   - main
      - v1beta1
   - release-1.4
      - v1beta1
   - release-1.3
      - v1beta1
   - release-1.2
      - v1beta1
   - release-1.1
      - v1beta1

Currently, in Metal³ organization only CAPM3 and IPAM follow CAPI release cycles. The supported versions (excluding release candidates) for CAPM3 and IPAM releases are as follows:

- CAPM3
   - v1beta1
      - v1.4.0, v1.3.2, v1.3.1, v1.3.0, v1.2.2, v1.2.1, v1.2.0, v1.1.4, v1.1.3, v1.1.2, v1.1.1, v1.1.0
- IPAM
   - v1beta1
      - v1.4.0, v1.3.1, v1.3.0
   - v1alpha1
      - v1.2.2, v1.2.1, v1.2.0, v1.1.4, v1.1.3, v1.1.2, v1.1.1, v1.1.0

The compatability of IPAM and CAPM3 API versions with CAPI is discussed [here](https://github.com/metal3-io/ip-address-manager#compatibility-with-cluster-api).

Since BMO and Ironic do not follow similar release cycles they are (mostly) backward compatible. However, we used to tag the BMO and Ironic code base whenever we do a release in CAPM3 prior to CAPM3 release `v1.1.3`. The tags used to have a prefix **capm3-** and the suffix was always the corresponding capm3- release version. So for example, if we cut a `v1.0.0` release for CAPM3 we created a tag in the BMO and Ironic code base with `capm3-v1.0.0`. Please note, currently that is applicable only for Ironic starting from CAPM3 release `v1.1.3` and onwards.

Following the same trend, the following tags for Ironic and MariaDB are available and supported (image tags):

- capm3-v1.4.0
- capm3-v1.3.2
- capm3-v1.2.2
- capm3-v1.1.4

Since `capm3-v1.1.2`, BMO follows the semantic versioning scheme for its own release cycle, the same way as CAPM3 and IPAM. At the moment, we always cut rolling releases from the main branch of BMO and tag them with the release version (i.e: `v0.x.y`).

Here are available and supported BMO image tags:

- v0.3.0
- v0.2.0
- v0.1.2
- v0.1.1

## Supported Image tags

Supported container images for BMO and Ironic can be found in quay. Examples are:

- quay.io/metal3-io/baremetal-operator:v0.3.0
- quay.io/metal3-io/ironic:capm3-v1.4.0
- quay.io/metal3-io/mariadb:capm3-v1.4.0

Supported container images for CAPM3 and IPAM will always follow the supported release version tags and can be found in quay. Examples are:

- quay.io/metal3-io/cluster-api-provider-metal3:v1.4.0
- quay.io/metal3-io/ip-address-manager:v1.4.0

## CI Test Matrix

The table describes which branches/image-tags are tested in each periodic CI tests:

| INTEGRATION TESTS                                    | CAPM3 branch | IPAM branch  | BMO branch/tag  | Keepalived tag | MariaDB tag | Ironic tag |
| ------                                               | ------------ | -----------  | --------------- | -------------- | ------- | ------ |
| daily_main_integration_test_ubuntu/centos            | main         | main         | main            | latest         | latest  | latest |
| daily_main_e2e_integration_test_ubuntu/centos        | main         | main         | main            | latest         | latest  | latest |
| daily_release-1-4_integration_test_ubuntu/centos     | release-1.4  | release-1.4  | v0.3.0          | v0.3.0         | latest  | latest |
| daily_release-1-3_integration_test_ubuntu/centos     | release-1.3  | release-1.3  | v0.2.0          | v0.2.0         | latest  | latest |
| daily_release-1-2_integration_test_ubuntu/centos     | release-1.2  | release-1.2  | v0.1.2          | v0.1.2         | latest  | latest |
| daily_release-1-1_integration_test_ubuntu/centos     | release-1.1  | release-1.1  | v0.1.1          | v0.1.1         | latest  | latest |

| FEATURE AND E2E TESTS                                    | CAPM3 branch | IPAM branch  | BMO branch/tag  | Keepalived tag | MariaDB tag | Ironic tag |
| ------                                               | ------------ | -----------  | --------------- | -------------- | ------- | ------ |
| daily_main_e2e_feature_test_ubuntu/centos            | main         | main         | main            | latest         | latest  | latest |
| daily_release-1-4_e2e_feature_test_ubuntu/centos     | release-1.4  | release-1.4  | v0.3.0          | v0.3.0         | latest  | latest |
| daily_release-1-3_e2e_feature_test_ubuntu/centos     | release-1.3  | release-1.3  | v0.2.0          | v0.2.0         | latest  | latest |
| daily_release-1-2_e2e_feature_test_ubuntu/centos     | release-1.2  | release-1.2  | v0.1.2          | v0.1.2         | latest  | latest |
| daily_release-1-1_e2e_feature_test_ubuntu/centos     | release-1.1  | release-1.1  | v0.1.1          | v0.1.1         | latest  | latest |
| daily_main_feature_tests_ubuntu/centos               | main         | main         | main            | latest         | latest  | latest |

| EPHEMERAL TESTS                                    | CAPM3 branch | IPAM branch  | BMO branch/tag  | Keepalived tag | MariaDB tag | Ironic tag |
| ------                                               | ------------ | -----------  | --------------- | -------------- | ------- | ------ |
| daily_main_e2e_ephemeral_test_centos                 | main         | main         | main            | latest         | latest  | latest |

All tests use latest images of VBMC and sushy-tools.
