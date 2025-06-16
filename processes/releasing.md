# Releasing in Metal3

This document details the high-level process of creating a Metal3 release, and
the post-release actions required to add new release branches to the CI.

## Process

High-level release process for a major/minor release. For patch releases, only
release the relevant versions.

**NOTE**: [Ironic-image](https://github.com/metal3-io/ironic-image) (via
upstream Ironic) and
[IrSO](https://github.com/metal3-io/ironic-standalone-operator) (linked to
Ironic-image releases) have different release cadence as CAPM3, BMO and IPAM
repos.

1. [Release Ironic-image](https://github.com/metal3-io/ironic-image/blob/main/docs/releasing.md)
1. [Release IrSO](https://github.com/metal3-io/ironic-standalone-operator/blob/main/docs/releasing.md)
1. [Release IPAM](https://github.com/metal3-io/ip-address-manager/blob/main/docs/releasing.md)
1. [Release BMO](https://github.com/metal3-io/baremetal-operator/blob/main/docs/releasing.md)
1. [Release CAPM3](https://github.com/metal3-io/cluster-api-provider-metal3/blob/main/docs/releasing.md)
1. [Update Metal3 dev-env and CI to support new releases](#update-metal3-dev-env-and-ci-to-support-new-releases)

**NOTE**: Always follow release documentation from the respective main branch.
Release documentation in release branches may be outdated.

## Tag Mariadb image

**NOTE**: This step is deprecated and is applied only up to CAPM3 v1.11.x tags.

After releasing `v1.x.y` version of CAPM3, create an annotated tag with `capm3-`
prefix + release version in
[mariadb-image](https://github.com/metal3-io/mariadb-image) Github repository.
Origin points to `metal3-io`.

For minor releases:

```bash
git tag -s -a capm3-v1.x.y -m capm3-v1.x.y
git push origin capm3-v1.x.y
```

For patch releases:

```bash
git tag -s -a capm3-v1.x.y -m capm3-v1.x.y [optional sha, or tag^{}]
git push origin capm3-v1.x.y
```

The last part should point to a previous patch. For example for tag `v.1.x.2`:

```bash
git tag -s -a capm3-v1.x.2 -m capm3-v1.x.2 capm3-v1.x.1^{}
```

After this, [MariaDB](https://quay.io/repository/metal3-io/mariadb) container
image will be built automatically  with `capm3-v1.x.y` tag in Quay. Verify the
build is triggered, as often Quay has disabled the build trigger due build
failures or other reasons.

If build is not triggered check:

- Debug and retrigger [workflow](https://github.com/metal3-io/mariadb-image/actions/runs/13174700659/job/36772849955)
for building container images
- You can also try running the job in [Jenkins](https://jenkins.nordix.org/view/Metal3/job/metal3_mariadb_container_image_building/)

## Update Metal3 dev-env and CI to support new releases

If a new minor or major release was published, we need to make changes in
Metal3 dev-env and CI.
**NOTE**: These changes shall only be merged after the releases are out, as they
require the releases they refer to be out already to pass PR tests to merge!

### Create Jenkins jobs

Two Jenkins jobs need to be created in
[JJB](https://gerrit.nordix.org/gitweb?p=infra/cicd.git;a=tree;f=jjb/metal3;hb=HEAD):

- a periodic job that runs on a regular basis.
- a PR verification job that is triggered by a keyword on a PR targeted for that
  release branch.

[Prior art](https://gerrit.nordix.org/c/infra/cicd/+/17709) that adds support
for periodics and PR jobs.

### Change project-infra to support new branches

We also need to change project-infra keywords for required tests for some of
the repositories.

Prior art - jobs:

- [BMO](https://github.com/metal3-io/project-infra/pull/1000)
- [IPAM](https://github.com/metal3-io/project-infra/pull/998)
- [CAPM3](https://github.com/metal3-io/project-infra/pull/999)
- [IrSO](https://github.com/metal3-io/project-infra/pull/1034)
- [Other jobs and milestones](https://github.com/metal3-io/project-infra/pull/1002)

### Configure Metal3 dev-env to support new branches

Metal3-dev-env needs to be modified to support new release branches and
tags with supported combination of component versions for testing.

[Prior art](https://github.com/metal3-io/metal3-dev-env/pull/1523)

### Configure Metal3 dev-tools to sync new release branches to Nordix

Dev-tools synchronizes `metal3-io` changes to the `Nordix` fork for the EST
folks.

[Prior art](https://github.com/Nordix/metal3-dev-tools/pull/784)

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

CAPM3 v1.x.y, IPAM v1.x.y, BMO v0.x.y, IrSO v0.x.y and Ironic-image vx.y.z minor
releases are out now! Release notes can be found here: [1], [2], [3], [4], [5].
Thanks to all our contributors!

[1] https://github.com/metal3-io/cluster-api-provider-metal3/releases/tag/v1.x.y
[2] https://github.com/metal3-io/ip-address-manager/releases/tag/v1.x.y
[3] https://github.com/metal3-io/baremetal-operator/releases/tag/v0.x.y
[4] https://github.com/metal3-io/ironic-standalone-operator/releases/tag/vx.y.z
[5] https://github.com/metal3-io/ironic-image/releases/tag/vx.y.z

Thanks to all our contributors!
```

Slack template:

```text
Hey folks,

CAPM3 v1.x.y, IPAM v1.x.y, BMO v0.x.y, IrSO v0.x.y and Ironic-image vx.y.z minor
releases are out now! now :tada::metal3:!

Release notes can be found here:
- https://github.com/metal3-io/cluster-api-provider-metal3/releases/tag/v1.x.y
- https://github.com/metal3-io/ip-address-manager/releases/tag/v1.x.y
- https://github.com/metal3-io/baremetal-operator/releases/tag/v0.x.y
- https://github.com/metal3-io/ironic-standalone-operator/releases/tag/vx.y.z
- https://github.com/metal3-io/ironic-image/releases/tag/vx.y.z

Thanks to all our contributors! :blush:
```
