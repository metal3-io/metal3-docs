# Glossary

Metal3 is a Cluster API provider, you might also want to take a look at
[CAPI glossary](https://cluster-api.sigs.k8s.io/reference/glossary).

## Abbreviations

| Abbreviation | Full Name | Description |
|--------------|-----------|-------------|
| BIOS | [Basic Input/Output System](https://en.wikipedia.org/wiki/BIOS) | Legacy firmware interface for booting computers, being replaced by UEFI |
| BMC | [Baseboard Management Controller](https://en.wikipedia.org/wiki/Baseboard_management_controller) | Out-of-band management chip enabling remote power control, console access, and hardware monitoring independent of the host OS |
| BMH | [BareMetalHost](./bmo/introduction.md#enrolling-baremetalhosts) | Metal3 Kubernetes custom resource representing a physical server and its desired state |
| BMO | [Bare Metal Operator](./bmo/introduction.md) | Metal3 Kubernetes controller that reconciles BareMetalHost resources by communicating with Ironic |
| CAPI | [Cluster API](https://cluster-api.sigs.k8s.io/) | Kubernetes SIG project providing declarative APIs for cluster creation, configuration, and management |
| CAPM3 | [Cluster API Provider Metal3](./capm3/introduction.md) | Metal3's infrastructure provider enabling Cluster API to manage bare-metal clusters |
| DHCP | [Dynamic Host Configuration Protocol](https://en.wikipedia.org/wiki/Dynamic_Host_Configuration_Protocol) | Network protocol for automatic IP configuration; required for PXE/iPXE boot |
| EOL | [End of Life](https://en.wikipedia.org/wiki/End-of-life_product) | Version no longer receiving updates or support |
| FIPS | [Federal Information Processing Standards](https://www.nist.gov/standardsgov/compliance-faqs-federal-information-processing-standards-fips) | US government security standards for cryptographic modules |
| iDRAC | [Integrated Dell Remote Access Controller](./bmo/supported_hardware.md#redfish-and-its-variants) | Dell's BMC implementation with Redfish support |
| iLO | [Integrated Lights-Out](./bmo/supported_hardware.md#redfish-and-its-variants) | HPE's BMC implementation with Redfish support |
| IPA | [Ironic Python Agent](./ironic/ironic-python-agent.md) | Agent running in a ramdisk that executes Ironic commands on bare-metal hosts (inspection, deployment, cleaning) |
| IPAM | [IP Address Manager](./ipam/introduction.md) | Metal3 controller managing static IP allocations for cluster nodes |
| IPMI | [Intelligent Platform Management Interface](./bmo/supported_hardware.md#ipmi) | Legacy protocol for remote hardware management; less secure than Redfish |
| iRMC | [Integrated Remote Management Controller](./bmo/supported_hardware.md#vendor-specific-protocols) | Fujitsu's BMC implementation (deprecated in Metal3) |
| IrSO | [Ironic Standalone Operator](./irso/introduction.md) | Metal3 Kubernetes operator that deploys and manages Ironic |
| MAC | [Media Access Control](https://en.wikipedia.org/wiki/MAC_address) | Unique hardware address identifying a network interface |
| NIC | [Network Interface Card](https://en.wikipedia.org/wiki/Network_interface_controller) | Hardware providing network connectivity |
| PXE | [Preboot Execution Environment](https://docs.openstack.org/ironic/latest/admin/interfaces/boot.html#pxe-boot) | Intel standard for network booting via DHCP and TFTP |
| RAID | [Redundant Array of Independent Disks](./bmo/raid.md) | Technology combining multiple disks for performance or redundancy |
| SRIOV | [Single Root I/O Virtualization](https://en.wikipedia.org/wiki/Single-root_input/output_virtualization) | PCIe standard allowing a device to appear as multiple virtual devices |
| TFTP | [Trivial File Transfer Protocol](https://en.wikipedia.org/wiki/Trivial_File_Transfer_Protocol) | Simple protocol for transferring boot files; used by PXE |
| TLS | [Transport Layer Security](https://en.wikipedia.org/wiki/Transport_Layer_Security) | Cryptographic protocol securing network communications |
| UEFI | [Unified Extensible Firmware Interface](https://en.wikipedia.org/wiki/UEFI) | Modern firmware interface replacing BIOS; supports Secure Boot |
| UUID | [Universally Unique Identifier](https://en.wikipedia.org/wiki/Universally_unique_identifier) | 128-bit identifier for uniquely identifying resources |
| VBMC | [Virtual BMC](https://docs.openstack.org/virtualbmc/latest/) | Tool emulating IPMI BMC for virtual machines |

## Key Terms

| Term | Description |
|------|-------------|
| [Automated Cleaning](./bmo/automated_cleaning.md) | Ironic feature that wipes disk metadata before/after provisioning |
| [BareMetalHost](./bmo/introduction.md#enrolling-baremetalhosts) (BMH) | Metal3 custom resource representing a physical server and its desired state |
| [Bare Metal Operator](./bmo/introduction.md) (BMO) | Metal3 controller reconciling BareMetalHost resources via Ironic |
| [Bifrost](https://docs.openstack.org/bifrost/latest/) | OpenStack tool for standalone Ironic deployment |
| [Bootstrap Cluster](https://cluster-api.sigs.k8s.io/reference/glossary#bootstrap-cluster) | Temporary cluster used to provision a target management cluster |
| [cloud-init](https://cloudinit.readthedocs.io/en/latest/) | Industry-standard tool for cloud instance initialization and configuration |
| [Cluster API](https://cluster-api.sigs.k8s.io/) (CAPI) | Kubernetes SIG project for declarative cluster lifecycle management |
| [Cluster API Provider Metal3](./capm3/introduction.md) (CAPM3) | Metal3's infrastructure provider for Cluster API |
| [clusterctl](https://cluster-api.sigs.k8s.io/clusterctl/overview) | CLI tool for Cluster API cluster lifecycle management |
| [Custom Resource](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) (CR/CRD) | Kubernetes API extension for domain-specific objects; CRD defines the schema |
| [Deprovisioning](./bmo/provisioning.md#deprovisioning) | Process of removing an OS image and cleaning a host |
| [dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html) | Lightweight DNS/DHCP/TFTP server used for network boot |
| [Failure Domain](./capm3/failure_domain.md) | Topology grouping of hosts sharing common failure characteristics |
| [Finalizer](https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/) | Kubernetes mechanism preventing resource deletion until cleanup completes |
| [Firmware Settings](./bmo/firmware_settings.md) | BIOS/UEFI configuration options manageable through Metal3 |
| [Glean](https://docs.openstack.org/infra/glean/) | Alternative to cloud-init for instance configuration |
| [Hardware Inventory](./ironic/introduction.md#host-enrollment-and-hardware-inventory) | Discovered hardware details (CPU, RAM, disks, NICs) of a host |
| [Hardware RAID](./bmo/raid.md#hardware-raid) | RAID implemented by dedicated hardware controller |
| [Host Inspection](./ironic/introduction.md#host-enrollment-and-hardware-inventory) | Process of discovering and recording hardware details of a bare-metal host |
| [Ignition](https://coreos.github.io/ignition/) | Configuration system used by Fedora CoreOS and similar distributions |
| [Infrastructure Provider](https://cluster-api.sigs.k8s.io/user/concepts#infrastructure-provider) | Cluster API component implementing cloud/platform-specific functionality |
| [IP Address Manager](./ipam/introduction.md) (IPAM) | Metal3 controller managing static IP allocations for cluster nodes |
| [IPAddress](./ipam/introduction.md#ipaddress) | IPAM resource representing an allocated IP address |
| [IPClaim](./ipam/introduction.md#ipclaim) | IPAM resource representing a request for an IP address |
| [IPPool](./ipam/introduction.md#ippool) | IPAM resource defining a pool of IP addresses for allocation |
| [iPXE](https://ipxe.org/) | Open-source network boot firmware extending PXE with HTTP support and scripting |
| [Ironic](./ironic/introduction.md) | OpenStack project for bare-metal provisioning, used by Metal3 |
| [Ironic Python Agent](./ironic/ironic-python-agent.md) (IPA) | Agent in ramdisk executing Ironic commands on bare-metal hosts |
| [Ironic Standalone Operator](./irso/introduction.md) (IrSO) | Metal3 operator deploying and managing Ironic |
| [ISO](https://en.wikipedia.org/wiki/ISO_9660) | Disc image format (ISO 9660) used for virtual media boot |
| [Keepalived](https://www.keepalived.org/) | Service providing virtual IP address failover |
| [KubeadmControlPlane](https://cluster-api.sigs.k8s.io/tasks/control-plane/kubeadm-control-plane) (KCP) | Cluster API resource managing Kubernetes control plane nodes |
| [Kustomize](https://kustomize.io/) | Kubernetes configuration customization tool |
| [Live ISO](./bmo/live-iso.md) | Bootable ISO image that runs entirely in memory without disk installation |
| [Machine](https://cluster-api.sigs.k8s.io/user/concepts#machine) | Cluster API resource representing a single Kubernetes node |
| [MachineDeployment](https://cluster-api.sigs.k8s.io/user/concepts#machinedeployment) | Cluster API resource for declarative worker node management |
| [MachineSet](https://cluster-api.sigs.k8s.io/user/concepts#machineset) | Cluster API resource maintaining a set of Machines |
| [Management Cluster](https://cluster-api.sigs.k8s.io/reference/glossary#management-cluster) | Kubernetes cluster running Metal3/CAPI controllers |
| [Metal3Cluster](./capm3/introduction.md) | CAPM3 custom resource representing cluster infrastructure |
| [Metal3Machine](./capm3/introduction.md) | CAPM3 custom resource linking a Machine to a BareMetalHost |
| [Metal3MachineTemplate](./capm3/introduction.md) | CAPM3 template for creating Metal3Machine resources |
| [Network Boot](./bmo/supported_hardware.md) | Booting a machine over the network using PXE/iPXE |
| [Network Data](./bmo/instance_customization.md#networkdata) | Configuration describing network settings for a provisioned host |
| [Node Reuse](./capm3/node_reuse.md) | Feature allowing reuse of same hosts during rolling upgrades |
| [Pivoting](./capm3/pivoting.md) | Moving cluster management from bootstrap to target cluster |
| [Preparing](./bmo/state_machine.md#preparing) | Host state where RAID/firmware configuration is applied |
| [Provisioning](./bmo/provisioning.md) | Process of deploying an OS image to a bare-metal host |
| [Provisioning Network](./irso/install-basics.md#network-boot-requirements) | Isolated L2 network for Metal3 to bare-metal communication |
| [Ramdisk](https://docs.openstack.org/ironic/latest/admin/ramdisk-boot.html) | Minimal Linux image loaded into RAM for provisioning operations |
| [Redfish](./bmo/supported_hardware.md#redfish-and-its-variants) | Modern RESTful API standard for hardware management, replacing IPMI |
| [Remediation](./capm3/remediaton.md) | Automated recovery of unhealthy cluster nodes |
| [Root Device Hints](./bmo/root_device_hints.md) | Criteria for selecting which disk to use as the root device |
| [Software RAID](./bmo/raid.md#software-raid) | RAID implemented by the Linux kernel using mdadm |
| [Sushy-tools](https://docs.openstack.org/sushy-tools/latest/) | BMC emulator implementing Redfish protocol for virtual machines |
| [Target Cluster](./capm3/pivoting.md) | Destination cluster in a pivoting operation |
| [User Data](./bmo/instance_customization.md#userdata) | Configuration script/data processed by cloud-init or similar |
| [Virtual Media](./bmo/supported_hardware.md) | Boot method using virtual CD/DVD over BMC (no provisioning network needed) |
| [Workload Cluster](https://cluster-api.sigs.k8s.io/reference/glossary#workload-cluster) | Kubernetes cluster running user applications |
