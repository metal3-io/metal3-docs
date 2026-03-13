#!/usr/bin/env bash

#------------------------------------------------------------------------------
# This script sets up a quick start test environment for Metal3 by
# configuring a virtual lab, bootstrapping a Kind cluster, setting up
# DHCP and image servers, and deploying Ironic and baremetal operators.
#------------------------------------------------------------------------------
set -eux

# Default QUICK_START_BASE to the absolute path of this script's directory if not already set.
export QUICK_START_BASE=${QUICK_START_BASE:="$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")"}

ensure_env() {
    echo "Ensuring kubectl is installed and meets minimum version requirements..."
    "${QUICK_START_BASE}/ensure/ensure_kubectl.sh"

    echo "Ensuring clusterctl is installed and meets minimum version requirements..."
    "${QUICK_START_BASE}/ensure/ensure_clusterctl.sh"
}

setup() {
    echo "Disk images directory. If disk images are missing, they will be downloaded and prepared."
    setup_disk_images_dir

    echo "Setting up virtual lab..."
    "${QUICK_START_BASE}/setup-virtual-lab.sh"

    echo "Setting up DHCP and image servers..."
    "${QUICK_START_BASE}/start-image-server.sh"

    echo "Bootstrapping Kind cluster..."
    "${QUICK_START_BASE}/setup-bootstrap.sh"
    if ! kubectl -n baremetal-operator-system wait --for=condition=Available --timeout=300s deployment --all; then
        exit 1
    fi
}

create_bmhs() {
    kubectl apply -f "${QUICK_START_BASE}/bmc-secret.yaml"
    kubectl apply -f "${QUICK_START_BASE}/bmh-01.yaml"
    # Wait for BMHs to be available
    if ! kubectl wait --for=jsonpath='{.status.provisioning.state}'=available --timeout=600s bmh --all; then
        echo "ERROR: One or more BMHs failed to reach 'available' state within timeout."
        exit 1
    fi
}

scenario_2() {
    echo "Running Scenario 2: ..."
    # "clusterctl init --infrastructure metal3 --ipam=metal3" has already been run.
    # Define env variables
    # shellcheck source=/dev/null
    source "${QUICK_START_BASE}/capm3-vars.sh"

    # Render and apply manifests
    clusterctl generate cluster my-cluster --control-plane-machine-count 1 --worker-machine-count 0 | kubectl apply -f -
    
    # Wait for all BMHs in default namespace to be provisioned
    if ! kubectl wait --for=jsonpath='{.status.provisioning.state}'=provisioned --timeout=1800s bmh --all; then
        echo "ERROR: BMHs failed to reach 'provisioned' state within timeout."
        exit 1
    fi

    # Get kubeconfig for the workload cluster and install CNI
    clusterctl get kubeconfig my-cluster > "${QUICK_START_BASE}/kubeconfig.yaml"

    # Wait for the target cluster API server to be ready before applying CNI
    echo "Waiting for target cluster API server to be ready..."
    until kubectl --kubeconfig="${QUICK_START_BASE}/kubeconfig.yaml" get nodes &>/dev/null; do
        echo "Target cluster API server not ready yet, retrying in 2 seconds..."
        sleep 2
    done
    echo "Target cluster API server is ready."

    kubectl --kubeconfig="${QUICK_START_BASE}/kubeconfig.yaml" apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.0/manifests/calico.yaml

    # Wait for the control plane machine to be ready
    if ! kubectl wait --for=condition=Ready --timeout=600s machine --all; then
        echo "ERROR: Machine failed to reach 'Ready' state within timeout."
        exit 1
    fi
}

setup_disk_images_dir() {
    DISK_IMAGE_DIR="${QUICK_START_BASE}/disk-images"
    REQUIRED_FILES=(
        "jammy-server-cloudimg-amd64.img"
        "CENTOS_10_NODE_IMAGE_K8S_v1.34.1.qcow2"
        "CENTOS_10_NODE_IMAGE_K8S_v1.34.1.raw"
        "ipa-centos9-master.tar.gz"
    )

    missing_files=0
    for file in "${REQUIRED_FILES[@]}"; do
        if [[ ! -f "${DISK_IMAGE_DIR}/${file}" ]]; then
            missing_files=1
            break
        fi
    done

    if [[ "${missing_files}" -eq 1 ]]; then
        rm -r "${DISK_IMAGE_DIR}" || true
        echo "Setting up disk images directory..."
        "${QUICK_START_BASE}/setup-image-server-dir.sh"
    else
        echo "All required disk images are present."
    fi
}

cleanup() {
    echo "Cleaning up the quick start test environment..."
    "${QUICK_START_BASE}/cleanup-clusters.sh"
    docker stop image-server
    "${QUICK_START_BASE}/cleanup-virtlab.sh"
}

ensure_env
setup
create_bmhs
scenario_2
cleanup
