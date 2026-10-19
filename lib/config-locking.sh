#!/bin/bash

###############################################################################
# Sleep Warning System - Config File Locking Module
#
# This module handles config file locking during restricted hours (Enhancement #18).
# It uses file system permissions (chmod) to make the config directory and file
# read-only during restricted hours and lock hours.
#
# Functions:
# - is_config_lock_active()        - Check if lock should be active
# - store_lock_state()             - Save permissions to marker file
# - retrieve_lock_state()          - Read permissions from marker file
# - apply_config_directory_lock()    - Main locking function
# - check_and_restore_config_file() - Self-healing function
#
# Dependencies:
# - config.sh (for CONFIG_FILE, CONFIG_DIR, get_config_lock_enabled, parse_config, parse_lock_hours)
# - time-validation.sh (for is_restricted_hour, is_lock_hour)
# - logging.sh (for log_message, log_to_file - optional)
#
# Usage: Source this file after config.sh and time-validation.sh
#   source lib/config.sh
#   source lib/time-validation.sh
#   source lib/config-locking.sh
###############################################################################

# Marker file location (in parent directory, not in locked config subdirectory)
MARKER_FILE="${CONFIG_DIR}/.config_locked"
SNAPSHOT_FILE="${CONFIG_DIR}/.config_locked_snapshot"
CONFIG_DIR_LOCKED="${CONFIG_DIR}/config"

# Check if config lock should be active
# Returns 0 if lock should be active, 1 if not
# This function checks CONFIG_LOCK_ENABLED and current time (restriction hours OR lock hours)
is_config_lock_active() {
    if type runtime_daily_caps_are_safe >/dev/null 2>&1 && ! runtime_daily_caps_are_safe; then
        return 1
    fi
    # Check if config locking is enabled
    local lock_enabled
    lock_enabled=$(get_config_lock_enabled)
    
    # If locking is disabled, lock should not be active
    if [ "${lock_enabled}" != "true" ]; then
        return 1
    fi
    
    # Get current day of week (0=Sunday, 6=Saturday)
    local current_day
    current_day=$(date +%w)
    
    # Get current time in HHMM format (Enhancement 16b)
    local current_time_hhmm
    current_time_hhmm=$(get_current_time)
    
    # Parse restriction hours for current day
    local restricted_range
    restricted_range=$(parse_config "${current_day}")
    
    # Check if current time is within restricted range for current day
    if is_restricted_time "${current_time_hhmm}" "${restricted_range}" self; then
        # Current time is restricted - lock should be active
        return 0
    fi
    
    # Parse lock hours for current day (reuse existing function from Enhancement #19)
    local lock_hours_range=""
    if type parse_lock_hours >/dev/null 2>&1; then
        lock_hours_range=$(parse_lock_hours "${current_day}")
    fi
    
    # Check if current time is within lock hours for current day
    if [ -n "${lock_hours_range}" ] && type is_lock_hour >/dev/null 2>&1; then
        if is_restricted_time "${current_time_hhmm}" "${lock_hours_range}" self; then
            # Current time is in lock hours - lock should be active
            return 0
        fi
    fi
    
    # Current day may not have restrictions or lock hours, but check if previous day has overnight ranges
    # that extend into current day (same logic as sleep-warning.sh and check_config_lock_time)
    
    # Calculate previous day (handle wrap-around: Sunday (0) -> Saturday (6))
    local prev_day
    if [ "${current_day}" -eq 0 ]; then
        prev_day=6  # Sunday -> Saturday
    else
        prev_day=$((current_day - 1))
    fi
    
    # Check previous day's restriction hours for overnight ranges that carry into today.
    local prev_day_range
    prev_day_range=$(parse_config "${prev_day}")
    if is_time_in_previous_day_overnight_tail "${current_time_hhmm}" "${prev_day_range}"; then
        return 0
    fi
    
    # Check previous day's lock hours for overnight ranges that carry into today.
    if type parse_lock_hours >/dev/null 2>&1; then
        local prev_day_lock_hours
        prev_day_lock_hours=$(parse_lock_hours "${prev_day}")
        if is_time_in_previous_day_overnight_tail "${current_time_hhmm}" "${prev_day_lock_hours}"; then
            return 0
        fi
    fi
    
    # Not in restricted hours or lock hours - lock should not be active
    return 1
}

# Store lock state (permissions) to marker file
# This function gets current permissions and stores them in the marker file
# Parameters: None
# Returns: 0 on success, 1 on error
store_lock_state() {
    local dir_mode="755"
    local file_mode="644"
    local marker_mode="644"
    local reason="restricted_hours"
    local timestamp
    
    # Get current timestamp (ISO format)
    timestamp=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "$(date +%s)")
    
    # Determine reason (restricted hours or lock hours)
    # This is a simplified check - in practice, we could check which one applies
    # For now, we'll use "restricted_hours" as default, or check if we're in lock hours
    local current_day current_hour
    current_day=$(date +%w)
    current_hour=$(date +%H)
    current_hour=$((10#${current_hour}))
    
    local lock_hours_range=""
    if type parse_lock_hours >/dev/null 2>&1; then
        lock_hours_range=$(parse_lock_hours "${current_day}")
    fi
    
    if [ -n "${lock_hours_range}" ] && type is_lock_hour >/dev/null 2>&1; then
        if is_lock_hour "${current_hour}" "${lock_hours_range}"; then
            reason="lock_hours"
        fi
    fi
    
    # Get current directory permissions (if directory exists)
    if [ -d "${CONFIG_DIR_LOCKED}" ]; then
        if command -v stat >/dev/null 2>&1; then
            # Try Linux format first
            dir_mode=$(stat -c '%a' "${CONFIG_DIR_LOCKED}" 2>/dev/null)
            if [ $? -ne 0 ]; then
                # Try macOS format
                dir_mode=$(stat -f '%A' "${CONFIG_DIR_LOCKED}" 2>/dev/null)
            fi
            # If both fail, use default
            if [ -z "${dir_mode}" ] || ! [[ "${dir_mode}" =~ ^[0-7]{3,4}$ ]]; then
                dir_mode="755"
            fi
        fi
    fi
    
    # Get current file permissions (if file exists)
    if [ -f "${CONFIG_FILE}" ]; then
        if command -v stat >/dev/null 2>&1; then
            # Try Linux format first
            file_mode=$(stat -c '%a' "${CONFIG_FILE}" 2>/dev/null)
            if [ $? -ne 0 ]; then
                # Try macOS format
                file_mode=$(stat -f '%A' "${CONFIG_FILE}" 2>/dev/null)
            fi
            # If both fail, use default
            if [ -z "${file_mode}" ] || ! [[ "${file_mode}" =~ ^[0-7]{3,4}$ ]]; then
                file_mode="644"
            fi
        fi
    fi
    
    # Get current marker file permissions (if file exists)
    if [ -f "${MARKER_FILE}" ]; then
        if command -v stat >/dev/null 2>&1; then
            # Try Linux format first
            marker_mode=$(stat -c '%a' "${MARKER_FILE}" 2>/dev/null)
            if [ $? -ne 0 ]; then
                # Try macOS format
                marker_mode=$(stat -f '%A' "${MARKER_FILE}" 2>/dev/null)
            fi
            # If both fail, use default
            if [ -z "${marker_mode}" ] || ! [[ "${marker_mode}" =~ ^[0-7]{3,4}$ ]]; then
                marker_mode="644"
            fi
        fi
    fi
    
    # Write marker file with all state information
    {
        echo "TIMESTAMP=${timestamp}|REASON=${reason}|DIR_MODE=${dir_mode}|FILE_MODE=${file_mode}|MARKER_MODE=${marker_mode}"
    } > "${MARKER_FILE}" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Retrieve lock state (permissions) from marker file
# Returns: "DIR_MODE FILE_MODE MARKER_MODE" on success, empty string on failure
# Example: "755 644 644"
retrieve_lock_state() {
    # Check if marker file exists
    if [ ! -f "${MARKER_FILE}" ]; then
        return 1
    fi
    
    # Read marker file
    local marker_content
    marker_content=$(cat "${MARKER_FILE}" 2>/dev/null)
    
    if [ -z "${marker_content}" ]; then
        return 1
    fi
    
    # Parse marker file format: TIMESTAMP=...|REASON=...|DIR_MODE=...|FILE_MODE=...|MARKER_MODE=...
    local dir_mode=""
    local file_mode=""
    local marker_mode=""
    
    # Extract DIR_MODE
    if echo "${marker_content}" | grep -q "DIR_MODE="; then
        dir_mode=$(echo "${marker_content}" | sed -n 's/.*DIR_MODE=\([^|]*\).*/\1/p')
    fi
    
    # Extract FILE_MODE
    if echo "${marker_content}" | grep -q "FILE_MODE="; then
        file_mode=$(echo "${marker_content}" | sed -n 's/.*FILE_MODE=\([0-7]\{3,4\}\).*/\1/p')
    fi
    
    # Extract MARKER_MODE
    if echo "${marker_content}" | grep -q "MARKER_MODE="; then
        marker_mode=$(echo "${marker_content}" | sed -n 's/.*MARKER_MODE=\([0-7]\{3,4\}\).*/\1/p')
    fi
    
    # Validate modes (must be valid octal permissions)
    local valid_mode=true
    
    if [ -z "${dir_mode}" ] || ! [[ "${dir_mode}" =~ ^[0-7]{3,4}$ ]]; then
        valid_mode=false
    fi
    
    if [ -z "${file_mode}" ] || ! [[ "${file_mode}" =~ ^[0-7]{3,4}$ ]]; then
        valid_mode=false
    fi
    
    if [ -z "${marker_mode}" ] || ! [[ "${marker_mode}" =~ ^[0-7]{3,4}$ ]]; then
        valid_mode=false
    fi
    
    if [ "${valid_mode}" = "false" ]; then
        return 1
    fi
    
    # Return modes as space-separated string
    echo "${dir_mode} ${file_mode} ${marker_mode}"
    return 0
}

# Apply config directory lock (main locking function)
# This function is idempotent - safe to call multiple times
# Returns: 0 on success, 1 on error
apply_config_directory_lock() {
    # Check if lock should be active
    if ! is_config_lock_active; then
        # Lock should NOT be active - unlock if currently locked
        if [ -f "${MARKER_FILE}" ]; then
            # Retrieve stored permissions
            local stored_perms
            stored_perms=$(retrieve_lock_state)
            
            local dir_mode="755"
            local file_mode="644"
            local marker_mode="644"
            
            if [ -n "${stored_perms}" ]; then
                # Parse stored permissions
                dir_mode=$(echo "${stored_perms}" | cut -d' ' -f1)
                file_mode=$(echo "${stored_perms}" | cut -d' ' -f2)
                marker_mode=$(echo "${stored_perms}" | cut -d' ' -f3)
            else
                # Marker file corrupted/missing - use safe defaults
                if type log_message >/dev/null 2>&1; then
                    log_message "warning" "Marker file corrupted or invalid, using safe defaults for permission restoration"
                fi
            fi
            
            # Restore marker file permissions first (make it writable)
            chmod "${marker_mode}" "${MARKER_FILE}" 2>/dev/null || chmod 644 "${MARKER_FILE}" 2>/dev/null
            
            # Restore directory permissions
            if [ -d "${CONFIG_DIR_LOCKED}" ]; then
                chmod "${dir_mode}" "${CONFIG_DIR_LOCKED}" 2>/dev/null || chmod 755 "${CONFIG_DIR_LOCKED}" 2>/dev/null
            fi
            
            # Restore file permissions
            if [ -f "${CONFIG_FILE}" ]; then
                chmod "${file_mode}" "${CONFIG_FILE}" 2>/dev/null || chmod 644 "${CONFIG_FILE}" 2>/dev/null
            fi
            
            # Remove marker and snapshot files
            rm -f "${MARKER_FILE}" 2>/dev/null
            rm -f "${SNAPSHOT_FILE}" 2>/dev/null
        fi
        return 0
    fi
    
    # Lock should be active
    # Ensure config directory exists
    mkdir -p "${CONFIG_DIR_LOCKED}" 2>/dev/null
    
    # Check if marker file exists
    if [ ! -f "${MARKER_FILE}" ]; then
        # First-time lock - store current permissions
        if ! store_lock_state; then
            # Failed to store state - log warning but continue
            if type log_message >/dev/null 2>&1; then
                log_message "warning" "Failed to store lock state, using defaults for restoration"
            fi
        fi
        
        # Create snapshot copy (for self-healing)
        if [ -f "${CONFIG_FILE}" ]; then
            cp "${CONFIG_FILE}" "${SNAPSHOT_FILE}" 2>/dev/null
        fi
        
        # Lock marker file (read-only to prevent deletion/editing)
        chmod 444 "${MARKER_FILE}" 2>/dev/null
    fi
    
    # Apply lock (idempotent - safe to call multiple times)
    # Lock directory
    if [ -d "${CONFIG_DIR_LOCKED}" ]; then
        chmod 555 "${CONFIG_DIR_LOCKED}" 2>/dev/null
    fi
    
    # Lock file
    if [ -f "${CONFIG_FILE}" ]; then
        chmod 444 "${CONFIG_FILE}" 2>/dev/null
    fi
    
    # Re-assert marker file lock (in case user changed it)
    if [ -f "${MARKER_FILE}" ]; then
        chmod 444 "${MARKER_FILE}" 2>/dev/null
    fi
    
    return 0
}

# Check and restore config file (self-healing function)
# This function detects tampering and restores the config file if needed
# Returns: 0 on success, 1 on error
check_and_restore_config_file() {
    # Only check if lock should be active
    if ! is_config_lock_active; then
        # Lock is not active, no need to check
        return 0
    fi
    
    # Lock is active - check for tampering
    
    # Check if config file exists
    if [ ! -f "${CONFIG_FILE}" ]; then
        # File is missing - restore from snapshot
        if [ -f "${SNAPSHOT_FILE}" ]; then
            cp "${SNAPSHOT_FILE}" "${CONFIG_FILE}" 2>/dev/null
            if [ $? -eq 0 ]; then
                # Re-apply lock
                chmod 444 "${CONFIG_FILE}" 2>/dev/null
                chmod 555 "${CONFIG_DIR_LOCKED}" 2>/dev/null
                
                if type log_message >/dev/null 2>&1; then
                    log_message "warning" "Config file was deleted during lock hours, restored from snapshot"
                fi
            fi
        fi
        return 0
    fi
    
    # File exists - check if it was modified (compare modification time with snapshot)
    if [ -f "${SNAPSHOT_FILE}" ]; then
        local file_mtime snapshot_mtime
        if command -v stat >/dev/null 2>&1; then
            # Get modification times
            file_mtime=$(stat -c '%Y' "${CONFIG_FILE}" 2>/dev/null || stat -f '%m' "${CONFIG_FILE}" 2>/dev/null)
            snapshot_mtime=$(stat -c '%Y' "${SNAPSHOT_FILE}" 2>/dev/null || stat -f '%m' "${SNAPSHOT_FILE}" 2>/dev/null)
            
            # If file is newer than snapshot, it may have been modified
            if [ -n "${file_mtime}" ] && [ -n "${snapshot_mtime}" ] && [ "${file_mtime}" -gt "${snapshot_mtime}" ]; then
                # File was modified - restore from snapshot
                cp "${SNAPSHOT_FILE}" "${CONFIG_FILE}" 2>/dev/null
                if [ $? -eq 0 ]; then
                    # Re-apply lock
                    chmod 444 "${CONFIG_FILE}" 2>/dev/null
                    chmod 555 "${CONFIG_DIR_LOCKED}" 2>/dev/null
                    
                    if type log_message >/dev/null 2>&1; then
                        log_message "warning" "Config file was modified during lock hours, restored from snapshot"
                    fi
                fi
            fi
        fi
    fi
    
    # Re-assert read-only permissions (in case user changed them)
    if [ -d "${CONFIG_DIR_LOCKED}" ]; then
        # Check if directory is writable (not read-only)
        if [ -w "${CONFIG_DIR_LOCKED}" ]; then
            chmod 555 "${CONFIG_DIR_LOCKED}" 2>/dev/null
            if type log_message >/dev/null 2>&1; then
                log_message "warning" "Config directory permissions were changed during lock hours, re-applied lock"
            fi
        fi
    fi
    
    if [ -f "${CONFIG_FILE}" ]; then
        # Check if file is writable (not read-only)
        if [ -w "${CONFIG_FILE}" ]; then
            chmod 444 "${CONFIG_FILE}" 2>/dev/null
            if type log_message >/dev/null 2>&1; then
                log_message "warning" "Config file permissions were changed during lock hours, re-applied lock"
            fi
        fi
    fi
    
    if [ -f "${MARKER_FILE}" ]; then
        # Check if marker file is writable (not read-only)
        if [ -w "${MARKER_FILE}" ]; then
            chmod 444 "${MARKER_FILE}" 2>/dev/null
        fi
    fi
    
    return 0
}

# Temporarily restore write permissions so the configure wizard can save during lock hours.
# Call before atomic write; pair with config_lock_finish_wizard_write().
config_lock_prepare_for_wizard_write() {
    if ! is_config_lock_active 2>/dev/null; then
        return 0
    fi

    if [ ! -f "${MARKER_FILE}" ]; then
        return 0
    fi

    local stored_perms dir_mode file_mode marker_mode
    stored_perms=$(retrieve_lock_state)
    dir_mode="755"
    file_mode="644"
    marker_mode="644"
    if [ -n "${stored_perms}" ]; then
        dir_mode=$(echo "${stored_perms}" | cut -d' ' -f1)
        file_mode=$(echo "${stored_perms}" | cut -d' ' -f2)
        marker_mode=$(echo "${stored_perms}" | cut -d' ' -f3)
    fi

    chmod "${marker_mode}" "${MARKER_FILE}" 2>/dev/null || chmod 644 "${MARKER_FILE}" 2>/dev/null
    if [ -d "${CONFIG_DIR_LOCKED}" ]; then
        chmod "${dir_mode}" "${CONFIG_DIR_LOCKED}" 2>/dev/null || chmod 755 "${CONFIG_DIR_LOCKED}" 2>/dev/null
    fi
    if [ -f "${CONFIG_FILE}" ]; then
        chmod "${file_mode}" "${CONFIG_FILE}" 2>/dev/null || chmod 644 "${CONFIG_FILE}" 2>/dev/null
    fi
    return 0
}

# Re-apply read-only lock and refresh snapshot after a wizard save during lock hours.
config_lock_finish_wizard_write() {
    if ! is_config_lock_active 2>/dev/null; then
        return 0
    fi

    if [ -f "${CONFIG_FILE}" ]; then
        cp "${CONFIG_FILE}" "${SNAPSHOT_FILE}" 2>/dev/null || true
    fi

    if [ -d "${CONFIG_DIR_LOCKED}" ]; then
        chmod 555 "${CONFIG_DIR_LOCKED}" 2>/dev/null || true
    fi
    if [ -f "${CONFIG_FILE}" ]; then
        chmod 444 "${CONFIG_FILE}" 2>/dev/null || true
    fi
    if [ -f "${MARKER_FILE}" ]; then
        chmod 444 "${MARKER_FILE}" 2>/dev/null || true
    fi
    return 0
}
