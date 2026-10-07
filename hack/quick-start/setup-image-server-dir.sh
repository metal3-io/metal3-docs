#!/usr/bin/env bash

mkdir "${QUICK_START_BASE}/disk-images"

pushd "${QUICK_START_BASE}/disk-images" || exit
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img --quiet
wget https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS --quiet
sha256sum --ignore-missing -c SHA256SUMS
wget https://idknxc8t3pjc.objectstorage.eu-paris-1.oci.customer-oci.com/p/qBVVBPA7b72OTvcnLaKDkn7N4_YmWeVlBvaIsEnzX9EHGqBXQZyFxG15piXNjYot/n/idknxc8t3pjc/b/public-metal3-node-image-bucket/o/CENTOS_10_NODE_IMAGE_K8S_v1.37.0.qcow2 --quiet
# Generate checksum file for the qcow2 image
sha256sum CENTOS_10_NODE_IMAGE_K8S_v1.37.0.qcow2 > CENTOS_10_NODE_IMAGE_K8S_v1.37.0.qcow2.sha256sum
# Convert to raw.
# This helps lower memory requirements, since the raw image can be streamed to disk
# instead of first loaded to memory by IPA for conversion.
qemu-img convert -f qcow2 -O raw CENTOS_10_NODE_IMAGE_K8S_v1.37.0.qcow2 CENTOS_10_NODE_IMAGE_K8S_v1.37.0.raw
# Generate checksum file for the raw image
sha256sum CENTOS_10_NODE_IMAGE_K8S_v1.37.0.raw > CENTOS_10_NODE_IMAGE_K8S_v1.37.0.raw.sha256sum
# Local cache of IPA
wget https://tarballs.opendev.org/openstack/ironic-python-agent/dib/ipa-centos10-master.tar.gz --quiet
popd || exit
