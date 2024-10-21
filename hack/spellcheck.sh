#!/bin/sh

# Spelling errors detected in markdown files.
# If the errors are names, external links, or unusual but accurate technical words,
# then you should create an inline comment like:
#
# <!-- cSpell:ignore someword someotherword -->
#
# Of course, you should only include non-dictionary words that are correctly spelled!
# If the error happens because of a common technical term or proper name that is likely
# to appear many times, then please edit "../.cspell-config.json" and add it to the
# "words" list.
# shellcheck disable=SC2292

set -eux

IS_CONTAINER="${IS_CONTAINER:-false}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"
WORKDIR="${WORKDIR:-/workdir}"

# all md files, but ignore .github and node_modules
if [ "${IS_CONTAINER}" != "false" ]; then
    cspell-cli --show-suggestions -c .cspell-config.json -- "./**/*.md"
else
    "${CONTAINER_RUNTIME}" run --rm \
        --env IS_CONTAINER=TRUE \
        --volume "${PWD}:${WORKDIR}:ro,z" \
        --entrypoint sh \
        --workdir "${WORKDIR}" \
        ghcr.io/streetsidesoftware/cspell:8.13.3@sha256:03df0e485775a43531c9c0e829227f39b3380796e92faab4166137dc5712d40a \
        "${WORKDIR}"/hack/spellcheck.sh "$@"
fi
