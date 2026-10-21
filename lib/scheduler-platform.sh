#!/bin/bash

###############################################################################
# Sleep Warning System - Scheduler platform helpers (systemd / launchd)
###############################################################################

if [ -z "${SCHEDULER_PLATFORM_LOADED:-}" ]; then
    SCHEDULER_PLATFORM_LOADED=1

    scheduler_is_darwin() {
        [ "$(uname -s 2>/dev/null)" = "Darwin" ]
    }

    scheduler_plist_path() {
        echo "${HOME}/Library/LaunchAgents/com.sleep-warning.plist"
    }

    scheduler_stop_and_disable() {
        if scheduler_is_darwin; then
            local lib_dir
            lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            if [ -f "${lib_dir}/service-config-darwin.sh" ]; then
                # shellcheck disable=SC1091
                source "${lib_dir}/service-config-darwin.sh"
                disable_scheduled_service
                return $?
            fi
            return 1
        fi
        local rc=0
        systemctl --user stop sleep-warning.timer 2>/dev/null || rc=1
        systemctl --user disable sleep-warning.timer 2>/dev/null || rc=1
        return "${rc}"
    }

    scheduler_remove_files() {
        if scheduler_is_darwin; then
            local lib_dir
            lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            if [ -f "${lib_dir}/service-config-darwin.sh" ]; then
                # shellcheck disable=SC1091
                source "${lib_dir}/service-config-darwin.sh"
                remove_launch_agent
                return $?
            fi
            return 1
        fi
        rm -f "${HOME}/.config/systemd/user/sleep-warning.service" 2>/dev/null
        rm -f "${HOME}/.config/systemd/user/sleep-warning.timer" 2>/dev/null
    }

    scheduler_reload() {
        if scheduler_is_darwin; then
            return 0
        fi
        systemctl --user daemon-reload 2>/dev/null
    }

    scheduler_is_installed() {
        local script_path="${HOME}/.local/bin/sleep-warning.sh"
        if scheduler_is_darwin; then
            [ -f "${script_path}" ] && [ -f "$(scheduler_plist_path)" ]
        else
            [ -f "${script_path}" ] \
                && [ -f "${HOME}/.config/systemd/user/sleep-warning.service" ] \
                && [ -f "${HOME}/.config/systemd/user/sleep-warning.timer" ]
        fi
    }

    scheduler_status_lines() {
        if scheduler_is_darwin; then
            local lib_dir status
            lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            # shellcheck disable=SC1091
            source "${lib_dir}/service-config-darwin.sh"
            status=$(get_launch_agent_status_text)
            echo "Platform: macOS (launchd)"
            echo "LaunchAgent: $(scheduler_plist_path)"
            echo "Status: ${status}"
            return 0
        fi
        local enabled active
        enabled=$(systemctl --user is-enabled sleep-warning.timer 2>/dev/null)
        active=$(systemctl --user is-active sleep-warning.timer 2>/dev/null)
        echo "Platform: Linux (systemd)"
        echo "Enabled: ${enabled:-unknown}"
        echo "Active: ${active:-unknown}"
        if [ "${active}" = "active" ]; then
            local next_trigger
            next_trigger=$(systemctl --user list-timers sleep-warning.timer --no-pager --no-legend 2>/dev/null | awk '{print $1, $2, $3, $4, $5}')
            [ -n "${next_trigger}" ] && echo "Next trigger: ${next_trigger}"
        fi
    }

    scheduler_enable_start() {
        if scheduler_is_darwin; then
            local lib_dir
            lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            # shellcheck disable=SC1091
            source "${lib_dir}/service-config-darwin.sh"
            enable_scheduled_service
            return $?
        fi
        systemctl --user daemon-reload 2>/dev/null
        systemctl --user enable sleep-warning.timer 2>/dev/null
        systemctl --user start sleep-warning.timer 2>/dev/null
    }
fi
