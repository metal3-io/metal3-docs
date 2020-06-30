# Metal3 Roadmap

The Metal3 Roadmap is maintained as a Github project and can be found
[here](https://github.com/orgs/metal3-io/projects/2).

## Description

Each column in the project represents the work items for a specific release of
either Baremetal Operator or Cluster API Provider Metal3. In addition there is
a `Feature requests` that contains item that have not yet been accepted and the
`Backlog` column that contains items that have been accepted but not yet
planned for a specific release.

## Proposing a feature

Proposing a new feature for a specific release of one of the components is done
by opening an issue in the metal3-docs repository, describing the feature and
which components and release are targeted. The new issue will automatically
appear in the feature request column of the roadmap.

## Updating the Roadmap

Updating the roadmap is done during a community meeting, with a discussion
within the members of the projects, alternatively through an email thread.
The update is performed by one of the approvers of the metal3-docs project.

A new feature proposal is moved from the `feature requests` column to a
component release column if agreed within the community, and a member
volunteers to take ownership of that feature. If a feature is seen as
necessary in the long-term without being planned for the releases defined,
it is then placed in the `Backlog` column. An issue from the `backlog` can be
moved to a specific release when someone volunteers to take ownership of the
issue.

An inactive issue in one of the releases (marked as stale) can be moved back to
the `Backlog` column.

