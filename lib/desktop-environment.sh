#!/bin/bash

###############################################################################
# Sleep Warning System - Desktop Environment Module
#
# This module handles desktop environment and dialog tool detection including:
# - KDE desktop environment detection
# - Dialog tool availability checking (zenity/yad/kdialog)
# - Unified dialog tool priority selection (YAD → Zenity → KDialog)
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

# Check if a dialog tool is available (unified priority: YAD → Zenity → KDialog)
# YAD's superior capabilities (native positioning, reliable sizing, window management)
# outweigh visual consistency considerations, even on KDE
check_dialog_tool() {
    local env_type="$1"

    # Unified priority for ALL environments: YAD -> Zenity -> KDialog
    if command -v yad >/dev/null 2>&1; then
        echo "yad"
        return 0
    elif command -v zenity >/dev/null 2>&1; then
        echo "zenity"
        return 0
    elif command -v kdialog >/dev/null 2>&1; then
        echo "kdialog"
        return 0
    fi

    return 1
}
