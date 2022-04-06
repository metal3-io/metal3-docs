# Ironic

[Ironic](https://ironicbaremetal.org/) is an opensource collection of services
developed in [Python](https://www.python.org/) that help automating the
provisioning and managing of bare metal machines.
Born as the Bare Metal As A Service element of the
[OpenStack](https://www.openstack.org/)
cloud software suite, keeping the role as one of its core components, it has
evolved to become a semi-autonomous project, adding ways to be deployed
independently as a standalone service, for example using
[Bifrost](https://docs.openstack.org/bifrost/latest/), and integrates in other
tools and projects, as in the case of [Metal3](https://metal3.io/).
Tailored on the analysis of many end-users cases, Ironic nowadays supports the
two main standard hardware management interfaces,
[Redfish](https://www.dmtf.org/standards/redfish) and
[IPMI](https://en.wikipedia.org/wiki/Intelligent_Platform_Management_Interface),
and thanks to its large community of contributors, it can provide native support
for many different bare metal hardware brands, such as Dell, Fujitsu, HP, and
Supermicro.

## Why Ironic in Metal3

Ironic is opensource! This aligns perfectly with the philosophy behind Metal3.
Ironic has a vendor agnostic interface provided by a robust set of RESTful APIs.
The features included in its APIs fit exactly what's needed by the Metal3 project,
from bare metal "nodes" auto-registration and hardware specifications retrieval
of newly discovered bare metal machines, configuration and provisioning with
custom operating system images, up to machines reset, cleaning for re-provisionionig
or end-of-life retirement.

## How Metal3 uses Ironic

The Metal3 project adopted Ironic as the hidden engine that operates to manage
bare metal hosts behind native Kubernetes API.
It makes use of a [Bare Metal Operator](https://github.com/metal3-io/baremetal-operator)
as the main component that interfaces with the Ironic APIs for the essential
operations needed to provision bare metal hosts, such as hardware capabilites
inspection, operating system installation, and re-initialization when needed to
restore the bare metal machine to its original status.

## References

- [Ironic Project Website](https://ironicbaremetal.org/)
- [Ironic Documentation](https://docs.openstack.org/ironic/latest/)
- [Ironic Opendev Source Repository](https://opendev.org/openstack/ironic/)
