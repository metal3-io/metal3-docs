# Metal3 Self-assessment
<!-- markdownlint-disable single-h1 no-emphasis-as-heading -->
<!-- cSpell:ignore roadmapping,Kubed,controlplanes,htpasswd -->

> This self-assessment document is intended to identify security insights of
> Metal3 project, aid in roadmapping and a tool/documentation for onboarding new
> maintainers to the project.

Metal3 has been in CNCF Sandbox since 2020, and is now applying for
[Incubation](https://github.com/cncf/toc/issues/1365).

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

|                   |                                              |
| ----------------- | -------------------------------------------- |
| Assessment Stage  | In Progress                                  |
| Software          | <https://github.com/metal3-io/>              |
| Security Provider | No                                           |
| Languages         | Go, Bash, Python                             |
| SBOM              | Metal3 does not generate SBOMs currently     |

### Security links

| Document      | URL                                              |
| ------------- | ------------------------------------------------ |
| Security file | <https://book.metal3.io/security_policy>         |

## Overview

The Metal3 Project (pronounced: "Metal Kubed") empowers organizations with a
flexible, open-source solution for bare metal provisioning that combines the
benefits of bare metal performance with the ease of use and automation provided
by Kubernetes. Metal3 provides a comprehensive set of components for baremetal
host management with Kubernetes, so that a user can enroll user's baremetal
machines, provision operating system images, deploy Kubernetes clusters on them
and manage the lifecycle of the Kubernetes cluster, baremetal server and
applications, all through Kubernetes native APIs.

### Background

Metal3 is an open-source technology which enables users to provision and
manage a baremetal server's lifecycle using Kubernetes native APIs. There are
a number of great open source tools for bare metal host provisioning, including
Ironic. Metal3 aims to build on these technologies to provide a Kubernetes
native API for managing bare metal hosts via a provisioning stack that is also
running on Kubernetes. We believe that Kubernetes Native Infrastructure, or
managing your infrastructure just like your applications, is a powerful next
step in the evolution of infrastructure management.

The Metal3 project is also an infrastructure provider with the Kubernetes
Cluster API project, allowing Metal3 to be used as an infrastructure backend for
Machine objects from the Cluster API. These components integrate seamlessly to
leverage the Kubernetes ecosystem and automate the provisioning and management
of bare-metal infrastructure.

This is paired with one of the components from the OpenStack ecosystem, Ironic
for booting and installing machines. Metal³ handles the installation of Ironic
as a standalone component (there's no need to bring along the rest of
OpenStack). Ironic is supported by a mature community of hardware vendors and
supports a wide range of bare metal management protocols which are continuously
tested on a variety of hardware. Backed by Ironic, Metal³ can provision
machines, no matter the brand of hardware.

### Actors

Metal3 as a project bundles the following actors together:

#### Cluster API provider Metal3 (CAPM3)

The Cluster API brings declarative, Kubernetes-style APIs to cluster creation,
configuration and management. The API itself is shared across multiple
infrastructure providers. Cluster API Provider Metal3 (CAPM3) is one such
provider for Cluster API which enables users to deploy a Cluster API based
cluster on top of bare metal infrastructure using Metal3. On the one hand it
acts as a plugin for Cluster API and brings in the flexibility of simplified
Kubernetes cluster management, and on the other hand it interfaces with
Baremetal operator (a controller which manages Baremetal Host API) to manage
baremetal servers' lifecycle through simple Kubernetes native APIs.

#### IP Address Manager (IPAM)

The IP Address Manager (IPAM) is an actor in Metal3 which manages static IP
allocations for baremetal hosts. IPAM handles allocations of IPs from subnet
according to the requests without handling any use of those addresses. IPAM
simply keeps track of IP pools and allocations. It is then up to the consumers
to act on the information. It can share a pool across different types of CAPI
machine objects (controlplanes and machine deployments), allow non-continuous
pools and external IP management by using IPAddress CRDs, offer predictable IP
addresses and other useful IPAM features as well. Currently, IPAM is deployed as
part of CAPM3 provider, however there's significant effort currently in the
project towards making Metal3 IPAM and independent IPAM provider for CAPI.

#### Baremetal Operator (BMO)

The Bare Metal Operator (BMO) is a Kubernetes controller that manages bare-metal
hosts, represented in Kubernetes by BareMetalHost (BMH) custom resources.

BMO is responsible for the following operations:

* Inspecting the host's hardware and reporting the details on the corresponding
   BareMetalHost. This includes information about CPUs, RAM, disks, NICs, and
   more.
* Optionally preparing the host by configuring RAID, changing firmware settings
   or updating the system and/or BMC firmware.
* Provisioning the host with a desired image.
* Cleaning the host's disk contents before and after provisioning.

Under the hood, BMO uses Ironic to conduct these actions.

#### Ironic

Ironic is an open-source service for automating provisioning and lifecycle
management of bare metal machines. It is known as the baremetal service for
OpenStack and it is a powerful tool on its own, adding ways to be deployed
independently as a standalone service, for example using Bifrost, and integrates
in other tools and projects, as in the case of Metal3. As mentioned above,
Metal³ handles the installation of Ironic as a standalone component. Bare Metal
Operator is the main component that interfaces with the Ironic API for all
operations needed to provision bare-metal hosts, such as hardware capabilities
inspection, operating system installation, and re-initialization when restoring
a bare-metal machine to its original status. Metal3 provides a way to install
Ironic with a suitable configuration. Currently Metal3 is in the process of
introducing a stand alone operator to deploy ironic instances.

Alternatively, Bare Metal Operator can be set up to use an externally managed
Ironic instance.

### Actions

Metal3 follows the Kubernetes declarative model where users interact with the
system by creating, updating and deleting Kubernetes custom resources. The main
actions flow through several key components:

1. Users submit Kubernetes manifests (CRs) to define desired state for baremetal
   hosts and clusters
1. CAPM3 (Cluster API Provider Metal3) receives the desired state of the
   cluster, the machine specs and infrastructure configurations. It sets the
   infrastructure components accordingly, interacts with IPAM for static IP
   allocation and also communicates the desired state of the Metal3 machine and
   chooses a baremetal host to be consumed accordingly.
1. Baremetal Operator validates and processes BareMetalHost resources,
   performing security checks on credentials and configurations
1. BMO interacts with Ironic using authenticated API calls to execute the actual
   provisioning operations
1. IPAM manages IP address allocation requests securely through IPAddress custom
   resources
1. All component interactions happen through the Kubernetes API server,
   inheriting its authentication and authorization controls

The security boundary between components is maintained through:

* Kubernetes RBAC controls for API access
* Authentication between components
* Mutual TLS configuration
* Validation of all inputs before processing
* Secure storage of sensitive data like BMC credentials in Kubernetes secrets

### Goals

There are a number of great open source tools for bare metal host provisioning,
including Ironic. Metal3 aims to build on these technologies to provide a
Kubernetes native API for managing bare metal hosts via a provisioning stack
that is also running on Kubernetes. We believe that Kubernetes Native
Infrastructure, or managing your infrastructure just like your applications, is
a powerful next step in the evolution of infrastructure management.

The Metal3 project is also an infrastructure provider with the Kubernetes
Cluster API project, allowing Metal3 to be used as an infrastructure backend for
Machine objects from the Cluster API. These components integrate seamlessly to
leverage the Kubernetes ecosystem and automate the provisioning and management
of bare-metal infrastructure.

### Non-goals

Metal3's non-goals include:

* Non-baremetal hardware provisioning
* Direct hardware management without Ironic
* Operating system configuration management after provisioning
* Network provisioning or SDN implementation
* Providing a standalone solution outside of Kubernetes
* Exposing full set of Ironic features

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

**Critical**

* Ironic: Ironic is the ultimate component which provisions the bare metal
   hosts, talks to the real hardware and is able to perform very destructive or
   malicious actions.

**Security Relevant**

* Ironic Python Agent (IPA): Ironic's agent counterpart that is responsible for
   doing initial bootstrapping of the node.
* Bare Metal Operator (BMO): Currently BMO has cluster-wide K8s Secret access
   so it can read BMC secrets from any namespace. This is needed as access to
   BareMetalHost CRDs which are separated from the secrets, to enable role
   separation for the users and admins.
* Cluster API Provider Metal3 (CAPM3): CAPM3 has cluster-wide access to BMH
   CRDs which can be used to change the installation content. It also has access
   to supplied `userData`, which might contain sensitive information.

## Project compliance

The Metal3 project does not comply with any specific security standard.

## Secure development practices

**Development Pipeline**

* We run many linters and unit tests first, then e2e suite as required. If
   PR is touching a major feature, we run optional e2e feature suite. Most
   testing is configured via
   [Prow config](https://github.com/metal3-io/project-infra/blob/main/prow/config/config.yaml)
   and on top we run GH action based checks.
* Contributors are not required to sign commits, but they must sign-off the
   code for DCO.
* Container images or other release artifacts we build are not immutable or
   signed at the time.
* We normally require LGTM and approve from different persons, but it is not
   technically enforced. Self-reviewing is disabled. Only whitelisted owners
   are allowed to give LGTM and approve. Metal3 organization membership does
   not give reviewer rights.
* Administrators cannot bypass these Prow controls, force pushing is disabled
   regardless of permissions
* We have scheduled scans for CVEs with OSV-scanner (in progress to add it to
   all repositories), and security linters to find vulnerabilities in code,
   but no CVE scanner is run on PRs (yet)
* All Metal3 repos use Dependabot configured with regular scans for all
   projects, including automatic update PRs. Some have alternatively Renovate
   bot configured.
* Most of the containers, GitHub actions and downloaded dependencies are pinned
   and are required to stay so.
* We do not have fuzzing.

**Communication Channels**

Detailed from the
[community README.md](https://github.com/metal3-io/community/blob/main/README.md):

* We are available on Kubernetes [slack](http://slack.k8s.io/) in the
   [#cluster-api-baremetal](https://kubernetes.slack.com/messages/CHD49TLE7)
   channel
* Join to the [Metal3-dev](https://groups.google.com/forum/#!forum/metal3-dev)
   google group for the edit access to the
   [Community meetings Notes](https://docs.google.com/document/d/1IkEIh-ffWY3DaNX3aFcAxGbttdEY_symo7WAGmzkWhU/edit)
* Subscribe to the
   [Metal3 Development Mailing List](https://groups.google.com/forum/#!forum/metal3-dev)
   for the project related announcements, discussions and questions.
* Come and meet us in our weekly community meetings on every
   Wednesday at 14:00 UTC on
   [Zoom](https://zoom.us/j/97255696401?pwd=ZlJMckNFLzdxMDNZN2xvTW5oa2lCZz09)
* If you missed the previous community meeting, you can still find the notes
   [here](https://docs.google.com/document/d/1IkEIh-ffWY3DaNX3aFcAxGbttdEY_symo7WAGmzkWhU/edit)
   and recordings
   [here](https://www.youtube.com/playlist?list=PL2h5ikWC8viJY4SNeOpCKTyERToTbJJJA)
* Find more information about Metal3 on [Metal3 Website](https://metal3.io)

### Ecosystem

Metal3 is deeply integrated into the cloud native ecosystem. It integrates with
OpenStack Ironic for provisioning operations and functions as a provider within
the Cluster API (CAPI) ecosystem, implementing the CAPI specification for
declarative management of bare metal infrastructure. As part of both the
Kubernetes and CAPI ecosystems, Metal3 provides the foundation for organizations
to treat physical infrastructure as programmable resources within their
Kubernetes clusters.

## Security issue resolution

Security disclosure process and resolution is detailed in the project's
[security policy](https://book.metal3.io/security_policy) in detail.

Examples of past security advisories can be found in Appendix.

## Appendix

**Known Issues Over Time**

Metal3 has had four vulnerabilities:

* [Ironic and ironic-inspector may expose htpasswd files as ConfigMaps](https://github.com/metal3-io/baremetal-operator/security/advisories/GHSA-9wh7-397j-722m)
* [Unauthenticated access to Ironic API](https://github.com/metal3-io/ironic-image/security/advisories/GHSA-jwpr-9fwh-m4g7)
* [Unauthenticated local access to Ironic API](https://github.com/metal3-io/ironic-image/security/advisories/GHSA-g2cm-9v5f-qg7r)
* [BMO can expose particularly named secrets from other namespaces via BMH CRD](https://github.com/metal3-io/baremetal-operator/security/advisories/GHSA-pqfh-xh7w-7h3p)

> * Case Studies. Provide context for reviewers by detailing 2-3 scenarios of
>    real-world use cases.
> * Related Projects / Vendors. Reflect on times prospective users have asked
>    about the differences between your project and projectX. Reviewers will have
>    the same question.

**OpenSSF Best Practices**

Metal3 has passing page in
[CII/OpenSSF Best Practices](https://www.bestpractices.dev/en/projects/9160)
and is at 167% completion level, working towards the Silver badge.

### Case Studies

* Ericsson: As a Kubernetes distributor we are building Cloud Container
   Distribution (CCD) and integrating Metal3 project for baremetal deployments
   and for baremetal cluster LCM tasks.
* Red Hat: Red Hat's OpenShift distribution includes Metal3 as part of its
   solution for automating the deployment of bare metal clusters.
* SUSE: Metal3 is used for automated bare metal deployment as part of the
   SUSE Edge solution.

More use-cases can be found in our
[ADOPTERS.md](https://github.com/metal3-io/community/blob/main/ADOPTERS.md).

### Related Projects / Vendors

* [Canonical MAAS](https://canonical.com/maas) - An open source bare metal provisioning
  and lifecycle management system. MAAS treats physical servers like virtual
  instances in the cloud, providing API-driven IPAM, PXE boot, hardware
  inventory, and operating system deployment. It operates as a standalone
  solution with its own control plane, separate from Kubernetes.

* [Tinkerbell](https://tinkerbell.org/) - A CNCF sandbox project for bare metal
  provisioning and workflow management. It provides a cloud-native, API-driven
  approach using microservices architecture. While it can work alongside
  Kubernetes, it maintains its own workflow engine and focuses on
  hardware-specific actions through custom workflows.

Metal3 differentiates itself through its native Kubernetes integration, using
CustomResourceDefinitions (CRDs) and controllers to manage bare metal
infrastructure as part of the Kubernetes ecosystem. It leverages the mature
Ironic project for actual provisioning while providing Kubernetes-native
abstractions through the Cluster API provider model.
