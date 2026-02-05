#!/bin/bash

###############################################################################
# Test Popup Script - Display example sleep warning popup
#
# This script displays a test popup with the same format as the sleep warning
# system to demonstrate the appearance and size.
#
# Usage (from root project directory):
#   ./tests/test-popup.sh
###############################################################################

# Project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Unicode / locale safety helper (ASCII fallback under non-UTF locales).
# shellcheck disable=SC1090
if [ -f "${SCRIPT_DIR}/lib/unicode-dialog-safety.sh" ]; then
    source "${SCRIPT_DIR}/lib/unicode-dialog-safety.sh"
fi
if ! type dialog_safe_text >/dev/null 2>&1; then
    dialog_safe_text() { printf '%s' "${1:-}"; }
fi

# Check if zenity is available
if command -v zenity >/dev/null 2>&1; then
    dialog_tool="zenity"
elif command -v yad >/dev/null 2>&1; then
    dialog_tool="yad"
elif command -v kdialog >/dev/null 2>&1; then
    dialog_tool="kdialog"
else
    echo "Error: No dialog tool available (zenity/yad/kdialog)"
    echo "Please install zenity: sudo apt install zenity (or equivalent for your distro)"
    exit 1
fi

# Prefer UTF-8 locale when available; otherwise dialog_safe_text() will sanitize.
if type dialog_prepare_utf8_locale >/dev/null 2>&1; then
    dialog_prepare_utf8_locale
fi

# Warning message (same format as sleep-warning.sh)
title="ALERT: Restricted time window"
message_fancy="⚠️  Late Night Usage Warning ⚠️

You are using your computer during restricted hours.

It's recommended to get some rest. Consider taking a break or going to sleep.

This warning will appear every 10 minutes while you continue using your computer during these hours."

title="$(dialog_safe_text "${title}")"
message="$(dialog_safe_text "${message_fancy}")"

# Display popup based on available tool
case "${dialog_tool}" in
    zenity)
        zenity --warning \
            --title="${title}" \
            --text="${message}" \
            --modal \
            --width=400 \
            --height=200 \
            2>/dev/null
        ;;
    yad)
        yad --warning \
            --title="${title}" \
            --text="${message}" \
            --modal \
            --width=400 \
            --height=200 \
            --on-top \
            2>/dev/null
        ;;
    kdialog)
        kdialog --title "${title}" \
            --warning "${message}" \
            2>/dev/null
        ;;
esac

echo "Popup displayed (400x200 pixels)"
