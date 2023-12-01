#!/bin/bash

# TODO:
# Fix markdownlint complaints
#
# Further documentation is available for these failures:
#  - MD013: https://github.com/markdownlint/markdownlint/blob/main/docs/RULES.md#md013---line-length
#  - MD029: https://github.com/markdownlint/markdownlint/blob/main/docs/RULES.md#md029---ordered-list-item-prefix
#  - MD047: https://github.com/markdownlint/markdownlint/blob/main/docs/RULES.md#md047---file-should-end-with-a-single-newline-character
#  - MD033: https://github.com/markdownlint/markdownlint/blob/main/docs/RULES.md#md033---inline-html
#  - MD041: https://github.com/markdownlint/markdownlint/blob/main/docs/RULES.md#md041---first-line-in-file-should-be-a-top-level-header
#  - MD007: https://github.com/markdownlint/markdownlint/blob/main/docs/RULES.md#md007---unordered-list-indentation
#  - MD046: https://github.com/markdownlint/markdownlint/blob/main/docs/RULES.md#md046---code-block-style
#  - MD055: https://github.com/markdownlint/markdownlint/blob/main/docs/RULES.md#md055---table-row-doesn-t-begin-end-with-pipes
#  - MD057: https://github.com/markdownlint/markdownlint/blob/main/docs/RULES.md#md057---table-has-missing-or-invalid-header-separation-second-row-


set -eux

IS_CONTAINER=${IS_CONTAINER:-false}
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-podman}"

if [ "${IS_CONTAINER}" != "false" ]; then
  TOP_DIR="${1:-.}"
  find "${TOP_DIR}" \
      -name '*.md' -exec \
      mdl --style all --warnings \
      --rules "~MD007,~MD013,~MD029,~MD033,~MD041,~MD046,~MD047,~MD055,~MD057" \
      {} \+
else
  "${CONTAINER_RUNTIME}" run --rm \
    --env IS_CONTAINER=TRUE \
    --volume "${PWD}:/workdir:ro,z" \
    --entrypoint sh \
    --workdir /workdir \
    docker.io/pipelinecomponents/markdownlint:0.13.0@sha256:9c0cdfb64fd3f1d3bdc5181629b39c2e43b6a52fc9fdc146611e1860845bbae0 \
    /workdir/hack/markdownlint.sh "$@"
fi
