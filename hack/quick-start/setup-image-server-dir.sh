#!/usr/bin/env bash

mkdir "${QUICK_START_BASE}/disk-images"

pushd "${QUICK_START_BASE}/disk-images" || exit
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS
sha256sum --ignore-missing -c SHA256SUMS
wget https://artifactory.nordix.org/artifactory/metal3/images/k8s_v1.34.1/CENTOS_10_NODE_IMAGE_K8S_v1.34.1.qcow2
# Generate checksum file for the qcow2 image
sha256sum CENTOS_10_NODE_IMAGE_K8S_v1.34.1.qcow2 > CENTOS_10_NODE_IMAGE_K8S_v1.34.1.qcow2.sha256sum
# Convert to raw.
# This helps lower memory requirements, since the raw image can be streamed to disk
# instead of first loaded to memory by IPA for conversion.
qemu-img convert -f qcow2 -O raw CENTOS_10_NODE_IMAGE_K8S_v1.34.1.qcow2 CENTOS_10_NODE_IMAGE_K8S_v1.34.1.raw
# Generate checksum file for the raw image
sha256sum CENTOS_10_NODE_IMAGE_K8S_v1.34.1.raw > CENTOS_10_NODE_IMAGE_K8S_v1.34.1.raw.sha256sum
# Local cache of IPA
wget https://tarballs.opendev.org/openstack/ironic-python-agent/dib/ipa-centos9-master.tar.gz
popd || exit
