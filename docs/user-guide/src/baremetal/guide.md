# Baremetal provisioning

This is a guide to provision baremetal servers using the Metal³ project. It is a generic guide with basic implementation, different hardware may require different configuration.

In this guide we will use minikube as management cluster.

All commands are executed on the host where minikube is set up.

This is a separate machine, e.g. your laptop or one of the servers, that has access to the network where the servers are in order to provision them.

## Install requirements on the host

Login to the host from where you want to provision. The baremetal nodes should be accesible from the host via one of the following protocols.

- IPMI
- Redfish
- WSMAN
- iRMC
- ibmc
- iLO

See [Install Ironic](../ironic/ironic_installation.md) for other requirements.

Install following requirements on the host.

- Python
- Golang
- Docker for ubuntu and podman for Centos
- Ansible

## Configure host

- Create network settings. We are creating 2 bridge interfaces:
  provisioning and external. The provisioning interface is used by
  Ironic to provision the BareMetalHosts and the external interface
  allows them to communicate with each other and connect to internet.

  ```bash
  # Create a veth iterface peer.
  sudo ip link add ironicendpoint type veth peer name ironic-peer

  # Create provisioning bridge.
  sudo brctl addbr provisioning

  sudo ip addr add dev ironicendpoint 172.22.0.1/24
  sudo brctl addif provisioning ironic-peer
  sudo ip link set ironicendpoint up
  sudo ip link set ironic-peer up

  # Create the external bridge
  sudo brctl addbr external

  sudo ip addr add dev external 192.168.111.1/24
  sudo ip link set external up

  # Add udp forwarding to firewall, this allows to use ipmitool (port 623)
  # as well as allowing TFTP traffic outside the host (random port)
  iptables -A FORWARD -p udp -j ACCEPT

  # Add interface to provisioning bridge
  brctl addif provisioning eno1

  # Set VLAN interface to be up
  ip link set up dev bmext

  # Check if bmext interface is addded to the bridge
  brctl show baremetal | grep bmext

  # Add bmext to baremeatal bridge
  brctl addif baremetal bmext
  ```

## Prepare image cache

- Start httpd container. This is used to host the the OS images that the BareMetalHosts will be provisioned with.

  ```bash
  sudo docker run -d --net host --privileged --name httpd-infra -v /opt/metal3-dev-env/ironic:/shared --entrypoint /bin/runhttpd --env
  ```

  Download the node image and put it in the folder where the httpd container can host it.

  ```bash
  wget -O /opt/metal3-dev-env/ironic/html/images https://artifactory.nordix.org/artifactory/metal3/images/k8s_v1.27.1
  ```

  Convert the qcow2 image to raw format and get the hash of the raw image

   ```bash
  # Change IMAGE_NAME and IMAGE_RAW_NAME according to what you download from artifactory
  cd /opt/metal3-dev-env/ironic/hrtml/images
  IMAGE_NAME="CENTOS_9_NODE_IMAGE_K8S_v1.27.1.qcow2"
  IMAGE_RAW_NAME="CENTOS_9_NODE_IMAGE_K8S_v1.27.1-raw.img"
  qemu-img convert -O raw "${IMAGE_NAME}" "${IMAGE_RAW_NAME}"

  # Create sha256 hash
  sha256sum "${IMAGE_RAW_NAME}" | awk '{print $1}' > "${IMAGE_RAW_NAME}.sha256sum"
  ```

## Launch management cluster using minikube

- Create a minikube cluster to use as management cluster.

  ```bash
  minikube start

  # Configuring ironicendpoint with minikube
  minikube ssh sudo brctl addbr ironicendpoint
  minikube ssh sudo ip link set ironicendpoint up
  minikube ssh sudo brctl addif ironicendpoint eth2
  minikube ssh sudo ip addr add 172.22.0.9/24 dev ironicendpoint
  ```

- Initialize Cluster API and the Metal3 provider.

  ```bash
  kubectl create namespace metal3
  clusterctl init --core cluster-api --bootstrap kubeadm --control-plane kubeadm --infrastructure metal3
  # NOTE: In clusterctl init you can change the version of provider like this "cluster-api:v1.6.0",
  # if no version is given by deafult latest stable release will be used.
  ```

## Install provisioning components

- Exporting necessary variables for baremetal operator and Ironic deployment.

  ```bash
  # The URL of the kernel to deploy.
  export DEPLOY_KERNEL_URL="http://172.22.0.1:6180/images/ironic-python-agent.kernel"

  # The URL of the ramdisk to deploy.
  export DEPLOY_RAMDISK_URL="http://172.22.0.1:6180/images/ironic-python-agent.initramfs"

  # The URL of the Ironic endpoint.
  export IRONIC_URL="http://172.22.0.1:6385/v1/"

  # The URL of the Ironic inspector endpoint - only before BMO 0.5.0.
  #export IRONIC_INSPECTOR_URL="http://172.22.0.1:5050/v1/"

  # Do not use a dedicated CA certificate for Ironic API.
  # Any value provided in this variable disables additional CA certificate validation.
  # To provide a CA certificate, leave this variable unset.
  # If unset, then IRONIC_CA_CERT_B64 must be set.
  export IRONIC_NO_CA_CERT=true

  # Disables basic authentication for Ironic API.
  # Any value provided in this variable disables authentication.
  # To enable authentication, leave this variable unset.
  # If unset, then IRONIC_USERNAME and IRONIC_PASSWORD must be set.
  #export IRONIC_NO_BASIC_AUTH=true

  # Disables basic authentication for Ironic inspector API (when used).
  # Any value provided in this variable disables authentication.
  # To enable authentication, leave this variable unset.
  # If unset, then IRONIC_INSPECTOR_USERNAME and IRONIC_INSPECTOR_PASSWORD must be set.
  #export IRONIC_INSPECTOR_NO_BASIC_AUTH=true
  ```

- Launch baremetal operator.

  ```bash
  # Clone BMO repo
  git clone https://github.com/metal3-io/baremetal-operator.git
  # Run deploy.sh
  ./baremetal-operator/tools/deploy.sh -b -k -t
  ```

- Launch Ironic.

  ```bash
  # Run deploy.sh
  ./baremetal-operator/tools/deploy.sh -i -k -t
  ```

## Create Secrets and BareMetalHosts

  Create yaml files for each BareMetalHost that will be used. Below is an example.

  ```yaml
  ---
  apiVersion: v1
  kind: Secret
  metadata:
    name: <<secret_name_bmh1>>
  type: Opaque
  data:
    username: <<username_bmh1>>
    password: <<password_bmh1>>
  ---
  apiVersion: metal3.io/v1alpha1
    kind: BareMetalHost
    metadata:
      name: <<id_bmh1>>
    spec:
      online: true
      bootMACAddress: <<mac_address_bmh1>>
      bootMode: legacy
      bmc:
        address: <<address_bmh1>> // this depends on the protocol that are mentioned above, they depend on hardware vendor
        credentialsName: <<secret_name_bmh1>>
        disableCertificateVerification: true
  ```

  Apply the manifests.

  ```bash
  kubectl apply -f ./bmh1.yaml -n metal3
  ```

  At this point, the BareMetalHosts will go through `registering` and `inspection` phases before they become `available`.

  Wait for all of them to be available. You can check their status with `kubectl get bmh -n metal3`.

  The next step is to create a workload cluster from these BareMetalHosts.

## Create and apply cluster, controlplane and worker template

  ```bash
  #API endpoint IP and port for target cluster
  export CLUSTER_APIENDPOINT_HOST="192.168.111.249"
  export CLUSTER_APIENDPOINT_PORT="6443"

  # Export node image variable and node image hash varibale that we created before.
  # Change name according to what was downlowded from artifactory
  export IMAGE_URL=http://172.22.0.1/images/CENTOS_9_NODE_IMAGE_K8S_v1.27.1-raw.img
  export IMAGE_CHECKSUM=http://172.22.0.1/images/CENTOS_9_NODE_IMAGE_K8S_v1.27.1-raw.img.sha256sum
  export IMAGE_CHECKSUM_TYPE=sha256
  export IMAGE_FORMAT=raw

  # Generate templates with clusterctl, change control plane and worker count according to
  # the number of BareMetalHosts
  clusterctl generate cluster capm3-cluster \
    --kubernetes-version v1.27.0 \
    --control-plane-machine-count=3 \
    --worker-machine-count=3 \
    > capm3-cluster-template.yaml

  # Apply the template
  kubectl apply -f capm3-cluster-template.yaml
  ```
