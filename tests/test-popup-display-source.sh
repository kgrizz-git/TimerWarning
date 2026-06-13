#!/bin/bash
# Direct-source smoke: popup-display facade and Linux lifecycle helpers.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
export CONFIG_DIR="${HOME}/.config/sleep-warning"
export CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"
mkdir -p "${CONFIG_DIR}/config" "${CONFIG_DIR}/logs"

# shellcheck disable=SC1091
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/display-detection.sh"
source "${LIB_DIR}/desktop-environment.sh"
source "${LIB_DIR}/window-management.sh"
source "${LIB_DIR}/time-calculations.sh"
source "${LIB_DIR}/pause-state.sh"
source "${LIB_DIR}/popup-display.sh"

for fn in show_warning _popup_spawn_warning_dialog _popup_linux_run_post_spawn_lifecycle \
    _popup_linux_on_spawn_success popup_start_pid_file_watchdog; do
    if ! type "$fn" >/dev/null 2>&1; then
        echo "FAIL: missing function $fn"
        exit 1
    fi
done

# Message helpers remain on facade
for fn in _popup_get_interval_text _popup_build_base_message _popup_build_initial_countdown_suffix; do
    if ! type "$fn" >/dev/null 2>&1; then
        echo "FAIL: missing helper $fn"
        exit 1
    fi
done

echo "PASS: popup-display direct-source smoke"
