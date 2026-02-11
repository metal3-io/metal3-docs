<!--
This work is licensed under a Creative Commons Attribution 3.0
Unported License.

http://creativecommons.org/licenses/by/3.0/legalcode
-->

# metal³ user-guide

<!-- cSpell:ignore asciidoctor -->

## Status

implementable

## Summary

Create the Metal³ user-guide which describes the fundamentals of
the project to make the user getting-started experience easier.

## Motivation

Currently all the documentation describing different parts
of the Metal³ project is scattered across different repositories
which doesn't bring a good user experience from the documentation
perspective.

### Goals

1. Use mdbook tool to create the online/web-based user-guide from
    the markdown-based documents available under /doc in metal3-docs Github repository.

1. Configure Netlify for the book preview as part of a PR review for document changes.

1. Write-down and add missing documents.

### Non-Goals

1. Create developer-guide

1. Keep HTML/CSS files within the repository

## Proposal

Use mdbook tool to build the user-guide for the Metal³ project, which
will combine documents under metal3-docs/docs and publish them as a single user-guide.

### User Stories

* As the Metal³ user I would like to have a document that would help me to
   get started with the project easily.

## Design Details

### Why mdbook

1. Renders a book content from markdown files

1. Automatically generates all the HTML/CSS files for you

1. Used by several open source projects including Kubernetes ecosystems such as
    Cluster API, Cluster-api-provider-aws, some docs of Kubernetes
    and etc.

1. Offers preview capabilities to detect issues before they get merged.

Netlify deployment will be configured for the metal3-docs repository to have a
preview process when a future commit introduces documentation changes.

**How do we keep the user-guide in sync with documentation changes in the
    metal3-docs repository?**

There are two possible ways for that.

1. Have a Makefile target/script in the Metal3-docs repository to build the user-guide
    from the current content. And configure Netlify automatic-triggering which will
    first run the Makefile target/script under Metal3-docs and then publish the output
    (i.e. final user-guide with updated content).

1. Add the script within Netlify to build the user-guide from the current content
    and configure Netlify automatic-triggering.

**Where do we store mdbook auto-generated files like CSS/HTML ?**

Since we are using Netlify, we don't have to store those files within the Metal3-docs
Github repository. Because, Netlify will run the mdbook binary, which will be looking
for the book structure file in `.toml` format. As such, the user-guide is generated
on the fly, and the output (i.e. online user-guide) is stored and published via
the Netlify URL.

**How will the book preview work when there is a PR with doc changes in the
    Metal3-docs repository?**

Netlify automatically gets triggered on every PR opened in the Metal3-docs repository.
And after that, it will follow either step1 or step2 (in question *How do we keep
the user-guide in sync with documentation changes in the metal3-docs repository?*)
and publish the final-user guide and a temporary URL.

**How often do we trigger the Netlify build for the final book?**

Netlify allows us to configure automatic-triggering N times per day. As such,
we can decide how many times in a day we want to trigger it. And it actually
depends on what's the frequency of PRs in the Metal3-docs repository. But since
the frequency of the documentation is very low we can configure it to be once a
day for now.

### Implementation Details/Notes/Constraints

Example flow of the doc changes and keeping the user-guide in sync:

* The user opened a PR to change user-guide related documents.

* Netlify gets triggered and publishes the user-guide based on the changes introduces
    in the PR.

* Maintainers reviewed the PR + the user-guide and PR is merged.

* Currently, the online-user guide is out of sync with the actual content in the
    Metal3-docs repository. However, it will be updated during the 24 hours, because
    the Netlify build is configured to be run once a day.

* Netlify got triggered and executed mdbook builds commands against the current
    content in the Metal3-docs repository. And publishes the final user-guide
    in the preassigned URL.

**Note:** The Netlify account provided by the CNCF will be used.

### Risks and Mitigations

None

### Work Items

1. Write down documentation
1. Create code-based architectures so that it is easy to modify after a while if
    there are architectural changes. Example via PlantUml
1. Configure the Netlify
1. Refactor the existing documents. This includes typos, indentation, etc.
1. Write down documentation
1. Create mdbook book structure

### Dependencies

None

### Test Plan

none

### Upgrade / Downgrade Strategy

None

### Version Skew Strategy

None

## Drawbacks

None

## Alternatives

Use asciidoctor.

*Advantages:*

1. Asciidoc provides easily referencing documents via the URL.
1. Can convert the book into different formats, such as HTML, PDF, etc.
1. Makes it easy to create a book with different versions of the product. For example,
    different versions of BMO can introduce new types, etc.

*Disadvantages:*

1. Asciidoc requires source documents to be in `.adoc` format.

## References

1. Mdbook: <https://github.com/rust-lang/mdBook>

1. Cluster-api book: <https://cluster-api.sigs.k8s.io/>

1. Cluster-api-provider-aws book: <https://cluster-api-aws.sigs.k8s.io/>

1. PlantUML: <https://plantuml.com/>

1. Asciidoctor: <https://asciidoctor.org/>
