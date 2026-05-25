#!/bin/bash

###############################################################################
# Sleep Warning System - Main Script
#
# This script checks if the current time falls within user-defined restricted
# hours and displays a modal warning popup if usage is detected during those
# hours. It is designed to help users maintain healthy sleep schedules.
#
# Requirements:
# - bash
# - zenity (or yad/kdialog as fallback)
# - systemd (for timer integration)
# - Graphical desktop environment
#
# Configuration:
# - Reads from ~/.config/sleep-warning/config/sleep-warning.conf (Enhancement #18)
# - Falls back to default values if config file missing
#
# Usage:
# - Typically run by systemd timer every 10 minutes
# - Can also be run manually for testing
#
# Output:
# - Displays modal warning dialog during restricted hours
# - Exits silently during non-restricted hours or if GUI unavailable
###############################################################################

# Determine script directory and library search paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_LIB_DIR="${SCRIPT_DIR}/lib"
INSTALLED_LIB_DIR="${HOME}/.local/lib/sleep-warning"

for _bootstrap_lib in \
    "${INSTALLED_LIB_DIR}/_bootstrap-bash4.sh" \
    "${SCRIPT_LIB_DIR}/_bootstrap-bash4.sh"; do
    if [ -f "${_bootstrap_lib}" ]; then
        # shellcheck disable=SC1090
        source "${_bootstrap_lib}"
        _bootstrap_bash4 "${BASH_SOURCE[0]}" "$@"
        break
    fi
done
unset _bootstrap_lib

# Load shared library loader helper
LIB_HELPER_PATH=""
for candidate in \
    "${INSTALLED_LIB_DIR}/library-loader.sh" \
    "${SCRIPT_LIB_DIR}/library-loader.sh"; do
    if [ -z "${LIB_HELPER_PATH}" ] && [ -f "${candidate}" ]; then
        LIB_HELPER_PATH="${candidate}"
    fi
done

if [ -z "${LIB_HELPER_PATH}" ]; then
    echo "Error: library loader helper not found. Please reinstall the Sleep Warning System." >&2
    exit 1
fi

# shellcheck disable=SC1090
source "${LIB_HELPER_PATH}"
init_library_paths "${INSTALLED_LIB_DIR}" "${SCRIPT_LIB_DIR}"

# Source library modules in dependency order
source_required_lib "platform.sh" || exit 1
source_required_lib "config.sh" || exit 1
source_required_lib "logging.sh" || exit 1
source_required_lib "pause-state.sh" || exit 1
if is_darwin; then
    source_required_lib "sleep-detection-darwin.sh" || exit 1
    source_required_lib "display-detection-darwin.sh" || exit 1
    source_required_lib "window-management-darwin.sh" || exit 1
else
    source_required_lib "sleep-detection.sh" || exit 1  # Enhancement #9: Sleep/hibernate detection
    source_required_lib "display-detection.sh" || exit 1
    source_required_lib "window-management.sh" || exit 1
fi
source_required_lib "configure-core.sh" || exit 1
source_required_lib "configure-validation.sh" || exit 1
source_required_lib "desktop-environment.sh" || exit 1
source_required_lib "popup-safety.sh" || exit 1
source_required_lib "time-validation.sh" || exit 1
source_required_lib "time-parsing.sh" || exit 1  # normalize_time_range for parse_config (12h config format)
source_required_lib "time-calculations.sh" || exit 1
source_required_lib "config-locking.sh" || exit 1  # Enhancement #18: Config file locking
if is_darwin; then
    source_optional_lib "resolution-detection-darwin.sh" || true
fi
source_required_lib "resolution-detection.sh" || exit 1  # Enhancement #3: Display resolution detection
source_required_lib "popup-display.sh" || exit 1

# Validate configuration file safety at runtime.
# Enforces the per-day per-category 16-hour cap and falls back to safe
# defaults if any violation is found in any of the three categories
# (restriction, configure_block, uninstall_block).
# Returns 0 if config is safe, 1 if any cap violation detected.
validate_config_safety() {
    # No config file → use defaults (safe)
    if [ ! -f "${CONFIG_FILE}" ]; then
        return 0
    fi

    local _day_vars=("SUNDAY" "MONDAY" "TUESDAY" "WEDNESDAY" "THURSDAY" "FRIDAY" "SATURDAY")
    local _lock_prefixes=("CONFIG_LOCK_HOURS_" "UNINSTALL_LOCK_HOURS_")

    # Helper: read the LAST occurrence of a key from the config file (tail wins on dupes).
    _read_config_value() {
        local key="$1"
        grep -E "^[[:space:]]*${key}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null \
            | tail -n1 | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    }

    # Build restriction lines ("DAYVAR=RANGE")
    local config_lines=()
    local i day_var val
    for i in 0 1 2 3 4 5 6; do
        day_var="${_day_vars[${i}]}"
        if grep -qE "^[[:space:]]*${day_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null; then
            val=$(_read_config_value "${day_var}")
            config_lines[${i}]="${day_var}=${val}"
        fi
    done

    # Build lock-hours lines ("CONFIG_LOCK_HOURS_DAYVAR=RANGE")
    local lock_hours_lines=()
    for i in 0 1 2 3 4 5 6; do
        day_var="${_day_vars[${i}]}"
        local lock_key="CONFIG_LOCK_HOURS_${day_var}"
        if grep -qE "^[[:space:]]*${lock_key}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null; then
            val=$(_read_config_value "${lock_key}")
            lock_hours_lines[${i}]="${lock_key}=${val}"
        fi
    done

    # Build uninstall-lock-hours lines
    local uninstall_lock_hours_lines=()
    for i in 0 1 2 3 4 5 6; do
        day_var="${_day_vars[${i}]}"
        local un_key="UNINSTALL_LOCK_HOURS_${day_var}"
        if grep -qE "^[[:space:]]*${un_key}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null; then
            val=$(_read_config_value "${un_key}")
            uninstall_lock_hours_lines[${i}]="${un_key}=${val}"
        fi
    done

    # Read feature-enable flags from config file
    local configure_block_enabled
    configure_block_enabled=$(_read_config_value "CONFIGURE_BLOCK_ENABLED")
    [ -z "${configure_block_enabled}" ] && configure_block_enabled="false"

    local uninstall_protection_mode
    uninstall_protection_mode=$(_read_config_value "UNINSTALL_PROTECTION_MODE")
    [ -z "${uninstall_protection_mode}" ] && uninstall_protection_mode="none"

    # Warn about duplicate day lines (both head-n1 and tail-n1 agree on last-wins,
    # but duplicates suggest a manual edit worth flagging).
    for i in 0 1 2 3 4 5 6; do
        day_var="${_day_vars[${i}]}"
        local count
        count=$(grep -cE "^[[:space:]]*${day_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null || echo 0)
        if [ "${count}" -gt 1 ]; then
            log_to_file "WARNING" "validate_config_safety: duplicate '${day_var}=' lines in config (using last occurrence)"
        fi
    done

    # Apply the per-day per-category 16-hour cap check.
    if type check_daily_caps >/dev/null 2>&1; then
        local violations
        violations=$(check_daily_caps \
            "${configure_block_enabled}" \
            "${uninstall_protection_mode}" \
            "${config_lines[@]}" \
            "${lock_hours_lines[@]}" \
            "${uninstall_lock_hours_lines[@]}")
        if [ -n "${violations}" ]; then
            log_to_file "ERROR" "validate_config_safety: per-day cap violations detected:\n${violations}"
            return 1
        fi
    else
        # Fallback to the legacy weekly-total check if daily-caps unavailable.
        local validation_result
        validation_result=$(check_restriction_coverage "${config_lines[@]}")
        if [ "${validation_result}" = "block" ]; then
            return 1
        fi
    fi

    return 0
}

# Main function
main() {
    # Apply config file lock (Enhancement #18)
    # This should be done early, before other operations
    if type apply_config_directory_lock >/dev/null 2>&1; then
        apply_config_directory_lock 2>/dev/null || true
    fi
    
    # Self-healing check (if lock is active)
    if type is_config_lock_active >/dev/null 2>&1 && type check_and_restore_config_file >/dev/null 2>&1; then
        if is_config_lock_active 2>/dev/null; then
            check_and_restore_config_file 2>/dev/null || true
        fi
    fi
    
    # Log system mode at startup (Enhancement #4)
    if type detect_system_mode >/dev/null 2>&1; then
        local system_mode
        system_mode=$(detect_system_mode 2>/dev/null || echo "unknown")
        if [ "${system_mode}" != "unknown" ]; then
            log_to_file "INFO" "System mode detected: ${system_mode}"
        fi
    fi
    
    # Check and clear expired pause state (Enhancement #21)
    # This should be done before checking restricted hours
    check_and_clear_expired_pause
    
    # Check if we should skip warning due to recent system resume (Enhancement #9)
    # This should be done before checking restricted hours
    if type should_skip_warning_after_resume >/dev/null 2>&1; then
        if should_skip_warning_after_resume; then
            # System recently resumed, skip warning during grace period
            exit 0
        fi
    fi
    
    # Validate configuration safety before proceeding
    # This prevents 24/7 restrictions from manual config file editing
    local use_defaults=false
    if ! validate_config_safety; then
        # 24/7 restrictions detected in config file
        # This is a critical safety issue - log error and fall back to defaults
        log_message "error" "CRITICAL: 24/7 restrictions detected in config file (manual edit bypassed validation). Falling back to default restrictions for safety."
        log_to_file "ERROR" "CRITICAL SAFETY ISSUE: 24/7 restrictions detected in config file. This would lock the user out of their system. Falling back to default restrictions. Please use configure.sh to fix the configuration."
        
        # Mark that we should use defaults instead of reading from config file
        use_defaults=true
    fi
    
    # Get current day of week (0=Sunday, 6=Saturday)
    local current_day
    current_day=$(date +%w)
    
    # Get current time in HHMM format (Enhancement 16b)
    local current_time_hhmm
    current_time_hhmm=$(get_current_time)
    
    # Parse configuration for current day
    # If 24/7 restrictions were detected, use defaults instead of config file
    local restricted_range
    if [ "${use_defaults}" = "true" ]; then
        # Use default restrictions (safe - only 5 hours per day)
        # Defaults are defined in config.sh: DEFAULT_HOURS array
        # For Sunday (0): "1-5", for Monday-Friday (1-5): "0-5", for Saturday (6): "1-5"
        case "${current_day}" in
            0) restricted_range="1-5" ;;  # Sunday: 1:00 AM to 4:59 AM
            6) restricted_range="1-5" ;;  # Saturday: 1:00 AM to 4:59 AM
            *) restricted_range="0-5" ;; # Monday-Friday: Midnight to 4:59 AM
        esac
    else
        # Config is safe, read from file
        restricted_range=$(parse_config "${current_day}")
    fi
    
    # Check if current time is within restricted range for current day.
    # The previous-day overnight carry is ALWAYS evaluated regardless of whether
    # the current day has its own ranges (Phase 1.8 fix).
    local is_restricted=false
    local matched_range="${restricted_range}"

    # Calculate previous day index (handle Sunday wrap-around)
    local prev_day
    if [ "${current_day}" -eq 0 ]; then
        prev_day=6
    else
        prev_day=$((current_day - 1))
    fi

    # Get previous day's restriction range for overnight carry check
    local prev_day_range
    if [ "${use_defaults}" = "true" ]; then
        case "${prev_day}" in
            0) prev_day_range="1-5" ;;
            6) prev_day_range="1-5" ;;
            *) prev_day_range="0-5" ;;
        esac
    else
        prev_day_range=$(parse_config "${prev_day}")
    fi

    # Helper: normalise a range component to HHMM integer for numeric comparison
    _norm_to_hhmm() {
        local part="$1"
        if [[ "${part}" =~ : ]]; then
            echo "${part}" | tr -d ':'
        else
            printf "%02d00" "${part}"
        fi
    }

    # Check current day's own restricted range first
    if is_restricted_time "${current_time_hhmm}" "${restricted_range}"; then
        is_restricted=true
    fi

    # Always check previous day for overnight carry (runs even when current day has ranges).
    if [ "${is_restricted}" = "false" ] && [ -n "${prev_day_range}" ]; then
        local IFS=','
        for range in ${prev_day_range}; do
            range=$(echo "${range}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            local start_part="${range%%-*}"
            local end_part="${range##*-}"
            local start_time end_time
            start_time=$(_norm_to_hhmm "${start_part}")
            end_time=$(_norm_to_hhmm "${end_part}")

            # Only overnight ranges carry to the next day
            if [ "${start_time}" -gt "${end_time}" ]; then
                if [ "${current_time_hhmm}" -lt "${end_time}" ]; then
                    is_restricted=true
                    matched_range="${range} (from previous day)"
                    break
                fi
            fi
        done
    fi

    if [ "${is_restricted}" = "true" ]; then
        # Check if pause is currently active (Enhancement #21)
        # Pause only suppresses warning popups, not restrictions
        # configure.sh blocking and uninstall.sh protection still apply during pause
        if is_pause_active; then
            # Pause is active, skip showing warning popup
            log_message "info" "Pause active, skipping warning popup (restrictions still apply)"
            log_to_file "INFO" "Pause active, skipping warning popup - Day: ${current_day}, Time: ${current_time_hhmm}, Range: ${matched_range}"
            exit 0
        fi
        
        log_message "info" "Restricted time detected: Day ${current_day}, Time ${current_time_hhmm}, Range ${matched_range}"
        
        # Get display environment info for logging
        local env_type display_id
        env_type=$(detect_display_environment)
        display_id=$(get_display_identifier "${env_type}")
        
        # Get system mode for logging (Enhancement #4)
        local system_mode="unknown"
        if type detect_system_mode >/dev/null 2>&1; then
            system_mode=$(detect_system_mode 2>/dev/null || echo "unknown")
        fi
        
        # Log warning trigger with full context
        log_to_file "WARNING" "Restricted time detected - Day: ${current_day}, Time: ${current_time_hhmm}, Range: ${matched_range}, Display: ${env_type}, Display ID: ${display_id}, System Mode: ${system_mode}"
        
        show_warning
    else
        # Not a restricted hour, exit silently
        exit 0
    fi
}

# Run main function
main "$@"
