#!/usr/bin/env bash

mkdir disk-images

pushd disk-images
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS
sha256sum --ignore-missing -c SHA256SUMS
wget https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2
wget https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2.SHA256SUM
sha256sum -c CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2.SHA256SUM
wget https://artifactory.nordix.org/artifactory/metal3/images/k8s_v1.33.0/CENTOS_9_NODE_IMAGE_K8S_v1.33.0.qcow2
sha256sum CENTOS_9_NODE_IMAGE_K8S_v1.33.0.qcow2
popd

docker run --name image-server --rm -d -p 80:8080 \
  -v "$(pwd)/disk-images:/usr/share/nginx/html" nginxinc/nginx-unprivileged
