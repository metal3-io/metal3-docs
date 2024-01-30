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

set -eux

IS_CONTAINER="${IS_CONTAINER:-false}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"

# all md files, but ignore .github and node_modules
if [ "${IS_CONTAINER}" != "false" ]; then
    cspell-cli --show-suggestions -c .cspell-config.json -- ./**/*.md
else
    "${CONTAINER_RUNTIME}" run --rm \
        --env IS_CONTAINER=TRUE \
        --volume "${PWD}:/workdir:ro,z" \
        --entrypoint sh \
        --workdir /workdir \
        ghcr.io/streetsidesoftware/cspell:8.3.2@sha256:2a6ab337b2f1a89e910653b46fdf219e3e4ec9662fc8d561b956c1fe14db9fac \
        /workdir/hack/spellcheck.sh "$@"
fi
