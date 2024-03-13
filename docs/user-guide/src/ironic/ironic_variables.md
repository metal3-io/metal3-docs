<!-- markdownlint-disable first-line-h1 -->

The following environmental variables can be passed to configure the Ironic services:

- `HTTP_PORT` - port used by httpd server (default 6180)
- `PROVISIONING_IP` - provisioning interface IP address to use for ironic, dnsmasq(dhcpd) and httpd (default 172.22.0.1)
- `CLUSTER_PROVISIONING_IP` - cluster provisioning interface IP address (default 172.22.0.2)
- `PROVISIONING_INTERFACE` - interface to use for ironic, dnsmasq(dhcpd) and httpd (default ironicendpoint)
- `CLUSTER_DHCP_RANGE` - dhcp range to use for provisioning (default 172.22.0.10-172.22.0.100)
- `DEPLOY_KERNEL_URL` - the URL of the kernel to deploy ironic-python-agent
- `DEPLOY_RAMDISK_URL` - the URL of the ramdisk to deploy ironic-python-agent
- `IRONIC_ENDPOINT` - the endpoint of the ironic
- `CACHEURL` - the URL of the cached images
- `IRONIC_FAST_TRACK` - whether to enable fast_track provisioning or not (default true)
- `IRONIC_KERNEL_PARAMS` - kernel parameters to pass to IPA (default console=ttyS0)
- `IRONIC_INSPECTOR_VLAN_INTERFACES` - VLAN interfaces included in introspection, all - all VLANs on all interfaces, using LLDP information (default), interface all VLANs on an interface, using LLDP information, interface.vlan - a particular VLAN interface, not using LLDP
- `IRONIC_BOOT_ISO_SOURCE` - where the boot iso image will be served from, possible values are: local (default), to download the image, prepare it and serve it
    from the conductor; http, to serve it directly from its HTTP URL
- `IPA_DOWNLOAD_ENABLED` - enables the use of the Ironic Python Agent Downloader container to download IPA archive (default true)
- `USE_LOCAL_IPA` - enables the use of locally supplied IPA archive. This condition is handled by BMO and this has effect only when `IPA_DOWNLOAD_ENABLED` is "false", otherwise `IPA_DOWNLOAD_ENABLED` takes precedence. (default false)
- `LOCAL_IPA_PATH` - this has effect only when `USE_LOCAL_IPA` is set to "true", points to the directory where the IPA archive is located. This variable is handled by BMO. The variable should contain an arbitrary path pointing to the directory that contains the ironic-python-agent.tar
- `GATEWAY_IP` - gateway IP address to use for ironic dnsmasq (dhcpd)
- `DNS_IP` - DNS IP address to use for ironic dnsmasq (dhcpd)

To know how to pass these variables, please see the sections below.
