<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# host-profiles

## Status

One of: provisional

## Table of Contents

<!--ts-->
   * [host-profiles](#host-profiles)
      * [Status](#status)
      * [Table of Contents](#table-of-contents)
      * [Summary](#summary)
      * [Motivation](#motivation)
         * [Goals](#goals)
         * [Non-Goals](#non-goals)
      * [Proposal](#proposal)
         * [User Stories [optional]](#user-stories-optional)
            * [Controlling Types of Hosts Added to the Cluster](#controlling-types-of-hosts-added-to-the-cluster)
            * [Testing On New Host Types](#testing-on-new-host-types)
         * [Implementation Details/Notes/Constraints [optional]](#implementation-detailsnotesconstraints-optional)
         * [Risks and Mitigations](#risks-and-mitigations)
      * [Design Details](#design-details)
         * [Work Items](#work-items)
         * [Dependencies](#dependencies)
         * [Test Plan](#test-plan)
         * [Upgrade / Downgrade Strategy](#upgrade--downgrade-strategy)
         * [Version Skew Strategy](#version-skew-strategy)
      * [Drawbacks [optional]](#drawbacks-optional)
      * [Alternatives [optional]](#alternatives-optional)
      * [References](#references)
         * [Example Ironic Inventory Results](#example-ironic-inventory-results)
            * [Virtual Machine](#virtual-machine)
            * [Bare Metal](#bare-metal)

<!-- Added by: stack, at: 2019-02-15T16:58-05:00 -->

<!--te-->

## Summary

Host profiles allow us to match the hardware characteristics of a host
to provide a label similar to an instance flavor in a traditional
cloud environment. Host profiles are configurable through the
Kubernetes API, allowing cluster administrators to expand the known
hardware platforms and control how they are used in the cluster.

## Motivation

We want to limit the provisioning operations to known hardware
platforms, while making the set of known platforms easy to expand over
time. We do not want to hard-code the definitions, because that makes
it more difficult to configure development or test environments that
may not match what an expected production environment looks like.

### Goals

- Provide a place for us to store known hardware profiles.
- Provide a way to match known profiles to actual hardware.
- Provide a way to control how that hardware is used as part of a
  MachineSet.

### Non-Goals

This goal is about examining the hardware present in the host. It does
not consider whether that hardware is returning fault codes or
otherwise not working properly. Dealing with faulty hardware is
covered under a separate design.

For now, we only want to do simple matching based on data, and we do
not want a complex "language" to describe matching rules. It is enough
for hosts to look like the hardware described in the profile.

This design does not cover using the profile to control how software
is deployed to the host (specifying networking access, storage use,
etc.). That may come in a later design.

## Proposal

A new CRD, BareMetalHostProfile, is defined with Spec fields for all
of the relevant hardware considerations. Ideally this would reuse the
hardware specification data structure in the BareMetalHost itself, or
be a different structure that summarizes that structure (for example,
providing numCPUs and cpuGHz, fields but not a list of CPUs and their
individual speeds).

The Status portion of the BareMetalHostProfile will report all of the
BareMetalHosts and MachineSets associated with the profile.

*We need more detail about exactly what sort of hardware matching we
care about.*

When a profile is created, the profile operator causes all host
resources labeled as having an unknown profile to be reconciled to see
if they match the new profile. This means the order of creation for
hosts and profiles does not matter, because the match will happen
eventually.

When a profile is updated, the profile operator causes all host
resources associated with that profile to be reconciled to see if they
still match the updated profile.

### User Stories [optional]

Detail the things that people will be able to do if the design is
implemented.  Include as much detail as possible so that people can
understand the "how" of the system.  The goal here is to make this
feel real for users without getting bogged down.

#### Controlling Types of Hosts Added to the Cluster

The machine actuator in the cluster-api-provider-baremetal repository
will expect the template machine spec in the MachineSet to include the
name of a host profile, and will use that name to find hosts to add to
the set when it expands. This means that hosts with different profiles
will always be in different machine sets, and only hosts with profiles
named by a MachineSet will ever be included in the cluster.

#### Testing On New Host Types

To test a new hosts type or configuration, the cluster admin will
create a new profile CR populated with the relevant data and then add
host resources expected to match that profile. Then by creating a
MachineSet using the new profile name, they can bring those hosts into
the cluster.

### Implementation Details/Notes/Constraints [optional]

It is generally frowned upon to use the Kubernetes API as a "mere
database". Profiles are less reactive than some other other types of
resources, but their operator does work in conjunction with the host
operator to ensure matching is consistently applied. Host configs are
another example of this pattern.  On the other hand, we might not
actually need a second controller, if we set the watch rules up in the
host operator. The choice for how to handle that will be made based on
which implementation is easier to understand.

### Risks and Mitigations

Cluster admins will have access to APIs to add host profiles on their
own, leading to deployments on hardware configurations not supported
by their vendor. The vendor can reject support requests for these
configurations.

## Design Details

### Work Items

- Define a new BareMetalHostProfile CRD in the baremetal-operator git
  repo.
- Add a controller for the BareMetalHostProfile CRD in the
  baremetal-operator git repo.
- The logic to match a BareMetalHostProfile (profile) to a
  BareMetalHost (host) is implemented as a module within the
  baremetal-operator git repo.
- A new controller for the profile CRD is added to the
  baremetal-operator git repo.
- When a host is created, or a profile triggers its reconciliation,
  the match logic is invoked by the operator for the host CR, which
  updates the `metalkube.org/hardware-profile` label on the host to
  associate it with the profile.
- Add a tool to the dev-scripts git repo to create virtual machines
  matching a couple of standard dev/test profiles.

### Dependencies

None

### Test Plan

There will be unit tests for the profile matching logic.

There will be end-to-end tests for the use of profiles to manage
hosts.

Most developers will run with profiles describing virtual machines,
which can be varied to ensure that the rest of the project does not
make assumptions about hardware details.

### Upgrade / Downgrade Strategy

Upgrades of the baremetal-operator can come with additional YAML files
to define host profiles for common hardware configuration so that they
are installed automatically when the operator is upgrade.

Existing resources will not require modification on upgrade.

### Version Skew Strategy

This does not apply because the only other consumer of the profile is
the machine actuator, which only knows the name of a profile and does
not use any of the details.

## Drawbacks [optional]

See comments in the Risks section above.

## Alternatives [optional]

1. **Build the data into the baremetal-operator.** We would prefer a
   more data-driven approach that allows us to separate production
   profiles from dev/test profiles.
2. **Use a ConfigMap with profile data.**

## References

* [Ironic Documentation](https://docs.openstack.org/ironic/latest/)
* [Ironic API](https://developer.openstack.org/api-ref/baremetal/)
* [Ironic Inspector Documentation](https://docs.openstack.org/ironic-inspector/latest/)
* [Ironic Inspector API](https://developer.openstack.org/api-ref/baremetal-introspection/)
* [Kubernetes "Meaning of Memory" description](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/#meaning-of-memory)

### Example Ironic Inventory Results


#### Virtual Machine

*This is the result of asking ironic inspector to examine a virtual
machine, but given a general idea of what might be included in results
of inspecting the host and that could be applied to the profile.*

```
{
  "cpu_arch": "x86_64",
  "macs": [
    "00:ca:ff:65:6e:68"
  ],
  "root_disk": {
    "rotational": true,
    "vendor": "0x1af4",
    "name": "/dev/vda",
    "wwn_vendor_extension": null,
    "hctl": null,
    "wwn_with_extension": null,
    "by_path": "/dev/disk/by-path/pci-0000:00:05.0",
    "model": "",
    "wwn": null,
    "serial": null,
    "size": 53687091200
  },
  "all_interfaces": {
    "eth1": {
      "ip": "192.168.111.20",
      "mac": "00:ca:ff:65:6e:6a",
      "client_id": null,
      "pxe": false
    },
    "eth0": {
      "ip": "172.22.0.43",
      "mac": "00:ca:ff:65:6e:68",
      "client_id": null,
      "pxe": true
    }
  },
  "cpus": 2,
  "boot_interface": "00:ca:ff:65:6e:68",
  "memory_mb": 6144,
  "ipmi_address": null,
  "inventory": {
    "bmc_address": "0.0.0.0",
    "interfaces": [
      {
        "lldp": [],
        "ipv6_address": "fe80::2ca:ffff:fe65:6e68%eth0",
        "vendor": "0x1af4",
        "name": "eth0",
        "has_carrier": true,
        "product": "0x0001",
        "ipv4_address": "172.22.0.43",
        "biosdevname": null,
        "client_id": null,
        "mac_address": "00:ca:ff:65:6e:68"
      },
      {
        "lldp": [],
        "ipv6_address": "fe80::2ca:ffff:fe65:6e6a%eth1",
        "vendor": "0x1af4",
        "name": "eth1",
        "has_carrier": true,
        "product": "0x0001",
        "ipv4_address": "192.168.111.20",
        "biosdevname": null,
        "client_id": null,
        "mac_address": "00:ca:ff:65:6e:6a"
      }
    ],
    "disks": [
      {
        "rotational": true,
        "vendor": "0x1af4",
        "name": "/dev/vda",
        "wwn_vendor_extension": null,
        "hctl": null,
        "wwn_with_extension": null,
        "by_path": "/dev/disk/by-path/pci-0000:00:05.0",
        "model": "",
        "wwn": null,
        "serial": null,
        "size": 53687091200
      }
    ],
    "boot": {
      "current_boot_mode": "bios",
      "pxe_interface": "00:ca:ff:65:6e:68"
    },
    "system_vendor": {
      "serial_number": "",
      "product_name": "KVM",
      "manufacturer": "Red Hat"
    },
    "memory": {
      "physical_mb": 6144,
      "total": 6256263168
    },
    "cpu": {
      "count": 2,
      "frequency": "1899.999",
      "flags": [
        "fpu", "vme", "de", "pse", "tsc", "msr", "pae", "mce", "cx8", "apic",
        "sep", "mtrr", "pge", "mca", "cmov", "pat", "pse36", "clflush", "mmx",
        "fxsr", "sse", "sse2", "ss", "syscall", "nx", "pdpe1gb", "rdtscp",
        "lm", "constant_tsc", "arch_perfmon", "rep_good", "nopl", "xtopology",
        "eagerfpu", "pni", "pclmulqdq", "vmx", "ssse3", "cx16", "pcid",
        "sse4_1", "sse4_2", "x2apic", "popcnt", "tsc_deadline_timer", "aes",
        "xsave", "avx", "f16c", "rdrand", "hypervisor", "lahf_lm", "ibrs",
        "ibpb", "stibp", "tpr_shadow", "vnmi", "flexpriority", "ept", "vpid",
        "fsgsbase", "tsc_adjust", "smep", "erms", "xsaveopt", "arat",
        "spec_ctrl", "intel_stibp"
      ],
      "model_name": "Intel(R) Xeon(R) CPU E5-2440 v2 @ 1.90GHz",
      "architecture": "x86_64"
    }
  },
  "error": null,
  "local_gb": 49,
  "interfaces": {
    "eth0": {
      "ip": "172.22.0.43",
      "mac": "00:ca:ff:65:6e:68",
      "client_id": null,
      "pxe": true
    }
  }
}
```

#### Bare Metal

Below is a payload containing data returned for a baremetal server.

Note the following:
* lldp_processed contains interesting data from a network switch
  received via LLDP packets from each switch port
* Introspection on this baremetal server ran with `extra-hardware` and
  `numa-topology` set so there is a lot more data.  We don't plan on
  using these inspector options with Metalkube.

```
{
  "cpu_arch": "x86_64",
  "macs": [
    "b0:83:fe:c6:63:86"
  ],
  "root_disk": {
    "rotational": true,
    "vendor": "DELL",
    "name": "/dev/sda",
    "wwn_vendor_extension": "0x1bd2cc7e0fc68486",
    "hctl": "0:2:0:0",
    "wwn_with_extension": "0x6b083fe0d2d0eb001bd2cc7e0fc68486",
    "by_path": "/dev/disk/by-path/pci-0000:01:00.0-scsi-0:2:0:0",
    "model": "PERC H710",
    "wwn": "0x6b083fe0d2d0eb00",
    "serial": "6b083fe0d2d0eb001bd2cc7e0fc68486",
    "size": 599550590976
  },
  "extra": {
    "network": {
      "p2p2": {
        "tx-udp_tnl-csum-segmentation": "on",
        "vlan-challenged": "off [fixed]",
        "rx-vlan-offload": "on",
        "tx-vlan-stag-hw-insert": "off [fixed]",
        "rx-vlan-stag-filter": "off [fixed]",
        "highdma": "on [fixed]",
        "autonegotiation": "on",
        "tx-gso-robust": "off [fixed]",
        "tcp-segmentation-offload/tx-tcp-mangleid-segmentation": "off",
        "rx-udp_tunnel-port-offload": "off [fixed]",
        "netns-local": "off [fixed]",
        "vendor": "Intel Corporation",
        "serial": "a0:36:9f:52:7f:b3",
        "speed": "1Gbit/s",
        "size": 1000000000,
        "l2-fwd-offload": "off [fixed]",
        "latency": 0,
        "tx-checksumming/tx-checksum-ipv6": "off [fixed]",
        "tx-gre-segmentation": "on",
        "tx-checksumming/tx-checksum-ipv4": "off [fixed]",
        "tx-fcoe-segmentation": "off [fixed]",
        "duplex": "full",
        "tcp-segmentation-offload": "on",
        "Autonegotiate": "on",
        "tx-udp_tnl-segmentation": "on",
        "RX": "on",
        "firmware": "1.67, 0x80000cc9, 16.0.22",
        "fcoe-mtu": "off [fixed]",
        "tcp-segmentation-offload/tx-tcp-ecn-segmentation": "off [fixed]",
        "large-receive-offload": "off [fixed]",
        "tx-sctp-segmentation": "off [fixed]",
        "tx-checksumming/tx-checksum-fcoe-crc": "off [fixed]",
        "rx-vlan-stag-hw-parse": "off [fixed]",
        "businfo": "pci@0000:08:00.1",
        "tx-vlan-offload": "on",
        "product": "I350 Gigabit Network Connection",
        "tx-nocache-copy": "off",
        "udp-fragmentation-offload": "off [fixed]",
        "tx-checksumming/tx-checksum-sctp": "on",
        "driver": "igb",
        "tx-sit-segmentation": "on",
        "busy-poll": "off [fixed]",
        "scatter-gather/tx-scatter-gather": "on",
        "tx-checksumming/tx-checksum-ip-generic": "on",
        "link": "yes",
        "rx-all": "off",
        "tx-ipip-segmentation": "on",
        "tcp-segmentation-offload/tx-tcp6-segmentation": "on",
        "rx-checksumming": "on",
        "tcp-segmentation-offload/tx-tcp-segmentation": "on",
        "TX": "off",
        "generic-segmentation-offload": "on",
        "loopback": "off [fixed]",
        "tx-lockless": "off [fixed]",
        "tx-checksumming": "on",
        "ntuple-filters": "off",
        "rx-vlan-filter": "on [fixed]",
        "tx-gre-csum-segmentation": "on",
        "tx-gso-partial": "on",
        "receive-hashing": "on",
        "scatter-gather/tx-scatter-gather-fraglist": "off [fixed]",
        "generic-receive-offload": "on",
        "rx-fcs": "off [fixed]",
        "scatter-gather": "on",
        "hw-tc-offload": "off [fixed]"
      },
      "p2p1": {
        "tx-udp_tnl-csum-segmentation": "on",
        "vlan-challenged": "off [fixed]",
        "rx-vlan-offload": "on",
        "tx-vlan-stag-hw-insert": "off [fixed]",
        "rx-vlan-stag-filter": "off [fixed]",
        "highdma": "on [fixed]",
        "autonegotiation": "on",
        "tx-gso-robust": "off [fixed]",
        "tcp-segmentation-offload/tx-tcp-mangleid-segmentation": "off",
        "rx-udp_tunnel-port-offload": "off [fixed]",
        "netns-local": "off [fixed]",
        "vendor": "Intel Corporation",
        "serial": "a0:36:9f:52:7f:b2",
        "speed": "1Gbit/s",
        "size": 1000000000,
        "l2-fwd-offload": "off [fixed]",
        "latency": 0,
        "tx-checksumming/tx-checksum-ipv6": "off [fixed]",
        "tx-gre-segmentation": "on",
        "tx-checksumming/tx-checksum-ipv4": "off [fixed]",
        "tx-fcoe-segmentation": "off [fixed]",
        "duplex": "full",
        "tcp-segmentation-offload": "on",
        "Autonegotiate": "on",
        "tx-udp_tnl-segmentation": "on",
        "RX": "on",
        "firmware": "1.67, 0x80000cc9, 16.0.22",
        "fcoe-mtu": "off [fixed]",
        "tcp-segmentation-offload/tx-tcp-ecn-segmentation": "off [fixed]",
        "large-receive-offload": "off [fixed]",
        "tx-sctp-segmentation": "off [fixed]",
        "tx-checksumming/tx-checksum-fcoe-crc": "off [fixed]",
        "rx-vlan-stag-hw-parse": "off [fixed]",
        "businfo": "pci@0000:08:00.0",
        "tx-vlan-offload": "on",
        "product": "I350 Gigabit Network Connection",
        "tx-nocache-copy": "off",
        "udp-fragmentation-offload": "off [fixed]",
        "tx-checksumming/tx-checksum-sctp": "on",
        "driver": "igb",
        "tx-sit-segmentation": "on",
        "busy-poll": "off [fixed]",
        "scatter-gather/tx-scatter-gather": "on",
        "tx-checksumming/tx-checksum-ip-generic": "on",
        "link": "yes",
        "rx-all": "off",
        "tx-ipip-segmentation": "on",
        "tcp-segmentation-offload/tx-tcp6-segmentation": "on",
        "rx-checksumming": "on",
        "tcp-segmentation-offload/tx-tcp-segmentation": "on",
        "TX": "off",
        "generic-segmentation-offload": "on",
        "loopback": "off [fixed]",
        "tx-lockless": "off [fixed]",
        "tx-checksumming": "on",
        "ntuple-filters": "off",
        "rx-vlan-filter": "on [fixed]",
        "tx-gre-csum-segmentation": "on",
        "tx-gso-partial": "on",
        "receive-hashing": "on",
        "scatter-gather/tx-scatter-gather-fraglist": "off [fixed]",
        "generic-receive-offload": "on",
        "rx-fcs": "off [fixed]",
        "scatter-gather": "on",
        "hw-tc-offload": "off [fixed]"
      },
      "em1": {
        "tx-udp_tnl-csum-segmentation": "off [fixed]",
        "vlan-challenged": "off [fixed]",
        "rx-vlan-offload": "on [fixed]",
        "ipv4-network": "10.8.146.0",
        "rx-vlan-stag-filter": "off [fixed]",
        "highdma": "on",
        "autonegotiation": "on",
        "tx-gso-robust": "off [fixed]",
        "tcp-segmentation-offload/tx-tcp-mangleid-segmentation": "off",
        "rx-udp_tunnel-port-offload": "off [fixed]",
        "netns-local": "off [fixed]",
        "TX negotiated": "on",
        "serial": "b0:83:fe:c6:63:86",
        "speed": "1Gbit/s",
        "size": 1000000000,
        "l2-fwd-offload": "off [fixed]",
        "latency": 0,
        "tx-checksumming/tx-checksum-ipv6": "on",
        "tx-gre-segmentation": "off [fixed]",
        "TX": "on",
        "ipv4-netmask": "255.255.255.0",
        "duplex": "full",
        "tcp-segmentation-offload": "on",
        "Autonegotiate": "on",
        "tx-udp_tnl-segmentation": "off [fixed]",
        "RX": "on",
        "firmware": "FFV7.10.17 bc 5720-v1.34",
        "fcoe-mtu": "off [fixed]",
        "tcp-segmentation-offload/tx-tcp-ecn-segmentation": "on",
        "vendor": "Broadcom Limited",
        "large-receive-offload": "off [fixed]",
        "tx-sctp-segmentation": "off [fixed]",
        "RX negotiated": "on",
        "ipv4": "10.8.146.101",
        "tx-gso-partial": "off [fixed]",
        "ipv4-cidr": 24,
        "rx-vlan-stag-hw-parse": "off [fixed]",
        "tx-vlan-offload": "on [fixed]",
        "product": "NetXtreme BCM5720 Gigabit Ethernet PCIe",
        "tx-nocache-copy": "off",
        "udp-fragmentation-offload": "off [fixed]",
        "tx-checksumming/tx-checksum-sctp": "off [fixed]",
        "driver": "tg3",
        "tx-sit-segmentation": "off [fixed]",
        "busy-poll": "off [fixed]",
        "scatter-gather/tx-scatter-gather": "on",
        "tx-checksumming/tx-checksum-ip-generic": "off [fixed]",
        "tx-vlan-stag-hw-insert": "off [fixed]",
        "loopback": "off [fixed]",
        "rx-all": "off [fixed]",
        "tx-ipip-segmentation": "off [fixed]",
        "tcp-segmentation-offload/tx-tcp6-segmentation": "on",
        "rx-checksumming": "on",
        "tcp-segmentation-offload/tx-tcp-segmentation": "on",
        "generic-receive-offload": "on",
        "tx-checksumming/tx-checksum-ipv4": "on",
        "generic-segmentation-offload": "on",
        "tx-fcoe-segmentation": "off [fixed]",
        "tx-lockless": "off [fixed]",
        "tx-checksumming/tx-checksum-fcoe-crc": "off [fixed]",
        "tx-checksumming": "on",
        "ntuple-filters": "off [fixed]",
        "rx-vlan-filter": "off [fixed]",
        "tx-gre-csum-segmentation": "off [fixed]",
        "businfo": "pci@0000:02:00.0",
        "receive-hashing": "off [fixed]",
        "scatter-gather/tx-scatter-gather-fraglist": "off [fixed]",
        "link": "yes",
        "rx-fcs": "off [fixed]",
        "scatter-gather": "on",
        "hw-tc-offload": "off [fixed]"
      },
      "em2": {
        "tx-udp_tnl-csum-segmentation": "off [fixed]",
        "vlan-challenged": "off [fixed]",
        "rx-vlan-offload": "on [fixed]",
        "tx-vlan-stag-hw-insert": "off [fixed]",
        "rx-vlan-stag-filter": "off [fixed]",
        "highdma": "on",
        "autonegotiation": "on",
        "tx-gso-robust": "off [fixed]",
        "tcp-segmentation-offload/tx-tcp-mangleid-segmentation": "off",
        "rx-udp_tunnel-port-offload": "off [fixed]",
        "netns-local": "off [fixed]",
        "TX negotiated": "on",
        "serial": "b0:83:fe:c6:63:87",
        "speed": "1Gbit/s",
        "size": 1000000000,
        "l2-fwd-offload": "off [fixed]",
        "latency": 0,
        "tx-checksumming/tx-checksum-ipv6": "on",
        "tx-gre-segmentation": "off [fixed]",
        "tx-checksumming/tx-checksum-ipv4": "on",
        "tx-fcoe-segmentation": "off [fixed]",
        "duplex": "full",
        "tcp-segmentation-offload": "on",
        "Autonegotiate": "on",
        "tx-udp_tnl-segmentation": "off [fixed]",
        "RX": "on",
        "firmware": "FFV7.10.17 bc 5720-v1.34",
        "fcoe-mtu": "off [fixed]",
        "tcp-segmentation-offload/tx-tcp-ecn-segmentation": "on",
        "vendor": "Broadcom Limited",
        "large-receive-offload": "off [fixed]",
        "tx-sctp-segmentation": "off [fixed]",
        "RX negotiated": "on",
        "rx-vlan-stag-hw-parse": "off [fixed]",
        "businfo": "pci@0000:02:00.1",
        "tx-vlan-offload": "on [fixed]",
        "product": "NetXtreme BCM5720 Gigabit Ethernet PCIe",
        "tx-nocache-copy": "off",
        "udp-fragmentation-offload": "off [fixed]",
        "tx-checksumming/tx-checksum-sctp": "off [fixed]",
        "driver": "tg3",
        "tx-sit-segmentation": "off [fixed]",
        "busy-poll": "off [fixed]",
        "scatter-gather/tx-scatter-gather": "on",
        "tx-checksumming/tx-checksum-ip-generic": "off [fixed]",
        "link": "yes",
        "rx-all": "off [fixed]",
        "tx-ipip-segmentation": "off [fixed]",
        "tcp-segmentation-offload/tx-tcp6-segmentation": "on",
        "rx-checksumming": "on",
        "tcp-segmentation-offload/tx-tcp-segmentation": "on",
        "TX": "on",
        "generic-segmentation-offload": "on",
        "loopback": "off [fixed]",
        "tx-lockless": "off [fixed]",
        "tx-checksumming/tx-checksum-fcoe-crc": "off [fixed]",
        "tx-checksumming": "on",
        "ntuple-filters": "off [fixed]",
        "rx-vlan-filter": "off [fixed]",
        "tx-gre-csum-segmentation": "off [fixed]",
        "tx-gso-partial": "off [fixed]",
        "receive-hashing": "off [fixed]",
        "scatter-gather/tx-scatter-gather-fraglist": "off [fixed]",
        "generic-receive-offload": "on",
        "rx-fcs": "off [fixed]",
        "scatter-gather": "on",
        "hw-tc-offload": "off [fixed]"
      }
    },
    "ipmi": {
      "Mem Fatal SB CRC": {
        "value": "Not Readable"
      },
      "Redundancy": {
        "value": "Not Readable"
      },
      "Fan4A RPM": {
        "value": 1920,
        "unit": "RPM"
      },
      "Fan3B RPM": {
        "value": 1800,
        "unit": "RPM"
      },
      "Unknown": {
        "value": "Not Readable"
      },
      "SBE Log Disabled": {
        "value": "Not Readable"
      },
      "Voltage 2": {
        "value": 206,
        "unit": "Volts"
      },
      "CPU Init Err": {
        "value": "Not Readable"
      },
      "Mem CRC Err": {
        "value": "Not Readable"
      },
      "Dedicated NIC": {
        "value": "0x00"
      },
      "PCIe Slot3": {
        "value": "Not Readable"
      },
      "PCIe Slot2": {
        "value": "0x00"
      },
      "PCIe Slot1": {
        "value": "Not Readable"
      },
      "ROMB Battery": {
        "value": "Not Readable"
      },
      "PCIe Slot4": {
        "value": "Not Readable"
      },
      "Memory Added": {
        "value": "0x00"
      },
      "Fan1B RPM": {
        "value": 2280,
        "unit": "RPM"
      },
      "3.3V PG": {
        "value": "0x00"
      },
      "CMOS Battery": {
        "value": "0x00"
      },
      "POST Err": {
        "value": "0x00"
      },
      "Fan5A RPM": {
        "value": 1920,
        "unit": "RPM"
      },
      "Power Cable": {
        "value": "0x00"
      },
      "Drive 0": {
        "value": "0x00"
      },
      "Memory Mirrored": {
        "value": "Not Readable"
      },
      "Riser 2 Presence": {
        "value": "0x00"
      },
      "Presence": {
        "value": "0x00"
      },
      "Mem Fatal NB CRC": {
        "value": "Not Readable"
      },
      "Memory Cfg Err": {
        "value": "Not Readable"
      },
      "PS Redundancy": {
        "value": "0x00"
      },
      "Riser Config Err": {
        "value": "0x00"
      },
      "PS1 PG Fail": {
        "value": "0x00"
      },
      "Riser 1 Presence": {
        "value": "0x00"
      },
      "Cable SAS D": {
        "value": "Not Readable"
      },
      "lan": {
        "802.1q-vlan-id": "Disabled",
        "802.1q-vlan-priority": 0,
        "default-gateway-ip": "10.9.31.254",
        "set-in-progress": "Set Complete",
        "rmcp+-cipher-suites": "0,1,2,3,4,5,6,7,8,9,10,11,12,13,14",
        "ip-address-source": "DHCP Address",
        "gratituous-arp-intrvl": "2.0 seconds",
        "backup-gateway-ip": "0.0.0.0",
        "bmc-arp-control": "ARP Responses Enabled, Gratuitous ARP Disabled",
        "auth-type-enable": "Callback : MD2 MD5",
        "ip-header": "TTL=0x40 Flags=0x40 Precedence=0x00 TOS=0x10",
        "bad-password-threshold": "Not Available",
        "ip-address": "10.9.10.109",
        "default-gateway-mac": "00:00:00:00:00:00",
        "auth-type-support": "NONE MD2 MD5 PASSWORD",
        "snmp-community-string": "public",
        "backup-gateway-mac": "00:00:00:00:00:00",
        "cipher-suite-priv-max": "Xaaaaaaaaaaaaaa",
        "mac-address": "b0:83:fe:c6:63:88",
        "subnet-mask": "255.255.224.0"
      },
      "Non Fatal PCI Er": {
        "value": "Not Readable"
      },
      "Memory RAID": {
        "value": "Not Readable"
      },
      "VGA Cable Pres": {
        "value": "0x00"
      },
      "BP1 5V PG": {
        "value": "0x00"
      },
      "Intrusion": {
        "value": "0x00"
      },
      "OS Watchdog Time": {
        "value": "0x00"
      },
      "PFault Fail Safe": {
        "value": "Not Readable"
      },
      "Status": {
        "value": "0x00"
      },
      "Fan5B RPM": {
        "value": 1800,
        "unit": "RPM"
      },
      "VSA PG": {
        "value": "0x00"
      },
      "OS Watchdog": {
        "value": "0x00"
      },
      "Fan2B RPM": {
        "value": 1800,
        "unit": "RPM"
      },
      "CPU Protocol Err": {
        "value": "Not Readable"
      },
      "PCI Parity Err": {
        "value": "0x95"
      },
      "Fan1A RPM": {
        "value": 3120,
        "unit": "RPM"
      },
      "PCIE Fatal Err": {
        "value": "Not Readable"
      },
      "CPU Machine Chk": {
        "value": "Not Readable"
      },
      "Cable SAS C": {
        "value": "Not Readable"
      },
      "Cable SAS B": {
        "value": "0x00"
      },
      "Cable SAS A": {
        "value": "0x00"
      },
      "Current 2": {
        "value": "0.20",
        "unit": "Amps"
      },
      "Current 1": {
        "value": "0.40",
        "unit": "Amps"
      },
      "MSR Info Log": {
        "value": "0x00"
      },
      "Fan3A RPM": {
        "value": 1800,
        "unit": "RPM"
      },
      "1.5V PG": {
        "value": "0x00"
      },
      "5V PG": {
        "value": "0x00"
      },
      "Inlet Temp": {
        "value": 21,
        "unit": "degrees C"
      },
      "Logging Disabled": {
        "value": "Not Readable"
      },
      "Mem ECC Warning": {
        "value": "Not Readable"
      },
      "CPU Bus PERR": {
        "value": "Not Readable"
      },
      "SEL": {
        "value": "Not Readable"
      },
      "MEM VDDQ PG": {
        "value": "0x00"
      },
      "Pwr Consumption": {
        "value": 70,
        "unit": "Watts"
      },
      "Signal Cable": {
        "value": "0x00"
      },
      "Fan Redundancy": {
        "value": "0x00"
      },
      "ECC Uncorr Err": {
        "value": "Not Readable"
      },
      "Hdwr version err": {
        "value": "Not Readable"
      },
      "VTT PG": {
        "value": "0x00"
      },
      "LCD Cable Pres": {
        "value": "0x00"
      },
      "Memory Removed": {
        "value": "Not Readable"
      },
      "SD1": {
        "value": "Not Readable"
      },
      "SD2": {
        "value": "Not Readable"
      },
      "MEM VTT PG": {
        "value": "0x00"
      },
      "Fan4B RPM": {
        "value": 1920,
        "unit": "RPM"
      },
      "Mem Redun Gain": {
        "value": "Not Readable"
      },
      "ECC Corr Err": {
        "value": "Not Readable"
      },
      "Fan2A RPM": {
        "value": 1920,
        "unit": "RPM"
      },
      "Err Reg Pointer": {
        "value": "0x00"
      },
      "Memory Spared": {
        "value": "Not Readable"
      },
      "A": {
        "value": "0x00"
      },
      "I/O Channel Chk": {
        "value": "Not Readable"
      },
      "VCORE PG": {
        "value": "0x00"
      },
      "Temp": {
        "value": 50,
        "unit": "degrees C"
      },
      "Power Optimized": {
        "value": "0x00"
      },
      "PLL PG": {
        "value": "0x00"
      },
      "Voltage 1": {
        "value": 206,
        "unit": "Volts"
      },
      "vFlash": {
        "value": "0x00"
      },
      "USB Cable Pres": {
        "value": "0x00"
      },
      "Chipset Err": {
        "value": "0x00"
      },
      "USB Over-current": {
        "value": "Not Readable"
      },
      "PS2 PG Fail": {
        "value": "0x00"
      },
      "1.1V PG": {
        "value": "0x00"
      },
      "PCI System Err": {
        "value": "Not Readable"
      },
      "Mem Overtemp": {
        "value": "0x00"
      },
      "Fatal IO Error": {
        "value": "0x00"
      }
    },
    "firmware": {
      "bios": {
        "date": "07/10/2014",
        "version": "2.3.3",
        "vendor": "Dell Inc."
      }
    },
    "system": {
      "motherboard": {
        "serial": "..CN7792148C00M7.",
        "version": "A01",
        "vendor": "Dell Inc.",
        "name": "0KM5PX"
      },
      "kernel": {
        "cmdline": "ipa-inspection-callback-url=http://10.8.146.1:5050/v1/continue ipa-inspection-collectors=default,extra-hardware,numa-topology,logs systemd.journald.forward_to_console=yes BOOTIF=b0:83:fe:c6:63:86 ipa-debug=1 ipa-inspection-dhcp-all-interfaces=1 ipa-collect-lldp=1 initrd=agent.ramdisk",
        "version": "3.10.0-862.3.2.el7.x86_64",
        "arch": "x86_64"
      },
      "product": {
        "serial": "JLRCY12",
        "vendor": "Dell Inc.",
        "name": "PowerEdge R320 (SKU=NotProvided;ModelName=PowerEdge R320)",
        "uuid": "4C4C4544-004C-5210-8043-CAC04F593132"
      },
      "ipmi": {
        "channel": 1
      }
    },
    "memory": {
      "bank:2": {
        "slot": "DIMM_A3",
        "product": "HMT41GR7AFR4A-PB",
        "vendor": "00AD04B300AD",
        "description": "DIMM DDR3 Synchronous Registered (Buffered) 1600 MHz (0.6 ns)",
        "clock": 1600000000,
        "serial": "50764EED",
        "size": 8589934592
      },
      "bank:3": {
        "slot": "DIMM_A4",
        "product": "M393B2G70QH0-YK0",
        "vendor": "00CE00B300CE",
        "description": "DIMM DDR3 Synchronous Registered (Buffered) 1600 MHz (0.6 ns)",
        "clock": 1600000000,
        "serial": "1428D2BE",
        "size": 17179869184
      },
      "bank:0": {
        "slot": "DIMM_A1",
        "product": "M393B2G70QH0-YK0",
        "vendor": "00CE00B300CE",
        "description": "DIMM DDR3 Synchronous Registered (Buffered) 1600 MHz (0.6 ns)",
        "clock": 1600000000,
        "serial": "1324B867",
        "size": 17179869184
      },
      "bank:1": {
        "slot": "DIMM_A2",
        "product": "M393B2G70QH0-YK0",
        "vendor": "00CE00B300CE",
        "description": "DIMM DDR3 Synchronous Registered (Buffered) 1600 MHz (0.6 ns)",
        "clock": 1600000000,
        "serial": "1428D3C9",
        "size": 17179869184
      },
      "bank:4": {
        "slot": "DIMM_A5",
        "product": "M393B2G70QH0-YK0",
        "vendor": "00CE00B300CE",
        "description": "DIMM DDR3 Synchronous Registered (Buffered) 1600 MHz (0.6 ns)",
        "clock": 1600000000,
        "serial": "1324B7B3",
        "size": 17179869184
      },
      "bank:5": {
        "slot": "DIMM_A6",
        "product": "HMT41GR7AFR4A-PB",
        "vendor": "00AD04B300AD",
        "description": "DIMM DDR3 Synchronous Registered (Buffered) 1600 MHz (0.6 ns)",
        "clock": 1600000000,
        "serial": "50764F6F",
        "size": 8589934592
      },
      "banks": {
        "count": 6
      },
      "total": {
        "size": 85899345920
      }
    },
    "disk": {
      "sda{megaraid,1}": {
        "SMART/specified_start_stop_cycle_count_over_lifetime": 10000,
        "SMART/non_medium_errors_count": 55,
        "SMART/blocks_received": 1487990569,
        "SMART/health": "OK",
        "SMART/power_on_hours": "20393.68",
        "SMART/drive_trip_temperature_unit": "C",
        "SMART/verify_gigabytes_processed": "87726.547",
        "SMART/manufacture_date": "week 33 of year 2014",
        "SMART/verify_total_corrected_errors": 3540276270,
        "SMART/write_total_uncorrected_errors": 0,
        "SMART/write_gigabytes_processed": "18954.897",
        "SMART/write_total_corrected_errors": 0,
        "SMART/vendor": "SEAGATE",
        "SMART/serial_number": "S0M3EX0G",
        "SMART/specified_load_count_over_lifetime": 300000,
        "SMART/current_drive_temperature_unit": "C",
        "SMART/blocks_read_from_cache": 1294981828,
        "SMART/load_count": 4228,
        "SMART/drive_trip_temperature": 50,
        "SMART/read_gigabytes_processed": "8969.755",
        "SMART/read_total_corrected_errors": 2628931962,
        "SMART/read_total_uncorrected_errors": 0,
        "SMART/verify_total_uncorrected_errors": 0,
        "SMART/blocks_sent": 401498517,
        "SMART/current_drive_temperature": 27,
        "SMART/start_stop_cycle_count": 738,
        "SMART/product": "ST600MM0006"
      },
      "sda": {
        "Write Cache Enable": 1,
        "rotational": 1,
        "vendor": "DELL",
        "SMART/serial_number": "008684c60f7eccd21b00ebd0d2e03f08",
        "rev": "3.13",
        "scsi-id": "scsi-36b083fe0d2d0eb001bd2cc7e0fc68486",
        "optimal_io_size": 0,
        "SMART/vendor": "DELL",
        "wwn-id": "wwn-0x6b083fe0d2d0eb001bd2cc7e0fc68486",
        "physical_block_size": 512,
        "Read Cache Disable": 0,
        "model": "PERC H710",
        "SMART/product": "PERC H710",
        "size": 599
      },
      "logical": {
        "count": 1
      },
      "sda{megaraid,0}": {
        "SMART/specified_start_stop_cycle_count_over_lifetime": 10000,
        "SMART/non_medium_errors_count": 31,
        "SMART/blocks_received": 2118230176,
        "SMART/health": "OK",
        "SMART/power_on_hours": "20390.07",
        "SMART/drive_trip_temperature_unit": "C",
        "SMART/verify_gigabytes_processed": "87251.333",
        "SMART/manufacture_date": "week 33 of year 2014",
        "SMART/verify_total_corrected_errors": 137083140,
        "SMART/write_total_uncorrected_errors": 0,
        "SMART/write_gigabytes_processed": "19447.522",
        "SMART/write_total_corrected_errors": 0,
        "SMART/vendor": "SEAGATE",
        "SMART/serial_number": "S0M3EYH8",
        "SMART/specified_load_count_over_lifetime": 300000,
        "SMART/current_drive_temperature_unit": "C",
        "SMART/blocks_read_from_cache": 1539521174,
        "SMART/load_count": 4234,
        "SMART/drive_trip_temperature": 50,
        "SMART/read_gigabytes_processed": "8302.626",
        "SMART/read_total_corrected_errors": 3214892750,
        "SMART/read_total_uncorrected_errors": 0,
        "SMART/verify_total_uncorrected_errors": 0,
        "SMART/blocks_sent": 2456935760,
        "SMART/current_drive_temperature": 27,
        "SMART/start_stop_cycle_count": 739,
        "SMART/product": "ST600MM0006"
      }
    },
    "cpu": {
      "physical_0": {
        "physid": 400,
        "product": "Intel(R) Xeon(R) CPU E5-2440 v2 @ 1.90GHz",
        "enabled_cores": 8,
        "vendor": "Intel Corp.",
        "clock": 2105032704,
        "frequency": 1842480000,
        "version": "Intel(R) Xeon(R) CPU E5-2440 v2 @ 1.90GHz",
        "threads": 16,
        "cores": 8,
        "flags": "lm fpu fpu_exception wp vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp x86-64 constant_tsc arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc aperfmperf eagerfpu pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm pcid dca sse4_1 sse4_2 x2apic popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm tpr_shadow vnmi flexpriority ept vpid fsgsbase smep erms xsaveopt ibpb ibrs dtherm ida arat pln pts cpufreq"
      },
      "logical": {
        "number": 16
      },
      "physical": {
        "number": 1
      }
    }
  },
  "all_interfaces": {
    "p2p2": {
      "ip": null,
      "mac": "a0:36:9f:52:7f:b3",
      "lldp_processed": {
        "switch_port_mau_type": "Unknown",
        "switch_capabilities_enabled": [
          "Bridge",
          "Router"
        ],
        "switch_port_description": "host02.beaker.tripleo.lab.eng.rdu2 port 4 (Bond)",
        "switch_port_physical_capabilities": [
          "1000BASE-T fdx"
        ],
        "switch_port_id": "ge-1/0/26",
        "switch_mgmt_addresses": [
          "10.10.191.229"
        ],
        "switch_capabilities_support": [
          "Bridge",
          "Router"
        ],
        "switch_port_autonegotiation_support": true,
        "switch_port_link_aggregation_id": 662,
        "switch_system_name": "sw01-dist-1b-b12.rdu2",
        "switch_port_link_aggregation_enabled": true,
        "switch_port_link_aggregation_support": true,
        "switch_system_description": "Juniper Networks, Inc. ex4200-48t Ethernet Switch, kernel JUNOS 15.1R6.7, Build date: 2017-04-23 01:16:48 UTC Copyright (c) 1996-2017 Juniper Networks, Inc.",
        "switch_port_vlans": [
          {
            "name": "vlan101",
            "id": 101
          },
          {
            "name": "vlan102",
            "id": 102
          },
          {
            "name": "vlan104",
            "id": 104
          },
          {
            "name": "vlan2001",
            "id": 2001
          },
          {
            "name": "vlan2002",
            "id": 2002
          }
        ],
        "switch_chassis_id": "64:64:9b:32:f3:00",
        "switch_port_untagged_vlan_id": 102,
        "switch_port_autonegotiation_enabled": true,
        "switch_port_mtu": 1514
      },
      "client_id": null,
      "pxe": false
    },
    "p2p1": {
      "ip": null,
      "mac": "a0:36:9f:52:7f:b2",
      "lldp_processed": {
        "switch_port_mau_type": "Unknown",
        "switch_capabilities_enabled": [
          "Bridge",
          "Router"
        ],
        "switch_port_description": "host02.beaker.tripleo.lab.eng.rdu2 port 3 (Bond)",
        "switch_port_physical_capabilities": [
          "1000BASE-T fdx"
        ],
        "switch_port_id": "ge-0/0/26",
        "switch_mgmt_addresses": [
          "10.10.191.229"
        ],
        "switch_capabilities_support": [
          "Bridge",
          "Router"
        ],
        "switch_port_autonegotiation_support": true,
        "switch_port_link_aggregation_id": 662,
        "switch_system_name": "sw01-dist-1b-b12.rdu2",
        "switch_port_link_aggregation_enabled": true,
        "switch_port_link_aggregation_support": true,
        "switch_system_description": "Juniper Networks, Inc. ex4200-48t Ethernet Switch, kernel JUNOS 15.1R6.7, Build date: 2017-04-23 01:16:48 UTC Copyright (c) 1996-2017 Juniper Networks, Inc.",
        "switch_port_vlans": [
          {
            "name": "vlan101",
            "id": 101
          },
          {
            "name": "vlan102",
            "id": 102
          },
          {
            "name": "vlan104",
            "id": 104
          },
          {
            "name": "vlan2001",
            "id": 2001
          },
          {
            "name": "vlan2002",
            "id": 2002
          }
        ],
        "switch_chassis_id": "64:64:9b:32:f3:00",
        "switch_port_untagged_vlan_id": 102,
        "switch_port_autonegotiation_enabled": true,
        "switch_port_mtu": 1514
      },
      "client_id": null,
      "pxe": false
    },
    "em1": {
      "ip": "10.8.146.101",
      "mac": "b0:83:fe:c6:63:86",
      "lldp_processed": {
        "switch_port_mau_type": "Unknown",
        "switch_capabilities_enabled": [
          "Bridge",
          "Router"
        ],
        "switch_port_description": "host02.beaker.tripleo.lab.eng.rdu2 port 1 (Prov/Trunked VLANs)",
        "switch_port_physical_capabilities": [
          "1000BASE-T fdx",
          "100BASE-TX fdx",
          "100BASE-TX hdx",
          "10BASE-T fdx",
          "10BASE-T hdx",
          "Asym and Sym PAUSE fdx"
        ],
        "switch_port_id": "ge-0/0/25",
        "switch_mgmt_addresses": [
          "10.10.191.229"
        ],
        "switch_capabilities_support": [
          "Bridge",
          "Router"
        ],
        "switch_port_autonegotiation_support": true,
        "switch_port_link_aggregation_id": 0,
        "switch_system_name": "sw01-dist-1b-b12.rdu2",
        "switch_port_link_aggregation_enabled": false,
        "switch_port_link_aggregation_support": true,
        "switch_system_description": "Juniper Networks, Inc. ex4200-48t Ethernet Switch, kernel JUNOS 15.1R6.7, Build date: 2017-04-23 01:16:48 UTC Copyright (c) 1996-2017 Juniper Networks, Inc.",
        "switch_port_vlans": [
          {
            "name": "vlan101",
            "id": 101
          },
          {
            "name": "vlan102",
            "id": 102
          },
          {
            "name": "vlan104",
            "id": 104
          },
          {
            "name": "vlan2001",
            "id": 2001
          },
          {
            "name": "vlan2002",
            "id": 2002
          }
        ],
        "switch_chassis_id": "64:64:9b:32:f3:00",
        "switch_port_untagged_vlan_id": 102,
        "switch_port_autonegotiation_enabled": true,
        "switch_port_mtu": 9216
      },
      "client_id": null,
      "pxe": true
    },
    "em2": {
      "ip": null,
      "mac": "b0:83:fe:c6:63:87",
      "lldp_processed": {
        "switch_port_mau_type": "Unknown",
        "switch_capabilities_enabled": [
          "Bridge",
          "Router"
        ],
        "switch_port_description": "host02.beaker.tripleo.lab.eng.rdu2 port 2 (Storage)",
        "switch_port_physical_capabilities": [
          "1000BASE-T fdx",
          "100BASE-TX fdx",
          "100BASE-TX hdx",
          "10BASE-T fdx",
          "10BASE-T hdx",
          "Asym and Sym PAUSE fdx"
        ],
        "switch_port_id": "ge-1/0/25",
        "switch_mgmt_addresses": [
          "10.10.191.229"
        ],
        "switch_capabilities_support": [
          "Bridge",
          "Router"
        ],
        "switch_port_autonegotiation_support": true,
        "switch_port_link_aggregation_id": 0,
        "switch_system_name": "sw01-dist-1b-b12.rdu2",
        "switch_port_link_aggregation_enabled": false,
        "switch_port_link_aggregation_support": true,
        "switch_system_description": "Juniper Networks, Inc. ex4200-48t Ethernet Switch, kernel JUNOS 15.1R6.7, Build date: 2017-04-23 01:16:48 UTC Copyright (c) 1996-2017 Juniper Networks, Inc.",
        "switch_port_vlans": [
          {
            "name": "vlan101",
            "id": 101
          },
          {
            "name": "vlan104",
            "id": 104
          },
          {
            "name": "vlan2001",
            "id": 2001
          },
          {
            "name": "vlan2002",
            "id": 2002
          },
          {
            "name": "vlan2003",
            "id": 2003
          }
        ],
        "switch_chassis_id": "64:64:9b:32:f3:00",
        "switch_port_mtu": 9216,
        "switch_port_autonegotiation_enabled": true
      },
      "client_id": null,
      "pxe": false
    }
  },
  "cpus": 16,
  "boot_interface": "b0:83:fe:c6:63:86",
  "memory_mb": 81920,
  "ipmi_address": "10.9.10.109",
  "numa_topology": {
    "nics": [
      {
        "numa_node": 0,
        "name": "p2p1"
      },
      {
        "numa_node": 0,
        "name": "p2p2"
      },
      {
        "numa_node": 0,
        "name": "em2"
      },
      {
        "numa_node": 0,
        "name": "em1"
      }
    ],
    "ram": [
      {
        "numa_node": 0,
        "size_kb": 83839532
      }
    ],
    "cpus": [
      {
        "numa_node": 0,
        "thread_siblings": [
          1,
          9
        ],
        "cpu": 1
      },
      {
        "numa_node": 0,
        "thread_siblings": [
          0,
          8
        ],
        "cpu": 0
      },
      {
        "numa_node": 0,
        "thread_siblings": [
          7,
          15
        ],
        "cpu": 7
      },
      {
        "numa_node": 0,
        "thread_siblings": [
          6,
          14
        ],
        "cpu": 6
      },
      {
        "numa_node": 0,
        "thread_siblings": [
          5,
          13
        ],
        "cpu": 5
      },
      {
        "numa_node": 0,
        "thread_siblings": [
          4,
          12
        ],
        "cpu": 4
      },
      {
        "numa_node": 0,
        "thread_siblings": [
          3,
          11
        ],
        "cpu": 3
      },
      {
        "numa_node": 0,
        "thread_siblings": [
          2,
          10
        ],
        "cpu": 2
      }
    ]
  },
  "error": null,
  "local_gb": 557,
  "interfaces": {
    "em1": {
      "ip": "10.8.146.101",
      "mac": "b0:83:fe:c6:63:86",
      "lldp_processed": {
        "switch_port_mau_type": "Unknown",
        "switch_capabilities_enabled": [
          "Bridge",
          "Router"
        ],
        "switch_port_description": "host02.beaker.tripleo.lab.eng.rdu2 port 1 (Prov/Trunked VLANs)",
        "switch_port_physical_capabilities": [
          "1000BASE-T fdx",
          "100BASE-TX fdx",
          "100BASE-TX hdx",
          "10BASE-T fdx",
          "10BASE-T hdx",
          "Asym and Sym PAUSE fdx"
        ],
        "switch_port_id": "ge-0/0/25",
        "switch_mgmt_addresses": [
          "10.10.191.229"
        ],
        "switch_capabilities_support": [
          "Bridge",
          "Router"
        ],
        "switch_port_autonegotiation_support": true,
        "switch_port_link_aggregation_id": 0,
        "switch_system_name": "sw01-dist-1b-b12.rdu2",
        "switch_port_link_aggregation_enabled": false,
        "switch_port_link_aggregation_support": true,
        "switch_system_description": "Juniper Networks, Inc. ex4200-48t Ethernet Switch, kernel JUNOS 15.1R6.7, Build date: 2017-04-23 01:16:48 UTC Copyright (c) 1996-2017 Juniper Networks, Inc.",
        "switch_port_vlans": [
          {
            "name": "vlan101",
            "id": 101
          },
          {
            "name": "vlan102",
            "id": 102
          },
          {
            "name": "vlan104",
            "id": 104
          },
          {
            "name": "vlan2001",
            "id": 2001
          },
          {
            "name": "vlan2002",
            "id": 2002
          }
        ],
        "switch_chassis_id": "64:64:9b:32:f3:00",
        "switch_port_untagged_vlan_id": 102,
        "switch_port_autonegotiation_enabled": true,
        "switch_port_mtu": 9216
      },
      "client_id": null,
      "pxe": true
    }
  },
  "inventory": {
    "bmc_address": "10.9.10.109",
    "interfaces": [
      {
        "lldp": [
          [
            1,
            "0464649b32f300"
          ],
          [
            2,
            "0567652d302f302f3236"
          ],
          [
            3,
            "003c"
          ],
          [
            5,
            "737730312d646973742d31622d6231322e72647532"
          ],
          [
            6,
            "4a756e69706572204e6574776f726b732c20496e632e206578343230302d3438742045746865726e6574205377697463682c206b65726e656c204a554e4f532031352e3152362e372c204275696c6420646174653a20323031372d30342d32332030313a31363a34382055544320436f707972696768742028632920313939362d32303137204a756e69706572204e6574776f726b732c20496e632e"
          ],
          [
            7,
            "00140014"
          ],
          [
            8,
            "05010a0abfe501000000000c0103060102011f0101010100"
          ],
          [
            4,
            "686f737430322e6265616b65722e747269706c656f2e6c61622e656e672e7264753220706f727420332028426f6e6429"
          ],
          [
            127,
            "00120f010300010000"
          ],
          [
            127,
            "00120f030300000296"
          ],
          [
            127,
            "00120f0405ea"
          ],
          [
            127,
            "0080c2010066"
          ],
          [
            127,
            "00906901425030323134323530393236"
          ],
          [
            127,
            "0080c203006507766c616e313031"
          ],
          [
            127,
            "0080c203006607766c616e313032"
          ],
          [
            127,
            "0080c203006807766c616e313034"
          ],
          [
            127,
            "0080c20307d108766c616e32303031"
          ],
          [
            127,
            "0080c20307d208766c616e32303032"
          ],
          [
            127,
            "0012bb01000f04"
          ],
          [
            0,
            ""
          ]
        ],
        "product": "0x1521",
        "vendor": "0x8086",
        "name": "p2p1",
        "has_carrier": true,
        "ipv4_address": null,
        "biosdevname": "p2p1",
        "client_id": null,
        "mac_address": "a0:36:9f:52:7f:b2"
      },
      {
        "lldp": [
          [
            1,
            "0464649b32f300"
          ],
          [
            2,
            "0567652d312f302f3236"
          ],
          [
            3,
            "003c"
          ],
          [
            5,
            "737730312d646973742d31622d6231322e72647532"
          ],
          [
            6,
            "4a756e69706572204e6574776f726b732c20496e632e206578343230302d3438742045746865726e6574205377697463682c206b65726e656c204a554e4f532031352e3152362e372c204275696c6420646174653a20323031372d30342d32332030313a31363a34382055544320436f707972696768742028632920313939362d32303137204a756e69706572204e6574776f726b732c20496e632e"
          ],
          [
            7,
            "00140014"
          ],
          [
            8,
            "05010a0abfe501000000000c0103060102011f0101010100"
          ],
          [
            4,
            "686f737430322e6265616b65722e747269706c656f2e6c61622e656e672e7264753220706f727420342028426f6e6429"
          ],
          [
            127,
            "00120f010300010000"
          ],
          [
            127,
            "00120f030300000296"
          ],
          [
            127,
            "00120f0405ea"
          ],
          [
            127,
            "0080c2010066"
          ],
          [
            127,
            "00906901425030323134323531303731"
          ],
          [
            127,
            "0080c203006507766c616e313031"
          ],
          [
            127,
            "0080c203006607766c616e313032"
          ],
          [
            127,
            "0080c203006807766c616e313034"
          ],
          [
            127,
            "0080c20307d108766c616e32303031"
          ],
          [
            127,
            "0080c20307d208766c616e32303032"
          ],
          [
            127,
            "0012bb01000f04"
          ],
          [
            0,
            ""
          ]
        ],
        "product": "0x1521",
        "vendor": "0x8086",
        "name": "p2p2",
        "has_carrier": true,
        "ipv4_address": null,
        "biosdevname": "p2p2",
        "client_id": null,
        "mac_address": "a0:36:9f:52:7f:b3"
      },
      {
        "lldp": [
          [
            1,
            "0464649b32f300"
          ],
          [
            2,
            "0567652d312f302f3235"
          ],
          [
            3,
            "003c"
          ],
          [
            5,
            "737730312d646973742d31622d6231322e72647532"
          ],
          [
            6,
            "4a756e69706572204e6574776f726b732c20496e632e206578343230302d3438742045746865726e6574205377697463682c206b65726e656c204a554e4f532031352e3152362e372c204275696c6420646174653a20323031372d30342d32332030313a31363a34382055544320436f707972696768742028632920313939362d32303137204a756e69706572204e6574776f726b732c20496e632e"
          ],
          [
            7,
            "00140014"
          ],
          [
            8,
            "05010a0abfe501000000000c0103060102011f0101010100"
          ],
          [
            4,
            "686f737430322e6265616b65722e747269706c656f2e6c61622e656e672e7264753220706f72742032202853746f7261676529"
          ],
          [
            127,
            "00120f01036c110000"
          ],
          [
            127,
            "00120f030100000000"
          ],
          [
            127,
            "00120f042400"
          ],
          [
            127,
            "00906901425030323134323531303731"
          ],
          [
            127,
            "0080c203006507766c616e313031"
          ],
          [
            127,
            "0080c203006807766c616e313034"
          ],
          [
            127,
            "0080c20307d108766c616e32303031"
          ],
          [
            127,
            "0080c20307d208766c616e32303032"
          ],
          [
            127,
            "0080c20307d308766c616e32303033"
          ],
          [
            127,
            "0012bb01000f04"
          ],
          [
            0,
            ""
          ]
        ],
        "product": "0x165f",
        "vendor": "0x14e4",
        "name": "em2",
        "has_carrier": true,
        "ipv4_address": null,
        "biosdevname": "em2",
        "client_id": null,
        "mac_address": "b0:83:fe:c6:63:87"
      },
      {
        "lldp": [
          [
            1,
            "0464649b32f300"
          ],
          [
            2,
            "0567652d302f302f3235"
          ],
          [
            3,
            "003c"
          ],
          [
            5,
            "737730312d646973742d31622d6231322e72647532"
          ],
          [
            6,
            "4a756e69706572204e6574776f726b732c20496e632e206578343230302d3438742045746865726e6574205377697463682c206b65726e656c204a554e4f532031352e3152362e372c204275696c6420646174653a20323031372d30342d32332030313a31363a34382055544320436f707972696768742028632920313939362d32303137204a756e69706572204e6574776f726b732c20496e632e"
          ],
          [
            7,
            "00140014"
          ],
          [
            8,
            "05010a0abfe501000000000c0103060102011f0101010100"
          ],
          [
            4,
            "686f737430322e6265616b65722e747269706c656f2e6c61622e656e672e7264753220706f72742031202850726f762f5472756e6b656420564c414e7329"
          ],
          [
            127,
            "00120f01036c110000"
          ],
          [
            127,
            "00120f030100000000"
          ],
          [
            127,
            "00120f042400"
          ],
          [
            127,
            "0080c2010066"
          ],
          [
            127,
            "00906901425030323134323530393236"
          ],
          [
            127,
            "0080c203006507766c616e313031"
          ],
          [
            127,
            "0080c203006607766c616e313032"
          ],
          [
            127,
            "0080c203006807766c616e313034"
          ],
          [
            127,
            "0080c20307d108766c616e32303031"
          ],
          [
            127,
            "0080c20307d208766c616e32303032"
          ],
          [
            127,
            "0012bb01000f04"
          ],
          [
            0,
            ""
          ]
        ],
        "product": "0x165f",
        "vendor": "0x14e4",
        "name": "em1",
        "has_carrier": true,
        "ipv4_address": "10.8.146.101",
        "biosdevname": "em1",
        "client_id": null,
        "mac_address": "b0:83:fe:c6:63:86"
      }
    ],
    "disks": [
      {
        "rotational": true,
        "vendor": "DELL",
        "name": "/dev/sda",
        "wwn_vendor_extension": "0x1bd2cc7e0fc68486",
        "hctl": "0:2:0:0",
        "wwn_with_extension": "0x6b083fe0d2d0eb001bd2cc7e0fc68486",
        "by_path": "/dev/disk/by-path/pci-0000:01:00.0-scsi-0:2:0:0",
        "model": "PERC H710",
        "wwn": "0x6b083fe0d2d0eb00",
        "serial": "6b083fe0d2d0eb001bd2cc7e0fc68486",
        "size": 599550590976
      }
    ],
    "boot": {
      "current_boot_mode": "bios",
      "pxe_interface": "b0:83:fe:c6:63:86"
    },
    "system_vendor": {
      "serial_number": "JLRCY12",
      "product_name": "PowerEdge R320 (SKU=NotProvided;ModelName=PowerEdge R320)",
      "manufacturer": "Dell Inc."
    },
    "memory": {
      "physical_mb": 81920,
      "total": 84418736128
    },
    "cpu": {
      "count": 16,
      "frequency": "2400.0000",
      "flags": [
        "fpu", "vme", "de", "pse", "tsc", "msr", "pae", "mce", "cx8", "apic",
        "sep", "mtrr", "pge", "mca", "cmov", "pat", "pse36", "clflush", "dts",
        "acpi", "mmx", "fxsr", "sse", "sse2", "ss", "ht", "tm", "pbe",
        "syscall", "nx", "pdpe1gb", "rdtscp", "lm", "constant_tsc",
        "arch_perfmon", "pebs", "bts", "rep_good", "nopl", "xtopology",
        "nonstop_tsc", "aperfmperf", "eagerfpu", "pni", "pclmulqdq", "dtes64",
        "monitor", "ds_cpl", "vmx", "smx", "est", "tm2", "ssse3", "cx16",
        "xtpr", "pdcm", "pcid", "dca", "sse4_1", "sse4_2", "x2apic", "popcnt",
        "tsc_deadline_timer", "aes", "xsave", "avx", "f16c", "rdrand",
        "lahf_lm", "tpr_shadow", "vnmi", "flexpriority", "ept", "vpid",
        "fsgsbase", "smep", "erms", "xsaveopt", "ibpb", "ibrs", "dtherm",
        "ida", "arat", "pln", "pts"
      ],
      "model_name": "Intel(R) Xeon(R) CPU E5-2440 v2 @ 1.90GHz",
      "architecture": "x86_64"
    }
  }
}
```
