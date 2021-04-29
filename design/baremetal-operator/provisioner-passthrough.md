<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Add provisioner passthrough API to BareMetalHost

## Status

implementable

## Summary

Add a new interface so that it is possible to configure any provisioner specific options.

## Motivation

In some circumstances it is desirable to use some provisioner specific features that
can't be exposed to generic operator interface, e.g. ironic ansible deploy driver,
ironic vendor passthrough options etc.

### Goals

Expand the Operator API to make it possible to expand provisioners without
furhter API changes.

### Non-Goals

Do not try to describe all known provisioner specific options in the Operator API.

## Proposal

Add a option to the BareMetalHost spec which indicates additional options to
provisioner:

```yaml
  spec:
    privisionerPassthrough:
      ironic:
        driver: ansible
        ansible_extra:
          foo: bar
```

### Work Items

- Add generic passthrough parameter to BareMetalHost.Spec.
- Implement any provisioner specific options as needed.

### Upgrade / Downgrade Strategy

This new format is added to the BMH API as an optional new interface, all existing
BMH interfaces should continue to work as before.

On upgrade this new interface will become available, and once in use it will not
be possible to downgrade, which given the expected use in net-new deployments
is probably reasonable.

## Alternatives

Proceed through Operator API changes to expose every single yet unreachable
provisioner specific feature.
