# Quick-start for Metal3

<!-- cSpell:ignore htpasswd,virsh -->

This guide has been tested on Ubuntu server 22.04. It should be seen as an
example rather than the absolute truth about how to deploy and use Metal3. We
will cover two environments and two scenarios. The environments are

1. a baremetal lab with actual physical servers and baseboard management
   controllers (BMCs), and
1. a virtualized baremetal lab with virtual machines and sushy-tools acting as
   BMC.

In both of these, we will show how to use Bare Metal Operator and Ironic to
manage the servers through a Kubernetes API, as well as how to turn the servers
into Kubernetes clusters managed through Cluster API. These are the two
scenarios.

In a nut-shell, this is what we will do:

1. [Setup a management cluster](#management-cluster)
1. [Setup a DHCP server](#dhcp-server)
1. [Setup a disk image server](#image-server)
1. [Deploy Ironic](#deploy-ironic)
1. [Deploy Bare Metal Operator](#deploy-bare-metal-operator)
1. [Create BareMetalHosts to represent the servers](#create-baremetalhosts)
1. [(Scenario 1) Provision the BareMetalHosts](#scenario-1-provision-baremetalhosts)
1. [(Scenario 2) Deploy Cluster API and turn the BareMetalHosts into a Kubernetes cluster](#scenario-2-metal3-and-cluster-api)

## Prerequisites

You will need the following tools installed.

- docker (or podman)
- kind or minikube (management cluster, not needed if you already have a "real"
  cluster that you want to use)
- clusterctl
- kubectl
- htpasswd
- virsh and virt-install for the virtualized setup

## Baremetal lab configuration

The baremetal lab has two servers that we will call bml-01 and bml-02, as well
as a management computer where we will set up Metal3. The servers are equipped
with iLO 4 BMCs. These BMCs are connected to an "out of band" network
(`192.168.1.0/24`) and they have the following IP addresses.

- bml-01: 192.168.1.13
- bml-02: 192.168.1.14

There is a separate network for the servers (`192.168.0.0/24`). The management
computer is connected to both of these networks with IP addresses `192.168.1.7`
and `192.168.0.150` respectively.

Finally, we will need the MAC addresses of the servers to keep track of which is
which.

- bml-01: 80:c1:6e:7a:e8:10
- bml-02: 80:c1:6e:7a:5a:a8

## Virtualized configuration

If you do not have the hardware or perhaps just want to test things out without
committing to a full baremetal lab, you may simulate it with virtual machines.
In this section we will show how to create a virtual machine and use sushy-tools
as a baseboard management controller for it.

The configuration is a bit simpler than in the baremetal lab because we don't
have a separate out of band network here. In the end we will have the BMC
available as

- bml-vm-01: 192.168.222.1:8000/redfish/v1/Systems/bmh-vm-01

and the MAC address:

- bml-vm-01: 00:60:2f:31:81:01

Start by defining a libvirt network:

```xml
<network>
  <name>baremetal</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='metal3'/>
  <ip address='192.168.222.1' netmask='255.255.255.0'>
  </ip>
</network>
```

Save this as `net.xml`, define it and start it.

```bash
virsh -c qemu:///system net-define net.xml
virsh -c qemu:///system net-start baremetal
```

Next, we will create a virtual machine. Feel free to adjust at as you see fit,
but make sure to note the MAC address. That will be needed later. You can also
create more than one if you like.

```bash
# use --ram=8192 for Scenario 2
virt-install \
  --connect qemu:///system \
  --name bmh-vm-01 \
  --description "Virtualized BareMetalHost" \
  --osinfo=ubuntu-lts-latest \
  --ram=4096 \
  --vcpus=2 \
  --disk size=25 \
  --graphics=none \
  --console pty \
  --serial pty \
  --pxe \
  --network network=baremetal,mac="00:60:2f:31:81:01" \
  --noautoconsole
```

### Sushy-tools - AKA the BMC

Metal3 relies on baseboard management controllers to manage the baremetal
servers, so we need something similar for our virtual machines. This comes in
the form of [sushy-tools](https://docs.openstack.org/sushy/latest/).

We need to create configuration file first:

```conf
# Listen on 192.168.222.1:8000
SUSHY_EMULATOR_LISTEN_IP = u'192.168.222.1'
SUSHY_EMULATOR_LISTEN_PORT = 8000
# The libvirt URI to use. This option enables libvirt driver.
SUSHY_EMULATOR_LIBVIRT_URI = u'qemu:///system'
```

```bash
docker run --name sushy-tools --rm --network host -d \
  -v /var/run/libvirt:/var/run/libvirt \
  -v "$(pwd)/sushy-tools.conf:/etc/sushy/sushy-emulator.conf" \
  -e SUSHY_EMULATOR_CONFIG=/etc/sushy/sushy-emulator.conf \
  quay.io/metal3-io/sushy-tools:latest sushy-emulator
```

## Common setup

This section is common for both the baremetal configuration and the virtualized
environment. Specific configuration will always differ between environments
though. We will go through how to configure and deploy Ironic and Baremetal
Operator.

### Management cluster

If you already have a Kubernetes cluster that you want to use, go ahead and use
that. Please ensure that it is connected to the relevant networks so that Ironic
can reach the BMCs and so that the BareMetalHosts can reach Ironic.

If you do not have an cluster already, you can create one using kind. Please
note that this is absolutely not intended for production environments.

We will use the following configuration file for kind, save it as `kind.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  # Open ports for Ironic
  extraPortMappings:
  # Ironic httpd
  - containerPort: 6180
    hostPort: 6180
    listenAddress: "0.0.0.0"
    protocol: TCP
  # Ironic API
  - containerPort: 6385
    hostPort: 6385
    listenAddress: "0.0.0.0"
    protocol: TCP
  # Inspector API
  - containerPort: 5050
    hostPort: 5050
    listenAddress: "0.0.0.0"
    protocol: TCP
```

As you can see, it has a few ports forwarded from the host. This is to make
Ironic reachable when it is running inside the kind cluster.

Now go ahead and create the cluster:

```bash
kind create cluster --config kind.yaml
```

We will need to install cert-manager also. It will be used to manage the
certificates for Ironic later.

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml
```

### DHCP server

The BareMetalHosts must be able to call back to Ironic when going through the
inspection phase. This means that they must have IP addresses in a network where
they can reach Ironic. We will set up a DHCP server for this purpose.

Any DHCP server can be used for this. We will here use the Ironic container
image that incudes dnsmasq and some scripts for configuring it.

Create a configuration file and save it as `dnsmasq.env`.

Baremetal lab:

```bash
# The same HTTP port must be provided to all containers!
HTTP_PORT=6180
# Specify the MAC addresses (separated by ;) of the hosts we know about and want to use
DHCP_HOSTS=80:c1:6e:7a:e8:10;80:c1:6e:7a:5a:a8
# Ignore unknown hosts so we don't accidentally give out IP addresses to other hosts in the network
DHCP_IGNORE=tag:!known
# Listen on this IP (management computer)
PROVISIONING_IP=192.168.0.150
# Give out IP addresses in this range
DHCP_RANGE=192.168.0.100,192.168.0.149
GATEWAY_IP=192.168.0.1
```

Virtualized environment:

```bash
HTTP_PORT=6180
DHCP_HOSTS=00:60:2f:31:81:01
DHCP_IGNORE=tag:!known
# IP of the host from VM perspective
PROVISIONING_IP=192.168.222.1
GATEWAY_IP=192.168.222.1
DHCP_RANGE=192.168.222.100,192.168.222.149
```

You can now run the DHCP server like this:

```bash
docker run --name dnsmasq --rm -d --net=host --privileged --user 997:994 \
  --env-file dnsmasq.env --entrypoint /bin/rundnsmasq \
  quay.io/metal3-io/ironic
```

### Image server

In order to do anything useful, we will need a server for hosting disk images
that can be used to provision the servers.

Create a directory to hold the disk images:

```bash
mkdir disk-images
```

Download images to use for testing (pick those that you want):

```bash
pushd disk-images
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/jammy/current/SHA256SUMS
sha256sum --ignore-missing -c SHA256SUMS
wget https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-x86_64-9-latest.x86_64.qcow2
wget https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-x86_64-9-latest.x86_64.qcow2.SHA256SUM
sha256sum -c CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2.SHA256SUM
wget https://artifactory.nordix.org/artifactory/metal3/images/k8s_v1.33.0/CENTOS_9_NODE_IMAGE_K8S_v1.33.0.qcow2
sha256sum CENTOS_9_NODE_IMAGE_K8S_v1.33.0.qcow2
popd
```

Run a basic http server to expose the disk images:

```bash
docker run --name image-server --rm -d -p 80:8080 \
  -v "$(pwd)/disk-images:/usr/share/nginx/html" nginxinc/nginx-unprivileged
```

### Deploy Ironic

In this section we will create a
[kustomization](https://kubectl.docs.kubernetes.io/references/kustomize/glossary/#kustomization)
containing configuration and credentials for deploying Ironic.

Create a folder to hold the kustomization:

```bash
mkdir ironic
```

#### Authentication configuration

Create authentication configuration for Ironic and Inspector. You will need to
generate a username and password for each. We will here refer to them as
`IRONIC_USERNAME`, `IRONIC_PASSWORD`, `INSPECTOR_USERNAME` and
`INSPECTOR_PASSWORD`.

Create a file `ironic-auth-config` with configuration for how to access Ironic.
This will be use by Inspector. It should have the following content:

```conf
[ironic]
auth_type=http_basic
username=IRONIC_USERNAME
password=IRONIC_PASSWORD
```

Create a file `ironic-inspector-auth-config` with configuration for how to
access Inspector. This will be used by Ironic. It should have the following
content:

```conf
[inspector]
auth_type=http_basic
username=INSPECTOR_USERNAME
password=INSPECTOR_PASSWORD
```

To enable basic auth, we need to create secrets containing the keys
`IRONIC_HTPASSWD` and `INSPECTOR_HTPASSWD` with values generated from the
credentials using htpasswd. We will do this by creating two files
`ironic-htpasswd` and `ironic-inspector-htpasswd` with the following content.

`ironic-htpasswd`:

```bash
IRONIC_HTPASSWD="<output of `htpasswd -n -b -B IRONIC_USERNAME IRONIC_PASSWORD`>"
```

Similarly for `ironic-inspector-htpasswd`:

```bash
INSPECTOR_HTPASSWD="<output of `htpasswd -n -b -B INSPECTOR_USERNAME INSPECTOR_PASSWORD`>"
```

#### Ironic environment variables

In this section we will create a file containing environment variables used to
configure Ironic and related components. We will call the file `ironic_bmo.env`.
It looks like this for the baremetal lab:

```bash
# Same port as exposed in kind.yaml
HTTP_PORT=6180
# This is the interface inside the container
PROVISIONING_INTERFACE=eth0
# URL where the http server is exposed (IP of management computer)
CACHEURL=http://192.168.0.150
IRONIC_KERNEL_PARAMS=console=ttyS0
# IP where the BMCs can access Ironic to get the virtualmedia boot image.
# This is the IP of the management computer in the out of band network.
IRONIC_EXTERNAL_IP=192.168.1.7
# URLs where the servers can callback during inspection.
# IP of management computer in the other network and same ports as in kind.yaml
IRONIC_EXTERNAL_CALLBACK_URL=https://192.168.0.150:6385
IRONIC_INSPECTOR_CALLBACK_ENDPOINT_OVERRIDE=https://192.168.0.150:5050
```

For the virtualized environment it looks like this:

```bash
HTTP_PORT=6180
PROVISIONING_INTERFACE=eth0
CACHEURL=http://192.168.222.1/images
IRONIC_KERNEL_PARAMS=console=ttyS0
# Docker does not allow cross-network access. If using kind to create the management
# cluster, explicitly set the external ip and use port forwarding to access ironic services. 
IRONIC_EXTERNAL_IP=192.168.222.1
```

For more details on available variables, see the
[ironic-image repository](https://github.com/metal3-io/ironic-image/tree/main).

#### Patch Ironic Deployment

The Ironic kustomization that we build on includes a dnsmasq container used for
DHCP and PXE booting. However, we already set this up separately, because it is
tricky to expose a DHCP server running inside kind. This means that we do not
need the dnsmasq container that comes with the kustomization by default.

We will create a patch for removing it. It looks like this:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ironic
spec:
  template:
    spec:
      containers:
      - name: ironic-dnsmasq
        $patch: delete
```

Save it as `ironic-patch.yaml`.

#### Ironic kustomization

Time to tie it all together by creating a `kustomization.yaml`. At this point
you should have a file structure like this:

```text
ironic/
├── ironic-auth-config
├── ironic-htpasswd
├── ironic-inspector-auth-config
├── ironic-inspector-htpasswd
├── ironic-patch.yaml
├── ironic_bmo.env
└── kustomization.yaml
```

Here is a commented `kustomization.yaml`. Check carefully the IP addresses as
these will always differ depending on environment.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: baremetal-operator-system
# These are the kustomizations we build on. You can download them and change the URLs to relative
# paths if you do not want to access them over the network.
# Note that the ref=v0.5.1 specifies the version to use.
resources:
- https://github.com/metal3-io/baremetal-operator/config/namespace?ref=v0.5.1
- https://github.com/metal3-io/baremetal-operator/ironic-deployment/base?ref=v0.5.1
# The kustomize components configure basic-auth and TLS
components:
- https://github.com/metal3-io/baremetal-operator/ironic-deployment/components/basic-auth?ref=v0.5.1
- https://github.com/metal3-io/baremetal-operator/ironic-deployment/components/tls?ref=v0.5.1
images:
- name: quay.io/metal3-io/ironic
  newTag: v24.0.0
# Create a ConfigMap from ironic_bmo.env and call it ironic-bmo-configmap.
# This ConfigMap will be used to set environment variables for the containers.
configMapGenerator:
- envs:
  - ironic_bmo.env
  name: ironic-bmo-configmap
  behavior: create

patches:
# Patch for removing dnsmasq
- path: ironic-patch.yaml
# The TLS component adds certificates but it cannot know the exact IPs of our environment.
# Here we patch the certificates to have the correct IPs.
# - 192.168.1.7: management computer IP in out of band network
# - 172.18.0.2: kind cluster node IP. This is what Ironic will see attached to the interface
#   and use to communicate with Inspector.
# - 192.168.0.150: management computer IP in the other network
- patch: |-
    - op: replace
      path: /spec/ipAddresses/0
      value: 192.168.1.7
    - op: add
      path: /spec/ipAddresses/-
      value: 172.18.0.2
    - op: add
      path: /spec/ipAddresses/-
      value: 192.168.0.150
  # The same patch in the virtualized environment looks like this:
  # - op: replace
  #   path: /spec/ipAddresses/0
  #   value: 192.168.222.1
  # - op: add
  #   path: /spec/ipAddresses/-
  #   value: 172.18.0.2
  target:
    kind: Certificate
    name: ironic-cert|ironic-inspector-cert
# The CA certificate should not have any IP address so we remove it.
- patch: |-
    - op: remove
      path: /spec/ipAddresses
  target:
    kind: Certificate
    name: ironic-cacert
# Create secrets from the authentication configuration.
# These will be mounted or used for environment variables.
# See the basic-auth component for more details on how they are used.
secretGenerator:
- name: ironic-htpasswd
  behavior: create
  envs:
  - ironic-htpasswd
- name: ironic-inspector-htpasswd
  behavior: create
  envs:
  - ironic-inspector-htpasswd
- name: ironic-auth-config
  files:
  - auth-config=ironic-auth-config
- name: ironic-inspector-auth-config
  files:
  - auth-config=ironic-inspector-auth-config
```

You can check that it works and inspect the resulting manifest by running this:

```bash
kubectl create -k ironic --dry-run=client -o yaml
```

When you are happy with the output, apply it in the cluster:

```bash
kubectl apply -k ironic
```

### Deploy Bare Metal Operator

Similar to Ironic, we will create a kustomization for deploying Baremetal
Operator. It will include credentials for accessing Ironic. Start with creating
a folder for the kustomization:

```bash
mkdir bmo
```

Create files containing the credentials for Ironic and Inspector:

- ironic-username
- ironic-password
- ironic-inspector-username
- ironic-inspector-password

We will use kustomize to create secrets from these that Bare Metal Operator can
use to access Ironic.

Next, create a file for environment variables. We will call it `ironic.env`. The
content looks like this for the baremetal lab:

```bash
DEPLOY_KERNEL_URL=http://192.168.0.150:6180/images/ironic-python-agent.kernel
DEPLOY_RAMDISK_URL=http://192.168.0.150:6180/images/ironic-python-agent.initramfs
IRONIC_ENDPOINT=https://192.168.0.150:6385/v1/
```

The IP address is that of the management computer. The same in the virtualized
environment looks like this:

```bash
DEPLOY_KERNEL_URL=http://192.168.222.1:6180/images/ironic-python-agent.kernel
DEPLOY_RAMDISK_URL=http://192.168.222.1:6180/images/ironic-python-agent.initramfs
IRONIC_ENDPOINT=https://192.168.222.1:6385/v1/
```

Finally, create the `kustomization.yaml` with this content:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: baremetal-operator-system
# This is the kustomization that we build on. You can download it and change
# the URL to a relative path if you do not want to access it over the network.
# Note that the ref=v0.5.1 specifies the version to use.
resources:
- https://github.com/metal3-io/baremetal-operator/config/overlays/basic-auth_tls?ref=v0.5.1
images:
- name: quay.io/metal3-io/baremetal-operator
  newTag: v0.5.1
# Create a ConfigMap from ironic.env and name it ironic.
configMapGenerator:
- name: ironic
  behavior: create
  envs:
  - ironic.env

# We cannot use suffix hashes since the kustomizations we build on
# cannot be aware of what suffixes we add.
generatorOptions:
  disableNameSuffixHash: true
# Create secrets with the credentials for accessing Ironic.
secretGenerator:
- name: ironic-credentials
  files:
  - username=ironic-username
  - password=ironic-password
- name: ironic-inspector-credentials
  files:
  - username=ironic-inspector-username
  - password=ironic-inspector-password
```

At this point, you should have a folder structure like this:

```text
bmo/
├── ironic-password
├── ironic-username
├── ironic-inspector-username
├── ironic-inspector-password
├── ironic.env
└── kustomization.yaml
```

You can check that the kustomization works and inspect the resulting manifest by
running this:

```bash
kubectl create -k bmo --dry-run=client -o yaml
```

When you are happy with the output, apply it in the cluster:

```bash
kubectl apply -k bmo
```

## Deployment summary

You are not expected to go through all the above steps each time you want to
deploy Metal3. Store the configuration and reuse it the next time.

Here is a summary of the deploy steps when all configuration is already in
place.

1. Create the management cluster.

   ```bash
   kind create cluster --config kind.yaml
   ```

1. Deploy cert-manager.

   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.3/cert-manager.yaml
   ```

1. Start the DHCP server.

   ```bash
   docker run --name dnsmasq --rm -d --net=host --privileged --user 997:994 \
     --env-file dnsmasq.env --entrypoint /bin/rundnsmasq \
     quay.io/metal3-io/ironic
   ```

1. Start the image server.

   ```bash
   docker run --name image-server --rm -d -p 80:8080 \
     -v "$(pwd)/disk-images:/usr/share/nginx/html" nginxinc/nginx-unprivileged
   ```

1. Deploy Ironic.

   ```bash
   kubectl apply -k ironic
   ```

1. Deploy Bare Metal Operator.

   ```bash
   kubectl apply -k bmo
   ```

## Create BareMetalHosts

Now that we have Bare Metal Operator deployed, let's put it to use by creating
BareMetalHosts (BMHs) to represent our servers. You will need the protocol and
IPs of the BMCs, as well as credentials for accessing them, and the servers MAC
addresses.

Create one secret for each BareMetalHost, containing the credentials for
accessing its BMC. No credentials are needed in the virtualized setup but you
still need to create the secret with some values. Here is an example:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: bml-01
type: Opaque
stringData:
  username: replaceme
  password: replaceme
```

Then continue by creating the BareMetalHost manifest. You can put it in the same
file as the secret if you want. Just remember to separate the two resources with
one line containing `---`.

Here is an example of a BareMetalHost referencing the secret above with MAC
address and BMC address matching our `bml-01` server (see [supported
hardware](bmo/supported_hardware) for information on BMC addressing).

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: bml-01
spec:
  online: true
  bootMACAddress: 80:c1:6e:7a:e8:10
  # This particular hardware does not support UEFI so we use legacy
  bootMode: legacy
  bmc:
    address: ilo4-virtualmedia://192.168.1.13
    credentialsName: bml-01
    disableCertificateVerification: true
```

Here is the same for the virtualized BareMetalHost:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: bml-vm-01
spec:
  online: true
  bootMACAddress: 00:60:2f:31:81:01
  bootMode: UEFI # use 'legacy' for Scenario 2
  hardwareProfile: libvirt
  bmc:
    address: redfish-virtualmedia+http://192.168.222.1:8000/redfish/v1/Systems/bmh-vm-01
    credentialsName: bml-01
```

Apply these in the cluster with `kubectl apply -f path/to/file`.

You should now be able to see the BareMetalHost go through `registering` and
`inspecting` phases before it finally becomes `available`. Check with
`kubectl get bmh`. The output should look similar to this:

```text
NAME      STATE         CONSUMER   ONLINE   ERROR   AGE
bml-01    available                true             26m
```

## (Scenario 1) Provision BareMetalHosts

If you want to manage the BareMetalHosts directly, keep reading. If you would
rather use Cluster API to make Kubernetes clusters out of them, skip to the next
section.

Edit the BareMetalHost to add details of what image you want to provision it
with. For example:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: bml-01
spec:
  online: true
  bootMACAddress: 80:c1:6e:7a:e8:10
  bootMode: legacy
  bmc:
    address: ilo4-virtualmedia://192.168.1.13
    credentialsName: bml-01
    disableCertificateVerification: true
  image:
    checksumType: sha256
    checksum: http://192.168.0.150/SHA256SUMS
    format: qcow2
    url: http://192.168.0.150/jammy-server-cloudimg-amd64.img
```

Note that the URL for the disk image is _not_ using the out of band network.
Image provisioning works so that the Ironic Python Agent is first booted on the
machine. From there (i.e. not in the out of band network) it downloads the disk
image and writes it to disk. If the machine has several disks, and you want to
specify which one to use, set [rootDeviceHints](bmo/root_device_hints.md)
(otherwise, `/dev/sda` is used by default).

The manifest above is enough to provision the BareMetalHost, but unless you have
everything you need already baked in the disk image, you will most likely want
to add some user-data and network-data. We will show here how to configure
authorized ssh keys using user-data (see [instance
customization](bmo/instance_customization.md) for more details).

First, we create a file (`user-data.yaml`) with the user-data:

```yaml
#cloud-config
users:
- name: user
  ssh_authorized_keys:
  - ssh-ed25519 ABCD... user@example.com
```

Then create a secret from it.

```bash
kubectl create secret generic user-data --from-file=value=user-data.yaml --from-literal=format=cloud-config
```

Add the following to the BareMetalHost manifest to make it use the user-data:

```yaml
spec:
  ...
  userData:
    name: user-data
    namespace: default
```

Apply the changes with `kubectl apply -f path/to/file`. You should now see the
BareMetalHost go into `provisioning` and eventually become `provisioned`.

```text
NAME      STATE         CONSUMER   ONLINE   ERROR   AGE
bml-01    provisioned              true             2h
```

You can now check the logs of the DHCP server to see what IP the BareMetalHost
got (`docker logs dnsmasq`) and try to ssh to it.

## (Scenario 2) Metal3 and Cluster API

If you want to turn the BareMetalHosts into Kubernetes clusters, you should
consider using Cluster API and the infrastructure provider for Metal3. In this
section we will show how to do it.

Initialize the Cluster API core components and the infrastructure provider for
Metal3:

```bash
clusterctl init --infrastructure metal3
```

Now we need to set some environment variables that will be used to render the
manifests from the cluster template. Most of them are related to the disk image
that we downloaded above.

**Note:** There are many ways to configure and expose the API endpoint of the
cluster. You need to decide how to do it. It will not "just work". Here are some
options:

1. Configure a specific IP for the control-plane server through the DHCP server.
   This is doesn't require anything extra but it is also very limited. You will
   not be able to upgrade the cluster for example.
1. Set up a load balancer separately and use that as API endpoint.
1. Use keepalived or kube-vip or similar to assign a VIP to one of the
   control-plane nodes.

```bash
export IMAGE_CHECKSUM="ab54897a1bcae83581512cdeeda787f009846cfd7a63b298e472c1bd6c522d23"
export IMAGE_CHECKSUM_TYPE="sha256"
export IMAGE_FORMAT="qcow2"
# Baremetal lab IMAGE_URL
export IMAGE_URL="http://192.168.0.150/CENTOS_9_NODE_IMAGE_K8S_v1.33.0.qcow2"
# Virtualized setup IMAGE_URL
export IMAGE_URL="http://192.168.222.1/CENTOS_9_NODE_IMAGE_K8S_v1.33.0.qcow2"
export KUBERNETES_VERSION="v1.33.0"
# Make sure this does not conflict with other networks
export POD_CIDR='["192.168.10.0/24"]'
# These can be used to add user-data
export CTLPLANE_KUBEADM_EXTRA_CONFIG="
    users:
    - name: user
      sshAuthorizedKeys:
      - ssh-ed25519 ABCD... user@example.com"
export WORKERS_KUBEADM_EXTRA_CONFIG="
      users:
      - name: user
        sshAuthorizedKeys:
        - ssh-ed25519 ABCD... user@example.com"
# NOTE! You must ensure that this is forwarded or assigned somehow to the
# server(s) that is selected for the control-plane.
export CLUSTER_APIENDPOINT_HOST="192.168.0.101"
export CLUSTER_APIENDPOINT_PORT="6443"
```

With the variables in place, we can render the manifests and apply:

```bash
clusterctl generate cluster my-cluster --control-plane-machine-count 1 --worker-machine-count 0 | kubectl apply -f -
```

You should see BareMetalHosts be provisioned as they are "consumed" by the
Metal3Machines:

```text
NAME      STATE         CONSUMER                        ONLINE   ERROR   AGE
bml-02    provisioned   my-cluster-controlplane-8z46n   true             68m
```

If all goes well and the API endpoint is correctly configured, you should
eventually see a healthy cluster. Check with
`clusterctl describe cluster my-cluster`:

```text
NAME                                                READY  SEVERITY  REASON  SINCE  MESSAGE
Cluster/my-cluster                                  True                     76s
├─ClusterInfrastructure - Metal3Cluster/my-cluster  True                     15m
└─ControlPlane - KubeadmControlPlane/my-cluster     True                     76s
  └─Machine/my-cluster-cj5zt                        True                     76s
```

## Cleanup

If you created a cluster using Cluster API, delete that first:

```bash
kubectl delete cluster my-cluster
```

Delete all BareMetalHosts with `kubectl delete bmh <name>`. This ensures that
the servers are cleaned and powered off.

Delete the management cluster.

```bash
kind delete cluster
```

Stop DHCP and image servers. They are automatically removed when stopped.

```bash
docker stop dnsmasq
docker stop image-server
```

If you did the virtualized setup you will also need to cleanup the sushy-tools
container and the VM.

```bash
docker stop sushy-tools

virsh -c qemu:///system destroy --domain bmh-vm-01
virsh -c qemu:///system undefine --domain bmh-vm-01 --remove-all-storage --nvram

virsh -c qemu:///system net-destroy baremetal
virsh -c qemu:///system net-undefine baremetal
```
