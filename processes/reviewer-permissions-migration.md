# reviewer-permissions-migration

## Status

implementable

## Summary

We should use the OWNERS files in each repository to manage the list
of reviewers, instead of relying on the Github organization
membership.

## Motivation

As the metal3 community expands, we are inevitably going to find that
teams of people focus on different areas and different components. For
example, we recently added the hardware-classification-controller,
which is managed by some existing as well as new contributors. One of
the things we have to balance as we add new contributors is the trust
we extend and the obligations we place on them. I think we have grown
to a point where we need to change how we do that.

We have been using Github org membership as the way to indicate who
has permission to use /lgtm as part of approving
patches. Unfortunately, that extends to any repository in the org,
which means we have to trust someone quite a lot before we invite them
to be an org member. As we grow, this becomes more difficult to do
with blanket permissions across all of our repositories.

### Goals

1. Transition from github org membership to OWNERS files for reviewer
   permissions.

### Non-Goals

1. Define a new process for approving reviewers.
1. Change the process for approving approvers.
1. Change the permissions for managing the CI infrastructure.

## Proposal

Given the new repositories and teams, I think we should shift as much
as possible to using the OWNERS files in repositories, so that our
teams can manage the list of reviewers in each repository
independently. This will mean that the OWNERS file will manage
permissions for /lgtm as well as /approve.

### Implementation Details/Notes/Constraints

In order to make the change, we need to review the `OWNERS_ALIASES`
file(s) in each repository and update them to include the appropriate
list of reviewers. The `OWNERS` files in each repository will
reference these aliases, which contain the actual usernames for
reviewers and approvers. We have
[a process for approval permission](https://github.com/metal3-io/community/blob/main/maintainers/README.md),
but that does not apply to reviewers. We should give reviewer
permission more easily than approver permission, as a way to grow our
teams without friction, so we're going to want to have a separate
process for that.

If we focus on the transition for now, we can define that process
separately later. So, I propose that we take the contributors with 10
or more commits according to github's contribution list (via the page
like
<https://github.com/metal3-io/cluster-api-provider-metal3/graphs/contributors>)
as the initial set of reviewers for each repo. That will allow us to
complete the migration and we can expand the list further afterwards.

After we agree on this process, I will propose PRs to each repo to add
reviewers to the owners files. When we have merged those PRs, we can
change Prow's configuration to have it use the OWNERS file instead of
github org membership for /lgtm permissions. We should also update the
maintainers process document to include instructions for managing the
list of org members and for managing the reviewer list for a repo.

### Risks and Mitigations

If we miss a repository, the list of approvers for that repository
will also have reviewer permission so we can still merge patches.

### Work Items

- Add reviewers to OWNERS files in the root of all repositories
- Update Prow configuration to look for reviewers in the OWNERS files

## Alternatives

This change will not affect the commands to the Jenkins integration
jobs managed by Ericsson, like /test-integration. That tool chain only
looks at org membership, so all members of the organization will still
be able to trigger the Jenkins integration tests. This is however not
the case for the metal3-io/project-infra repository where only a
subset of people can trigger the Jenkins tests due to the sensitivity
of the information available (such as Github tokens).
