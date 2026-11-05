#!/bin/sh
# markdownlint-cli2 has config file(s) named .markdownlint-cli2.yaml in the repo

set -eux

IS_CONTAINER="${IS_CONTAINER:-false}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"

# all md files, but ignore .github
if [ "${IS_CONTAINER}" != "false" ]; then
    markdownlint-cli2 "**/*.md" "#.github"
else
    "${CONTAINER_RUNTIME}" run --rm \
        --env IS_CONTAINER=TRUE \
        --volume "${PWD}:/workdir:ro,z" \
        --entrypoint sh \
        --workdir /workdir \
        docker.io/pipelinecomponents/markdownlint-cli2:0.14.19@sha256:c651559a31fefc82cf864486d9472338ffa0aaa529ebf71a035d4f1d913809aa \
        /workdir/hack/markdownlint.sh "$@"
fi
