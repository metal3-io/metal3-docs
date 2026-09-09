<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Pre-boot File Injection

## Status

provisional

## Summary

This proposal introduces a new feature to inject files into node OS during
provisioning before the OS starts. This would be implemented by default using
Ironic file injection deploy step. Unlike Cloud-init and other configuration
management systems (CMS), this feature would inject the files before booting,
which means that they are present earlier in the file system than injecting
with Cloud-init and other CMS. It enables adjusting the boot loader
configuration before first boot and user space init system configuration, e.g.
systemd unit boot order. Using Ironic feature would also be independent from
the chosen CMS.

## Motivation

Currently files can be injected into images using Configuration management
systems (CMS) (such as Cloud init and Ignition). This has few shortcomings:

- CMS injects files late in the OS boot process. If CMS fails, no files are
  injected even though the OS might boot up.
- It assumes that the image being provisioned has CMS installed.
- Different CMS have different configuration formats. Injecting files using
  Ironic would be CMS agnostic way.

The main disadvantage of CMS is injecting files late in the boot process. Being
able to inject files before the boot process begins gives more tools to users
to manage their installations and more visibility to the boot process. If the
OS boot or CMS fails, there is very little logs to inspect.

### Goals

- Provide CMS agnostic way to inject files into images before they are booted.
- Extend current custom resources to enable configuring which files are
  injected and where.

### Non-Goals

- Inject files into running OS
- Supporting non-Linux operating systems

## Proposal

A file to be injected will be saved into a secret. User can then specify a
files to be injected to a node by giving a list of file locations in the file
system and secrets. This list will be added to `BaremetalHost` resource.

### User Stories

#### Story 1

As cluster operator I want to get visibility to booting starting from as early
as possible. Cloud-init starts late in the boot process and might provide no
logs and access to the node if it fails before injecting SSH keys.

With pre-boot file injection I would inject a small logger to the file system
before booting which will monitor relevant targets to provide visibility to
early booting.

## Design Details

A new field `InjectFiles` in `BaremetalHost.Spec.Image` will be added. It
will contain `files` and `priority`. Priority is an integer between 41-79
(inclusive). The priority is 50 by default and it corresponds to the Ironic
deploy step priority. The priority is optional field.

Files is a list of items, and each item in the list contains

- A reference to a secret (`secretName`) containing the file contents. The
  secret must be in the same namespace as BMH (and PPI).
- A string field `URL` containing a link to the file to be injected.
- A string field `path` for absolute file system path. All missing directories
  are created.
- Integer fields `owner`, `group`, `mode`, `dirmode`.
- A boolean field `deleted`.
- A string field `partition`.

Item details:

- The secret will contain one key-value pair. The key is `content` and the value
  is the file contents. No checks for the file contents are made, it can be
  practically any data.
- If the `InjectFiles` field is absent or the list is empty, no files are
  injected.
- If the file contents are provided, file path is required and vice versa.
- Both `deleted` and `secretName` (file contents) cannot be provided at the same
  time.
- Content can be a base64 encoded string or an URL to the content (without
  base64 encoding).
- Partition can be provided in three different ways:
   - A number is treated as a partition index
   - A path is treated as a block device path
   - If missing, the ironic-python-agent will try to determine the partition.
     partition label.
- The priority will be validated to be in the correct range (41-79). 
- Path is always required. One of `URL`, `deleted`, and `secretName` is
  required. The rest of fields are optional.

Example:

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
spec:
  image:
    url: http://[2001:db8::1234]/image.qcow2
    format: qcow2
    injectFiles:
      files:
      - secretName: file-content-secret
        path: /etc/systemd/system/my-target.service
        owner: 1000
        group: 1000
        mode: 0644
        dirmode: 0755
        partition: "/dev/disk/by-uuid/e8bbbd38-c175-44f5-8001-6b39fdff2daa"
      - deleted: true
        path: /etc/systemd/system/my-second-target.service
        partition: "/dev/disk/by-uuid/e8bbbd38-c175-44f5-8001-6b39fdff2daa"
      - url: https://example.com/1234567890-0987654321
        path: /etc/systemd/system/my-target3.service
      priority: 70
```

### Implementation Details/Notes/Constraints

- It will require a corresponding interface in CAPM3, which end users can use.
- This can be transferred into `HostClaim` once they are implemented to ensure
  proper RBAC. However, if this is included into `HostClaim`, that will be
  discussed in a separate proposal.
- The default implementation will be done using [Ironic file injection deploy
  step](https://docs.openstack.org/ironic-python-agent/latest/admin/hardware_managers.html#injecting-files).
  No new dependencies are needed to implement this.
- The implementation also extends the `Provisioner` interface, and hence any
  compatible provisioner could provide the feature.
   - A setter function `SetFileInjections` will be added. It will set the files
     to be injected for the next deployment. The files to be injected must be
     set after each deployment. The file contents and file paths are handed to
     the provisioner through arguments.
   - The `Provisioner` interface will also be extended in such a way that BMO
     can find out whether the provisioner supports this feature or not. A
     function `SupportedFeatures` will be added. The function has no arguments.
     A supporting provisioner must include a constant in the return value of
     `SupportedFeatures` identified as `PreBootFileInjection`.
   - `SupportedFeatures` is a generic function which will serve a
     multi-provisioner model. It takes no arguments and returns a list of
     strings (or integers) which define which features are supported. Each
     provisioner can specify which features it supports through this.
   - The constant variable `PreBootFileInjection` can have either string value
     or integer value. The value itself is not relevant, as long as all the
     different features will have unique value. The constant will be public so
     that provisioners can return the set of variables that they support.
- There will be no hashes of the injected file (or checking hashes). That is
  out of the scope. The file is only delivered, not executed during delivery.
  The file contents are not checked in any way. The file might be executed or
  used by Systemd after the quest boots up, if the written file is binary or
  part of system configuration.
- LVM is not supported.
- Names are not supported for `owner` and `group`.
- No files can be injected with live-ISO. This is checked when validating the
  data. To specify the file injections, we require that the image field and
  image type are populated.
- Changing any field in `injectedFiles` or the secret content does not affect
  anything. The contents are checked and used when provisioning. In order to
  changes to take effect, the node needs to be provisioned again.
- If the user tries to inject files with a provisioner that does not support
  `PreBootFileInjection`, baremetal-operator will fail the deployment. A
  deployment failure event will be recorded. The user then needs to switch the
  provisioner or remove file injections.
- `mode` and `dirMode` are integer fields and they need to be prefixed with `0`
  or `0o` in order for yaml to interpret them as octal numbers. The mode can
  also be provided as decimal number, but the user should notice that it does
  not match octal representation.

### Risks and Mitigations

If implemented wrong, this could allow infrastructure operators to inject files
into nodes that are handed out to end users (cluster operators). This would
violate security boundaries.

End users could break their deployments by injecting wrong files. With greater
power comes greater responsibility.

File contents are passed to provisioner, and current implementation of Ironic dumps
them in logs at Info level in `DeployStep`.

### Work Items

### Dependencies

None

### Test Plan

A new E2E test will be added. This feature needs to be tested by provisioning
an image and checking that the injected file exists in the file system. There
is few tricky parts:

- Requires that provisioning succeeds
- Requires SSH connection to the node after provisioning. This can be tricky
  with IPv6 tests as assigning static IPv6 address requires usage of
  pre-provisioning network data. So successful PP network data is also
  required.
- These two requirements can make this test flaky.

### Upgrade / Downgrade Strategy

This proposal adds new feature and hence upgrading clusters will remain
backward compatible.

No new CRs is defined. When downgrading, the baremetal operator cannot inject
files anymore and the new fields in BMH would be ignored. Hence, no actions
required when downgrading.

### Version Skew Strategy

None

## Drawbacks

Most use cases can already be covered by Cloud-init (or Ignition) file
injection. Other CMS most likely have similar features. Hence this feature
would duplicate the same feature.

## Alternatives

### Own Custom Resource

The feature could be added by creating a new custom resources which would
manage the files to be injected. This approach would require an operator as
well. It would decouple specifying file injections from BMH resource and allow
finer security boundary between file injections and BMH resources.

However, the OS image is already specified in the BMH resource and file
injections are closely related to the specified image. Coupling the file
injections with the image is logical and separating them would not increase
security much, because both have effect on the provisioned file system.

### Including in PreProvisioningImage

Another option is to include the configuration into `PreprovisioningImage` CR.
It would be another logical place as the file injections are done by [Ironic
agent](https://docs.openstack.org/ironic-python-agent/) during deployment, after
writing the OS image and before booting it.

However, as the contents of `PreProvisioningImage` are copied From the BMH
resource, this might in practice require the same information to be in BMH as
well.

### Communication with Provisioner

This alternative is only limited to the provisioner interface changes. Instead
of adding `SetFileInjections` to the provisioner interface, we could add the
file injection data to the `ProvisionData` structure. When the operator issues
provisioning command to the provisioner, the file injection information would be
passed in the `ProvisionData` parameter instead of calling any functions.

## References

None
