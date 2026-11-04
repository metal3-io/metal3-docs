#!/usr/bin/env bash

set -eux

USR_LOCAL_BIN="/usr/local/bin"
MINIMUM_KIND_VERSION=v0.33.0

# Map uname output to the OS/arch names used in kind release assets.
case "$(uname -s)" in
    Linux)  KIND_OS="linux" ;;
    Darwin) KIND_OS="darwin" ;;
    *)      KIND_OS="" ;;
esac
case "$(uname -m)" in
    x86_64 | amd64)  KIND_ARCH="amd64" ;;
    aarch64 | arm64) KIND_ARCH="arm64" ;;
    *)               KIND_ARCH="" ;;
esac

# SHA256 checksums of the kind ${MINIMUM_KIND_VERSION} release binaries, keyed
# by "${KIND_OS}/${KIND_ARCH}". Update together with MINIMUM_KIND_VERSION, see
# https://github.com/kubernetes-sigs/kind/releases/download/<version>/kind-<os>-<arch>.sha256sum
# A case statement is used instead of an associative array to stay compatible
# with bash 3.2, the default bash on macOS.
case "${KIND_OS}/${KIND_ARCH}" in
    linux/amd64)  KIND_CHECKSUM="aee6151561422756b764a4ae28e7f44cda5af5a9eead3cc9985112b1de8d8e0d" ;;
    linux/arm64)  KIND_CHECKSUM="20022bee6cfcd5086cb7234d218e3454e6090022f2a8f55d1fa7fcf42c3867a2" ;;
    darwin/amd64) KIND_CHECKSUM="5a99f26f57246dc9319dd294803313197a0f34d33c525b3ea8b655db5916ece0" ;;
    darwin/arm64) KIND_CHECKSUM="0c8c7dbe5e23594a198b786c4bc13dacc101fa6196b0cb0b23a1ca44e61f4b4f" ;;
    *)            KIND_CHECKSUM="" ;;
esac

KIND_URL="https://github.com/kubernetes-sigs/kind/releases/download/${MINIMUM_KIND_VERSION}/kind-${KIND_OS}-${KIND_ARCH}"

# Check if the detected version (passed as the first argument) is greater than
# or equal to the minimum version (passed as the second argument).
compare_versions() {
    local detected_version minimum_version version_ok i

    detected_version="${1}"
    minimum_version="${2}"

    IFS=. read -r -a current <<< "${detected_version#v}"
    IFS=. read -r -a minimum <<< "${minimum_version#v}"
    current[2]="${current[2]:-0}"
    current[2]="${current[2]%%[-+]*}"   # drop pre-release/build suffix, e.g. "0-alpha+abc"

    # Compare major, minor, patch numerically
    version_ok=true
    for i in 0 1 2; do
        if (( 10#${current[i]:-0} > 10#${minimum[i]:-0} )); then
            break
        elif (( 10#${current[i]:-0} < 10#${minimum[i]:-0} )); then
            version_ok=false
            break
        fi
    done

    echo "${version_ok}"
}

# Ensure the kind tool exists and is a viable version, or installs it
verify_kind_version()
{
    # If kind is not available on the path, get it
    if ! [[ -x "$(command -v kind)" ]]; then
        # A checksum is only defined for platforms with a kind release binary
        if [[ -n "${KIND_CHECKSUM}" ]]; then
            local tmp_dir checksum

            echo "kind not found, installing"

            if ! command -v sha256sum &>/dev/null; then
                echo "ERROR: sha256sum not found. On macOS, install coreutils: brew install coreutils" >&2
                exit 1
            fi

            tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/kind.XXXXXX")"
            # shellcheck disable=SC2064 # Intentional: expand tmp_dir now since it's local
            trap "$(printf 'rm -rf -- %q' "${tmp_dir}")" EXIT

            # Download the kind binary
            if ! curl --proto '=https' --tlsv1.3 -sSfL \
                --retry 3 --retry-delay 5 --max-time 120 \
                -o  "${tmp_dir}/kind" "${KIND_URL}"; then
                echo >&2 "fatal: failed to download kind from ${KIND_URL}"
                return 1
            fi

            # Verify checksum before using
            checksum="$(sha256sum "${tmp_dir}/kind" | awk '{print $1;}')"
            if [[ "${checksum}" != "${KIND_CHECKSUM}" ]]; then
                echo >&2 "fatal: ${KIND_URL} checksum '${checksum}' differs from expected '${KIND_CHECKSUM}'"
                return 1
            else
                echo "kind checksum ${checksum} verified"
            fi

            sudo install -o root -g 0 -m 0755 "${tmp_dir}/kind" "${USR_LOCAL_BIN}/kind"
        else
            echo "Missing required binary in path: kind (no kind release binary for $(uname -s)/$(uname -m))"
            return 2
        fi
    fi

    local kind_version version_ok
    if [[ -x "$(command -v kind)" ]]; then
       kind_version="v$(kind version -q)"
    else
        echo >&2 "warning: ${USR_LOCAL_BIN} not in your path"
        kind_version="v$("${USR_LOCAL_BIN}"/kind version -q)"
        return 2
    fi

    version_ok="$(compare_versions "${kind_version}" "${MINIMUM_KIND_VERSION}")"
    if [[ "${version_ok}" != "true" ]]; then
        echo >&2 "Detected kind version: ${kind_version}. Requires ${MINIMUM_KIND_VERSION} or greater."
        return 2
    fi
}

verify_kind_version
