# Metal3 Documentation - AI Agent Instructions

Instructions for AI coding agents. For project overview, see [README.md](README.md).

## Overview

Central documentation repository for Metal3, published at
<https://book.metal3.io>. Uses mdBook static site generator.

## Repository Structure

| Directory | Purpose |
|-----------|---------|
| `docs/user-guide/` | Main user documentation (mdBook source) |
| `design/` | Design proposals and architecture docs |
| `processes/` | Project processes (release, security) |
| `security/` | Security policies and advisories |
| `hack/` | CI scripts (markdownlint, spellcheck, shellcheck) |

## Testing Standards

CI uses GitHub Actions. Run locally before PRs:

| Command | Purpose |
|---------|---------|
| `make lint` | Run all linters (markdown, spell, shell) |
| `make serve` | Serve docs locally on port 3000 |
| `make build` | Build static site |
| `./hack/markdownlint.sh` | Markdown linting |
| `./hack/spellcheck.sh` | Spell checking (cspell) |

## Code Conventions

- **Markdown**: Config in `.markdownlint-cli2.yaml`
- **Spelling**: Custom dictionary in `.cspell-config.json`
- **Links**: Checked by lychee (`.lycheeignore` for exceptions)

## Adding Documentation

1. Create/edit Markdown in `docs/user-guide/src/`
1. Update `SUMMARY.md` if adding new pages
1. Run `make serve` to preview
1. Run `make lint` before committing

## Code Review Guidelines

When reviewing pull requests:

1. **Accuracy** - Technical content must be correct and up-to-date
1. **Clarity** - Clear language, good examples
1. **Links** - No broken internal/external links
1. **Spelling** - No typos (add technical terms to `.cspell-config.json`)

## AI Agent Guidelines

1. Run `make lint` before committing
1. Update `.cspell-config.json` for new technical terms
1. Keep docs in sync with actual component behavior
1. Cross-link related pages

## Related Documentation

- [CAPM3](https://github.com/metal3-io/cluster-api-provider-metal3)
- [BMO](https://github.com/metal3-io/baremetal-operator)
- [Ironic Standalone Operator](https://github.com/metal3-io/ironic-standalone-operator)
