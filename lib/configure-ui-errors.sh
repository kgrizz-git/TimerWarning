#!/bin/bash

###############################################################################
# Sleep Warning System - Configure UI error dialogs
#
# Lock/cap/partial-lock error display for the configure wizard.
# Sourced by configure-ui.sh (stable public function names).
#
# Dependencies: configure-core.sh, configure-time.sh, configure-dialogs.sh,
# config.sh, time-parsing.sh, time-calculations.sh (calculate_restriction_end_time)
###############################################################################

_configure_ui_errors_ensure_invariants() {
    if type safety_invariant_footer >/dev/null 2>&1; then
        return 0
    fi
    local _dir
    _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck disable=SC1091
    [ -f "${_dir}/safety-invariants.sh" ] && source "${_dir}/safety-invariants.sh"
}
_configure_ui_errors_ensure_deps() {
    if type _configure_ui_ensure_time_parsing >/dev/null 2>&1; then
        _configure_ui_ensure_time_parsing
    else
        local _dir
        _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # shellcheck disable=SC1091
        [ -f "${_dir}/time-parsing.sh" ] && source "${_dir}/time-parsing.sh"
    fi
    if ! type format_hour_12h >/dev/null 2>&1 || ! type format_endpoint_12h >/dev/null 2>&1 || ! type format_ranges_human >/dev/null 2>&1; then
        local _dir
        _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # shellcheck disable=SC1091
        [ -f "${_dir}/configure-core.sh" ] && source "${_dir}/configure-core.sh"
        # shellcheck disable=SC1091
        [ -f "${_dir}/configure-time.sh" ] && source "${_dir}/configure-time.sh"
    fi
    if ! type parse_config >/dev/null 2>&1 || ! type parse_lock_hours >/dev/null 2>&1; then
        local _dir
        _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # shellcheck disable=SC1091
        [ -f "${_dir}/config.sh" ] && source "${_dir}/config.sh"
    fi
    if ! type calculate_restriction_end_time >/dev/null 2>&1; then
        local _dir
        _dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # shellcheck disable=SC1091
        [ -f "${_dir}/time-calculations.sh" ] && source "${_dir}/time-calculations.sh"
    fi
}

# Show hard-block error when a per-day per-category cap violation is detected.
# Parameters:
#   $1 - use_gui (true/false)
#   $2 - violation_text: multi-line "day|category|minutes" lines from check_daily_caps
show_cap_violation_error() {
    local use_gui="$1"
    local violation_text="$2"

    _configure_ui_errors_ensure_invariants

    local title="ERROR: Per-Day 16-Hour Cap Exceeded"

    # Build human-readable violation list
    local details=""
    local line day cat mins inv_id
    while IFS='|' read -r day cat mins; do
        [ -z "${day}" ] && continue
        local hours=$(( mins / 60 ))
        local rem=$(( mins % 60 ))
        local cat_label
        inv_id="$(safety_invariant_id_for_category "${cat}")"
        case "${cat}" in
            restriction)     cat_label="Restriction hours" ;;
            configure_block) cat_label="Configure-block hours" ;;
            uninstall_block) cat_label="Uninstall-block hours" ;;
            *)               cat_label="${cat}" ;;
        esac
        details="${details}  • [${inv_id}] ${day}: ${cat_label} = ${hours}h ${rem}m (limit: 16h 0m)\n"
    done <<< "${violation_text}"

    local safety_footer
    safety_footer="$(safety_invariant_footer "${INV_CAP_RESTRICTION_DAY}")"

    local message="🚫 Configuration cannot be saved.

The following day/category pairs exceed the 16-hour per-day cap:

${details}
Each restriction category may cover at most 16 hours on any single calendar day.

Categories:
  • Restriction hours — popup warning schedule
  • Configure-block hours — configure/manage lock (restriction + lock hours when enabled)
  • Uninstall-block hours — uninstall protection (restriction + uninstall-lock hours when enabled)

Please reduce the configured hours to fix this before saving.${safety_footer}"

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
        safety_invariant_tag "${INV_CAP_RESTRICTION_DAY}" >&2
        safety_invariant_doc_link "${INV_CAP_RESTRICTION_DAY}" >&2
        echo "" >&2
        configure_read -rp "Press Enter to continue..."
    fi
}

# Show hard-block error when input-time cap validation rejects a proposed range.
# Uses a tkinter text dialog on macOS (osascript alerts can hide behind the terminal
# after the time picker closes). Save-time cap errors use show_cap_violation_error.
# Parameters:
#   $1 - use_gui (true/false)
#   $2 - violation_text: multi-line "day|category|minutes" lines from check_daily_caps
show_input_time_cap_violation_error() {
    local use_gui="$1"
    local violation_text="$2"

    _configure_ui_errors_ensure_invariants

    local title="Time Range Exceeds 16-Hour Limit"

    local details=""
    local line day cat mins inv_id
    while IFS='|' read -r day cat mins; do
        [ -z "${day}" ] && continue
        local hours=$(( mins / 60 ))
        local rem=$(( mins % 60 ))
        local cat_label
        inv_id="$(safety_invariant_id_for_category "${cat}")"
        case "${cat}" in
            restriction)     cat_label="Restriction hours" ;;
            configure_block) cat_label="Configure-block hours" ;;
            uninstall_block) cat_label="Uninstall-block hours" ;;
            *)               cat_label="${cat}" ;;
        esac
        details="${details}  • [${inv_id}] ${day}: ${cat_label} = ${hours}h ${rem}m (limit: 16h 0m)\n"
    done <<< "${violation_text}"

    local safety_footer
    safety_footer="$(safety_invariant_footer "${INV_CAP_RESTRICTION_DAY}")"

    local message="This time range cannot be accepted.

The per-day limit is 16 hours in each category (popup restrictions, configure-block, uninstall-block). Your selection exceeds that limit on:

${details}
Overnight ranges (for example 9pm–6am or 9pm–6pm) count toward both the start day and the next calendar day. Use shorter ranges or different hours.

Each category may cover at most 16 hours on any single calendar day.${safety_footer}"

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # Prefer scrollable text dialog: visible after macOS tkinter time picker (z-order safe).
        if type show_text_info_dialog >/dev/null 2>&1; then
            show_text_info_dialog "${title}" "${message}" 720 520
        elif type show_error_dialog >/dev/null 2>&1; then
            show_error_dialog "${title}" "${message}" 720 520
        else
            show_info_dialog "${title}" "${message}" 720 520
        fi
    else
        echo "" >&2
        echo "========================================" >&2
        echo "Time Range Exceeds 16-Hour Limit" >&2
        echo "========================================" >&2
        echo "" >&2
        echo "This time range cannot be accepted." >&2
        echo "" >&2
        echo "${details}" | sed 's/\\n/\n/g' >&2
        echo "Overnight ranges count toward both the start day and the next calendar day." >&2
        echo "Each category may cover at most 16 hours per calendar day." >&2
        safety_invariant_tag "${INV_CAP_RESTRICTION_DAY}" >&2
        safety_invariant_doc_link "${INV_CAP_RESTRICTION_DAY}" >&2
        echo "" >&2
        configure_read -rp "Press Enter to try again..."
    fi
}

# Show error when tighten-only partial lock rejects proposed changes at save time.
show_partial_lock_violation_error() {
    local use_gui="$1"
    local violation_text="$2"

    _configure_ui_errors_ensure_invariants

    local title="Change Not Allowed During Lock Hours"
    local safety_footer
    safety_footer="$(safety_invariant_footer "${INV_PARTIAL_LOCK_TIGHTEN}")"
    local message="Limited configuration mode is active. The following changes are not allowed:

${violation_text}

During lock hours you may only tighten restrictions (more frequent popups, longer min display, add hours, enable locks).${safety_footer}"

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        show_info_dialog "${title}" "${message}" 720 420
    else
        echo "" >&2
        echo "ERROR: Changes not allowed during lock hours (tighten-only mode):" >&2
        printf '%b\n' "${violation_text}" >&2
        safety_invariant_tag "${INV_PARTIAL_LOCK_TIGHTEN}" >&2
        safety_invariant_doc_link "${INV_PARTIAL_LOCK_TIGHTEN}" >&2
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
    
    _configure_ui_errors_ensure_deps
    
    # Get current time information
    local current_day current_hour
    current_day=$(date +%w)
    current_hour=$(date +%H)
    current_hour=$((10#${current_hour}))
    
    
    local day_name="${DAY_NAMES[${current_day}]}"
    local current_time_12h
    current_time_12h=$(format_hour_12h "${current_hour}")
    
    
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
        if is_restricted_time "${current_time_hhmm}" "${restricted_range}" self; then
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
        if [ -n "${lock_hours_range}" ] && is_restricted_time "${current_time_hhmm}" "${lock_hours_range}" self; then
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
                    end_12h=$(format_endpoint_12h "${end_part}") || continue
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
                    end_12h=$(format_endpoint_12h "${end_part}") || continue
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
