#!/bin/bash

###############################################################################
# Sleep Warning System - Logging Module
#
# This module handles all logging functionality including:
# - Logging to systemd journal
# - File-based logging with rotation
#
# Dependencies: config.sh (for CONFIG_DIR, LOG_FILE, MAX_LOG_SIZE, SCRIPT_NAME)
#
# Usage: Source this file after config.sh
#   source lib/config.sh
#   source lib/logging.sh
###############################################################################

# Logging function (optional, logs to systemd journal if available)
log_message() {
    local level="$1"
    shift
    local message="$*"
    
    # Try to log to systemd journal if available
    if command -v logger >/dev/null 2>&1; then
        logger -t "${SCRIPT_NAME}" -p "user.${level}" "${message}"
    fi
}

# File-based logging function
log_to_file() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Ensure log directory exists
    mkdir -p "${CONFIG_DIR}"
    
    # Rotate log if it exceeds max size
    if [ -f "${LOG_FILE}" ] && [ -s "${LOG_FILE}" ]; then
        local log_size
        log_size=$(stat -f%s "${LOG_FILE}" 2>/dev/null || stat -c%s "${LOG_FILE}" 2>/dev/null || echo 0)
        if [ "${log_size}" -gt "${MAX_LOG_SIZE}" ]; then
            # Rotate: keep last 1000 lines
            tail -n 1000 "${LOG_FILE}" > "${LOG_FILE}.tmp" 2>/dev/null && mv "${LOG_FILE}.tmp" "${LOG_FILE}" 2>/dev/null
        fi
    fi
    
    # Append to log file
    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}" 2>/dev/null
}
