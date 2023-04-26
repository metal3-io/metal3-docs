# Ironic

[Ironic](https://ironicbaremetal.org/) is an open-source service
for automating provisioning and lifecycle management of bare metal machines.
Born as the Bare Metal service of the [OpenStack](https://www.openstack.org/)
cloud software suite, it has evolved to become a semi-autonomous project,
adding ways to be deployed independently as a standalone service, for example
using [Bifrost](https://docs.openstack.org/bifrost/latest/), and integrates in
other tools and projects, as in the case of [Metal3](https://metal3.io/).

Ironic nowadays supports the two main standard hardware management interfaces,
[Redfish](https://www.dmtf.org/standards/redfish) and
[IPMI](https://en.wikipedia.org/wiki/Intelligent_Platform_Management_Interface),
and thanks to its large community of contributors, it can provide native
support for many different bare-metal hardware vendors, such as Dell, Fujitsu,
HPE, and Supermicro.

## Why Ironic in Metal3

- Ironic is open source! This aligns perfectly with the philosophy behind
  Metal3.
- Ironic has a vendor agnostic interface provided by a robust set of RESTful
  APIs.
- Ironic has a vibrant and diverse community, including small and large
  operators, hardware and software vendors.
- Ironic provides features covering the whole hardware life-cycle:
  from bare metal machine registration and hardware specifications
  retrieval of newly discovered bare metal machines, configuration and
  provisioning with custom operating system images, up to machines reset,
  cleaning for re-provisionionig or end-of-life retirement.

## How Metal3 uses Ironic

The Metal3 project adopted Ironic as the back-end that manages bare-metal hosts
behind native Kubernetes API.

[Bare Metal Operator](https://github.com/metal3-io/baremetal-operator)
is the main component that interfaces with the Ironic API for all
operations needed to provision bare-metal hosts, such as hardware capabilites
inspection, operating system installation, and re-initialization when
restoring a bare-metal machine to its original status.

## References

- [Ironic Project Website](https://ironicbaremetal.org/)
- [Ironic Documentation](https://docs.openstack.org/ironic/latest/)
- [Ironic Source Repository on OpenDev.org](https://opendev.org/openstack/ironic/)
