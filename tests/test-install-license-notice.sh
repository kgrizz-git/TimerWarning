#!/bin/bash
# Verify both installers copy LICENSE next to the libraries and refuse a copy without it.
# Inputs: repository LICENSE and lib/install-{linux,darwin}.sh. Output: PASS or a failing exit.
# Requires bash. Uses a temp HOME under tmp/ and does not touch the installed config.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "${ROOT}/tmp"
WORK="$(mktemp -d "${ROOT}/tmp/license-install.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

print_success() { :; }
print_error() { echo "ERR: $*" >&2; }
print_warning() { :; }
print_info() { :; }

assert_copied() {
    local installer="$1"
    local dest="$2"
    (
        export HOME="${WORK}/home-${installer}"
        mkdir -p "$HOME" "$dest"
        SCRIPT_DIR="$ROOT"
        LIB_DIR="$dest"
        # shellcheck disable=SC1090
        source "${ROOT}/lib/${installer}"
        install_copy_license
        cmp -s "${ROOT}/LICENSE" "${dest}/LICENSE"
    )
}

assert_copied "install-linux.sh" "${WORK}/linux-lib"
assert_copied "install-darwin.sh" "${WORK}/darwin-lib"

for installer in install-linux.sh install-darwin.sh; do
    if (
        export HOME="${WORK}/home-missing-${installer}"
        mkdir -p "$HOME" "${WORK}/missing-lib" "${WORK}/empty-src"
        SCRIPT_DIR="${WORK}/empty-src"
        LIB_DIR="${WORK}/missing-lib"
        # shellcheck disable=SC1090
        source "${ROOT}/lib/${installer}"
        install_copy_license
    ); then
        echo "FAIL: ${installer} continued without LICENSE"
        exit 1
    fi
done

echo "PASS: installers copy LICENSE and refuse a source tree without it"
