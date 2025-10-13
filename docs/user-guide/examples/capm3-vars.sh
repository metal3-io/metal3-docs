# Baremetal lab image variables
# export IMAGE_URL="http://192.168.0.150/CENTOS_10_NODE_IMAGE_K8S_v1.34.1.qcow2"
# export IMAGE_CHECKSUM="afa7e95ee6fb92b952ab85bae4d01033651e690cf04a626c668041d7b94ddd4a"
# export IMAGE_FORMAT="qcow2"
# Virtualized setup variables
export IMAGE_URL="http://192.168.222.1/CENTOS_10_NODE_IMAGE_K8S_v1.34.1.raw"
export IMAGE_CHECKSUM="20537529c0588e1c3d1929981207ef6fac73df7b2500b84f462d09badcc670ea"
export IMAGE_FORMAT="raw"
# Common variables
export IMAGE_CHECKSUM_TYPE="sha256"
export KUBERNETES_VERSION="v1.34.1"
# Make sure this does not conflict with other networks
export POD_CIDR='["192.168.10.0/24"]'
# These can be used to add user-data
export CTLPLANE_KUBEADM_EXTRA_CONFIG="
    preKubeadmCommands:
    - systemctl enable --now crio
    users:
    - name: user
      sshAuthorizedKeys:
      - ssh-ed25519 ABCD... user@example.com"
export WORKERS_KUBEADM_EXTRA_CONFIG="
      preKubeadmCommands:
      - systemctl enable --now crio
      users:
      - name: user
        sshAuthorizedKeys:
        - ssh-ed25519 ABCD... user@example.com"
# NOTE! You must ensure that this is forwarded or assigned somehow to the
# server(s) that is selected for the control-plane.
# We reserved this address in the net.xml as a basic way to get a fixed IP.
export CLUSTER_APIENDPOINT_HOST="192.168.222.101"
export CLUSTER_APIENDPOINT_PORT="6443"
