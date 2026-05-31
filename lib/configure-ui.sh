#!/bin/bash

###############################################################################
# Sleep Warning System - User Interface Dialogs Module
#
# This module provides basic UI dialog functions for user interaction in both
# GUI (YAD/Zenity/KDialog) and text modes.
#
# Functions:
# - handle_main_menu_cancel_menu() - Exit vs continue after main menu list cancel (GUI)
# - handle_window_behavior_cancel_menu() - Exit vs back vs continue after Window Behavior cancel
# - confirm_cancel()              - Confirm cancellation dialog
# - confirm_skip_day()            - Confirm skipping a day
# - show_help_dialog()            - Display configuration help
# - show_welcome()                - Show welcome message
# - show_success()                - Show success message
# - ask_weekday_together()        - Ask if configuring weekdays together
# - ask_weekend_together()        - Ask if configuring weekends together
# - ask_what_to_edit()            - Ask what to edit (restricted hours, lock hours, or both) (Enhancement #19 Phase 2)
# - show_24_7_error()             - Show error dialog for 24/7 restrictions detected
# - show_high_restriction_warning() - Show warning dialog for high restriction levels
# - calculate_restriction_end_time() - Calculate when current restriction period ends
# - show_config_locked_error()    - Show error when configure.sh/manage.sh is blocked (Enhancement #19)
# - show_config_file_locked_error() - Show error when config file is locked (Enhancement #18)
#
# Dependencies:
# - configure-core.sh (for has_dialog_tool, CONFIG_FILE)
# - configure-dialogs.sh (for dialog abstraction functions)
# - time-parsing.sh (range_endpoint_to_day_minutes, range_is_overnight, range_overnight_tail_active_for_hour)
###############################################################################

_configure_ui_ensure_time_parsing() {
    if type range_endpoint_to_day_minutes >/dev/null 2>&1; then
        return 0
    fi
    local _tp_dir
    _tp_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck disable=SC1091
    [ -f "${_tp_dir}/time-parsing.sh" ] && source "${_tp_dir}/time-parsing.sh"
}

# Menu after user cancels the main configuration list (GUI).
# stdout: CANCELLED when exiting the wizard
# return 1 = stay in / return to main menu
# return 2 = exit entire wizard (stdout CANCELLED)
handle_main_menu_cancel_menu() {
    local use_gui="$1"
    local menu_prompt="${2:-You closed the configuration menu. What would you like to do?}"

    if [ "${use_gui}" != "true" ] || ! has_dialog_tool; then
        if confirm_cancel "${use_gui}"; then
            echo "CANCELLED"
            return 2
        fi
        return 1
    fi

    while true; do
        local choice
        choice=$(show_list_dialog \
            "Sleep Warning Configuration" \
            "${menu_prompt}" \
            520 \
            280 \
            "Exit without saving" \
            "Continue configuring")
        local list_exit=$?
        # If the cancel menu itself is dismissed (Cancel / window close), treat it as
        # "Continue configuring" so the user is never trapped in an infinite loop.
        if [ ${list_exit} -ne 0 ] || [ -z "${choice}" ]; then
            return 1
        fi

        case "${choice}" in
            "Exit without saving")
                # User explicitly chose "Exit without saving" from the cancel menu —
                # that selection IS the confirmation; no second dialog needed.
                echo "CANCELLED"
                return 2
                ;;
            "Continue configuring")
                return 1
                ;;
        esac
    done
}

# Menu after user cancels a Window Behavior sub-prompt (GUI).
# stdout: BACK | CANCELLED
# return 1 = back to Window Behavior submenu
# return 2 = cancel entire wizard (stdout CANCELLED)
# return 3 = retry the same sub-prompt
handle_window_behavior_cancel_menu() {
    local use_gui="$1"
    local menu_prompt="${2:-What would you like to do?}"

    if [ "${use_gui}" != "true" ] || ! has_dialog_tool; then
        echo "BACK"
        return 1
    fi

    while true; do
        local choice
        choice=$(show_list_dialog \
            "Window Behavior" \
            "${menu_prompt}" \
            520 \
            280 \
            "Return to Window Behavior menu" \
            "Cancel configuration" \
            "Continue configuring")
        local list_exit=$?
        # If the cancel menu itself is dismissed, treat it as "Return to Window Behavior menu"
        # so the user is never trapped in an infinite loop.
        if [ ${list_exit} -ne 0 ] || [ -z "${choice}" ]; then
            echo "BACK"
            return 1
        fi

        case "${choice}" in
            "Return to Window Behavior menu")
                echo "BACK"
                return 1
                ;;
            "Cancel configuration")
                # User explicitly chose "Cancel configuration" from the cancel menu —
                # that selection IS the confirmation; no second dialog needed.
                echo "CANCELLED"
                return 2
                ;;
            "Continue configuring")
                return 3
                ;;
        esac
    done
}

# Confirm cancellation with user.
#
# On macOS, osascript `display alert` appears behind the terminal after a
# `choose from list` window closes (z-order regression on macOS 13+). We use
# `show_list_dialog` (which wraps `choose from list`) on darwin so the prompt
# always appears in front.  Linux keeps the original `show_question_dialog`.
confirm_cancel() {
    local use_gui="$1"

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        if type is_darwin >/dev/null 2>&1 && is_darwin; then
            local choice
            choice=$(show_list_dialog \
                "Cancel Configuration?" \
                "Exit the wizard? All unsaved changes will be lost." \
                520 \
                250 \
                "Yes, Exit without saving" \
                "No, Continue configuring")
            local list_exit=$?
            if [ "${list_exit}" -ne 0 ] || [ -z "${choice}" ]; then
                return 1  # Dismissed → treat as "continue"
            fi
            [ "${choice}" = "Yes, Exit without saving" ]
            return $?
        fi
        show_question_dialog \
            "Cancel Configuration?" \
            "Are you sure you want to cancel?\n\nAll unsaved changes will be lost." \
            "Yes, Cancel" \
            "No, Continue" \
            500 \
            250
        return $?
    else
        echo ""
        configure_read -p "Cancel configuration? All unsaved changes will be lost. [y/N]: " answer
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
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_question_dialog \
            "Skip ${day_name}?" \
            "${skip_message}" \
            "Yes, Skip" \
            "No, Configure" \
            550 \
            300
        return $?
    else
        echo "" >&2
        if [ "${is_multiple}" = "true" ]; then
            configure_read -p "Skip ${day_name}? No restrictions will be set. [y/N]: " answer
        else
            configure_read -p "Skip ${day_name}? No restrictions will be set for this day. [y/N]: " answer
        fi
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Show help dialog
show_help_dialog() {
    local use_gui="$1"
    
    local help_text="TIME RANGE CONFIGURATION HELP

GUI TIME PICKER (graphical mode):
  Minute choices are :00, :15, :30, and :45.
  Text mode accepts any valid minute (e.g. 11:17pm-5:42am).

SINGLE RANGE:
  Format: START-END
  Example: 0-5
  Meaning: Midnight (00:00) to 4:59 AM on the same day

MULTIPLE RANGES:
  Format: START-END,START-END
  Example: 0-5,22-23
  Meaning: Two separate periods:
    - Midnight to 4:59 AM
    - 10:00 PM to 11:59 PM

OVERNIGHT RANGES (spans midnight):
  Format: START-END (where START > END)
  Example: 23-6
  Meaning: 11:00 PM on the named day to 5:59 AM on the NEXT day
  Example: Monday 23-6 = Monday 11 PM → Tuesday 5:59 AM

OVERLAPPING RANGES:
  If you set Monday 23-5 and Tuesday 0-5:
  - Both cover Tuesday midnight to 4:59 AM
  - Only one warning will be shown (not duplicated)
  - This is harmless but redundant

SAFETY FEATURE - 24/7 Restriction Prevention:
  - The system prevents configuring restrictions for all 24 hours, 7 days a week
  - If you configure 24/7 restrictions, you'll see an error and cannot save
  - If you configure > 16 hours/day, you'll see a warning and can choose to save anyway
  - Safety features (popup size limits, config locking disabled) are automatically applied for high restriction levels

NAVIGATION:
  - Cancel: Exit without saving (available at any time)
  - Back: Return to previous day's configuration
  - Skip: Skip current day (no restrictions for that day)

EXAMPLES:
  - '0-5' = Midnight to 4:59 AM
  - '22-23' = 10:00 PM to 11:59 PM  
  - '23-6' = 11:00 PM to 5:59 AM (overnight)
  - '0-5,22-23' = Midnight-4:59 AM AND 10 PM-11:59 PM"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # Use show_info_dialog for consistent appearance with other dialogs
        show_info_dialog \
            "Configuration Help" \
            "${help_text}" \
            800 \
            500
    else
        echo ""
        echo "=== CONFIGURATION HELP ==="
        echo "${help_text}"
        echo ""
        configure_read -p "Press Enter to continue..."
    fi
}

# Show welcome message
show_welcome() {
    local use_gui="$1"
    
    local message="Welcome to the Sleep Warning Configuration Wizard!

This wizard will help you set up restricted hours for each day of the week.
During these hours, you will receive warning popups if you use your computer.

NAVIGATION:
- You can cancel at any time (changes won't be saved)
- You can go back to previous days to edit
- You can skip days to have no restrictions

TIME RANGE FORMATS:
- Single: '0-5' = Midnight to 4:59 AM
- Multiple: '0-5,22-23' = Two periods (midnight-4:59 AM AND 10 PM-11:59 PM)
- Overnight: '23-6' = 11 PM to 5:59 AM (spans midnight to next day)

IMPORTANT - Overnight Ranges:
If you enter '23-6' on Monday, it means:
  Monday 11:00 PM → Tuesday 5:59 AM

This spans across midnight to the next day. If you also set Tuesday 0-5,
both will cover Tuesday midnight-4:59 AM (redundant but harmless).

SAFETY FEATURE:
The system includes a safety feature that prevents you from accidentally
configuring restrictions for all 24 hours, 7 days a week (which would
lock you out). If you configure very high restriction levels (> 16 hours/day),
you'll see a warning and safety features will be automatically applied.

Examples:
- '0-5' = Midnight to 4:59 AM (same day)
- '22-23' = 10:00 PM to 11:59 PM (same day)
- '23-6' = 11:00 PM to 5:59 AM (overnight, spans to next day)
- '0-5,22-23' = Midnight-4:59 AM AND 10 PM-11:59 PM

Let's get started!"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # Use info dialog for consistency with other dialogs
        show_info_dialog \
            "Sleep Warning Configuration" \
            "${message}" \
            800 \
            400
    else
        echo "${message}"
        echo ""
        configure_read -p "Press Enter to continue..."
    fi
}

# Ask if user wants to configure weekdays together
ask_weekday_together() {
    local use_gui="$1"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_question_dialog \
            "Sleep Warning Configuration" \
            "Would you like to use the same restricted hours for all weekdays (Monday-Friday)?" \
            "Yes" \
            "No"
        return $?
    else
        configure_read -p "Use same hours for all weekdays (Monday-Friday)? [y/N]: " answer
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Ask if user wants to configure weekends together
ask_weekend_together() {
    local use_gui="$1"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_question_dialog \
            "Sleep Warning Configuration" \
            "Would you like to use the same restricted hours for both weekend days (Saturday and Sunday)?" \
            "Yes" \
            "No" \
            650 \
            250
        return $?
    else
        configure_read -p "Use same hours for both weekend days (Saturday and Sunday)? [y/N]: " answer
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Ask what to edit for a day (restricted hours, lock hours, or both)
# Returns: "restricted", "lock", "both", or "CANCELLED"
# Enhancement #19 Phase 2 - Visual grid lock hours editing
ask_what_to_edit() {
    local day_name="$1"
    local use_gui="$2"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode - use list dialog
        local choice
        choice=$(show_list_dialog \
            "Edit ${day_name}" \
            "What would you like to edit for ${day_name}?" \
            500 \
            350 \
            "Restricted Hours" \
            "Lock Hours" \
            "Uninstall Lock Hours" \
            "All")
        local exit_code=$?
        
        if [ ${exit_code} -ne 0 ] || [ -z "${choice}" ]; then
            if confirm_cancel "${use_gui}"; then
                echo "CANCELLED"
                return 2
            else
                # User wants to continue, re-prompt
                return 1
            fi
        fi
        
        case "${choice}" in
            "Restricted Hours")
                echo "restricted"
                return 0
                ;;
            "Lock Hours")
                echo "lock"
                return 0
                ;;
            "Uninstall Lock Hours")
                echo "uninstall_lock"
                return 0
                ;;
            "All")
                echo "all"
                return 0
                ;;
            *)
                echo "CANCELLED"
                return 2
                ;;
        esac
    else
        # Text mode
        echo "" >&2
        echo "What would you like to edit for ${day_name}?" >&2
        echo "  1) Restricted Hours" >&2
        echo "  2) Lock Hours" >&2
        echo "  3) Uninstall Lock Hours" >&2
        echo "  4) All" >&2
        echo "" >&2
        
        while true; do
            configure_read -p "Select option [1-4]: " choice
            case "${choice}" in
                1|restricted|Restricted)
                    echo "restricted"
                    return 0
                    ;;
                2|lock|Lock)
                    echo "lock"
                    return 0
                    ;;
                3|uninstall_lock|Uninstall)
                    echo "uninstall_lock"
                    return 0
                    ;;
                4|all|All)
                    echo "all"
                    return 0
                    ;;
                *)
                    echo "Invalid option. Please select 1, 2, or 3." >&2
                    ;;
            esac
        done
    fi
}

# Show success message
show_success() {
    local use_gui="$1"
    local check_interval="$2"
    
    local message="Configuration saved successfully!

Your settings have been saved to:
${CONFIG_FILE}

Popup display frequency: Every ${check_interval} minute(s)

All settings (restricted hours, popup size, position, etc.) will take effect on the next check.
If the timer was already running, it has been automatically restarted.
No manual action is required - everything is ready to use!

You can run this wizard again anytime to change your settings."

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_info_dialog \
            "Sleep Warning Configuration" \
            "${message}" \
            650 \
            280
    else
        echo ""
        echo "${message}"
    fi
}

# Show 24/7 restriction error dialog
# This is displayed when validation detects restrictions covering all 24 hours, 7 days a week
show_24_7_error() {
    local use_gui="$1"
    
    local title="ERROR: 24/7 Restrictions Detected"
    local message="🚨 ⚠️  CRITICAL ERROR  ⚠️  🚨

The combined total of restriction hours and additional lock hours covers all 24 hours, 7 days a week.

This would effectively lock you out of your computer.

Please modify your settings to leave at least some unrestricted time.

Configuration cannot be saved until you reduce the restriction level."
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_info_dialog "${title}" "${message}" 650 350
    else
        echo "" >&2
        echo "========================================" >&2
        echo "🚨 ⚠️  ERROR: 24/7 Restrictions Detected  ⚠️  🚨" >&2
        echo "========================================" >&2
        echo "" >&2
        echo "The combined total of restriction hours and additional lock hours covers all 24 hours, 7 days a week." >&2
        echo "This would effectively lock you out of your computer." >&2
        echo "" >&2
        echo "Please modify your settings to leave at least some unrestricted time." >&2
        echo "Configuration cannot be saved until you reduce the restriction level." >&2
        echo "" >&2
        configure_read -p "Press Enter to continue..."
    fi
}

# Show high restriction warning dialog
# This is displayed when validation detects restrictions exceeding THRESHOLD_WARN minutes (> HOURS_PER_DAY_WARN hours/day)
# Returns 0 if user confirms (save anyway), 1 if user cancels (modify settings)
show_high_restriction_warning() {
    local use_gui="$1"
    
    local title="Warning: Very High Restriction Level"
    local message="⚠️  ⚠️  WARNING  ⚠️  ⚠️

The combined total of restriction hours and additional lock hours exceeds 16 hours per day.

This leaves very little unrestricted time and may effectively lock you out.

Safety measures will be applied:
- Config locking features will be disabled
- Popup size will be limited to small/medium
- Additional lock hours will be cleared

Do you want to save this configuration anyway?"
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_question_dialog "${title}" "${message}" "Yes, Save Anyway" "No, Modify Settings" 700 400
        return $?
    else
        echo "" >&2
        echo "⚠️  ⚠️  WARNING: Very High Restriction Level  ⚠️  ⚠️" >&2
        echo "" >&2
        echo "The combined total of restriction hours and additional lock hours exceeds 16 hours per day." >&2
        echo "This leaves very little unrestricted time and may effectively lock you out." >&2
        echo "" >&2
        echo "Safety measures will be applied:" >&2
        echo "- Config locking features will be disabled" >&2
        echo "- Popup size will be limited to small/medium" >&2
        echo "- Additional lock hours will be cleared" >&2
        echo "" >&2
        configure_read -p "Save anyway? [y/N]: " answer
        case "${answer}" in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Calculate when the current restriction period ends
# This function finds which restriction range the current hour falls into and calculates when it ends
# Handles overnight ranges and multiple ranges per day
# Parameters:
#   $1 - current_hour (0-23)
#   $2 - current_day (0-6, Sunday=0)
#   $3 - restricted_range (optional, comma-separated ranges for current day)
# Returns: "END_HOUR_12H|END_DAY_NAME|IS_OVERNIGHT" or empty string if not in restriction
# Dependencies: configure-core.sh (for format_hour_12h, DAY_NAMES), time-validation.sh (for is_hour_in_single_range), config.sh (for parse_config)
calculate_restriction_end_time() {
    local current_hour="$1"
    local current_day="$2"
    local restricted_range="$3"
    
    _configure_ui_ensure_time_parsing
    
    # Source required modules if not already sourced
    if ! type format_hour_12h >/dev/null 2>&1 || [ -z "${DAY_NAMES}" ]; then
        local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
        source "${SCRIPT_DIR}/lib/configure-core.sh" 2>/dev/null || return 1
    fi
    
    if ! type parse_config >/dev/null 2>&1; then
        local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
        source "${SCRIPT_DIR}/lib/config.sh" 2>/dev/null || return 1
    fi
    
    # Check if we're in an overnight range from previous day
    local prev_day
    if [ "${current_day}" -eq 0 ]; then
        prev_day=6  # Sunday -> Saturday
    else
        prev_day=$((current_day - 1))
    fi
    
    local prev_day_range
    prev_day_range=$(parse_config "${prev_day}" 2>/dev/null || echo "")
    
    # Check previous day's overnight ranges first
    if [ -n "${prev_day_range}" ]; then
        local IFS=','
        for range in ${prev_day_range}; do
            range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            local start_part end_part
            start_part="${range%%-*}"
            end_part="${range##*-}"
            start_part=$(echo "${start_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            end_part=$(echo "${end_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if range_overnight_tail_active_for_hour "${current_hour}" "${start_part}" "${end_part}"; then
                local end_12h
                end_12h=$(format_hour_12h "${end_part}")
                local current_day_name="${DAY_NAMES[${current_day}]}"
                echo "${end_12h}|${current_day_name}|true"
                return 0
            fi
        done
    fi
    
    # Check current day's ranges
    if [ -z "${restricted_range}" ]; then
        return 1
    fi
    
    local IFS=','
    for range in ${restricted_range}; do
        range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Check if current hour is in this range
        if type is_hour_in_single_range >/dev/null 2>&1; then
            if is_hour_in_single_range "${current_hour}" "${range}"; then
                local start_part end_part end_12h
                start_part="${range%%-*}"
                end_part="${range##*-}"
                start_part=$(echo "${start_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                end_part=$(echo "${end_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                end_12h=$(format_hour_12h "${end_part}")
                local current_day_name="${DAY_NAMES[${current_day}]}"

                if range_is_overnight "${start_part}" "${end_part}"; then
                    local next_day_index=$(( (current_day + 1) % 7 ))
                    local next_day_name="${DAY_NAMES[${next_day_index}]}"
                    echo "${end_12h}|${next_day_name}|true"
                else
                    echo "${end_12h}|${current_day_name}|false"
                fi
                return 0
            fi
        else
            # Fallback: use minute-aware restricted check when available
            if type is_restricted_time >/dev/null 2>&1; then
                local current_time_hhmm
                current_time_hhmm=$(printf "%02d00" "${current_hour}")
                if is_restricted_time "${current_time_hhmm}" "${range}"; then
                    local start_part end_part end_12h
                    start_part="${range%%-*}"
                    end_part="${range##*-}"
                    start_part=$(echo "${start_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    end_part=$(echo "${end_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    end_12h=$(format_hour_12h "${end_part}")
                    local current_day_name="${DAY_NAMES[${current_day}]}"
                    if range_is_overnight "${start_part}" "${end_part}"; then
                        local next_day_index=$(( (current_day + 1) % 7 ))
                        local next_day_name="${DAY_NAMES[${next_day_index}]}"
                        echo "${end_12h}|${next_day_name}|true"
                    else
                        echo "${end_12h}|${current_day_name}|false"
                    fi
                    return 0
                fi
            else
            # Legacy integer-hour fallback
            local start_hour end_hour
            start_hour=$(echo "${range}" | cut -d'-' -f1)
            end_hour=$(echo "${range}" | cut -d'-' -f2)
            
            local in_range=false
            if [ "${start_hour}" -gt "${end_hour}" ]; then
                # Overnight range
                if [ "${current_hour}" -ge "${start_hour}" ] || [ "${current_hour}" -lt "${end_hour}" ]; then
                    in_range=true
                fi
            else
                # Normal range
                if [ "${current_hour}" -ge "${start_hour}" ] && [ "${current_hour}" -lt "${end_hour}" ]; then
                    in_range=true
                fi
            fi
            
            if [ "${in_range}" = "true" ]; then
                local end_12h
                end_12h=$(format_hour_12h "${end_hour}")
                local current_day_name="${DAY_NAMES[${current_day}]}"
                
                if [ "${start_hour}" -gt "${end_hour}" ]; then
                    local next_day_index=$(( (current_day + 1) % 7 ))
                    local next_day_name="${DAY_NAMES[${next_day_index}]}"
                    echo "${end_12h}|${next_day_name}|true"
                else
                    echo "${end_12h}|${current_day_name}|false"
                fi
                return 0
            fi
            fi
        fi
    done
    
    return 1  # Not in any range
}

# Show hard-block error when a per-day per-category cap violation is detected.
# Parameters:
#   $1 - use_gui (true/false)
#   $2 - violation_text: multi-line "day|category|minutes" lines from check_daily_caps
show_cap_violation_error() {
    local use_gui="$1"
    local violation_text="$2"

    local title="ERROR: Per-Day 16-Hour Cap Exceeded"

    # Build human-readable violation list
    local details=""
    local line day cat mins
    while IFS='|' read -r day cat mins; do
        [ -z "${day}" ] && continue
        local hours=$(( mins / 60 ))
        local rem=$(( mins % 60 ))
        local cat_label
        case "${cat}" in
            restriction)     cat_label="Restriction hours" ;;
            configure_block) cat_label="Configure-block hours" ;;
            uninstall_block) cat_label="Uninstall-block hours" ;;
            *)               cat_label="${cat}" ;;
        esac
        details="${details}  • ${day}: ${cat_label} = ${hours}h ${rem}m (limit: 16h 0m)\n"
    done <<< "${violation_text}"

    local message="🚫 Configuration cannot be saved.

The following day/category pairs exceed the 16-hour per-day cap:

${details}
Each restriction category may cover at most 16 hours on any single calendar day.

Categories:
  • Restriction hours — popup warning schedule
  • Configure-block hours — configure/manage lock (restriction + lock hours when enabled)
  • Uninstall-block hours — uninstall protection (restriction + uninstall-lock hours when enabled)

Please reduce the configured hours to fix this before saving."

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_info_dialog "${title}" "${message}" 720 480
    else
        echo "" >&2
        echo "========================================" >&2
        echo "ERROR: Per-Day 16-Hour Cap Exceeded" >&2
        echo "========================================" >&2
        echo "" >&2
        echo "${details}" | sed 's/\\n/\n/g' >&2
        echo "Each category may cover at most 16 hours per calendar day." >&2
        echo "Please reduce hours before saving." >&2
        echo "" >&2
        configure_read -rp "Press Enter to continue..."
    fi
}

# Show error when tighten-only partial lock rejects proposed changes at save time.
show_partial_lock_violation_error() {
    local use_gui="$1"
    local violation_text="$2"
    local title="Change Not Allowed During Lock Hours"
    local message="Limited configuration mode is active. The following changes are not allowed:

${violation_text}

During lock hours you may only tighten restrictions (more frequent popups, longer min display, add hours, enable locks)."

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_info_dialog "${title}" "${message}" 720 420
    else
        echo "" >&2
        echo "ERROR: Changes not allowed during lock hours (tighten-only mode):" >&2
        printf '%b\n' "${violation_text}" >&2
        echo "" >&2
        configure_read -rp "Press Enter to continue..."
    fi
}

# Show error message when configure.sh or manage.sh is blocked during restricted hours or lock hours
# This is for Enhancement #19 (Prevent configure.sh and manage.sh Execution)
# Phase 2: Also checks lock hours in addition to restriction hours
# Parameters:
#   $1 - use_gui (true/false)
#   $2 - script_name ("Configuration" or "Management" or custom)
# Dependencies: configure-core.sh (for format_hour_12h, DAY_NAMES), configure-time.sh (for format_ranges_human), config.sh (for parse_config, parse_lock_hours), time-validation.sh (for is_restricted_hour, is_lock_hour, is_hour_in_single_range)
show_config_locked_error() {
    local use_gui="$1"
    local script_name="${2:-Configuration}"
    
    _configure_ui_ensure_time_parsing
    
    # Get current time information
    local current_day current_hour
    current_day=$(date +%w)
    current_hour=$(date +%H)
    current_hour=$((10#${current_hour}))
    
    # Source required modules if not already sourced
    if ! type format_hour_12h >/dev/null 2>&1 || ! type format_ranges_human >/dev/null 2>&1; then
        local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
        source "${SCRIPT_DIR}/lib/configure-core.sh" 2>/dev/null || true
        source "${SCRIPT_DIR}/lib/configure-time.sh" 2>/dev/null || true
    fi
    
    local day_name="${DAY_NAMES[${current_day}]}"
    local current_time_12h
    current_time_12h=$(format_hour_12h "${current_hour}")
    
    # Get config parsing functions
    if ! type parse_config >/dev/null 2>&1 || ! type parse_lock_hours >/dev/null 2>&1; then
        local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
        source "${SCRIPT_DIR}/lib/config.sh" 2>/dev/null || true
    fi
    
    # Get restriction hours for current day
    local restricted_range
    restricted_range=$(parse_config "${current_day}" 2>/dev/null || echo "")
    
    # Get lock hours for current day (Phase 2)
    local lock_hours_range=""
    if type parse_lock_hours >/dev/null 2>&1; then
        lock_hours_range=$(parse_lock_hours "${current_day}" 2>/dev/null || echo "")
    fi
    
    # Check for overnight ranges from previous day
    local prev_day
    if [ "${current_day}" -eq 0 ]; then
        prev_day=6
    else
        prev_day=$((current_day - 1))
    fi
    
    local prev_day_range
    prev_day_range=$(parse_config "${prev_day}" 2>/dev/null || echo "")
    
    local prev_day_lock_hours=""
    if type parse_lock_hours >/dev/null 2>&1; then
        prev_day_lock_hours=$(parse_lock_hours "${prev_day}" 2>/dev/null || echo "")
    fi
    
    # Check if we're in restriction hours or lock hours
    # Get current time in HHMM format (Enhancement 16b)
    local current_time_hhmm
    current_time_hhmm=$(get_current_time)
    
    local in_restriction=false
    local in_lock_hours=false
    
    # Check restriction hours (current day and previous day overnight)
    if type is_restricted_time >/dev/null 2>&1; then
        if is_restricted_time "${current_time_hhmm}" "${restricted_range}"; then
            in_restriction=true
        elif [ -n "${prev_day_range}" ]; then
            # Check previous day's overnight ranges
            local IFS=','
            for range in ${prev_day_range}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                # Normalize range to HHMM format for comparison
                local start_time end_time
                local start_part="${range%%-*}"
                local end_part="${range##*-}"
                
                if [[ "${start_part}" =~ : ]]; then
                    start_time=$(echo "${start_part}" | tr -d ':')
                else
                    start_time=$(printf "%02d00" "${start_part}")
                fi
                
                if [[ "${end_part}" =~ : ]]; then
                    end_time=$(echo "${end_part}" | tr -d ':')
                else
                    end_time=$(printf "%02d00" "${end_part}")
                fi
                
                if [ "${start_time}" -gt "${end_time}" ]; then
                    # Overnight range: check if current time falls within the end portion
                    if [ "${current_time_hhmm}" -lt "${end_time}" ]; then
                        in_restriction=true
                        break
                    fi
                fi
            done
            unset IFS
        fi
    fi
    
    # Check lock hours (current day and previous day overnight) - Phase 2
    if type is_restricted_time >/dev/null 2>&1; then
        if [ -n "${lock_hours_range}" ] && is_restricted_time "${current_time_hhmm}" "${lock_hours_range}"; then
            in_lock_hours=true
        elif [ -n "${prev_day_lock_hours}" ]; then
            # Check previous day's overnight lock hours
            local IFS=','
            for range in ${prev_day_lock_hours}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                # Normalize range to HHMM format for comparison
                local start_time end_time
                local start_part="${range%%-*}"
                local end_part="${range##*-}"
                
                if [[ "${start_part}" =~ : ]]; then
                    start_time=$(echo "${start_part}" | tr -d ':')
                else
                    start_time=$(printf "%02d00" "${start_part}")
                fi
                
                if [[ "${end_part}" =~ : ]]; then
                    end_time=$(echo "${end_part}" | tr -d ':')
                else
                    end_time=$(printf "%02d00" "${end_part}")
                fi
                
                if [ "${start_time}" -gt "${end_time}" ]; then
                    # Overnight range: check if current time falls within the end portion
                    if [ "${current_time_hhmm}" -lt "${end_time}" ]; then
                        in_lock_hours=true
                        break
                    fi
                fi
            done
            unset IFS
        fi
    fi
    
    # Determine lock type and build appropriate message
    local lock_type=""
    local active_range_formatted=""
    local end_info=""
    
    if [ "${in_restriction}" = "true" ] && [ "${in_lock_hours}" = "true" ]; then
        # Blocked by both
        lock_type="both"
        
        # Format restriction hours
        local restriction_formatted=""
        if [ -n "${restricted_range}" ]; then
            restriction_formatted=$(format_ranges_human "${restricted_range}" "${day_name}" 2>/dev/null || echo "")
        fi
        if [ -z "${restriction_formatted}" ] && [ -n "${prev_day_range}" ]; then
            # Check previous day's overnight range
            local IFS=','
            for range in ${prev_day_range}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start_part end_part
                start_part="${range%%-*}"
                end_part="${range##*-}"
                start_part=$(echo "${start_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                end_part=$(echo "${end_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if range_overnight_tail_active_for_hour "${current_hour}" "${start_part}" "${end_part}"; then
                    local prev_day_name="${DAY_NAMES[${prev_day}]}"
                    restriction_formatted=$(format_range_human "${range}" "${prev_day_name}" 2>/dev/null || echo "")
                    break
                fi
            done
            unset IFS
        fi
        
        # Format lock hours
        local lock_formatted=""
        if [ -n "${lock_hours_range}" ]; then
            lock_formatted=$(format_ranges_human "${lock_hours_range}" "${day_name}" 2>/dev/null || echo "")
        fi
        if [ -z "${lock_formatted}" ] && [ -n "${prev_day_lock_hours}" ]; then
            # Check previous day's overnight lock hours
            local IFS=','
            for range in ${prev_day_lock_hours}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start_part end_part
                start_part="${range%%-*}"
                end_part="${range##*-}"
                start_part=$(echo "${start_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                end_part=$(echo "${end_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if range_overnight_tail_active_for_hour "${current_hour}" "${start_part}" "${end_part}"; then
                    local prev_day_name="${DAY_NAMES[${prev_day}]}"
                    lock_formatted=$(format_range_human "${range}" "${prev_day_name}" 2>/dev/null || echo "")
                    break
                fi
            done
            unset IFS
        fi
        
        # Combine formatted ranges
        if [ -n "${restriction_formatted}" ] && [ -n "${lock_formatted}" ]; then
            active_range_formatted="Restriction: ${restriction_formatted}, Lock: ${lock_formatted}"
        elif [ -n "${restriction_formatted}" ]; then
            active_range_formatted="Restriction: ${restriction_formatted}, Lock: (configured)"
        elif [ -n "${lock_formatted}" ]; then
            active_range_formatted="Restriction: (configured), Lock: ${lock_formatted}"
        else
            active_range_formatted="Restriction and Lock hours (both active)"
        fi
        
        # Calculate end times for both and find earliest
        local restriction_end=""
        local lock_end=""
        
        restriction_end=$(calculate_restriction_end_time "${current_hour}" "${current_day}" "${restricted_range}" 2>/dev/null || echo "")
        if [ -n "${lock_hours_range}" ]; then
            lock_end=$(calculate_restriction_end_time "${current_hour}" "${current_day}" "${lock_hours_range}" 2>/dev/null || echo "")
        fi
        # If lock_end still empty, we may be in previous day's overnight lock hours
        if [ -z "${lock_end}" ] && [ -n "${prev_day_lock_hours}" ]; then
            local IFS=','
            for range in ${prev_day_lock_hours}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start_part end_part
                start_part="${range%%-*}"
                end_part="${range##*-}"
                start_part=$(echo "${start_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                end_part=$(echo "${end_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if range_overnight_tail_active_for_hour "${current_hour}" "${start_part}" "${end_part}"; then
                    local end_12h
                    end_12h=$(format_hour_12h "${end_part}")
                    lock_end="${end_12h}|${day_name}|true"
                    break
                fi
            done
            unset IFS
        fi
        
        # Use restriction end if available, otherwise lock end (user can retry when first period ends)
        end_info="${restriction_end}"
        if [ -z "${end_info}" ] && [ -n "${lock_end}" ]; then
            end_info="${lock_end}"
        fi
        
    elif [ "${in_restriction}" = "true" ]; then
        # Blocked by restriction hours only (Phase 1 behavior)
        lock_type="restriction"
        
        # Format restriction hours (same as Phase 1)
        if [ -n "${restricted_range}" ]; then
            active_range_formatted=$(format_ranges_human "${restricted_range}" "${day_name}" 2>/dev/null || echo "")
        fi
        if [ -z "${active_range_formatted}" ] && [ -n "${prev_day_range}" ]; then
            # Check previous day's overnight range
            local IFS=','
            for range in ${prev_day_range}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start_part end_part
                start_part="${range%%-*}"
                end_part="${range##*-}"
                start_part=$(echo "${start_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                end_part=$(echo "${end_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if range_overnight_tail_active_for_hour "${current_hour}" "${start_part}" "${end_part}"; then
                    local prev_day_name="${DAY_NAMES[${prev_day}]}"
                    active_range_formatted=$(format_range_human "${range}" "${prev_day_name}" 2>/dev/null || echo "")
                    break
                fi
            done
            unset IFS
        fi
        
        # Calculate when restrictions end
        end_info=$(calculate_restriction_end_time "${current_hour}" "${current_day}" "${restricted_range}" 2>/dev/null || echo "")
        
    elif [ "${in_lock_hours}" = "true" ]; then
        # Blocked by lock hours only (Phase 2)
        lock_type="lock"
        
        # Format lock hours
        if [ -n "${lock_hours_range}" ]; then
            active_range_formatted=$(format_ranges_human "${lock_hours_range}" "${day_name}" 2>/dev/null || echo "")
        fi
        if [ -z "${active_range_formatted}" ] && [ -n "${prev_day_lock_hours}" ]; then
            # Check previous day's overnight lock hours
            local IFS=','
            for range in ${prev_day_lock_hours}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start_part end_part
                start_part="${range%%-*}"
                end_part="${range##*-}"
                start_part=$(echo "${start_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                end_part=$(echo "${end_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if range_overnight_tail_active_for_hour "${current_hour}" "${start_part}" "${end_part}"; then
                    local prev_day_name="${DAY_NAMES[${prev_day}]}"
                    active_range_formatted=$(format_range_human "${range}" "${prev_day_name}" 2>/dev/null || echo "")
                    break
                fi
            done
            unset IFS
        fi
        
        # Calculate when lock hours end (current day's lock range)
        if [ -n "${lock_hours_range}" ]; then
            end_info=$(calculate_restriction_end_time "${current_hour}" "${current_day}" "${lock_hours_range}" 2>/dev/null || echo "")
        fi
        # If still no end time, we may be in previous day's overnight lock hours
        if [ -z "${end_info}" ] && [ -n "${prev_day_lock_hours}" ]; then
            local IFS=','
            for range in ${prev_day_lock_hours}; do
                range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                local start_part end_part
                start_part="${range%%-*}"
                end_part="${range##*-}"
                start_part=$(echo "${start_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                end_part=$(echo "${end_part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if range_overnight_tail_active_for_hour "${current_hour}" "${start_part}" "${end_part}"; then
                    local end_12h
                    end_12h=$(format_hour_12h "${end_part}")
                    end_info="${end_12h}|${day_name}|true"
                    break
                fi
            done
            unset IFS
        fi
    else
        # Should not happen (function should only be called when blocked)
        lock_type="unknown"
        active_range_formatted="(unknown)"
    fi
    
    # Build error message based on lock type
    local error_msg=""
    case "${lock_type}" in
        "both")
            error_msg="${script_name} is locked during restricted hours and configured lock hours.\n\n"
            ;;
        "restriction")
            error_msg="${script_name} is locked during restricted hours.\n\n"
            ;;
        "lock")
            error_msg="${script_name} is locked during configured lock hours.\n\n"
            ;;
        *)
            error_msg="${script_name} is locked.\n\n"
            ;;
    esac
    
    error_msg="${error_msg}Current time: ${day_name}, ${current_time_12h}\n"
    
    if [ -n "${active_range_formatted}" ] && [ "${active_range_formatted}" != "(no restrictions)" ]; then
        if [ "${lock_type}" = "both" ]; then
            error_msg="${error_msg}Active locks: ${active_range_formatted}\n"
        elif [ "${lock_type}" = "restriction" ]; then
            error_msg="${error_msg}Active restriction: ${active_range_formatted}\n"
        elif [ "${lock_type}" = "lock" ]; then
            error_msg="${error_msg}Active lock hours: ${active_range_formatted}\n"
        else
            error_msg="${error_msg}Active: ${active_range_formatted}\n"
        fi
    fi
    
    if [ -n "${end_info}" ]; then
        local end_time end_day is_overnight
        end_time=$(echo "${end_info}" | cut -d'|' -f1)
        end_day=$(echo "${end_info}" | cut -d'|' -f2)
        is_overnight=$(echo "${end_info}" | cut -d'|' -f3)
        
        if [ "${is_overnight}" = "true" ]; then
            error_msg="${error_msg}Lock ends: ${end_time} on ${end_day}\n"
        else
            error_msg="${error_msg}Lock ends: ${end_time} today\n"
        fi
    fi
    
    error_msg="${error_msg}\nPlease try again after the lock period ends."
    
    # Display error message
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_info_dialog "${script_name} Locked" "${error_msg}" 650 350
    else
        echo "" >&2
        case "${lock_type}" in
            "both")
                echo "Error: ${script_name} is locked during restricted hours and configured lock hours." >&2
                ;;
            "restriction")
                echo "Error: ${script_name} is locked during restricted hours." >&2
                ;;
            "lock")
                echo "Error: ${script_name} is locked during configured lock hours." >&2
                ;;
            *)
                echo "Error: ${script_name} is locked." >&2
                ;;
        esac
        echo "" >&2
        echo "Current time: ${day_name}, ${current_time_12h}" >&2
        if [ -n "${active_range_formatted}" ] && [ "${active_range_formatted}" != "(no restrictions)" ]; then
            if [ "${lock_type}" = "both" ]; then
                echo "Active locks: ${active_range_formatted}" >&2
            elif [ "${lock_type}" = "restriction" ]; then
                echo "Active restriction: ${active_range_formatted}" >&2
            elif [ "${lock_type}" = "lock" ]; then
                echo "Active lock hours: ${active_range_formatted}" >&2
            else
                echo "Active: ${active_range_formatted}" >&2
            fi
        fi
        if [ -n "${end_info}" ]; then
            local end_time end_day is_overnight
            end_time=$(echo "${end_info}" | cut -d'|' -f1)
            end_day=$(echo "${end_info}" | cut -d'|' -f2)
            is_overnight=$(echo "${end_info}" | cut -d'|' -f3)
            if [ "${is_overnight}" = "true" ]; then
                echo "Lock ends: ${end_time} on ${end_day}" >&2
            else
                echo "Lock ends: ${end_time} today" >&2
            fi
        fi
        echo "" >&2
        echo "Please try again after the lock period ends." >&2
        echo "" >&2
    fi
}

# Show error when config file is locked (Enhancement #18)
# This function displays an error message when the user tries to save configuration
# but the config file is locked due to restricted hours or lock hours
# Parameters:
#   $1 - use_gui (true/false)
# Dependencies: Same as show_config_locked_error
show_config_file_locked_error() {
    local use_gui="$1"
    
    # Reuse the same logic as show_config_locked_error but with different message
    show_config_locked_error "${use_gui}" "Configuration File"
}
