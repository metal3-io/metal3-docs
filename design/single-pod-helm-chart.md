<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Single-pod Helm chart

## Status

provisional

## Table of Contents

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

## Summary

Provide a Helm chart to deploy Metal3 and Ironic as a single
pod in a Kubernetes cluster.

## Motivation

### Goals

The goal is to support a popular way to deploy Kubernetes applications
to simplify creation of development environments on top of arbitrary
Kubernetes clusters.

Another goal to preare to set a standard for production-grade deployment
of Metal3 and its components.

### Non-Goals

Providing end-to-end bootstrap sequence for Metal3 and Ironic is not a
a goal of this design.

## Proposal

### User Stories [optional]

#### Story 1

As a user of Metal3, I want to install it in my existing Kubernetes
cluster using Helm.

### Implementation Details/Notes/Constraints [optional]

Initial implementation will includ 2 Helm charts that replicate
behavior and outcomes of metal3-dev-env scripts. The charts shall be added
as a separate repository in metal3-io space.

### Risks and Mitigations

None.

## Design Details

Helm charts will require a separate repository (metal3-helm-charts)
to be created.

In future, a CI environment that will build and test the charts,
will have to be created.

Potentially, the Helm charts will require changes in the way the
Docker images for components of Ironic and Metal3 are built. The
changes will include additional parameters that will be exposed
through the charts metadata (values.yaml files).

### Work Items

1. Create a Helm chart for Ironic and its components.
2. Create a Helm chart for ``cluster-api-provider-baremetal`` and
   ``baremetal-operator``.

### Dependencies

The charts require ``helm`` binary to build and deploy. 
Supported version of Helm is embedded in the charts.

### Test Plan

Testing strategy for Helm charts includes static code tests and
integration tests. Integration tests include verification of
deployment, update/upgrade and functional verification of the
resulting installation for both scenarios.

### Upgrade / Downgrade Strategy

None.

### Version Skew Strategy

None.

## Drawbacks [optional]

Helm charts do not immediately improve development environment
creation experience.

## Alternatives [optional]

Currently, the deloyment functionality is already implemented as
``metal3-dev-env`` scripts. Another alternative is to use plain
Kubernetes manifest from ```baremetal-operator/deploy`` for
deployment on K8s.

## References

None.
