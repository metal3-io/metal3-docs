# Labels Synchronization between BareMetalHost and Kubernetes Nodes

CAPM3 has mechanism to synchronize BareMetalHost (BMH) labels with predefined
prefixes to the corresponding Kubernetes node object on that BMH.

## How to use?

To use label synchronization user needs to define prefix(es) for labels. Only
labels that fall within prefix set are synchronized. User defines prefixes with
annotation in Metal3Cluster object by using
**metal3.io/metal3-label-sync-prefixes** annotation key and gives prefixes as
annotation value. Prefixes should be separated by comma.

In the following example we are defining two label prefixes for label
synchronization: **test.foobar.io** and **my-prefix**.

```bash
kubectl annotate metal3cluster test1 metal3.io/metal3-label-sync-prefixes=test.foobar.io,my-prefix -n=metal3 --overwrite
```

**Note:** All prefixes should be complaint with [RFC 1123](https://kubernetes.io/docs/concepts/overview/working-with-objects/names/#dns-subdomain-names).

After adding annotation on Metal3Cluster, we label BMH nodes with labels that
start with prefixes defined above:

```bash
kubectl label baremetalhosts node-0 my-prefix/rack=xyz-123 -n=metal3
kubectl label baremetalhosts node-0 test.foobar.io/group=abc -n=metal3
```

**Note:** Prefixes should be separated from the rest of the label key by **"/"**, e.g. my-prefix/rack, test.foobar.io/xyz

Now label sync controller will apply same labels to corresponding Kubernetes node.

```bash
$ kubectl get nodes --show-labels
NAME          STATUS    ROLES  AGE  VERSION  LABELS
test1-8ndsl   NotReady  <none> 10m  v1.31.0  my-prefix/rack=xyz-123,test.foobar.io/group=abc
```

Label sync controller removes the labels with defined prefixes if same label
does not exist in BMH. Similarly, if we delete the label which exists in BMH
from Node it will be re-added at the next reconciliation cycle.
