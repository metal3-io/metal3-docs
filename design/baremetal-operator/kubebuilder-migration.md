# kubebuilder-migration

<!-- cSpell:ignore dhellmann's -->

## Status

implemented

## Summary

We have recently encountered several situations where we wanted to
take advantage of kubernetes API features that are not supported by
the old version of operator-sdk currently used with the
baremetal-operator (especially web hooks for validation and converting
between different API versions, and support for v1 of the
CustomResourceDefinition API).  The newer version of operator-sdk (1.0
and later) is more closely aligned with kubebuilder, so updating to
the new version would be about the same amount of work as switching to
kubebuilder. Updating the tool will unblock several efforts, and that
will be enough work own that documenting the change separately seems
prudent.

Since the results are effectively the same, and the other projects in
metal3 use kubebuilder, this proposal describes the work we will need
to do to migrate from operator-sdk to kubebuilder, with references to
a proof-of-concept implementation.

## Motivation

We chose to build the baremetal-operator using the operator-sdk
because it was familiar to the original designers and known to be
under active development. The version of operator-sdk we are using
does not support all of the features we need, and in the time since
that initial choice, the priorities of the operator-sdk team have
decided to integrate the work with kubebuilder. The newer version of
kubebuilder has features that will be useful to us (web hooks, API
version migration, etc.).

### Goals

- Use a tool more widely used for complex controller implementation.
- Update our tools to gain support for features such as web hooks and
  scaffolding for multiple API versions for the same resource type.

### Non-Goals

- Make any API changes to the BareMetalHost type.

## Proposal

As discussed in [the original v1alpha2 API
proposal](https://github.com/metal3-io/metal3-docs/pull/101/), we will
need to carry a modified version of kubebuilder to support float field
types.  We can carry the fork either within the baremetal-operator
repository or in a separate repository under the metal3-io org on
github, but it will involve fewer large patches to the
baremetal-operator repository if we fork what we need in a separate
repository and have the Makefile in the baremetal-operator repository
build the tools from our fork.

Kubebuilder initializes a project repository using a different layout
than the old version of operator-sdk. It also uses a different
approach to registering controllers, API types, etc. So, migrating
will involve moving some existing code to new places and changing some
of it. In particular:

- kubebuilder places all packages at the top of the repository, not
  under `pkg`
- kubebuilder places all controllers in the same directory
- main.go instantiates reconciler objects directly instead of calling
  a factory, so some previously private parameters such as the
  provisioner factory may need to be made public

The [kubebuilder3
branch](https://github.com/dhellmann/baremetal-operator/tree/kubebuilder3)
of dhellmann's fork of the baremetal-operator repository is a
proof-of-concept implementation of the migration. The host API is out
of date, and the kubebuilder code probably is as well, but the same
basic steps can be repeated when we are ready to do the work.

As much effort as possible should be made to preserve the git history
of files such as the API definition and the controller
implementation. Unfortunately, these significant files will also have
to be changed beyond their location within the repository, so
preserving all of the history may not be possible.

### User Stories

#### Story 1

As a contributor to the baremetal-operator, I want to use familiar
tools and workflows so I can take advantage of my experience
contributing elsewhere in the kubernetes community to work more
efficiently.

#### Story 2

As a contributor to the baremetal-operator, I want to be able to make
API changes to the BareMetalHost and support conversion web hooks to
change between different storage versions.

#### Story 3

As a contributor to the baremetal-operator, I want to be able to use
admission web hooks to validate BareMetalHost resources.

## Design Details

The process for creating the proof-of-concept migration was basically:

1. Move everything in the git repository out of the way.
1. Remove the copy of operator-sdk.
1. Use kubebuilder init to create a new project in the repository,
   setting the domain to an empty string.
1. Update the kubebuilder and controller-gen settings to allow "unsafe
   fields".
1. Use kubebuilder to create an API and controller for BareMetalHost,
   then replace the implementations with the existing ones.
1. Restore the rest of the existing code from the pkg directory,
   moving it to the root of the repository.
1. Fix everything so it compiles and the tests run.
1. Add missing targets to the Makefile (lint, sec, openapi generation,
   etc.).

### Implementation Details/Notes/Constraints

Using `git mv` as often as possible will help link the new files to
their history in any old locations.

Using an empty string for the domain argument to `kubebuilder init`
means that we can specify a group of `"metal3.io"` when creating the
host API, and avoid ending up renaming the resource type. Future APIs
should include a more well-scoped group ("networking.metal3.io" or
"hardware.metal3.io") but changing the group name for the existing
resource will make it exceptionally difficult to upgrade.

### Risks and Mitigations

Although operator-sdk and kubebuilder both use the same underlying
code generation library, and are trying to achieve parity, they are
likely to be using different versions and options from time to
time. The new implementation will therefore introduce updated
dependencies, and the longer we put off the work the more likely those
dependencies are to require code changes. We will mitigate some of
that risk by forking the tool(s), which lets us lock in a specific
version to use.

Bug fixes will be more challenging to backport after the migration,
because the code layout will be different. This risk is mitigated by
the fact that we do not maintain old versions of the
baremetal-operator today, and maintain backwards compatibility in all
changes. The new implementation should also be API-compatible with the
older implementation. We can create a maintenance branch for anyone
using the baremetal-operator who wishes to support the older
implementation for any reason.

Effectively re-implementing something that works is inherently risky.
Most of the differences in the implementation will be in the generated
code that invokes the same controller runtime library, though, which
will minimize the changes in behavior.

Other projects that import the BMO code (CAPM3, CAPBM, etc.) will need
to update the import statements after upgrading to the new
implementation. Until the API of the BareMetalHost is changed, these
updates aren't strictly necessary, but if we do them sooner that will
make future API changes easier to follow.

### Work Items

1. Tag a release and create a maintenance branch for the
   baremetal-operator.
1. Follow a process as described in the Design Details section above
   to migrate to kubebuilder.
1. Tag a release to use for including in the cluster API providers.
1. Rebase all open PRs after the new implementation is approved.
1. Update the imports in CAPM3.
1. Update the imports and vendoring in CAPBM (only for downstream
   consumers).

### Dependencies

N/A

### Test Plan

The unit tests should pass with no changes except to their import
statements.

The integration tests should pass with no changes at all.

### Upgrade / Downgrade Strategy

The host API will not change, so upgrading and downgrading should be
transparent.

### Version Skew Strategy

N/A

## Drawbacks

None

## Alternatives

We could use a new version of the operator-sdk instead of
kubebuilder. The amount of work involved would be effectively the
same, though, and we should benefit from standardizing on tools for
all metal3 repositories.

## References

- The [kubebuilder3
  branch](https://github.com/dhellmann/baremetal-operator/tree/kubebuilder3)
  of dhellmann's fork of the baremetal-operator repository is a
  proof-of-concept implementation of the migration.
- The [v1alpha2 API
  migration](https://github.com/metal3-io/metal3-docs/pull/101)
  proposal.
- [operator-sdk 1.0 migration guide](https://sdk.operatorframework.io/docs/building-operators/golang/migration/)
- [migration implementation pull request](https://github.com/metal3-io/baremetal-operator/pull/655)
- updates to kustomize deployment files and CI fixes:
   - <https://github.com/metal3-io/baremetal-operator/pull/672>
   - <https://github.com/metal3-io/baremetal-operator/pull/674>
   - <https://github.com/metal3-io/baremetal-operator/pull/675>
   - <https://github.com/metal3-io/baremetal-operator/pull/676>
   - <https://github.com/metal3-io/baremetal-operator/pull/677>
   - <https://github.com/metal3-io/baremetal-operator/pull/679>
   - <https://github.com/metal3-io/metal3-dev-env/pull/510>
   - <https://github.com/metal3-io/cluster-api-provider-metal3/pull/137>
   - <https://github.com/metal3-io/cluster-api-provider-metal3/pull/138>
   - <https://github.com/metal3-io/baremetal-operator/pull/678>
- [baremetal-operator PR](https://github.com/metal3-io/baremetal-operator/pull/650)
