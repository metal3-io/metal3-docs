<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Host BMC Settings API

## Status

implementable

## Summary

This design proposes new API resources for managing BMCs. These include
operations such as changing passwords or configuring networking for the BMC.

## Motivation

Metal3 aims to provide zero-touch experience for bare-metal management as much
as it's physically possible. Features like firmware upgrades or, more recently,
ToR switch management have significantly reduced the burden of introducing new
hardware into the data center. However, there is a significant gap: BMC
themselves.

BMC enrollment poses a classic chicken-and-egg problem: how do you enroll
something that is required for hardware enrollment? Based on my
(non-representative) survey of fellow operators, these process operates along
these lines:

- Machines come with factory BMC passwords, usually unique and provided in a
  spreadsheet, but often enough the same default passwords.

  Operators need to install their own passwords and often enough to connect
  the BMCs to their authentication service via LDAP, ActiveDirectory, or OIDC.

- BMCs are pre-configured to run DHCP. Operators need to assign static
  addresses because DHCP adds a risk of changing network identities or
  unavailability. Often enough, the dynamic address is simply re-assigned as
  the static one, and nameservers are also copied over.

  Additionally, some operators will run hardware discovery by analyzing DHCP
  logs or by integrating with the DHCP server. For this use case, they need an
  ability to inspect the discovered machines in a non-invasive way - the
  functionality we now provide with *fast inspection*.

- Correct time can be crucial to security, so operators need to configure NTP.

- A bunch of TLS settings need to be changed, most notably the trusted CA and
  the certificates for web UI and Redfish API.

- There are certain configurations that are deemed insecure in a multi-tenant
  environment. In my survey, IPMI protocol and BMC *host interface* were
  mentioned very often.

Additionally, operators may want to configure arbitrary and potentially vendor-
or model-specific parameters of BMCs.

### Goals

- New API resources for changing BMC settings using the existing *preparing*
  and *servicing* features.

- Ability to change BMC password in the BMC itself, Ironic, and BMO more or
  less simultaneously.

- Ability to switch off DHCP and use static networking.

- Define the approximate scope of feature additions after this MVP is
  delivered.

### Non-Goals

- Generating passwords for BMCs. It's left for a higher-level orchestrator.
  Metal3 will receive passwords as secrets.

- Implement all possible workflows at once. The plan here is ambitious enough.
  We need to start somewhere and work from there.

- Disabling LDAP or ActiveDirectory after it was enabled. See implementation
  details on why.

## Proposal

This is where we get down to the details of what the proposal actually is.

### User Stories

#### Story 1

As an infrastructure operator that frequently enrolls new hardware at remote
locations, I want to be able to reduce the number of operations that are done
manually or using self-written scripts. I want to make sure that the machine is
prepared for secure multi-tenant operation by Metal3 using familiar
instruments.

#### Story 2

As an infrastructure operator, I want to be able to rotate BMC credentials
periodically. I want to do it in a way that does not cause issues in Ironic and
BMO because of invalid passwords.

## Design Details

We'll add a new resource `HostBMCSettings` that will handle BMC settings in a
similar way to how `HostFirmwareSettings` handles machine settings. Operations
will happen during either the `preparing` or the `servicing` phase, depending
on the initial state.

### MVP Scope

Here is the initial shape of the resource with all possible fields (see [future
additions](#future-additions) for some of the already requested extensions):

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostBMCSettings
metadata:
  name: host-0
  namespace: infra
spec:
  access:
    credentials:
      name: new-bmc-credentials
    authenticationService:
      type: ldap # none, activeDirectory
      config:
        name: ldap-config
  networking:
    # Automatically moves dynamic addresses and nameservers into static
    # configuration
    disableDHCP: true
    # Or addresses can be provided directly or via IPClaim links
    staticAddresses:
    - ip: 192.0.2.42
      useByDefault: true
    # Nameservers can also be provided explicitly, if needed
    nameServers:
    - 8.8.8.8
status:
  conditions:
  - type: Valid
    status: "True"
  - type: ChangeDetected
    status: "False"
  # More on these three in the implementation details.
  - type: ApprovalRequired
    status: "False"
  - type: AccessChangeApproved
    status: "Unknown"
  - type: NetworkingChangeApproved
    status: "Unknown"
  # ... more on other status fields below.
```

When explicitly set spec fields differ from status fields, `ChangeDetected` is
set to true. Most changes are applied immediately as a series of clean steps if
the host state is `available`, or as a series of service steps on the next
servicing if the host state is `provisioned`. The latter is subject to
HostUpdatePolicy, which gets a few new fields:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostUpdatePolicy
metadata:
  name: host-0
  namespace: infra
spec:
  bmcSettings: onService
  # Two more granular policies that override the generic bmcSettings
  bmcAccess: onService
  bmcNetworking: onPreparing
```

Two especially dangerous settings are exceptions from the automated application
process:

1. Any access settings
1. Changing the IP address that is used by default.

See details below on how they are handled.

### Implementation Details/Notes/Constraints

#### Pending settings

When modelling HostFirmwareSettings, we hit a problem: Ironic cannot report
back which URLs have been applied previously, and versions are also not always
reliable. Currently, the BMH controller (which handles most of the logic around
HFC) sets `status.updates` to `spec.updates` once the updates are *requested*.
On error, it unsets `status.updates`.

This is an unfortunate design. For example, it will cause all updates to be
re-applied on failure, even ones that have previously succeeded.

To avoid repeating the same issue in HostBMCSettings, the settings that cannot
be received back from Ironic will be stored in `status` in two places: for
applied and for pending settings.

Example for networking:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostBMCSettings
metadata:
  name: host-0
  namespace: infra
spec:
  networking:
    disableDHCP: true
    staticAddresses:
    - ip: 192.0.2.42
      useByDefault: true
    nameServers:
    - 8.8.8.8
status:
  # These are already applied settings. A diff with them triggers
  # ChangeDetected and eventually a change in the BMC.
  networking:
    disableDHCP: true
    staticAddresses:
    - ip: 192.0.2.42
      useByDefault: true
    nameServers:
    - 8.8.8.8
  # These are settings being applied right now. They're used for retries.
  # On success, they're moved to `networking`. On cancellation - removed.
  pendingNetworking: {}
```

Both applied and pending settings will expand secrets to include their
versions, so that changed or re-created secrets can be detected:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostBMCSettings
metadata:
  name: host-0
  namespace: infra
spec:
  access:
    credentials:
      name: new-bmc-credentials
    authenticationService:
      type: ldap # none, activeDirectory
      config:
        name: ldap-config
status:
  access:
    credentials:
      reference:
        name: new-bmc-credentials
      version: "1234"
    authenticationService:
      type: ldap # none, activeDirectory
      config:
        reference:
          name: ldap-config
        version: "5678"
  pendingAccess: {} # same format when populated
```

#### Process of changing BMC credentials

Changing BMC credentials is so dangerous, that it requires an additional
approval. When a diff is detected in `access`, the `ChangeDetected` condition
stays `false`, while another `ApprovalRequired` condition gets set to `true`.
A user approves the operation with an annotation:

`kubectl annotate hostbmcsettings host-01 approve.hostbmcsettings.metal3.io/access=true`

This causes `ApprovalRequired` to be set to `false` and `ChangeDetected` to be
set to `true`. Another condition `AccessChangeApproved` is set to `true` a
signal to the BareMetalHost controller (which in the current BMO design drives
preparation or servicing).

The BareMetalHost controller inspects both conditions. `ChangeDetected` causes
it to start preparing or allow servicing by the corresponding trigger. Once the
process is started (provisioning state is `preparing` or operational status is
`servicing`), the `AccessChangeApproved` condition temporary turns off the BMC
secret update logic in the registration code. The `AccessChangeApproved`
condition is copied to the BMH as `AccessChangeInProgress` for visibility.

Now the BMH controller can request the corresponding Ironic step:

- `configure_authentication` if the authentication service type is not `none`
- `set_bmc_password` otherwise.

**LIMITATION:** it's not going to be possible to disable a previously enabled
authentication service in the initial version.

Both steps automatically update the password in Ironic. All that remains is to
update the password on the BareMetalHost by copying the secret reference and
adjusting the host's status accordingly. The approval annotation is removed
automatically when no longer needed.

#### Process of changing BMC address

The HostBMCSettings controller will check the provided IP addresses against the
current IP address in the BMC settings. It will calculate which address will be
used after the change is applied. The following situations trigger the change
of the BMC address:

1. `bmc.address` has an IP address that is not the address marked as
   `useByDefault` in HostBMCSettings.
1. `bmc.address` is a hostname, and `useByDefault` now points to a different
   address than before.

In all other cases, the BMC address is not changed, so the currently used
address must be in the list of static addresses, if it's provided. It's
possible to use `disableDHCP` without providing a list of addresses: in this
case Ironic will configure the currently used address as the only static IP
address (it's a validation error for it to be a hostname in this case).

If the BMC address change is not triggered, a networking update runs as normal
preparing/servicing without extra logic. If it is triggered, a similar
safeguard to changing the BMC password is applied:

The `ApprovalRequired` condition gets set to `true`. A user approves the
operation with an annotation:

`kubectl annotate hostbmcsettings host-01 approve.hostbmcsettings.metal3.io/networking=true`

This causes `ApprovalRequired` to be set to `false` and `ChangeDetected` to be
set to `true`. Another condition `NeworkingChangeApproved` is set to `true` a
signal to the BareMetalHost controller (which in the current BMO design drives
preparation or servicing).

Similarly to BMC password, the `NetworkingChangeApproved` condition turns into
`NetworkingChangeInProgress` on the BMH, which cases the DriverInfo
synchronization logic to be paused.

Now the BMH controller can request the corresponding Ironic step:

- `configure_static_networking` if IP addresses are provided
- `disable_dhcp` otherwise.

With the BMC address in Ironic automatically updated, all the BMH controller
need to do in the end is to change `bmc.address` accordingly and unset
`NetworkingChangeInProgress`.

#### Future additions

For the sake of delivering an MVP, this design deliberately omits certain more
complex features that have been already requested. Here is a tentative list:

- Arbitrary BMC settings:

  ```yaml
  apiVersion: metal3.io/v1alpha1
  kind: HostBMCSettings
  metadata:
    name: host-0
    namespace: infra
  spec:
    settings:
      VendorField: 42
      AnotherField: banana
  status:
    firmwareSchema:
      namespace: infra
      name: schema-abcd
    settings:
      VendorField: 42
      AnotherField: banana
      ThirdField: ""
    pendingSettings: {}
  ```

- Support for IP claims:

  ```yaml
  apiVersion: metal3.io/v1alpha1
  kind: HostBMCSettings
  metadata:
    name: host-0
    namespace: infra
  spec:
    networking:
      disableDHCP: true
      staticAddresses:
      - ipClaim:
          name: host-0-ipv4
      - ipClaim:
          name: host-0-ipv6
        useByDefault: true
  status:
    networking:
      disableDHCP: true
      staticAddresses:
      - ipClaim:
          name: host-0-ipv4
        ip: 192.0.2.42 # resolved from IPClaim
      - ipClaim:
          name: host-0-ipv6
        ip: 2001:db8::42 # resolved from IPClaim
  ```

- Configuring current time or NTP servers:

  ```yaml
  apiVersion: metal3.io/v1alpha1
  kind: HostBMCSettings
  metadata:
    name: host-0
    namespace: infra
  spec:
    time:
      # Set date and time together with the offset
      dateTime: "2026-11-26T17:00:05+01:00"
      # ... or provide only the offset and NTP servers
      offset: "+01:00"
      ntpServers:
      - ntp.example.com
  status:
    time:
      dateTime: "2026-11-26T17:00:05+01:00"
      offset: "+01:00"
      ntpServers:
      - ntp.example.com
    pendingTime: {}
  ```

- Protocol management:

  ```yaml
  apiVersion: metal3.io/v1alpha1
  kind: HostBMCSettings
  metadata:
    name: host-0
    namespace: infra
  spec:
    protocols:
      ipmi: disabled # or enabled; unchanged if missing
      hostInterface: disabled # same
  status:
    protocols:
      ipmi: disabled # or enabled; unchanged if missing
      hostInterface: disabled # same
    pendingProtocols: {}
  ```

- CA certificates for LDAP:

  ```yaml
  apiVersion: metal3.io/v1alpha1
  kind: HostBMCSettings
  metadata:
    name: host-0
    namespace: infra
  spec:
    access:
      credentials:
        name: new-bmc-credentials
      authenticationService:
        type: ldap
        config:
          name: ldap-config
        caCertificate:
          name: ldap-ca
  status:
    access:
      credentials:
        reference:
          name: new-bmc-credentials
        version: "1234"
      authenticationService:
        type: ldap
        config:
          reference:
            name: ldap-config
          version: "4567"
        caCertificate:
          reference:
            name: ldap-ca
          version: "89ab"
  ```

- Global CA certificates for the BMC:

  ```yaml
  apiVersion: metal3.io/v1alpha1
  kind: HostBMCSettings
  metadata:
    name: host-0
    namespace: infra
  spec:
    caCertificate:
      name: bmc-ca-bundle
  status:
    caCertificate:
      reference:
        name: ldap-ca
      version: "89ab"
    pendingCACertificate: {}
  ```

### Risks and Mitigations

...

### Work Items

...

### Dependencies

- For high-level operations, Ironic must implement [BMC management
  steps](https://review.opendev.org/c/openstack/ironic-specs/+/1006205)

- For arbitrary settings, Ironic must add [BMC settings
  API](https://review.opendev.org/c/openstack/ironic-specs/+/1004909)

- [Make sure secrets are safe to pass as step
  arguments](https://review.opendev.org/c/openstack/ironic/+/1017069)

- Ideally, we need [a way to figure out available
  steps](https://bugs.launchpad.net/ironic/+bug/2176192) to provide better
  user experience on missing Ironic features.

- There is no Ironic design for CA certificates (both global and LDAP).

### Test Plan

Redfish emulator supports managing users, including changing password, so we
should be able to cover this functionality in e2e tests. We'll need to create a
separate user for this test case to avoid disrupting other tests.

LDAP and networking tests are difficult to cover using the emulator in a
meaningful way, so they'll need to be tested manually and with unit tests.

...

### Upgrade / Downgrade Strategy

...

### Version Skew Strategy

...

## Drawbacks

- Changing BMC settings is risky. However, by not implementing this API, we
  don't reduce the risk, we just move it elsewhere.

...

## Alternatives

- Reuse HostFirmwareSettings. Rejected because HFS is something we want to
  expose (to at least some degree) to tenants, while BMC settings must never be
  modified or even read by tenants.

...

## References
