#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

run_text_custom_percent_case() (
    source "${ROOT_DIR}/lib/configure-core.sh"
    source "${ROOT_DIR}/lib/configure-dialogs.sh"
    source "${ROOT_DIR}/lib/configure-input-popup-size.sh"

    get_display_resolution() { echo "1000 800"; }

    result="$(printf "%s\n%s\n%s\n%s\n" 1 "100%x100%" 1 "95%x95%" | get_custom_popup_size_config false)"
    if printf '%s\n' "${result}" | grep -q '^100%x100%$'; then
        fail "text custom popup size accepted 100%x100%"
    fi
    printf '%s\n' "${result}" | grep -q '^95%x95%$' || fail "text custom popup size did not accept 95%x95%"
)

run_runtime_custom_pixel_case() (
    source "${ROOT_DIR}/lib/config.sh"

    get_display_resolution() { echo "1000 800"; }
    CONFIG_FILE="$(mktemp)"
    printf "%s\n" "POPUP_SIZE=custom" "POPUP_SIZE_CUSTOM=1000x800" "POPUP_SIZE_CUSTOM_ABSOLUTE=1000x800" > "${CONFIG_FILE}"

    result="$(get_popup_dimensions custom)"
    rm -f "${CONFIG_FILE}"
    [ "${result}" = "950 760" ] || fail "expected custom pixel size 950 760, got '${result}'"
)

run_runtime_raw_pixel_case() (
    source "${ROOT_DIR}/lib/config.sh"

    get_display_resolution() { echo "1000 800"; }
    CONFIG_FILE="$(mktemp)"
    printf "%s\n" "POPUP_SIZE=1000x800" > "${CONFIG_FILE}"

    result="$(get_popup_dimensions "$(get_popup_size)")"
    rm -f "${CONFIG_FILE}"
    [ "${result}" = "950 760" ] || fail "expected raw pixel size 950 760, got '${result}'"
)

run_text_custom_percent_case
run_runtime_custom_pixel_case
run_runtime_raw_pixel_case

echo "OK: popup size custom validation checks passed"
