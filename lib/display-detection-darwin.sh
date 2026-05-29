#!/bin/bash

###############################################################################
# Sleep Warning System - macOS Display / GUI Session Detection
###############################################################################

if [ -z "${DISPLAY_DETECTION_DARWIN_LOADED:-}" ]; then
    DISPLAY_DETECTION_DARWIN_LOADED=1

    detect_display_environment() {
        if ! command -v osascript >/dev/null 2>&1; then
            echo "none"
            return 0
        fi
        # Quick check that we can run AppleScript in a GUI session
        if osascript -e 'return "ok"' >/dev/null 2>&1; then
            echo "macos"
            return 0
        fi
        echo "none"
    }

    get_display_identifier() {
        echo "macos"
    }

    detect_system_mode() {
        echo "desktop"
    }

    get_mode_display_identifier() {
        echo "macos"
    }

    get_display() {
        local env_type="${1:-}"
        if [ "${env_type}" = "macos" ]; then
            echo "macos"
            return 0
        fi
        echo ""
    }
fi
