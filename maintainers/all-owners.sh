#!/usr/bin/env bash
#
# usage: ./all-owners.sh > ALL-OWNERS
#

set -eu

declare -a REPOS=(
    baremetal-operator
    cluster-api-provider-metal3
    ip-address-manager
    ironic-agent-image
    ironic-client
    ironic-image
    ironic-ipa-downloader
    mariadb-image
    metal3-dev-env
    metal3-docs
    metal3-io.github.io
    project-infra
    static-ip-manager-image
)

declare -a OWNER_TYPES=(
    approvers
    emeritus_approvers
)


# check dependencies are in place - yq is not commonly available
# as os package, and yq from Ubuntu snap is incompatible
INSTALL_URL="https://github.com/mikefarah/yq/issues/488"
command -v yq &>/dev/null || { echo >&2 "fatal: yq not found: see ${INSTALL_URL}"; exit 1; }

all_owners_raw()
{
    owner_type="${1:?need to pass in one of: approvers, reviewers, emeritus_approvers, emeritus_reviewers}"

    for repo in "${REPOS[@]}"; do
        if [ "${repo}" = "metal3-io.github.io" ]; then
            filter=".filters.\".*\".${owner_type}"
        else
            filter=".${owner_type}"
        fi

        git ls-remote -q --exit-code --heads "https://github.com/metal3-io/${repo}" main >/dev/null 2>&1
        retVal=$?

        if [ ${retVal} -eq 0 ]; then
            branch='main'
        elif [ ${retVal} -ne 0 ]; then
            if [ "${repo}" = "metal3-io.github.io" ]; then
            branch='source'
        else
            branch='master'
        fi
    fi

    # NOTE: yq -y is not supported by any recent version of yq
    curl -s "https://raw.githubusercontent.com/metal3-io/${repo}/${branch}/OWNERS" | \
        yq "${filter}" | \
        grep -v "null" | \
        grep -v "\.\.\."
    done
}

echo "# All approvers from all top-level OWNERS files"
echo "# See metal3-docs/maintainers/all-owners.sh"

for owner in "${OWNER_TYPES[@]}"; do
    echo -e "\n${owner}:"
    all_owners_raw "${owner}" | \
        tr '[:upper:]' '[:lower:]' | \
        sort -u
done
