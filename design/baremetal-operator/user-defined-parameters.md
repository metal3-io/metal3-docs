<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Add Support for User-defined Parameters

## Status

provisional

## Summary

Add an optional field `extraParametersName` to accept a `Secret` object
where to allow user to set vendor specific configuration.

## Motivation

When deploying BM nodes, some vendor's BMC will require additional parameters
to adapt to certain situations. For example:

1. When FIPS mode is enabled on the host running the ironic service, the
   version of SNMP protocol of iRMC driver must be v3. Therefore, additional
   parameters are needed to specify the version and to provide the corresponding
   credential information.
2. With some BMC firmware upgrades, additional configuration may be required.
   E.g.: For iRMC firmware version >= `iRMC S6 2.00`, we need to additionally
   provide driver info such as:
    - **redifsh_address**: iRMC IP address or hostname.
    - **redfish_username**: iRMC user name with administrative privileges.
    - **redfish_password**: password of redfish_username.
    - **redfish_verify_ca**: accepts values those accepted in irmc_verify_ca.
3. For the production environment, it may be necessary to use a certificate
   issued by a third-party CA for verification, so additional parameters are
   required to specify the root certificate, e.g.: `irmc_verify_ca=<cert_path.crt>`.

Considering that the user-defined parameters may contain credential information,
`Secret` object would be an appropriate carrier for usage.

To sum up, without changing the existing APIs, adding support for extra
user-defined parameters will bring more freedom to meet the specific
configuration requirements for some vendors' BM.

### Goals

- Add an optional field `extraParametersName` in BMH to allow specify a
  `Secret` object.
- Users can define arbitrary parameters in the `Secret`.
- The parameters can be passed to ironic's driver_info.

### Non-Goals

- User-defined parameters can override the BMC parameters that set by existing
  APIs.
- Verify that user-defined parameters are valid.

## Proposal

### User Stories

#### Story 1

As a cluster administrator, I would like to build an OpenShift cluster with
FIPS mode using Fujitsu PRIMERGY servers, but due to [the limitation of iRMC driver](https://github.com/openstack/ironic/blob/21.3.0/ironic/drivers/modules/irmc/common.py#L254-L257),
I need to set `irmc_snmp_version` to "v3" and provide related credential.

#### Story 2

As a cluster administrator, when deploying Fujitsu PRIMERGY servers with
firmware version >= `iRMC S6 2.00` using the iRMC driver, I need to provide
additional parameters due to the following [change](https://docs.openstack.org/ironic/latest/admin/drivers/irmc#node-configuration):

> Fujitsu server equipped with iRMC S6 2.00 or later version of firmware disables IPMI over LAN by default.
> However user may be able to enable IPMI via BMC settings. To handle this change, irmc hardware type first
> tries IPMI and, if IPMI operation fails, irmc hardware type uses Redfish API of Fujitsu server to provide
> Ironic functionalities. So if user deploys Fujitsu server with iRMC S6 2.00 or later, user needs to set
> Redfish related parameters in driver_info.

Note that so called "Redfish related parameters" above is for iRMC rather than Redfish driver.

## Design Details

### Implementation Details/Notes/Constraints

#### Add New Field

Add a new string type field in `spec.bmc.extraParametersName` for `BareMetalHost`
CRD to specify a `Secret` containing user-defined parameters.

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: worker-test-bmc-secret
type: Opaque
data:
  username: YWRtaW4=                                      # admin
  password: YWRtaW4=                                      # admin
---
apiVersion: v1
kind: Secret
metadata:
  name: worker-test-bmc-extra-parameters                  # the secret containing user-defined parameter
type: Opaque
data:
  irmc_snmp_auth_password: YXNkZjEyMzQ=                   # asdf1234
  irmc_snmp_priv_password: YXNkZjEyMzQ=                   # asdf1234
stringData:
  snmp_version: v3
  irmc_snmp_user: testuser
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: worker-test
spec:
  online: true
  bootMACAddress: <mac-address>
  bmc:
    address: <bmc-address>
    credentialsName: worker-test-bmc-secret
    extraParametersName: worker-test-bmc-extra-parameters # New field
```

### Risks and Mitigations

Since we cannot verify user-defined parameters, some unsupported or invalid parameters may be passed.

### Work Items

- Add a new field `ExtraParametersName`.
- Convert `ExtraParametersName` to `ExtraParameters`.
- Modify provisioner factory interface to accept extra parameters.
- Modify ironic provisioner to merge the extra parameters to driverinfo.
- Update the `ExtraParameters` to ironic when they change

### Dependencies

None

### Test Plan

- Unit tests
- Integration testing with iRMC hardware

### Upgrade / Downgrade Strategy

None

### Version Skew Strategy

None

## Drawbacks

- Due to the limitation of `Secret` object, the value of `ExtraParameter` can only
  be string type.
- This approach requires the user to consult the ironic documentation to determine
  which fields can be used.

## Alternatives

None

## References

[PoC](https://github.com/metal3-io/baremetal-operator/compare/main...Hellcatlk:baremetal-operator:extra-parameters)
