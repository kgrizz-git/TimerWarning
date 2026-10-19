#!/bin/bash

###############################################################################
# Sleep Warning System - Configuration file write (configure wizard)
# Sourced by configure-config.sh
###############################################################################

_CONFIG_WRITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${_CONFIG_WRITE_DIR}/daily-caps.sh"
# shellcheck disable=SC1091
source "${_CONFIG_WRITE_DIR}/config-safety.sh"
unset _CONFIG_WRITE_DIR

# Write configuration file
# Parameters:
#   $1-$7: Standard configuration parameters (check_interval, popup_size, popup_position, min_display_time, popup_immovable, popup_auto_close, configure_block_enabled)
#   $8: Uninstall protection mode (uninstall_protection_mode)
#   $9: Pause enabled (pause_enabled) - Enhancement #21
#   $10: Pause duration in minutes (pause_duration) - Enhancement #21
#   $11: Pause cooldown in hours (pause_cooldown_hours) - Enhancement #21
#   $12: Dialog tool (dialog_tool) - Enhancement #25
#   $13: Config lock enabled (config_lock_enabled) - Enhancement #18
#   $14: Popup size mode (popup_size_mode) - Enhancement #3: fixed or display-based
#   $15: Popup custom size (popup_size_custom) - Enhancement #3: Custom size (percentage or pixel format)
#   $16: Popup custom size absolute (popup_size_custom_absolute) - Enhancement #3: Absolute fallback
#   $17+: config_lines array (7 day configurations: Sunday-Saturday)
#   After config_lines: lock_hours_lines array (optional, Enhancement #19 Phase 2)
#   After lock_hours_lines: uninstall_lock_hours_lines array (optional, Enhancement #26 Phase 2)
#   Optional (if override flags present, last 4 arguments): 
#     Fourth-to-last: popup_size_overridden ("true" if popup_size was restricted due to high restrictions)
#     Third-to-last: configure_block_overridden ("true" if configure_block_enabled was disabled due to high restrictions)
#     Second-to-last: lock_hours_cleared ("true" if lock_hours_lines were cleared due to high restrictions)
#     Last: uninstall_lock_hours_cleared ("true" if uninstall_lock_hours_lines were cleared due to high restrictions)
# Note: lock_hours_lines is detected by checking for "${CONFIG_KEY_PREFIX_CONFIG_LOCK_HOURS}_" prefix in arguments
# Note: uninstall_lock_hours_lines is detected by checking for "${CONFIG_KEY_PREFIX_UNINSTALL_LOCK_HOURS}_" prefix in arguments
# Note: If pause settings are not provided (for backward compatibility), defaults will be used
_write_config_header() {
    local check_interval="$1"
    local popup_size="$2"
    local popup_position="$3"
    local min_display_time="$4"
    local popup_immovable="$5"
    local popup_auto_close="$6"
    local configure_block_enabled="$7"
    local uninstall_protection_mode="$8"
    local pause_enabled="$9"
    local pause_duration="${10}"
    local pause_cooldown_hours="${11}"
    local dialog_tool="${12}"
    local config_lock_enabled="${13}"
    local popup_size_mode="${14}"
    local popup_size_custom="${15}"
    local popup_size_custom_absolute="${16}"
    local popup_size_overridden="${17}"
    local configure_block_overridden="${18}"

    # Standard header
    echo "# Sleep Warning Configuration"
    echo "# Format: DAY=START_HOUR-END_HOUR"
    echo "# Hours are in 24-hour format (0-23)"
    echo "# Multiple ranges can be specified per day (comma-separated)"
    echo "# Leave a day empty or omit it to have no restrictions for that day"
    echo "#"
    echo "# POPUP_DISPLAY_FREQUENCY: How often to show warning popups (in minutes). Range 1-60. (Enhancement #30)"
    echo "# Default: 10 minutes"
    echo "${CONFIG_KEY_POPUP_DISPLAY_FREQUENCY}=${check_interval}"
    echo "#"
    echo "# POPUP_SIZE: Size of warning popup (xsmall, small, medium, large, xlarge, max, custom, or custom WIDTHxHEIGHT/WIDTH%xHEIGHT%)"
    echo "# Default: medium"
    echo "# Enhancement #3: New sizes available: xsmall, xlarge, max. Custom sizes support percentage format (WIDTH%xHEIGHT%)"
    echo "${CONFIG_KEY_POPUP_SIZE}=${popup_size}"
    # Add comment if popup size was restricted due to high restrictions
    if [ "${popup_size_overridden}" = "true" ]; then
        echo "# POPUP_SIZE has been restricted to xsmall/small/medium only because restrictions exceed 16 hours/day."
        echo "# This prevents overly intrusive popups when user has very limited unrestricted time."
    fi
    echo "#"
    echo "# POPUP_SIZE_MODE: Window size calculation mode (Enhancement #3)"
    echo "# Options: fixed (absolute pixel sizes) or display-based (percentage-based)"
    echo "# Default: fixed (for backward compatibility)"
    echo "${CONFIG_KEY_POPUP_SIZE_MODE}=${popup_size_mode}"
    echo "#"
    echo "# POPUP_SIZE_CUSTOM: Custom size configuration (Enhancement #3)"
    echo "# Format: PERCENT%xPERCENT% (e.g., 50%x50%) or WIDTHxHEIGHT (absolute pixels)"
    echo "# If percentage format, used in display-based mode; if pixel format, used as absolute fallback"
    echo "# Default: 50%x50%"
    echo "${CONFIG_KEY_POPUP_SIZE_CUSTOM}=${popup_size_custom}"
    echo "#"
    echo "# POPUP_SIZE_CUSTOM_ABSOLUTE: Absolute pixel fallback for custom size (Enhancement #3)"
    echo "# Used when resolution cannot be detected and custom size is percentage-based"
    echo "# Default: 1280x720 (50% of 2560x1440)"
    echo "${CONFIG_KEY_POPUP_SIZE_CUSTOM_ABSOLUTE}=${popup_size_custom_absolute}"
    echo "#"
    echo "# POPUP_POSITION: Position of warning popup on screen"
    echo "# Default: center"
    echo "${CONFIG_KEY_POPUP_POSITION}=${popup_position}"
    echo "#"
    echo "# POPUP_MIN_DISPLAY_TIME: Minimum time popup must be visible before it can be closed (in seconds)"
    echo "# Default: 30 seconds"
    echo "${CONFIG_KEY_POPUP_MIN_DISPLAY_TIME}=${min_display_time}"
    echo "#"
    echo "# POPUP_IMMOVABLE: Prevent popup window from being moved during minimum display time"
    echo "# Default: true"
    echo "${CONFIG_KEY_POPUP_IMMOVABLE}=${popup_immovable}"
    echo "#"
    echo "# POPUP_AUTO_CLOSE: Automatically close popup window 10 seconds after minimum display time completes"
    echo "# Default: true (enabled by default)"
    echo "# Options: true, false"
    echo "# Auto-close happens 10 seconds after minimum display time completes (additional time, not total time)"
    echo "# If minimum display time is 0, auto-close happens after 10 seconds"
    echo "# Auto-close time is fixed at 10 seconds (not configurable)"
    echo "# This is Enhancement #15 (Auto-Close Popup Window)"
    echo "${CONFIG_KEY_POPUP_AUTO_CLOSE}=${popup_auto_close}"
    echo "#"
    echo "# CONFIGURE_BLOCK_ENABLED: Restrict configure.sh and manage.sh to tighten-only edits during restricted hours"
    echo "# Default: false (opt-in feature)"
    echo "# When enabled, the configure/manage wizards open in tighten-only mode during restricted hours:"
    echo "# settings can be made stricter but not loosened, removed, or disabled, to prevent circumventing"
    echo "# restrictions. Disabling the service and uninstalling remain available (see docs/SAFETY.md)."
    echo "# This is Enhancement #19 (formerly full block; now tighten-only partial lock, lib/configure-partial-lock.sh)"
    echo "${CONFIG_KEY_CONFIGURE_BLOCK_ENABLED}=${configure_block_enabled}"
    # Add comment if configure block was disabled due to high restrictions
    if [ "${configure_block_overridden}" = "true" ]; then
        echo "# CONFIGURE_BLOCK_ENABLED has been disabled because restrictions exceed 16 hours/day."
        echo "# This prevents accidental lockout when user has very limited unrestricted time."
    fi
    echo "#"
    echo "# UNINSTALL_PROTECTION_MODE: Protection mode for uninstall.sh during restricted hours"
    echo "# Default: difficult"
    echo "# Options:"
    echo "#   none - No protection, uninstall works normally during restricted hours"
    echo "#   difficult - Difficult uninstall, requires confirmation phrase + 5 arithmetic questions (3 wrong answers allowed)"
    echo "# When enabled, uninstall.sh requires verification during restricted hours to prevent"
    echo "# users from circumventing restrictions by uninstalling the system."
    echo "# This is Enhancement #26 (Prevent uninstall.sh Execution During Restricted Hours)"
    echo "# Note: Total block mode may be considered as future phase"
    echo "${CONFIG_KEY_UNINSTALL_PROTECTION_MODE}=${uninstall_protection_mode}"
    echo "#"
    echo "# PAUSE_ENABLED: Enable/disable pause feature for warning popups"
    echo "# Default: true"
    echo "# When enabled, users can pause warning popups for a configured duration"
    echo "# directly from the warning popup window. Pause only suppresses popups, not restrictions."
    echo "# This is Enhancement #21 (One-Time Pause Feature)"
    echo "${CONFIG_KEY_PAUSE_ENABLED}=${pause_enabled}"
    echo "#"
    echo "# PAUSE_DURATION: Duration of pause in minutes (1, 2, 3, 5, 10, or 15)"
    echo "# Default: 5 minutes"
    echo "# This controls how long warning popups are paused when user clicks pause button"
    echo "${CONFIG_KEY_PAUSE_DURATION}=${pause_duration}"
    echo "#"
    echo "# PAUSE_COOLDOWN_HOURS: Minimum hours between pause activations (6, 8, 12, or 24)"
    echo "# Default: 24 hours (matches prior once-per-calendar-day behavior when key is absent)"
    echo "# After a pause ends, another pause cannot start until this cooldown elapses."
    echo "${CONFIG_KEY_PAUSE_COOLDOWN_HOURS}=${pause_cooldown_hours}"
    echo "#"
    echo "# DIALOG_TOOL: Dialog tool selection for popup windows"
    echo "# Default: auto (uses automatic priority: YAD → Zenity → KDialog)"
    echo "# Options:"
    echo "#   auto - Automatic selection (recommended, uses priority system)"
    echo "#   zenity - Force use of zenity (if installed)"
    echo "#   yad - Force use of yad (if installed)"
    echo "#   kdialog - Force use of kdialog (if installed)"
    echo "# If selected tool is not installed, system falls back to automatic selection"
    echo "# This is Enhancement #25 (User-Selectable Dialog Tool)"
    echo "${CONFIG_KEY_DIALOG_TOOL}=${dialog_tool}"
    echo "#"
    echo "# CONFIG_LOCK_ENABLED: Enable/disable config file locking during restricted hours"
    echo "# Default: false (opt-in feature)"
    echo "# When enabled, the config file and directory are made read-only during restricted hours"
    echo "# and any configured lock hours to prevent users from circumventing restrictions"
    echo "# by changing settings. This is a deterrence mechanism, not true security."
    echo "# This is Enhancement #18 (Config File Locking During Restricted Hours)"
    echo "# Note: Automatically disabled if restrictions exceed ${THRESHOLD_WARN} minutes/week (> $(get_threshold_warn_description)) (Enhancement #22)"
    echo "${CONFIG_KEY_CONFIG_LOCK_ENABLED}=${config_lock_enabled}"
    echo "#"
    echo "# GAMING_MODE_EXPERIMENTAL_ENABLED: Enable/disable experimental SteamOS Gaming Mode (gamescope) overlay support"
    echo "# Default: false"
    echo "# When enabled on Linux/SteamOS, warning popups in Gaming Mode use Xwayland (:0) with STEAM_OVERLAY=1"
    echo "# and STEAM_INPUT_FOCUS=1 atoms, while normal Desktop Mode continues to work when in a desktop session."
    local effective_gaming_mode_experimental="${gaming_mode_experimental_enabled:-}"
    if [ -z "${effective_gaming_mode_experimental}" ]; then
        if type get_gaming_mode_experimental_enabled >/dev/null 2>&1; then
            effective_gaming_mode_experimental=$(get_gaming_mode_experimental_enabled)
        else
            effective_gaming_mode_experimental="false"
        fi
    fi
    echo "${CONFIG_KEY_GAMING_MODE_EXPERIMENTAL_ENABLED}=${effective_gaming_mode_experimental}"
    echo "#"
    echo "# This file was generated by the configuration wizard on $(date)"

    echo ""
}

_write_restrictions_section() {
    local -n config_lines_ref="$1"

    # Write configuration lines in calendar order (Sun-Sat, indices 0-6)
    for day_index in 0 1 2 3 4 5 6; do
        if [ -n "${config_lines_ref[${day_index}]}" ]; then
            # Write the line (includes empty values for explicitly skipped days)
            echo "${config_lines_ref[${day_index}]}"
        fi
    done
}

_write_lock_hours_section() {
    local -n lock_hours_lines_ref="$1"
    local lock_hours_cleared="$2"

    # Only write section header if there are any lock hours configured
    local has_lock_hours=false
    for day_index in 0 1 2 3 4 5 6; do
        if [ -n "${lock_hours_lines_ref[${day_index}]}" ]; then
            has_lock_hours=true
            break
        fi
    done

    if [ "${has_lock_hours}" = "true" ]; then
        echo ""
        echo "# CONFIG_LOCK_HOURS: Additional hours that restrict configure.sh and manage.sh to tighten-only (separate from restriction hours)"
        echo "# Format: CONFIG_LOCK_HOURS_DAYNAME=START_HOUR-END_HOUR"
        echo "# Hours are in 24-hour format (0-23)"
        echo "# Multiple ranges can be specified per day (comma-separated)"
        echo "# Overnight ranges are supported (e.g., 23-6 spans midnight)"
        echo "# Leave a day empty or omit it to have no lock hours for that day"
        echo "# When CONFIGURE_BLOCK_ENABLED=true, configuration is tighten-only during restriction hours OR lock hours"
        echo "# This is Enhancement #19 Phase 2 (Additional Configurable Lock Hours)"
        # Add comment if lock hours were cleared due to high restrictions
        if [ "${lock_hours_cleared}" = "true" ]; then
            echo "# CONFIG_LOCK_HOURS have been cleared because combined restrictions exceed 16 hours/day."
            echo "# This prevents accidental lockout when user has very limited unrestricted time."
        fi

        # Write lock hours lines in calendar order (Sun-Sat, indices 0-6)
        for day_index in 0 1 2 3 4 5 6; do
            if [ -n "${lock_hours_lines_ref[${day_index}]}" ]; then
                # Write the line (includes empty values for explicitly disabled days)
                echo "${lock_hours_lines_ref[${day_index}]}"
            fi
        done
    fi
}

_write_uninstall_lock_hours_section() {
    local -n uninstall_lock_hours_lines_ref="$1"
    local uninstall_lock_hours_cleared="$2"

    # Only write section header if there are any uninstall lock hours configured
    local has_uninstall_lock_hours=false
    for day_index in 0 1 2 3 4 5 6; do
        if [ -n "${uninstall_lock_hours_lines_ref[${day_index}]}" ]; then
            has_uninstall_lock_hours=true
            break
        fi
    done

    if [ "${has_uninstall_lock_hours}" = "true" ]; then
        echo ""
        echo "# UNINSTALL_LOCK_HOURS: Additional hours for difficult uninstall verification (separate from restriction hours and configure.sh lock hours)"
        echo "# Format: UNINSTALL_LOCK_HOURS_DAYNAME=START_HOUR-END_HOUR"
        echo "# Hours are in 24-hour format (0-23)"
        echo "# Multiple ranges can be specified per day (comma-separated)"
        echo "# Overnight ranges are supported (e.g., 23-6 spans midnight)"
        echo "# Leave a day empty or omit it to have no uninstall lock hours for that day"
        echo "# When UNINSTALL_PROTECTION_MODE=difficult, difficult uninstall verification applies during restriction hours OR uninstall lock hours"
        echo "# This is Enhancement #26 Phase 2 (Additional Uninstall Lock Hours)"
        echo "# WARNING: Additional uninstall lock hours increase the risk of preventing legitimate uninstall needs"
        # Add comment if uninstall lock hours were cleared due to high restrictions
        if [ "${uninstall_lock_hours_cleared}" = "true" ]; then
            echo "# UNINSTALL_LOCK_HOURS have been cleared because combined restrictions exceed 16 hours/day."
            echo "# This prevents accidental lockout when user has very limited unrestricted time."
        fi

        # Write uninstall lock hours lines in calendar order (Sun-Sat, indices 0-6)
        for day_index in 0 1 2 3 4 5 6; do
            if [ -n "${uninstall_lock_hours_lines_ref[${day_index}]}" ]; then
                # Write the line (includes empty values for explicitly disabled days)
                echo "${uninstall_lock_hours_lines_ref[${day_index}]}"
            fi
        done
    fi
}

_finish_config_lock_wizard_write_if_available() {
    if type config_lock_finish_wizard_write >/dev/null 2>&1; then
        config_lock_finish_wizard_write || true
    fi
}

write_config() {
    local check_interval="$1"
    local popup_size="$2"
    local popup_position="$3"
    local min_display_time="$4"
    local popup_immovable="$5"
    local popup_auto_close="$6"
    local configure_block_enabled="$7"
    local uninstall_protection_mode="$8"
    local pause_enabled="${9:-true}"
    local pause_duration="${10:-5}"
    local pause_cooldown_hours="${11:-24}"
    local dialog_tool="${12:-auto}"
    local config_lock_enabled="${13:-false}"
    local popup_size_mode="${14:-fixed}"  # Enhancement #3: Size mode (fixed or display-based)
    local popup_size_custom="${15:-50%x50%}"  # Enhancement #3: Custom size
    local popup_size_custom_absolute="${16:-1280x720}"  # Enhancement #3: Absolute fallback
    shift 16
    
    # Extract config_lines array, optional lock_hours_lines array, optional uninstall_lock_hours_lines array, and optional override flags
    # config_lines values are always "DAYVAR=RANGE" format (e.g., "MONDAY=0-5")
    # lock_hours_lines values are always "${CONFIG_KEY_PREFIX_CONFIG_LOCK_HOURS}_DAYNAME=RANGE" format (e.g., "CONFIG_LOCK_HOURS_MONDAY=9-17")
    # uninstall_lock_hours_lines values are always "${CONFIG_KEY_PREFIX_UNINSTALL_LOCK_HOURS}_DAYNAME=RANGE" format (e.g., "UNINSTALL_LOCK_HOURS_MONDAY=9-17")
    # Override flags are always "true" or empty string, and never contain "="
    local popup_size_overridden=""
    local configure_block_overridden=""
    local lock_hours_cleared=""
    local uninstall_lock_hours_cleared=""
    local config_lines=()
    local lock_hours_lines=()
    local uninstall_lock_hours_lines=()
    local all_args=("$@")
    local arg_count=${#all_args[@]}
    
    # Find where lock_hours_lines start (first argument with "${CONFIG_KEY_PREFIX_CONFIG_LOCK_HOURS}_" prefix)
    local lock_hours_start=-1
    # Find where uninstall_lock_hours_lines start (first argument with "${CONFIG_KEY_PREFIX_UNINSTALL_LOCK_HOURS}_" prefix)
    local uninstall_lock_hours_start=-1
    local override_flags_start=-1
    
    for i in "${!all_args[@]}"; do
        if [[ "${all_args[${i}]}" =~ ^${CONFIG_KEY_PREFIX_CONFIG_LOCK_HOURS}_ ]]; then
            if [ ${lock_hours_start} -eq -1 ]; then
                lock_hours_start=${i}
            fi
        elif [[ "${all_args[${i}]}" =~ ^${CONFIG_KEY_PREFIX_UNINSTALL_LOCK_HOURS}_ ]]; then
            if [ ${uninstall_lock_hours_start} -eq -1 ]; then
                uninstall_lock_hours_start=${i}
            fi
        fi
    done
    
    # Find where override flags start (last 2-4 arguments that are "true" or empty and don't contain "=")
    # Check for 4 flags first (new format), then fall back to 2 flags (old format for backward compatibility)
    if [ $arg_count -ge 4 ]; then
        local fourth_to_last="${all_args[$((arg_count - 4))]}"
        local third_to_last="${all_args[$((arg_count - 3))]}"
        local second_to_last="${all_args[$((arg_count - 2))]}"
        local last="${all_args[$((arg_count - 1))]}"
        
        if ([ -z "${fourth_to_last}" ] || [ "${fourth_to_last}" = "true" ]) && \
           ([ -z "${third_to_last}" ] || [ "${third_to_last}" = "true" ]) && \
           ([ -z "${second_to_last}" ] || [ "${second_to_last}" = "true" ]) && \
           ([ -z "${last}" ] || [ "${last}" = "true" ]) && \
           [[ ! "${fourth_to_last}" =~ = ]] && [[ ! "${third_to_last}" =~ = ]] && \
           [[ ! "${second_to_last}" =~ = ]] && [[ ! "${last}" =~ = ]]; then
            override_flags_start=$((arg_count - 4))
        elif [ $arg_count -ge 2 ]; then
            # Fall back to 2 flags (backward compatibility)
            if ([ -z "${second_to_last}" ] || [ "${second_to_last}" = "true" ]) && \
               ([ -z "${last}" ] || [ "${last}" = "true" ]) && \
               [[ ! "${second_to_last}" =~ = ]] && [[ ! "${last}" =~ = ]]; then
                override_flags_start=$((arg_count - 2))
            fi
        fi
    elif [ $arg_count -ge 2 ]; then
        # Only 2-3 arguments, check for 2 flags (backward compatibility)
        local second_to_last="${all_args[$((arg_count - 2))]}"
        local last="${all_args[$((arg_count - 1))]}"
        
        if ([ -z "${second_to_last}" ] || [ "${second_to_last}" = "true" ]) && \
           ([ -z "${last}" ] || [ "${last}" = "true" ]) && \
           [[ ! "${second_to_last}" =~ = ]] && [[ ! "${last}" =~ = ]]; then
            override_flags_start=$((arg_count - 2))
        fi
    fi
    
    # Extract arrays based on detected boundaries
    # Order: config_lines, lock_hours_lines, uninstall_lock_hours_lines, override_flags
    if [ ${lock_hours_start} -ge 0 ]; then
        # Lock hours present
        config_lines=("${all_args[@]:0:${lock_hours_start}}")
        
        if [ ${uninstall_lock_hours_start} -ge 0 ] && [ ${uninstall_lock_hours_start} -gt ${lock_hours_start} ]; then
            # Both lock hours and uninstall lock hours present
            lock_hours_lines=("${all_args[@]:${lock_hours_start}:$((uninstall_lock_hours_start - lock_hours_start))}")
            
            if [ ${override_flags_start} -ge 0 ] && [ ${override_flags_start} -gt ${uninstall_lock_hours_start} ]; then
                # Override flags present after uninstall lock hours
                uninstall_lock_hours_lines=("${all_args[@]:${uninstall_lock_hours_start}:$((override_flags_start - uninstall_lock_hours_start))}")
                # Extract override flags (handle both 2-flag and 4-flag formats)
                if [ $((arg_count - override_flags_start)) -eq 4 ]; then
                    popup_size_overridden="${all_args[$((arg_count - 4))]}"
                    configure_block_overridden="${all_args[$((arg_count - 3))]}"
                    lock_hours_cleared="${all_args[$((arg_count - 2))]}"
                    uninstall_lock_hours_cleared="${all_args[$((arg_count - 1))]}"
                else
                    # Backward compatibility: 2 flags
                    popup_size_overridden="${all_args[$((arg_count - 2))]}"
                    configure_block_overridden="${all_args[$((arg_count - 1))]}"
                fi
            else
                # No override flags, uninstall lock hours go to end
                uninstall_lock_hours_lines=("${all_args[@]:${uninstall_lock_hours_start}}")
            fi
        else
            # Only lock hours, no uninstall lock hours
            if [ ${override_flags_start} -ge 0 ] && [ ${override_flags_start} -gt ${lock_hours_start} ]; then
                # Override flags present after lock hours
                lock_hours_lines=("${all_args[@]:${lock_hours_start}:$((override_flags_start - lock_hours_start))}")
                # Extract override flags (handle both 2-flag and 4-flag formats)
                if [ $((arg_count - override_flags_start)) -eq 4 ]; then
                    popup_size_overridden="${all_args[$((arg_count - 4))]}"
                    configure_block_overridden="${all_args[$((arg_count - 3))]}"
                    lock_hours_cleared="${all_args[$((arg_count - 2))]}"
                    uninstall_lock_hours_cleared="${all_args[$((arg_count - 1))]}"
                else
                    # Backward compatibility: 2 flags
                    popup_size_overridden="${all_args[$((arg_count - 2))]}"
                    configure_block_overridden="${all_args[$((arg_count - 1))]}"
                fi
            else
                # No override flags, lock hours go to end
                lock_hours_lines=("${all_args[@]:${lock_hours_start}}")
            fi
        fi
    elif [ ${uninstall_lock_hours_start} -ge 0 ]; then
        # Only uninstall lock hours, no lock hours
        config_lines=("${all_args[@]:0:${uninstall_lock_hours_start}}")
        
            if [ ${override_flags_start} -ge 0 ] && [ ${override_flags_start} -gt ${uninstall_lock_hours_start} ]; then
                # Override flags present after uninstall lock hours
                uninstall_lock_hours_lines=("${all_args[@]:${uninstall_lock_hours_start}:$((override_flags_start - uninstall_lock_hours_start))}")
                # Extract override flags (handle both 2-flag and 4-flag formats)
                local flags_count=$((arg_count - override_flags_start))
                if [ ${flags_count} -ge 4 ]; then
                    popup_size_overridden="${all_args[$((arg_count - 4))]}"
                    configure_block_overridden="${all_args[$((arg_count - 3))]}"
                    lock_hours_cleared="${all_args[$((arg_count - 2))]}"
                    uninstall_lock_hours_cleared="${all_args[$((arg_count - 1))]}"
                else
                    popup_size_overridden="${all_args[$((arg_count - 2))]}"
                    configure_block_overridden="${all_args[$((arg_count - 1))]}"
                fi
        else
            # No override flags, uninstall lock hours go to end
            uninstall_lock_hours_lines=("${all_args[@]:${uninstall_lock_hours_start}}")
        fi
    else
        # No lock hours or uninstall lock hours
        if [ ${override_flags_start} -ge 0 ]; then
            # Override flags present
            config_lines=("${all_args[@]:0:${override_flags_start}}")
            # Extract override flags (handle both 2-flag and 4-flag formats)
            local flags_count=$((arg_count - override_flags_start))
            if [ ${flags_count} -ge 4 ]; then
                popup_size_overridden="${all_args[$((arg_count - 4))]}"
                configure_block_overridden="${all_args[$((arg_count - 3))]}"
                lock_hours_cleared="${all_args[$((arg_count - 2))]}"
                uninstall_lock_hours_cleared="${all_args[$((arg_count - 1))]}"
            else
                popup_size_overridden="${all_args[$((arg_count - 2))]}"
                configure_block_overridden="${all_args[$((arg_count - 1))]}"
            fi
        else
            # No override flags, all are config_lines
            config_lines=("${all_args[@]}")
        fi
    fi
    
    # Keep the safety gate at the actual write boundary, including callers that
    # do not go through configure.sh's interactive save menu.
    local cap_defaults=()
    if type append_missing_restriction_default_lines >/dev/null 2>&1; then
        append_missing_restriction_default_lines cap_defaults "${config_lines[@]}"
    fi
    if ! check_daily_caps "${configure_block_enabled}" "${uninstall_protection_mode}" \
        "CONFIG_LOCK_ENABLED=${config_lock_enabled}" \
        "${config_lines[@]}" "${lock_hours_lines[@]}" \
        "${uninstall_lock_hours_lines[@]}" "${cap_defaults[@]}"; then
        return 1
    fi

    # Create config directory if it doesn't exist
    # Enhancement #18: Config file is now in subdirectory
    mkdir -p "${CONFIG_DIR}/config"

    # Allow atomic write during config-file lock hours (tighten-only wizard saves).
    if type config_lock_prepare_for_wizard_write >/dev/null 2>&1; then
        config_lock_prepare_for_wizard_write || true
    fi
    
    # Extract user comments from existing file
    # User comments are no longer preserved to prevent config file growth
    
    # Create temporary file for atomic write
    local temp_file
    temp_file=$(mktemp "${CONFIG_FILE}.tmp.XXXXXX" 2>/dev/null || echo "${CONFIG_FILE}.tmp")
    
    # Write configuration file to temp file
    {
        _write_config_header \
            "${check_interval}" \
            "${popup_size}" \
            "${popup_position}" \
            "${min_display_time}" \
            "${popup_immovable}" \
            "${popup_auto_close}" \
            "${configure_block_enabled}" \
            "${uninstall_protection_mode}" \
            "${pause_enabled}" \
            "${pause_duration}" \
            "${pause_cooldown_hours}" \
            "${dialog_tool}" \
            "${config_lock_enabled}" \
            "${popup_size_mode}" \
            "${popup_size_custom}" \
            "${popup_size_custom_absolute}" \
            "${popup_size_overridden}" \
            "${configure_block_overridden}"

        _write_restrictions_section config_lines
        _write_lock_hours_section lock_hours_lines "${lock_hours_cleared}"
        _write_uninstall_lock_hours_section uninstall_lock_hours_lines "${uninstall_lock_hours_cleared}"
    } > "${temp_file}"
    
    # Check if write to temp file succeeded
    if [ $? -ne 0 ]; then
        # Write failed, clean up temp file
        rm -f "${temp_file}" 2>/dev/null
        _finish_config_lock_wizard_write_if_available
        return 1
    fi
    
    # Atomically replace config file with temp file
    if mv "${temp_file}" "${CONFIG_FILE}" 2>/dev/null; then
        _finish_config_lock_wizard_write_if_available
        return 0
    else
        # Move failed, clean up temp file
        rm -f "${temp_file}" 2>/dev/null
        _finish_config_lock_wizard_write_if_available
        return 1
    fi
}

# Atomically update GAMING_MODE_EXPERIMENTAL_ENABLED in CONFIG_FILE.
# Used by Option 12 (configure_service_mode) so toggling Gaming Mode persists immediately
# even if the user exits the wizard without selecting Option 13 (Save & Exit).
# When the config file does not exist yet, create it with only this key.
# Parameters:
#   $1 - new value ("true" or "false")
update_gaming_mode_config_in_place() {
    local new_val="${1:-false}"
    if [ "${new_val}" != "true" ]; then
        new_val="false"
    fi

    if [ ! -f "${CONFIG_FILE}" ]; then
        local config_parent
        config_parent=$(dirname "${CONFIG_FILE}")
        if [ ! -d "${config_parent}" ]; then
            mkdir -p "${config_parent}" || return 1
        fi
    fi

    if type config_lock_prepare_for_wizard_write >/dev/null 2>&1; then
        config_lock_prepare_for_wizard_write || true
    fi

    local temp_file write_rc=0
    temp_file=$(mktemp "${CONFIG_FILE}.tmp.XXXXXX" 2>/dev/null || echo "${CONFIG_FILE}.tmp")

    if [ -f "${CONFIG_FILE}" ] && grep -qE "^[[:space:]]*${CONFIG_KEY_GAMING_MODE_EXPERIMENTAL_ENABLED}=" "${CONFIG_FILE}" 2>/dev/null; then
        if ! awk -v key="${CONFIG_KEY_GAMING_MODE_EXPERIMENTAL_ENABLED}" -v val="${new_val}" '
            $0 ~ "^[[:space:]]*" key "=" { print key "=" val; next }
            { print }
        ' "${CONFIG_FILE}" > "${temp_file}" 2>/dev/null; then
            write_rc=1
        fi
    elif [ -f "${CONFIG_FILE}" ]; then
        # cat's status must count. A failed read must not be replaced by a
        # file that contains only the appended key.
        if ! cat "${CONFIG_FILE}" > "${temp_file}" 2>/dev/null; then
            write_rc=1
        elif ! {
            echo ""
            echo "# GAMING_MODE_EXPERIMENTAL_ENABLED: Enable/disable experimental SteamOS Gaming Mode (gamescope) overlay support"
            echo "${CONFIG_KEY_GAMING_MODE_EXPERIMENTAL_ENABLED}=${new_val}"
        } >> "${temp_file}" 2>/dev/null; then
            write_rc=1
        fi
    else
        if ! {
            echo "# Created by Option 12 before the first full wizard save."
            echo "# GAMING_MODE_EXPERIMENTAL_ENABLED: Enable/disable experimental SteamOS Gaming Mode (gamescope) overlay support"
            echo "${CONFIG_KEY_GAMING_MODE_EXPERIMENTAL_ENABLED}=${new_val}"
        } > "${temp_file}" 2>/dev/null; then
            write_rc=1
        fi
    fi

    if [ "${write_rc}" -eq 0 ] && [ -s "${temp_file}" ] && mv "${temp_file}" "${CONFIG_FILE}" 2>/dev/null; then
        _finish_config_lock_wizard_write_if_available
        return 0
    fi

    rm -f "${temp_file}" 2>/dev/null
    _finish_config_lock_wizard_write_if_available
    return 1
}
