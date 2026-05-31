#!/bin/bash

###############################################################################
# test-popup-interval-message.sh - Popup interval message text vs config
#
# Purpose: Verify popup interval text uses POPUP_DISPLAY_FREQUENCY (Enhancement
# #30), not legacy CHECK_INTERVAL-only reads. No GUI required.
# Last updated: 2026-05-31
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_DIR}/lib"

pass=0
fail=0

assert_interval_for_config() {
    local config_body="$1"
    local expected_text="$2"
    local label="$3"

    if (
        set -euo pipefail
        local test_home
        test_home=$(mktemp -d)
        export HOME="${test_home}"
        local config_dir="${HOME}/.config/sleep-warning"
        mkdir -p "${config_dir}/config"
        local config_file="${config_dir}/config/sleep-warning.conf"
        printf '%s\n' "${config_body}" > "${config_file}"

        # shellcheck disable=SC1091
        source "${LIB_DIR}/config.sh"

        _popup_get_interval_text() {
            local minutes="$1"
            if [ "${minutes}" -eq 1 ]; then
                echo "every minute"
            else
                echo "every ${minutes} minutes"
            fi
        }

        local freq interval_text check_interval
        freq=$(get_popup_display_frequency)
        check_interval=$(get_check_interval)
        interval_text="$(_popup_get_interval_text "${freq}")"

        if [ "${interval_text}" != "${expected_text}" ] || [ "${check_interval}" != "${freq}" ]; then
            echo "FAIL: ${label} — expected '${expected_text}', got '${interval_text}' (freq=${freq}, get_check_interval=${check_interval})" >&2
            rm -rf "${test_home}"
            exit 1
        fi
        rm -rf "${test_home}"
    ); then
        echo "PASS: ${label}"
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
    fi
}

echo "=== Popup interval message config tests ==="
echo ""

assert_interval_for_config \
    "POPUP_DISPLAY_FREQUENCY=30" \
    "every 30 minutes" \
    "modern config (POPUP_DISPLAY_FREQUENCY=30 only)"

assert_interval_for_config \
    "CHECK_INTERVAL=20" \
    "every 20 minutes" \
    "legacy config (CHECK_INTERVAL=20 only)"

assert_interval_for_config \
    $'POPUP_DISPLAY_FREQUENCY=15\nCHECK_INTERVAL=30' \
    "every 15 minutes" \
    "both keys set (prefers POPUP_DISPLAY_FREQUENCY)"

assert_interval_for_config \
    "POPUP_DISPLAY_FREQUENCY=1" \
    "every minute" \
    "singular (POPUP_DISPLAY_FREQUENCY=1)"

assert_interval_for_config \
    "# empty config" \
    "every 10 minutes" \
    "missing keys (default 10)"

echo ""
echo "Results: ${pass} passed, ${fail} failed"
[ "${fail}" -eq 0 ]
