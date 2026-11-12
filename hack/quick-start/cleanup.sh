#!/usr/bin/env bash

set -ux

export QUICK_START_BASE=${QUICK_START_BASE:="$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")"}
PURGE_IMAGES=${PURGE_IMAGES:-false}

"${QUICK_START_BASE}/cleanup-clusters.sh"
docker stop image-server || true
"${QUICK_START_BASE}/cleanup-virtlab.sh"

if [[ "${PURGE_IMAGES}" == "true" ]]; then
    rm -rf "${QUICK_START_BASE}/disk-images"
fi

# Make sure cleanup is always successful, even if some of the cleanup steps fail.
exit 0
