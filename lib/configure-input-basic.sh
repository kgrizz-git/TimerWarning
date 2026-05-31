#!/bin/bash

###############################################################################
# Sleep Warning System - Basic Input Collection Module
#
# This module provides basic user input collection functions for the configuration
# wizard, supporting both GUI (YAD/Zenity/KDialog) and text modes.
#
# Functions:
# - get_hour_zenity()              - Get hour input using dialog tool (legacy name)
# - get_hour_text()                - Get hour input using text prompt
#
# Dependencies:
# - configure-core.sh (for has_dialog_tool, CONFIG_FILE)
# - configure-dialogs.sh (for show_entry_dialog, show_info_dialog)
###############################################################################

# Get hour input using dialog tool (legacy name: get_hour_zenity)
get_hour_zenity() {
    local prompt="$1"
    local default="$2"
    
    local hour
    hour=$(show_time_selection_dialog "Sleep Warning Configuration" "" "")
    
    if [ -z "${hour}" ]; then
        echo ""
        return 1
    fi
    
    echo "${hour}"
    return 0
}

# Get hour input using text prompt
get_hour_text() {
    local prompt="$1"
    local default="$2"
    
    while true; do
        configure_read -p "${prompt} [${default}]: " input
        input=${input:-${default}}
        
        if [ -z "${input}" ]; then
            echo ""
            return 1
        fi
        
        local normalized
        if normalized=$(convert_time_range_to_24hour "${input}"); then
            echo "${normalized}"
            return 0
        elif [[ "${input}" =~ ^[0-9]+$ ]] && [ "${input}" -ge "${MIN_HOUR}" ] && [ "${input}" -le "${MAX_HOUR}" ]; then
            # Legacy hour-only input
            printf "%02d:00" "${input}"
            return 0
        else
            echo "Invalid time format. Please enter 12h (e.g., 11pm) or 24h (e.g., 23:00) format." >&2
        fi
    done
}
