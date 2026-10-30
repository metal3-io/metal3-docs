#!/usr/bin/env bash

set -ux

export QUICK_START_BASE=${QUICK_START_BASE:="$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")"}
"${QUICK_START_BASE}/cleanup-clusters.sh"
docker stop image-server || true
"${QUICK_START_BASE}/cleanup-virtlab.sh"
