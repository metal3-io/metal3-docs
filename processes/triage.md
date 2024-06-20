# Title

Metal3 Issue Triage Process

## Status

provisional

## Summary

In order to ensure that issues reported by Metal3 users are reviewed on
a consistent basis, we should meet on a regular schedule in a live
meeting to review newly submitted issues, and on some recurring basis
look at potentially stale issues for consideration whether it should be
closed, increase priority, etc.

## Proposal

During the triage process, the moderator should go through each of the
subcategories listed below and apply the process to each issue.

### New Issue Triage

[GitHub Search
Query](https://github.com/metal3-io/metal3-docs/issues?q=is%3Aissue+is%3Aopen+no%3Alabel):
`archived:false user:metal3-io no:label is:issue sort:created-asc
is:open`

- Evaluate if the issue is still relevant.
   - If not, close the issue.
- Determine the kind, and apply the right label. For example: bug, feature, etc.
- Make a best guess at priority, if the issue isn't actively being
  worked on
- If needed, ask for more information from the reporter or a
  developer. Label this issue `priority/awaiting-evidence`.
- Mark trivial issues as `good first issue`

### Awaiting Evidence

[GitHub Search
Query](https://github.com/metal3-io/metal3-docs/issues?q=is%3Aissue+is%3Aopen+label%3Apriority%2Fawaiting-more-evidence):`archived:false
user:metal3-io is:issue sort:created-asc is:open
label:priority/awaiting-more-evidence`

- Review if the required evidence has been provided, if so, change the
  priority/kind as needed, or close the issue if resolved.

### Stale Issues

[GitHub Search
Query](https://github.com/metal3-io/metal3-docs/issues?q=is%3Aissue+is%3Aopen+label%3Alifecycle%2Fstale):
`archived:false user:metal3-io is:issue sort:created-asc is:open
label:lifecycle/stale`

- There are periodic jobs in Prow that mark issues stale after 90 days of
  inactivity.
- After 30 additional days of inactivity, issues will be closed.
- Every other triage (e.g. once per 30 days), the stale issues should
  be reviewed to ensure that no critical issues we want to keep open
  would be closed.
