# Managing Reviewers

## Status

implementable

## Summary

After the migration to use OWNERS files to manage reviewers, it is
easier for us to add reviewers to separate repositories. This document
describes the process for adding reviewers to a metal3 project repo.

### Goals

1. Describe a process for adding reviewers.
1. Keep the process light-weight.

### Non-Goals

1. Change the process for adding [maintainers](https://github.com/metal3-io/community/tree/main/maintainers).

## Proposal

Anyone can propose a patch to update an OWNERS file in a repository to
add a reviewer. The patch should be submitted as a standalone PR,
rather than being linked to any other contribution.

The reviewer list for each repository will be pruned over time to
remove contributors who are inactive.

Reviewers may also be removed for behaving in a manner that other
maintainers view as detrimental to the project, following the process
described for maintainers in [Revoking Approval
Access](https://github.com/metal3-io/community/tree/main/maintainers/README.md#revoking-approval-access).

Pull requests to add or remove reviewers from OWNERS files should be
approved using the same policy as other changes: One person with
approval permission and another with at least reviewer permission must
accept the PR.

### Risks and Mitigations

Ideally new reviewers will have already contributed to the project,
either through code, documentation, reviews, or design
discussions. New contributors can be added to new repositories if they
are helping to launch a new sub-component.

### Dependencies

- [reviewer-permissions-migration](reviewer-permissions-migration.md)
