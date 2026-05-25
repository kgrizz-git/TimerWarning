#!/bin/bash

###############################################################################
# Sleep Warning System - Popup PID / State Management
#
# This module contains the PID/state-file based popup queue-prevention helpers
# extracted from `lib/popup-display.sh` to keep that file smaller.
#
# Functions:
# - cleanup_stale_pid()
# - get_popup_age(popup_pid)
# - is_popup_running()
# - close_existing_popups()
# - save_popup_pid(popup_pid)
# - cleanup_popup_pid([expected_pid])
#
# Dependencies:
# - Expects `POPUP_PID_FILE` to be set (from `lib/config.sh`)
# - Optionally uses:
#   - `log_to_file` (from `lib/logging.sh`)
#   - `check_window_tools` (from `lib/window-management.sh`)
#   - `close_popup_process` (from `lib/popup-display.sh`)
###############################################################################

# Clean up stale PID file if process no longer exists
# This function checks if the PID in the PID file is still running
# If not, removes the PID file
# Returns: 0 if cleaned up or file doesn't exist, 1 on error
# This is for Enhancement #9 (Popup Queue Prevention)
cleanup_stale_pid() {
    if [ ! -f "${POPUP_PID_FILE}" ]; then
        return 0  # No PID file, nothing to clean up
    fi
    
    local stored_pid
    stored_pid=$(cat "${POPUP_PID_FILE}" 2>/dev/null | tr -d '\n')
    
    if [ -z "${stored_pid}" ] || ! [[ "${stored_pid}" =~ ^[0-9]+$ ]]; then
        # Invalid PID in file, remove it
        rm -f "${POPUP_PID_FILE}" 2>/dev/null
        return 0
    fi
    
    # Check if process is still running
    if ! kill -0 "${stored_pid}" 2>/dev/null; then
        # Process no longer exists, remove stale PID file
        rm -f "${POPUP_PID_FILE}" 2>/dev/null
        if type log_to_file >/dev/null 2>&1; then
            log_to_file "INFO" "Cleaned up stale PID file: Process ${stored_pid} no longer exists"
        fi
        return 0
    fi
    
    return 0
}

# Get age of popup in seconds
# Parameters:
#   $1 - popup_pid - Process ID of the popup
# Returns: Age in seconds, or 0 if cannot determine
# This is for Enhancement #9 (Popup Queue Prevention)
get_popup_age() {
    local popup_pid="$1"
    
    if [ -z "${popup_pid}" ] || ! [[ "${popup_pid}" =~ ^[0-9]+$ ]]; then
        echo "0"
        return 1
    fi
    
    # Try to get process start time from /proc
    if [ -d "/proc/${popup_pid}" ]; then
        local start_time
        start_time=$(stat -c %Y "/proc/${popup_pid}" 2>/dev/null || echo "")
        
        if [ -n "${start_time}" ]; then
            local current_time
            current_time=$(date +%s)
            local age
            age=$((current_time - start_time))
            echo "${age}"
            return 0
        fi
    fi
    
    # Fallback: Try to get from PID file timestamp
    if [ -f "${POPUP_PID_FILE}" ]; then
        local file_timestamp
        file_timestamp=$(stat -c %Y "${POPUP_PID_FILE}" 2>/dev/null || echo "")
        
        if [ -n "${file_timestamp}" ]; then
            local current_time
            current_time=$(date +%s)
            local age
            age=$((current_time - file_timestamp))
            echo "${age}"
            return 0
        fi
    fi
    
    echo "0"
    return 1
}

# Check if popup is already running
# Returns: PID and age if found (format: "PID|AGE"), empty string if not found
# This is for Enhancement #9 (Popup Queue Prevention)
is_popup_running() {
    # Clean up stale PIDs first
    cleanup_stale_pid
    
    # Primary method: Check PID file
    if [ -f "${POPUP_PID_FILE}" ]; then
        local stored_pid
        stored_pid=$(cat "${POPUP_PID_FILE}" 2>/dev/null | tr -d '\n')
        
        if [ -n "${stored_pid}" ] && [[ "${stored_pid}" =~ ^[0-9]+$ ]]; then
            # Check if process is still running
            if kill -0 "${stored_pid}" 2>/dev/null; then
                local age
                age=$(get_popup_age "${stored_pid}")
                echo "${stored_pid}|${age}"
                return 0
            fi
        fi
    fi
    
    # Secondary method: Window title matching (if window tools available)
    local window_tool
    window_tool=$(check_window_tools)
    
    if [ -n "${window_tool}" ]; then
        local window_title="ALERT: Restricted time window"
        local found_pid=""
        
        case "${window_tool}" in
            wmctrl)
                # Use wmctrl to find window by title
                found_pid=$(wmctrl -l 2>/dev/null | grep -i "ALERT: Restricted time window" | head -n1 | awk '{print $1}' | xargs -I {} wmctrl -lp 2>/dev/null | grep "{}" | awk '{print $3}' | head -n1)
                ;;
            xdotool)
                # Use xdotool to find window by title
                found_pid=$(xdotool search --name "ALERT: Restricted time window" 2>/dev/null | head -n1)
                if [ -n "${found_pid}" ]; then
                    # Get process PID from window ID
                    found_pid=$(xdotool getwindowpid "${found_pid}" 2>/dev/null || echo "")
                fi
                ;;
        esac
        
        if [ -n "${found_pid}" ] && [[ "${found_pid}" =~ ^[0-9]+$ ]]; then
            # Verify it's actually a dialog tool process
            local proc_name
            proc_name=$(ps -p "${found_pid}" -o comm= 2>/dev/null | tr -d '\n')
            if echo "${proc_name}" | grep -qE "^(zenity|yad|kdialog)$"; then
                local age
                age=$(get_popup_age "${found_pid}")
                echo "${found_pid}|${age}"
                return 0
            fi
        fi
    fi
    
    # Final fallback: Process tree checking
    local dialog_pids
    dialog_pids=$(pgrep -f "zenity.*ALERT: Restricted time window\\|yad.*ALERT: Restricted time window\\|kdialog.*ALERT: Restricted time window" 2>/dev/null | head -n1)
    
    if [ -n "${dialog_pids}" ] && [[ "${dialog_pids}" =~ ^[0-9]+$ ]]; then
        local age
        age=$(get_popup_age "${dialog_pids}")
        echo "${dialog_pids}|${age}"
        return 0
    fi
    
    return 1
}

# Close all existing popups found
# This function finds and closes all popups matching our window title
# Returns: Number of popups closed
# This is for Enhancement #9 (Popup Queue Prevention)
close_existing_popups() {
    local closed_count=0
    local window_tool
    window_tool=$(check_window_tools)
    
    # Find all popups by window title
    local window_title="ALERT: Restricted time window"
    local window_ids=""
    
    if [ -n "${window_tool}" ]; then
        case "${window_tool}" in
            wmctrl)
                window_ids=$(wmctrl -l 2>/dev/null | grep -i "${window_title}" | awk '{print $1}')
                ;;
            xdotool)
                window_ids=$(xdotool search --name "${window_title}" 2>/dev/null)
                ;;
        esac
    fi
    
    # Also check PID file
    if [ -f "${POPUP_PID_FILE}" ]; then
        local stored_pid
        stored_pid=$(cat "${POPUP_PID_FILE}" 2>/dev/null | tr -d '\n')
        if [ -n "${stored_pid}" ] && [[ "${stored_pid}" =~ ^[0-9]+$ ]]; then
            if kill -0 "${stored_pid}" 2>/dev/null; then
                # Close process
                if close_popup_process "${stored_pid}" "unknown"; then
                    closed_count=$((closed_count + 1))
                fi
            fi
            # Clean up PID file
            rm -f "${POPUP_PID_FILE}" 2>/dev/null
        fi
    fi
    
    # Close windows found by window tools
    if [ -n "${window_ids}" ]; then
        local window_id
        for window_id in ${window_ids}; do
            # Get process PID from window
            local window_pid=""
            case "${window_tool}" in
                wmctrl)
                    window_pid=$(wmctrl -lp 2>/dev/null | grep "${window_id}" | awk '{print $3}' | head -n1)
                    ;;
                xdotool)
                    window_pid=$(xdotool getwindowpid "${window_id}" 2>/dev/null)
                    ;;
            esac
            
            if [ -n "${window_pid}" ] && [[ "${window_pid}" =~ ^[0-9]+$ ]]; then
                # Verify it's a dialog tool
                local proc_name
                proc_name=$(ps -p "${window_pid}" -o comm= 2>/dev/null | tr -d '\n')
                if echo "${proc_name}" | grep -qE "^(zenity|yad|kdialog)$"; then
                    if close_popup_process "${window_pid}" "${proc_name}"; then
                        closed_count=$((closed_count + 1))
                    fi
                fi
            fi
        done
    fi
    
    if [ "${closed_count}" -gt 0 ] && type log_to_file >/dev/null 2>&1; then
        log_to_file "INFO" "Closed ${closed_count} existing popup(s)"
    fi
    
    echo "${closed_count}"
    return 0
}

# Save popup PID to state file (atomic operation)
# Parameters:
#   $1 - popup_pid - Process ID to save
# Returns: 0 on success, 1 on failure
# This is for Enhancement #9 (Popup Queue Prevention)
save_popup_pid() {
    local popup_pid="$1"
    
    if [ -z "${popup_pid}" ] || ! [[ "${popup_pid}" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    # Ensure config directory exists
    local config_dir
    config_dir=$(dirname "${POPUP_PID_FILE}")
    if [ ! -d "${config_dir}" ]; then
        mkdir -p "${config_dir}" 2>/dev/null || return 1
    fi
    
    # Atomic write: write to temp file then rename
    local temp_file
    temp_file="${POPUP_PID_FILE}.tmp"
    echo "${popup_pid}" > "${temp_file}" 2>/dev/null
    if [ $? -eq 0 ]; then
        mv "${temp_file}" "${POPUP_PID_FILE}" 2>/dev/null || return 1
        if type log_to_file >/dev/null 2>&1; then
            log_to_file "INFO" "Saved popup PID to file: ${popup_pid}"
        fi
        return 0
    fi
    
    return 1
}

# Clean up popup PID file
# Parameters:
#   $1 - popup_pid - Process ID to verify (optional, if provided verifies it matches)
# Returns: 0 on success, 1 on failure
# This is for Enhancement #9 (Popup Queue Prevention)
cleanup_popup_pid() {
    local expected_pid="$1"
    
    if [ ! -f "${POPUP_PID_FILE}" ]; then
        return 0  # No PID file, nothing to clean up
    fi
    
    # If expected PID provided, verify it matches
    if [ -n "${expected_pid}" ] && [[ "${expected_pid}" =~ ^[0-9]+$ ]]; then
        local stored_pid
        stored_pid=$(cat "${POPUP_PID_FILE}" 2>/dev/null | tr -d '\n')
        if [ "${stored_pid}" != "${expected_pid}" ]; then
            # PID doesn't match, don't remove (might be a different popup)
            return 0
        fi
    fi
    
    # Remove PID file
    rm -f "${POPUP_PID_FILE}" 2>/dev/null
    if type log_to_file >/dev/null 2>&1; then
        if [ -n "${expected_pid}" ]; then
            log_to_file "INFO" "Cleaned up popup PID file: ${expected_pid}"
        else
            log_to_file "INFO" "Cleaned up popup PID file"
        fi
    fi
    return 0
}

