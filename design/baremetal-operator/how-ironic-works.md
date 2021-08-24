<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# how-ironic-works

This document explains how to use ironic in order to achieve various
tasks such as creating a node, recreating a node, unprovisioning a
node, and deleting a node.

This is not intended to be design specific documentation, but intends
to help convey the mechanics of how, such that the reader does not
have to become an expert in Ironic in order to learn to leverage it.

## How ironic controls hardware

Ironic is largely designed around the ability to issue commands to a
remote Baseboard Management Controller (BMC) in order to control the
desired next boot device and the system power state.

Without BMC functionality, the power and potential boot mode changes
need to be performed by an external entity such as a human or a
network attached power distribution unit.

## How ironic boots hardware

Typically nodes are booted utilizing PXE. In the most ideal scenario this
would be a hybrid PXE/iPXE configuration such that the deployment ramdisk
for ironic is able to be quickly and efficently transferred to the
node.

In order to assert this configuration at boot time, a dedicated DHCP server
on a semi-dedicated "provisioning" network should be leveraged. This network
may be reused by other services and systems, but can also be leveraged in
the case of hardware discovery. The most important factor is that this
network does not have a second DHCP server attached.

In the use case in which Ironic was developed, it would manage the DHCP
server configuration. In this use case, we would rely upon a static
configuration being provided by the DHCP server to signal where to find
the initial components required to boot the ramdisk.

Some specific hardware types in ironic do support use of virtual media
to boot the deployment ramdisk, however this functionality is not
available with the vendor neutral IPMI driver. Newer protocols such as Redfish
may support virtual media, but not as of the time of this document
having been composed. Virtual media should be considered
not well enough supported at this time to be considered useful.
Other methods such as booting directly from iSCSI should be considered
out-of-scope in this use case as they are require an external block
storage management system.

## How ironic writes an operating system image to baremetal

Ironic supports two fundamental types of disk images: whole-disk and
partition (or filesystem) images. The Metal3 use cases will rely on
whole disk images.

The basic workflow consists of:

1. Booting the deployment ramdisk
2. The deployment ramdisk checks in with the ironic introspection
   service which updates configuration information stored in ironic
   about the baremetal machine.
3. The deployment ramdisk checks in with the ironic service and leverages
   the MAC addresses to help identify the physical machine in the hardware
   inventory.
4. Ironic initiates deployment by first identifying the root disk upon
   which the disk image is to be written. By default this will be the
   smallest storage device available, and can be overridden via explict
   configuration of a [root_device hint](https://docs.openstack.org/ironic/latest/install/advanced.html#specifying-the-disk-for-deployment-root-device-hints)
5. The deployment ramdisk downloads the image to be written and streams
   that to the storage device.
6. If defined as part of the deployment, ironic will add an additional
   partition for a configuration drive. Ironic will then write the
   configuraiton drive to disk
7. Finally ironic reboots the machine.

There are some additional steps that ironic performs, mainly fixing
partition table data with GPT based partition tables in order to
prevent issues after deployment, but these steps are incorporated
as part of the deployment sequence to help ensure that the machine
will deploy successfully without issues.

## What connectivity is required

Access to the BMC can be via a routed IP network, however this may be
less desirable than having it on the same L2 network as Ironic from a
security standpoint.

When virtual media is used, the BMC needs to be on a network that
allows it to reach the host serving the virtual media image.

To boot the discovery and deployment image on the node, it will need
access to the ironic host using:

- DHCP (for IP assignment and PXE instructions)
- TFTP (if iPXE is not natively supported by the network interfaces.)
- HTTP in order to download kernel/ramdisk images via HTTP over a TCP
  connection.

Connections from the ramdisk are to the host upon which ironic is
executing.

The discovery and deployment ramdisk image needs to be able to:

- DHCP (via the ironic host, for IP assignment and PXE instructions)
- Resolve DNS (FIXME - also via the ironic host?)
- Connect to the ironic inspector API endpoint, which operates
  on port 5050/TCP by default.
- Connect to the ironic API endpoint, which operates on port
  6385/TCP by default.
- The ramdisk needs to be able to reach an external
  HTTP(s) endpoint in order to download the image files for
  deployment.
- Be accessible on port 9999/TCP. This is used by ironic to issue
  commands to the running ramdisk.

Between ironic and ironic-inspector:

- Each service must be able to reach the API endpoint for
  the other service.

## What is ironic-inspector

Ironic-inspector is an auxiliary service that provides separate API to
inspect and register hardware properties for a bare metal node (node
introspection process).
Ideally the node UUID must be already known by ironic, that means the node
is enrolled and power management credentials should be already provided to
allow sending reboot commands to the node, but this process may also be
triggered during discovery and allow automatic node registration in ironic.
The process of "hardware introspection" allows also to get the hardware
parameters from a bare metal node and ready it for scheduling.

Start, abort introspection, get introspection status, get introspection data
are done through the `/v1/introspection` resource.

To start the introspection process using ironic-inspector API send a POST
request with an empty body using:

```http
    POST /v1/introspection/node-id
```

The normal response code is 202 and if inspector can't find the node it will
return a 404.
The response is also an empty body.

It's possible to monitor the status of a single introspection process using:

```http
    GET /v1/introspection/node-id
```

This provides not only the state of the process, but also information on
start and ending time, and more.
An example of status answer:

    {
      "error": null,
      "finished": true,
      "finished_at": "2017-08-16T12:24:30",
      "links": [
        {
          "href": "http://127.0.0.1:5050/v1/introspection/c244557e-899f-46fa-a1ff-5b2c6718616b",
          "rel": "self"
        }
      ],
      "started_at": "2017-08-16T12:22:01",
      "state": "finished",
      "uuid": "c244557e-899f-46fa-a1ff-5b2c6718616b"
    }

There can be multiple introspection processes running at the same time, it's
possible to retrieve all the statuses using:

```http
    GET /v1/introspection
```

The output will be a paginated list of single status as shown above.

If it's needed, it's possible to interrupt the introspection process using:

```http
    POST /v1/introspection/node-id/abort
```

At the end of the introspection process, to return all the data stored for a
single node:

```http
    GET /v1/introspection/node-id/data
```

The result will be a json body which content may vary based on the ramdisk
used and the version of ironic-inspector itself.

## How-to

### How to discover hardware

New hardware can be discovered by booting the deployment and discovery
ramdisk with the "ipa-inspection-callback-url" kernel parameter. This URL
is used by the agent on the deployment and discovery ramdisk as the location
of the ironic-inspector service where it will post hardware profile
information to.

The ironic-inspector service then processes this data, and updates stored data
or creates a new node and associated supporting records in ironic.

### How to add hardware to ironic

The action of creating a node is part of the enrollment process and
the first step to prepare a node to reach the "available" status
At the end of the creation, the node status will be "enroll".

All nodes must be created with a valid hardware type, or "driver".
Valid and maintained in-tree hardware types, or drivers, as of
ironic 12.0.0 is: idrac, ilo, ipmi, irmc, redfish, snmp, and xclarity.

Usually more info are provided, at least a node name and parameters to
initialize the drivers, such as username and password, if needed, passed
through the “driver_info” option.

An example of a typical node create request in JSON format:

    {
    "name": "test_node_dynamic",
    "driver": "ipmi",
    "driver_info": {
        "ipmi_username": "ADMIN",
        "ipmi_password": "password"
    },
    "power_interface": "ipmitool"
    }

The response, if successful, contains a complete record of the node in JSON
format with provided or default ({}, “null”, or “”) values.

## Updating information about a hardware node in ironic

All node information can be updated after the node has been created.

Send a PATCH to `/v1/nodes/node-id` in the form of a JSON PATCH document.

The normal response is a 200 and contains a complete record of the node in
JSON format with the updated node.

### How do I identify the current state

All nodes in ironic are tied to a state which allows ironic to track what
actions can be performed upon the node and convey its general disposition.
This field is the "provision_state" field that can be retrieved via the API.

    GET /v1/nodes/node-id

Inside the returned document, a "provision_state" field can be referenced.
Further information can be found in ironic's
[state machine documentation](https://docs.openstack.org/ironic/latest/contributor/states.html).

### How to inspect hardware

Inspection may be used if a baremetal node has not been already discovered
or inspected previously in order to collect up to date details about the
hardware. This is particullarly important in order to update the records
of networking ports for identification of the baremetal node and creation
of PXE/iPXE configuration files in order to help ensure that baremetal node
is quickly booted for booting into the deployment and discovery ramdisk.

    PUT /v1/nodes/node-id/provision/states
    {"target": "inspect"}

This operation can only be performed in the "manageable" ironic node state.
If the node is already in the "available" state, the same requst can be used
with a target of "manage", and then the target of "inspect" can be utilized
to step through the state machine.

After inspection, it is advisable to return nodes to an "available" state.
This can be performed simillarly via the target "provide".

### How to deploy

Starting with the bare metal node in the "available" provision_state:

1. First assert configuration to API to indicate the image written
   to disk. This is performed as a HTTP PATCH request to the
   `/v1/nodes/node-id` endpoint.

       {
       {“op”: “replace”, “path”: “/instance_info”, “value”: {
           “image_source”: “http://url-to-image”,
           “image_os_hash_algo”: “sha256”,
           “image_os_hash_value”: “abcdefghi…”}},
       {“op”: “replace”, “path”: “/instance_uuid”, “value”: “anyuuidvalue”}},
       }

   **NOTE:** Instead of defining the "image_os_hash_*" values, a MD5 based
   image checksum can be set.

   This configuration does two things. First sets the image and checksum
   to be utilized for image verification, and sets an "instance_uuid" value
   which acts as a signal to any client that the node has been claimed by
   an API cient. The instance_uuid can be set to any value, and is
   ultimately not required.

2. Request ironic to perform a "validate" operation on the information
   it is presently configured with. The expected response is a HTTP 200
   return code, with a message body that consists of a list of "driver"
   interfaces and any errors if applicable.

       GET /v1/nodes/node-id/validate

   Reply:

       {
       "boot": true,
       ..
       "deploy": "configuration error message if applicable"
       }

   The particular interfaces that would be important to pay attention to are
   ‘boot’, ‘deploy’, ‘power’, ‘management’.

   More information can be found in the [API documentation](https://developer.openstack.org/api-ref/baremetal/?expanded=validate-node-detail).

3. Craft a configuration drive file

   Configuration drives are files that contain a small ISO9660 filesystem
   which contains configuration metadata and user defined "user-data".

   1) Create a folder called “TEMPDIR”
   2) In the case of ignition based configuration, that file would be
      renamed "user_data" and placed in `TEMPDIR/openstack/latest/`
      folder.
   3) Metadata for networking configuration setup using "cloud-init" or
      a similar application would also be written to the
      `TEMPDIR/openstack/latest` as well. This is out of scope, but is well
      documented in the OpenStack community.
   4) Create an iso9660 image containing the contents of TEMPDIR using
      a label of “config-2”.
   5) Compress the resulting ISO9660 image file using the gzip
      algorithm.
   6) Encode the resulting gzip compressed image file in base64 for
      storage and transport. Ironic does the needful to decode and uncompress
      the configuration drive prior to deployment.

4. Send a HTTP POST to `/v1/nodes/node-id/states/provision` to initiate
   the deployment

       {“target”: “active”,
        “configdrive”: “http://url-to-config-drive/node.iso.gz”}

   Once the request to make the node active has been received by ironic,
   it will proceed with the deployment process and execute the required
   steps to help ensure the baremetal node reboots into the requested
   disk image.

5. Monitor the provisioning operation by [fetching the machine
   state](#how-do-i-identify-the-current-state) periodically, looking
   for it to be set to `active`.

   The "provision_state" field will track the state of the node along
   the state machine. A provision_state field with "active" means the
   deployment has been completed.

   As the deployment is progressing, the "provision_state" may
   alternate between "deploying" and "deploy wait" states. Deploying
   indicates that the ironic server is actively working on the
   deployment, where as "deploy wait" indicates that ironic is waiting
   for the agent on the baremetal node to boot, write contents to
   disk, or complete any other outstanding task issued by Ironic.

   A "deploy failed" state indicates that the deployment failed, and
   additional details as to why can be retrieved from the "last_error"
   fiend in the JSON document. With newer versions of ironic, greater
   granularity can be observed by also refering the "deploy_step"
   field, however this is a relatively new feature in ironic and the
   information provided is fairly broad as of the time this document
   was written.

### How to unprovision a baremetal node

A provisioned, or "active" baremetal node can be unprovisioned by sending
a state change request to the ironic api. This request will move the
baremetal node through the "cleaning" process which ironic utilizes to
erase the contents of the disks. This can be a time intensive process,
and ultimately may only be useful for cleaning metadata except in limited
circumstances.

    PUT /v1/nodes/node-id/states/provision
    {"target": "deleted"}

### How to delete a baremetal node

Deletion of a node in ironic is removal from its inventory.

As ironic is designed to manage the lifecycle of baremetal nodes, protections
exist to prevent users of the ironic API from deleting nodes in states that
may not be ideal. Mainly this restricts deletion to states where the node
is not in use or is not actively performing a task.

Safe states are:

- "available"
- "manageable"
- "enroll"
- "adopt fail"

This may be overridden by putting the node into "maintenance", during
which ironic will not attempt to perform any operations.

```http
    PUT /v1/nodes/node-id/maintenance
    DELETE /v1/nodes/node-id
```

**NOTE:** Care should be taken to avoid triggering the deletion of a node in
a "clean*" states.

Additional information on states and state transitions in ironic can
be found [in the ironic documentation](https://docs.openstack.org/ironic/latest/contributor/states.html)

### How to create the record of an active node

Ironic possesses the functionality to create a node and move it into
an "active" state from the "manageable" state. This is useful to create
the record of an "active" node without performing a deployment.

Details on this functionality can be found in the [ironic adoption
documentation](https://docs.openstack.org/ironic/latest/admin/adoption.html)

## References

- [Ironic Documentation](https://docs.openstack.org/ironic/latest/)
