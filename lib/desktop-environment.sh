#!/bin/bash

###############################################################################
# Sleep Warning System - Desktop Environment Module
#
# This module handles desktop environment and dialog tool detection including:
# - KDE desktop environment detection
# - Dialog tool availability checking (zenity/yad/kdialog)
# - Environment-aware dialog tool priority selection
#
# Dependencies: None (standalone module)
#
# Usage: Source this file to access desktop environment functions
#   source lib/desktop-environment.sh
###############################################################################

# Detect if running on KDE
is_kde() {
    if [ -n "${KDE_SESSION_VERSION}" ] || [ -n "${KDE_FULL_SESSION}" ] || [ "${XDG_CURRENT_DESKTOP}" = "KDE" ] || [ "${XDG_SESSION_DESKTOP}" = "kde" ]; then
        return 0
    fi
    # Also check if KWin is running
    if pgrep -x kwin >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Check if a dialog tool is available (environment-aware priority)
check_dialog_tool() {
    local env_type="$1"

    # Wayland/gamescope: prefer yad for better Wayland behavior
    if [ "${env_type}" = "wayland" ] || [ "${env_type}" = "gamescope" ]; then
        if command -v yad >/dev/null 2>&1; then
            echo "yad"
            return 0
        elif command -v kdialog >/dev/null 2>&1; then
            echo "kdialog"
            return 0
        elif command -v zenity >/dev/null 2>&1; then
            echo "zenity"
            return 0
        fi
        return 1
    fi

    # KDE: prefer kdialog for KDE integration
    if is_kde; then
        if command -v kdialog >/dev/null 2>&1; then
            echo "kdialog"
            return 0
        elif command -v yad >/dev/null 2>&1; then
            echo "yad"
            return 0
        elif command -v zenity >/dev/null 2>&1; then
            echo "zenity"
            return 0
        fi
        return 1
    fi

    # Default: zenity -> yad -> kdialog
    if command -v zenity >/dev/null 2>&1; then
        echo "zenity"
        return 0
    elif command -v yad >/dev/null 2>&1; then
        echo "yad"
        return 0
    elif command -v kdialog >/dev/null 2>&1; then
        echo "kdialog"
        return 0
    fi

    return 1
}
