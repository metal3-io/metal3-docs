<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# host-profiles

## Status

One of: provisional

## Table of Contents

<!--ts-->
   * [host-profiles](#host-profiles)
      * [Status](#status)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
         * [Non-Goals](#non-goals)
      * [Proposal](#proposal)
         * [User Stories [optional]](#user-stories-optional)
            * [Controlling Types of Hosts Added to the Cluster](#controlling-types-of-hosts-added-to-the-cluster)
            * [Testing On New Host Types](#testing-on-new-host-types)
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

<!-- Added by: stack, at: 2019-02-15T13:56-05:00 -->

<!--te-->

## Summary

Host profiles allow us to match the hardware characteristics of a host
to provide a label similar to an instance flavor in a traditional
cloud environment. Host profiles are configurable through the
Kubernetes API, allowing cluster administrators to expand the known
hardware platforms and control how they are used in the cluster.

## Motivation

We want to limit the provisioning operations to known hardware
platforms, while making the set of known platforms easy to expand over
time. We do not want to hard-code the definitions, because that makes
it more difficult to configure development or test environments that
may not match what an expected production environment looks like.

### Goals

- Provide a place for us to store known hardware profiles.
- Provide a way to match known profiles to actual hardware.
- Provide a way to control how that hardware is used as part of a
  MachineSet.

### Non-Goals

This goal is about examining the hardware present in the host. It does
not consider whether that hardware is returning fault codes or
otherwise not working properly. Dealing with faulty hardware is
covered under a separate design.

For now, we only want to do simple matching based on data, and we do
not want a complex "language" to describe matching rules. It is enough
for hosts to look like the hardware described in the profile.

This design does not cover using the profile to control how software
is deployed to the host (specifying networking access, storage use,
etc.). That may come in a later design.

## Proposal

A new CRD, BareMetalHostProfile, is defined with Spec fields for all
of the relevant hardware considerations. Ideally this would reuse the
hardware specification data structure in the BareMetalHost itself, or
be a different structure that summarizes that structure (for example,
providing numCPUs and cpuGHz, fields but not a list of CPUs and their
individual speeds).

The Status portion of the BareMetalHostProfile will report all of the
BareMetalHosts and MachineSets associated with the profile.

*We need more detail about exactly what sort of hardware matching we
care about.*

When a profile is created, the profile operator causes all host
resources labeled as having an unknown profile to be reconciled to see
if they match the new profile. This means the order of creation for
hosts and profiles does not matter, because the match will happen
eventually.

When a profile is updated, the profile operator causes all host
resources associated with that profile to be reconciled to see if they
still match the updated profile.

### User Stories [optional]

Detail the things that people will be able to do if the design is
implemented.  Include as much detail as possible so that people can
understand the "how" of the system.  The goal here is to make this
feel real for users without getting bogged down.

#### Controlling Types of Hosts Added to the Cluster

The machine actuator in the cluster-api-provider-baremetal repository
will expect the template machine spec in the MachineSet to include the
name of a host profile, and will use that name to find hosts to add to
the set when it expands. This means that hosts with different profiles
will always be in different machine sets, and only hosts with profiles
named by a MachineSet will ever be included in the cluster.

#### Testing On New Host Types

To test a new hosts type or configuration, the cluster admin will
create a new profile CR populated with the relevant data and then add
host resources expected to match that profile. Then by creating a
MachineSet using the new profile name, they can bring those hosts into
the cluster.

### Implementation Details/Notes/Constraints [optional]

It is generally frowned upon to use the Kubernetes API as a "mere
database". Profiles are less reactive than some other other types of
resources, but their operator does work in conjunction with the host
operator to ensure matching is consistently applied. Host configs are
another example of this pattern.  On the other hand, we might not
actually need a second controller, if we set the watch rules up in the
host operator. The choice for how to handle that will be made based on
which implementation is easier to understand.

### Risks and Mitigations

Cluster admins will have access to APIs to add host profiles on their
own, leading to deployments on hardware configurations not supported
by their vendor. The vendor can reject support requests for these
configurations.

## Design Details

### Work Items

- Define a new BareMetalHostProfile CRD in the baremetal-operator git
  repo.
- Add a controller for the BareMetalHostProfile CRD in the
  baremetal-operator git repo.
- The logic to match a BareMetalHostProfile (profile) to a
  BareMetalHost (host) is implemented as a module within the
  baremetal-operator git repo.
- A new controller for the profile CRD is added to the
  baremetal-operator git repo.
- When a host is created, or a profile triggers its reconciliation,
  the match logic is invoked by the operator for the host CR, which
  updates the `metalkube.org/hardware-profile` label on the host to
  associate it with the profile.
- Add a tool to the dev-scripts git repo to create virtual machines
  matching a couple of standard dev/test profiles.

### Dependencies

None

### Test Plan

There will be unit tests for the profile matching logic.

There will be end-to-end tests for the use of profiles to manage
hosts.

Most developers will run with profiles describing virtual machines,
which can be varied to ensure that the rest of the project does not
make assumptions about hardware details.

### Upgrade / Downgrade Strategy

Upgrades of the baremetal-operator can come with additional YAML files
to define host profiles for common hardware configuration so that they
are installed automatically when the operator is upgrade.

Existing resources will not require modification on upgrade.

### Version Skew Strategy

This does not apply because the only other consumer of the profile is
the machine actuator, which only knows the name of a profile and does
not use any of the details.

## Drawbacks [optional]

See comments in the Risks section above.

## Alternatives [optional]

1. **Build the data into the baremetal-operator.** We would prefer a
   more data-driven approach that allows us to separate production
   profiles from dev/test profiles.
2. **Use a ConfigMap with profile data.**

## References

None
