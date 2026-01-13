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
        local size
        size=$(zenity --list \
            --title="Sleep Warning Configuration" \
            --text="Select popup size:" \
            --column="Size" --column="Dimensions" \
            "small" "300x150 pixels" \
            "medium" "400x200 pixels" \
            "large" "500x250 pixels" \
            --hide-column=2 \
            --print-column=1 \
            --default-item="${default_size}" \
            2>/dev/null)
        
        if [ -n "${size}" ]; then
            echo "${size}"
            return 0
        else
            echo "${default_size}"
            return 0
        fi
    else
        # Text mode
        echo ""
        echo "Popup Size Options:"
        echo "  1) small (300x150)"
        echo "  2) medium (400x200)"
        echo "  3) large (500x250)"
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
        local time
        time=$(zenity --entry \
            --title="Sleep Warning Configuration" \
            --text="Minimum time popup must be visible before it can be closed:\n\nEnter time in seconds (0-300):\n(0 = disabled, 30 = default)" \
            --entry-text="${default_time}" \
            2>/dev/null)
        
        if [ -z "${time}" ]; then
            echo "${default_time}"
            return 0
        fi
        
        # Validate time
        if ! [[ "${time}" =~ ^[0-9]+$ ]] || [ "${time}" -lt 0 ] || [ "${time}" -gt 300 ]; then
            zenity --error --text="Invalid time. Please enter a number between 0 and 300 seconds." 2>/dev/null
            echo "${default_time}"
            return 0
        fi
        
        echo "${time}"
        return 0
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
        local position
        position=$(zenity --list \
            --title="Sleep Warning Configuration" \
            --text="Select popup position on screen:" \
            --column="Position" \
            "center" \
            "top-left" \
            "top-right" \
            "bottom-left" \
            "bottom-right" \
            "top-center" \
            "bottom-center" \
            --default-item="${default_position}" \
            2>/dev/null)
        
        if [ -n "${position}" ]; then
            echo "${position}"
            return 0
        else
            echo "${default_position}"
            return 0
        fi
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
            interval=$(zenity --entry \
                --title="Sleep Warning Configuration" \
                --text="How often should the system check for restricted hours?\n\nEnter interval in minutes (1-60):" \
                --entry-text="${default_interval}" \
                2>/dev/null)
            
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

# Get hour range for a day
get_day_hours() {
    local day_name="$1"
    local day_index="$2"
    local use_gui="$3"
    
    local start_hour end_hour
    
    if [ "${use_gui}" = "true" ] && has_zenity; then
        # GUI mode
        while true; do
            start_hour=$(get_hour_zenity "Enter start hour (0-23) for ${day_name}:\n(Leave empty to skip this day)" "0")
            if [ -z "${start_hour}" ]; then
                echo "skip"
                return 0
            fi
            
            end_hour=$(get_hour_zenity "Enter end hour (0-23) for ${day_name}:\n(Must be greater than start hour)" "6")
            if [ -z "${end_hour}" ]; then
                continue
            fi
            
            # Validate range
            if [ "${start_hour}" -ge "${end_hour}" ]; then
                zenity --error --text="End hour must be greater than start hour." 2>/dev/null
                continue
            fi
            
            echo "${start_hour}-${end_hour}"
            return 0
        done
    else
        # Text mode
        echo "Configuring ${day_name}:" >&2
        while true; do
            start_hour=$(get_hour_text "Start hour (0-23, or 'skip' to skip this day)" "0")
            if [ "${start_hour}" = "skip" ]; then
                echo "skip"
                return 0
            fi
            
            end_hour=$(get_hour_text "End hour (0-23, must be > start hour)" "6")
            
            # Validate range
            if [ "${start_hour}" -ge "${end_hour}" ]; then
                echo "Error: End hour must be greater than start hour." >&2
                continue
            fi
            
            echo "${start_hour}-${end_hour}"
            return 0
        done
    fi
}

# Show welcome message
show_welcome() {
    local use_gui="$1"
    
    local message="Welcome to the Sleep Warning Configuration Wizard!

This wizard will help you set up restricted hours for each day of the week.
During these hours, you will receive warning popups if you use your computer.

You can:
- Set different hours for each day
- Apply the same settings to all weekdays
- Apply the same settings to both weekend days
- Skip days to have no restrictions

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

# Show summary and confirm
show_summary() {
    local use_gui="$1"
    local check_interval="$2"
    local popup_size="$3"
    local popup_position="$4"
    local min_display_time="$5"
    shift 5
    local summary_lines=("$@")
    
    local summary="Configuration Summary:\n\n"
    summary="${summary}Check Interval: Every ${check_interval} minute(s)\n"
    summary="${summary}Popup Size: ${popup_size}\n"
    summary="${summary}Popup Position: ${popup_position}\n\n"
    for line in "${summary_lines[@]}"; do
        summary="${summary}${line}\n"
    done
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
        echo "Configuration Summary:"
        echo "  Check Interval: Every ${check_interval} minute(s)"
        echo "  Popup Size: ${popup_size}"
        echo "  Popup Position: ${popup_position}"
        if [ "${min_display_time}" -eq 0 ]; then
            echo "  Minimum Display Time: Disabled"
        else
            echo "  Minimum Display Time: ${min_display_time} seconds"
        fi
        for line in "${summary_lines[@]}"; do
            echo "  ${line}"
        done
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
    shift 4
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
    
    # Get popup size
    local popup_size
    popup_size=$(get_popup_size_config "${use_gui}")
    
    # Get popup position
    local popup_position
    popup_position=$(get_popup_position_config "${use_gui}")
    
    # Get minimum display time
    local min_display_time
    min_display_time=$(get_min_display_time_config "${use_gui}")
    
    # Array to store configuration
    declare -a config_lines
    declare -a summary_lines
    
    # Ask about weekdays
    local weekday_range=""
    if ask_weekday_together "${use_gui}"; then
        weekday_range=$(get_day_hours "Weekdays (Monday-Friday)" 1 "${use_gui}")
        if [ "${weekday_range}" != "skip" ]; then
            for i in 1 2 3 4 5; do  # Monday through Friday
                config_lines[${i}]="${DAY_VARS[${i}]}=${weekday_range}"
                summary_lines[${i}]="${DAY_NAMES[${i}]}: ${weekday_range}"
            done
        fi
    else
        # Configure each weekday separately
        for i in 1 2 3 4 5; do  # Monday through Friday
            local range
            range=$(get_day_hours "${DAY_NAMES[${i}]}" "${i}" "${use_gui}")
            if [ "${range}" != "skip" ]; then
                config_lines[${i}]="${DAY_VARS[${i}]}=${range}"
                summary_lines[${i}]="${DAY_NAMES[${i}]}: ${range}"
            fi
        done
    fi
    
    # Ask about weekends
    local weekend_range=""
    if ask_weekend_together "${use_gui}"; then
        weekend_range=$(get_day_hours "Weekends (Saturday and Sunday)" 6 "${use_gui}")
        if [ "${weekend_range}" != "skip" ]; then
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
        range=$(get_day_hours "${DAY_NAMES[0]}" 0 "${use_gui}")
        if [ "${range}" != "skip" ]; then
            config_lines[0]="${DAY_VARS[0]}=${range}"
            summary_lines[0]="${DAY_NAMES[0]}: ${range}"
        fi
        
        # Saturday (6)
        range=$(get_day_hours "${DAY_NAMES[6]}" 6 "${use_gui}")
        if [ "${range}" != "skip" ]; then
            config_lines[6]="${DAY_VARS[6]}=${range}"
            summary_lines[6]="${DAY_NAMES[6]}: ${range}"
        fi
    fi
    
    # Show summary and confirm
    if ! show_summary "${use_gui}" "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${summary_lines[@]}"; then
        if [ "${use_gui}" = "true" ] && has_zenity; then
            zenity --info --text="Configuration cancelled." 2>/dev/null
        else
            echo "Configuration cancelled."
        fi
        exit 0
    fi
    
    # Write configuration
    if write_config "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${config_lines[@]}"; then
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
