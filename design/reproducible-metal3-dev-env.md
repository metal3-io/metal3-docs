<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Reproducible metal3-dev-env

## Status

provisional

## Summary

The [metal3-dev-env](https://github.com/metal3-io/metal3-dev-env) is used by
developers working on metal3 components, for all CI builds and integration
tests, and it is also something of a reference for users deploying metal3.

At the moment, the environment is quite far from being reproducible. In other
words, running `make` in metal3-dev-env at the same commit on two different
days could lead to different results and different software being run in the
environment, regardless of any changes to metal3 projects. In several places,
the Bash scripts in metal3-dev-env get the latest version of external software
and automatically pull this into the environment, meaning that upstream
releases change or break the development environment.

The purpose of this proposed change is to pin external dependencies of metal3
in the metal3-dev-env, and use automated tooling, such as
[Renovate](https://github.com/renovatebot/renovate) to keep these dependencies
up to date via pull requests. Then updates to external software which may break
the environment can be gated at pull request time, when an integration test is
run. Furthermore, if there are external changes which flakily break the build
(and get past an integration test), it is simple enough to revert the merge
commit to fix the environment.

## Motivation

On weeks commencing 11th April 2021 and 18th April 2021, there were several
software releases and wider infrastructure issues which led to build failures
on the master branch:

* Minikube v1.19 was released and automatically pulled into our environment. It
  appears to have a flaky issue with instantiating an IP address for the
  minikube VM in our environment, which we did not see in v1.18.
* A kubelet bug in Kubernetes v1.20.4 occasionally breaks builds with a
  multi-node control plane
* A change to tripleo-repos script was pulled in automatically by the
  Dockerfile which builds vbmc, and broke all builds and integration tests

Each of these changes and consequent changes were outside of metal3. During
this time, integration tests in pull requests for components were failing for
reasons unrelated to the content of the proposed change. Furthermore, these
issues compounded: in order to fix one of the problems in metal3-dev-env, the
integration test for the fix failed for a different reason. Developers also
struggled against these issues when iterating on code in their own local
environment, and any users who may have tried out Metal3 (using the Metal3 docs
'Try It' page) would potentially have run into difficulties and problems.

By versioning our dependencies and gating them into the environment at pull
request time, we can add stability to our builds, tests and development
environments.

### Goals

* All metal3-dev-env dependencies on external infrastructure to be versioned
  and pinned.
* Pinned dependencies to receive automated updates via pull request.
* Additionally, move sushy-tools and vbmc image building to a separate repo and
  version the images properly?

### Non-Goals

* No changes to any of the metal3 components: the focus of this change is only
  on the development environment
* Continue to pull metal3 dependencies themselves (BMO, CAPM3, etc.) from
  master directly. Only external software outside of the main mandate of the
  metal3 project is included in this proposal.

## Proposal

### User Stories

#### Story 1

* As a developer
* When I clone metal3-dev-env at a given commit on some machine
* I get the same environment regardless of when I issued `git clone`

#### Story 2

* As a maintainer of the metal3-dev-env
* When new releases of upstream software are released
* I'm notified by pull request and can merge the proposed upgrade if the
  integration tests pass

## Design Details

Versions of external software used in the metal3-dev-env should be pinned.

A comprehensive list of software (TODO: along with where it is used):

* Kubernetes
* Minikube and its docker kvm2 machine driver
* kind
* vbmc image: tripleo-repos
* sushy-tools image: libvirt-dev and libvirt-python (we could also track
  updates to sushy-tools itself)
* ironic-python-agent version downloaded with the ipa-downloader image
* TODO: Ansible? Ubuntu? CentOS? OpenStack client? More?

Then the plan is to enable the 'Renovate' app on the GitHub metal3-dev-env
repo, together with a renovate.json file with the details of our dependencies.
From here, pull requests can be automatically generated against the
metal3-dev-env repo when dependencies change. Or, if dependencies change
frequently, on a less frequent schedule (e.g. once weekly or once monthly).

### Implementation Details/Notes/Constraints

TBD.

### Risks and Mitigations

* Risk that dependencies fall out of date and no one looks at / reviews
  updates. Mitigated by assigning pull requests to someone on designated CI
  support.

### Work Items

* Identify the dependencies that are used in the metal3-dev-env
* For each dependency, add an environment variable for the version and set that
  environment variable.
* Where the version of software is in a Docker image built in the
  metal3-dev-env, see instead if the Docker image can be built in a separate
  repository, and use Docker tags to pull newer versions of these images.
* Add Renovate as a GitHub App to the metal3-dev-env repository.
* Add a renovate.json config which will create pull requests for dependencies
  on a suitable schedule.

### Dependencies

No dependency on other metal3 items of work.

### Test Plan

TBD.

### Upgrade / Downgrade Strategy

Not applicable.

### Version Skew Strategy

Not applicable.

## Drawbacks

* Pull requests created by Renovate could be spammy. We can configure Renovate
  to get a trade-off between being up-to-date, having the latest external
  dependencies and reducing the amount of spam in pull requests to the repo.
  But this may take some trial and error.
* If a dependency introduces failures into the metal3-dev-env we still need to
  investigate to some extent why and what changes are required to support the
  update. (But at least we can do it on our schedule instead of hurrying to fix
  master.

## Alternatives

* Do nothing. We continue to fix master of metal3-dev-env forwards when we spot
  problems in CI.
* Add dependencies only for the most frequently broken components.

## References

TBD.
