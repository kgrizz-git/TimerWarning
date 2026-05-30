#!/usr/bin/env bash

###############################################################################
# test-stat-mode.sh — Portable octal mode from stat (GNU Linux and BSD/macOS)
#
# Usage (source from test scripts):
#   # shellcheck disable=SC1091
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/test-stat-mode.sh"
#   mode=$(test_stat_octal_mode "${path}")
###############################################################################

# Returns octal permission mode (e.g. 600, 700, 755) or empty on failure.
test_stat_octal_mode() {
    local path="$1"
    local mode=""

    if [ -z "${path}" ] || [ ! -e "${path}" ]; then
        return 1
    fi

    if mode=$(stat -c '%a' "${path}" 2>/dev/null) && [[ "${mode}" =~ ^[0-9]+$ ]]; then
        printf '%s' "${mode}"
        return 0
    fi

    if mode=$(stat -f '%OLp' "${path}" 2>/dev/null) && [[ "${mode}" =~ ^[0-9]+$ ]]; then
        printf '%s' "${mode}"
        return 0
    fi

    return 1
}
