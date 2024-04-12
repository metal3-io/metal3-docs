# Releasing in Metal3

This document details the high-level process of creating a Metal3 release, and
the post-release actions required to add new release branches to the CI.

Note the [TODO](#releasing-process-todo) section in the end.

## Process

High-level release process for a major/minor release. For patch releases, only
release the relevant versions.

**NOTE**: Ironic-image (via upstream Ironic) has different release cadence as
Metal3 repos. It is not always possible to release them synced.

1. [Release ironic-image](https://github.com/metal3-io/ironic-image/blob/main/docs/releasing.md)
1. [Release IPAM](https://github.com/metal3-io/ip-address-manager/blob/main/docs/releasing.md)
1. [Release BMO](https://github.com/metal3-io/baremetal-operator/blob/main/docs/releasing.md)
1. [Release CAPM3](https://github.com/metal3-io/cluster-api-provider-metal3/blob/main/docs/releasing.md)
1. [Tag Mariadb image](#tag-mariadb-image)
1. [Update Metal3 dev-env and CI to support new releases](#update-metal3-dev-env-and-ci-to-support-new-releases)

**NOTE**: Always follow release documentation from the respective main branch.
Release documentation in release branches may be outdated.

## Tag Mariadb image

After releasing `v1.x.y` version of CAPM3, create an annotated tag with `capm3-`
prefix + release version in
[mariadb-image](https://github.com/metal3-io/mariadb-image) Github repository.

```bash
git tag -s -a capm3-v1.x.y -m capm3-v1.x.y [optional sha, or tag^{}]
git push origin capm3-v1.x.y
```

After this, [MariaDB](https://quay.io/repository/metal3-io/mariadb) container
image will be built automatically  with `capm3-v1.x.y` tag in Quay. Verify the
build is triggered, as often Quay has disabled the build trigger due build
failures or other reasons.

## Update Metal3 dev-env and CI to support new releases

If a new minor or major release was published, we need to make changes in
Metal3 dev-env and CI.
**NOTE**: These changes shall only be merged after the releases are out, as they
require the releases they refer to be out already to pass PR tests to merge!

### Create Jenkins jobs

Many Jenkins jobs need to be created in
[JJB](https://gerrit.nordix.org/plugins/gitiles/infra/cicd/+/refs/heads/master/jjb/metal3/).


- a periodic job that runs on a regular basis.
- a PR verification job that is triggered by a keyword on a PR targeted for that
  release branch.

[Prior art](https://gerrit.nordix.org/c/infra/cicd/+/17709) that adds support
for periodics and PR jobs.

### Change project-infra to support new branches

We also need to change project-infra keywords for required tests for some of
the repositories.

[Prior art](https://github.com/metal3-io/project-infra/pull/496)

### Configure Metal3 dev-env to support new branches

Metal3-dev-env needs to be modified to support new release branches and
tags with supported combination of component versions for testing.

[Prior art](https://github.com/metal3-io/metal3-dev-env/pull/1222)

### Configure Metal3 dev-tools to sync new release branches to Nordix

Dev-tools synchronizes `metal3-io` changes to the `Nordix` fork for the EST
folks.

[Prior art](https://github.com/Nordix/metal3-dev-tools/pull/672)

### Update testing matrix documentation

Update
[version support documentation](https://github.com/metal3-io/metal3-docs/blob/main/docs/user-guide/src/version_support.md)
including Testing Matrix to reflect the new release and the combination of
components that are tested in periodic jobs.

[Prior art](https://github.com/metal3-io/metal3-docs/pull/330)

## Announcements

We announce the release in Kubernetes slack on `#cluster-api-baremetal` channel
and through the `metal3-dev` group mailing list.

Email template, with title `New CAPM3, IPAM and BMO minor releases are out!`
(adjust as necessary depending on what is being released):

```text
Hey folks,

CAPM3 v1.x.y, IPAM v1.x.y, BMO v0.x.y and Ironic-image vx.y.z minor releases are out now!
Release notes can be found here: [1], [2], [3], [4].

Thanks to all our contributors!

[1] https://github.com/metal3-io/cluster-api-provider-metal3/releases/tag/v1.x.y
[2] https://github.com/metal3-io/ip-address-manager/releases/tag/v1.x.y
[3] https://github.com/metal3-io/baremetal-operator/releases/tag/v0.x.y
[4] https://github.com/metal3-io/ironic-image/releases/tag/vx.y.z

Thanks to all our contributors!
```

Slack template:

```text
Hey folks,

CAPM3 v1.x.y, IPAM v1.x.y, BMO v0.x.y and Ironic-image vx.y.z minor releases
are out now! now :tada::metal3:!

Release notes can be found here:
- https://github.com/metal3-io/cluster-api-provider-metal3/releases/tag/v1.x.y
- https://github.com/metal3-io/ip-address-manager/releases/tag/v1.x.y
- https://github.com/metal3-io/baremetal-operator/releases/tag/v0.x.y
- https://github.com/metal3-io/ironic-image/releases/tag/vx.y.z

Thanks to all our contributors! :blush:
```

## Releasing process TODO

### BMO

BMO releasing to be fine-tuned.

1. BMO dependencies
   - BMO contains `keepalived`
     ([within BMO repo](https://github.com/metal3-io/baremetal-operator/tree/main/resources/keepalived-docker))
1. BMO makes assumption about the exact configuration of MariaDB.
   However, [mariadb-image](https://github.com/metal3-io/mariadb-image) is
   currently branchless.

### Mariadb-image

Mariadb-image releasing to be implemented.
