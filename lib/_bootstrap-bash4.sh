#!/bin/bash

###############################################################################
# _bootstrap-bash4.sh — Source ensure-bash4 and re-exec if needed (entry scripts)
#
# Place at top of user-facing scripts after minimal path setup.
# Searches project lib/ and ~/.local/lib/sleep-warning/.
###############################################################################

_bootstrap_bash4() {
    local script_path="$1"
    shift
    local dir candidate
    dir="$(cd "$(dirname "${script_path}")" && pwd)"
    for candidate in \
        "${dir}/lib/ensure-bash4.sh" \
        "${HOME}/.local/lib/sleep-warning/ensure-bash4.sh"; do
        if [ -f "${candidate}" ]; then
            # shellcheck disable=SC1090
            source "${candidate}"
            ensure_bash4_reexec "${script_path}" "$@"
            return 0
        fi
    done
    return 0
}
