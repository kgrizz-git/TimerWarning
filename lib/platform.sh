#!/bin/bash

###############################################################################
# Sleep Warning System - Platform Detection Module
#
# Detects Linux vs macOS (Darwin) and exposes init-system helpers used by
# install, configure, manage, status, and service adapters.
#
# Outputs: detect_platform echoes "linux" or "darwin"
###############################################################################

if [ -z "${PLATFORM_MODULE_LOADED:-}" ]; then
    PLATFORM_MODULE_LOADED=1

    # Cached platform id: linux | darwin
    _SLEEP_WARNING_PLATFORM=""

    detect_platform() {
        if [ -n "${_SLEEP_WARNING_PLATFORM}" ]; then
            echo "${_SLEEP_WARNING_PLATFORM}"
            return 0
        fi
        local uname_s
        uname_s="$(uname -s 2>/dev/null || echo "")"
        case "${uname_s}" in
            Darwin)
                _SLEEP_WARNING_PLATFORM="darwin"
                ;;
            Linux)
                _SLEEP_WARNING_PLATFORM="linux"
                ;;
            *)
                # Default to linux for unknown Unix-like systems
                _SLEEP_WARNING_PLATFORM="linux"
                ;;
        esac
        echo "${_SLEEP_WARNING_PLATFORM}"
    }

    is_darwin() {
        [ "$(detect_platform)" = "darwin" ]
    }

    is_linux() {
        [ "$(detect_platform)" = "linux" ]
    }

    get_init_system() {
        if is_darwin; then
            echo "launchd"
        else
            echo "systemd"
        fi
    }

    # GUI session domain for launchctl (macOS 13+)
    launchd_gui_domain() {
        echo "gui/$(id -u)"
    }

    # LaunchAgent label
    launchd_label() {
        echo "com.sleep-warning"
    }

    get_launch_agent_plist_path() {
        echo "${HOME}/Library/LaunchAgents/$(launchd_label).plist"
    }

    get_timer_config_path() {
        if is_darwin; then
            get_launch_agent_plist_path
        else
            echo "${HOME}/.config/systemd/user/sleep-warning.timer"
        fi
    }

    get_service_config_path() {
        if is_darwin; then
            get_launch_agent_plist_path
        else
            echo "${HOME}/.config/systemd/user/sleep-warning.service"
        fi
    }

    is_scheduled_service_installed() {
        if is_darwin; then
            [ -f "$(get_launch_agent_plist_path)" ]
        else
            [ -f "${HOME}/.config/systemd/user/sleep-warning.timer" ] \
                && [ -f "${HOME}/.config/systemd/user/sleep-warning.service" ]
        fi
    }
fi
