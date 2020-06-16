# BareMetalHost v1alpha2 API Changes

## Status

provisional

## Summary

We need to continue the API version migration for the `BareMetalHost`
resource type to complete the work described in
<https://github.com/metal3-io/baremetal-operator/issues/434>. The fix
would be a relatively small API change, but the effect of that
backwards-incompatible change is larger than anticipated. Therefore, I
propose that we wait and include the change along with other, more
significant, reworking of the API so that we don't take on the extra
work multiple times.

## Motivation

The `baremetal-operator` repository still relies on a vendored copy of
the `operator-sdk` project because the `BareMetalHost` CRD includes a
field with type `float`, which is not formally supported by either
`operator-sdk` or `kubebuilder`. Changing the field type will require
a backwards-incompatible API change, so we need to change our API
version and support upgrading existing users.

The mechanism for handling API upgrades in kubernetes is a "conversion
webhook". The kubebuilder project supports generating the scaffolding
for the REST API for the conversion for `go` types that support the
`Conversion` interface. The `baremetal-operator` uses the
`operator-sdk` project, which does not yet have this
feature. Therefore, part of the process of upgrading the API will also
require us to convert to kubebuilder.

We have also discussed [future API
evolution](https://groups.google.com/d/msg/metal3-dev/QfMJpyG0Zss/5gdmRbm6CAAJ)
that would be more significant than changing the type of one field. Those
changes will also be backwards-incompatible and require effort to
upgrade. By combining the incremental change and the more significant
change we can avoid doing the upgrade work multiple times.

### Goals

- Implement an API version update to `v1alpha2` for the
  `BareMetalHost` CRD.
- Clean up a few issues with the `BareMetalHost` API for which the
  fixes are not backwards-compatible.
- Anticipate other more significant changes to the API.
- Support in-place upgrades of existing `BareMetalHost` resources.

### Non-Goals

- Describe a stable `v1` API.

## Proposal

### User Stories

#### Story 1

As a cluster administrator, I want to update the version of metal3 in
my existing cluster without losing any data or features.

## Design Details

### Choosing a New Type for the Clock Speed Field

Our problematic field holds the clock speed of a CPU in fractional
megahertz. We assume the fractional portion is noise, so we could
truncate the value without losing any information.

We have three options for the new type. The advice from the
`controller-tools` maintainers is to use `resource.Quantity` or
`int32` for floating point values. We receive the value from
gophercloud as a string, so we could also simply pass the string
through unmodified.

The `Quantity` type adds extra characters representing the unit
conversion, so that a `1 GHz` value would be expressed as `1Gi`, which
would be a bit ugly for someone trying to consume the value without
access to the `go` library for parsing the string.

The CPU speed is simply being reported, and not used by the
`baremetal-operator` code. We could, therefore, use a `string` field
without losing any functionality. The value we get from `gophercloud`
is already a string.

Since the fractional portion of the speed can be dropped, we can use
an `int32` to hold the value. An integer value will make it easier for
the `hardware-classification-controller` to continue to use the value
when applying rules.

The best approach is to use an `int32` field.

### Converting Existing Data

It is possible to [use a web
hook](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definition-versioning/#configure-customresourcedefinition-to-use-conversion-webhooks)
to convert resources from their storage format to a specific API
format. We do not want users to continue to consume the `v1alpha1`
format, however, because we want to be able to drop support
quickly. Therefore, we should not write a conversion web hook.

Instead, we should add startup code to the baremetal-operator to read
all host resources in their current format and write them (with type
conversion but no other changes) to the new storage format. See option
2
[here](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definition-versioning/#upgrade-existing-objects-to-a-new-stored-version)
for more discussion.

### Dropping Hardware Profile Field

Now that we have support for more verbose root device hints and we
have the `hardware-classification-controller`, we no longer need the
hardware profile fields. We can remove them as part of the
backwards-incompatible changes as we move to the new API version.

### Converting to Kubebuilder

The `baremetal-operator` was built with the `operator-sdk`, which is
actively developed and maintained but has fewer features than the
alternative, `kubebuilder`, including especially the ability to
generate the scaffolding for the conversion webhooks for API changes.

`kubebuilder` is also built on the same code generator project as
`operator-sdk`, and enforces the same limitation on the use of `float`
type for fields. In order to support the same `v1alpha1` API, we will
need to apply the same work-around in a forked copy of the tool.

It is possible, but not trivial, to convert between the two tools. The
expectations are different for code layout, CRD naming, build tools,
and other aspects. Moving the `baremetal-operator` to `kubebuilder`
will introduce inherent compatibility issues in the results.

The `BareMetalHost` CRD as defined today has the group `"metal3.io"`,
so that its full name is `baremetalhost.metal3.io`. Kubebuilder
expects the domain and group portion of a CRD to be different, so it
wants an additional value as a prefix to `"metal3.io"` (for example,
`"hardware.metal3.io"`). We could work around this by modifying the
output generated by the tool, but working against the intent of the
tools is how we ended up in a situation where we need to fix the API,
so we should avoid doing that again.

Given that we're going to end up with the resource renamed anyway, it
makes sense to consider the more significant API changes proposed to
the API on the mailing list. The specific changes to make will be
addressed by a separate proposal.

### Risks and Mitigations

We do not know all of the ways that consumers of the API are using the
CPU speed values currently being reported. Given that most kubernetes
tools appear to assume that floating point types are not to be used in
APIs, it is likely that most consumers are either ignoring the value
or using it in simple ways (displaying it, logging it, etc.) where
loss of precision from the type conversion to a float is not
significant.

### Work Items

#### Phase I

- Release baremetal-operator version 0.1.0 with existing API.

#### Phase II -- Kubebuilder conversion

- Replace the `operator-sdk` project with a `kubebuilder` project in
  the same git repository.
- Use new resource group, kind, and version values for `BareMetalHost`
  (details to be determined later).
- Change the `ClockSpeed` type to `int32` in v1alpha2.
- Remove hardware profile from spec and status.
  - remove fields
  - Remove the state machine states for setting the hardware profile.
- Write logic to read the old `baremetalhost.metal3.io` and rewrite
  them as `baremetalhost.hardware.metal3.io` (or whatever name we
  choose). This could be used in an offline tool run as part of a
  cluster upgrade, or included in an operator used for managing a
  metal3 deployment.
- Update `cluster-api-provider-metal3` and
  `hardware-classification-controller` to use the new API and release
  them.

#### Phase III -- More significant API changes

- Add additional types (to be determined later) and the relevant
  controllers to `baremetal-operator` repo.
- Write logic to convert the data, to be run during an upgrade or
  included in an operator for managing a metal3 deployment.
- Update `cluster-api-provider-metal3` and
  `hardware-classification-controller` to use the new API and release
  them.

### Dependencies

The prerequisite work was done as part of
[#434](https://github.com/metal3-io/baremetal-operator/issues/434).

### Test Plan

- Test updating the `baremetal-operator` on an existing cluster with
  `v1alpha1` host resources.
- Unit tests, etc.

### Upgrade / Downgrade Strategy

This approach supports upgrading, but not downgrading.

### Version Skew Strategy

If we are unable to guarantee updating the host CRD in a cluster as
part of updating the `cluster-api-provider-metal3`, then we may need a
version of CAPM3 that understands both types of resources and changes
behavior based on which is installed.

## Drawbacks

None of the approaches described here are ideal. Most involve updating
incrementally over multiple releases, and potential issues for users.

## Alternatives

### Change Type in Place, Retain v1alpha1

The API version for `BareMetalHost` is `v1alpha1`. Upstream in metal3,
we could reasonably say that the way to fix the problem with the CPU
speed field is to change the type of the field and that no backwards
compatibility or upgrade support is provided. Fixing the type in place
allows the `operator-sdk` tools to work properly again.

Any existing users would be broken by the type change, because
existing data could no longer be deserialized from storage properly.

Downstream, because several of us have shipped the API to customers,
we cannot allow the break. We might as well do the conversion work
upstream to make maintenance simpler for everyone.

### Remove Field, Retain v1alpha1

We could remove the problematic field entirely.

Removing the old field with the bad type would allow the
`operator-sdk` tools to work properly again.

The content of the field in existing CRs would be lost. It’s a status
field, so the impact of the loss would be minimal. It would however
break downstream tools like GUIs, which is not ideal.

### Rename and Change Type, Retain v1alpha1

We could add a new field to replace the old field, using a different
name and correct type and continue to use the v1alpha1 version.

The API won't call conversion web hooks for an object accessed with
the same version as its storage version.

As in the case of simply removing the field, the content of the field
in existing CRs would be lost. It's a status field, so the impact of
the loss would be minimal but would break downstream GUIs.  Any nodes
deployed with the new CRD definition would report the data correctly.

### Change Type, Switch to New API Version

Under most circumstances, the most natural thing to do when changing
the API would be to increment the version number and provide converter
web hooks. Updating to `v1alpha2` or `v1beta1` would require maintaining
the current v1alpha1 types to support the conversion tools. In this
case, the API needs to be changed because the tools for managing the
code break with the current code base. That makes retaining the old
API version with the current type harder.

We could hack around the problem in `operator-sdk` by changing the
type in our code temporarily, so we could generate the new CRD
definition, then changing the type back and editing the generated
files to make them conform with reality. That would not solve the
problem long-term, and would not allow us to enable automated tests
for the CRD generation to prevent this issue from recurring.

Dropping the `v1alpha1` version from the code base entirely would
finally allow us to resume using the CRD validation tools.

### Fork operator-sdk Indefinitely

We have worked around the issue temporarily by forking the version of
kubebuilder in `operator-sdk` to bypass the error. We could make the
fork permanent, and continue to carry the `operator-sdk` code in our
repository.

This would make updating to newer versions of `operator-sdk`
difficult. We could update the code and apply our patch, but without
support upstream that will become harder over time and will be extra
work for us. That extra effort will likely lead to using a stale
version of `operator-sdk` instead of staying current.

### Build webhooks by hand

Since the `operator-sdk` does not support webhook scaffolding, we
could build them by hand. This is not appealing, because it could be
tricky to get right and would not take advantage of any of the
framework code. If the `operator-sdk` does eventually gain the ability
to manage webhooks, the manually managed code would not be likely to
be compatible with the auto-generated code.

### Fresh git Repository

Instead of replacing the code in the existing `baremetal-operator` we
could start a fresh `kubebuilder` project in a new repository. This
would mean losing all of the git history for the code we already have.

## References

- [original problem report](https://github.com/metal3-io/baremetal-operator/issues/434)
- [Future API evolution mailing list thread](https://groups.google.com/d/msg/metal3-dev/QfMJpyG0Zss/5gdmRbm6CAAJ)
- [controller-tools feature request for float support](https://github.com/kubernetes-sigs/controller-tools/issues/245)
- [resource.Quantity type](https://godoc.org/k8s.io/apimachinery/pkg/api/resource#Quantity)
- [Versions in CustomResourceDefinitions](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definition-versioning/)
- [Upgrade existing objects to a new stored version](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definition-versioning/#upgrade-existing-objects-to-a-new-stored-version)
