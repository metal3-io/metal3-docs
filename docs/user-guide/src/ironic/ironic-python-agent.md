# Ironic Python Agent (IPA)

[IPA](https://docs.openstack.org/ironic-python-agent/latest/) is a service written in python that runs within a ramdisk. It provides remote access to `ironic` and `ironic-inspector` services to perform various operations on the managed server. It also sends information about the server to `Ironic`.

By default, we pull IPA images from [Ironic upstream](https://tarballs.opendev.org/openstack/ironic-python-agent/dib) archive where an image is built on every commit to the *master* git branch.

However, another remote registry or a local IPA archive can be specified. [ipa-downloader](https://github.com/metal3-io/ironic-ipa-downloader) is responsible for downloading the IPA ramdisk image to a shared volume from where the nodes are able to retrieve it.

## Data flow

IPA interacts with other components. The information exchanged and the component to which it is sent to or received from are described below.
The communication between IPA and these components can be encrypted in-transit with SSL/TLS.

- Heartbeat: periodic message informing Ironic that the node is still running.
- Lookup: data sent to Ironic that helps it determine Ironic’s node UUID for the node.
- Introspection: data about hardware details, such as CPU, disk, RAM and network interfaces.

The above data is sent/received as follows.

- Lookup/heartbeats data is sent to Ironic.
- Introspection result is sent to ironic-inspector.
- User supplied boot image that will be written to the node’s disk is retrieved from HTTPD server

## References

- [IPA Documentation](https://docs.openstack.org/ironic-python-agent/latest/admin/how_it_works.html)
- [IPA github repo](https://opendev.org/openstack/ironic-python-agent)
