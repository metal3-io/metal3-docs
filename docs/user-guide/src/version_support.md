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
| v1.13         | v1beta2     | Supported |
| v1.12         | v1beta1     | Supported |
| v1.11         | v1beta1     | Tested    |
| v1.10         | v1beta1     | EOL       |
| v1.9          | v1beta1     | EOL       |
| v1.8          | v1beta1     | EOL       |
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
| v1.13         | v1beta2     | Supported |
| v1.12         | v1beta1     | Supported |
| v1.11         | v1beta1     | Tested    |
| v1.10         | v1beta1     | EOL       |
| v1.9          | v1beta1     | EOL       |
| v1.8          | v1beta1     | EOL       |
| v1.7          | v1beta1     | EOL       |
| v1.6          | v1beta1     | EOL       |
| v1.5          | v1beta1     | EOL       |
| v1.4          | v1beta1     | EOL       |
| v1.3          | v1beta1     | EOL       |
| v1.2          | v1beta1     | EOL       |
| v1.1          | v1beta1     | EOL       |

The compatibility of IPAM and CAPM3 API versions with CAPI is discussed
[in the following docs](https://github.com/metal3-io/ip-address-manager#compatibility-with-cluster-api).

## Baremetal Operator

Since `capm3-v1.1.2`, BMO follows the semantic versioning scheme for its own
release cycle, the same way as CAPM3 and IPAM. Two branches are maintained as
supported releases. Following table summarizes BMO release/test process:

| Minor release | Status    |
| ------------- | --------- |
| v0.13         | Supported |
| v0.12         | Supported |
| v0.11         | Tested    |
| v0.10         | EOL       |
| v0.9          | EOL       |
| v0.8          | EOL       |
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

| Minor release | Status    | Ironic Branch       |
| ------------- | --------- | ------------------- |
| v37.0         | Supported | bugfix/37.0         |
| v35.0         | Supported | stable/2026.1       |
| v34.0         | Supported | bugfix/34.0         |
| v33.0         | Supported | bugfix/33.0         |
| v32.0         | Tested    | stable/2025.2       |
| v31.0         | Tested    | bugfix/31.0 (EOL)   |
| v30.0         | EOL       | bugfix/30.0 (EOL)   |
| v29.0         | EOL       | stable/2025.1       |
| v28.0         | EOL       | bugfix/28.0 (EOL)   |
| v27.0         | EOL       | bugfix/27.0 (EOL)   |
| v26.0         | EOL       | bugfix/26.0 (EOL)   |
| v25.0         | EOL       | bugfix/25.0 (EOL)   |
| v24.1         | EOL       | stable/2024.1 (EOL) |
| v24.0         | EOL       | bugfix/24.0 (EOL)   |
| v23.1         | EOL       | bugfix/23.1 (EOL)   |

## Ironic Standalone Operator

Ironic Standalone Operator (IrSO) follows the semantic versioning scheme for its
own release cycle, the same way as CAPM3 and IPAM. A major and minor version can
be supplied to the `Ironic` resource to request a specific branch of ironic-image
(and thus Ironic). Here are supported version values for each branch and release
of the operator:

| Operator version | Ironic version(s)                    | Default version | Support status |
| ---------------- | ------------------------------------ | --------------- | -------------- |
| latest (main)    | latest, 37.0, 35.0, 34.0             | latest          | Supported      |
| 0.10.0           | 37.0, 35.0, 34.0                     | 37.0            | Supported      |
| 0.9.0            | 35.0, 34.0, 33.0                     | 35.0            | Supported      |
| 0.8.0            | 34.0, 33.0, 32.0                     | 34.0            | Tested         |
| 0.7.0            | 33.0, 32,0, 31.0                     | 33.0            | EOL            |
| 0.6.0            | 32.0, 31.0, 30.0                     | 32.0            | EOL            |
| 0.5.0            | 31.0, 30.0, 29.0, 28.0, 27.0         | 31.0            | EOL            |
| 0.4.0            | 30.0, 29.0, 28.0, 27.0               | 30.0            | EOL            |
| 0.3.0            | 29.0, 28.0, 27.0                     | latest          | EOL            |
| 0.2.0            | 28.0, 27.0                           | latest          | EOL            |
| 0.1.0            | 27.0                                 | latest          | EOL            |

**NOTE:** the special version value `latest` always installs the latest
available version of ironic-image and Ironic. This version value is
supported by all releases of IrSO but only works reliably in the
latest release.

## Image tags

The Metal³ team provides container images for all the main projects and also
many auxiliary tools needed for tests or otherwise useful. Some of these images
are tagged in a way that makes it easy to identify what version of Cluster API
provider Metal³ they are tested with.

All container images are published through the
[Metal³ organization in Quay](https://quay.io/organization/metal3-io/).
Here are some examples:

- quay.io/metal3-io/cluster-api-provider-metal3:v1.13.0
- quay.io/metal3-io/baremetal-operator:v0.13.0
- quay.io/metal3-io/ip-address-manager:v1.13.0
- quay.io/metal3-io/ironic:v37.0.0
- quay.io/metal3-io/ironic-standalone-operator:v0.10.0

## CI Test Matrix

The table describes which branches/image-tags are tested in each periodic CI tests:

<!-- markdownlint-disable MD013 -->

| INTEGRATION TESTS                                               | CAPM3 branch | IPAM branch  | BMO branch/tag | Keepalived tag | MariaDB tag | Ironic tag |
| --------------------------------------------------------------- | ------------ | ------------ | -------------- | -------------- | ----------- | ---------- |
| metal3-periodic-ubuntu/centos-e2e-integration-test-main         | main         | main         | main           | latest         | latest      | latest     |
| metal3_periodic_main_integration_test_ubuntu/centos             | main         | main         | main           | latest         | latest      | latest     |
| metal3-periodic-ubuntu/centos-e2e-integration-test-release-1-13 | release-1.13 | release-1.13 | release-0.13   | latest         | latest      | v35.0.0    |
| metal3-periodic-ubuntu/centos-e2e-integration-test-release-1-12 | release-1.12 | release-1.12 | release-0.12   | latest         | latest      | v33.0.0    |
| metal3-periodic-ubuntu/centos-e2e-integration-test-release-1-11 | release-1.11 | release-1.11 | release-0.11   | latest         | latest      | v31.0.0    |

| FEATURE AND E2E TESTS                                            | CAPM3 branch | IPAM branch  | BMO branch/tag | Keepalived tag | MariaDB tag | Ironic tag |
| ---------------------------------------------------------------- | ------------ | ------------ | -------------- | -------------- | ----------- | ---------- |
| metal3-periodic-centos-e2e-feature-test-main-pivoting            | main         | main         | main           | latest         | latest      | latest     |
| metal3-periodic-centos-e2e-feature-test-release-1-13-pivoting    | release-1.13 | release-1.13 | release-0.13   | latest         | latest      | v35.0.0    |
| metal3-periodic-centos-e2e-feature-test-release-1-12-pivoting    | release-1.12 | release-1.12 | release-0.12   | latest         | latest      | v33.0.0    |
| metal3-periodic-centos-e2e-feature-test-release-1-11-pivoting    | release-1.11 | release-1.11 | release-0.11   | latest         | latest      | v31.0.0    |
| metal3-periodic-centos-e2e-feature-test-main-remediation         | main         | main         | main           | latest         | latest      | latest     |
| metal3-periodic-centos-e2e-feature-test-release-1-13-remediation | release-1.13 | release-1.13 | release-0.13   | latest         | latest      | v35.0.0    |
| metal3-periodic-centos-e2e-feature-test-release-1-12-remediation | release-1.12 | release-1.12 | release-0.12   | latest         | latest      | v33.0.0    |
| metal3-periodic-centos-e2e-feature-test-release-1-11-remediation | release-1.11 | release-1.11 | release-0.11   | latest         | latest      | v31.0.0    |
| metal3-periodic-centos-e2e-feature-test-main-features            | main         | main         | main           | latest         | latest      | latest     |
| metal3-periodic-centos-e2e-feature-test-release-1-13-features    | release-1.13 | release-1.13 | release-0.13   | latest         | latest      | v35.0.0    |
| metal3-periodic-centos-e2e-feature-test-release-1-12-features    | release-1.12 | release-1.12 | release-0.12   | latest         | latest      | v33.0.0    |
| metal3-periodic-centos-e2e-feature-test-release-1-11-features    | release-1.11 | release-1.11 | release-0.11   | latest         | latest      | v31.0.0    |

| EPHEMERAL TESTS                                                | CAPM3 branch | IPAM branch | BMO branch/tag | Keepalived tag | MariaDB tag | Ironic tag |
| -------------------------------------------------------------- | ------------ | ----------- | -------------- | -------------- | ----------- | ---------- |
| metal3_periodic_e2e_ephemeral_test_centos                      | main         | main        | main           | latest         | latest      | latest     |

<!-- markdownlint-enable MD013 -->

All tests use latest images of VBMC and sushy-tools.
