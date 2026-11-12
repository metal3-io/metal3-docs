<!--
 This work is licensed under a Creative Commons Attribution 3.0
 Unported License.

 http://creativecommons.org/licenses/by/3.0/legalcode
-->

# Fetch IPA Ramdisk and Kernel from OCI Artifacts

## Status

provisional

## Summary

This proposal details a mechanism for enabling the `ironic-ipa-downloader`
to pull the Ironic Python Agent (IPA) kernel and ramdisk (initramfs) directly
from an OCI (Open Container Initiative) registry artifact. Instead of solely
relying on standard HTTP/HTTPS tarball downloads, the downloader will support
an `oci://` scheme in its base URI configuration. Under this scheme, the
downloader will fetch OCI Image Indexes or OCI Image Manifests, extract the
kernel, repackage the root filesystem layer(s) into a compressed
initramfs format, and place the resulting artifacts in the shared volume.
This integration allows users to unify their software and OS image
distribution pipelines, support secure and fully air-gapped environments,
and automatically resolve multi-architecture images.

## Motivation

Currently, `ironic-ipa-downloader` retrieves IPA images exclusively from HTTP
archives (by default, `tarballs.opendev.org`). While simple, this approach has
several key limitations in modern enterprise environments:

1. **Air-Gapped and Restricted Environments**: Many corporate and production
   Kubernetes environments completely disallow raw HTTP/HTTPS traffic to the
   external internet. These environments rely on internal, secured, and
   audited OCI registries (such as Quay, Harbor, or Artifactory) to store and
   distribute all software components, including operating system and
   provisioning images.
1. **Infrastructure Fragmentation**: Forcing operators to maintain both an OCI
   registry for container images and a separate HTTP server (or internal cache)
   for the IPA ramdisk tarballs adds administrative overhead and complexity.
1. **Security and Trust**: OCI registries offer robust access controls,
   vulnerability scanning, and cryptographic signing/verification capabilities
   (e.g., Cosign). Raw HTTP tarballs cannot be easily scanned or
   cryptographically verified at the registry level prior to pulling.
1. **Multi-Architecture Complexity**: Managing different CPU architectures
   (such as `x86_64` and `aarch64`) with URL-based tarballs requires complex
   URI templating and manual tracking of platform-specific paths. OCI Image
   Indexes solve this problem natively by allowing a single reference to
   resolve to the correct architecture-specific manifest.

### Goals

- Introduce OCI pulling support in `ironic-ipa-downloader` via the `oci://`
  scheme in `IPA_BASEURI`.
- Implement parsing of OCI Image Manifests (single architecture) and OCI
  Image Indexes (multi-architecture) to download the correct
  platform-specific files.
- Automate the extraction of the kernel (vmlinuz/Image/zImage) and the
  conversion/repackaging of the container layer into a compressed `zstd`
  initramfs.
- Implement an OCI-specific caching layer utilizing the OCI manifest
  SHA-256 digest to skip subsequent downloads if the artifact has not changed.
- Preserve full backward compatibility with the existing HTTP/HTTPS tarball
  download mechanism.

### Non-Goals

- Deprecating or removing the existing HTTP/HTTPS tarball download path.
- Restricting final implementation decisions to specific utilities like `oras`
  or `bsdtar`. While the Proof of Concept (PoC) uses these tools, alternative
  utilities or libraries can be chosen during development.
- Rewriting the entire downloader tool in Go or another language as a
  prerequisite. While a language-based rewrite is an open question that may
  be decided during the implementation phase (and could provide cleaner
  multi-layer image support), this proposal focuses on defining OCI support
  and does not mandate a full rewrite.
- Addressing transport-level security features (such as custom CA bundles) in
  this proposal. These transport capabilities are also missing from the
  existing HTTP(s) implementation and should be handled as a separate
  enhancement.
- Defining the pipeline or tooling used to build the OCI rootfs images; the
  downloader assumes a compliant single-layer OCI rootfs is provided.

## Proposal

We propose upgrading the `get-resource.sh` entrypoint of the
`ironic-ipa-downloader` image to detect when `IPA_BASEURI` starts with the
`oci://` scheme. When detected, the script will leverage an OCI client (such as
`oras` or equivalent libraries) to fetch and parse the OCI manifest or index.

The OCI image will typically pack the IPA root filesystem inside a single
tarball layer, with the kernel located inside `/usr/lib/modules/`. The
script will:

1. Fetch and parse the manifest or index JSON.
1. Filter by architecture to support multi-arch environments.
1. Download the rootfs layer.
1. Extract the kernel and repack the layer into a standard `newc` cpio
   archive, compressed to form a compliant `initramfs`.
1. Caching will be handled by mapping the SHA-256 digest of the manifest to a
   local directory path `/shared/html/images/${digest}`. If this path exists
   on the shared volume, the download is skipped entirely.

### User Stories

#### Story 1: Enterprise Air-Gapped Deployment

An enterprise operator wants to deploy Metal3 in an air-gapped environment.
They mirror all container images and the IPA ramdisk image (packaged as an
OCI artifact) into their internal Harbor registry. They configure
`IPA_BASEURI: oci://harbor.internal/metal3/ironic-python-agent:v1.0.0`. The
`ironic-ipa-downloader` successfully fetches, extracts, and serves the IPA
images locally using the mirrored OCI registry without needing external HTTP
internet access.

#### Story 2: Heterogeneous Hardware Management (Multi-Arch)

An operator manages a cluster consisting of both `x86_64` and `aarch64` bare
metal servers. They build a multi-architecture OCI image index for IPA and
push it to a registry. They set `IPA_BASEURI` to point to this index. The
downloader resolves the index, detects both architectures, fetches the
respective layers, and outputs both `ironic-python-agent_x86_64.kernel/
initramfs` and `ironic-python-agent_aarch64.kernel/initramfs` on the shared
volume, allowing Ironic to boot either type of server dynamically.

#### Story 3: Unified Community Distribution Channel

The Metal3 community wants to simplify release management, mirroring, and
artifact signing. By distributing the IPA ramdisk/kernel as OCI artifacts
in the same registry that hosts all other Metal3 container images (e.g.,
Quay.io), the
community and downstream users gain a single, unified location for all
distributed artifacts. This eliminates the need for maintaining separate HTTP
tarball mirrors, makes digital signing (e.g., using Cosign) uniform across
all components, and simplifies release bundle distribution.

## Design Details

### get-resource.sh Implementation

The script logic will branch depending on the schema of `IPA_BASEURI`:

```bash
if [[ "${IPA_BASEURI}" == oci://* ]]; then
  get_oci_tarball "${IPA_BASEURI#oci://}"
else
  # Legacy HTTP/HTTPS tarball downloading logic
  ...
fi
```

#### Manifest Fetching and Parsing

The script will fetch the registry manifest and process it conceptually as
follows:

1. **Manifest Type Determination**: The downloader inspects the `mediaType` of
   the manifest (or equivalent fallback fields) to determine if it is an
   Image Manifest (single architecture) or an Image Index (multi-architecture).
1. **Index Processing**: If an index is provided, the downloader parses the
   available architectures, fetches the matching sub-manifests, and processes
   them.
1. **Manifest Processing and Extraction**:
   - Calculates the SHA-256 digest of the manifest content as the cache key.
   - If `/shared/html/images/${digest}` exists, the download is skipped.
   - Extracts the architecture from the OCI config blob and normalizes it.
   - Fetches the layer blob. The implementation assumes a single-layer rootfs
     format.
   - Locates and extracts the kernel from the standard directory structure
     (typically containing `vmlinuz`, `Image`, or `zImage`).
   - Repacks the remaining files from the layer into a `newc` cpio archive
     and compresses it using `zstd` to construct the `initramfs`.
   - Symlinks the kernel and initramfs files to standard destination names
     with architecture suffixes.

Note: A Proof of Concept (PoC) used standard CLI tools like
`oras`, `jq`, and `bsdtar` to handle these steps. However, other client
utilities, libraries, or programming languages can be chosen during
development.

### Dockerfile Requirements

To support the OCI-fetching logic, the container image will need additional
tools installed. In the PoC, packages like `jq`, `libarchive` (providing
`bsdtar`), and `zstd` are installed, and `oras` is retrieved as a release
binary from GitHub. The exact set of dependencies is subject to change
depending on the choice of the OCI client or custom language runtime.

### Risks and Mitigations

1. **Increased Container Image Size**:
   - *Risk*: Adding OCI client tools and extraction utilities increases the
     overall footprint of the `ironic-ipa-downloader` image.
   - *Mitigation*: These binaries are very lightweight (under 50MB combined).
     The increase in image size is negligible compared to the size of the IPA
     images being downloaded (often >400MB), and the security and
     administrative gains far outweigh this footprint.

1. **Repackaging Performance & Resource Usage**:
   - *Risk*: Converting a large tar layer into a `newc` cpio archive and
     compressing it via `zstd` is a CPU-intensive operation.
   - *Mitigation*: This operation occurs exactly once per new image version
     pulled. The strong digest-based caching layer ensures that on container
     restarts, no extraction or compression occurs if the image digest is
     unchanged.

1. **Multi-layer OCI Images**:
   - *Risk*: The extraction logic assumes a single-layer rootfs layout
     (`.layers | length == 1`). Standard OCI images could contain multiple
     layers. This is done to avoid having to deal with whiteouts files and
     layers order in order to keep implementations simple.
   - *Mitigation*: Standard base OS and rootfs artifacts are distributed as
     single-layer tarballs or filesystem roots. We explicitly document this
     single-layer constraint.

### Work Items

1. **Establish a Test Flow/Framework**: Create the initial automated testing
   framework for `ironic-ipa-downloader` as none currently exists.
1. **Update `ironic-ipa-downloader` Dependencies**: Add installation steps
   for OCI clients and compression/extraction utilities in the `Dockerfile`.
1. **Implement OCI Logic in `get-resource.sh`**: Port OCI pulling, parsing, and
   extraction capabilities into the script or program.
1. **Update CI and Testing Pipelines**: Update tests in the
   `ironic-ipa-downloader` repository to verify both OCI and HTTP retrieval
   under the new framework.
1. **Update Documentation**: Update the user guide in `metal3-docs` to
   describe the use of the `oci://` scheme.

### Dependencies

- OCI-compatible client utility (such as `oras` v1.2.0 or newer)
- JSON processing tool (such as `jq` v1.6 or newer)
- Archive extraction tool (such as `bsdtar` v3.5 or newer)
- Compression tool (such as `zstd` v1.5 or newer)

### Test Plan

Currently, the `ironic-ipa-downloader` repository does not have an existing
automated test plan or test flow. Therefore, implementing this enhancement
will require designing and creating a test flow/framework first as part of
the work items, before integrating the OCI test cases.

Once the framework is established, the test plan will consist of:

1. **Unit and Script-level Testing**:
   - Verify parsing logic, URI schema routing, and cache directory checking.
1. **Integration Testing**:
   - Set up a local OCI registry in CI, push a dummy single-layer artifact,
     and verify successful pull, extraction of the kernel, repacking to `zstd`
     initramfs, and correct symlinking.
   - Verify that subsequent runs skip download based on digest caching.
   - Ensure the traditional HTTP path remains fully functional.

### Upgrade / Downgrade Strategy

This change is fully backward-compatible. Existing clusters using
traditional HTTP/HTTPS tarball URIs in `IPA_BASEURI` will continue to use
the legacy download code-path exactly as before without any configuration
modifications.

If an operator decides to migrate to OCI artifacts:

1. They upgrade the `ironic-ipa-downloader` image version.
1. They update `IPA_BASEURI` to use the `oci://` scheme.

Downgrading is simple:

1. Revert `IPA_BASEURI` to the traditional HTTP URI.
1. Downgrade the `ironic-ipa-downloader` image version if desired (though the
   new image version remains fully capable of handling HTTP URIs).

### Version Skew Strategy

Not applicable. The `ironic-ipa-downloader` executes as an independent
init-container. It communicates exclusively with the OCI registry (or HTTP
server) and writes to a shared volume. It has no API contract or tight
runtime coupling with other Metal3/Ironic components, other than providing
the standardized kernel and initramfs files.

## Drawbacks

- Increased container complexity and image size due to additional OCI-specific
  tooling.
- CPU utilization spike during init container startup when pulling a new OCI
  image version (due to compression/repackaging).

## Alternatives

1. **Distribute IPA as a standard Docker image containing pre-packaged files**:
   Instead of converting a rootfs layer, build a standard container image
   where the pre-compiled `ironic-python-agent.kernel` and
   `ironic-python-agent.initramfs` are already present in a directory. The
   downloader would simply copy them out.
   - *Why rejected*: This requires maintaining a specialized image-building
     pipeline specifically for wrapping files in a container image, rather
     than natively supporting standard OCI rootfs images which are more aligned
     with generic OS-container artifacts.
1. **Distribute kernel and ramdisk as separate raw OCI artifacts**:
   We could package the kernel and ramdisk directly as individual raw OCI
   artifacts (rather than standard container/docker images containing a full
   root filesystem). This approach is very clean and could eventually be
   integrated directly into Ironic itself.
   - *Why rejected for now*: Publishing and managing raw OCI artifacts
     requires specialized tooling and registries that support them. Standard
     container/docker images containing a single rootfs layer are much more
     widely supported by existing CI/CD pipelines, registries, and developer
     toolchains. This proposal specifically aims to support environments where
     publishing specialized raw OCI artifacts is not easily doable, making
     standard container images containing the rootfs the most practical and
     accessible distribution format.
1. **Write a custom Golang Downloader**:
   Build a custom Go binary (or another compiled language) that handles OCI
   pulling, parsing, and extraction using container registry libraries,
   potentially providing cleaner multi-layer image support.
   - *Why rejected*: While a custom language-based downloader is an open
     question and a highly viable outcome, the choice of implementation
     language is considered out of scope for this proposal. The intent is to
     establish the OCI artifact pulling capability and contract, rather than
     mandating a full rewrite of the existing scripting.

## References

- [ORAS (OCI Registry As Storage)](https://oras.land/)
- [OCI Image Specification](https://github.com/opencontainers/image-spec)
- [Ironic Python Agent](https://docs.openstack.org/ironic-python-agent/latest/)
- [get-resource.sh PoC](https://gist.github.com/diconico07/d30aedd8f90ff245ab686cfe1d54f7b3)
