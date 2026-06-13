#!/bin/bash

###############################################################################
# Sleep Warning System - Configuration File Operations Module
#
# This module handles all configuration file operations including reading,
# writing, and preserving user customizations. It also manages systemd timer
# file updates.
#
# Functions:
# - load_existing_config()   - configure-config-load.sh
# - write_config()           - configure-config-write.sh
# - update_timer_file()      - Update systemd timer file with new interval
#
# Dependencies:
# - configure-core.sh (for CONFIG_DIR, CONFIG_FILE, TIMER_FILE, SERVICE_NAME,
#                      DAY_NAMES, DAY_VARS, minutes_to_oncalendar)
###############################################################################

_CONFIGURE_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "${_CONFIGURE_CONFIG_DIR}/config-keys.sh"
# shellcheck disable=SC1090
source "${_CONFIGURE_CONFIG_DIR}/configure-config-load.sh"
source "${_CONFIGURE_CONFIG_DIR}/configure-config-write.sh"
unset _CONFIGURE_CONFIG_DIR

# Update timer / LaunchAgent from popup display frequency (Enhancement #30).
# Argument: popup_display_frequency (1-60 minutes). Run interval derived: 5 min if freq>=5, else freq.
update_timer_file() {
    local popup_freq="${1:-}"
    local run_interval
    run_interval=$(get_timer_run_interval "${popup_freq}")
    local _lib_dir
    _lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [ -f "${_lib_dir}/platform.sh" ]; then
        # shellcheck disable=SC1091
        source "${_lib_dir}/platform.sh"
    fi
    if [ -f "${_lib_dir}/service-config.sh" ]; then
        # shellcheck disable=SC1091
        source "${_lib_dir}/service-config.sh"
    fi

    if type update_timer_file_platform >/dev/null 2>&1; then
        update_timer_file_platform "${run_interval}"
        return $?
    fi

    # Legacy fallback (Linux systemd)
    if [ ! -f "${TIMER_FILE}" ]; then
        return 0
    fi
    local oncalendar
    oncalendar=$(minutes_to_oncalendar "${run_interval}")
    local backup_file="${TIMER_FILE}.bak"
    cp "${TIMER_FILE}" "${backup_file}" 2>/dev/null
    local temp_file
    temp_file=$(mktemp)
    {
        echo "[Unit]"
        echo "Description=Sleep Warning System Timer - Triggers warning check every ${run_interval} minutes"
        echo "Documentation=man:systemd.timer(5)"
        echo "Requires=${SERVICE_NAME}.service"
        echo ""
        echo "[Timer]"
        echo "# Run every ${run_interval} minutes (derived from popup display frequency)"
        echo "OnCalendar=${oncalendar}"
        echo "Persistent=true"
        echo "AccuracySec=1min"
        echo ""
        echo "[Install]"
        echo "WantedBy=timers.target"
    } > "${temp_file}"
    if mv "${temp_file}" "${TIMER_FILE}" 2>/dev/null; then
        systemctl --user daemon-reload >/dev/null 2>&1
        systemctl --user restart "${SERVICE_NAME}.timer" >/dev/null 2>&1 || true
        rm -f "${backup_file}" 2>/dev/null
        return 0
    fi
    mv "${backup_file}" "${TIMER_FILE}" 2>/dev/null
    return 1
}
