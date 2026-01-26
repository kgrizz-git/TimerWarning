#!/bin/bash

###############################################################################
# Sleep Warning System - Sleep/Hibernate Detection Module
#
# This module handles detection of system sleep/hibernate resume events
# to skip warnings for a grace period after system resume (Enhancement #9).
#
# Functions:
# - check_system_resume() - Detect if system recently resumed
# - get_last_resume_time() - Get timestamp of last resume
# - is_within_resume_grace_period() - Check if within grace period
# - update_uptime_tracking() - Store current uptime for comparison
# - should_skip_warning_after_resume() - Main function: returns 0 if should skip, 1 if should show
#
# Dependencies:
#   - config.sh (for SLEEP_RESUME_GRACE_PERIOD, LAST_UPTIME_FILE)
#   - logging.sh (for logging functions - optional)
#
# Usage: Source this file after config.sh
#   source lib/config.sh
#   source lib/logging.sh
#   source lib/sleep-detection.sh
###############################################################################

# Check if system recently resumed from sleep/hibernate
# Returns 0 if system recently resumed, 1 if not (or uncertain)
# Uses systemd-logind as primary method, uptime comparison as fallback
check_system_resume() {
    # Primary method: systemd-logind
    if command -v systemctl >/dev/null 2>&1; then
        local user_id
        user_id=$(id -u 2>/dev/null)
        
        if [ -n "${user_id}" ]; then
            # Try to get last resume time from systemd-logind
            local active_enter_timestamp
            active_enter_timestamp=$(systemctl show -p ActiveEnterTimestamp "user@${user_id}.service" 2>/dev/null | cut -d'=' -f2-)
            
            if [ -n "${active_enter_timestamp}" ] && [ "${active_enter_timestamp}" != "" ]; then
                # Convert systemd timestamp to Unix timestamp
                local resume_timestamp
                resume_timestamp=$(date -d "${active_enter_timestamp}" +%s 2>/dev/null || date -r "${active_enter_timestamp}" +%s 2>/dev/null || echo "")
                
                if [ -n "${resume_timestamp}" ]; then
                    local current_time
                    current_time=$(date +%s)
                    local time_since_resume
                    time_since_resume=$((current_time - resume_timestamp))
                    
                    # If resume was within last 2 minutes (120 seconds), consider it recent
                    # This is more lenient than grace period to account for detection delays
                    if [ "${time_since_resume}" -ge 0 ] && [ "${time_since_resume}" -le 120 ]; then
                        if type log_to_file >/dev/null 2>&1; then
                            log_to_file "INFO" "System resume detected via systemd-logind: ${time_since_resume} seconds ago"
                        fi
                        echo "${resume_timestamp}"
                        return 0
                    fi
                fi
            fi
        fi
    fi
    
    # Fallback method: uptime comparison
    if [ -f "${LAST_UPTIME_FILE}" ]; then
        local last_uptime
        last_uptime=$(cat "${LAST_UPTIME_FILE}" 2>/dev/null | tr -d '\n')
        
        if [ -n "${last_uptime}" ] && [[ "${last_uptime}" =~ ^[0-9]+$ ]]; then
            local current_uptime
            current_uptime=$(cat /proc/uptime 2>/dev/null | cut -d' ' -f1 | cut -d'.' -f1)
            
            if [ -n "${current_uptime}" ] && [[ "${current_uptime}" =~ ^[0-9]+$ ]]; then
                # If current uptime is less than last recorded uptime, system was resumed
                if [ "${current_uptime}" -lt "${last_uptime}" ]; then
                    local current_time
                    current_time=$(date +%s)
                    # Estimate resume time: current time - (last_uptime - current_uptime)
                    local estimated_resume_time
                    estimated_resume_time=$((current_time - (last_uptime - current_uptime)))
                    
                    if type log_to_file >/dev/null 2>&1; then
                        log_to_file "INFO" "System resume detected via uptime comparison: uptime decreased from ${last_uptime}s to ${current_uptime}s"
                    fi
                    echo "${estimated_resume_time}"
                    return 0
                fi
            fi
        fi
    fi
    
    # No clear evidence of resume
    return 1
}

# Get last resume timestamp
# Returns Unix timestamp of last resume, or empty string if not available
get_last_resume_time() {
    check_system_resume
}

# Check if we're within the grace period after resume
# Parameters:
#   $1 - resume_timestamp - Unix timestamp of when system resumed
# Returns: 0 if within grace period, 1 if not
is_within_resume_grace_period() {
    local resume_timestamp="$1"
    
    if [ -z "${resume_timestamp}" ] || ! [[ "${resume_timestamp}" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    local current_time
    current_time=$(date +%s)
    local time_since_resume
    time_since_resume=$((current_time - resume_timestamp))
    
    # Grace period is 60 seconds (1 minute) - fixed, not configurable
    if [ "${time_since_resume}" -ge 0 ] && [ "${time_since_resume}" -le "${SLEEP_RESUME_GRACE_PERIOD}" ]; then
        return 0
    fi
    
    return 1
}

# Update uptime tracking file
# Stores current system uptime for comparison on next run
update_uptime_tracking() {
    local current_uptime
    current_uptime=$(cat /proc/uptime 2>/dev/null | cut -d' ' -f1 | cut -d'.' -f1)
    
    if [ -n "${current_uptime}" ] && [[ "${current_uptime}" =~ ^[0-9]+$ ]]; then
        # Ensure config directory exists
        local config_dir
        config_dir=$(dirname "${LAST_UPTIME_FILE}")
        if [ ! -d "${config_dir}" ]; then
            mkdir -p "${config_dir}" 2>/dev/null || return 1
        fi
        
        # Write uptime to file (atomic: write to temp file then rename)
        local temp_file
        temp_file="${LAST_UPTIME_FILE}.tmp"
        echo "${current_uptime}" > "${temp_file}" 2>/dev/null
        if [ $? -eq 0 ]; then
            mv "${temp_file}" "${LAST_UPTIME_FILE}" 2>/dev/null || return 1
            return 0
        fi
    fi
    
    return 1
}

# Main function: Check if we should skip warning after resume
# Returns 0 if should skip (within grace period), 1 if should show warning
should_skip_warning_after_resume() {
    # Check if system recently resumed
    local resume_timestamp
    resume_timestamp=$(check_system_resume)
    local resume_detected=$?
    
    if [ "${resume_detected}" -eq 0 ] && [ -n "${resume_timestamp}" ]; then
        # Check if within grace period
        if is_within_resume_grace_period "${resume_timestamp}"; then
            local current_time
            current_time=$(date +%s)
            local time_since_resume
            time_since_resume=$((current_time - resume_timestamp))
            local remaining_grace
            remaining_grace=$((SLEEP_RESUME_GRACE_PERIOD - time_since_resume))
            
            if type log_to_file >/dev/null 2>&1; then
                log_to_file "INFO" "Skipping warning: System resumed ${time_since_resume} seconds ago (${remaining_grace} seconds remaining in grace period)"
            fi
            return 0
        fi
    fi
    
    # Update uptime tracking for next run (always update, even if no resume detected)
    update_uptime_tracking
    
    return 1
}
