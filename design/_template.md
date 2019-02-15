<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Title

This is the title of the design.
Keep it simple and descriptive.

A good title can help communicate what the design is and should be
considered as part of any review.

The title should be lowercased and spaces/punctuation should be
replaced with `-`.

Some notes about the design process:

- Not all changes need a design document. Anything that is likely to
  result in significant review discussion, or changes to user-facing
  documentation, does.

- The aim of this document is first to define the problem we need to
  solve, and second agree the overall approach to solve that problem.

- This document is not intended to be extensive user-facing
  documentation for a new feature. It should provide enough detail for
  contributors to the project to understand the impact and help refine
  the design.

Some notes about using this template:

- The new document should be in [Markdown
  syntax](https://daringfireball.net/projects/markdown/syntax), like
  this template.

- Please wrap text at 79 columns.

- Please do not delete any of the sections in this template.  If you have
  nothing to say for a whole section, just write: None

To get started with this template:

1. **Make a copy of this template.**

    Copy this template into the `design` directory and name it
    `my-title.md`.

1. **Fill out the "overview" sections.**

    This includes the Summary and Motivation sections. Remove the
    boilerplate and instructions as you go.

1. **Create a PR.**

1. **Merge early.**

    Avoid getting hung up on specific details and instead aim to get
    the goal of the design merged quickly.  The best way to do this is
    to just start with the "Overview" sections and fill out details
    incrementally in follow on PRs.  View anything marked as a
    `provisional` as a working document and subject to change.  Aim
    for single topic PRs to keep discussions focused.  If you disagree
    with what is already in a document, open a new PR with suggested
    changes.

The canonical place for the latest set of instructions (and the likely
source of this file) is [here](/designs/_template.md).

## Status

One of: provisional|implementable|implemented|deferred|rejected|withdrawn|replaced

## Table of Contents

A table of contents is helpful for quickly jumping to sections of a
design and for highlighting any additional information provided beyond
the standard template.

[Tools for generating][] a table of contents from markdown are available.

<!--ts-->
   * [Title](#title)
      * [Status](#status)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
         * [Non-Goals](#non-goals)
      * [Proposal](#proposal)
         * [User Stories [optional]](#user-stories-optional)
            * [Story 1](#story-1)
            * [Story 2](#story-2)
         * [Implementation Details/Notes/Constraints [optional]](#implementation-detailsnotesconstraints-optional)
         * [Risks and Mitigations](#risks-and-mitigations)
      * [Design Details](#design-details)
         * [Work Items](#work-items)
         * [Dependencies](#dependencies)
         * [Test Plan](#test-plan)
         * [Upgrade / Downgrade Strategy](#upgrade--downgrade-strategy)
         * [Version Skew Strategy](#version-skew-strategy)
      * [Drawbacks [optional]](#drawbacks-optional)
      * [Alternatives [optional]](#alternatives-optional)
      * [References](#references)

<!-- Added by: stack, at: 2019-02-15T11:41-05:00 -->

<!--te-->

[Tools for generating]: https://github.com/ekalinin/github-markdown-toc

## Summary

The `Summary` section is important for producing high quality
user-focused documentation such as release notes or a development
roadmap.  It should be possible to collect this information before
implementation begins in order to avoid requiring implementors to
split their attention between writing release notes and implementing
the feature itself.  Reviewers should help to ensure that the tone and
content of the `Summary` section is useful for a wide audience.

A good summary is probably at least a paragraph in length.

## Motivation

This section is for explicitly listing the motivation, goals and
non-goals of this design.  Describe why the change is important and
the benefits to users, including what problem it solves.

### Goals

List the specific goals of the design.
How will we know that this has succeeded?

### Non-Goals

What is out of scope for this design?
Listing non-goals helps to focus discussion and make progress.

## Proposal

This is where we get down to the details of what the proposal actually is.

### User Stories [optional]

Detail the things that people will be able to do if the design is
implemented.  Include as much detail as possible so that people can
understand the "how" of the system.  The goal here is to make this
feel real for users without getting bogged down.

#### Story 1

#### Story 2

### Implementation Details/Notes/Constraints [optional]

- What are the caveats to the implementation?
- What are some important details that didn't come across above.
- Go in to as much detail as necessary here.
- This might be a good place to talk about core concepts and how they relate.

### Risks and Mitigations

What are the risks of this proposal and how do we mitigate.  Think
broadly.  For example, consider both security and how this will impact
the larger kubernetes ecosystem.

## Design Details

- What will actually need to change in the code?
- What new objects is this going to require?
- What new fields are needed, for either the Spec or Status section?
- What other changes (labels, annotations, etc.) are needed?

### Work Items

Work items or tasks -- break the feature up into the things that need to be
done to implement it.

### Dependencies

* Include specific references to work here or in other projects that
  this design either depends on or is related to.

* Does this feature require any new library dependencies or code
  otherwise not included in the code? Or does it depend on a specific
  version of library?

### Test Plan

Consider the following in developing a test plan for this enhancement:

- Will there be end-to-end and integration tests, in addition to unit
  tests?
- How will it be tested in isolation vs. with other components?

No need to outline all of the test cases, just the general strategy.

Anything that would count as tricky in the implementation and anything
particularly challenging to test should be called out.

All code is expected to have adequate tests.

### Upgrade / Downgrade Strategy

If applicable, how will the component be upgraded and downgraded? Make
sure this is in the test plan.

Consider the following in developing an upgrade/downgrade strategy for
this enhancement:

- What changes (in invocations, configurations, API use, etc.) is an
  existing cluster required to make on upgrade in order to keep
  previous behavior?
- What changes (in invocations, configurations, API use, etc.) is an
  existing cluster required to make on upgrade in order to make use of
  the enhancement?

### Version Skew Strategy

If applicable, how will the component handle version skew with other
components? What are the guarantees? Make sure this is in the test
plan.

## Drawbacks [optional]

Why should this design _not_ be implemented.

## Alternatives [optional]

Similar to the `Drawbacks` section the `Alternatives` section is used
to highlight and record other possible approaches to delivering the
value proposed by a design.

## References

Please add any useful references here. You are not required to have any
reference. Moreover, this specification should still make sense when your
references are unavailable. Examples of what you could include are:

- Links to mailing list or other discussions
- Links to relevant research, if appropriate
- Related designs, as appropriate
- Anything else you feel it is worthwhile to refer to
