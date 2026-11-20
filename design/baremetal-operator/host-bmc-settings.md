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
    credentials:
      name: new-bmc-credentials
    authenticationService:
      type: ldap # none, activeDirectory
      config:
        name: ldap-config
      # Future addition, not in the MVP:
      # caCertificate:
      #   name: ldap-ca
  networking:
    # Automatically moves dynamic addresses and nameservers into static
    # configuration
    disableDHCP: true
    # Or addresses can be provided directly or via IPClaim links
    staticAddresses:
    - ip: 192.0.2.42
      useByDefault: true
    # Future addition, not in the MVP:
    # - ipClaim:
    #     name: host-0-ipv6
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
  # access, networking, and protocols are copied from spec when applied.
  # secrets' versions are tracked to detect changes.
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
      # Future addition, not in the MVP:
      # caCertificate:
      #   reference:
      #     name: ldap-ca
      #   version: "89ab"
  # Each group has a pending version to track what has been requested but not applied yet
  pendingAccess: {}
  networking:
    disableDHCP: true
    staticAddresses:
    - ip: 192.0.2.42
      useByDefault: true
    # Future addition, not in the MVP:
    # - ipClaim:
    #     name: host-0-ipv6
    #   ip: 2001:db8::42 # resolved from IPClaim
    nameServers:
    - 8.8.8.8
    ntpServers:
    - ntp.example.com
  pendingNetworking: {}
  protocols:
    ipmi: disabled # or enabled; unchanged if missing
    hostInterface: disabled # same
  pendingProtocols: {}
  settings:
    VendorField: 42
    AnotherField: banana
    ThirdField: ""
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

It's important to ensure that the BMH controller doesn't interfere with the
process of changing BMC information (e.g. by setting the Redfish address back).

...

#### Pending settings

When modelling HostFirmwareSettings, we hit a problem: Ironic cannot report
back which URLs have been applied previously, and versions are also not always
reliable. Currently, the BMH controller (which handles most of the logic around
HFC) sets `status.updates` to `spec.updates` once the updates are *requested*.
On error, it unsets `status.updates`.

This is an unfortunate design. For example, it will cause all updates to be
re-applied on failure, even ones that have previously succeeded.

To avoid repeating the same issue in HostBMCSettings, the settings that cannot
be received back from Ironic will be stored in `status` in two places. For
example for `access`:

1. Once the corresponding steps are requested, the information from
   `spec.access` is copied into `status.pendingAccess`.
1. Once the steps succeed, `status.access` is updated from `pendingAccess`.

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
adjusting the host's status accordingly.

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
