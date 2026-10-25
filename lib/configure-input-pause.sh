#!/bin/bash

###############################################################################
# Sleep Warning System - Pause feature getters (configure wizard)
#
# Sourced by configure-input-features.sh. Requires configure-input-feature-helpers.sh.
###############################################################################

get_pause_enabled_config() {
    local use_gui="$1"
    local default_enabled
    default_enabled="$(_get_existing_bool_setting_from_config "PAUSE_ENABLED" "true")"

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        _prompt_bool_setting_gui_strict \
            "${use_gui}" \
            "Sleep Warning Configuration - Pause Feature" \
            "Enable pause feature for warning popups?\n\nWhen enabled, users can pause warning popups for 1, 2, 3, 5, 10, or 15 minutes directly from the warning popup window.\n\nNote: Pause only suppresses warning popups, not restrictions. Tighten-only configuration and uninstall protection still apply during pause.\n\nCurrent setting: ${default_enabled}" \
            650 \
            400 \
            "pause_enabled" \
            "${_baseline_pause_enabled:-${default_enabled}}"
        return $?
    fi

    echo "" >&2
    echo "Pause Feature - Enable/Disable:" >&2
    echo "  When enabled, users can pause warning popups for a short period" >&2
    echo "  (1, 2, 3, 5, 10, or 15 minutes) directly from the warning popup window." >&2
    echo "  Note: Pause only suppresses warning popups, not restrictions." >&2
    echo "  Tighten-only configuration and uninstall protection still apply." >&2
    echo "" >&2
    _prompt_bool_setting_text_yn \
        "${use_gui}" \
        "${default_enabled}" \
        "Enable pause feature? [y/n, default: ${default_enabled}]: " \
        "pause_enabled" \
        "${_baseline_pause_enabled:-${default_enabled}}"
}

get_pause_duration_config() {
    local use_gui="$1"
    local default_duration="5"

    if type get_pause_duration >/dev/null 2>&1; then
        default_duration=$(get_pause_duration)
    elif [ -f "${CONFIG_FILE}" ]; then
        local existing_duration
        existing_duration=$(grep -E "^[[:space:]]*PAUSE_DURATION=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_duration}" ] && type pause_is_valid_duration_minutes >/dev/null 2>&1 && pause_is_valid_duration_minutes "${existing_duration}"; then
            default_duration="${existing_duration}"
        fi
    fi

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        _prompt_list_setting_gui_strict \
            "${use_gui}" \
            "Sleep Warning Configuration - Pause Duration" \
            "Select pause duration:\n\nCurrent setting: ${default_duration} minutes\n\nHow long warning popups stay paused after you click Pause." \
            600 \
            400 \
            "pause_duration" \
            "${_baseline_pause_duration:-${default_duration}}" \
            "1" "2" "3" "5" "10" "15"
        return $?
    fi

    echo "" >&2
    echo "Pause Duration:" >&2
    echo "  Select how long warning popups are paused when user clicks pause button." >&2
    echo "  Allowed values: 1, 2, 3, 5, 10, or 15 minutes." >&2
    echo "" >&2
    if type pause_is_valid_duration_minutes >/dev/null 2>&1; then
        _prompt_validated_setting_text \
            "${use_gui}" \
            "${default_duration}" \
            "Pause duration in minutes [default: ${default_duration}]: " \
            "pause_is_valid_duration_minutes" \
            "pause_duration" \
            "${_baseline_pause_duration:-${default_duration}}" \
            "Invalid choice. Please enter 1, 2, 3, 5, 10, or 15."
        return $?
    fi
    while true; do
        local choice
        configure_read -p "Pause duration in minutes [default: ${default_duration}]: " choice
        choice=${choice:-${default_duration}}
        if [ "${choice}" = "5" ] || [ "${choice}" = "10" ]; then
            echo "${choice}"
            return 0
        fi
        echo "Invalid choice. Please enter 5 or 10." >&2
    done
}

get_pause_cooldown_hours_config() {
    local use_gui="$1"
    local default_cooldown="24"

    if type get_pause_cooldown_hours >/dev/null 2>&1; then
        default_cooldown=$(get_pause_cooldown_hours)
    elif [ -f "${CONFIG_FILE}" ]; then
        local existing_cooldown
        existing_cooldown=$(grep -E "^[[:space:]]*PAUSE_COOLDOWN_HOURS=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
        if [ -n "${existing_cooldown}" ] && type pause_is_valid_cooldown_hours >/dev/null 2>&1 && pause_is_valid_cooldown_hours "${existing_cooldown}"; then
            default_cooldown="${existing_cooldown}"
        fi
    fi

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        _prompt_list_setting_gui_strict \
            "${use_gui}" \
            "Sleep Warning Configuration - Pause Cooldown" \
            "Minimum hours between pause activations:\n\nCurrent setting: ${default_cooldown} hours\n\nCounted from when you click Pause (not when the quiet period ends)." \
            650 \
            400 \
            "pause_cooldown_hours" \
            "${_baseline_pause_cooldown_hours:-${default_cooldown}}" \
            "6" "8" "12" "24"
        return $?
    fi

    echo "" >&2
    echo "Pause Cooldown:" >&2
    echo "  Minimum hours between pause activations (6, 8, 12, or 24)." >&2
    echo "  Counted from when you click Pause, not when the quiet period ends." >&2
    echo "" >&2
    if type pause_is_valid_cooldown_hours >/dev/null 2>&1; then
        _prompt_validated_setting_text \
            "${use_gui}" \
            "${default_cooldown}" \
            "Pause cooldown in hours [default: ${default_cooldown}]: " \
            "pause_is_valid_cooldown_hours" \
            "pause_cooldown_hours" \
            "${_baseline_pause_cooldown_hours:-${default_cooldown}}" \
            "Invalid choice. Please enter 6, 8, 12, or 24."
        return $?
    fi
    while true; do
        local choice
        configure_read -p "Pause cooldown in hours [default: ${default_cooldown}]: " choice
        choice=${choice:-${default_cooldown}}
        if [ "${choice}" = "6" ] || [ "${choice}" = "8" ] || [ "${choice}" = "12" ] || [ "${choice}" = "24" ]; then
            echo "${choice}"
            return 0
        fi
        echo "Invalid choice. Please enter 6, 8, 12, or 24." >&2
    done
}
