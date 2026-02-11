<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# api-design-principles

## Status

implemented

## Summary

This document describes the design principles being used to create the
metal3 API.

## Motivation

As our contributor community grows, having these principles written
down ensures we design new features in a consistent way.

### Goals

1. Describe the general principles for adding to or changing the API.

### Non-Goals

1. Prescribe specific API choices for future features.

## Proposal

### Grow Slowly

Given the backwards-compatibility constraints for APIs in general, we
want to take care when adding new features. When in doubt about a
design, wait to implement it. Waiting gives us time to find more use
cases and implementation details that may make it easier to choose the
right path.

### Be Explicit

All fields must have well-defined types. No files may use
`interface{}` types.

We have two primary reasons for requiring explicitly naming and typing
every API parameter.

1. Metal3 is meant to be an abstraction on top of a provisioning
   system. If we do not describe the API completely, the abstraction
   breaks and the user must understand another API in order to use
   ours. This exposes the underlying API in a way that makes it more
   difficult to change the metal3 API, while simultaneously making
   using metal3 for our users.
1. Future versions of kubernetes will improve support for OpenAPI
   validation, and will require good validation by default as a
   security measure. Passing unstructured data through the API and
   storing it exposes clusters to security issues if an API changes
   and new fields are added. See
   <https://www.youtube.com/watch?v=fatglKZYdSQ> for details.

### Don't Assume Ironic

Ironic is an implementation detail for the current version of
metal3. Although it has allowed us to move quickly, we do not want to
assume that we will continue to use it indefinitely or exclusively. We
should therefore not expose Ironic API-isms such as names or workflow
assumptions through the metal3 API.

### Don't Assume Machine API

Don't make assumptions about what the BaremetalHost will be used
for. The Machine API is not the only consumer and running a Kubernetes
node is not the only thing users may want to do with the Host.

### Not Every Feature Needs to Go into the baremetal-operator

Metal3 is designed to take advantage of the microservice nature of
kubernetes. New features may require changing the BareMetalHost
schema, but just as often it will be possible to add a new feature
using a new API.

Provisioning hosts can be complicated. The BareMetalHost API is
designed so the `baremetal-operator` can eliminate all of the
complexity beyond basic host management and provisioning
operations. Other APIs and controllers drive the decisions about how
to configure a host, which image to use, etc. For example, the
`cluster-api-provider-metal3` is separated from the
`baremetal-operator` so that we can plug Metal3 into the cluster API
ecosystem, but also so different hosts can be configured in different
ways using the Machine API and so the BareMetalHost API can be used by
tools other than the cluster API provider.

### Make Features Optional

We want to avoid making the Metal3 features so tightly coupled that in
order to use any of them a user has to deploy or enable all of
them. Where possible, features should be optional or pluggable so that
users can replace one of our implementations with one of their own, or
avoid using a feature or API entirely. This encourages adoption, by
allowing users to start with a simple configuration and add features
over time as they need them. It also makes it easier to integrate
Metal3 with downstream products, which may already have some or all of
the same features.

### Follow Kubernetes API Patterns

We want Metal3 APIs to be easy for new users to adopt. One way to
achieve that is to use patterns that are already common elsewhere in
other kubernetes APIs. New APIs should act like other parts of the
system. When designing a new Metal3 API, look at other APIs for
guidance, where parallels are available.
