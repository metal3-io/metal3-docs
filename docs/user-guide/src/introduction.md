<!-- markdownlint-disable first-line-h1 no-inline-html -->
<div style="float: right; position: relative; display: inline;">
    <img src="images/metal3-color.svg" width="160px" alt="" />
</div>
<!-- markdownlint-enable first-line-h1 no-inline-html -->

# Metal³

<!-- cSpell:ignore kubed -->

The Metal³ project (pronounced: "Metal Kubed") provides components for bare
metal host management with Kubernetes. You can enrol your bare metal machines,
provision operating system images, and then, if you like, deploy Kubernetes
clusters to them. From there, operating and upgrading your Kubernetes clusters
can be handled by Metal³. Moreover, Metal³ is itself a Kubernetes application,
so it runs on Kubernetes, and uses Kubernetes resources and APIs as its
interface.

Metal³ is one of the providers for the Kubernetes sub-project [Cluster
API](https://github.com/kubernetes-sigs/cluster-api). Cluster API provides
infrastructure agnostic Kubernetes lifecycle management, and Metal³ brings the
bare metal implementation.

This is paired with one of the components from the OpenStack ecosystem,
[Ironic](https://ironicbaremetal.org/) for booting and installing machines.
Metal³ handles the installation of Ironic as a standalone component (there's no
need to bring along the rest of OpenStack). Ironic is supported by a mature
community of hardware vendors and supports a wide range of bare metal
management protocols which are continuously tested on a variety of hardware.
Backed by Ironic, Metal³ can provision machines, no matter the brand of
hardware.

In summary, you can write Kubernetes manifests representing your hardware and
your desired Kubernetes cluster layout. Then Metal³ can:

* Discover your hardware inventory
* Configure BIOS and RAID settings on your hosts
* Optionally clean a host's disks as part of provisioning
* Install and boot an operating system image of your choice
* Deploy Kubernetes
* Upgrade Kubernetes or the operating system in your clusters with a
  non-disruptive rolling strategy
* Automatically remediate failed nodes by rebooting them and removing them from
  the cluster if necessary

You can even deploy Metal³ to your clusters so that they can manage other
clusters using Metal³...

Metal³ is [open-source](https://github.com/metal3-io) and welcomes community
contributions. The community meets at the following venues:

* \#cluster-api-baremetal on [Kubernetes Slack](https://communityinviter.com/apps/kubernetes/community)
* Metal³ development [mailing list](https://groups.google.com/g/metal3-dev)
* From the mailing list, you'll also be able to find the details of a weekly
  Zoom community call on Wednesdays at 14:00 GMT

# About this guide

This user guide aims to explain the Metal³ feature set, and provide how-tos for
using Metal³. It's not a tutorial (for that, see the [Getting Started
Guide](developer_environment/tryit.md)). Nor is it a reference (for that, see
the [API Reference
Documentation](https://github.com/metal3-io/cluster-api-provider-metal3/blob/main/docs/api.md),
and of course, the code itself.)
