# Synchronize Labels between BaremetalHosts and Kubernetes Nodes

There are use cases where certain information is inherently tied to the BMH but
at the same time, is valuable to the users/operators/schedulers in the K
workload cluster. For example, a user may wish to place her workloads across
hosts that are in different failure zones. In Kubernetes, labels on Node objects
are the primary means by which to solve this problem. The proposal is for CAPM3
to synchronize a specific set of labels placed on a BMH with labels on the
corresponding Kubernetes Node running on that BMH.

## User Stories

As a user I want replicas of a specific workload spread out across different
server racks or geographical locations.

As a user, I would like to place my security sensitive workloads on machines
that meet specific security requirements. For example, certain hosts may be
in a fortified zone within a data center or certain hosts may have strong
hardware based security mechanisms in place (e.g. hardware attestation via TPM).

## Goals

* Implement a label synchronization mechanism between BMH and Node objects
* Limit the scope of synchronization to only labels matching a configured set
  of prefixes
* Support a wide range of label prefixes including those in *.kubernetes.io/*

## Non-Goals

* Synchronize taints or annotation on a BMH with those on the Node

## Proposal

CAPM3 can already map a BMH object to the corresponding Node object. The
proposal seeks to extend CAPM3 to also perform label synchronization
between the two.

Synchronization is not just a one time copy from BMH to Node on creation.
More specifically, synchronization accomplishes the following:

1. Addition/Removal of a label, within the set of predefined prefixes, on the
  BMH will result in the addition/removal of that label on the corresponding
  Node. Labels outside the prefix set will be ignored.
1. Addition/Removal of a label, within the set of predefined prefixes,
  *directly* on the Node will result in the removal/re-adding of that label
  on the Node.

The synchronization should be limited to only labels matching a certain set of
prefixes. The primary reason for this limitation is to avoid stepping on labels
managed by other entities. Here CAPM3 would own the set of labels that match the
prefixes. For example, the user may specify *my-prefix.foobar.io/* as their
prefix. Labels placed on the BMH that match this prefix would be synchronized
with the labels on the Node object. For example,

```yaml
kind: BareMetalHost
name: node-0
metadata:
  labels:
    my-prefix.foobar.io/rack: xyz-123
    my-prefix.foobar.io/zone: security-level-0
    some-other-prefix.blah.io/cow: moo
---
kind: Node
name: worker-node-0
metadata:
  labels:
    my-prefix.foobar.io/rack: xyz-123
    my-prefix.foobar.io/zone: security-level-0
```

It's assumed that labels beginning with the specified prefix(es) are owned by
CAPM3 and CAPM3 is solely responsible for keeping the set of labels in sync
between BMH and Node objects. In other words, for the given set of label
prefixes, the BMH is the source of truth and CAPM3 will enforce their
presence on the Node.

Additionally, there are certain well-known prefixes (e.g.
kubelet.kubernetes.io/*, beta.kubernetes.io/*, kubernetes.io/*, k8s.io/*) that
should be disallowed. Note the distinction between *.kubernetes.io/* (allowed)
versus kubernetes.io/* (disallowed).

### Synchronization Approach

Synchronization must handle two scenarios: (i) a label is added/removed on a
BMH and must be added/removed on the corresponding Node and (ii) a label is
added/removed on the Node and must be removed/re-added on the Node to bring it
in sync with the labels on BMH.

The actual implementation of the synchronization logic may be encapsulated
into an additional controller running within CAPM3; however, in the discussion
below we simply reference CAPM3 as the entity doing the work.

Scenario (i) can be handled as follows:

1. CAPM3 will set up a watch on the BMH resource. It only requires read-only
  access similar to what is done today:

    baremetalhosts,verbs=get;list;watch

1. On each BMH reconcile event, the controller will fetch the corresponding
  Node. The *mapping* can be accomplished by:

    BMH.ConsumerRef --> Metal3Machine.OwnerRef --> Machine.Status.NodeRef

1. Synchronize the labels and update the Node in the workload cluster. CAPM3
  already fetches the Node objects from the workload clusters today using a
  remote client. We would leverage that same capability here.

Scenario (ii) can be handled with a full-sync of all BMH and Node objects at a
preconfigured synchronization interval.

An alternative would be to set up a watch on the Node resource types in every
workload cluster. The benefit being that we can quickly synchronize any label
changes on the Node object itself. However, this introduces complications when
the management cluster != workload cluster and additionally, when there are
many workload clusters being managed by a single management cluster. How such
a watch could be implemented within the controller-runtime model would require
further investigation.

Controller-runtime supports requeuing of a resource after a specified time has
elapsed via the `RequeueAfter` field in its Result object. We can use this
to ensure that synchronization always happens on every BMH at least once
within a desired interval.

### Configuration

We need to expose two additional configuration variables to the user: the set
of label prefixes and the full-sync interval.

Several alternatives were also considered (see Alternatives section).

#### Metal3Cluster

We can have the prefixes specified at the Metal3Cluster level. For example,

```yaml
kind: Metal3Cluster
name: test1
spec:
  metal3-label-sync-prefixes: "my-prefix.foobar.io, my-prefix.kubernetes.io"
  metal3-label-sync-interval: "30s"
```

Alternatively, we can use an annotation on the Meal3Cluster:

```yaml
kind: Metal3Cluster
name: test1
metadata:
  annotations:
    metal3.io/metal3-label-sync-prefixes: "my-prefix.foobar.io, my.thing"
    metal3.io/metal3-label-sync-interval: "30s"
```

We need to map the BMH to the Metal3Cluster object. One path to doing this is
as follows:

```diff
    BMH.ConsumerRef --> Metal3Machine.OwnerRef -->
    CAPI.Machine.Labels{cluster.x-k8s.io/cluster-name} -->
    CAPI.Cluster.InfrastructureRef.Namespace/Name --> Metal3Cluster
```

Similarly, when Metal3Cluster is updated, we need to fetch all associated
BMHs. One path to doing this is as follows:

```diff
    Metal3Cluster.OwnerRef --> CAPI.Cluster -->
    Label-Selector{CAPI.Cluster.Name} --> CAPI.MachineList -->
    Machine.Spec.InfrastructureRef.Namespace/Name -->
    Metal3Machine.Annotation{metal3.io/BareMetalHost} --> BMH
```

The last step is to map the Metal3Machine to the BMH. Currently, an annotation
is added to the Metal3Machine of the format  `metal3.io/BareMetalHost:
Namespace/Name`. We can use this annotation to fetch the corresponding BMH.

```console
    Kind:         Metal3Machine
    Annotations:  metal3.io/BareMetalHost: metal3/bmh-node-0
```

### Other Issues

#### Prefix Deletion

Removal of a prefix, p1, from the configuration, has two consequences:

1. Any additional labels with prefix p1 placed on the BMH will not be
  synchronized to the corresponding Node.

1. Any existing labels with prefix p1 present on the BMH or Node objects
  will not be removed. Removal of these labels is the users responsibility.

#### Delay between Node create and label sync

The Node object is first created when kubeadm joins a node to the workload
cluster (i.e. kubelet is up and running). There may be a delay (potentially
several seconds) before the CAPM3 node synchronization logic kicks in to apply
the labels on the Node.

Kubernetes supports both equality and inequality requirements in label selection.

In an equality based selection, the user wants to place a workload on node(s)
matching a specific label (e.g. Node.Labels contains `my.prefix/foo=bar`). The
delay in CAPM3 applying the label on the node, may cause a subsequent delay in
the placement of the workload, but this is likely acceptable.

In an inequality based selection, the user wants to place a workload on node(
s) that do not contain a specific label (e.g. Node.Labels not contain
`my.prefix/foo=bar`). The case is potentially problematic because it relies on
the absence of a label and this can occur during the delay.

One way to address this is to use kubelet's `--node-labels` flag. In CAPI, we
can potentially utilize `kubeletExtraArgs` within the KubeadmConfig spec for
this purpose. However, this would require further investigation.  In
particular, since the KubeadmConfig objects are generally created from
KubeadmConfigTemplate, can we dynamically patch the objects with the labels
from the BMH?

Another possibility is to utilize the Metal3DataTemplate for labeling the
nodes. This would need to further investigation as well.

Yet another possibility is to use a temporary label (e.g. `label-sync-pending`)
through kubelet's `--node-labels` at node creation. The label can subsequently
be removed by CAPM3 when it has applied the desired set of labels. The user
must construct their label-selectors with this label in mind. For example:

```console
    Node.Labels not contain `label-sync-pending` AND Node.Labels not contain `my.prefix/foo=bar`...
```

This approach can also be implemented entirely by the user. For example, the
user may specify through the KubeadmConfigTemplate a label similar to
`label-sync-pending`. Subsequently, when the node is ready to accept workloads
(e.g. the desired labels have been applied by CAPM3), they can manually remove
this label.

There is also a security vulnerability associated with kubelet's ability to
self-label the Node object. This has been
[addressed](https://github.com/kubernetes/enhancements/tree/master/keps/sig-auth/279-limit-node-access).
However, as a consequence, BMH labels that fall within the *.kubernetes.io/*
space cannot be specified via kubelet's `--node-labels` flag.

Any solution to this issue is beyond the scope of this proposal. We should
however document this limitation.

## Alternatives

* A provider-agnostic mechanism could be implemented in CAPI itself. For
  example, labels placed on a provider specific Machine object (e.g.
  Meta3Machine) could be read by CAPI and applied to corresponding Kubernetes
  Node. [Here is](https://github.com/kubernetes-sigs/cluster-api/issues/3504)
  one such use case for the AWS provider. However, there is reluctance in the
  CAPI community to support such a mechanism. Additionally, for metal3, such a
  scenario would still require that CAPM3 synchronize labels from BMH to
  Metal3Machine.
* Specifying labels via KubeadmConfigTemplate's
  `NodeRegistration.KubeletExtraArgs`. This approach is complementary but has
  certain limitations:
    1. Labels are only applicable at creation time. Adding/Removing a new
      label requires a complete MachineDeployment rollout. This is highly
      undesirable in a baremetal environment.
    1. MachineDeployment grouping may not always provide the needed
      granularity; effectively a MachineDeployment == workload type. Depending
      on the how granular the user wants their labeling, this may lead to a
      large number of MachineDeployments.
    1. There are cases where a logical grouping like MachineDeployment is not
      appropriate when trying to capture physical grouping. For example, you
      may want a specific label on all hosts in the same rack but logically
      hosts in the rack may belong to different MachineDeployments.
    1. There are security concerns with kubelet's `--node-labels` flag (as
      mentioned in this proposal). This is not a deal breaker but definitely
      undesirable.
* Using node-feature-discovery to apply labels. This approach is also
    complementary, but has certain limitations:
    1. Certain information may not be discoverable by host inspection alone.
      For example, user intent cases such as I want to label certain hosts as
      temporary so only workloads that can tolerate interruptions are scheduled
      there.
    1. It would require that users deploy (and potentially implement)
      controllers for feature discovery. The proposed mechanism for label sync
      would provide a convenient, albeit more manual, alternative.

### Configuration Alternatives

The following were also considered for specifying the prefix set.

#### Command-Line Flag

We need to expose two additional configuration variables to the user: the set
of label prefixes and the full-sync interval. We can introduce two new
command-line flags for CAPM3, and also utilize default values if the flags are
not specified: (i) `--bmh-label-prefixes` with a nil default value and (ii)
`--label-sync-interval` with a 60-second default value.

Unfortunately, command-line flags will not be compatible with openShift where
cluster administrators do not deploy metal3 themselves and do not have access
to the command line arguments for the cluster-api provider.

#### Annotations on BMH

In this approach, an annotation is added to a BMH, in addition to the labels
to be synchronized, which reflects the prefixes to be utilized. For example,

```yaml
kind: BareMetalHost
metadata:
  annotations:
    metal3.io/label-prefixes: {"my-prefix.foobar.io","my-prefix.kubernetes.io"}
  labels:
    my-prefix.foobar.io/rack: xyz-123
    my-prefix.kubernetes.io/zone: security-level-0
```

A concern with this approach is consistency since the same annotation would
have to be duplicated across BMHs. The prefixes, while user configurable, are
static and should not require re-configuring. For example, in a likely
scenario, the cluster admin would define a standard set of prefixes to
be used internally. Also, annotations can be (accidentally) added/removed/
changed, leading to undesirable behavior.

#### New API Type

We could introduce a new API type: `BareMetalHostLabelSyncProfile` (any other
suggestions for the name?).

The common case is when a label on the BMH is updated, we must first find the
corresponding `BareMetalHostLabelSyncProfile` (if any) that matches the BMH.
To avoid fetching all `BareMetalHostLabelSyncProfile`, we can make use of a
label on the BMH, in namespace/name format, that references the
`BareMetalHostLabelSyncProfile` (see example below). We can drop the namespace
requirement if it's in the same namespace as the BMH.

The less common case is where the `BareMetalHostLabelSyncProfile` is updated (
e.g. a prefix is removed). In this case, we will need to fetch all BMHs
associated and perform a sync operations across the impacted Nodes. Label
selectors could be used for this purpose.

The approach is illustrated below:

```yaml
kind: BareMetalHost
metadata:
  labels:
    metal3.io/baremetalhost-label-sync-profile: some-ns/label-sync-profile-0
---
kind: BareMetalHostLabelSyncProfile
name: label-sync-profile-0
namespace: some-ns
labelSelector:
  matchLabels:
    metal3.io/baremetalhost-label-sync-profile: some-ns/label-sync-profile-0
prefixes:
- my-prefix.foobar.io
- my-prefix.kubernetes.io
label-sync-interval: "30s"
```

It's the admin's/user's responsibility to create linkage by labeling BMHs (e.g
`metal3.io/baremetalhost-label-sync-profile: some-ns/label-sync-profile-0`).

## Related

* There is a related issue in the CAPI community. See [over here](https://github.com/kubernetes-sigs/cluster-api/issues/493).
  The proposal there is for CAPI to synchronize labels placed on
  MachineDeployment objects with the Nodes created from that deployment. While
  similar, they are addressing different things. However, the proposed CAPI
  approach also uses prefixes to limit the scope of the synchronization.
