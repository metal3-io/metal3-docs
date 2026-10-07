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
    mkdir -p "${artifacts_dir}"

    # --- Management (kind) cluster ---------------------------------------
    {
        echo "### clusterctl describe cluster my-cluster ###"
        clusterctl describe cluster my-cluster
        echo
        echo "### kubectl get all -A ###"
        kubectl get all --all-namespaces -o wide
        echo
        echo "### kubectl get bmh -A ###"
        kubectl get baremetalhosts --all-namespaces -o wide
        echo
        echo "### kubectl get machines/metal3machines -A ###"
        kubectl get machines,metal3machines --all-namespaces -o wide
        echo
        echo "### kubectl get clusters/metal3clusters -A ###"
        kubectl get clusters,metal3clusters --all-namespaces -o wide
    } > "${artifacts_dir}/mgmt-cluster-overview.txt" 2>&1

    # Detailed descriptions and CR yaml for the Metal3 objects.
    kubectl describe baremetalhosts --all-namespaces > "${artifacts_dir}/mgmt-bmh-describe.txt" 2>&1
    kubectl get baremetalhosts --all-namespaces -o yaml > "${artifacts_dir}/mgmt-bmh.yaml" 2>&1
    kubectl describe machines --all-namespaces > "${artifacts_dir}/mgmt-machines-describe.txt" 2>&1
    kubectl get events --all-namespaces --sort-by=.lastTimestamp > "${artifacts_dir}/mgmt-events.txt" 2>&1

    # Controller logs from every namespace in the management cluster. We
    # iterate all namespaces.
    local ns
    for ns in $(kubectl get namespaces -o name 2>/dev/null | sed 's|namespace/||'); do
        kubectl -n "${ns}" get pods -o wide > "${artifacts_dir}/mgmt-pods-${ns}.txt" 2>&1
        local pod
        for pod in $(kubectl -n "${ns}" get pods -o name 2>/dev/null); do
            kubectl -n "${ns}" logs "${pod}" --all-containers=true --prefix=true \
                >> "${artifacts_dir}/mgmt-logs-${ns}.txt" 2>&1
        done
    done

    # --- Workload (target) cluster ---------------------------------------
    if [[ -f "${kubeconfig}" ]]; then
        {
            echo "### kubectl get nodes -o wide ###"
            kubectl --kubeconfig="${kubeconfig}" get nodes -o wide
            echo
            echo "### kubectl describe nodes ###"
            kubectl --kubeconfig="${kubeconfig}" describe nodes
            echo
            echo "### kubectl get pods -A -o wide ###"
            kubectl --kubeconfig="${kubeconfig}" get pods --all-namespaces -o wide
            echo
            echo "### kubectl describe daemonset -n kube-system calico-node ###"
            kubectl --kubeconfig="${kubeconfig}" describe daemonset -n kube-system calico-node
            echo
            echo "### kubectl get events -A ###"
            kubectl --kubeconfig="${kubeconfig}" get events --all-namespaces --sort-by=.lastTimestamp
        } > "${artifacts_dir}/workload-cluster.txt" 2>&1

        # Per-pod logs from the workload cluster, grouped by namespace.
        # We capture logs from every container (including init
        # containers via --all-containers) and also the previous instance
        # (--previous) so the crash output of a restarting container is kept.
        local wl_ns
        for wl_ns in $(kubectl --kubeconfig="${kubeconfig}" get namespaces -o name 2>/dev/null | sed 's|namespace/||'); do
            kubectl --kubeconfig="${kubeconfig}" -n "${wl_ns}" get pods -o wide \
                > "${artifacts_dir}/workload-pods-${wl_ns}.txt" 2>&1
            local wl_pod
            for wl_pod in $(kubectl --kubeconfig="${kubeconfig}" -n "${wl_ns}" get pods -o name 2>/dev/null); do
                {
                    echo "===== ${wl_pod} (current) ====="
                    kubectl --kubeconfig="${kubeconfig}" -n "${wl_ns}" logs "${wl_pod}" \
                        --all-containers=true --prefix=true
                    echo "===== ${wl_pod} (previous, if any) ====="
                    kubectl --kubeconfig="${kubeconfig}" -n "${wl_ns}" logs "${wl_pod}" \
                        --all-containers=true --prefix=true --previous
                } >> "${artifacts_dir}/workload-logs-${wl_ns}.txt" 2>&1
            done
        done
    else
        echo "Workload cluster kubeconfig not found at ${kubeconfig}; skipping." \
            > "${artifacts_dir}/workload-cluster.txt"
    fi

    # --- Containers (kind / sushy-tools / image-server) ------------------
    {
        echo "### docker ps -a ###"
        docker ps -a
        echo
        echo "### sushy-tools logs ###"
        docker logs sushy-tools
        echo
        echo "### image-server logs ###"
        docker logs image-server
    } > "${artifacts_dir}/containers.txt" 2>&1

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