<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Consumer Settings for BareMetalHost

## Status

provisional

## Summary

This design introduces a new field for BareMetalHost named consumerSettings.
Its lifespan cannot exceed the lifespan of the consumer it is associated to
(characterized by the consumerRef field).

consumerSettings contain various fields that were already present in the
BareMetalHost resource or some of its companion resources (HostFirmwareSettings
and HostFirmwareComponents). When they are defined, their value takes
precedence over the equivalent field in the ``spec`` part of the resource.

## Motivation

With the advent of HostClaims resource and the desire to share BareMetalHosts
between several tenants, it is clear that most BareMetalHost settings must
be cleared between bindings with different consumer resources.

On the other hand, it is desirable to define defaults values for most of those
fields. In some cases they contain instance specific values that the consumer
cannot guess before being bound. Those values are set by the infrastructure
manager.

### Goals

The goal of this new field is to provide a place for tenants to define their
settings without overwriting the defaults.

### Non-Goals

This design does not specify how and when specific settings are taken into
account by Ironic.

Ironic may delay the application of some settings (for example the cleaning
mode). As the consumer may unbind at any time, this may create some security
issues.

## Proposal

We introduce a ``consumerSettings`` field. It is an optional object containing
several fields. The field can be defined only if a consumer binds the host
(``consumerRef`` field is not nil).

The ``consumerSettings`` field contains at least the following fields:

* userData
* networkData
* metaData
* automatedCleaningMode

All those fields are necessary to implement the HostClaim proposal
while preserving the existence of infrastructure provided defaults.

The ``consumerSettings`` field may then be extended with the
following fields:

* raid,
* hostFirmwareSettings (to override the settings field of the
  HostFirmwareSettings resource associated to the BareMetalHost),
* hostFirmwareUpdates (to override the updates field of HostFirmwareComponent
  resource associated to the BareMetalHost).

## Design Details

### Implementation Details/Notes/Constraints

The constraint between the values of ``consumerRef`` and ``consumerSettings``
will be implemented in the bareMetalHost webhook. It is very easy to
make a CEL constraint but the webhook already exists.

Most of the changes are located in the BareMetalHost controller. Before setting
a field, the controller must check if an override exists and use the later.

The HostClaim controller will use the ``consumerSettings`` field and will never
touch the now protected fields in the bound BareMetalHost.

The Metal3Machine controller should be modified to use the consumerSettings
and get a cleaner semantics without corner cases especially for ``xxxData``
fields.

### Risks and Mitigations

Some field like ``automatedCleaningMode`` do not strictly specify the state of
the server (It specifies how the server will be cleaned for the *next*
deprovisioning). When we unbind a server, we must make sure that the disk are
cleaned before the next user even if the previous user disabled
cleaning. The existence of the field alone is not enough if we do not know
that an OS was provisioned and nobody cleaned the disk since.

### Work Items

The handling of the data fields will be done first, followed by the cleaning
mode. Implementation of other features can be done later.

### Test Plan

For each field it is important to check the transitions from infrastructure
default to user provided settings and back.

### Upgrade / Downgrade Strategy

The introduction of the new fields should not create any issue. Old controllers
(unmodified Metal3Machine controllers) will ignore the fields and continue to
modify the default fields.

The only risk is for controller that *steal* BareMetalHost by resetting the
``consumerRef`` field. If ``consumerSettings`` field is defined, the update
will fail.

## Drawbacks

None except the complexity linked to the number of fields.

## Alternatives

### HostClaims are directly handled by BareMetalHost controller

If the BareMetalHost controller is aware of HostClaims:

* it can access a bound HostClaim through the ConsumerRef,
* check that the binding is legitimate by checking the ``status.baremetalhost``
  field of the HostClaim,
* directly access the secrets associated to the HostClaim or any other field
  in the HostClaim (eg. automatedCleaningMode) and give them priority over
  the values stored in its own specification.

The main advantages are:

* it avoids copies of secrets.
* because secrets are not copied in the namespace of the BareMetalHost, they
  may stay hidden from administrators in charge of the servers.

The main drawbacks/risks are:

* it is HostClaim specific and will not benefit other BareMetalHost consumers
  (for example Metal3Machine).
* the expected configuration of the BareMetalHost is less readable for a human:
  he must access the HostClaim and check its settings.
* this is a huge change in the logic of the BareMetalHost controller that requires
  to mediate most access to the BareMetalHost specification through an abstract
  structure that can give priority to a HostClaim if it exists.
* there are more risk of reconciliation loops as BareMetalHost and HostClaim
  need to watch each other resource.

### Infrastructure manager disallow customizing some settings

If the secret pointed by some settings (typically NetworkData) do not respect
convention of the HostClaim controller (specific label, name convention or both),
it is considered as set by the infrastructure manager and cannot be overridden
by the HostClaim controller.
It is then an error for the end-user to try to set it and the field value can
only be nil in the HostClaim.

This is clearly less flexible than the proposal but does not require additional
fields. If this alternative proposal is followed, we could question the way
fields can be overridden by the metal3 machine controller (without HostClaims).

### Ignore infrastructure defaults when using HostClaims

This would clearly create security risks for some fields (automatedCleaningMode).
For cloudInit data, we could always follow the HostClaim settings and
either overwrite or reset the secrets depending on the value set in HostClaim.
In that case the way for the infrastructure to convey settings (typically
network configuration) to the end user is to use BareMetalHost metadata.

### Consumer settings for companion resources

For HostFirmwareSettings or HostFirmwareComponents, the ``consumerSettings``
field could be defined in the resource. This would be more modular but it would
be impossible to enforce the constraint that the setting is not set if there
is no consumer on the BareMetalHost.
