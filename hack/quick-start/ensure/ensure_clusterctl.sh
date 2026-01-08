#!/usr/bin/env bash

set -eux

USR_LOCAL_BIN="/usr/local/bin"
MINIMUM_CLUSTERCTL_VERSION=v1.12.1

# Ensure the clusterctl tool exists and is a viable version, or installs it
verify_clusterctl_version()
{
    # If clusterctl is not available on the path, get it
    if ! [[ -x "$(command -v clusterctl)" ]]; then
        if [[ "${OSTYPE}" == "linux-gnu" ]]; then
            echo "clusterctl not found, installing"
            curl -Lo /tmp/clusterctl "https://github.com/kubernetes-sigs/cluster-api/releases/download/${MINIMUM_CLUSTERCTL_VERSION}/clusterctl-linux-amd64"
            sudo install -o root -g root -m 0755 /tmp/clusterctl "${USR_LOCAL_BIN}/clusterctl"
            rm /tmp/clusterctl
        else
            echo "Missing required binary in path: clusterctl"
            return 2
        fi
    fi

    local clusterctl_version
    IFS=" " read -ra clusterctl_version <<< "$(clusterctl version)"
    # Extract version from output like "clusterctl version: &version.Info{Major:"1", Minor:"12", GitVersion:"v1.12.1",...}"
    local version
    version=$(echo "${clusterctl_version[@]}" | grep -oP 'GitVersion:"v\K[^"]+' | head -n1)
    version="v${version}"
    if [[ "${MINIMUM_CLUSTERCTL_VERSION}" != $(echo -e "${MINIMUM_CLUSTERCTL_VERSION}\n${version}" | sort -s -t. -k 1,1 -k 2,2n -k 3,3n | head -n1) ]]; then
        cat << EOF
Detected clusterctl version: ${version}.
Requires ${MINIMUM_CLUSTERCTL_VERSION} or greater.
Please install ${MINIMUM_CLUSTERCTL_VERSION} or later.
EOF
        return 2
    fi
}

verify_clusterctl_version
