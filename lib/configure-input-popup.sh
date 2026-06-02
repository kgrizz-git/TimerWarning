#!/bin/bash

###############################################################################
# Sleep Warning System - Popup Settings Input Collection Module
#
# This module provides popup-related user input collection functions for the
# configuration wizard, supporting both GUI (YAD/Zenity/KDialog) and text modes.
#
# Functions:
# - get_popup_size_config()        - Get popup size from user
# - get_custom_popup_size_config() - Get custom popup size configuration (helper)
# - get_min_display_time_config()  - Get minimum display time
# - get_popup_immovable_config()   - Get immovable setting
# - get_popup_auto_close_config() - Get auto-close setting (Enhancement #15)
# - get_popup_size_mode_config()  - Get popup size mode (percentage vs fixed; config value remains display-based)
# - get_popup_position_config()   - Get popup position
#
# Dependencies:
# - configure-core.sh (for has_dialog_tool, CONFIG_FILE)
# - configure-dialogs.sh (for dialog abstraction functions)
# - configure-ui.sh (for confirm_cancel)
# - display-detection.sh (for get_display_resolution - used in custom size validation)
###############################################################################

# Popup size input functions are sourced from a submodule to keep this file smaller.
_CONFIGURE_INPUT_POPUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
if [ -f "${_CONFIGURE_INPUT_POPUP_DIR}/configure-input-popup-size.sh" ]; then
    source "${_CONFIGURE_INPUT_POPUP_DIR}/configure-input-popup-size.sh"
fi
unset _CONFIGURE_INPUT_POPUP_DIR

# Handle GUI cancel on a Window Behavior sub-prompt. return 3 = retry caller loop.
_handle_window_behavior_gui_cancel() {
    local use_gui="$1"
    local menu_prompt="${2:-What would you like to do?}"
    local menu_result
    menu_result=$(handle_window_behavior_cancel_menu "${use_gui}" "${menu_prompt}")
    local menu_exit=$?
    case ${menu_exit} in
        1)
            echo "${menu_result}"
            return 1
            ;;
        2)
            echo "${menu_result}"
            return 2
            ;;
        3)
            return 3
            ;;
    esac
}

# Map friendly on/off list labels to true/false config values.
_map_on_off_list_to_bool() {
    case "$1" in
        "Yes, prevent movement"|"Yes, enable auto-close") echo "true" ;;
        "No, allow movement"|"No, disable auto-close") echo "false" ;;
        "true"|"false") echo "$1" ;;
        *) echo "" ;;
    esac
}

# Resolve the popup display frequency (in minutes) currently in effect for the
# wizard session: prefer the in-progress value, then live config, then default.
# Used to bound min-display time so popups never outlast their interval and stack
# (see validate_popup_timing_config).
_resolve_current_popup_frequency() {
    local freq="${check_interval:-}"
    if [ -z "${freq}" ] || ! [[ "${freq}" =~ ^[0-9]+$ ]] || \
       [ "${freq}" -lt "${MIN_CHECK_INTERVAL}" ] || [ "${freq}" -gt "${MAX_CHECK_INTERVAL}" ]; then
        if type get_popup_display_frequency >/dev/null 2>&1; then
            freq=$(get_popup_display_frequency)
        elif [ -f "${CONFIG_FILE}" ]; then
            freq=$(grep -E "^[[:space:]]*POPUP_DISPLAY_FREQUENCY=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
            [ -z "${freq}" ] && freq=$(grep -E "^[[:space:]]*CHECK_INTERVAL=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        fi
        if [ -z "${freq}" ] || ! [[ "${freq}" =~ ^[0-9]+$ ]]; then
            freq=10  # Default
        fi
    fi
    echo "${freq}"
}

# Get minimum display time from user
get_min_display_time_config() {
    local use_gui="$1"
    local default_time="${DEFAULT_MIN_DISPLAY_TIME:-30}"
    local max_display_limit
    max_display_limit=$(get_max_min_display_time_limit)

    # The effective ceiling is the smaller of the absolute cap and the popup
    # display frequency (in seconds): a min-display longer than the interval
    # would let popups stack. Surface that up front instead of only on rejection.
    local freq_minutes effective_max freq_note=""
    freq_minutes=$(_resolve_current_popup_frequency)
    effective_max="${max_display_limit}"
    if [ $((freq_minutes * 60)) -lt "${effective_max}" ]; then
        effective_max=$((freq_minutes * 60))
        freq_note=$'\n'"(Capped at ${effective_max}s by popup frequency of ${freq_minutes} min — raise the frequency to allow a longer time.)"
    fi

    local min_display_prompt
    min_display_prompt=$'Minimum time popup must be visible before it can be closed:\n\n'"Enter time in seconds (${MIN_DISPLAY_TIME}-${effective_max}):"$'\n'"(${MIN_DISPLAY_TIME} = disabled, ${default_time} = default)""${freq_note}"

    # Try to get existing time from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_time
        existing_time=$(grep -E "^[[:space:]]*POPUP_MIN_DISPLAY_TIME=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_time}" ] && [[ "${existing_time}" =~ ^[0-9]+$ ]]; then
            default_time="${existing_time}"
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local time
            time=$(show_entry_dialog \
                "Sleep Warning Configuration" \
                "${min_display_prompt}" \
                "${default_time}")
            local exit_code=$?
            
            # User cancelled
            if [ "${exit_code}" -ne 0 ] || [ -z "${time}" ]; then
                local cancel_action cancel_rc
                cancel_action=$(_handle_window_behavior_gui_cancel "${use_gui}" "You cancelled minimum display time setup.")
                cancel_rc=$?
                case ${cancel_rc} in
                    1|2) echo "${cancel_action}"; return "${cancel_rc}" ;;
                    3) continue ;;
                esac
            fi
            
            # Validate time against the effective ceiling (absolute cap AND popup
            # frequency). When the frequency is the binding limit, explain why.
            if ! [[ "${time}" =~ ^[0-9]+$ ]] || [ "${time}" -lt "${MIN_DISPLAY_TIME}" ] || [ "${time}" -gt "${effective_max}" ]; then
                local _invalid_msg="Invalid time. Please enter a number between ${MIN_DISPLAY_TIME} and ${effective_max} seconds."
                if [ -n "${freq_note}" ]; then
                    _invalid_msg="${_invalid_msg}"$'\n\n'"${effective_max}s is the most you can require: popups appear every ${freq_minutes} min (${effective_max}s), and a longer minimum would let popups stack. Raise the popup display frequency first to allow a longer time."
                fi
                show_info_dialog \
                    "Invalid Time" \
                    "${_invalid_msg}"
                continue
            fi

            # Defense in depth: authoritative timing check (Enhancement #9/#30).
            if type validate_popup_timing_config >/dev/null 2>&1; then
                local validation_error
                validation_error=$(validate_popup_timing_config "${time}" "${freq_minutes}" 2>&1)
                if [ $? -ne 0 ]; then
                    # Hard error - block user from proceeding
                    show_error_dialog \
                        "Configuration Error" \
                        "${validation_error}"
                    continue  # Re-prompt
                fi
            fi

            if type configure_partial_lock_reject_scalar_change >/dev/null 2>&1; then
                local _pl_base="${_baseline_min_display_time:-${default_time}}"
                if ! configure_partial_lock_reject_scalar_change "min_display_time" "${_pl_base}" "${time}" "${use_gui}"; then
                    continue
                fi
            fi
            
            echo "${time}"
            return 0
        done
    else
        # Text mode
        while true; do
            local _freq_hint=""
            [ -n "${freq_note}" ] && _freq_hint=", capped by ${freq_minutes}-min popup frequency"
            configure_read -p "Minimum display time in seconds (${MIN_DISPLAY_TIME}-${effective_max}${_freq_hint}, ${MIN_DISPLAY_TIME}=disabled) [${default_time}]: " time
            time=${time:-${default_time}}

            if [[ "${time}" =~ ^[0-9]+$ ]] && [ "${time}" -ge "${MIN_DISPLAY_TIME}" ] && [ "${time}" -le "${effective_max}" ]; then
                # Defense in depth: authoritative timing check (Enhancement #9/#30).
                if type validate_popup_timing_config >/dev/null 2>&1; then
                    local validation_error
                    validation_error=$(validate_popup_timing_config "${time}" "${freq_minutes}" 2>&1)
                    if [ $? -ne 0 ]; then
                        # Hard error - block user from proceeding
                        echo "" >&2
                        echo "ERROR: ${validation_error}" >&2
                        echo "" >&2
                        continue  # Re-prompt
                    fi
                fi

                if type configure_partial_lock_reject_scalar_change >/dev/null 2>&1; then
                    local _pl_base="${_baseline_min_display_time:-${default_time}}"
                    if ! configure_partial_lock_reject_scalar_change "min_display_time" "${_pl_base}" "${time}" "${use_gui}"; then
                        continue
                    fi
                fi

                echo "${time}"
                return 0
            else
                echo "Invalid time. Please enter a number between ${MIN_DISPLAY_TIME} and ${effective_max}." >&2
                if [ -n "${freq_note}" ] && [[ "${time}" =~ ^[0-9]+$ ]] && [ "${time}" -gt "${effective_max}" ]; then
                    echo "(${effective_max}s is the cap because popups appear every ${freq_minutes} min; raise the popup display frequency to allow a longer minimum.)" >&2
                fi
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
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        local default_label="Off"
        [ "${default_immovable}" = "true" ] && default_label="On"
        local darwin_note=""
        if type is_darwin >/dev/null 2>&1 && is_darwin; then
            darwin_note=$'\n\nNote: On macOS this is saved for config compatibility but window movement is not enforced (Linux only).'
        fi
        local immovable_message
        immovable_message="Prevent popup window from being moved during minimum display time?${darwin_note}"$'\n\n'"Current setting: ${default_label}"

        while true; do
            local immovable_result immovable
            immovable_result=$(show_list_dialog \
                "Sleep Warning Configuration" \
                "${immovable_message}" \
                620 \
                340 \
                "Yes, prevent movement" "No, allow movement")
            local exit_code=$?

            if [ ${exit_code} -eq 0 ] && [ -n "${immovable_result}" ]; then
                immovable=$(_map_on_off_list_to_bool "${immovable_result}")
            else
                immovable=""
            fi

            if [ -n "${immovable}" ]; then
                if type configure_partial_lock_reject_scalar_change >/dev/null 2>&1; then
                    local _pl_base="${_baseline_popup_immovable:-${default_immovable}}"
                    if ! configure_partial_lock_reject_scalar_change "popup_immovable" "${_pl_base}" "${immovable}" "${use_gui}"; then
                        continue
                    fi
                fi
                echo "${immovable}"
                return 0
            fi

            local cancel_action cancel_rc
            cancel_action=$(_handle_window_behavior_gui_cancel "${use_gui}" "You cancelled immovable window setup.")
            cancel_rc=$?
            case ${cancel_rc} in
                1|2) echo "${cancel_action}"; return "${cancel_rc}" ;;
                3) continue ;;
            esac
        done
    else
        # Text mode
        echo "" >&2
        local darwin_note=""
        if type is_darwin >/dev/null 2>&1 && is_darwin; then
            darwin_note=$'\n\nNote: On macOS this is saved for config compatibility but window movement is not enforced (Linux only).'
        fi
        echo "Popup Immovable Setting:${darwin_note}" >&2
        echo "  Prevents the popup window from being moved during minimum display time" >&2
        echo "  by monitoring and restoring its position if moved." >&2
        echo "" >&2
        while true; do
            configure_read -p "Prevent window movement? [y/n, default: ${default_immovable}]: " choice
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

get_popup_auto_close_config() {
    local use_gui="$1"
    local default_auto_close="true"
    
    # Try to get existing setting from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_auto_close
        existing_auto_close=$(grep -E "^[[:space:]]*POPUP_AUTO_CLOSE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -n "${existing_auto_close}" ]; then
            if [ "${existing_auto_close}" = "true" ] || [ "${existing_auto_close}" = "1" ] || [ "${existing_auto_close}" = "yes" ]; then
                default_auto_close="true"
            elif [ "${existing_auto_close}" = "false" ] || [ "${existing_auto_close}" = "0" ] || [ "${existing_auto_close}" = "no" ]; then
                default_auto_close="false"
            fi
        fi
    fi
    
    # Get minimum display time for reference
    local min_display_time="0"
    local max_display_limit
    max_display_limit=$(get_max_min_display_time_limit)
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_time
        existing_time=$(grep -E "^[[:space:]]*POPUP_MIN_DISPLAY_TIME=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_time}" ] && [[ "${existing_time}" =~ ^[0-9]+$ ]] && [ "${existing_time}" -ge "${MIN_DISPLAY_TIME}" ] && [ "${existing_time}" -le "${max_display_limit}" ]; then
            min_display_time="${existing_time}"
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local auto_close auto_close_result
            local message
            local default_label="Off"
            [ "${default_auto_close}" = "true" ] && default_label="On"
            if [ "${min_display_time}" -gt 0 ]; then
                message=$'Automatically close popup window 10 seconds after minimum display time completes?\n\n'"Current minimum display time: ${min_display_time} seconds"$'\n'"Auto-close will happen after ${min_display_time} + 10 = $((min_display_time + 10)) seconds total"$'\n\n'"Current setting: ${default_label}"
            else
                message=$'Automatically close popup window 10 seconds after it appears?\n\n'"Current minimum display time: 0 seconds (disabled)"$'\n'"Auto-close will happen after 10 seconds"$'\n\n'"Current setting: ${default_label}"
            fi

            auto_close_result=$(show_list_dialog \
                "Sleep Warning Configuration" \
                "${message}" \
                620 \
                360 \
                "Yes, enable auto-close" "No, disable auto-close")
            local exit_code=$?

            if [ ${exit_code} -eq 0 ] && [ -n "${auto_close_result}" ]; then
                auto_close=$(_map_on_off_list_to_bool "${auto_close_result}")
            else
                auto_close=""
            fi

            if [ -n "${auto_close}" ]; then
                echo "${auto_close}"
                return 0
            fi

            local cancel_action cancel_rc
            cancel_action=$(_handle_window_behavior_gui_cancel "${use_gui}" "You cancelled auto-close setup.")
            cancel_rc=$?
            case ${cancel_rc} in
                1|2) echo "${cancel_action}"; return "${cancel_rc}" ;;
                3) continue ;;
            esac
        done
    else
        # Text mode
        echo "" >&2
        echo "Popup Auto-Close Setting:" >&2
        echo "  Automatically closes the popup window 10 seconds after minimum display time completes" >&2
        if [ "${min_display_time}" -gt 0 ]; then
            echo "  Current minimum display time: ${min_display_time} seconds" >&2
            echo "  Auto-close will happen after ${min_display_time} + 10 = $((min_display_time + 10)) seconds total" >&2
        else
            echo "  Current minimum display time: 0 seconds (disabled)" >&2
            echo "  Auto-close will happen after 10 seconds" >&2
        fi
        echo "" >&2
        while true; do
            configure_read -p "Enable auto-close? [y/n, default: ${default_auto_close}]: " choice
            choice=${choice:-${default_auto_close}}
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
                    echo "${default_auto_close}"
                    return 0
                    ;;
                *)
                    echo "Invalid choice. Please enter 'y' for yes or 'n' for no." >&2
                    ;;
            esac
        done
    fi
}

get_popup_size_mode_config() {
    local use_gui="$1"
    local default_mode="fixed"
    
    # Try to get existing mode from config
    if [ -f "${CONFIG_FILE}" ]; then
        local existing_mode
        existing_mode=$(grep -E "^[[:space:]]*POPUP_SIZE_MODE=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ "${existing_mode}" = "display-based" ]; then
            default_mode="display-based"
        fi
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local mode_result
            local mode_display_name="${default_mode}"
            [ "${default_mode}" = "display-based" ] && mode_display_name="percentage"
            mode_result=$(show_list_dialog \
                "Sleep Warning Configuration - Size Mode" \
                "Select window size calculation mode:\n\nCurrent: ${mode_display_name}\n\n- fixed: Use absolute pixel sizes (backward compatible)\n- percentage: Percentage-based sizing (calculates sizes as percentage of screen resolution)\n\nNote: Percentage-based mode adapts to different screen sizes automatically." \
                600 \
                350 \
                "fixed (Absolute Pixels)" "Percentage (Percentage of Screen)")
            local exit_code=$?
            
            if [ ${exit_code} -ne 0 ] || [ -z "${mode_result}" ]; then
                local cancel_action cancel_rc
                cancel_action=$(_handle_window_behavior_gui_cancel "${use_gui}" "You cancelled popup size mode setup.")
                cancel_rc=$?
                case ${cancel_rc} in
                    1|2) echo "${cancel_action}"; return "${cancel_rc}" ;;
                    3) continue ;;
                esac
            fi
            
            # Extract mode from result
            if echo "${mode_result}" | grep -q "fixed"; then
                echo "fixed"
                return 0
            elif echo "${mode_result}" | grep -q "Percentage"; then
                echo "display-based"
                return 0
            else
                continue
            fi
        done
    else
        # Text mode
        echo "" >&2
        echo "Window Size Calculation Mode:" >&2
        local mode_display_name="${default_mode}"
        [ "${default_mode}" = "display-based" ] && mode_display_name="percentage"
        echo "  Current: ${mode_display_name}" >&2
        echo "" >&2
        echo "Options:" >&2
        echo "  1) fixed - Use absolute pixel sizes (backward compatible)" >&2
        echo "  2) percentage - Percentage-based sizing (calculates sizes as percentage of screen resolution)" >&2
        echo "" >&2
        echo "Note: Percentage-based mode adapts to different screen sizes automatically." >&2
        echo "" >&2
        
        while true; do
            local default_choice
            if [ "${default_mode}" = "fixed" ]; then
                default_choice="1"
            else
                default_choice="2"
            fi
            configure_read -p "Select mode [1-2, default: ${default_choice}]: " choice
            choice=${choice:-${default_choice}}
            case "${choice}" in
                1|fixed)
                    echo "fixed"
                    return 0
                    ;;
                2|display-based|percentage)
                    echo "display-based"
                    return 0
                    ;;
                "")
                    echo "${default_mode}"
                    return 0
                    ;;
                *)
                    echo "Invalid choice. Please select 1 or 2." >&2
                    ;;
            esac
        done
    fi
}

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
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            local position position_result
            position_result=$(show_list_dialog \
                "Sleep Warning Configuration" \
                "Select popup position on screen:\n(Current: ${default_position})" \
                500 \
                300 \
                "center" "top-left")
            local exit_code=$?

            if [ ${exit_code} -eq 0 ] && [ -n "${position_result}" ]; then
                echo "${position_result}"
                return 0
            fi

            local cancel_action cancel_rc
            cancel_action=$(_handle_window_behavior_gui_cancel "${use_gui}" "You cancelled popup position setup.")
            cancel_rc=$?
            case ${cancel_rc} in
                1|2) echo "${cancel_action}"; return "${cancel_rc}" ;;
                3) continue ;;
            esac
        done
    else
        # Text mode
        echo "" >&2
        echo "Popup Position Options:" >&2
        echo "  1) center" >&2
        echo "  2) top-left" >&2
        echo "" >&2
        while true; do
            configure_read -p "Select position [1-2, default: ${default_position}]: " choice
            case "${choice}" in
                1|center) echo "center"; return 0 ;;
                2|top-left) echo "top-left"; return 0 ;;
                "") echo "${default_position}"; return 0 ;;
                *) echo "Invalid choice. Please select 1-2." >&2 ;;
            esac
        done
    fi
}

