# Supported hardware

Metal3 supports many vendors and models of enterprise-grade hardware with
a *BMC* ([Baseboard Management Controller][bmc]) that supports one of the
remote management protocols described in this document. On top of that, one of
the two boot methods must be supported:

1. Network boot. Most hardware supports booting a Linux kernel and initramfs
   via TFTP. Metal3 augments it with [iPXE][ipxe] - a higher level network boot
   firmware with support for scripting and TCP-based protocols such as HTTP.

   Booting over network relies on DHCP and thus requires a *provisioning
   network* for isolated L2 traffic between the Metal3 control plane and the
   machines.

1. Virtual media boot. Some hardware model support directly booting an ISO 9660
   image as a virtual CD device over HTTP(s). An important benefit of this
   approach is the ability to boot hardware over L3 networks, potentially
   without DHCP at all.

## IPMI

[IPMI][ipmi] is the oldest and by far the most widely available remote
management protocol. Nearly all enterprise-grade hardware supports it. Its
downside include reduced reliability and a weak security, especially if not
configured properly.

**WARNING:** only network boot over iPXE is supported for IPMI.

<!-- markdownlint-disable MD013 -->

| BMC address format     | Notes                                   |
|------------------------|-----------------------------------------|
| `ipmi://<host>:<port>` | Port is optional, defaults to 623.      |
| `<host>:<port>`        | IPMI is the default protocol in Metal3. |

<!-- markdownlint-enable MD013 -->

## Redfish and its variants

[Redfish][redfish] is a vendor-agnostic protocol for remote hardware
management. It is based on HTTP(s) and JSON and thus does not suffer from the
limitations of IPMI. It also exposes modern features such as virtual media
boot, RAID management, firmware settings and updates.

Ironic (and thus Metal3) aims to support Redfish as closely to the standard as
possible, with a few workarounds for known issues and explicit support for Dell
iDRAC. Note, however, that all features are optional in Redfish, so you may
encounter a Redfish-capable hardware that is not supported by Metal3.
Furthermore, some features (such as virtual media boot) may require buying an
additional license to function.

Since a Redfish API endpoint can manage several servers (*systems* in Redfish
terminology), BMC addresses for Redfish-based drivers include a *system ID* -
the URL of the particular server. For Dell machines it usually looks like
`/redfish/v1/Systems/System.Embedded.1`, while other vendors may simply use
`/redfish/v1/Systems/1`. Check the hardware documentation to find out which
format is right for your machine.

<!-- markdownlint-disable MD013 -->

| Technology      | Boot method   | BMC address format                                | Notes                                                                   |
|-----------------|---------------|---------------------------------------------------|-------------------------------------------------------------------------|
| Generic Redfish | iPXE          | `redfish://<host>:<port>/<systemID>`              |                                                                         |
|                 | Virtual media | `redfish-virtualmedia://<host>:<port>/<systemID>` | **Must not** be used for Dell machines.                                 |
| Dell iDRAC 8+   | iPXE          | `idrac-redfish://<host>:<port>/<systemID>`        |                                                                         |
|                 | Virtual media | `idrac-virtualmedia://<host>:<port>/<systemID>`   | Requires firmware v6.10.30.00+ for iDRAC 9, v2.75.75.75+ for iDRAC 8.   |
| HPE iLO 5 and 6 | iPXE          | `ilo5-redfish://<host>:<port>/<systemID>`         | An alias of `redfish` for convenience. RAID management only on iLO 6.   |
|                 | Virtual media | `ilo5-virtualmedia://<host>:<port>/<systemID>`    | An alias of `redfish` for convenience. RAID management only on iLO 6.   |

<!-- markdownlint-enable MD013 -->

Users have also reported success with certain models of SuperMicro, Lenovo, ZT
Systems and Cisco UCS hardware, but hardware from these vendors is not
regularly tested by the team.

All drivers based on Redfish allow optionally specifying the carrier protocol
in the form of `+http` or `+https`, for example: `redfish+http://...` or
`idrac-virtualmedia+https`. When not specified, HTTPS is used by default.

### Redfish interoperability

As noted above, Redfish allows for very different valid implementations, some
of which are not compatible with Ironic (and thus Metal3). The Ironic project
publishes a *Redfish interoperability profile* -- a JSON document that
describes the required and optionally supported Redfish API features. Its
available versions can be found in the [Ironic source
tree][redfish-interop-profiles]. The
[Redfish-Interop-Validator][Redfish-Interop-Validator] tool can be used to
validate a server against this profile.

Check the [Ironic interoperability documentation][Ironic interoperability
documentation] for a rendered version of the latest profile. All features
required for Ironic are also required for Metal3. Most optional features except
for the out-of-band inspection are also supported, although the hardware
metrics support via [ironic-prometheus-exporter][ipe] is currently experimental
and undocumented.

[redfish-interop-profiles]: https://opendev.org/openstack/ironic/src/branch/master/redfish-interop-profiles
[Redfish-Interop-Validator]: https://github.com/DMTF/Redfish-Interop-Validator
[Ironic interoperability documentation]: https://docs.openstack.org/ironic/latest/admin/drivers/redfish/interop.html
[ipe]: https://docs.openstack.org/ironic-prometheus-exporter/latest/

## Vendor-specific protocols

<!-- markdownlint-disable MD013 -->

| Technology      | Protocol | Boot method   | BMC address format                  | Notes                                                                   |
|-----------------|----------|---------------|-------------------------------------|-------------------------------------------------------------------------|
| Fujitsu iRMC    | iRMC     | iPXE          | `irmc://<host>:<port>`              | **Deprecated**, to be removed after BMO 0.12.                           |
| HPE iLO 4       | iLO      | iPXE          | `ilo4://<host>:<port>`              | **Removed** after BMO 0.11 / Ironic 32.0.                               |
|                 | iLO      | Virtual media | `ilo4-virtualmedia://<host>:<port>` | **Removed** after BMO 0.11 / Ironic 32.0.                               |
| HPE iLO 5       | iLO      | iPXE          | `ilo5://<host>:<port>`              | **Removed** after BMO 0.11 / Ironic 32.0.                               |

<!-- markdownlint-enable MD013 -->

[bmc]: https://en.wikipedia.org/wiki/Intelligent_Platform_Management_Interface#Baseboard_management_controller
[ipxe]: https://ipxe.org/
[ipmi]: https://en.wikipedia.org/wiki/Intelligent_Platform_Management_Interface
[redfish]: https://redfish.dmtf.org/
