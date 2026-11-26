# Metal3 documentation (metal3-docs)

Source of the Metal3 user guide, published at <https://book.metal3.io>,
plus design proposals and project process documents. Project overview:
[README.md](README.md). Contribution rules:
[CONTRIBUTING.md](CONTRIBUTING.md) and the
[Metal3 community guide](https://github.com/metal3-io/community/blob/main/CONTRIBUTING.md).

This file holds only what you cannot cheaply infer from the repository.
Where it disagrees with the files or the Makefile, trust those and report
the mismatch.

## AI-assisted contributions

Metal3 follows the CNCF and
[Linux Foundation generative AI policy](https://www.linuxfoundation.org/legal/generative-ai).

- AI is a tool. The human who opens a PR is its author and is responsible
  for every line of it, including licensing and third-party content.
- Review is a conversation between humans. A PR where an agent or bot
  answers reviewers will be closed. Agents may draft changes; the
  contributor reads them, understands them, and replies personally.

- Keep changes surgical. The smallest complete change that solves the
  stated problem wins. Every added file, function, flag, dependency or
  test helper must trace to that problem; anything that does not is
  bloat and gets removed. Prefer reusing existing code over new code.
  Report unrelated findings instead of fixing them in the same PR.

## Repository map

- `docs/user-guide/`: the mdBook book. `src/SUMMARY.md` defines the page
  tree; a page missing from it is not published. `book.toml` enables two
  mdBook plugins built from `hack/tools/`: `releasetag` and `embed`.
- `design/`: design proposals, one directory per component, plus
  cross-project proposals at the top level.
- `processes/`: release, triage, roadmap and reviewer processes.
- `hack/quick-start/`: scripts and manifests used by the quick-start
  guide, and the CI test for it.

## Testing

- Targets are in the `Makefile`. CI jobs:
  [Prow](https://github.com/metal3-io/project-infra/blob/main/prow/config/jobs/metal3-io/metal3-docs.yaml)
  and `.github/workflows/`. Netlify builds a preview of every PR
  (`netlify.toml`).
- Conventions are whatever the existing pages and the lint configs do.
  Read neighboring pages before writing new ones.
- Before finishing, run `make lint`. For changes under
  `docs/user-guide/`, also run `make netlify-build`, which is what Netlify
  runs. All must pass. Add new technical terms to `.cspell-config.json`
  instead of rewording around them.
- `make build` and `make serve` need a TTY and use the
  `quay.io/metal3-io/mdbook:latest` image. Use `make netlify-build` for
  non-interactive checks.
- Do not run `hack/quick-start/*.sh` unless the user asks: they use
  `sudo` to create bridges, virtual interfaces and iptables rules, install
  `kubectl` into `/usr/local/bin`, and create libvirt VMs on the host.
  CI runs the quick-start test when `quick-start.md` or
  `hack/quick-start/` changes.

## Invariants

These apply to writing and to reviewing changes.

- **Docs match the code.** User-guide pages describe behavior of the
  component repos (sibling checkouts under `../`). Check claims against
  that source, not against memory or other pages.
- **Version support.** `docs/user-guide/src/version_support.md` is
  updated as part of component releases. Change it only to reflect a
  release or support decision that has actually happened.
- **Generated versions.** `{{#releasetag ...}}` resolves the latest
  release from `proxy.golang.org` at build time. Do not replace it with a
  hardcoded version.
- **Embedded files.** `{{#embed-github ...}}` in `quick-start.md` pulls
  files from the `main` branch on GitHub at build time, so a PR preview
  shows the old content. Keep the guide text and `hack/quick-start/` in
  sync in the same PR.
- **Book build.** Links with empty targets in `SUMMARY.md` crash the
  build (see the comment at its top).
- **Design proposals.** Start from `design/_template.md` and follow the
  [proposal process](https://github.com/metal3-io/community/blob/main/CONTRIBUTING.md#proposal-process).
  A proposal records a design agreed by humans: link the tracking issue
  and do not present a draft as agreed. API proposals follow
  [design/api-design-principles.md](design/api-design-principles.md).
- **Security.** Docs must not teach insecure setups silently. Examples
  contain no real secrets, keys or internal host names. Any example that
  disables TLS verification, uses default credentials, grants
  cluster-wide RBAC, or reaches across namespaces must say so and limit
  it to test environments. Guidance on multi-tenancy, namespace scoping
  and role isolation must match what the component actually enforces.
- **Pinning.** Pin new external references: GitHub Actions by commit SHA,
  container images by digest, downloaded binaries by version and
  checksum.

## External references

- [Metal3 user guide](https://book.metal3.io/)
- [mdBook documentation](https://rust-lang.github.io/mdBook/)
- [Design proposals](https://github.com/metal3-io/metal3-docs/tree/main/design)
