<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# BareMetalHost API v1beta1

## Status

One of: implementable

## Summary

This design proposes making certain backward incompatible changes to the
BareMetalHost API and publishing the result as version `v1beta1`.

## Motivation

The BareMetalHost API is currently stuck at `v1alpha1`. Meanwhile, several
incompatible changes are needed based on the recent development both in Metal3
itself and in Ironic.

For example, Ironic is planning a complete removal of MD5 support for
checksums.

### Goals

- Clean up issues in the BareMetalHost API that have accumulated during
  the usage of `v1alpha1`.

- Make the API version reflect the actual support status of the API (see
  [alternatives](#Alternatives) for details).

### Non-Goals

- Stabilize the BareMetalHost API completely (as `v1`).

## Proposal

Copy the current API types definition into a new package `v1beta1` with some
modifications.

## Design Details

The following addition should be done **before** the version is created:

- Add a `Spec.Architecture` field to override architecture in the profile.
  If not provided, BMO will use its own architecture as the default.

- Prepare `HardwareProfile` for deprecation:

  Add a new profile `empty` that does not have any fields populated. When this
  profile is used, do not set the fields on the Ironic node that are not
  overridden explicitly (via the `Architecture` and `RootDeviceHints`).

  Remove `RootGB` (only makes sense for partition images which we don't
  support) and `LocalGB` (optional and discovered by inspection).

- Prepare `Image.ChecksumType` for the default change:

  Add a new type `auto` that will tell Ironic to detect the checksum type
  itself (by not providing the `image_os_hash_algo` field).

- Ensure that a `HardwareData` CR exists for any host that has
  `HardwareDetails` in the status.

The following significant changes will be done to the new version:

- Check the default value of `Image.ChecksumType` from `md5` to `auto`.
  Mark the `md5` type as deprecated for removal before `v1`.

- Remove `HardwareProfile`, effectively using the `empty` profile in the
  new API version.

- Remove `HardwareDetails` from the `Status` in favour of the already
  introduced `HardwareData` CR.

The following cosmetic changes will be done to the new version:

- Rename `online` to `poweredOn`.

  The word *online* is ambiguous here: it may be understood to refer to
  provisioning status. Furthermore, the corresponding field in the `Status`
  is already called `poweredOn`.

- In `RootDeviceHints`:

  Rename `DeviceName` to `DevicePath` to better reflect what it actually is
  (especially after introducing support for `/dev/disk/by-path`).

  Rename `Model` and `Vendor` to `ModelContains` and `VendorContains` to
  reflect the fact that these fields use the `<in>` operator.

### Implementation Details/Notes/Constraints

Since the new API version will mostly involve removing or renaming fields,
the storage version will stay `v1alpha1` until this version is removed.
Similarly, the controller will also the old version to be able to handle
the fields not present in the new one (and to avoid constant conversion to
and from the storage version).

### Risks and Mitigations

None

### Work Items

- Refactor the BMO code to avoid referring directly to the current version.
- Add `Architecture` to the current version.
- Add `empty` hardware profile.
- Add `auto` checksum type.
- Copy type definitions and modify them.
- Create a conversion webhook to change between versions.
- Make a new BMO release and communicate the change to the community.

The old version will be phased out as follows:

- Create the last BMO branch with `v1alpha1` fully functional.

- Switch the storage and controller client versions to `v1beta1`. At this
  point, `v1alpha1` will still be generally functional, except for the features
  that are not part of `v1beta1`

- Create a migration script that reads `v1alpha1` resources and converts them
  to `v1beta1` ones. This is to ensure that each resource is written at least
  once with the new storage version.

- Create a new BMO release to get this change to the operators. Instruct them
  to run the migration script or migrate the objects themselves.

- Mark `v1alpha1` as no longer served in the CRD. At this point, deployments
  will not get it by default, but operators who are unable to upgrade, will
  still be able to re-enable it at their own risk.

I would like to aim for 3-6 months after `v1beta1` is first introduced. The
actual removal of `v1alpha1` from the code is an open question at this point.
Since everyone uses this version right now, we may keep it in the code for
a really long time.

### Dependencies

None

### Test Plan

We'll need to test both API versions. Since we already have tests for different
versions of CAPM3, we will tie them to different versions of BMH. For instance,
the current version of CAPM3 will switch to the new API version, while all
stable branches will keep using `v1alpha1`. We'll only need to add one of
such stable jobs to BMO.

### Upgrade / Downgrade Strategy

The conversion webhook will take care of in-flight CR upgrade.

On the path `v1alpha1` -> `v1beta1`:

- To allow a lossless reverse conversion, [marshal][marshal] the old resource.

- If `RootDeviceHints` is not set, populate it from the profile.

- Delete `HardwareProfile` and `HardwareDetails`.

- If `Image.ChecksumType` is empty, set it to `md5`.

- Rename any fields that were not deleted.

On the path `v1beta1` -> `v1alpha1`:

- If the conversion data is cached, [unmarshal][unmarshal] it.

- If `Image.ChecksumType` is empty, set it to `auto`.

- Rename any fields that were not deleted.

[marshal]: https://github.com/kubernetes-sigs/cluster-api/blob/c0744085e7eeae83e69dcc97c95fba8572bf5788/util/conversion/conversion.go#L101
[unmarshal]: https://github.com/kubernetes-sigs/cluster-api/blob/c0744085e7eeae83e69dcc97c95fba8572bf5788/util/conversion/conversion.go#L122

### Version Skew Strategy

BMO and CAPM3 version skew may affect the `ChecksumType` handling. With older
CAPM3, users will be able to use `md5` as the type, but it will be removed
when converting to `v1beta1` for internal storage.

## Drawbacks

The changes are breaking.

## Alternatives

We could keep `HardwareProfile` and `HardwareDetails` forever, but we cannot
work around the MD5 removal in Ironic.

We could drop all support for MD5 in the new API version. This would be
a pretty serious breaking change with an unclear impact on the consumers.

We could create version `v1alpha2` first. My main objection to it is the
following: per [kubernetes API versioning guideline][api versioning],
alpha versions are potentially buggy and subject to significant future
changes, and as such are not suitable for production. Neither is the case
for the BareMetalHost API. So, while creating a `v1alpha2` could be useful
to get more feedback, we're also explicitly telling people to avoid this
version, which may prevent us from getting feedback.

[api versioning]: https://kubernetes.io/docs/reference/using-api/#api-versioning

## References
