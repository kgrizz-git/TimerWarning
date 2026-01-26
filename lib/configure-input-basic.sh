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
    hour=$(show_entry_dialog \
        "Sleep Warning Configuration" \
        "${prompt}" \
        "${default}")
    
    if [ -z "${hour}" ]; then
        echo ""
        return 1
    fi
    
    # Validate hour
    if ! [[ "${hour}" =~ ^[0-9]+$ ]] || [ "${hour}" -lt 0 ] || [ "${hour}" -gt 23 ]; then
        show_info_dialog \
            "Invalid Hour" \
            "Invalid hour. Please enter a number between 0 and 23."
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
        read -p "${prompt} [${default}]: " hour
        hour=${hour:-${default}}
        
        if [[ "${hour}" =~ ^[0-9]+$ ]] && [ "${hour}" -ge 0 ] && [ "${hour}" -le 23 ]; then
            echo "${hour}"
            return 0
        else
            echo "Invalid hour. Please enter a number between 0 and 23." >&2
        fi
    done
}
