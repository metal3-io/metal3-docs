# Supported release versions

The Cluster API Provider Metal3 (CAPM3) team maintains the two most recent minor
releases; older minor releases are immediately unsupported when a new
major/minor release is available. Test coverage will be maintained for all
supported minor releases and for one additional release for the current API
version in case we have to do an emergency patch release. For example, if v1.6
and v1.7 are currently supported, we will also maintain test coverage for
v1.5 for one additional release cycle. When v1.8 is released, tests for v1.5
will be removed.

Currently, in Metal³ organization only CAPM3 and IPAM follow CAPI release
cycles. The supported versions (excluding release candidates) for CAPM3 and
IPAM releases are as follows:

Cluster API Provider Metal3

| Minor release | API version | Status    |
| ------------- | ----------- | --------- |
| v1.10         | v1beta1     | Supported |
| v1.9          | v1beta1     | Supported |
| v1.8          | v1beta1     | Tested    |
| v1.7          | v1beta1     | EOL       |
| v1.6          | v1beta1     | EOL       |
| v1.5          | v1beta1     | EOL       |
| v1.4          | v1beta1     | EOL       |
| v1.3          | v1beta1     | EOL       |
| v1.2          | v1beta1     | EOL       |
| v1.1          | v1beta1     | EOL       |

IP Address Manager

| Minor release | API version | Status    |
| ------------- | ----------- | --------- |
| v1.10         | v1beta1     | Supported |
| v1.9          | v1beta1     | Supported |
| v1.8          | v1beta1     | Tested    |
| v1.7          | v1beta1     | EOL       |
| v1.6          | v1beta1     | EOL       |
| v1.5          | v1beta1     | EOL       |
| v1.4          | v1beta1     | EOL       |
| v1.3          | v1beta1     | EOL       |
| v1.2          | v1beta1     | EOL       |
| v1.1          | v1beta1     | EOL       |

The compatibility of IPAM and CAPM3 API versions with CAPI is discussed
[here](https://github.com/metal3-io/ip-address-manager#compatibility-with-cluster-api).

## Baremetal Operator

Since `capm3-v1.1.2`, BMO follows the semantic versioning scheme for its own
release cycle, the same way as CAPM3 and IPAM. Two branches are maintained as supported releases.
Following table summarizes BMO release/test process:

| Minor release | Status    |
| ------------- | --------- |
| v0.10         | Supported |
| v0.9          | Supported |
| v0.8          | Tested    |
| v0.6          | EOL       |
| v0.5          | EOL       |
| v0.4          | EOL       |
| v0.3          | EOL       |
| v0.2          | EOL       |
| v0.1          | EOL       |

## Ironic-image

Since `v23.1.0`, Ironic follows the semantic versioning scheme for its own
release cycle, the same way as CAPM3 and IPAM. Two or three branches are
maintained as supported releases.

Following table summarizes Ironic-image release/test process:

| Minor release | Status    | Ironic Branch      |
| ------------- | --------- | ------------------ |
| v30.0         | Supported | bugfix/30.0        |
| v29.0         | Supported | stable/2025.1      |
| v28.0         | Supported | bugfix/28.0        |
| v27.0         | Supported | bugfix/27.0        |
| v26.0         | Tested    | bugfix/26.0        |
| v25.0         | EOL       | bugfix/25.0 (EOL)  |
| v24.1         | EOL       | stable/2024.1      |
| v24.0         | EOL       | bugfix/24.0 (EOL)  |
| v23.1         | EOL       | bugfix/23.1 (EOL)  |

## Image tags

The Metal³ team provides container images for all the main projects and also
many auxiliary tools needed for tests or otherwise useful. Some of these images
are tagged in a way that makes it easy to identify what version of Cluster API
provider Metal³ they are tested with. For example, we tag MariaDB
container images with tags like `capm3-v1.7.0`, where `v1.7.0` would be the
CAPM3 release it was tested with.

All container images are published through the
[Metal³ organization in Quay](https://quay.io/organization/metal3-io).
Here are some examples:

- quay.io/metal3-io/cluster-api-provider-metal3:v1.7.0
- quay.io/metal3-io/baremetal-operator:v0.6.0
- quay.io/metal3-io/ip-address-manager:v1.7.0
- quay.io/metal3-io/ironic:v24.1.1
- quay.io/metal3-io/mariadb:capm3-v1.7.0

## CI Test Matrix

The table describes which branches/image-tags are tested in each periodic CI tests:

<!-- markdownlint-disable MD013 -->

| INTEGRATION TESTS                                               | CAPM3 branch | IPAM branch  | BMO branch/tag | Keepalived tag | MariaDB tag | Ironic tag |
| --------------------------------------------------------------- | ------------ | ------------ | -------------- | -------------- | ----------- | ---------- |
| metal3-periodic-ubuntu/centos-e2e-integration-test-main         | main         | main         | main           | latest         | latest      | latest     |
| metal3_periodic_main_integration_test_ubuntu/centos             | main         | main         | main           | latest         | latest      | latest     |
| metal3-periodic-ubuntu/centos-e2e-integration-test-release-1-10 | release-1.10 | release-1.10 | release-0.10   | v0.10.0        | latest      | v29.0.0    |
| metal3-periodic-ubuntu/centos-e2e-integration-test-release-1-9  | release-1.9  | release-1.9  | release-0.9    | v0.9.0         | latest      | v27.0.0    |
| metal3-periodic-ubuntu/centos-e2e-integration-test-release-1-8  | release-1.8  | release-1.8  | release-0.8    | v0.8.0         | latest      | v26.0.1    |

| FEATURE AND E2E TESTS                                            | CAPM3 branch | IPAM branch  | BMO branch/tag | Keepalived tag | MariaDB tag | Ironic tag |
| ---------------------------------------------------------------- | ------------ | ------------ | -------------- | -------------- | ----------- | ---------- |
| metal3-periodic-centos-e2e-feature-test-main-pivoting            | main         | main         | main           | latest         | latest      | latest     |
| metal3-periodic-centos-e2e-feature-test-release-1-9-pivoting     | release-1.10 | release-1.10 | release-0.10   | v0.10.0        | latest      | v29.0.0    |
| metal3-periodic-centos-e2e-feature-test-release-1-9-pivoting     | release-1.9  | release-1.9  | release-0.9    | v0.9.0         | latest      | v27.0.0    |
| metal3-periodic-centos-e2e-feature-test-release-1-8-pivoting     | release-1.8  | release-1.8  | release-0.8    | v0.8.0         | latest      | v26.0.1    |
| metal3-periodic-centos-e2e-feature-test-main-remediation         | main         | main         | main           | latest         | latest      | latest     |
| metal3-periodic-centos-e2e-feature-test-release-1-9-remediation  | release-1.10 | release-1.10 | release-0.10   | v0.10.0        | latest      | v29.0.0    |
| metal3-periodic-centos-e2e-feature-test-release-1-9-remediation  | release-1.9  | release-1.9  | release-0.9    | v0.9.0         | latest      | v27.0.0    |
| metal3-periodic-centos-e2e-feature-test-release-1-8-remediation  | release-1.8  | release-1.8  | release-0.8    | v0.8.0         | latest      | v26.0.1    |
| metal3-periodic-centos-e2e-feature-test-main-features            | main         | main         | main           | latest         | latest      | latest     |
| metal3-periodic-centos-e2e-feature-test-release-1-9-features     | release-1.10 | release-1.10 | release-0.10   | v0.10.0        | latest      | v29.0.0    |
| metal3-periodic-centos-e2e-feature-test-release-1-9-features     | release-1.9  | release-1.9  | release-0.9    | v0.9.0         | latest      | v27.0.0    |
| metal3-periodic-centos-e2e-feature-test-release-1-8-features     | release-1.8  | release-1.8  | release-0.8    | v0.8.0         | latest      | v26.0.1    |

| EPHEMERAL TESTS                                                | CAPM3 branch | IPAM branch | BMO branch/tag | Keepalived tag | MariaDB tag | Ironic tag |
| -------------------------------------------------------------- | ------------ | ----------- | -------------- | -------------- | ----------- | ---------- |
| metal3_periodic_e2e_ephemeral_test_centos                      | main         | main        | main           | latest         | latest      | latest     |

<!-- markdownlint-enable MD013 -->

All tests use latest images of VBMC and sushy-tools.
