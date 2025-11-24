#!/usr/bin/env bash

docker rm -f sushy-tools

virsh -c qemu:///system destroy --domain "bmh-vm-01"
virsh -c qemu:///system undefine --domain "bmh-vm-01" --remove-all-storage --nvram

# Clear network
virsh -c qemu:///system net-destroy baremetal-e2e
virsh -c qemu:///system net-undefine baremetal-e2e

sudo iptables -D FORWARD -i kind -o metal3 -j ACCEPT
sudo iptables -D FORWARD -i metal3 -o kind -j ACCEPT

sudo ip link delete metalend type veth
