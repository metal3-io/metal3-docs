# Add non-bootable iso attach API to BareMetalHost

## Status

Implementable

## Summary

Add a new field in BareMetalHost so that it is possible to attach a generic
non-bootable iso image via Ironic, after the host has been provisioned.

## Motivation

In certain scenarios it is desirable to attach a non-bootable iso image
to a system after provisioning has finished, for example :

A configuration ISO can be used to provide first-boot configuration to a host
deployed from a standard image in advance. An operator may have a pool of
powered off hosts with operating system already provisioned. Then, adding
a host to the cluster boils down to powering it on with a configuration ISO provided.

### Goals

Expose the Ironic API to attach non-bootable iso images via Metal3.

### Non-Goals

Supporting non-ISO images such as a USB stick.

## Proposal

### BMO Proposal

Add a new optional section in the BareMetalHost spec containing details of the
non-bootable iso image, example :

```yaml
  spec:
    dataImage:
      url: http://1.2.3.4/image.iso
      credentialsName: dataimage-secret
      disableCertificateVerification: false
```

Secret holding the image url credentials, base64 encoded :

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: dataimage-secret
type: Opaque
data:
  username: dGVzdA==
  password: cGFzc3dvcmQ=
```

Note that in this case, the iso image will be attached after the node
has been provisioned or ExternallyProvisioned.

### Ironic Proposal

The [proposal](https://bugs.launchpad.net/ironic/+bug/2033288) for exposing this functionaility in Ironic has been
accepted by the upstream Ironic community.

## Design Details

Add an optional section `DataImage` to `BareMetalHostSpec`, with sub-fields
`Url`, `CredentialsName`, `DisableCertificateVerification` and a secret
for dataImage with name `CredentialsName`.

The ISO will be attached when the host is in either the `StateProvisioned` or
the `StateExternallyProvisioned` state before `actionManageSteadyState` is
called to maintain the State and manage the host power status.

We want to attach the non-bootable ISO without an extra reboot.

### Implementation Details

**ToDo** : Explicitly and clearly define the order of actions for the
below scenarios.

What should be the order of action for attaching the ISO without an extra
reboot(i.e attaching when the host is poweredoff), when :

**Scenario 1** : `externallyProvisioned: true, online: true, dataImage: <set>`

* Proposed workflow : "attach dataImage" -> ManageSteadyState

**Scenario 2** : `image: <set>, online: true, dataImage: <set>`

* Proposed workflow : "mount image" -> provision -> "provisioning finished"-> "detach image" -> "attach dataImage" ->  ManageSteadyState

## Dependencies

There is a dependency on the implementation(based on the proposal shared
above) on Ironic side to finish for this feature to work. But this doesn't
block the development of the BMO API.

## Upgrade / Downgrade Strategy

This feature is added to the BareMetalHost API as an optional field, so all the
existing BareMetalHost definitions should continue to work as before.

This feature will become available after upgrade, and downgrade is also
possible as long as the corresponding fields are not used.

## Alternatives

We can also achieve this using the existing `BMH.Spec.Image` field, but this
attempts to change the boot order of the system and relies on the host to
fallback to the installed system when booting the image fails.