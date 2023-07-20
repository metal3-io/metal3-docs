
# Getting started with Metal3

 Ready to start taking steps towards your first experience with metal3? Follow these commands to get started!

- [1. Environment Setup](#1-environment-setup)
  - [1.1. Prerequisites](#11-prerequisites)
  - [1.2. Setup](#12-setup)
  - [1.3. Tear Down](#13-tear-down)
  - [1.4. Using Custom Image](#14-using-custom-image)
  - [1.5. Setting environment variables](#15-setting-environment-variables)
- [2. Working with Environment](#2-working-with-environment)
  - [2.1. BareMetalHosts](#21-baremetalhosts)
  - [2.2. Provision Cluster and Machines](#22-provision-cluster-and-machines)
  - [2.3. Deprovision Cluster and Machines](#23-deprovision-cluster-and-machines)
  - [2.4. Running Custom Baremetal-Operator](#24-running-custom-baremetal-operator)
  - [2.5. Running Custom Cluster API Provider Metal3](#25-running-custom-cluster-api-provider-metal3)
    - [Tilt development environment](#tilt-development-environment)
  - [2.6. Accessing Ironic API](#26-accessing-ironic-api)

---

## 1. Environment Setup

> **_info:_** "Naming"
> For the v1alpha3 release, the Cluster API provider for Metal3 was renamed from
> Cluster API provider BareMetal (CAPBM) to Cluster API provider Metal3 (CAPM3). Hence,
> from v1alpha3 onwards it is Cluster API provider Metal3.

### 1.1. Prerequisites

- System with CentOS 9 Stream or Ubuntu 22.04
- Bare metal preferred, as we will be creating VMs to emulate bare metal hosts
- Run as a user with passwordless sudo access
- Minimum resource requirements for the host machine: 4C CPUs, 16 GB RAM memory