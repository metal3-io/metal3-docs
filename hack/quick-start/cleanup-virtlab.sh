#!/usr/bin/env bash

set -x

# Stop and remove containers
docker rm -f sushy-tools

sudo virsh -c qemu:///system destroy --domain "bmh-vm-01"
sudo virsh -c qemu:///system undefine --domain "bmh-vm-01" --remove-all-storage --nvram

# Cleanup network
sudo virsh -c qemu:///system net-destroy baremetal-e2e
sudo virsh -c qemu:///system net-undefine baremetal-e2e

# Cleanup network interfaces and docker network
sudo ip link delete metalend type veth
docker network rm kind

# Cleanup iptables rules
sudo iptables -D FORWARD -i kind -o metal3 -j ACCEPT
sudo iptables -D FORWARD -i metal3 -o kind -j ACCEPT
