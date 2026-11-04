#!/usr/bin/env bash

# Default QUICK_START_BASE to the absolute path of this script's directory if
# not already set. This lets the script run standalone (./collect_artifacts.sh)
# as well as when invoked from quick-start-test.sh.
export QUICK_START_BASE=${QUICK_START_BASE:="$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")"}

# collect_artifacts dumps all relevant information about the quick-start setup
# into the _artifacts directory.
collect_all_quickstart_artifacts() {
    # Disable tracing/exit-on-error inside the collector so that a single
    # failing diagnostic command cannot abort the rest of the dump.
    set +eux

    local artifacts_dir="${QUICK_START_BASE}/_artifacts"
    local kubeconfig="${QUICK_START_BASE}/kubeconfig.yaml"
    mkdir -p "${artifacts_dir}/management"

    local mgmt_kubeconfig="${artifacts_dir}/management/kubeconfig.yaml"
    if kind get kubeconfig --name kind > "${mgmt_kubeconfig}" 2>/dev/null; then
        export KUBECONFIG="${mgmt_kubeconfig}"
    else
        echo "Could not obtain kind kubeconfig; management commands may fail." > "${artifacts_dir}/management/kubeconfig-unavailable.txt"
    fi

    # --- Management (kind) cluster ---------------------------------------
    clusterctl --kubeconfig="${mgmt_kubeconfig}" describe cluster my-cluster > "${artifacts_dir}/management/mgmt-cluster-overview.txt" 2>&1

    # --- Events ---------------------------------------
    kubectl get events --all-namespaces --sort-by=.lastTimestamp > "${artifacts_dir}/management/events.txt" 2>&1

    # --- Bare Metal Hosts (BMH) ---------------------------------------
    mkdir -p "${artifacts_dir}/management/bmhs"
    kubectl get baremetalhosts --all-namespaces -o wide > "${artifacts_dir}/management/bmhs/overview.txt" 2>&1
    for bmh in $(kubectl get baremetalhosts --all-namespaces -o name 2>/dev/null); do
        kubectl get "${bmh}" -o yaml > "${artifacts_dir}/management/bmhs/${bmh##*/}.yaml" 2>&1
    done

    # --- Metal3 Machines (M3M) ---------------------------------------
    mkdir -p "${artifacts_dir}/management/m3machines"
    kubectl get metal3machines --all-namespaces -o wide > "${artifacts_dir}/management/m3machines/overview.txt" 2>&1
    for m3m in $(kubectl get metal3machines --all-namespaces -o name 2>/dev/null); do
        kubectl get "${m3m}" -o yaml > "${artifacts_dir}/management/m3machines/${m3m##*/}.yaml" 2>&1
    done

    # --- Machines ---------------------------------------
    mkdir -p "${artifacts_dir}/management/machines"
    kubectl get machines --all-namespaces -o wide > "${artifacts_dir}/management/machines/overview.txt" 2>&1
    for machine in $(kubectl get machines --all-namespaces -o name 2>/dev/null); do
        kubectl get "${machine}" -o yaml > "${artifacts_dir}/management/machines/${machine##*/}.yaml" 2>&1
    done

    # --- Pod logs ---------------------------------------
    mkdir -p "${artifacts_dir}/management/pods"
    kubectl get pods --all-namespaces -o wide > "${artifacts_dir}/management/pods/overview.txt" 2>&1
    local ns
    for ns in $(kubectl get namespaces -o name 2>/dev/null); do
        ns="${ns##*/}"
        mkdir -p "${artifacts_dir}/management/pods/${ns}"
        for pod in $(kubectl -n "${ns}" get pods -o name 2>/dev/null); do
            kubectl -n "${ns}" get pod "${pod}" -o yaml > "${artifacts_dir}/management/pods/${ns}/${pod##*/}.yaml" 2>&1
            kubectl -n "${ns}" logs "${pod}" --all-containers=true --prefix=true > "${artifacts_dir}/management/pods/${ns}/${pod##*/}.log" 2>&1
        done
    done

    # --- Workload (target) cluster ---------------------------------------
    local workload_dir="${artifacts_dir}/workload"
    mkdir -p "${workload_dir}"
    if [[ -f "${kubeconfig}" ]]; then
        # --- Nodes -------------------------------------------------------
        mkdir -p "${workload_dir}/nodes"
        kubectl --kubeconfig="${kubeconfig}" get nodes -o wide > "${workload_dir}/nodes/overview.txt" 2>&1
        for wl_node in $(kubectl --kubeconfig="${kubeconfig}" get nodes -o name 2>/dev/null); do
            kubectl --kubeconfig="${kubeconfig}" get "${wl_node}" -o yaml > "${workload_dir}/nodes/${wl_node##*/}.yaml" 2>&1
        done

        # --- Events -------------------------------------------
        kubectl --kubeconfig="${kubeconfig}" get events --all-namespaces --sort-by=.lastTimestamp > "${workload_dir}/events.txt" 2>&1

        # --- Pod logs ---------------------------------------
        mkdir -p "${workload_dir}/pods"
        kubectl --kubeconfig="${kubeconfig}" get pods --all-namespaces -o wide > "${workload_dir}/pods/overview.txt" 2>&1
        local wl_ns
        for wl_ns in $(kubectl --kubeconfig="${kubeconfig}" get namespaces -o name 2>/dev/null); do
            wl_ns="${wl_ns##*/}"
            mkdir -p "${workload_dir}/pods/${wl_ns}"
            local wl_pod
            for wl_pod in $(kubectl --kubeconfig="${kubeconfig}" -n "${wl_ns}" get pods -o name 2>/dev/null); do
                # Strip the "pod/" prefix so the file is named after the pod.
                kubectl --kubeconfig="${kubeconfig}" -n "${wl_ns}" get "${wl_pod}" -o yaml > "${workload_dir}/pods/${wl_ns}/${wl_pod##*/}.yaml" 2>&1

                kubectl --kubeconfig="${kubeconfig}" -n "${wl_ns}" logs "${wl_pod}" --all-containers=true --prefix=true > "${workload_dir}/pods/${wl_ns}/${wl_pod##*/}.log" 2>&1
                kubectl --kubeconfig="${kubeconfig}" -n "${wl_ns}" logs "${wl_pod}" --all-containers=true --prefix=true --previous > "${workload_dir}/pods/${wl_ns}/${wl_pod##*/}_previous.log" 2>&1
            done
        done
    else
        echo "Workload cluster kubeconfig not found at ${kubeconfig}; skipping." \
            > "${artifacts_dir}/workload/workload-cluster.txt"
    fi

    # --- Containers -----------------------------------------------------
    mkdir -p "${artifacts_dir}/containers"
    docker ps -a > "${artifacts_dir}/containers/overview.txt" 2>&1
    local container
    for container in $(docker ps -a --format '{{.Names}}' 2>/dev/null); do
        docker logs "${container}" > "${artifacts_dir}/containers/${container}.log" 2>&1
    done

    # --- libvirt VM + network + serial console ---------------------------
    {
        echo "### virsh list --all ###"
        virsh -c qemu:///system list --all
        echo
        echo "### virsh dominfo bmh-vm-01 ###"
        virsh -c qemu:///system dominfo bmh-vm-01
        echo
        echo "### virsh net-list --all ###"
        virsh -c qemu:///system net-list --all
        echo
        echo "### virsh net-dumpxml baremetal-e2e ###"
        virsh -c qemu:///system net-dumpxml baremetal-e2e
    } > "${artifacts_dir}/libvirt.txt" 2>&1

    # VM serial console log (contains cloud-init / kubeadm boot output).
    # The file is owned by root (qemu runs privileged), so copy it with sudo
    # and hand ownership to the invoking user so the artifact stays readable.
    local serial_log="/var/log/libvirt/qemu/bmh-vm-01-serial0.log"
    local serial_dest="${artifacts_dir}/bmh-vm-01-serial0.log"
    if sudo test -r "${serial_log}"; then
        sudo cp -f "${serial_log}" "${serial_dest}"
        sudo chown "$(id -u):$(id -g)" "${serial_dest}"
    else
        echo "Serial log not available at ${serial_log}" > "${serial_dest}"
    fi

    # --- Host networking -------------------------------------------------
    {
        echo "### ip addr ###"
        ip addr
        echo
        echo "### ip route ###"
        ip route
        echo
        echo "### iptables -L FORWARD -n -v ###"
        sudo iptables -L FORWARD -n -v
    } > "${artifacts_dir}/host-network.txt" 2>&1

    echo "Artifact collection complete: ${artifacts_dir}"
}

collect_all_quickstart_artifacts
