#!/bin/bash

###############################################################################
# Sleep Warning System - macOS Display Resolution Detection (Phase 3)
###############################################################################

if [ -z "${RESOLUTION_DETECTION_DARWIN_LOADED:-}" ]; then
    RESOLUTION_DETECTION_DARWIN_LOADED=1

    get_primary_screen_resolution() {
        local w h
        w=$(system_profiler SPDisplaysDataType 2>/dev/null | awk '/Resolution:/ {print $2; exit}')
        h=$(system_profiler SPDisplaysDataType 2>/dev/null | awk '/Resolution:/ {print $4; exit}')
        if [ -n "${w}" ] && [ -n "${h}" ]; then
            echo "${w} ${h}"
            return 0
        fi
        echo "1920 1080"
    }
fi
