#!/usr/bin/env bash

# Define and start the baremetal-e2e network
virsh -c qemu:///system net-define net.xml
virsh -c qemu:///system net-start baremetal-e2e

# Start the sushy-emulator container that acts as BMC
docker run --name sushy-tools --rm --network host -d \
  -v /var/run/libvirt:/var/run/libvirt \
  -v "$(pwd)/sushy-tools.conf:/etc/sushy/sushy-emulator.conf" \
  -e SUSHY_EMULATOR_CONFIG=/etc/sushy/sushy-emulator.conf \
  quay.io/metal3-io/sushy-tools:latest sushy-emulator

# Generate a VM definition xml file and then define the VM
virt-install \
  --connect qemu:///system \
  --name bmh-vm-01 \
  --description "Virtualized BareMetalHost" \
  --osinfo=ubuntu-lts-latest \
  --ram=4096 \
  --vcpus=2 \
  --disk size=25 \
  --boot hd,network \
  --import \
  --network network=baremetal-e2e,mac="00:60:2f:31:81:01" \
  --noautoconsole \
  --print-xml > bmh-vm-01.xml
virsh define bmh-vm-01.xml
