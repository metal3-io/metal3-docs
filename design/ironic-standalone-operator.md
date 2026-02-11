<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Ironic Standalone Operator

## Status

implementable

## Summary

This proposal discussed the [ironic-standalone-operator][ir-op] project that
was written using inspiration from OpenShift's
[cluster-baremetal-operator][cbo]. The project is already under the Metal3's
umbrella, so this document serves to describe its design goals, future plans
and the rough API shape.

[ir-op]: https://github.com/metal3-io/ironic-standalone-operator
[cbo]: https://github.com/openshift/cluster-baremetal-operator

## Motivation

Ironic is not trivial to install and operate. Although we provide
[ironic-deployment scripts][ironic-deployment] as part of BMO, there are still
a lot of moving parts where things can be wrong. Configuring Ironic through
environment variables is error-prone and complicates upgrades. The operator
pattern is standard and ubiquitous in the Kubernetes world to manage complex
software. Metal3 should use it as well.

[ironic-deployment]: https://github.com/metal3-io/baremetal-operator/tree/main/ironic-deployment

### Goals

- Provide a recommended way to install Ironic and its satellite services for
  using with Metal3.
- Make it easy to install and manage Ironic for Metal3 newcomers.
- Provide a Kubernetes operator that can also be used outside of Metal3.
- Pave the way for highly-available Ironic installations.

### Non-Goals

Explicitly not planned:

- Tailor the new operator to use cases outside of Metal3 except for the most
  minor things.
- Support for versions of ironic-image predating this proposal (e.g. the ones
  containing ironic-inspector).
- Deprecate or discourage alternative ways to install Ironic for Metal3, get
  rid of ironic-image/mariadb-image.
- Install BMO, IPAM or CAPM3 via the same operator.

May happen in the future but not as part of this proposal:

- Radically change the installed architecture. For example, we have bold plans
  to look into dropping the host networking requirement.
- Stabilize the API design.

## Proposal

### User Stories

As an administrator, I want to be able to install Ironic in a way that is
suitable for Metal3 by installing an operator and creating custom Kubernetes
resources.

## Design Details

This proposal adds a new repository under the Metal3 umbrella:
ironic-standalone-operator. It is a Kubernetes operator that exposes a few
Custom Resources and manages an Ironic installation.

### Naming

The project has undergone a heavy discussion on its naming. The initial name
was straightforward: ironic-operator. However, it was quickly found to conflict
with a few existing projects, including a pretty active one developed by Red
Hat as part of its OpenStack offering.

Another candidate was metal3-ironic-operator. The arguments against it were
inconsistency with other Metal3 projects (we don't call BMO
metal3-baremetal-operator even though baremetal-operator is pretty generic) and
the desire to make the new operator usable outside of pure Metal3.

The argument against using the word "standalone" was that this word is
overloaded in the OpenStack context and may be unclear to people without this
context. A poll among contributors showed that the intention of the word is at
least more or less clear to us, and that it clearly conveys the difference from
the Red Hat's OpenStack operator.

A few code names were also discussed but ruled out because of a potential user
confusion and possible trademark issues.

Note that there is no established acronym for ironic-standalone-operator like
we have for baremetal-operator (BMO) or CAPM3. Using ISO is definitely going to
be confusing. This document will be referring to ironic-standalone-operator or
just "the operator" in cases where it does not cause confusion with a human
operator.

### Implementation Details/Notes/Constraints

This section describes the current state of the project. It is not an attempt
to fix the details forever. I'm using it to give a reader a clearer idea what
the operator currently does.

#### Current architecture

The operator has two controllers: for MariaDB and for Ironic plus its auxiliary
containers.

The MariaDB controller, also referred to as the *database controller* in this
context, starts a MariaDB instance in a *deployment* using
[mariadb-image][mariadb-image]. As with Metal3 now, MariaDB is optional: if it
is not configured, SQLite is used instead.

The Ironic controller starts and manages the following components:

- Ironic itself
- HTTPD for serving images and iPXE scripts
- Dnsmasq for DHCP and TFTP
- Ramdisk logs publisher
- IPA downloader

All these components are used in the same way as in a traditional Metal3
installation. Note that the IPA Downloader fate is under discussion: there is
a strong desire to make it optional and maybe replace with a different method
of delivering IPA images.

Unlike the current Metal3, the operator requires authentication and will create
secrets with random credentials when a user does not provide them. We're
considering to do the same with TLS, but it requires [figuring out CA
integration][issue4].

[mariadb-image]: https://github.com/metal3-io/mariadb-image/
[issue4]: https://github.com/metal3-io/ironic-standalone-operator/issues/4

#### HA architecture

The *non-HA* architecture is the architecture that Metal3 uses now. All Ironic
components are run in a single *deployment*.

The *HA* architecture is a new concept in ironic-standalone-operator. It
involves running a copy of Ironic and HTTPD per control plane node (so, 3
copies in most cases). This has two benefits:

1. Ironic can be updated in a rolling fashion without an interruption in the
   service.
1. Due to the way Ironic is designed, each replica will handle its proportion
   (1/3 in most cases) of nodes (active/active architecture, not
   active/backup).

MariaDB is not going to be run in an HA fashion. The mid-term plans include
looking into using a persistent volume for it instead.

When the HA architecture is enabled via a flag on the `Ironic` resource, all
Ironic components (except for MariaDB and dnsmasq) will be installed in a
*DaemonSet* instead of a *Deployment* to make sure there is one Ironic instance
per each control plane node (see FAQ below).

##### Dnsmasq, iPXE and provisioning network

Dnsmasq is also not going to be run with more than 1 replica. It's not
impossible to run several DHCP servers on the same network, but it's harder to
configure and to debug. In the future, we might look into some sort of a
managed DHCP offering, e.g. [Kea][kea].

Using a provisioning network will require having a provisioning IP per each
control plane node instead of only one with the non-HA architecture.

Using iPXE in the HA configuration poses one more problem. Our (static) DHCP
configuration must point each host at its iPXE configuration script. However,
dnsmasq does not know, which host belongs to which Ironic instance. To tackle
this limitation, a new [boot configuration API][boot config] has been proposed
(but not yet implemented) in Ironic. It will allow our DHCP configuration to
always point at the same Ironic instance for iPXE configuration, and Ironic
itself will do the required routing.

[boot config]: https://specs.openstack.org/openstack/ironic-specs/specs/approved/boot-config-api.html

##### JSON RPC

Ironic itself is a clustered software. Each instance, as noted above, will
handle its share of all nodes. When an instance crashes, the remaining
instances will take over its responsibilities. You can hit the API on any
instance for any node, and the request will be forwarded to the right instance.

To achieve that, Ironic supports JSON RPC. Metal3 currently does not use it,
and it still will not be used in the non-HA case. For JSON RPC to be usable,
each Ironic instance must register its RPC access IP or hostname in the
database.

When TLS support is enabled, the RPC communication must be secured by
TLS as well. This may pose a problem since each Ironic instance needs a TLS
certificate that is valid for its RPC access IP or hostname. This problem has
been extensively discussed in the [initial HA proposal][issue3], and here is
the proposed solution, at least for the MVP case:

The Ironic controller will generate a self-signed CA and pass its public and
private parts into each Ironic container. Each Ironic container will generate
its private key certificate and sign the certificate with this CA. The CA will
be trusted **only** for the RPC purpose, removing the possibility of abuse.
To reduce the number of code paths, this process will happen unconditionally,
even when TLS for Ironic itself is not enabled.

[kea]: https://www.isc.org/kea/
[issue3]: https://github.com/metal3-io/ironic-standalone-operator/issues/3

#### Architecture FAQ

Q: Why cannot we split dnsmasq into a separate deployment in the non-HA
architecture?
A: That may require having more than one IP address on the provisioning
network: for dnsmasq and for httpd/ironic. This is a new operational
requirement that I'd like to avoid at this stage.

Q: Why does the same dnsmasq limitation affect the HA architecture?
A: The HA architecture is completely new here, so we can introduce new
requirements without regression in the operational experience.

Q: Why using *DaemonSets* if *StatefulSets* provide us an easier way to address
separate Ironic instances?
A: While we're relying on host networking, making several Ironic instances
co-exist on the same Kubernetes node is too complex. Also, several Ironic
instances on the same node is not really an **HA** setup.

Q: Why aren't we using HostPort services?
A: The fact that they provide a random port is a roadblock for production
deployments since many of them require opening a predictable port in the
firewall configuration. If we use a pre-defined port, it may cause conflicts
with other HostPort services or even end up outside of the allowed range.

#### Current API design

Currently, the API consists of two main objects: `IronicDatabase` and `Ironic`.

The `IronicDatabase` object is very simple:

- `credentialsRef` - a reference to a secret with credentials (generated if
  missing)
- `image` - container image to use
- `tlsRef` - a reference to a TLS secret to use for the service

**NOTE:** after this design proposal was accepted, a decision [was
made](https://github.com/metal3-io/ironic-standalone-operator/issues/142) to
deprecate `IronicDatabase` in favour of 3rd party operators, such as [mariadb
operator](https://github.com/mariadb-operator/mariadb-operator).

The `Ironic` object is much more complex and should probably be split into more
custom resources as we polish its internal architecture. Currently, it uses
nested structures to logically group fields. Here are the most important fields
(omitting various fine-tuning for brevity):

- `credentialsRef` - a reference to a secret with credentials (generated if
  missing)
- `databaseRef` - a reference to an `IronicDatabase` object (if needed)
- `highAvailability` (called `distributed` in the prototype) - a boolean flag
  that enables the HA architecture
- `networking` - a nested structure that defines networking (see below)
- `nodeSelector` - a selector for nodes to run Ironic on
- `tlsRef` - a reference to a TLS secret to use for the service

The `networking` sub-structure deserves a separate consideration:

- `apiPort`, `imageServerPort`, `imageServerTLSPort` allow overriding listening
  ports for the services
- `bindInterface` - a boolean flag that makes Ironic listen on only the
  provisioning interface
- `dhcp` - another nested structure with DHCP parameters (see below)
- `externalIP` - IP through which nodes deployed over virtual media access
  Ironic and HTTPD
- `interface`, `ipAddress`, `macAddresses` - various ways to specify the
  provisioning interface

Finally, the `dhcp` sub-sub-structure contains the following fields:

- `networkCIDR` - CIDR of the provisioning network (required)
- `rangeBegin`, `rangeEnd` define the DHCP range (derived from `networkCIDR` if
  missing)
- `dnsAddress`, `serveDNS` - two mutually exclusive ways to optionally provide
  DNS to hosts: either a fixed address or dnsmasq itself
- `hosts`, `ignore` - fine tuning for specific hosts
- `gatewayAddress` - IP address of the default gateway (if necessary)

Providing a non-nil `dhcp` value enables dnsmasq.

### Risks and Mitigations

Our reliance on host networking means that it's not trivial to have several
Ironic installations on the same cluster. Each would need to use different
ports to avoid conflicts. Even without host networking, having several dnsmasq
instances on the same network is not going to work without some sort of
coordination between them.

### Work Items

General enablement:

- Add the operator to the development environment.
- Add an optional flag either to metal3-dev-env or to BMO e2e tests (TBD) that
  uses ironic-standalone-operator instead of the Kustomize scripts in BMO.
- Create and run CI jobs (integration or e2e - depending on the previous work
  item) on the operator.

HA:

- Implement the boot configuration API in Ironic (dependency).
- Start generating a private CA for JSON RPC.
- Enable the HA architecture.
- Adjust ironic-image to enable updates without wiping the database (see
  below).

### Dependencies

None for the core operator.

The HA approach will require [boot configuration API][boot config].

### Test Plan

The new operator will become the primary way to install Ironic. As such, it
will be tested in various CI jobs.

### Upgrade / Downgrade Strategy

By default, the operator will be tightly coupled with the version of Ironic
(and, eventually, IPA) that it installs. A release of the operator will follow
each release of ironic-image, and they release branches will match. The `main`
branch will continue following the latest container image.

After each full reconciliation, the operator will store the version of Ironic
it has just installed in the `status`. In the future, this will allow to apply
any logic on upgrade. However, ironic-image will remain usable and upgradable
without ironic-standalone-operator for the sake of users that use other
deployment methods.

To accommodate downstream modifications (like in OpenShift), it will be
possible to modify all images, as well as the installed version, via
environment variables.

#### Database Migrations

Having MariaDB as a separate container also poses a new challenge for Metal3
since now Ironic will sometimes start with the database already populated
rather than a clean one (as is the case for SQLite). To accommodate this:

- We'll create a new container entrypoint that will run the *online data
  migrations* for Ironic while the service is already running (a part of
  the upgrade process that we've ignored so far).
- We'll probably need to upgrade the database schema separately from Ironic to
  avoid running it 3+ times in parallel. Maybe it will take a form of a *Job*.
- BMO will need to be updated to handle more cases of unexpected provision
  state. E.g. what needs to be done when the BMH is *inspecting* but the node
  is found in a completely wrong state like `active` or `clean wait`.

#### IPA Upgrades

Currently, the only way to update IPA is to restart the IPA downloader
(essentially, re-create the whole pod). There is no way at all to track which
version of IPA is installed. This issue is known and is currently a subject of
discussions that will also be reflected in the ironic-standalone-operator
upgrade strategy.

### Version Skew Strategy

By default, the operator will not allow a version skew with the version of
Ironic and its image, except for the duration of an upgrade.

## Drawbacks

- One more project for the small Metal3 team to maintain.

## Alternatives

- Keep using Kustomize YAML files to install Ironic. This approach has already
  proven to be error-prone and confusing especially for new users.

## References
