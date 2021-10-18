#!/bin/bash

REPOS=" \
  baremetal-operator \
  cluster-api-provider-metal3 \
  hardware-classification-controller \
  ip-address-manager \
  ironic-agent-image \
  ironic-client \
  ironic-image \
  ironic-hardware-inventory-recorder-image \
  ironic-ipa-downloader \
  metal3-io.github.io \
  metal3-dev-env \
  metal3-docs \
  metal3-helm-chart \
  project-infra \
  static-ip-manager-image \
"

all_owners_raw() {
  for repo in $REPOS; do
    if [ "$repo" = "metal3-io.github.io" ]; then
      filter='.filters.".*".approvers'
    else
      filter='.approvers'
    fi
    curl -s "https://raw.githubusercontent.com/metal3-io/$repo/master/OWNERS" | \
      yq -y $filter | \
      grep -v "null" | \
      grep -v "\.\.\."
  done
}

echo "# All approvers from all top-level OWNERS files"
echo "# See metal3-docs/maintainers/all-owners.sh"
echo
echo "approvers:"

all_owners_raw | \
  tr '[:upper:]' '[:lower:]' | \
  sort -u
