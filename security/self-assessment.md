# Self-assessment of Security in Metal3
<!-- markdownlint-disable single-h1 -->

**NOTE: THIS IS VERY INITIAL AND WORK IN PROGRESS!**

*Any block quotes are the guiding words from the TAG security template and will
be removed going forward.*

> The Self-assessment is the initial document for projects to begin thinking about
> the security of the project, determining gaps in their security, and preparing
> any security documentation for their users. This document is ideal for projects
> currently in the CNCF **sandbox** as well as projects that are looking to
> receive a joint assessment and currently in CNCF **incubation**.

Metal3 has been in Sandbox since 2020, and is now applying for Incubation.

TODO: Link incubation PR and new template incubation PR.

> For a detailed guide with step-by-step discussion and examples, check out the
> free Express Learning course provided by Linux Foundation Training &
> Certification: [Security Assessments for Open Source
> Projects](https://training.linuxfoundation.org/express-learning/security-self-assessments-for-open-source-projects-lfel1005/).

TODO: Check that out.

# Table of contents

* [Metadata](#metadata)
   * [Security links](#security-links)
* [Overview](#overview)
   * [Actors](#actors)
   * [Actions](#actions)
   * [Background](#background)
   * [Goals](#goals)
   * [Non-goals](#non-goals)
* [Self-assessment use](#self-assessment-use)
* [Security functions and features](#security-functions-and-features)
* [Project compliance](#project-compliance)
* [Secure development practices](#secure-development-practices)
* [Security issue resolution](#security-issue-resolution)
* [Appendix](#appendix)

## Metadata

> A table at the top for quick reference information, later used for indexing.

TODO: Check if more languages need to be listed (Python, Shell, etc), SBOM
generation is in the todo list as well

|||
| -- | -- |
| Assessment Stage | Incomplete |
| Software | <https://github.com/metal3-io/> |
| Security Provider | No |
| Languages | Go |
| SBOM | No generated SBOM, but `go.mod` files are available for major repositories etc |

### Security links

> Provide the list of links to existing security documentation for the project. You may
> use the table below as an example:

| Doc | url |
| -- | -- |
| Security file | <https://book.metal3.io/security_policy> |
| Default and optional configs | Mostly Kustomize based: [CAPM3](https://github.com/metal3-io/cluster-api-provider-metal3/tree/main/config), [IPAM](https://github.com/metal3-io/ip-address-manager/tree/main/config), [BMO](https://github.com/metal3-io/baremetal-operator/tree/main/config), and so on. |

TODO.

## Overview

> One or two sentences describing the project -- something memorable and accurate
> that distinguishes your project to quickly orient readers who may be assessing
> multiple projects.

The Metal3 Project's mission is to empower organizations with a flexible,
open-source solution for bare metal provisioning that combines the benefits of
bare metal performance with the ease of use and automation provided by
Kubernetes.

### Background

> Provide information for reviewers who may not be familiar with your project's
> domain or problem area.

TODO: below is a copy of our Goals, which also give little background, but
we can put better text here.

There are a number of great open source tools for bare metal host provisioning,
including Ironic. Metal3 aims to build on these technologies to provide a
Kubernetes native API for managing bare metal hosts via a provisioning stack
that is also running on Kubernetes. We believe that Kubernetes Native
Infrastructure, or managing your infrastructure just like your applications, is
a powerful next step in the evolution of infrastructure management.

The Metal3 project is also building integration with the Kubernetes cluster-api
project, allowing Metal3 to be used as an infrastructure backend for Machine
objects from the Cluster API. These components integrate seamlessly to leverage
the Kubernetes ecosystem and automate the provisioning and management of
bare-metal infrastructure.

### Actors

> These are the individual parts of your system that interact to provide the
> desired functionality.  Actors only need to be separate, if they are isolated in
> some way.  For example, if a service has a database and a front-end API, but if
> a vulnerability in either one would compromise the other, then the distinction
> between the database and front-end is not relevant.
>
> The means by which actors are isolated should also be described, as this is
> often what prevents an attacker from moving laterally after a compromise.

#### Cluster API provider Metal3 (CAPM3)

TODO

#### IP Adress Manager (IPAM)

TODO

#### Baremetal Operator (BMO)

TODO

#### Ironic

TODO

#### Other supporting components

TODO

### Actions

> These are the steps that a project performs in order to provide some service or
> functionality.  These steps are performed by different actors in the system.
> Note, that an action need not be overly descriptive at the function call level.
> It is sufficient to focus on the security checks performed, use of sensitive
> data, and interactions between actors to perform an action.
>
> For example, the access server receives the client request, checks the format,
> validates that the request corresponds to a file the client is authorized to
> access, and then returns a token to the client.  The client then transmits that
> token to the file server, which, after confirming its validity, returns the
> file.

Something about applying manifests etc the k8s way. There is very little
command line or API access meant to be used directly by the user, but it does
not mean they don't exist for malicious actors, we'll talk about that later.

TODO.

### Goals

> The intended goals of the projects including the security guarantees the project
> is meant to provide (e.g., Flibble only allows parties with an authorization
> key to change data it stores).

There are a number of great open source tools for bare metal host provisioning,
including Ironic. Metal3 aims to build on these technologies to provide a
Kubernetes native API for managing bare metal hosts via a provisioning stack
that is also running on Kubernetes. We believe that Kubernetes Native
Infrastructure, or managing your infrastructure just like your applications, is
a powerful next step in the evolution of infrastructure management.

The Metal3 project is also building integration with the Kubernetes cluster-api
project, allowing Metal3 to be used as an infrastructure backend for Machine
objects from the Cluster API. These components integrate seamlessly to leverage
the Kubernetes ecosystem and automate the provisioning and management of
bare-metal infrastructure.

### Non-goals

> Non-goals that a reasonable reader of the project’s literature could believe may
> be in scope (e.g., Flibble does not intend to stop a party with a key from
> storing an arbitrarily large amount of data, possibly incurring financial cost
> or overwhelming the servers)

Something about virtual machines and clouds etc. Add a snippet for this.

TODO.

## Self-assessment use

This self-assessment is created by the Metal3 team to perform an internal
analysis of the project's security.  It is not intended to provide a security
audit of Metal3, or function as an independent assessment or attestation of
Metal3's security health.

This document serves to provide Metal3 users with an initial understanding of
Metal3's security, where to find existing security documentation, Metal3
plans for security, and general overview of Metal3 security practices, both
for development of Metal3 as well as security of Metal3.

This document provides the CNCF TAG-Security with an initial understanding of
Metal3 to assist in a joint-assessment, necessary for projects under
incubation.  Taken together, this document and the joint-assessment serve as a
cornerstone for if and when Metal3 seeks graduation and is preparing for a
security audit.

## Security functions and features

> * Critical.  A listing critical security components of the project with a brief
> description of their importance.  It is recommended these be used for threat
> modeling. These are considered critical design elements that make the product
> itself secure and are not configurable.  Projects are encouraged to track these
> as primary impact items for changes to the project.
> * Security Relevant.  A listing of security relevant components of the project
>   with brief description.  These are considered important to enhance the overall
> security of the project, such as deployment configurations, settings, etc.
> These should also be included in threat modeling.

TODO.

## Project compliance

> * Compliance.  List any security standards or sub-sections the project is
>   already documented as meeting (PCI-DSS, COBIT, ISO, GDPR, etc.).

TODO.

## Secure development practices

> * Development Pipeline.  A description of the testing and assessment processes
>    that the software undergoes as it is developed and built. Be sure to include
> specific information such as if contributors are required to sign commits, if
> any container images immutable and signed, how many reviewers before merging,
> any automated checks for vulnerabilities, etc.
> * Communication Channels. Reference where you document how to reach your team or
>    describe in corresponding section.
>    * Internal. How do team members communicate with each other?
>    * Inbound. How do users or prospective users communicate with the team?
>    * Outbound. How do you communicate with your users? (e.g. flibble-announce@
>      mailing list)
> * Ecosystem. How does your software fit into the cloud native ecosystem?  (e.g.
>    Flibber is integrated with both Flocker and Noodles which covers
> virtualization for 80% of cloud users. So, our small number of "users" actually
> represents very wide usage across the ecosystem since every virtual instance
> uses Flibber encryption by default.)

### Development Pipeline

* We run many linters and unit tests first, then e2e suite as required. If
   PR is touching a major feature, we run optional e2e feature suite. Most
   testing is configured via
   [Prow config](https://github.com/metal3-io/project-infra/blob/main/prow/manifests/overlays/metal3/config.yaml)
   and on top we run GH action based checks.
* Contributors are not required to sign commits, but they must sign DCO.
* Container images we build are not immutable or signed
* We normally require LGTM and approve from different persons, but it is not
   technically enforced. Self-reviewing is disabled.
* Administrators cannot bypass these Prow controls, force pushing is disabled
   regardless of permissions
* We have scheduled scans for CVEs with OSV-scanner (in progress to add it to
   all repositories), and security linters to find vulnerabilities in code,
   but no CVE scanner is run on PRs (yet)

TODO

### Communication Channels

Detailed from the
[community README.md](https://github.com/metal3-io/community/blob/main/README.md):

* We are available on Kubernetes [slack](http://slack.k8s.io/) in the
  [#cluster-api-baremetal](https://kubernetes.slack.com/messages/CHD49TLE7)
  channel
* Join to the [Metal3-dev](https://groups.google.com/forum/#!forum/metal3-dev)
  google group for the edit access to the
  [Community meetings Notes](https://docs.google.com/document/d/1IkEIh-ffWY3DaNX3aFcAxGbttdEY_symo7WAGmzkWhU/edit)
* Subscribe to the [Metal3 Development Mailing List](https://groups.google.com/forum/#!forum/metal3-dev)
  for the project related anouncements, discussions and questions.
* Come and meet us in our weekly community meetings on every
  Wednesday at 14:00 UTC on [Zoom](https://zoom.us/j/97255696401?pwd=ZlJMckNFLzdxMDNZN2xvTW5oa2lCZz09)
* If you missed the previous community meeting, you can still find the notes
  [here](https://docs.google.com/document/d/1IkEIh-ffWY3DaNX3aFcAxGbttdEY_symo7WAGmzkWhU/edit)
  and recordings [here](https://www.youtube.com/playlist?list=PL2h5ikWC8viJY4SNeOpCKTyERToTbJJJA)
* Find more information about Metal3 on [Metal3 Website](https://metal3.io)

TODO

### Ecosystem

CAPI ecosystem as a baremetal provider.

TODO.

## Security issue resolution

Security disclosure process and resolution is detailed in the project's
[security policy](https://book.metal3.io/security_policy) in detail.

## Appendix

> * Known Issues Over Time. List or summarize statistics of past vulnerabilities
>    with links. If none have been reported, provide data, if any, about your track
>    record in catching issues in code review or automated testing.
> * [CII Best
>    Practices](https://www.coreinfrastructure.org/programs/best-practices-program/).
>    Best Practices. A brief discussion of where the project is at with respect to
>    CII best practices and what it would need to achieve the badge.
> * Case Studies. Provide context for reviewers by detailing 2-3 scenarios of
>    real-world use cases.
> * Related Projects / Vendors. Reflect on times prospective users have asked
>    about the differences between your project and projectX. Reviewers will have
>    the same question.

### Known Issues Over Time

Metal3 has published three security advisories in its history:

* [Ironic and ironic-inspector may expose htpasswd files as ConfigMaps][ghsa-9wh7]
* [Unauthenticated access to Ironic API][ghsa-jwpr]
* [Unauthenticated local access to Ironic API][ghsa-g2cm]

In addition to published security advisories, we have received four more security
vulnerability disclosures that have been handled within two weeks of the
disclosure, resulting in no further actions taken.

[ghsa-9wh7]: https://github.com/metal3-io/baremetal-operator/security/advisories/GHSA-9wh7-397j-722m
[ghsa-jwpr]: https://github.com/metal3-io/ironic-image/security/advisories/GHSA-jwpr-9fwh-m4g7
[ghsa-g2cm]: https://github.com/metal3-io/ironic-image/security/advisories/GHSA-g2cm-9v5f-qg7r

### OpenSSF Best Practices

Metal3 has passing page in
[CII/OpenSSF Best Practices](https://www.bestpractices.dev/en/projects/9160)
and is at 167% completion level, working towards the Silver badge.

### Statistics

TODO

### Case Studies

[ADOPTERS](https://github.com/metal3-io/community/blob/main/ADOPTERS.md) description:

* Ericsson: As a Kubernetes distributor we are building Cloud Container
   Distribution (CCD) and integrating Metal3 project for baremetal deployments
   and for baremetal cluster LCM tasks.
* Red Hat: Red Hat's OpenShift distribution includes Metal3 as part of its
   solution for automating the deployment of bare metal clusters.
* SUSE: Metal3 is used for automated bare metal deployment as part of the
   SUSE Edge solution.

TODO

### Related Projects / Vendors

* [Canonical MaaS](https://maas.io/)
* [TinkerBell](https://tinkerbell.org/)
* [Equinix Metal](https://deploy.equinix.com/)

Comparison: TODO
