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
source_required_lib "config.sh" || exit 1
source_required_lib "logging.sh" || exit 1
source_required_lib "pause-state.sh" || exit 1
source_required_lib "sleep-detection.sh" || exit 1  # Enhancement #9: Sleep/hibernate detection
source_required_lib "configure-core.sh" || exit 1
source_required_lib "configure-validation.sh" || exit 1
source_required_lib "display-detection.sh" || exit 1
source_required_lib "desktop-environment.sh" || exit 1
source_required_lib "window-management.sh" || exit 1
source_required_lib "time-validation.sh" || exit 1
source_required_lib "time-parsing.sh" || exit 1  # normalize_time_range for parse_config (12h config format)
source_required_lib "time-calculations.sh" || exit 1
source_required_lib "config-locking.sh" || exit 1  # Enhancement #18: Config file locking
source_required_lib "resolution-detection.sh" || exit 1  # Enhancement #3: Display resolution detection
source_required_lib "popup-display.sh" || exit 1

# Validate configuration file to prevent 24/7 restrictions
# This function checks if manual config file editing created 24/7 restrictions
# Returns 0 if config is safe, 1 if 24/7 restrictions detected
validate_config_safety() {
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        # No config file, use defaults (safe)
        return 0
    fi
    
    # Read all day configurations from config file
    # Format expected by check_restriction_coverage(): array of "DAYVAR=RANGE" strings
    local config_lines=()
    local i
    for i in 0 1 2 3 4 5 6; do
        local day_var="${DAY_VARS[${i}]}"
        
        # Check if day line exists in config file
        local day_line_exists
        day_line_exists=$(grep -E "^[[:space:]]*${day_var}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | head -n1)
        
        if [ -n "${day_line_exists}" ]; then
            # Day line exists - extract value (may be empty if explicitly skipped)
            local day_config
            day_config=$(echo "${day_line_exists}" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            if [ -n "${day_config}" ]; then
                # Has a value - configured with restrictions
                config_lines[${i}]="${day_var}=${day_config}"
            else
                # Line exists but is empty - explicitly skipped, no restrictions
                config_lines[${i}]="${day_var}="
            fi
        fi
        # If day line doesn't exist, don't add to array (will be treated as empty by check_restriction_coverage)
    done
    
    # Check total restriction coverage
    local validation_result
    validation_result=$(check_restriction_coverage "${config_lines[@]}")
    
    # If 24/7 restrictions detected, this is unsafe
    if [ "${validation_result}" = "block" ]; then
        return 1
    fi
    
    # Config is safe (ok or warn)
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
    
    # Check if current time is within restricted range for current day
    local is_restricted=false
    local matched_range="${restricted_range}"
    
    if is_restricted_time "${current_time_hhmm}" "${restricted_range}"; then
        is_restricted=true
    elif [ -z "${restricted_range}" ]; then
        # Current day is empty/skipped (no restrictions for this day)
        # Check if previous day has an overnight range that extends into current day
        # Calculate previous day (handle wrap-around: Sunday (0) -> Saturday (6))
        local prev_day
        if [ "${current_day}" -eq 0 ]; then
            prev_day=6  # Sunday -> Saturday
        else
            prev_day=$((current_day - 1))
        fi
        
        # Get previous day's configuration
        # If we're using defaults due to 24/7 restrictions, use defaults for previous day too
        local prev_day_range
        if [ "${use_defaults}" = "true" ]; then
            # Use default restrictions for previous day
            case "${prev_day}" in
                0) prev_day_range="1-5" ;;  # Sunday: 1:00 AM to 4:59 AM
                6) prev_day_range="1-5" ;;  # Saturday: 1:00 AM to 4:59 AM
                *) prev_day_range="0-5" ;; # Monday-Friday: Midnight to 4:59 AM
            esac
        else
            # Config is safe, read from file
            prev_day_range=$(parse_config "${prev_day}")
        fi
        
        # Check if previous day has overnight ranges that extend into current day
        if [ -n "${prev_day_range}" ]; then
            # Check each range in previous day's configuration
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
                
                # Check if this is an overnight range (start > end) that extends into current day
                if [ "${start_time}" -gt "${end_time}" ]; then
                    # Overnight range: check if current time falls within the end portion (before end_time)
                    if [ "${current_time_hhmm}" -lt "${end_time}" ]; then
                        is_restricted=true
                        matched_range="${range} (from previous day)"
                        break
                    fi
                fi
            done
        fi
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
        
        # Enhancement #30: Only show popup if at least POPUP_DISPLAY_FREQUENCY minutes since last popup
        local popup_freq_minutes popup_freq_seconds last_ts time_since_last
        popup_freq_minutes=$(get_popup_display_frequency)
        popup_freq_seconds=$((popup_freq_minutes * 60))
        last_ts=$(read_last_popup_time)
        if [ -n "${last_ts}" ]; then
            time_since_last=$(($(date +%s) - last_ts))
            if [ "${time_since_last}" -lt "${popup_freq_seconds}" ]; then
                log_message "info" "Skipping popup - ${time_since_last}s since last (display frequency: ${popup_freq_minutes} min)"
                log_to_file "INFO" "Skipping popup - ${time_since_last}s since last popup (display frequency: ${popup_freq_minutes} min)"
                exit 0
            fi
        fi
        
        show_warning
        
        # Record popup display time for frequency throttling (Enhancement #30)
        write_last_popup_time "$(date +%s)" 2>/dev/null || true
    else
        # Not a restricted hour, exit silently
        exit 0
    fi
}

# Run main function
main "$@"
