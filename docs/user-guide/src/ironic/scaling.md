# Scaling Ironic

This document will guide you through important considerations when scaling your
Metal3 deployment beyond a simple testing environment. Please remember while
reading this text that scaling is not a one-size-fits-all topic. The higher the
scale you're trying to achieve, the more site-specific decisions you may need
to make.

## Baseline and general considerations

A standard Metal3 deployment will involve a single instance of Ironic backed by
SQLite as a database. The following host numbers can serve as a baseline:

### 1-300 hosts

In this area you can expect the defaults to work reasonably well with little
to no tuning. The two most important considerations are:

- Batched deployments. Deploying all 300 hosts at once can work, but it's
  recommended to start with smaller batches (no more than 50 hosts) and work
  your way up from that.

- Networking throughput. Especially with higher concurrency it's important to
  ensure performant networking both on the provisioning and the BMC networks
  (the latter in case of virtual media).

### 300-3500 hosts

3500 is the largest number of hosts our users have reported successfully
managing and provisioning. Your ability to reach this number will depend on the
exact configuration and workflow. In addition to previously mentioned
considerations:

- Check the [Ironic scaling
  guide](https://docs.openstack.org/ironic/latest/install/refarch/common.html#ha-and-scalability).
  It contains a lot of tips applicable to Metal3.

  **NOTE:** Ironic documentation uses the word *node* where Metal3 uses *host*.

- Aggressively disable features you don't use both on BMO and Ironic sides.
  [Inspection](../bmo/inspect_annotation.md) is an example of a feature that
  is enabled by default but can be optional in many cases.

- If you don't expect to actively manage provisioned hosts, consider
  [detaching](../bmo/detached_annotation.md) them to save some resources.

### 3500+ hosts

This is the area where the default configuration will most certainly *not* work
for you. This level of scaling is currently rare among Metal3 users. Ironic
users who achieved it resorted to multi-replica deployments, sometimes also
relying on Ironic-host locality with *conductor groups*.

Check the next section for ideas on how to apply these patterns to Metal3.

## Ironic HA deployment

[IrSO](../irso/introduction.md) can install Ironic in an HA configuration,
where every replica handles its share of hosts and can respond to API requests
for any of them.

Due to architectural restrictions, the HA mode still relies on host networking
for the Ironic pod. Replicas are installed via a *daemon set* one per each
node.

See [High availability in IrSO](../irso/ha.md) for more details.

## Multiple Ironic instances, single control plane

An alternative approach is to split your hosts into logical groups (most likely
based on their location) and to assign each of them a separate BMO instance and
an Ironic deployment using namespaces.

In this architecture, for each host namespace:

1. Install a separate Ironic on its own Kubernetes node using `nodeSelector`.
   It may make sense to co-locate this node with the hosts being deployed,
   especially if you're planning on using network boot.

1. Install BMO using its `-namespace` argument to provide the namespace to
   handle hosts in. Point this BMO at its corresponding Ironic.

In the end, configure your RBAC for BareMetalHosts so that they can be created
only in configured namespaces.

As a result, a namespace becomes a rough equivalent of a *conductor group* in
the Ironic world. This approach has several advantages over a normal HA
deployment:

- Logical assignment of hosts to locations. Creating a host in a certain
  namespace automatically assigns it to a certain Ironic instance.

- Database is not shared across locations. If you use one replica per location,
  you can even keep using SQLite.

- You're not limited at all by Ironic or BMO scalability. If you need to expand
  your cluster, add more namespaces, Ironic instances and BMO.

- You can still use [Ironic HA](../irso/ha.md) inside each location.
