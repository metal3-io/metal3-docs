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
  mariadb-image \
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
    git ls-remote -q --exit-code --heads https://github.com/metal3-io/$repo main >/dev/null 2>&1
    retVal=$?
    if [ $retVal -eq 0 ]; then
      branch='main'
    elif [ $retVal -ne 0 ]; then
      if [ "$repo" = "metal3-io.github.io" ]; then
        branch='source'
      else
        branch='master'
      fi
    fi
    curl -s "https://raw.githubusercontent.com/metal3-io/$repo/$branch/OWNERS" | \
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
