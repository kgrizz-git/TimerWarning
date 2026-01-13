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
#   ./configure.sh
#   sleep-warning-configure (after installation)
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
                "small" "300x225 pixels" \
                "medium" "750x500 pixels" \
                "large" "1900x1300 pixels" \
                --hide-column=2 \
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
        echo ""
        echo "Popup Size Options:"
        echo "  1) small (300x225)"
        echo "  2) medium (500x375)"
        echo "  3) large (875x660)"
        echo ""
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
        echo ""
        echo "Popup Immovable Setting:"
        echo "  Prevents the popup window from being moved during minimum display time"
        echo "  by monitoring and restoring its position if moved."
        echo ""
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
        echo ""
        echo "Popup Position Options:"
        echo "  1) center"
        echo "  2) top-left"
        echo "  3) top-right"
        echo "  4) bottom-left"
        echo "  5) bottom-right"
        echo "  6) top-center"
        echo "  7) bottom-center"
        echo ""
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
        # Reload systemd if timer is active
        if systemctl --user is-active "${SERVICE_NAME}.timer" >/dev/null 2>&1; then
            systemctl --user daemon-reload >/dev/null 2>&1
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
                # day2 early: start2 to end2 (e.g., 0-5 means 00:00 to 05:59)
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
  Meaning: Midnight (00:00) to 5:59 AM on the same day

MULTIPLE RANGES:
  Format: START-END,START-END
  Example: 0-5,22-23
  Meaning: Two separate periods:
    • Midnight to 5:59 AM
    • 10:00 PM to 11:59 PM

OVERNIGHT RANGES (spans midnight):
  Format: START-END (where START > END)
  Example: 23-6
  Meaning: 11:00 PM on the named day to 6:00 AM on the NEXT day
  Example: Monday 23-6 = Monday 11 PM → Tuesday 6 AM

OVERLAPPING RANGES:
  If you set Monday 23-5 and Tuesday 0-5:
  • Both cover Tuesday midnight to 5:59 AM
  • Only one warning will be shown (not duplicated)
  • This is harmless but redundant

NAVIGATION:
  • Cancel: Exit without saving (available at any time)
  • Back: Return to previous day's configuration
  • Skip: Skip current day (no restrictions for that day)

EXAMPLES:
  • '0-5' = Midnight to 5:59 AM
  • '22-23' = 10:00 PM to 11:59 PM  
  • '23-6' = 11:00 PM to 6:00 AM (overnight)
  • '0-5,22-23' = Midnight-5:59 AM AND 10 PM-11:59 PM"
    
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
            prompt_text="${prompt_text}• Single: 0-5 (midnight to 5:59 AM)\n"
            prompt_text="${prompt_text}• Multiple: 0-5,22-23 (two periods)\n"
            prompt_text="${prompt_text}• Overnight: 23-6 (11 PM to 6 AM, spans to next day)\n\n"
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
                # User cancelled - ask if they want to cancel whole configuration
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2  # Special return code for cancellation
                else
                    # User wants to continue - treat as skip for this day
                    echo "skip"
                    return 0
                fi
            fi
            
            # Validate the input (could be single range, multiple ranges, or overnight)
            # Check if it's a valid format
            if ! echo "${range_input}" | grep -qE '^([0-9]+-[0-9]+)(,[0-9]+-[0-9]+)*$'; then
                zenity --error --text="Invalid format. Use: START-END or START-END,START-END\n\nExamples:\n• 0-5 (midnight to 5:59 AM)\n• 0-5,22-23 (two periods)\n• 23-6 (11 PM to 6 AM, overnight)" 2>/dev/null
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
        echo ""
        echo "=== Configuring ${day_name} ===" >&2
        echo "" >&2
        echo "IMPORTANT - Overnight ranges:" >&2
        echo "  If you enter '23-6' on ${day_name}, it means:" >&2
        echo "  ${day_name} 11:00 PM → Next day 6:00 AM" >&2
        echo "" >&2
        echo "Format options:" >&2
        echo "  • Single: 0-5 (midnight to 5:59 AM)" >&2
        echo "  • Multiple: 0-5,22-23 (two periods)" >&2
        echo "  • Overnight: 23-6 (11 PM to 6 AM, spans to next day)" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  • Enter time range(s) to configure" >&2
        echo "  • Type 'skip' to skip this day" >&2
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
            read -p "Time range(s) for ${day_name}: " range_input
            
            # Handle special commands
            case "${range_input}" in
                skip|"")
                    echo "skip"
                    return 0
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
• Single: '0-5' = Midnight to 5:59 AM
• Multiple: '0-5,22-23' = Two periods (midnight-5:59 AM AND 10 PM-11:59 PM)
• Overnight: '23-6' = 11 PM to 6 AM (spans midnight to next day)

IMPORTANT - Overnight Ranges:
If you enter '23-6' on Monday, it means:
  Monday 11:00 PM → Tuesday 6:00 AM

This spans across midnight to the next day. If you also set Tuesday 0-5,
both will cover Tuesday midnight-5:59 AM (redundant but harmless).

Examples:
• '0-5' = Midnight to 5:59 AM (same day)
• '22-23' = 10:00 PM to 11:59 PM (same day)
• '23-6' = 11:00 PM to 6:00 AM (overnight, spans to next day)
• '0-5,22-23' = Midnight-5:59 AM AND 10 PM-11:59 PM

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

# Show summary and confirm (with overlap detection and human-readable times)
show_summary() {
    local use_gui="$1"
    local check_interval="$2"
    local popup_size="$3"
    local popup_position="$4"
    local min_display_time="$5"
    local popup_immovable="$6"
    shift 6
    local summary_lines=("$@")
    
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
    local day_index=0
    
    for line in "${summary_lines[@]}"; do
        if [ -n "${line}" ]; then
            # Extract day name and range
            local day_name range
            day_name=$(echo "${line}" | cut -d':' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            range=$(echo "${line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Format to human-readable
            local formatted
            formatted=$(format_ranges_human "${range}" "${day_name}")
            summary="${summary}• ${day_name}: ${formatted}\n"
            
            # Check for overlaps with previous day
            if [ "${day_index}" -gt 0 ]; then
                local prev_day_index=$((day_index - 1))
                if [ -n "${summary_lines[${prev_day_index}]}" ]; then
                    local prev_line="${summary_lines[${prev_day_index}]}"
                    local prev_day_name prev_range
                    prev_day_name=$(echo "${prev_line}" | cut -d':' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    prev_range=$(echo "${prev_line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    
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
        day_index=$((day_index + 1))
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
        local day_index=0
        
        for line in "${summary_lines[@]}"; do
            if [ -n "${line}" ]; then
                # Extract day name and range
                local day_name range
                day_name=$(echo "${line}" | cut -d':' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                range=$(echo "${line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                # Format to human-readable
                local formatted
                formatted=$(format_ranges_human "${range}" "${day_name}")
                echo "  • ${day_name}: ${formatted}"
                
                # Check for overlaps with previous day
                if [ "${day_index}" -gt 0 ]; then
                    local prev_day_index=$((day_index - 1))
                    if [ -n "${summary_lines[${prev_day_index}]}" ]; then
                        local prev_line="${summary_lines[${prev_day_index}]}"
                        local prev_day_name prev_range
                        prev_day_name=$(echo "${prev_line}" | cut -d':' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        prev_range=$(echo "${prev_line}" | cut -d':' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                        
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
            day_index=$((day_index + 1))
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
        
        # Write configuration lines
        for line in "${config_lines[@]}"; do
            if [ -n "${line}" ] && [ "${line}" != "skip" ]; then
                echo "${line}"
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

The sleep warning system will use these settings the next time it checks.
If the timer was already running, it has been updated with the new interval.
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
    if has_gui && has_zenity; then
        use_gui="true"
    fi
    
    # Show welcome
    show_welcome "${use_gui}"
    
    # Get check interval
    local check_interval
    check_interval=$(get_check_interval "${use_gui}")
    if [ "${check_interval}" = "CANCELLED" ]; then
        if [ "${use_gui}" = "true" ] && has_zenity; then
            zenity --info --text="Configuration cancelled." 2>/dev/null
        else
            echo "Configuration cancelled."
        fi
        exit 0
    fi
    
    # Get popup size
    local popup_size
    popup_size=$(get_popup_size_config "${use_gui}")
    if [ "${popup_size}" = "CANCELLED" ]; then
        if [ "${use_gui}" = "true" ] && has_zenity; then
            zenity --info --text="Configuration cancelled." 2>/dev/null
        else
            echo "Configuration cancelled."
        fi
        exit 0
    fi
    
    # Get popup position
    local popup_position
    popup_position=$(get_popup_position_config "${use_gui}")
    if [ "${popup_position}" = "CANCELLED" ]; then
        if [ "${use_gui}" = "true" ] && has_zenity; then
            zenity --info --text="Configuration cancelled." 2>/dev/null
        else
            echo "Configuration cancelled."
        fi
        exit 0
    fi
    
    # Get minimum display time
    local min_display_time
    min_display_time=$(get_min_display_time_config "${use_gui}")
    if [ "${min_display_time}" = "CANCELLED" ]; then
        if [ "${use_gui}" = "true" ] && has_zenity; then
            zenity --info --text="Configuration cancelled." 2>/dev/null
        else
            echo "Configuration cancelled."
        fi
        exit 0
    fi
    
    # Get popup immovable setting
    local popup_immovable
    popup_immovable=$(get_popup_immovable_config "${use_gui}")
    if [ "${popup_immovable}" = "CANCELLED" ]; then
        if [ "${use_gui}" = "true" ] && has_zenity; then
            zenity --info --text="Configuration cancelled." 2>/dev/null
        else
            echo "Configuration cancelled."
        fi
        exit 0
    fi
    
    # Array to store configuration
    declare -a config_lines
    declare -a summary_lines
    
    # Ask about weekdays
    local weekday_range=""
    if ask_weekday_together "${use_gui}"; then
        weekday_range=$(get_day_hours "Weekdays (Monday-Friday)" 1 "${use_gui}" "false" "true")
        if [ "${weekday_range}" = "CANCELLED" ]; then
            if [ "${use_gui}" = "true" ] && has_zenity; then
                zenity --info --text="Configuration cancelled." 2>/dev/null
            else
                echo "Configuration cancelled."
            fi
            exit 0
        elif [ "${weekday_range}" != "skip" ]; then
            for i in 1 2 3 4 5; do  # Monday through Friday
                config_lines[${i}]="${DAY_VARS[${i}]}=${weekday_range}"
                summary_lines[${i}]="${DAY_NAMES[${i}]}: ${weekday_range}"
            done
        fi
    else
        # Configure each weekday separately
        for i in 1 2 3 4 5; do  # Monday through Friday
            local range
            range=$(get_day_hours "${DAY_NAMES[${i}]}" "${i}" "${use_gui}" "false" "true")
            if [ "${range}" = "CANCELLED" ]; then
                if [ "${use_gui}" = "true" ] && has_zenity; then
                    zenity --info --text="Configuration cancelled." 2>/dev/null
                else
                    echo "Configuration cancelled."
                fi
                exit 0
            elif [ "${range}" != "skip" ]; then
                config_lines[${i}]="${DAY_VARS[${i}]}=${range}"
                summary_lines[${i}]="${DAY_NAMES[${i}]}: ${range}"
            fi
        done
    fi
    
    # Ask about weekends
    local weekend_range=""
    if ask_weekend_together "${use_gui}"; then
        weekend_range=$(get_day_hours "Weekends (Saturday and Sunday)" 6 "${use_gui}" "false" "true")
        if [ "${weekend_range}" = "CANCELLED" ]; then
            if [ "${use_gui}" = "true" ] && has_zenity; then
                zenity --info --text="Configuration cancelled." 2>/dev/null
            else
                echo "Configuration cancelled."
            fi
            exit 0
        elif [ "${weekend_range}" != "skip" ]; then
            # Sunday (0)
            config_lines[0]="${DAY_VARS[0]}=${weekend_range}"
            summary_lines[0]="${DAY_NAMES[0]}: ${weekend_range}"
            # Saturday (6)
            config_lines[6]="${DAY_VARS[6]}=${weekend_range}"
            summary_lines[6]="${DAY_NAMES[6]}: ${weekend_range}"
        fi
    else
        # Configure Sunday and Saturday separately
        # Sunday (0)
        local range
        range=$(get_day_hours "${DAY_NAMES[0]}" 0 "${use_gui}" "false" "true")
        if [ "${range}" = "CANCELLED" ]; then
            if [ "${use_gui}" = "true" ] && has_zenity; then
                zenity --info --text="Configuration cancelled." 2>/dev/null
            else
                echo "Configuration cancelled."
            fi
            exit 0
        elif [ "${range}" != "skip" ]; then
            config_lines[0]="${DAY_VARS[0]}=${range}"
            summary_lines[0]="${DAY_NAMES[0]}: ${range}"
        fi
        
        # Saturday (6)
        range=$(get_day_hours "${DAY_NAMES[6]}" 6 "${use_gui}" "false" "true")
        if [ "${range}" = "CANCELLED" ]; then
            if [ "${use_gui}" = "true" ] && has_zenity; then
                zenity --info --text="Configuration cancelled." 2>/dev/null
            else
                echo "Configuration cancelled."
            fi
            exit 0
        elif [ "${range}" != "skip" ]; then
            config_lines[6]="${DAY_VARS[6]}=${range}"
            summary_lines[6]="${DAY_NAMES[6]}: ${range}"
        fi
    fi
    
    # Show summary and confirm
    if ! show_summary "${use_gui}" "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${summary_lines[@]}"; then
        if [ "${use_gui}" = "true" ] && has_zenity; then
            zenity --info --text="Configuration cancelled." 2>/dev/null
        else
            echo "Configuration cancelled."
        fi
        exit 0
    fi
    
    # Write configuration
    if write_config "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${config_lines[@]}"; then
        # Update timer file if it exists
        if [ -f "${TIMER_FILE}" ]; then
            if update_timer_file "${check_interval}"; then
                show_success "${use_gui}" "${check_interval}"
            else
                local warning_msg="Configuration saved, but failed to update timer file.\n\nYou may need to manually update:\n${TIMER_FILE}\n\nOr run: systemctl --user daemon-reload"
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
        exit 1
    fi
}

# Run main function
main "$@"
