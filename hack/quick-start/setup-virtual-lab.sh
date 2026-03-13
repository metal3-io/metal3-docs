#!/usr/bin/env bash

# Define and start the baremetal-e2e network
virsh -c qemu:///system net-define "${QUICK_START_BASE}/net.xml"
virsh -c qemu:///system net-start baremetal-e2e

# We need to create veth pair to connect the baremetal-e2e net (defined above)
# and the docker network used by kind. This is to allow controllers in
# the kind cluster to communicate with the VMs and vice versa.
# For example, Ironic needs to communicate with IPA.
# These options are the same as what kind creates by default,
# except that we hard code the IPv6 subnet and specify a bridge name.
#
# NOTE! If you used kind before, you already have this network but
# without the fixed bridge name. Please remove it first in that case!
# docker network rm kind
docker network create -d=bridge \
    -o com.docker.network.bridge.enable_ip_masquerade=true \
    -o com.docker.network.driver.mtu=1500 \
    -o com.docker.network.bridge.name="kind" \
    --ipv6 --subnet "fc00:f853:ccd:e793::/64" \
    kind

# Next create the veth pair
sudo ip link add metalend type veth peer name kindend
sudo ip link set metalend master metal3
sudo ip link set kindend master kind
sudo ip link set metalend up
sudo ip link set kindend up

# Then we need to set routing rules as well
sudo iptables -I FORWARD -i kind -o metal3 -j ACCEPT
sudo iptables -I FORWARD -i metal3 -o kind -j ACCEPT

# Start the sushy-emulator container that acts as BMC
docker run --name sushy-tools --rm --network host -d \
  -v /var/run/libvirt:/var/run/libvirt \
  -v "${QUICK_START_BASE}/sushy-emulator.conf:/etc/sushy/sushy-emulator.conf" \
  -e SUSHY_EMULATOR_CONFIG=/etc/sushy/sushy-emulator.conf \
  quay.io/metal3-io/sushy-tools:latest sushy-emulator

# Generate a VM definition xml file and then define the VM
# use --ram=8192 for Scenario 2
SERIAL_LOG_PATH="/var/log/libvirt/qemu/bmh-vm-01-serial0.log"
virt-install \
  --connect qemu:///system \
  --name bmh-vm-01 \
  --description "Virtualized BareMetalHost" \
  --osinfo=ubuntu-lts-latest \
  --ram=4096 \
  --vcpus=2 \
  --disk size=8 \
  --boot uefi,hd,network \
  --import \
  --serial file,path="${SERIAL_LOG_PATH}" \
  --xml "./devices/serial/@type=pty" \
  --xml "./devices/serial/log/@file=${SERIAL_LOG_PATH}" \
  --xml "./devices/serial/log/@append=on" \
  --network network=baremetal-e2e,mac="00:60:2f:31:81:01" \
  --noautoconsole \
  --print-xml > "${QUICK_START_BASE}/bmh-vm-01.xml"

virsh -c qemu:///system define "${QUICK_START_BASE}/bmh-vm-01.xml"
