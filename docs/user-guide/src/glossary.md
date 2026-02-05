# Glossary

## Abbreviations

| Abbreviation | Full Name | Description |
|--------------|-----------|-------------|
| BIOS | Basic Input/Output System | Legacy firmware interface for booting computers, being replaced by UEFI |
| BMC | Baseboard Management Controller | Out-of-band management chip enabling remote power control, console access, and hardware monitoring independent of the host OS |
| BMH | BareMetalHost | Metal3 Kubernetes custom resource representing a physical server and its desired state |
| BMO | Bare Metal Operator | Metal3 Kubernetes controller that reconciles BareMetalHost resources by communicating with Ironic |
| CAPI | Cluster API | Kubernetes SIG project providing declarative APIs for cluster creation, configuration, and management |
| CAPM3 | Cluster API Provider Metal3 | Metal3's infrastructure provider enabling Cluster API to manage bare-metal clusters |
| DHCP | Dynamic Host Configuration Protocol | Network protocol for automatic IP configuration; required for PXE/iPXE boot |
| EOL | End of Life | Version no longer receiving updates or support |
| FIPS | Federal Information Processing Standards | US government security standards for cryptographic modules |
| iDRAC | Integrated Dell Remote Access Controller | Dell's BMC implementation with Redfish support |
| iLO | Integrated Lights-Out | HPE's BMC implementation with Redfish support |
| IPA | Ironic Python Agent | Agent running in a ramdisk that executes Ironic commands on bare-metal hosts (inspection, deployment, cleaning) |
| IPAM | IP Address Manager | Metal3 controller managing static IP allocations for cluster nodes |
| IPMI | Intelligent Platform Management Interface | Legacy protocol for remote hardware management; less secure than Redfish |
| iRMC | Integrated Remote Management Controller | Fujitsu's BMC implementation (deprecated in Metal3) |
| IrSO | Ironic Standalone Operator | Metal3 Kubernetes operator that deploys and manages Ironic |
| MAC | Media Access Control | Unique hardware address identifying a network interface |
| NIC | Network Interface Card | Hardware providing network connectivity |
| PXE | Preboot Execution Environment | Intel standard for network booting via DHCP and TFTP |
| RAID | Redundant Array of Independent Disks | Technology combining multiple disks for performance or redundancy |
| SRIOV | Single Root I/O Virtualization | PCIe standard allowing a device to appear as multiple virtual devices |
| TFTP | Trivial File Transfer Protocol | Simple protocol for transferring boot files; used by PXE |
| TLS | Transport Layer Security | Cryptographic protocol securing network communications |
| UEFI | Unified Extensible Firmware Interface | Modern firmware interface replacing BIOS; supports Secure Boot |
| UUID | Universally Unique Identifier | 128-bit identifier for uniquely identifying resources |
| VBMC | Virtual BMC | Tool emulating IPMI BMC for virtual machines |

## Key Terms

| Term | Description |
|------|-------------|
| Automated Cleaning | Ironic feature that wipes disk metadata before/after provisioning |
| BareMetalHost (BMH) | Metal3 custom resource representing a physical server and its desired state |
| Bare Metal Operator (BMO) | Metal3 controller reconciling BareMetalHost resources via Ironic |
| Bifrost | OpenStack tool for standalone Ironic deployment |
| Bootstrap Cluster | Temporary management cluster used to create the initial workload cluster |
| cloud-init | Industry-standard tool for cloud instance initialization and configuration |
| Cluster API (CAPI) | Kubernetes SIG project for declarative cluster lifecycle management |
| Cluster API Provider Metal3 (CAPM3) | Metal3's infrastructure provider for Cluster API |
| clusterctl | CLI tool for Cluster API cluster lifecycle management |
| Custom Resource (CR/CRD) | Kubernetes API extension for domain-specific objects; CRD defines the schema |
| Deprovisioning | Process of removing an OS image and cleaning a host |
| dnsmasq | Lightweight DNS/DHCP/TFTP server used for network boot |
| Failure Domain | Topology grouping of hosts sharing common failure characteristics |
| Finalizer | Kubernetes mechanism preventing resource deletion until cleanup completes |
| Firmware Settings | BIOS/UEFI configuration options manageable through Metal3 |
| Glean | Alternative to cloud-init for instance configuration |
| Hardware Inventory | Discovered hardware details (CPU, RAM, disks, NICs) of a host |
| Hardware RAID | RAID implemented by dedicated hardware controller |
| Host Inspection | Process of discovering and recording hardware details of a bare-metal host |
| Ignition | Configuration system used by Fedora CoreOS and similar distributions |
| Infrastructure Provider | Cluster API component implementing cloud/platform-specific functionality |
| IP Address Manager (IPAM) | Metal3 controller managing static IP allocations for cluster nodes |
| iPXE | Open-source network boot firmware extending PXE with HTTP support and scripting |
| Ironic | OpenStack project for bare-metal provisioning, used by Metal3 |
| Ironic Python Agent (IPA) | Agent in ramdisk executing Ironic commands on bare-metal hosts |
| Ironic Standalone Operator (IrSO) | Metal3 operator deploying and managing Ironic |
| ISO | Disc image format (ISO 9660) used for virtual media boot |
| Keepalived | Service providing virtual IP address failover |
| KubeadmControlPlane (KCP) | Cluster API resource managing Kubernetes control plane nodes |
| Kustomize | Kubernetes configuration customization tool |
| Live ISO | Bootable ISO image that runs entirely in memory without disk installation |
| Machine | Cluster API resource representing a single Kubernetes node |
| MachineDeployment | Cluster API resource for declarative worker node management |
| MachineSet | Cluster API resource maintaining a set of Machines |
| Management Cluster | Kubernetes cluster running Metal3/CAPI controllers |
| Metal3Cluster | CAPM3 custom resource representing cluster infrastructure |
| Metal3Machine | CAPM3 custom resource linking a Machine to a BareMetalHost |
| Metal3MachineTemplate | CAPM3 template for creating Metal3Machine resources |
| Network Boot | Booting a machine over the network using PXE/iPXE |
| Network Data | Configuration describing network settings for a provisioned host |
| Node Reuse | Feature allowing reuse of same hosts during rolling upgrades |
| Pivoting | Moving cluster management from bootstrap to target cluster |
| Preparing | Host state where RAID/firmware configuration is applied |
| Provisioning | Process of deploying an OS image to a bare-metal host |
| Provisioning Network | Isolated L2 network for Metal3 to bare-metal communication |
| Ramdisk | Minimal Linux image loaded into RAM for provisioning operations |
| Redfish | Modern RESTful API standard for hardware management, replacing IPMI |
| Remediation | Automated recovery of unhealthy cluster nodes |
| Root Device Hints | Criteria for selecting which disk to use as the root device |
| Software RAID | RAID implemented by the Linux kernel using mdadm |
| Sushy-tools | BMC emulator implementing Redfish protocol for virtual machines |
| Target Cluster | Destination cluster in a pivoting operation |
| User Data | Configuration script/data processed by cloud-init or similar |
| Virtual Media | Boot method using virtual CD/DVD over BMC (no provisioning network needed) |
| Workload Cluster | Kubernetes cluster running user applications |
