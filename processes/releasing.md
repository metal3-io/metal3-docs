# Releasing

This document details the high-level process of creating a Metal3 release, and
the post-release actions required to add new release branches to the CI.

Note the [TODO](#todo) section in the end.

## Process

High-level release process we followed in case it makes it clearer:

1. [Release IPAM](https://github.com/metal3-io/ip-address-manager/blob/main/docs/releasing.md)
1. [Release BMO](https://github.com/metal3-io/baremetal-operator/blob/main/docs/releasing.md)
1. [Release CAPM3](https://github.com/metal3-io/cluster-api-provider-metal3/blob/main/docs/releasing.md)
1. Update Metal3 dev-env and CI to support new releases

## Update Metal3 dev-env and CI to support new releases

If a new minor or major release was published, we need to make changes in
Metal3 dev-env and CI.

### Tag Ironic and Mariadb images

After releasing `v1.x.y` version of CAPM3, create an annotated tag with `capm3-`
prefix + release version in
[ironic-image](https://github.com/metal3-io/ironic-image) and
[mariadb-image](https://github.com/metal3-io/mariadb-image) Github
repositories.

```bash
git tag -s -a capm3-v1.x.y -m capm3-v1.x.y [optional sha, or tag^{}]
git push origin capm3-v1.x.y
```

After this, [Ironic](https://quay.io/repository/metal3-io/ironic) and
[MariaDB](https://quay.io/repository/metal3-io/mariadb) container images will
be built automatically  with `capm3-v1.x.y` tag in Quay. Verify the build is
triggered, as often Quay has disabled the build trigger due build failures or
other reasons.

### Create Jenkins jobs

Two Jenkins jobs need to be created in
[JJB](https://gerrit.nordix.org/plugins/gitiles/infra/cicd/+/refs/heads/master/jjb/metal3/):

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

Email template:

```text
Hey folks,

CAPM3 v1.x.y, IPAM v1.x.y and BMO v0.x.y minor releases are out now!
Release notes can be found here: CAPM3 release notes[1], IPAM release notes[2] and BMO release notes[3].

Thanks to all our contributors!

[1] https://github.com/metal3-io/cluster-api-provider-metal3/releases/tag/v1.x.y
[2] https://github.com/metal3-io/ip-address-manager/releases/tag/v1.x.y
[3] https://github.com/metal3-io/baremetal-operator/releases/tag/v0.x.y
```

Slack template:

```text
Hey folks,

CAPM3 v1.x.y, IPAM v1.x.y and BMO v0.x.y minor releases are out now :tada::metal3:!

Release notes can be found here:
- CAPM3 v1.x.y: https://github.com/metal3-io/cluster-api-provider-metal3/releases/tag/v1.x.y
- IPAM v1.x.y: https://github.com/metal3-io/ip-address-manager/releases/tag/v1.x.y
- BMO: v0.x.y: https://github.com/metal3-io/baremetal-operator/releases/tag/v0.x.y

Thanks to all our contributors! :blush:
```

## TODO

BMO releasing to be discussed.

1. BMO releasing and maintenance
   - BMO does not have release branches, only tags off the `main` branch
   - Without release branches, maintaining BMO versions that are coupled with
     CAPM3 releases is impossible
1. BMO dependencies
   - BMO contains `keepalived`
     ([within BMO repo](https://github.com/metal3-io/baremetal-operator/tree/main/resources/keepalived-docker))
1. BMO makes strong assumption about the exact configuration of Ironic.
   However, [ironic-image](https://github.com/metal3-io/ironic-image) is
   currently branchless.
1. BMO makes assumption about the exact configuration of MariaDB.
   However, [mariadb-image](https://github.com/metal3-io/mariadb-image) is
   currently branchless.
