# Install Baremetal Operator

<!-- cSpell:ignore xena,cakey,kustomizations -->

Installing Baremetal Operator (BMO) involves usually three steps:

1. Clone Metal3 BMO repository `https://github.com/metal3-io/baremetal-operator.git`.
1. Adapt the configuration settings to your specific needs.
1. Deploy BMO in the cluster with or without Ironic.

*Note*: This guide assumes that a local clone of the repository is available.

## Configuration Settings

Review and edit the file `ironic.env` found in `config/default`.
The operator supports several configuration options for controlling
its interaction with Ironic.

`DEPLOY_RAMDISK_URL` -- The URL for the ramdisk of the image
containing the Ironic agent.

`DEPLOY_KERNEL_URL` -- The URL for the kernel to go with the deploy
ramdisk.

`DEPLOY_ISO_URL` -- The URL for the ISO containing the Ironic agent for
drivers that support ISO boot. Optional if kernel/ramdisk are set.

`IRONIC_ENDPOINT` -- The URL for the operator to use when talking to
Ironic.

`IRONIC_CACERT_FILE` -- The path of the CA certificate file of Ironic, if needed

`IRONIC_INSECURE` -- ("True", "False") Whether to skip the ironic certificate
validation. It is highly recommend to not set it to True.

`IRONIC_CLIENT_CERT_FILE` -- The path of the Client certificate file of Ironic,
if needed. Both Client certificate and Client private key must be defined for
client certificate authentication (mTLS) to be enabled.

`IRONIC_CLIENT_PRIVATE_KEY_FILE` -- The path of the Client private key file of Ironic,
if needed. Both Client certificate and Client private key must be defined for
client certificate authentication (mTLS) to be enabled.

`IRONIC_SKIP_CLIENT_SAN_VERIFY` -- ("True", "False") Whether to skip the ironic
client certificate SAN validation.

`BMO_CONCURRENCY` -- The number of concurrent reconciles performed by the
Operator. Default is the number of CPUs, but no less than 2 and no more than 8.

`PROVISIONING_LIMIT` -- The desired maximum number of hosts that could be (de)provisioned
simultaneously by the Operator. The limit does not apply to hosts that use
virtual media for provisioning. The Operator will try to enforce this limit,
but overflows could happen in case of slow provisioners and / or higher number of
concurrent reconciles. For such reasons, it is highly recommended to keep
BMO_CONCURRENCY value lower than the requested PROVISIONING_LIMIT. Default is 20.

`IRONIC_EXTERNAL_URL_V6` -- This is the URL where Ironic will find the image
for nodes that use IPv6. In dual stack environments, this can be used to tell
Ironic which IP version it should set on the BMC.

### Deprecated options

`IRONIC_INSPECTOR_ENDPOINT` -- The URL for the operator to use when talking to
Ironic Inspector. Only supported before baremetal-operator 0.5.0.

## Kustomization Configuration

It is possible to deploy ```baremetal-operator``` with three different operator
configurations, namely:

1. operator with ironic
1. operator without ironic
1. ironic without operator

A detailed overview of the configuration is presented in the following sections.

### Notes on external Ironic

When an external Ironic is used, the following requirements must be met:

* Either HTTP basic or no-auth authentication must be used (Keystone is not
  supported).

* API version 1.74 (Xena release cycle) or newer must be available.

## Authenticating to Ironic

Because hosts under the control of Metal³ need to contact the Ironic API during
inspection and provisioning, it is highly advisable to require authentication
on those APIs, since the provisioned hosts running user workloads will remain
connected to the provisioning network.

### Configuration

The `baremetal-operator` supports connecting to Ironic with the following
`auth_strategy` modes:

* `noauth` (no authentication - not recommended)
* `http_basic` (HTTP [Basic access authentication](https://en.wikipedia.org/wiki/Basic_access_authentication))

Note that Keystone (OpenStack Identity) authentication methods are not yet
supported.

Authentication configuration is read from the filesystem, beginning at the root
directory specified in the environment variable `METAL3_AUTH_ROOT_DIR`. If this
variable is empty or not specified, the default is `/opt/metal3/auth`.

Within the root directory, there is a separate subdirectory `ironic` for
Ironic client configuration.

#### `noauth`

This is the default, and will be chosen if the auth root directory does not
exist. In this mode, the baremetal-operator does not attempt to do any
authentication against the Ironic APIs.

#### `http_basic`

This mode is configured by files in each authentication subdirectory named
`username` and `password`, and containing the Basic auth username and password,
respectively.

## Running Bare Metal Operator with or without Ironic

This section explains the deployment scenarios of deploying Bare Metal
Operator(BMO) with or without Ironic as well as deploying only Ironic scenario.

**These are the deployment use cases addressed:**

1. Deploying baremetal-operator with Ironic.

1. Deploying baremetal-operator without Ironic.

1. Deploying only Ironic.

### Current structure of baremetal-operator config directory

```console
tree config/
config/
├── basic-auth
│   ├── default
│   │   ├── credentials_patch.yaml
│   │   └── kustomization.yaml
│   └── tls
│       ├── credentials_patch.yaml
│       └── kustomization.yaml
├── certmanager
│   ├── certificate.yaml
│   ├── kustomization.yaml
│   └── kustomizeconfig.yaml
├── crd
│   ├── bases
│   │   ├── metal3.io_baremetalhosts.yaml
│   │   ├── metal3.io_firmwareschemas.yaml
│   │   └── metal3.io_hostfirmwaresettings.yaml
│   ├── kustomization.yaml
│   ├── kustomizeconfig.yaml
│   └── patches
│       ├── cainjection_in_baremetalhosts.yaml
│       ├── cainjection_in_firmwareschemas.yaml
│       ├── cainjection_in_hostfirmwaresettings.yaml
│       ├── webhook_in_baremetalhosts.yaml
│       ├── webhook_in_firmwareschemas.yaml
│       └── webhook_in_hostfirmwaresettings.yaml
├── default
│   ├── ironic.env
│   ├── kustomization.yaml
│   ├── manager_auth_proxy_patch.yaml
│   ├── manager_webhook_patch.yaml
│   └── webhookcainjection_patch.yaml
├── kustomization.yaml
├── manager
│   ├── kustomization.yaml
│   └── manager.yaml
├── namespace
│   ├── kustomization.yaml
│   └── namespace.yaml
├── OWNERS
├── prometheus
│   ├── kustomization.yaml
│   └── monitor.yaml
├── rbac
│   ├── auth_proxy_client_clusterrole.yaml
│   ├── auth_proxy_role_binding.yaml
│   ├── auth_proxy_role.yaml
│   ├── auth_proxy_service.yaml
│   ├── baremetalhost_editor_role.yaml
│   ├── baremetalhost_viewer_role.yaml
│   ├── firmwareschema_editor_role.yaml
│   ├── firmwareschema_viewer_role.yaml
│   ├── hostfirmwaresettings_editor_role.yaml
│   ├── hostfirmwaresettings_viewer_role.yaml
│   ├── kustomization.yaml
│   ├── leader_election_role_binding.yaml
│   ├── leader_election_role.yaml
│   ├── role_binding.yaml
│   └── role.yaml
├── render
│   └── capm3.yaml
├── samples
│   ├── metal3.io_v1alpha1_baremetalhost.yaml
│   ├── metal3.io_v1alpha1_firmwareschema.yaml
│   └── metal3.io_v1alpha1_hostfirmwaresettings.yaml
├── tls
│   ├── kustomization.yaml
│   └── tls_ca_patch.yaml
└── webhook
    ├── kustomization.yaml
    ├── kustomizeconfig.yaml
    ├── manifests.yaml
    └── service_patch.yaml
```

The `config` directory has one top level folder for deployment, namely `default`
and it deploys only baremetal-operator through kustomization file calling
`manager` folder. In addition, `basic-auth`, `certmanager`, `crd`, `namespace`,
`prometheus`, `rbac`, `tls` and `webhook` folders have their own kustomization
and yaml files. `samples` folder includes yaml representation of sample CRDs.

### Current structure of ironic-deployment directory

```console
tree ironic-deployment/
ironic-deployment/
├── base
│   ├── ironic.yaml
│   └── kustomization.yaml
├── components
│   ├── basic-auth
│   │   ├── auth.yaml
│   │   ├── ironic-auth-config
│   │   ├── ironic-auth-config-tpl
│   │   ├── ironic-htpasswd
│   │   └── kustomization.yaml
│   ├── keepalived
│   │   ├── ironic_bmo_configmap.env
│   │   ├── keepalived_patch.yaml
│   │   └── kustomization.yaml
│   └── tls
│       ├── certificate.yaml
│       ├── kustomization.yaml
│       ├── kustomizeconfig.yaml
│       └── tls.yaml
├── default
│   ├── ironic_bmo_configmap.env
│   └── kustomization.yaml
├── overlays
│   ├── basic-auth_tls
│   │   ├── basic-auth_tls.yaml
│   │   └── kustomization.yaml
│   └── basic-auth_tls_keepalived
│       └── kustomization.yaml
├── OWNERS
└── README.md
```

The `ironic-deployment` folder contains kustomizations for deploying Ironic.
It makes use of kustomize components for basic auth, TLS and keepalived configurations.
This makes it easy to combine the configurations, for example basic auth + TLS.
There are some ready made overlays in the `overlays` folder that shows how this
can be done. For more information, check the readme in the `ironic-deployment`
folder.

### Deployment commands

There is a useful deployment script that configures and deploys BareMetal
Operator and Ironic. It requires some variables :

* IRONIC_HOST : domain name for Ironic
* IRONIC_HOST_IP : IP on which Ironic is listening

In addition you can configure the following variables. They are **optional**.
If you leave them unset, then passwords and certificates will be generated
for you.

* KUBECTL_ARGS : Additional arguments to kubectl apply
* IRONIC_USERNAME : username for ironic
* IRONIC_PASSWORD : password for ironic
* IRONIC_CACERT_FILE : CA certificate path for ironic
* IRONIC_CAKEY_FILE : CA certificate key path, unneeded if ironic
* certificates exist
* IRONIC_CERT_FILE : Ironic certificate path
* IRONIC_KEY_FILE : Ironic certificate key path
* MARIADB_KEY_FILE: Path to the key of MariaDB
* MARIADB_CERT_FILE:  Path to the cert of MariaDB
* MARIADB_CAKEY_FILE: Path to the CA key of MariaDB
* MARIADB_CACERT_FILE: Path to the CA certificate of MariaDB

Before version 0.5.0, Ironic Inspector parameters were also used:

* IRONIC_INSPECTOR_USERNAME : username for inspector
* IRONIC_INSPECTOR_PASSWORD : password for inspector
* IRONIC_INSPECTOR_CERT_FILE : Inspector certificate path
* IRONIC_INSPECTOR_KEY_FILE : Inspector certificate key path
* IRONIC_INSPECTOR_CACERT_FILE : CA certificate path for inspector, defaults to
  IRONIC_CACERT_FILE
* IRONIC_INSPECTOR_CAKEY_FILE : CA certificate key path, unneeded if inspector
  certificates exist

Then run :

```sh
./tools/deploy.sh [-b -i -t -n -k]
```

* `-b`: deploy BMO
* `-i`: deploy Ironic
* `-t`: deploy with TLS enabled
* `-n`: deploy without authentication
* `-k`: deploy with keepalived

This will deploy BMO and / or Ironic with the proper configuration.

### Useful tips

It is worth mentioning some tips for when the different configurations are
useful as well. For example:

1. Only BMO is deployed, in  a case when Ironic is already running, e.g. as part
   of Cluster API Provider Metal3
   [(CAPM3)](https://github.com/metal3-io/cluster-api-provider-metal3) when
   a successful pivoting state was met and ironic being deployed.

1. BMO and Ironic are deployed together, in a case when CAPM3 is not used and
   baremetal-operator and ironic containers to be deployed together.

1. Only Ironic is deployed, in a case when BMO is deployed as part of CAPM3 and
   only Ironic setup is sufficient, e.g.
   [clusterctl](https://cluster-api.sigs.k8s.io/clusterctl/commands/move.html)
   provided by Cluster API(CAPI) deploys BMO, so that it can take care of moving
   the BaremetalHost during the pivoting.

**Important Note**
When the baremetal-operator is deployed through metal3-dev-env, baremetal-operator
container inherits the following environment variables through configmap:

```ini

$PROVISIONING_IP
$PROVISIONING_INTERFACE

```

In case you are deploying baremetal-operator locally, make sure to populate and
export these environment variables before deploying.
