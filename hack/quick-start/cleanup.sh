#!/usr/bin/env bash

set -eux

echo "Cleaning up the quick start test environment..."
"${QUICK_START_BASE}/cleanup-clusters.sh"
docker stop image-server
"${QUICK_START_BASE}/cleanup-virtlab.sh"