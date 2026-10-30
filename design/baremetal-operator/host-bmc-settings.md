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

- Ability to switch of DHCP and use static networking.

- Ability to configure NTP servers.

- Ability to disable IPMI and Redfish host interface.

### Non-Goals

- TLS certificate management. While highly desired, passing certificates from
  Kubernetes to Ironic is a non-trivial problem, so this feature was postponed
  to limit the scope.

- Generating passwords for BMCs. It's left for a higher-level orchestrator.
  Metal3 will receive passwords as secrets.

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

Here is the initial shape of the resource with all possible fields:

```yaml
apiVersion: metal3.io/v1alpha1
kind: HostBMCSettings
metadata:
  name: host-0
  namespace: infra
spec:
  access:
    credentialsName: new-bmc-credentials
    authenticationService:
      type: ldap # none, activeDirectory
      configName: ldap-config
      caCertificateName: ldap-ca
  networking:
    # Automatically moves dynamic addresses and nameservers into static
    # configuration
    disableDHCP: true
    # Or addresses can be provided directly or via IPClaim links
    staticAddresses:
    - ip: 192.0.2.42
    - ipClaimName: host-0-ipv6
      useByDefault: true
    # Nameservers and NTP servers can also be provided explicitly, if needed
    nameServers:
    - 8.8.8.8
    ntpServers:
    - ntp.example.com
  protocols:
    ipmi: disabled # or enabled; unchanged if missing
    hostInterface: disabled # same
  settings:
    VendorField: 42
    AnotherField: banana
status:
  conditions:
  - type: Valid
    status: "True"
  - type: ChangeDetected
    status: "False"
  firmwareSchema:
    namespace: infra
    name: schema-abcd
  # access, networking, and protocols are copied from spec when applied
  access:
    credentialsName: new-bmc-credentials
    authenticationService:
      type: ldap
      configName: ldap-config
      caCertificateName: ldap-ca
  networking:
    disableDHCP: true
    staticAddresses:
    - ip: 192.0.2.42
    - ipClaimName: host-0-ipv6
      ip: 2001:db8::42 # resolved from IPClaim
      useByDefault: true
    nameServers:
    - 8.8.8.8
    ntpServers:
    - ntp.example.com
  protocols:
    ipmi: disabled # or enabled; unchanged if missing
    hostInterface: disabled # same
  settings:
    VendorField: 42
    AnotherField: banana
    ThirdField: ""
```

When explicitly set spec fields differ from status fields, `ChangeDetected` is
set to true. The change is applied immediately as a series of clean steps if
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
  bmcSettings: onReboot
  # Two more granular policies that override the generic bmcSettings
  bmcAccess: onReboot
  bmcNetworking: onPreparing
```

### Implementation Details/Notes/Constraints

...

#### Process of changing BMC address

...

### Risks and Mitigations

...

### Work Items

...

### Dependencies

- For high-level operations, Ironic must implement [BMC management
  steps](https://review.opendev.org/c/openstack/ironic-specs/+/1006205)

- For arbitrary settings, Ironic must add [BMC settings
  API](https://review.opendev.org/c/openstack/ironic-specs/+/1004909)

Depending on what specification is implemented first, we can provide partial
API as an MVP.

### Test Plan

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
