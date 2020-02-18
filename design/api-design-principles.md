<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# api-design-principles

## Status

provisional

## Table of Contents

<!--ts-->
   * [api-design-principles](#api-design-principles)
      * [Status](#status)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
         * [Non-Goals](#non-goals)
      * [Proposal](#proposal)
         * [Grow Slowly](#grow-slowly)
         * [Be Explicit](#be-explicit)
         * [Don't Assume Ironic](#dont-assume-ironic)

<!-- Added by: dhellmann, at: Thu Oct 10 15:44:40 EDT 2019 -->

<!--te-->

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
2. Future versions of kubernetes will improve support for OpenAPI
   validation, and will require good validation by default as a
   security measure. Passing unstructured data through the API and
   storing it exposes clusters to security issues if an API changes
   and new fields are added. See
   https://www.youtube.com/watch?v=fatglKZYdSQ for details.

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
