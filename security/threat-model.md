# Threat model of Metal3

**NOTE: THIS IS VERY INITIAL AND WORK IN PROGRESS!**

*Any block quotes are the guiding words from the TAG security template and will
be removed going forward.*

> STRIDE Model

## Spoofing Identity

* Threat: Actor social engineers operator to give him/her more access than they
   should
* Mitigations:
   * In Metal3, there are no user identities. Users are given rights to perform
      actions based on the k8s RBAC, such as creating, editing or deleting
      Metal3 objects. Operators must be mindful what RBAC rights are given out

## Tampering with data

* Threat: Actor can change data or configuration without credentials
* Mitigations:
   * Ironic needs to be configured with authentication in place. Ironic allows
      no authentication scheme for testing and development, but it must not be
      used in production. Similarly, the networks must be configured in a way
      that non-party actors cannot reach them. Ironic is configured to use
      hostnetworking, hence it is possible to expose it for unintended
      interfaces

## Repudiation

* Threat: Actor can remove logs and/or crash the container after performing
   malicious actions
* Mitigations:
   * Logs should be forwarded outside the system to a log collection service
      that is not modifiable by the actor

## Information Disclosure

* Threat: Actor can read configuration files, environment variables and secrets
   from the cluster/container
* Mitigations:
   * Access to such information should be limited by the operator by restricting
      users with relevant RBAC rules and not allowing direct container access

## Denial of Service

* Threat: Actor is able to produce so many CRDs and events that the reconcile
   loop cannot process them fast enough due rate limits, hence hindering the
   speed of operations and eventually running out of memory and cycles
* Mitigations:
   * QPS and rate limit settings need to be adapted to suit the use case

## Elevation of Privilege

* Threat: Actor gets holds of serviceaccount privileges in a Metal3 container
   and is using the rights allowed by the RBAC to read secrets that allow
   privilege escalation in the cluster
* Mitigations:
   * RBAC rules should be restricted to relevant namespaces, unless the operator
      allows users to use namespaces with arbitrary names
