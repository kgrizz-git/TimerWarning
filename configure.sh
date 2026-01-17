#!/bin/bash

###############################################################################
# Sleep Warning System - Interactive Configuration Wizard
#
# This script provides a user-friendly GUI interface for configuring restricted
# hours for the sleep warning system. It walks users through setting up
# restricted hours for each day of the week.
#
# Requirements:
# - bash
# - zenity (preferred) or fallback to text prompts
#
# Usage:
#   ./configure.sh [OPTIONS]
#   sleep-warning-configure [OPTIONS] (after installation)
#
# Options:
#   --text, --no-gui    Force text mode (disable GUI)
#   --gui               Force GUI mode (requires zenity)
#   --help, -h          Show help message
#
# By default, GUI mode is used if zenity is available and a display is present.
#
# Output:
# - Updates ~/.config/sleep-warning/sleep-warning.conf with user selections
###############################################################################

SCRIPT_NAME="sleep-warning-configure"
CONFIG_DIR="${HOME}/.config/sleep-warning"
CONFIG_FILE="${CONFIG_DIR}/sleep-warning.conf"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
TIMER_FILE="${SYSTEMD_USER_DIR}/sleep-warning.timer"
SERVICE_NAME="sleep-warning"

# Day names array
declare -a DAY_NAMES=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
declare -a DAY_VARS=("SUNDAY" "MONDAY" "TUESDAY" "WEDNESDAY" "THURSDAY" "FRIDAY" "SATURDAY")

# Check if zenity is available
has_zenity() {
    command -v zenity >/dev/null 2>&1
}

# Check if GUI is available
has_gui() {
    [ -n "${DISPLAY}" ] || [ -S "/tmp/.X11-unix/X0" ] || command -v loginctl >/dev/null 2>&1
}

# Load existing configuration from file
# This function populates global arrays and sets global variables
# Arrays must be declared as global in the caller before calling this function
load_existing_config() {
    # Initialize with defaults
    declare -g check_interval="10"
    declare -g popup_size="medium"
    declare -g popup_position="center"
    declare -g min_display_time="30"
    declare -g popup_immovable="true"
    
    # Clear existing arrays (they should already be declared as global by caller)
    config_lines=()
    summary_lines=()
    
    if [ ! -f "${CONFIG_FILE}" ]; then
        # No config file, use defaults (already set above)
        return 0
    fi
    
    # Read check interval
    local existing_interval
    existing_interval=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_interval}" ] && [[ "${existing_interval}" =~ ^[0-9]+$ ]] && [ "${existing_interval}" -ge 1 ] && [ "${existing_interval}" -le 60 ]; then
        declare -g check_interval="${existing_interval}"
    fi
    
    # Read popup size
    local existing_size
    existing_size=$(grep -E "^[[:space:]]*POPUP_SIZE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_size}" ]; then
        declare -g popup_size="${existing_size}"
    fi
    
    # Read popup position
    local existing_position
    existing_position=$(grep -E "^[[:space:]]*POPUP_POSITION=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_position}" ]; then
        declare -g popup_position="${existing_position}"
    fi
    
    # Read minimum display time
    local existing_time
    existing_time=$(grep -E "^[[:space:]]*POPUP_MIN_DISPLAY_TIME=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -n "${existing_time}" ] && [[ "${existing_time}" =~ ^[0-9]+$ ]] && [ "${existing_time}" -ge 0 ] && [ "${existing_time}" -le 300 ]; then
        declare -g min_display_time="${existing_time}"
    fi
    
    # Read popup immovable setting
    local existing_immovable
    existing_immovable=$(grep -E "^[[:space:]]*POPUP_IMMOVABLE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [ -n "${existing_immovable}" ]; then
        if [ "${existing_immovable}" = "true" ] || [ "${existing_immovable}" = "1" ] || [ "${existing_immovable}" = "yes" ]; then
            declare -g popup_immovable="true"
        elif [ "${existing_immovable}" = "false" ] || [ "${existing_immovable}" = "0" ] || [ "${existing_immovable}" = "no" ]; then
            declare -g popup_immovable="false"
        fi
    fi
    
    # Load day configurations
    for i in 0 1 2 3 4 5 6; do
        local day_var="${DAY_VARS[${i}]}"
        local day_name="${DAY_NAMES[${i}]}"
        
        # Check if day line exists in config file (even if empty)
        local day_line_exists
        day_line_exists=$(grep -E "^[[:space:]]*${day_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | head -n1)
        
        if [ -n "${day_line_exists}" ]; then
            # Day line exists - extract value (may be empty if explicitly skipped)
            local day_config
            day_config=$(echo "${day_line_exists}" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            if [ -n "${day_config}" ]; then
                # Has a value - configured with restrictions
                config_lines[${i}]="${day_var}=${day_config}"
                summary_lines[${i}]="${day_name}: ${day_config}"
            else
                # Line exists but is empty - explicitly skipped, no restrictions
                config_lines[${i}]="${day_var}="
                summary_lines[${i}]="${day_name}: (no restrictions)"
            fi
        fi
        # If day line doesn't exist, don't add to array (will use defaults)
    done
}

# Get section status indicators for menu display
get_section_status() {
    # Access global config_lines array directly
    local weekdays_status="(not configured)"
    local weekends_status="(not configured)"
    
    # Check weekdays (indices 1-5: Monday-Friday)
    local has_weekdays=false
    for i in 1 2 3 4 5; do
        if [ -n "${config_lines[${i}]}" ]; then
            has_weekdays=true
            break
        fi
    done
    
    if [ "${has_weekdays}" = "true" ]; then
        weekdays_status="✓"
    fi
    
    # Check weekends (indices 0, 6: Sunday, Saturday)
    local has_weekends=false
    for i in 0 6; do
        if [ -n "${config_lines[${i}]}" ]; then
            has_weekends=true
            break
        fi
    done
    
    if [ "${has_weekends}" = "true" ]; then
        weekends_status="✓"
    fi
    
    echo "${weekdays_status}|${weekends_status}"
}

# Show main navigation menu
show_main_menu() {
    local use_gui="$1"
    local check_interval="$2"
    local popup_size="$3"
    local popup_position="$4"
    local min_display_time="$5"
    local popup_immovable="$6"
    local weekdays_status="$7"
    local weekends_status="$8"
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        # GUI mode
        local tmpfile
        tmpfile=$(mktemp)
        
        # Build window behavior description with all attributes
        local window_desc="Size: ${popup_size}"
        if [ "${popup_size}" = "small" ]; then
            window_desc="${window_desc} (400x250)"
        elif [ "${popup_size}" = "medium" ]; then
            window_desc="${window_desc} (800x500)"
        elif [ "${popup_size}" = "large" ]; then
            window_desc="${window_desc} (2000x1350)"
        fi
        window_desc="${window_desc}, Position: ${popup_position}"
        if [ "${min_display_time}" -gt 0 ]; then
            window_desc="${window_desc}, Min Display: ${min_display_time}s"
        else
            window_desc="${window_desc}, Min Display: Disabled"
        fi
        if [ "${popup_immovable}" = "true" ]; then
            window_desc="${window_desc}, Immovable: On"
        else
            window_desc="${window_desc}, Immovable: Off"
        fi
        
        zenity --list \
            --title="Sleep Warning Configuration" \
            --text="Select a section to configure:" \
            --column="Option" --column="Description" \
            --hide-column=1 \
            --width=700 \
            --height=400 \
            "1" "Timer Settings (Check Interval: ${check_interval} min)" \
            "2" "Window Behavior (${window_desc})" \
            "3" "Weekdays Configuration ${weekdays_status}" \
            "4" "Weekends Configuration ${weekends_status}" \
            "5" "Visual Day/Time Grid" \
            "6" "Review and Save" \
            > "${tmpfile}" 2>/dev/null
        local exit_code=$?
        local choice=$(cat "${tmpfile}" 2>/dev/null)
        rm -f "${tmpfile}"
        
        if [ "${exit_code}" -ne 0 ]; then
            # User cancelled - ask if they want to cancel whole config
            if confirm_cancel "${use_gui}"; then
                echo "CANCELLED"
                return 2
            else
                return 1  # Return to show menu again
            fi
        fi
        
        # If OK was clicked but no item selected, default to "Review and Save" (option 6)
        if [ -z "${choice}" ]; then
            choice="6"
        fi
        
        echo "${choice}"
        return 0
    else
        # Text mode
        echo "" >&2
        echo "=== Configuration Menu ===" >&2
        echo "" >&2
        # Build window behavior description with all attributes
        local window_desc="Size: ${popup_size}"
        if [ "${popup_size}" = "small" ]; then
            window_desc="${window_desc} (400x250)"
        elif [ "${popup_size}" = "medium" ]; then
            window_desc="${window_desc} (800x500)"
        elif [ "${popup_size}" = "large" ]; then
            window_desc="${window_desc} (2000x1350)"
        fi
        window_desc="${window_desc}, Position: ${popup_position}"
        if [ "${min_display_time}" -gt 0 ]; then
            window_desc="${window_desc}, Min Display: ${min_display_time}s"
        else
            window_desc="${window_desc}, Min Display: Disabled"
        fi
        if [ "${popup_immovable}" = "true" ]; then
            window_desc="${window_desc}, Immovable: On"
        else
            window_desc="${window_desc}, Immovable: Off"
        fi
        
        echo "1. Timer Settings (Check Interval: ${check_interval} min)" >&2
        echo "   Configure how often the system checks for restricted hours" >&2
        echo "" >&2
        echo "2. Window Behavior (${window_desc})" >&2
        echo "   Configure popup size, position, display time, and immovable settings" >&2
        echo "" >&2
        echo "3. Weekdays Configuration ${weekdays_status}" >&2
        echo "   Set restricted hours for Monday through Friday" >&2
        echo "" >&2
        echo "4. Weekends Configuration ${weekends_status}" >&2
        echo "   Set restricted hours for Saturday and Sunday" >&2
        echo "" >&2
        echo "5. Visual Day/Time Grid" >&2
        echo "   View and edit all days in a visual grid format" >&2
        echo "" >&2
        echo "6. Review and Save" >&2
        echo "   Review your configuration and save changes" >&2
        echo "" >&2
        echo "To cancel and exit without saving, press Ctrl+C" >&2
        echo "" >&2
        
        while true; do
            read -p "Select option [1-6]: " choice >&2
            case "${choice}" in
                1|2|3|4|5|6)
                    echo "${choice}"
                    return 0
                    ;;
                *)
                    echo "Invalid option. Please enter 1-6." >&2
                    ;;
            esac
        done
    fi
}

# Confirm cancellation with user
confirm_cancel() {
    local use_gui="$1"
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        zenity --question \
            --title="Cancel Configuration?" \
            --text="Are you sure you want to cancel?\n\nAll unsaved changes will be lost." \
            --ok-label="Yes, Cancel" \
            --cancel-label="No, Continue" \
            2>/dev/null
        return $?
    else
        echo ""
        read -p "Cancel configuration? All unsaved changes will be lost. [y/N]: " answer
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Confirm skipping a day
confirm_skip_day() {
    local day_name="$1"
    local use_gui="$2"
    
    # Determine if this is multiple days (weekdays or weekends)
    local is_multiple=false
    local skip_message=""
    if [[ "${day_name}" == *"Weekdays"* ]] || [[ "${day_name}" == *"Monday-Friday"* ]]; then
        is_multiple=true
        skip_message="Are you sure you want to skip all weekdays (Monday-Friday)?\n\nNo restrictions will be set for any weekday."
    elif [[ "${day_name}" == *"Weekends"* ]] || [[ "${day_name}" == *"Saturday and Sunday"* ]]; then
        is_multiple=true
        skip_message="Are you sure you want to skip both weekend days (Saturday and Sunday)?\n\nNo restrictions will be set for either weekend day."
    else
        skip_message="Are you sure you want to skip ${day_name}?\n\nNo restrictions will be set for this day."
    fi
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        zenity --question \
            --title="Skip ${day_name}?" \
            --text="${skip_message}" \
            --ok-label="Yes, Skip" \
            --cancel-label="No, Configure" \
            2>/dev/null
        return $?
    else
        echo "" >&2
        if [ "${is_multiple}" = "true" ]; then
            read -p "Skip ${day_name}? No restrictions will be set. [y/N]: " answer
        else
            read -p "Skip ${day_name}? No restrictions will be set for this day. [y/N]: " answer
        fi
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Get hour input using zenity
get_hour_zenity() {
    local prompt="$1"
    local default="$2"
    
    local hour
    hour=$(zenity --entry \
        --title="Sleep Warning Configuration" \
        --text="${prompt}" \
        --entry-text="${default}" \
        2>/dev/null)
    
    if [ -z "${hour}" ]; then
        echo ""
        return 1
    fi
    
    # Validate hour
    if ! [[ "${hour}" =~ ^[0-9]+$ ]] || [ "${hour}" -lt 0 ] || [ "${hour}" -gt 23 ]; then
        zenity --error --text="Invalid hour. Please enter a number between 0 and 23." 2>/dev/null
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

# Get popup size from user
get_popup_size_config() {
    local use_gui="$1"
    local default_size="medium"
    
    # Try to get existing size from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_size
        existing_size=$(grep -E "^[[:space:]]*POPUP_SIZE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_size}" ]; then
            default_size="${existing_size}"
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        # GUI mode
        while true; do
            local size
            local tmpfile
            tmpfile=$(mktemp)
            
            zenity --list \
                --title="Sleep Warning Configuration" \
                --text="Select popup size (current: ${default_size}):" \
                --column="Size" --column="Dimensions" \
                "small" "400x250 pixels" \
                "medium" "800x500 pixels" \
                "large" "2000x1350 pixels" \
                --width=500 \
                --height=350 \
                --print-column=1 \
                > "${tmpfile}" 2>/dev/null
            local exit_code=$?
            
            size=$(cat "${tmpfile}" 2>/dev/null)
            rm -f "${tmpfile}"
            
            # User cancelled
            if [ "${exit_code}" -ne 0 ] || [ -z "${size}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            echo "${size}"
            return 0
        done
    else
        # Text mode
        echo "" >&2
        echo "Popup Size Options:" >&2
        echo "  1) small (400x250)" >&2
        echo "  2) medium (800x500)" >&2
        echo "  3) large (2000x1350)" >&2
        echo "" >&2
        while true; do
            read -p "Select size [1-3, default: ${default_size}]: " choice
            case "${choice}" in
                1|small) echo "small"; return 0 ;;
                2|medium) echo "medium"; return 0 ;;
                3|large) echo "large"; return 0 ;;
                "") echo "${default_size}"; return 0 ;;
                *) echo "Invalid choice. Please select 1, 2, or 3." >&2 ;;
            esac
        done
    fi
}

# Get minimum display time from user
get_min_display_time_config() {
    local use_gui="$1"
    local default_time="30"
    
    # Try to get existing time from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_time
        existing_time=$(grep -E "^[[:space:]]*POPUP_MIN_DISPLAY_TIME=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_time}" ] && [[ "${existing_time}" =~ ^[0-9]+$ ]]; then
            default_time="${existing_time}"
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        # GUI mode
        while true; do
            local time
            local tmpfile
            tmpfile=$(mktemp)
            
            zenity --entry \
                --title="Sleep Warning Configuration" \
                --text="Minimum time popup must be visible before it can be closed:\n\nEnter time in seconds (0-300):\n(0 = disabled, 30 = default)" \
                --entry-text="${default_time}" \
                > "${tmpfile}" 2>/dev/null
            local exit_code=$?
            
            time=$(cat "${tmpfile}" 2>/dev/null)
            rm -f "${tmpfile}"
            
            # User cancelled
            if [ "${exit_code}" -ne 0 ] || [ -z "${time}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            # Validate time
            if ! [[ "${time}" =~ ^[0-9]+$ ]] || [ "${time}" -lt 0 ] || [ "${time}" -gt 300 ]; then
                zenity --error --text="Invalid time. Please enter a number between 0 and 300 seconds." 2>/dev/null
                continue
            fi
            
            echo "${time}"
            return 0
        done
    else
        # Text mode
        while true; do
            read -p "Minimum display time in seconds (0-300, 0=disabled) [${default_time}]: " time
            time=${time:-${default_time}}
            
            if [[ "${time}" =~ ^[0-9]+$ ]] && [ "${time}" -ge 0 ] && [ "${time}" -le 300 ]; then
                echo "${time}"
                return 0
            else
                echo "Invalid time. Please enter a number between 0 and 300." >&2
            fi
        done
    fi
}

# Get popup immovable setting from user
get_popup_immovable_config() {
    local use_gui="$1"
    local default_immovable="true"
    
    # Try to get existing setting from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_immovable
        existing_immovable=$(grep -E "^[[:space:]]*POPUP_IMMOVABLE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -n "${existing_immovable}" ]; then
            if [ "${existing_immovable}" = "true" ] || [ "${existing_immovable}" = "1" ] || [ "${existing_immovable}" = "yes" ]; then
                default_immovable="true"
            elif [ "${existing_immovable}" = "false" ] || [ "${existing_immovable}" = "0" ] || [ "${existing_immovable}" = "no" ]; then
                default_immovable="false"
            fi
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        # GUI mode
        while true; do
            local immovable
            local tmpfile
            tmpfile=$(mktemp)
            
            zenity --list \
                --title="Sleep Warning Configuration" \
                --text="Prevent popup window from being moved during minimum display time?\n(Current: ${default_immovable})" \
                --column="Option" --column="Description" \
                --width=500 \
                --height=250 \
                "true" "Prevent window movement (recommended)" \
                "false" "Allow window movement" \
                --hide-column=2 \
                --print-column=1 \
                > "${tmpfile}" 2>/dev/null
            local exit_code=$?
            
            immovable=$(cat "${tmpfile}" 2>/dev/null)
            rm -f "${tmpfile}"
            
            # User cancelled
            if [ "${exit_code}" -ne 0 ] || [ -z "${immovable}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            echo "${immovable}"
            return 0
        done
    else
        # Text mode
        echo "" >&2
        echo "Popup Immovable Setting:" >&2
        echo "  Prevents the popup window from being moved during minimum display time" >&2
        echo "  by monitoring and restoring its position if moved." >&2
        echo "" >&2
        while true; do
            read -p "Prevent window movement? [y/n, default: ${default_immovable}]: " choice
            choice=${choice:-${default_immovable}}
            case "${choice}" in
                y|Y|yes|YES|true|TRUE|1)
                    echo "true"
                    return 0
                    ;;
                n|N|no|NO|false|FALSE|0)
                    echo "false"
                    return 0
                    ;;
                "")
                    echo "${default_immovable}"
                    return 0
                    ;;
                *)
                    echo "Invalid choice. Please enter 'y' for yes or 'n' for no." >&2
                    ;;
            esac
        done
    fi
}

# Get popup position from user
get_popup_position_config() {
    local use_gui="$1"
    local default_position="center"
    
    # Try to get existing position from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_position
        existing_position=$(grep -E "^[[:space:]]*POPUP_POSITION=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_position}" ]; then
            default_position="${existing_position}"
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        # GUI mode
        while true; do
            local position
            local tmpfile
            tmpfile=$(mktemp)
            
            zenity --list \
                --title="Sleep Warning Configuration" \
                --text="Select popup position on screen:\n(Current: ${default_position})" \
                --column="Position" \
                --width=500 \
                --height=500 \
                "center" \
                "top-left" \
                "top-right" \
                "bottom-left" \
                "bottom-right" \
                "top-center" \
                "bottom-center" \
                > "${tmpfile}" 2>/dev/null
            local exit_code=$?
            
            position=$(cat "${tmpfile}" 2>/dev/null)
            rm -f "${tmpfile}"
            
            # User cancelled
            if [ "${exit_code}" -ne 0 ] || [ -z "${position}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    continue  # User wants to continue, re-prompt
                fi
            fi
            
            echo "${position}"
            return 0
        done
    else
        # Text mode
        echo "" >&2
        echo "Popup Position Options:" >&2
        echo "  1) center" >&2
        echo "  2) top-left" >&2
        echo "  3) top-right" >&2
        echo "  4) bottom-left" >&2
        echo "  5) bottom-right" >&2
        echo "  6) top-center" >&2
        echo "  7) bottom-center" >&2
        echo "" >&2
        while true; do
            read -p "Select position [1-7, default: ${default_position}]: " choice
            case "${choice}" in
                1|center) echo "center"; return 0 ;;
                2|top-left) echo "top-left"; return 0 ;;
                3|top-right) echo "top-right"; return 0 ;;
                4|bottom-left) echo "bottom-left"; return 0 ;;
                5|bottom-right) echo "bottom-right"; return 0 ;;
                6|top-center) echo "top-center"; return 0 ;;
                7|bottom-center) echo "bottom-center"; return 0 ;;
                "") echo "${default_position}"; return 0 ;;
                *) echo "Invalid choice. Please select 1-7." >&2 ;;
            esac
        done
    fi
}

# Get check interval from user
get_check_interval() {
    local use_gui="$1"
    local default_interval="10"
    
    # Try to get existing interval from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_interval
        existing_interval=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_interval}" ] && [[ "${existing_interval}" =~ ^[0-9]+$ ]]; then
            default_interval="${existing_interval}"
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        # GUI mode
        while true; do
            local interval
            local tmpfile
            tmpfile=$(mktemp)
            
            # Run zenity directly (not in command substitution) and capture exit code
            zenity --entry \
                --title="Sleep Warning Configuration" \
                --text="How often should the system check for restricted hours?\n\nEnter interval in minutes (1-60):" \
                --entry-text="${default_interval}" \
                > "${tmpfile}" 2>/dev/null
            local exit_code=$?
            
            # Read the output
            interval=$(cat "${tmpfile}" 2>/dev/null)
            rm -f "${tmpfile}"
            
            # Check exit code - non-zero means Cancel was clicked
            if [ ${exit_code} -ne 0 ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2
                else
                    continue
                fi
            fi
            
            # Empty input - use default
            if [ -z "${interval}" ]; then
                echo "${default_interval}"
                return 0
            fi
            
            # Validate interval
            if ! [[ "${interval}" =~ ^[0-9]+$ ]] || [ "${interval}" -lt 1 ] || [ "${interval}" -gt 60 ]; then
                zenity --error --text="Invalid interval. Please enter a number between 1 and 60 minutes." 2>/dev/null
                continue
            fi
            
            echo "${interval}"
            return 0
        done
    else
        # Text mode
        while true; do
            read -p "Check interval in minutes (1-60) [${default_interval}]: " interval
            interval=${interval:-${default_interval}}
            
            if [[ "${interval}" =~ ^[0-9]+$ ]] && [ "${interval}" -ge 1 ] && [ "${interval}" -le 60 ]; then
                echo "${interval}"
                return 0
            else
                echo "Invalid interval. Please enter a number between 1 and 60." >&2
            fi
        done
    fi
}

# Convert minutes to systemd OnCalendar format
minutes_to_oncalendar() {
    local minutes="$1"
    
    # Systemd timer format: *:0/N means every N minutes starting from minute 0
    # This works for any N from 1 to 60
    # Examples:
    #   *:0/1  = every minute
    #   *:0/5  = every 5 minutes (at :00, :05, :10, etc.)
    #   *:0/10 = every 10 minutes (at :00, :10, :20, etc.)
    #   *:0/15 = every 15 minutes (at :00, :15, :30, :45)
    echo "*:0/${minutes}"
}

# Update systemd timer file with new interval
update_timer_file() {
    local interval="$1"
    
    # Check if timer file exists
    if [ ! -f "${TIMER_FILE}" ]; then
        # Timer not installed yet, skip
        return 0
    fi
    
    # Convert interval to OnCalendar format
    local oncalendar
    oncalendar=$(minutes_to_oncalendar "${interval}")
    
    # Create backup of timer file
    local backup_file="${TIMER_FILE}.bak"
    cp "${TIMER_FILE}" "${backup_file}" 2>/dev/null
    
    # Update timer file
    local temp_file
    temp_file=$(mktemp)
    
    {
        echo "[Unit]"
        echo "Description=Sleep Warning System Timer - Triggers warning check every ${interval} minutes"
        echo "Documentation=man:systemd.timer(5)"
        echo "Requires=${SERVICE_NAME}.service"
        echo ""
        echo "[Timer]"
        echo "# Run every ${interval} minutes"
        echo "OnCalendar=${oncalendar}"
        echo "# Start immediately if missed"
        echo "Persistent=true"
        echo "# Timer accuracy (can be adjusted)"
        echo "AccuracySec=1min"
        echo ""
        echo "[Install]"
        echo "WantedBy=timers.target"
    } > "${temp_file}"
    
    # Replace timer file
    if mv "${temp_file}" "${TIMER_FILE}" 2>/dev/null; then
        # Always reload systemd daemon to pick up timer file changes
        systemctl --user daemon-reload >/dev/null 2>&1
        
        # Restart timer if it's active to pick up the new schedule
        if systemctl --user is-active "${SERVICE_NAME}.timer" >/dev/null 2>&1; then
            systemctl --user restart "${SERVICE_NAME}.timer" >/dev/null 2>&1
        fi
        rm -f "${backup_file}" 2>/dev/null
        return 0
    else
        # Restore backup on failure
        mv "${backup_file}" "${TIMER_FILE}" 2>/dev/null
        return 1
    fi
}

# Format hour to 12-hour format with AM/PM
format_hour_12h() {
    local hour="$1"
    if [ "${hour}" -eq 0 ]; then
        echo "12:00 AM"
    elif [ "${hour}" -eq 12 ]; then
        echo "12:00 PM"
    elif [ "${hour}" -lt 12 ]; then
        echo "${hour}:00 AM"
    else
        echo "$((hour - 12)):00 PM"
    fi
}

# Format a single range to human-readable format
format_range_human() {
    local range="$1"
    local day_name="$2"
    
    # Handle empty or invalid ranges (e.g., skipped days)
    if [ -z "${range}" ] || [ "${range}" = "(no restrictions)" ] || ! echo "${range}" | grep -qE '^[0-9]+-[0-9]+$'; then
        echo "(no restrictions)"
        return 0
    fi
    
    local start_hour end_hour
    start_hour=$(echo "${range}" | cut -d'-' -f1)
    end_hour=$(echo "${range}" | cut -d'-' -f2)
    
    local start_12h end_12h
    start_12h=$(format_hour_12h "${start_hour}")
    end_12h=$(format_hour_12h "${end_hour}")
    
    # Handle overnight ranges
    if [ "${start_hour}" -gt "${end_hour}" ]; then
        # Get next day name
        local next_day
        case "${day_name}" in
            Sunday) next_day="Monday" ;;
            Monday) next_day="Tuesday" ;;
            Tuesday) next_day="Wednesday" ;;
            Wednesday) next_day="Thursday" ;;
            Thursday) next_day="Friday" ;;
            Friday) next_day="Saturday" ;;
            Saturday) next_day="Sunday" ;;
            *) next_day="next day" ;;
        esac
        echo "${start_12h} → ${end_12h} (${next_day})"
    else
        echo "${start_12h} → ${end_12h}"
    fi
}

# Format multiple ranges to human-readable format
format_ranges_human() {
    local ranges="$1"
    local day_name="$2"
    
    local IFS=','
    local formatted_ranges=()
    for range in ${ranges}; do
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        formatted_ranges+=("$(format_range_human "${range}" "${day_name}")")
    done
    
    # Join with " AND "
    local result=""
    local first=true
    for formatted in "${formatted_ranges[@]}"; do
        if [ "${first}" = "true" ]; then
            result="${formatted}"
            first=false
        else
            result="${result} AND ${formatted}"
        fi
    done
    
    echo "${result}"
}

# Detect overlaps between days
detect_overlaps() {
    local day1_index="$1"
    local day1_ranges="$2"
    local day2_index="$3"
    local day2_ranges="$4"
    
    # Only check if day2 is the next day after day1
    local expected_next=$(( (day1_index + 1) % 7 ))
    if [ "${day2_index}" -ne "${expected_next}" ]; then
        return 1  # Not adjacent days, no overlap possible
    fi
    
    # Check if day1 has overnight range that overlaps with day2's early morning range
    if [ -z "${day1_ranges}" ] || [ -z "${day2_ranges}" ]; then
        return 1  # No overlap if either is empty
    fi
    
    # Extract overnight ranges from day1 (start > end)
    local IFS=','
    for range1 in ${day1_ranges}; do
        range1=$(echo "${range1}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        local start1 end1
        start1=$(echo "${range1}" | cut -d'-' -f1)
        end1=$(echo "${range1}" | cut -d'-' -f2)
        
        # If day1 has overnight range (start > end)
        if [ "${start1}" -gt "${end1}" ]; then
            # Check if day2 has early morning range that overlaps
            for range2 in ${day2_ranges}; do
                range2=$(echo "${range2}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start2 end2
                start2=$(echo "${range2}" | cut -d'-' -f1)
                end2=$(echo "${range2}" | cut -d'-' -f2)
                
                # Check if day2's range overlaps with day1's overnight end
                # day1 overnight: start1 to end1 (e.g., 23-6 means 23:00 to 05:59)
                # day2 early: start2 to end2 (e.g., 0-5 means 00:00 to 04:59)
                # Overlap if: day2 starts before day1's overnight ends
                if [ "${start2}" -lt "${end1}" ]; then
                    echo "${range1}|${range2}|${start2}-${end1}"
                    return 0
                fi
            done
        fi
    done
    
    return 1  # No overlap found
}

# Show help dialog
show_help_dialog() {
    local use_gui="$1"
    
    local help_text="TIME RANGE CONFIGURATION HELP

SINGLE RANGE:
  Format: START-END
  Example: 0-5
  Meaning: Midnight (00:00) to 4:59 AM on the same day

MULTIPLE RANGES:
  Format: START-END,START-END
  Example: 0-5,22-23
  Meaning: Two separate periods:
    • Midnight to 4:59 AM
    • 10:00 PM to 11:59 PM

OVERNIGHT RANGES (spans midnight):
  Format: START-END (where START > END)
  Example: 23-6
  Meaning: 11:00 PM on the named day to 5:59 AM on the NEXT day
  Example: Monday 23-6 = Monday 11 PM → Tuesday 5:59 AM

OVERLAPPING RANGES:
  If you set Monday 23-5 and Tuesday 0-5:
  • Both cover Tuesday midnight to 4:59 AM
  • Only one warning will be shown (not duplicated)
  • This is harmless but redundant

NAVIGATION:
  • Cancel: Exit without saving (available at any time)
  • Back: Return to previous day's configuration
  • Skip: Skip current day (no restrictions for that day)

EXAMPLES:
  • '0-5' = Midnight to 4:59 AM
  • '22-23' = 10:00 PM to 11:59 PM  
  • '23-6' = 11:00 PM to 5:59 AM (overnight)
  • '0-5,22-23' = Midnight-4:59 AM AND 10 PM-11:59 PM"
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        echo "${help_text}" | zenity --text-info \
            --title="Configuration Help" \
            --width=600 \
            --height=500 \
            --font="monospace" \
            2>/dev/null
    else
        echo ""
        echo "=== CONFIGURATION HELP ==="
        echo "${help_text}"
        echo ""
        read -p "Press Enter to continue..."
    fi
}

# Get hour range for a day (with navigation support)
get_day_hours() {
    local day_name="$1"
    local day_index="$2"
    local use_gui="$3"
    local allow_back="$4"  # true/false - whether back button should be shown
    local allow_cancel="$5"  # true/false - whether cancel should be available
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        # GUI mode
        while true; do
            # Build prompt text with examples
            local prompt_text="Configure restricted hours for ${day_name}:\n\n"
            prompt_text="${prompt_text}Format options:\n"
            prompt_text="${prompt_text}• Single: 0-5 (midnight to 4:59 AM)\n"
            prompt_text="${prompt_text}• Multiple: 0-5,22-23 (two periods)\n"
            prompt_text="${prompt_text}• Overnight: 23-6 (11 PM to 5:59 AM, spans to next day)\n\n"
            prompt_text="${prompt_text}IMPORTANT: Overnight ranges like '23-6' on ${day_name} mean:\n"
            prompt_text="${prompt_text}${day_name} 11:00 PM → Next day 6:00 AM\n\n"
            prompt_text="${prompt_text}(Leave empty to skip this day)"
            
            # Ask for time range (supports single range, multiple ranges, or overnight)
            local range_input
            local tmpfile
            tmpfile=$(mktemp)
            
            zenity --entry \
                --title="Sleep Warning Configuration - ${day_name}" \
                --text="${prompt_text}" \
                --width=550 \
                --extra-button="Help" \
                > "${tmpfile}" 2>/dev/null
            local exit_code=$?
            
            range_input=$(cat "${tmpfile}" 2>/dev/null)
            rm -f "${tmpfile}"
            
            # Handle extra button (Help)
            if [ "${exit_code}" -eq 1 ] && [ "${range_input}" = "Help" ]; then
                show_help_dialog "${use_gui}"
                continue
            fi
            
            # Handle cancel/empty
            if [ "${exit_code}" -ne 0 ] || [ -z "${range_input}" ]; then
                # User cancelled or left empty - show options menu
                local tmpfile
                tmpfile=$(mktemp)
                
                local menu_options=("Skip this day")
                if [ "${allow_back}" = "true" ]; then
                    menu_options+=("Go back to previous day")
                fi
                if [ "${allow_cancel}" = "true" ]; then
                    menu_options+=("Cancel configuration")
                fi
                menu_options+=("Continue configuring")
                
                printf '%s\n' "${menu_options[@]}" | zenity --list \
                    --title="What would you like to do?" \
                    --text="You cancelled or left ${day_name} empty. What would you like to do?" \
                    --column="Option" \
                    --width=350 \
                    --height=200 \
                    > "${tmpfile}" 2>/dev/null
                local menu_exit=$?
                local choice=$(cat "${tmpfile}" 2>/dev/null)
                rm -f "${tmpfile}"
                
                if [ "${menu_exit}" -ne 0 ] || [ -z "${choice}" ]; then
                    # User cancelled the menu - treat as cancel whole config
                    if confirm_cancel "${use_gui}"; then
                        echo "CANCELLED"
                        return 2
                    else
                        continue
                    fi
                fi
                
                case "${choice}" in
                    "Skip this day")
                        if confirm_skip_day "${day_name}" "${use_gui}"; then
                            echo "skip"
                            return 0
                        else
                            continue
                        fi
                        ;;
                    "Go back to previous day")
                        if [ "${allow_back}" = "true" ]; then
                            echo "back"
                            return 2
                        fi
                        continue
                        ;;
                    "Cancel configuration")
                        if [ "${allow_cancel}" = "true" ]; then
                            if confirm_cancel "${use_gui}"; then
                                echo "CANCELLED"
                                return 2
                            else
                                continue
                            fi
                        fi
                        continue
                        ;;
                    "Continue configuring")
                        continue
                        ;;
                    *)
                        continue
                        ;;
                esac
            fi
            
            # Validate the input (could be single range, multiple ranges, or overnight)
            # Check if it's a valid format
            if ! echo "${range_input}" | grep -qE '^([0-9]+-[0-9]+)(,[0-9]+-[0-9]+)*$'; then
                zenity --error --text="Invalid format. Use: START-END or START-END,START-END\n\nExamples:\n• 0-5 (midnight to 4:59 AM)\n• 0-5,22-23 (two periods)\n• 23-6 (11 PM to 5:59 AM, overnight)" 2>/dev/null
                continue
            fi
            
            # Validate each range in the input
            local IFS=','
            local valid=true
            for range in ${range_input}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start_hour end_hour
                start_hour=$(echo "${range}" | cut -d'-' -f1)
                end_hour=$(echo "${range}" | cut -d'-' -f2)
                
                # Validate hour values
                if [ "${start_hour}" -lt 0 ] || [ "${start_hour}" -gt 23 ] || \
                   [ "${end_hour}" -lt 0 ] || [ "${end_hour}" -gt 23 ]; then
                    valid=false
                    break
                fi
                
                # Start and end cannot be equal
                if [ "${start_hour}" -eq "${end_hour}" ]; then
                    valid=false
                    break
                fi
            done
            
            if [ "${valid}" = "false" ]; then
                zenity --error --text="Invalid hour values. Hours must be 0-23, and start cannot equal end." 2>/dev/null
                continue
            fi
            
            # Show preview of what will be restricted
            local preview
            preview=$(format_ranges_human "${range_input}" "${day_name}")
            if zenity --question \
                --title="Confirm Time Range" \
                --text="You entered: ${range_input}\n\nThis means:\n${preview}\n\nIs this correct?" \
                --ok-label="Yes" \
                --cancel-label="No, Edit" \
                2>/dev/null; then
                echo "${range_input}"
                return 0
            fi
            # User wants to edit, continue loop
        done
    else
        # Text mode
        echo "" >&2
        echo "=== Configuring ${day_name} ===" >&2
        echo "" >&2
        echo "IMPORTANT - Overnight ranges:" >&2
        echo "  If you enter '23-6' on ${day_name}, it means:" >&2
        echo "  ${day_name} 11:00 PM → Next day 5:59 AM" >&2
        echo "" >&2
        echo "Format options:" >&2
        echo "  • Single: 0-5 (midnight to 4:59 AM)" >&2
        echo "  • Multiple: 0-5,22-23 (two periods)" >&2
        echo "  • Overnight: 23-6 (11 PM to 5:59 AM, spans to next day)" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  • Enter time range(s) to configure" >&2
        echo "  • Press Enter or type 's' to skip this day" >&2
        if [ "${allow_back}" = "true" ]; then
            echo "  • Type 'back' to go to previous day" >&2
        fi
        if [ "${allow_cancel}" = "true" ]; then
            echo "  • Type 'cancel' to exit without saving" >&2
        fi
        echo "  • Type 'help' for detailed help" >&2
        echo "" >&2
        
        while true; do
            local range_input
            read -p "Time range(s) for ${day_name} (or 's' to skip): " range_input
            
            # Handle special commands
            case "${range_input}" in
                skip|s|S|"")
                    if confirm_skip_day "${day_name}" "${use_gui}"; then
                        echo "skip"
                        return 0
                    else
                        # User wants to continue configuring this day
                        continue
                    fi
                    ;;
                back)
                    if [ "${allow_back}" = "true" ]; then
                        echo "back"
                        return 2  # Special return code for back
                    else
                        echo "Cannot go back from here." >&2
                        continue
                    fi
                    ;;
                cancel)
                    if [ "${allow_cancel}" = "true" ]; then
                        if confirm_cancel "${use_gui}"; then
                            echo "CANCELLED"
                            return 2  # Special return code for cancellation
                        else
                            # User wants to continue
                            continue
                        fi
                    else
                        echo "Type 'skip' to skip this day." >&2
                        continue
                    fi
                    ;;
                help)
                    show_help_dialog "${use_gui}"
                    continue
                    ;;
            esac
            
            # Validate the input format
            if ! echo "${range_input}" | grep -qE '^([0-9]+-[0-9]+)(,[0-9]+-[0-9]+)*$'; then
                echo "Error: Invalid format. Use: START-END or START-END,START-END" >&2
                echo "Examples: 0-5 or 0-5,22-23 or 23-6" >&2
                continue
            fi
            
            # Validate each range
            local IFS=','
            local valid=true
            for range in ${range_input}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start_hour end_hour
                start_hour=$(echo "${range}" | cut -d'-' -f1)
                end_hour=$(echo "${range}" | cut -d'-' -f2)
                
                # Validate hour values
                if [ "${start_hour}" -lt 0 ] || [ "${start_hour}" -gt 23 ] || \
                   [ "${end_hour}" -lt 0 ] || [ "${end_hour}" -gt 23 ]; then
                    valid=false
                    break
                fi
                
                # Start and end cannot be equal
                if [ "${start_hour}" -eq "${end_hour}" ]; then
                    valid=false
                    break
                fi
            done
            
            if [ "${valid}" = "false" ]; then
                echo "Error: Invalid hour values. Hours must be 0-23, and start cannot equal end." >&2
                continue
            fi
            
            # Show preview
            local preview
            preview=$(format_ranges_human "${range_input}" "${day_name}")
            echo "" >&2
            echo "Preview: ${preview}" >&2
            echo "" >&2
            read -p "Is this correct? [Y/n]: " confirm
            case "${confirm}" in
                [Nn]*)
                    echo "Please re-enter the time range." >&2
                    continue
                    ;;
                *)
                    echo "${range_input}"
                    return 0
                    ;;
            esac
        done
    fi
}

# Show welcome message
show_welcome() {
    local use_gui="$1"
    
    local message="Welcome to the Sleep Warning Configuration Wizard!

This wizard will help you set up restricted hours for each day of the week.
During these hours, you will receive warning popups if you use your computer.

NAVIGATION:
• You can cancel at any time (changes won't be saved)
• You can go back to previous days to edit
• You can skip days to have no restrictions

TIME RANGE FORMATS:
• Single: '0-5' = Midnight to 4:59 AM
• Multiple: '0-5,22-23' = Two periods (midnight-4:59 AM AND 10 PM-11:59 PM)
• Overnight: '23-6' = 11 PM to 5:59 AM (spans midnight to next day)

IMPORTANT - Overnight Ranges:
If you enter '23-6' on Monday, it means:
  Monday 11:00 PM → Tuesday 5:59 AM

This spans across midnight to the next day. If you also set Tuesday 0-5,
both will cover Tuesday midnight-4:59 AM (redundant but harmless).

Examples:
• '0-5' = Midnight to 4:59 AM (same day)
• '22-23' = 10:00 PM to 11:59 PM (same day)
• '23-6' = 11:00 PM to 5:59 AM (overnight, spans to next day)
• '0-5,22-23' = Midnight-4:59 AM AND 10 PM-11:59 PM

Let's get started!"
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        zenity --info \
            --title="Sleep Warning Configuration" \
            --text="${message}" \
            --width=500 \
            2>/dev/null
    else
        echo "${message}"
        echo ""
        read -p "Press Enter to continue..."
    fi
}

# Ask if user wants to configure weekdays together
ask_weekday_together() {
    local use_gui="$1"
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        zenity --question \
            --title="Sleep Warning Configuration" \
            --text="Would you like to use the same restricted hours for all weekdays (Monday-Friday)?" \
            --ok-label="Yes" \
            --cancel-label="No" \
            2>/dev/null
        return $?
    else
        read -p "Use same hours for all weekdays (Monday-Friday)? [y/N]: " answer
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Ask if user wants to configure weekends together
ask_weekend_together() {
    local use_gui="$1"
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        zenity --question \
            --title="Sleep Warning Configuration" \
            --text="Would you like to use the same restricted hours for both weekend days (Saturday and Sunday)?" \
            --ok-label="Yes" \
            --cancel-label="No" \
            2>/dev/null
        return $?
    else
        read -p "Use same hours for both weekend days (Saturday and Sunday)? [y/N]: " answer
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Configure weekdays section
configure_weekdays_section() {
    local use_gui="$1"
    local -n config_lines_ref="$2"  # Pass by reference
    local -n summary_lines_ref="$3"  # Pass by reference
    
    # Ask if configure together or separately
    if ask_weekday_together "${use_gui}"; then
        # Configure all weekdays together
        local weekday_range
        weekday_range=$(get_day_hours "Weekdays (Monday-Friday)" 1 "${use_gui}" "false" "true")
        local exit_code=$?
        
        if [ "${weekday_range}" = "CANCELLED" ]; then
            return 2  # Cancelled
        elif [ "${weekday_range}" != "skip" ]; then
            # Apply to all weekdays (indices 1-5: Monday-Friday)
            for i in 1 2 3 4 5; do
                config_lines_ref[${i}]="${DAY_VARS[${i}]}=${weekday_range}"
                summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: ${weekday_range}"
            done
        else
            # Explicitly skipped - mark all weekdays as skipped (no restrictions)
            for i in 1 2 3 4 5; do
                config_lines_ref[${i}]="${DAY_VARS[${i}]}="
                summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: (no restrictions)"
            done
        fi
        return 0
    else
        # Configure each weekday separately
        local i=1  # Start with Monday
        while [ "${i}" -le 5 ]; do  # Monday through Friday
            local allow_back="false"
            if [ "${i}" -gt 1 ]; then
                allow_back="true"  # Allow back from Tuesday onwards
            fi
            
            local range
            range=$(get_day_hours "${DAY_NAMES[${i}]}" "${i}" "${use_gui}" "${allow_back}" "true")
            local exit_code=$?
            
            if [ "${range}" = "CANCELLED" ]; then
                return 2  # Cancelled
            elif [ "${range}" = "back" ] || [ ${exit_code} -eq 2 ]; then
                # User wants to go back
                if [ "${i}" -gt 1 ]; then
                    i=$((i - 1))  # Go back to previous day
                    # Remove previous day's entry if it was set
                    unset config_lines_ref[${i}]
                    unset summary_lines_ref[${i}]
                else
                    # Back from first day - return to main menu
                    return 0
                fi
                # Continue loop to re-prompt previous day
            elif [ "${range}" != "skip" ]; then
                config_lines_ref[${i}]="${DAY_VARS[${i}]}=${range}"
                summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: ${range}"
                i=$((i + 1))  # Move to next day
            else
                # Explicitly skipped - mark as skipped (no restrictions)
                config_lines_ref[${i}]="${DAY_VARS[${i}]}="
                summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: (no restrictions)"
                i=$((i + 1))  # Skip this day, move to next
            fi
        done
        return 0
    fi
}

# Configure weekends section
configure_weekends_section() {
    local use_gui="$1"
    local -n config_lines_ref="$2"  # Pass by reference
    local -n summary_lines_ref="$3"  # Pass by reference
    
    # Ask if configure together or separately
    if ask_weekend_together "${use_gui}"; then
        # Configure both weekend days together
        local weekend_range
        weekend_range=$(get_day_hours "Weekends (Saturday and Sunday)" 6 "${use_gui}" "false" "true")
        local exit_code=$?
        
        if [ "${weekend_range}" = "CANCELLED" ]; then
            return 2  # Cancelled
        elif [ "${weekend_range}" != "skip" ]; then
            # Apply to both weekend days (Saturday=6, Sunday=0)
            config_lines_ref[6]="${DAY_VARS[6]}=${weekend_range}"
            summary_lines_ref[6]="${DAY_NAMES[6]}: ${weekend_range}"
            config_lines_ref[0]="${DAY_VARS[0]}=${weekend_range}"
            summary_lines_ref[0]="${DAY_NAMES[0]}: ${weekend_range}"
        else
            # Explicitly skipped - mark both weekend days as skipped (no restrictions)
            config_lines_ref[6]="${DAY_VARS[6]}="
            summary_lines_ref[6]="${DAY_NAMES[6]}: (no restrictions)"
            config_lines_ref[0]="${DAY_VARS[0]}="
            summary_lines_ref[0]="${DAY_NAMES[0]}: (no restrictions)"
        fi
        return 0
    else
        # Configure Saturday and Sunday separately
        local weekend_day=6  # Start with Saturday
        while true; do
            local allow_back="false"
            if [ "${weekend_day}" -eq 0 ]; then
                allow_back="true"  # Allow back from Sunday to Saturday
            fi
            
            local range
            range=$(get_day_hours "${DAY_NAMES[${weekend_day}]}" "${weekend_day}" "${use_gui}" "${allow_back}" "true")
            local exit_code=$?
            
            if [ "${range}" = "CANCELLED" ]; then
                return 2  # Cancelled
            elif [ "${range}" = "back" ] || [ ${exit_code} -eq 2 ]; then
                # User wants to go back
                if [ "${weekend_day}" -eq 0 ]; then
                    weekend_day=6  # Go back to Saturday
                    # Remove Saturday's entry if it was set
                    unset config_lines_ref[6]
                    unset summary_lines_ref[6]
                else
                    # Back from Saturday - return to main menu
                    return 0
                fi
                # Continue loop to re-prompt previous day
            elif [ "${range}" != "skip" ]; then
                config_lines_ref[${weekend_day}]="${DAY_VARS[${weekend_day}]}=${range}"
                summary_lines_ref[${weekend_day}]="${DAY_NAMES[${weekend_day}]}: ${range}"
                if [ "${weekend_day}" -eq 6 ]; then
                    weekend_day=0  # Move to Sunday
                else
                    break  # Done with both weekend days
                fi
            else
                # Explicitly skipped - mark as skipped (no restrictions)
                config_lines_ref[${weekend_day}]="${DAY_VARS[${weekend_day}]}="
                summary_lines_ref[${weekend_day}]="${DAY_NAMES[${weekend_day}]}: (no restrictions)"
                if [ "${weekend_day}" -eq 6 ]; then
                    weekend_day=0  # Skip Saturday, move to Sunday
                else
                    break  # Done with both weekend days
                fi
            fi
        done
        return 0
    fi
}

# Get inherited overnight restrictions from previous day
# Returns formatted string if inherited restrictions exist, empty string otherwise
get_inherited_restrictions() {
    local day_index="$1"
    local -n summary_ref="$2"  # Use different name to avoid circular reference
    
    # Get previous day index (wrapping around: Sunday (0) checks Saturday (6))
    local prev_day_index
    if [ "${day_index}" -eq 0 ]; then
        prev_day_index=6  # Sunday checks Saturday
    else
        prev_day_index=$((day_index - 1))
    fi
    
    # Check if previous day has restrictions
    if [ -z "${summary_ref[${prev_day_index}]}" ]; then
        return 1  # No previous day restrictions
    fi
    
    local prev_line="${summary_ref[${prev_day_index}]}"
    local prev_range
    prev_range=$(echo "${prev_line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Check if previous day is skipped or has no restrictions
    if [ "${prev_range}" = "(no restrictions)" ] || [ -z "${prev_range}" ]; then
        return 1  # No restrictions to inherit
    fi
    
    # Check for overnight ranges in previous day (start > end)
    local IFS=','
    local inherited_ranges=()
    for range in ${prev_range}; do
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        local start_hour end_hour
        start_hour=$(echo "${range}" | cut -d'-' -f1)
        end_hour=$(echo "${range}" | cut -d'-' -f2)
        
        # If this is an overnight range (start > end), it extends into current day
        if [ "${start_hour}" -gt "${end_hour}" ]; then
            # Format the inherited portion: 0-end_hour on current day
            local inherited_start="0"
            local inherited_end="${end_hour}"
            local inherited_range="${inherited_start}-${inherited_end}"
            inherited_ranges+=("${inherited_range}")
        fi
    done
    
    # If we found inherited ranges, format them
    if [ ${#inherited_ranges[@]} -gt 0 ]; then
        local current_day_name="${DAY_NAMES[${day_index}]}"
        local formatted_ranges=()
        for inherited_range in "${inherited_ranges[@]}"; do
            local inherited_end
            inherited_end=$(echo "${inherited_range}" | cut -d'-' -f2)
            local start_12h end_12h
            start_12h=$(format_hour_12h "0")
            end_12h=$(format_hour_12h "${inherited_end}")
            formatted_ranges+=("${start_12h} → ${end_12h}")
        done
        
        # Join multiple inherited ranges with " AND "
        local result=""
        local first=true
        for formatted in "${formatted_ranges[@]}"; do
            if [ "${first}" = "true" ]; then
                result="${formatted}"
                first=false
            else
                result="${result} AND ${formatted}"
            fi
        done
        
        echo "${result} (inherited)"
        return 0
    fi
    
    return 1  # No inherited restrictions
}

# Show visual grid of all days with their time restrictions
show_visual_grid() {
    local use_gui="$1"
    local -n config_lines_ref="$2"  # Pass by reference
    local -n summary_lines_ref="$3"  # Pass by reference
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        # GUI mode
        while true; do
            local tmpfile
            tmpfile=$(mktemp)
            
            # Build grid data for zenity list
            # Store day names and time ranges separately, then combine with pipe
            local day_names=()
            local time_ranges_list=()
            
            for day_index in 0 1 2 3 4 5 6; do
                local day_name="${DAY_NAMES[${day_index}]}"
                local time_ranges=""
                
                if [ -n "${summary_lines_ref[${day_index}]}" ]; then
                    # Day has configuration (may be restricted or explicitly skipped)
                    local line="${summary_lines_ref[${day_index}]}"
                    local range
                    range=$(echo "${line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    
                    if [ "${range}" = "(no restrictions)" ] || [ -z "${range}" ]; then
                        # No explicit restrictions - check for inherited overnight restrictions
                        local inherited
                        inherited=$(get_inherited_restrictions "${day_index}" summary_lines_ref)
                        if [ $? -eq 0 ] && [ -n "${inherited}" ]; then
                            time_ranges="${inherited}"
                        else
                            time_ranges="(no restrictions)"
                        fi
                    else
                        # Has restrictions - show formatted time ranges
                        time_ranges=$(format_ranges_human "${range}" "${day_name}")
                    fi
                else
                    # Day has no configuration - check for inherited overnight restrictions
                    local inherited
                    inherited=$(get_inherited_restrictions "${day_index}" summary_lines_ref)
                    if [ $? -eq 0 ] && [ -n "${inherited}" ]; then
                        time_ranges="${inherited}"
                    else
                        time_ranges="(no restrictions)"
                    fi
                fi
                
                # Store separately
                day_names+=("${day_name}")
                time_ranges_list+=("${time_ranges}")
            done
            
            # Add "Back to Menu" option
            day_names+=("<<BACK>>")
            time_ranges_list+=("Back to Main Menu")
            
            # Build pipe-separated lines manually
            local grid_data=()
            for i in "${!day_names[@]}"; do
                grid_data+=("${day_names[${i}]}|${time_ranges_list[${i}]}")
            done
            
            # Debug: Log what we're sending to zenity (if DEBUG_GRID is set)
            if [ -n "${DEBUG_GRID:-}" ]; then
                echo "DEBUG: Grid data array contents:" >&2
                for i in "${!grid_data[@]}"; do
                    echo "  [${i}]: '${grid_data[${i}]}'" >&2
                done
                echo "DEBUG: Sending to zenity (pipe-separated):" >&2
                printf '%s\n' "${grid_data[@]}" >&2
            fi
            
            # Display grid using zenity
            # Use two columns: Day (with status indicator) and Time Ranges
            # zenity --list expects data as separate arguments, alternating between columns
            # For 2 columns, format is: col1_row1 col2_row1 col1_row2 col2_row2 ...
            local zenity_data=()
            for i in "${!day_names[@]}"; do
                zenity_data+=("${day_names[${i}]}")
                zenity_data+=("${time_ranges_list[${i}]}")
            done
            
            if [ -n "${DEBUG_GRID:-}" ]; then
                echo "DEBUG: Zenity data array (alternating Day, Time):" >&2
                for i in "${!zenity_data[@]}"; do
                    echo "  [${i}]: '${zenity_data[${i}]}'" >&2
                done
            fi
            
            # Pass data as separate arguments - zenity will group them into rows
            zenity --list \
                --title="Visual Day/Time Grid" \
                --text="Select a day to edit its restricted hours:" \
                --column="Day" --column="Time Ranges" \
                --width=800 \
                --height=450 \
                --print-column=1 \
                "${zenity_data[@]}" \
                > "${tmpfile}" 2>/dev/null
            local exit_code=$?
            
            local selected=$(cat "${tmpfile}" 2>/dev/null)
            rm -f "${tmpfile}"
            
            if [ -n "${DEBUG_GRID:-}" ]; then
                echo "DEBUG: zenity exit code: ${exit_code}" >&2
                echo "DEBUG: Selected value: '${selected}'" >&2
            fi
            
            if [ "${exit_code}" -ne 0 ] || [ -z "${selected}" ]; then
                # User cancelled - return to main menu
                declare -g grid_result_var="BACK"
                return 0
            fi
            
            # Extract day name from selection
            # With --print-column=1, we get just the Day column (first column)
            local selected_day
            selected_day=$(echo "${selected}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Check if "Back to Menu" was selected
            if [ "${selected_day}" = "<<BACK>>" ]; then
                declare -g grid_result_var="BACK"
                return 0
            fi
            
            # Find day index
            local day_index=-1
            for i in 0 1 2 3 4 5 6; do
                if [ "${DAY_NAMES[${i}]}" = "${selected_day}" ]; then
                    day_index=${i}
                    break
                fi
            done
            
            if [ "${day_index}" -lt 0 ]; then
                # Invalid selection
                zenity --error --text="Invalid day selection." 2>/dev/null
                continue
            fi
            
            # Store day index in global variable
            declare -g grid_result_var="${day_index}"
            return 0
        done
    else
        # Text mode
        while true; do
            echo ""
            echo "=== Visual Day/Time Grid ==="
            echo ""
            echo "Select a day to edit its restricted hours:"
            echo ""
            
            # Display grid with tab-separated table format
            for day_index in 0 1 2 3 4 5 6; do
                local day_name="${DAY_NAMES[${day_index}]}"
                local time_ranges=""
                
                if [ -n "${summary_lines_ref[${day_index}]}" ]; then
                    # Day has configuration
                    local line="${summary_lines_ref[${day_index}]}"
                    local range
                    range=$(echo "${line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    
                    if [ "${range}" = "(no restrictions)" ] || [ -z "${range}" ]; then
                        # No explicit restrictions - check for inherited overnight restrictions
                        local inherited
                        inherited=$(get_inherited_restrictions "${day_index}" summary_lines_ref)
                        if [ $? -eq 0 ] && [ -n "${inherited}" ]; then
                            time_ranges="${inherited}"
                        else
                            time_ranges="(no restrictions)"
                        fi
                    else
                        # Has restrictions - show formatted time ranges
                        time_ranges=$(format_ranges_human "${range}" "${day_name}")
                    fi
                else
                    # Day has no configuration - check for inherited overnight restrictions
                    local inherited
                    inherited=$(get_inherited_restrictions "${day_index}" summary_lines_ref)
                    if [ $? -eq 0 ] && [ -n "${inherited}" ]; then
                        time_ranges="${inherited}"
                    else
                        time_ranges="(no restrictions)"
                    fi
                fi
                
                # Display as table: number, day name (tab-separated), time ranges
                printf "%d.\t%-9s\t%s\n" $((day_index + 1)) "${day_name}:" "${time_ranges}"
            done
            
            echo ""
            echo "0. Back to Main Menu"
            echo ""
            
            while true; do
                read -p "Select option [0-7]: " choice
                    case "${choice}" in
                    0)
                        declare -g grid_result_var="BACK"
                        return 0
                        ;;
                    1|2|3|4|5|6|7)
                        # Convert to day index (1-7 -> 0-6)
                        local day_index=$((choice - 1))
                        declare -g grid_result_var="${day_index}"
                        return 0
                        ;;
                    *)
                        echo "Invalid option. Please enter 0-7." >&2
                        ;;
                    esac
            done
        done
    fi
}

# Configure a day from the visual grid
configure_day_from_grid() {
    local day_index="$1"
    local use_gui="$2"
    local -n config_lines_ref="$3"  # Pass by reference
    local -n summary_lines_ref="$4"  # Pass by reference
    
    # Validate day index
    if [ "${day_index}" -lt 0 ] || [ "${day_index}" -gt 6 ]; then
        return 1
    fi
    
    local day_name="${DAY_NAMES[${day_index}]}"
    local range=""
    local exit_code=0
    
    # Determine if weekday or weekend
    if [ "${day_index}" -ge 1 ] && [ "${day_index}" -le 5 ]; then
        # Weekday (Monday-Friday, indices 1-5)
        if ask_weekday_together "${use_gui}"; then
            # Apply to all weekdays
            range=$(get_day_hours "Weekdays (Monday-Friday)" 1 "${use_gui}" "false" "true")
            exit_code=$?
            
            if [ "${range}" = "CANCELLED" ]; then
                return 2
            elif [ "${range}" != "skip" ]; then
                # Apply to all weekdays (indices 1-5)
                for i in 1 2 3 4 5; do
                    config_lines_ref[${i}]="${DAY_VARS[${i}]}=${range}"
                    summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: ${range}"
                done
            else
                # Explicitly skipped - mark all weekdays as skipped
                for i in 1 2 3 4 5; do
                    config_lines_ref[${i}]="${DAY_VARS[${i}]}="
                    summary_lines_ref[${i}]="${DAY_NAMES[${i}]}: (no restrictions)"
                done
            fi
        else
            # Edit single weekday
            range=$(get_day_hours "${day_name}" "${day_index}" "${use_gui}" "false" "true")
            exit_code=$?
            
            if [ "${range}" = "CANCELLED" ]; then
                return 2
            elif [ "${range}" != "skip" ]; then
                config_lines_ref[${day_index}]="${DAY_VARS[${day_index}]}=${range}"
                summary_lines_ref[${day_index}]="${day_name}: ${range}"
            else
                # Explicitly skipped
                config_lines_ref[${day_index}]="${DAY_VARS[${day_index}]}="
                summary_lines_ref[${day_index}]="${day_name}: (no restrictions)"
            fi
        fi
    elif [ "${day_index}" -eq 0 ] || [ "${day_index}" -eq 6 ]; then
        # Weekend day (Sunday=0, Saturday=6)
        if ask_weekend_together "${use_gui}"; then
            # Apply to both weekend days
            range=$(get_day_hours "Weekends (Saturday and Sunday)" 6 "${use_gui}" "false" "true")
            exit_code=$?
            
            if [ "${range}" = "CANCELLED" ]; then
                return 2
            elif [ "${range}" != "skip" ]; then
                # Apply to both weekend days
                config_lines_ref[6]="${DAY_VARS[6]}=${range}"
                summary_lines_ref[6]="${DAY_NAMES[6]}: ${range}"
                config_lines_ref[0]="${DAY_VARS[0]}=${range}"
                summary_lines_ref[0]="${DAY_NAMES[0]}: ${range}"
            else
                # Explicitly skipped - mark both weekend days as skipped
                config_lines_ref[6]="${DAY_VARS[6]}="
                summary_lines_ref[6]="${DAY_NAMES[6]}: (no restrictions)"
                config_lines_ref[0]="${DAY_VARS[0]}="
                summary_lines_ref[0]="${DAY_NAMES[0]}: (no restrictions)"
            fi
        else
            # Edit single weekend day
            range=$(get_day_hours "${day_name}" "${day_index}" "${use_gui}" "false" "true")
            exit_code=$?
            
            if [ "${range}" = "CANCELLED" ]; then
                return 2
            elif [ "${range}" != "skip" ]; then
                config_lines_ref[${day_index}]="${DAY_VARS[${day_index}]}=${range}"
                summary_lines_ref[${day_index}]="${day_name}: ${range}"
            else
                # Explicitly skipped
                config_lines_ref[${day_index}]="${DAY_VARS[${day_index}]}="
                summary_lines_ref[${day_index}]="${day_name}: (no restrictions)"
            fi
        fi
    fi
    
    return ${exit_code}
}

# Show summary and confirm (with overlap detection and human-readable times)
show_summary() {
    local use_gui="$1"
    local check_interval="$2"
    local popup_size="$3"
    local popup_position="$4"
    local min_display_time="$5"
    local popup_immovable="$6"
    # Note: summary_lines must be accessed from global scope to preserve sparse array indices
    # Passing sparse arrays as parameters re-indexes them from 0, causing display bugs
    
    # Build summary with human-readable time periods
    local summary="Configuration Summary:\n\n"
    summary="${summary}Check Interval: Every ${check_interval} minute(s)\n"
    summary="${summary}Popup Size: ${popup_size}\n"
    summary="${summary}Popup Position: ${popup_position}\n"
    if [ "${min_display_time}" -eq 0 ]; then
        summary="${summary}Minimum Display Time: Disabled\n"
    else
        summary="${summary}Minimum Display Time: ${min_display_time} seconds\n"
    fi
    if [ "${popup_immovable}" = "true" ]; then
        summary="${summary}Prevent Window Movement: Enabled\n"
    else
        summary="${summary}Prevent Window Movement: Disabled\n"
    fi
    summary="${summary}\nRestricted Hours:\n"
    
    # Check for overlaps and format times
    local overlap_warnings=()
    
    # Iterate through all days in calendar order (Sun-Sat, indices 0-6)
    for day_index in 0 1 2 3 4 5 6; do
        local day_name="${DAY_NAMES[${day_index}]}"
        
        if [ -n "${summary_lines[${day_index}]}" ]; then
            # Day has restrictions configured (or explicitly skipped)
            local line="${summary_lines[${day_index}]}"
            # Extract day name and range
            local range
            range=$(echo "${line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Check if this is a skipped day (no restrictions)
            if [ "${range}" = "(no restrictions)" ] || [ -z "${range}" ]; then
                summary="${summary}• ${day_name}: No restrictions\n"
            else
                # Format to human-readable
                local formatted
                formatted=$(format_ranges_human "${range}" "${day_name}")
                summary="${summary}• ${day_name}: ${formatted}\n"
                
                # Check for overlaps with previous calendar day
                local prev_day_index
                if [ "${day_index}" -eq 0 ]; then
                    # Sunday (0) - check overlap with Saturday (6)
                    prev_day_index=6
                else
                    prev_day_index=$((day_index - 1))
                fi
                
                if [ -n "${summary_lines[${prev_day_index}]}" ]; then
                    local prev_line="${summary_lines[${prev_day_index}]}"
                    local prev_day_name prev_range
                    prev_day_name=$(echo "${prev_line}" | cut -d':' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    prev_range=$(echo "${prev_line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    
                    # Only check overlaps if previous day is not skipped
                    if [ "${prev_range}" != "(no restrictions)" ] && [ -n "${prev_range}" ]; then
                        local overlap
                        overlap=$(detect_overlaps "${prev_day_index}" "${prev_range}" "${day_index}" "${range}")
                        if [ $? -eq 0 ]; then
                            local range1 range2 overlap_hours
                            range1=$(echo "${overlap}" | cut -d'|' -f1)
                            range2=$(echo "${overlap}" | cut -d'|' -f2)
                            overlap_hours=$(echo "${overlap}" | cut -d'|' -f3)
                            overlap_warnings+=("${prev_day_name} ${range1} and ${day_name} ${range2} both cover ${overlap_hours}")
                        fi
                    fi
                fi
            fi
        else
            # Day has no restrictions configured
            summary="${summary}• ${day_name}: No restrictions\n"
        fi
    done
    
    # Add overlap warnings if any
    if [ ${#overlap_warnings[@]} -gt 0 ]; then
        summary="${summary}\n⚠️  OVERLAP WARNING:\n"
        for warning in "${overlap_warnings[@]}"; do
            summary="${summary}• ${warning}\n"
        done
        summary="${summary}\n(Overlaps are harmless - only one warning shown)\n"
    fi
    
    summary="${summary}\n\nSave this configuration?"
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        zenity --question \
            --title="Sleep Warning Configuration" \
            --text="${summary}" \
            --ok-label="Yes, Save" \
            --cancel-label="Cancel" \
            --width=400 \
            2>/dev/null
        return $?
    else
        echo ""
        echo "=== Configuration Summary ==="
        echo ""
        echo "Check Interval: Every ${check_interval} minute(s)"
        echo "Popup Size: ${popup_size}"
        echo "Popup Position: ${popup_position}"
        if [ "${min_display_time}" -eq 0 ]; then
            echo "Minimum Display Time: Disabled"
        else
            echo "Minimum Display Time: ${min_display_time} seconds"
        fi
        if [ "${popup_immovable}" = "true" ]; then
            echo "Prevent Window Movement: Enabled"
        else
            echo "Prevent Window Movement: Disabled"
        fi
        echo ""
        echo "Restricted Hours:"
        
        # Show human-readable times and check for overlaps
        local text_overlap_warnings=()
        
        # Iterate through all days in calendar order (Sun-Sat, indices 0-6)
        for day_index in 0 1 2 3 4 5 6; do
            local day_name="${DAY_NAMES[${day_index}]}"
            
            if [ -n "${summary_lines[${day_index}]}" ]; then
                # Day has restrictions configured (or explicitly skipped)
                local line="${summary_lines[${day_index}]}"
                # Extract range
                local range
                range=$(echo "${line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                # Check if this is a skipped day (no restrictions)
                if [ "${range}" = "(no restrictions)" ] || [ -z "${range}" ]; then
                    echo "  • ${day_name}: No restrictions"
                else
                    # Format to human-readable
                    local formatted
                    formatted=$(format_ranges_human "${range}" "${day_name}")
                    echo "  • ${day_name}: ${formatted}"
                    
                    # Check for overlaps with previous calendar day
                    local prev_day_index
                    if [ "${day_index}" -eq 0 ]; then
                        # Sunday (0) - check overlap with Saturday (6)
                        prev_day_index=6
                    else
                        prev_day_index=$((day_index - 1))
                    fi
                    
                    if [ -n "${summary_lines[${prev_day_index}]}" ]; then
                        local prev_line="${summary_lines[${prev_day_index}]}"
                        local prev_day_name prev_range
                        prev_day_name=$(echo "${prev_line}" | cut -d':' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        prev_range=$(echo "${prev_line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        
                        # Only check overlaps if previous day is not skipped
                        if [ "${prev_range}" != "(no restrictions)" ] && [ -n "${prev_range}" ]; then
                            local overlap
                            overlap=$(detect_overlaps "${prev_day_index}" "${prev_range}" "${day_index}" "${range}")
                            if [ $? -eq 0 ]; then
                                local range1 range2 overlap_hours
                                range1=$(echo "${overlap}" | cut -d'|' -f1)
                                range2=$(echo "${overlap}" | cut -d'|' -f2)
                                overlap_hours=$(echo "${overlap}" | cut -d'|' -f3)
                                text_overlap_warnings+=("${prev_day_name} ${range1} and ${day_name} ${range2} both cover ${overlap_hours}")
                            fi
                        fi
                    fi
                fi
            else
                # Day has no restrictions configured
                echo "  • ${day_name}: No restrictions"
            fi
        done
        
        # Show overlap warnings if any
        if [ ${#text_overlap_warnings[@]} -gt 0 ]; then
            echo ""
            echo "⚠️  OVERLAP WARNING:"
            for warning in "${text_overlap_warnings[@]}"; do
                echo "  • ${warning}"
            done
            echo "  (Overlaps are harmless - only one warning shown)"
        fi
        
        echo ""
        read -p "Save this configuration? [y/N]: " answer
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Extract user comments from existing config file
extract_user_comments() {
    local existing_file="$1"
    local user_comments=()
    
    if [ ! -f "${existing_file}" ]; then
        return 0
    fi
    
    # Standard header patterns to skip
    local skip_patterns=(
        "^# Sleep Warning Configuration"
        "^# Format:"
        "^# Hours are in 24-hour format"
        "^# Multiple ranges can be specified"
        "^# Leave a day empty"
        "^# CHECK_INTERVAL:"
        "^# POPUP_SIZE:"
        "^# POPUP_POSITION:"
        "^# POPUP_MIN_DISPLAY_TIME:"
        "^# Default:"
        "^# Minimum:"
        "^# Maximum:"
        "^# Options:"
        "^# Note:"
        "^CHECK_INTERVAL="
        "^POPUP_SIZE="
        "^POPUP_POSITION="
        "^POPUP_MIN_DISPLAY_TIME="
        "^# This file was generated"
        "^# *$"  # Empty comment lines
    )
    
    # Read existing file line by line
    while IFS= read -r line; do
        # Only process comment lines
        if [[ "${line}" =~ ^[[:space:]]*# ]]; then
            local should_skip=0
            
            # Check if this is a standard header line
            for pattern in "${skip_patterns[@]}"; do
                if [[ "${line}" =~ ${pattern} ]]; then
                    should_skip=1
                    break
                fi
            done
            
            # If not a standard header line, preserve it
            if [ "${should_skip}" -eq 0 ]; then
                user_comments+=("${line}")
            fi
        fi
    done < "${existing_file}"
    
    # Print user comments (one per line, separated by newlines for array)
    if [ ${#user_comments[@]} -gt 0 ]; then
        printf '%s\n' "${user_comments[@]}"
    fi
}

# Write configuration file
write_config() {
    local check_interval="$1"
    local popup_size="$2"
    local popup_position="$3"
    local min_display_time="$4"
    local popup_immovable="$5"
    shift 5
    local config_lines=("$@")
    
    # Create config directory if it doesn't exist
    mkdir -p "${CONFIG_DIR}"
    
    # Extract user comments from existing file
    local user_comments
    user_comments=$(extract_user_comments "${CONFIG_FILE}")
    
    # Write configuration file
    {
        # Standard header
        echo "# Sleep Warning Configuration"
        echo "# Format: DAY=START_HOUR-END_HOUR"
        echo "# Hours are in 24-hour format (0-23)"
        echo "# Multiple ranges can be specified per day (comma-separated)"
        echo "# Leave a day empty or omit it to have no restrictions for that day"
        echo "#"
        echo "# CHECK_INTERVAL: How often to check for restricted hours (in minutes)"
        echo "# Default: 10 minutes"
        echo "# Minimum: 1 minute"
        echo "# Maximum: 60 minutes"
        echo "CHECK_INTERVAL=${check_interval}"
        echo "#"
        echo "# POPUP_SIZE: Size of warning popup (small, medium, large, or custom WIDTHxHEIGHT)"
        echo "# Default: medium"
        echo "POPUP_SIZE=${popup_size}"
        echo "#"
        echo "# POPUP_POSITION: Position of warning popup on screen"
        echo "# Default: center"
        echo "POPUP_POSITION=${popup_position}"
        echo "#"
        echo "# POPUP_MIN_DISPLAY_TIME: Minimum time popup must be visible before it can be closed (in seconds)"
        echo "# Default: 30 seconds"
        echo "POPUP_MIN_DISPLAY_TIME=${min_display_time}"
        echo "#"
        echo "# POPUP_IMMOVABLE: Prevent popup window from being moved during minimum display time"
        echo "# Default: true"
        echo "POPUP_IMMOVABLE=${popup_immovable}"
        echo "#"
        echo "# This file was generated by the configuration wizard on $(date)"
        
        # Preserve user comments if any
        if [ -n "${user_comments}" ]; then
            echo ""
            echo "# User comments (preserved from previous configuration):"
            echo "${user_comments}"
        fi
        
        echo ""
        
        # Write configuration lines in calendar order (Sun-Sat, indices 0-6)
        for day_index in 0 1 2 3 4 5 6; do
            if [ -n "${config_lines[${day_index}]}" ]; then
                # Write the line (includes empty values for explicitly skipped days)
                echo "${config_lines[${day_index}]}"
            fi
        done
    } > "${CONFIG_FILE}"
    
    if [ $? -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Show success message
show_success() {
    local use_gui="$1"
    local check_interval="$2"
    
    local message="Configuration saved successfully!

Your settings have been saved to:
${CONFIG_FILE}

Check interval: Every ${check_interval} minute(s)

All settings (restricted hours, popup size, position, etc.) will take effect on the next check.
If the timer was already running, it has been automatically restarted with the new interval.
No manual action is required - everything is ready to use!

You can run this wizard again anytime to change your settings."

    if [ "${use_gui}" = "true" ] && has_zenity; then
        zenity --info \
            --title="Sleep Warning Configuration" \
            --text="${message}" \
            --width=500 \
            2>/dev/null
    else
        echo ""
        echo "${message}"
    fi
}

# Main function
main() {
    local use_gui="false"
    local force_text=false
    local force_gui=false
    
    # Parse command-line arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --text|--no-gui)
                force_text=true
                shift
                ;;
            --gui)
                force_gui=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --text, --no-gui    Force text mode (disable GUI)"
                echo "  --gui               Force GUI mode (requires zenity)"
                echo "  --help, -h          Show this help message"
                echo ""
                echo "By default, GUI mode is used if zenity is available and a display is present."
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Use --help for usage information." >&2
                exit 1
                ;;
        esac
    done
    
    # Determine GUI mode
    if [ "${force_text}" = "true" ]; then
        use_gui="false"
    elif [ "${force_gui}" = "true" ]; then
        if has_zenity; then
            use_gui="true"
        else
            echo "Error: --gui flag specified but zenity is not available." >&2
            echo "Please install zenity or use --text mode." >&2
            exit 1
        fi
    else
        # Auto-detect: use GUI if available
        if has_gui && has_zenity; then
            use_gui="true"
        fi
    fi
    
    # Show welcome
    show_welcome "${use_gui}"
    
    # Declare global arrays and variables BEFORE calling load_existing_config()
    # This ensures they exist in the parent shell
    declare -g -a config_lines=()
    declare -g -a summary_lines=()
    declare -g check_interval popup_size popup_position min_display_time popup_immovable
    
    # Load existing configuration
    # Function sets global variables and populates global arrays directly
    load_existing_config
    
    # Main configuration loop
    while true; do
        # Get section status indicators
        local status_data
        status_data=$(get_section_status)
        local weekdays_status weekends_status
        IFS='|' read -r weekdays_status weekends_status <<< "${status_data}"
        
        # Show main menu
        local menu_choice
        menu_choice=$(show_main_menu "${use_gui}" "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${weekdays_status}" "${weekends_status}")
        local menu_exit=$?
        
        if [ "${menu_exit}" -eq 2 ] || [ "${menu_choice}" = "CANCELLED" ]; then
            # User cancelled
            exit 0
        fi
        
        if [ "${menu_exit}" -ne 0 ]; then
            continue  # Show menu again
        fi
        
        # Handle menu choice
        case "${menu_choice}" in
            1)
                # Timer Settings
                local new_interval
                new_interval=$(get_check_interval "${use_gui}")
                if [ "${new_interval}" = "CANCELLED" ]; then
                    # User already confirmed cancellation in get_check_interval
                    exit 0
                else
                    check_interval="${new_interval}"
                fi
                ;;
            2)
                # Window Behavior
                local new_size
                new_size=$(get_popup_size_config "${use_gui}")
                if [ "${new_size}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    popup_size="${new_size}"
                fi
                
                local new_position
                new_position=$(get_popup_position_config "${use_gui}")
                if [ "${new_position}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    popup_position="${new_position}"
                fi
                
                local new_time
                new_time=$(get_min_display_time_config "${use_gui}")
                if [ "${new_time}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    min_display_time="${new_time}"
                fi
                
                local new_immovable
                new_immovable=$(get_popup_immovable_config "${use_gui}")
                if [ "${new_immovable}" = "CANCELLED" ]; then
                    # User already confirmed cancellation
                    exit 0
                else
                    popup_immovable="${new_immovable}"
                fi
                ;;
            3)
                # Weekdays Configuration
                configure_weekdays_section "${use_gui}" config_lines summary_lines
                local weekdays_exit=$?
                if [ "${weekdays_exit}" -eq 2 ]; then
                    # User cancelled
                    exit 0
                fi
                ;;
            4)
                # Weekends Configuration
                configure_weekends_section "${use_gui}" config_lines summary_lines
                local weekends_exit=$?
                if [ "${weekends_exit}" -eq 2 ]; then
                    # User cancelled
                    exit 0
                fi
                ;;
            5)
                # Visual Day/Time Grid
                # Use global variable to store result (avoid subshell issue with namerefs)
                declare -g grid_result_var=""
                while true; do
                    grid_result_var=""
                    show_visual_grid "${use_gui}" config_lines summary_lines
                    local grid_exit=$?
                    
                    if [ "${grid_exit}" -ne 0 ] || [ "${grid_result_var}" = "BACK" ]; then
                        # User wants to go back to main menu
                        break
                    fi
                    
                    # grid_result_var contains the day index (0-6) or "BACK"
                    local day_index="${grid_result_var}"
                    
                    # Configure the selected day
                    configure_day_from_grid "${day_index}" "${use_gui}" config_lines summary_lines
                    local config_exit=$?
                    
                    if [ "${config_exit}" -eq 2 ]; then
                        # User cancelled configuration
                        break
                    fi
                    
                    # Grid will refresh automatically on next loop iteration
                done
                ;;
            6)
                # Review and Save
                # Note: summary_lines is accessed globally by show_summary to preserve sparse array indices
                if show_summary "${use_gui}" "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}"; then
                    # Write configuration
                    if write_config "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${config_lines[@]}"; then
                        # Update timer file if it exists
                        if [ -f "${TIMER_FILE}" ]; then
                            if update_timer_file "${check_interval}"; then
                                show_success "${use_gui}" "${check_interval}"
                            else
                                local warning_msg="Configuration saved, but failed to update timer file.\n\nYou may need to manually update:\n${TIMER_FILE}\n\nThen run:\nsystemctl --user daemon-reload\nsystemctl --user restart ${SERVICE_NAME}.timer"
                                if [ "${use_gui}" = "true" ] && has_zenity; then
                                    zenity --warning --text="${warning_msg}" 2>/dev/null
                                else
                                    echo "${warning_msg}" >&2
                                fi
                            fi
                        else
                            show_success "${use_gui}" "${check_interval}"
                        fi
                        exit 0
                    else
                        local error_msg="Error: Failed to write configuration file.\n\nPlease check permissions for:\n${CONFIG_DIR}"
                        if [ "${use_gui}" = "true" ] && has_zenity; then
                            zenity --error --text="${error_msg}" 2>/dev/null
                        else
                            echo "${error_msg}" >&2
                        fi
                        # Return to menu instead of exiting on error
                    fi
                fi
                # User didn't confirm, return to menu
                ;;
        esac
    done
}

# Run main function
main "$@"
