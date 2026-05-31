#!/bin/bash

###############################################################################
# Sleep Warning System - Pause State Management Module
#
# This module handles pause state file management including:
# - Checking if pause is currently active
# - Activating pause for configured duration
# - Checking if user can pause now (cooldown + enabled + not already active)
# - Clearing expired pause state while retaining cooldown timestamps
# - Reading pause state file values
#
# Dependencies:
#   - config.sh (PAUSE_STATE_FILE, get_pause_enabled, get_pause_cooldown_hours,
#     pause_is_valid_duration_minutes)
#   - logging.sh (for logging functions)
#
# Usage: Source this file after config.sh and logging.sh
#   source lib/config.sh
#   source lib/logging.sh
#   source lib/pause-state.sh
###############################################################################

# Convert YYYY-MM-DD to local midnight Unix timestamp (Linux date -d / macOS date -j).
_pause_date_to_midnight_epoch() {
    local date_str="$1"
    date -d "${date_str} 00:00:00" +%s 2>/dev/null \
        || date -j -f "%Y-%m-%d %H:%M:%S" "${date_str} 00:00:00" +%s 2>/dev/null \
        || echo ""
}

# Read LAST_PAUSE_TIMESTAMP from state file (Unix seconds or empty).
get_last_pause_timestamp() {
    if [ ! -f "${PAUSE_STATE_FILE}" ]; then
        echo ""
        return 0
    fi

    local timestamp
    timestamp=$(grep -E "^[[:space:]]*LAST_PAUSE_TIMESTAMP=" "${PAUSE_STATE_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')

    if [ -n "${timestamp}" ] && [[ "${timestamp}" =~ ^[0-9]+$ ]]; then
        echo "${timestamp}"
        return 0
    fi

    echo ""
    return 0
}

# Effective last activation time for cooldown (handles migration from LAST_PAUSE_DATE only).
_pause_get_effective_last_activation_timestamp() {
    local last_ts
    last_ts=$(get_last_pause_timestamp)
    if [ -n "${last_ts}" ]; then
        echo "${last_ts}"
        return 0
    fi

    # Migration: LAST_PAUSE_DATE without timestamp — treat today's date as midnight today.
    local last_pause_date
    last_pause_date=$(get_last_pause_date)
    if [ -z "${last_pause_date}" ]; then
        echo ""
        return 0
    fi

    local today
    today=$(date +%Y-%m-%d)
    if [ "${last_pause_date}" = "${today}" ]; then
        _pause_date_to_midnight_epoch "${today}"
        return 0
    fi

    # Prior calendar day without timestamp — cooldown from old once-per-day has elapsed.
    echo ""
    return 0
}

# Returns 0 if cooldown period has elapsed (or no prior activation), 1 if still in cooldown.
_pause_cooldown_elapsed() {
    local effective_ts
    effective_ts=$(_pause_get_effective_last_activation_timestamp)
    if [ -z "${effective_ts}" ]; then
        return 0
    fi

    local cooldown_hours current_time elapsed_seconds required_seconds
    cooldown_hours=$(get_pause_cooldown_hours)
    current_time=$(date +%s)
    elapsed_seconds=$((current_time - effective_ts))
    required_seconds=$((cooldown_hours * 3600))

    if [ "${elapsed_seconds}" -ge "${required_seconds}" ]; then
        return 0
    fi
    return 1
}

# Unix timestamp when pause becomes available again, or empty if available now.
get_next_pause_available_timestamp() {
    if _pause_cooldown_elapsed; then
        echo ""
        return 0
    fi

    local effective_ts cooldown_hours
    effective_ts=$(_pause_get_effective_last_activation_timestamp)
    cooldown_hours=$(get_pause_cooldown_hours)
    echo $((effective_ts + cooldown_hours * 3600))
    return 0
}

# Write retained cooldown fields without an active pause end timestamp.
_pause_write_retained_state() {
    local last_pause_date="$1"
    local last_pause_timestamp="$2"

    mkdir -p "${CONFIG_DIR}"

    if [ -n "${last_pause_date}" ] || [ -n "${last_pause_timestamp}" ]; then
        local temp_file
        temp_file=$(mktemp "${PAUSE_STATE_FILE}.tmp.XXXXXX" 2>/dev/null || echo "${PAUSE_STATE_FILE}.tmp")
        {
            [ -n "${last_pause_date}" ] && echo "LAST_PAUSE_DATE=${last_pause_date}"
            [ -n "${last_pause_timestamp}" ] && echo "LAST_PAUSE_TIMESTAMP=${last_pause_timestamp}"
        } > "${temp_file}"
        chmod 0600 "${temp_file}"
        if ! mv "${temp_file}" "${PAUSE_STATE_FILE}" 2>/dev/null; then
            rm -f "${temp_file}" 2>/dev/null
            log_to_file "ERROR" "Failed to update pause state file (retained cooldown fields)"
            return 1
        fi
    else
        clear_pause_state
    fi
}

# Check if pause is currently active
# Returns 0 if pause is active, 1 if not
is_pause_active() {
    if [ ! -f "${PAUSE_STATE_FILE}" ]; then
        return 1
    fi

    local pause_end_timestamp
    pause_end_timestamp=$(get_pause_end_timestamp)

    if [ -z "${pause_end_timestamp}" ]; then
        return 1
    fi

    local current_time
    current_time=$(date +%s)

    if [ "${current_time}" -lt "${pause_end_timestamp}" ]; then
        return 0
    fi
    return 1
}

# Get pause end timestamp from state file
# Returns Unix timestamp or empty string if not found/invalid
get_pause_end_timestamp() {
    if [ ! -f "${PAUSE_STATE_FILE}" ]; then
        echo ""
        return 0
    fi

    local timestamp
    timestamp=$(grep -E "^[[:space:]]*PAUSE_END_TIMESTAMP=" "${PAUSE_STATE_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')

    if [ -n "${timestamp}" ] && [[ "${timestamp}" =~ ^[0-9]+$ ]]; then
        echo "${timestamp}"
        return 0
    fi

    echo ""
    return 0
}

# Get last pause date from state file
# Returns YYYY-MM-DD format date or empty string if not found/invalid
get_last_pause_date() {
    if [ ! -f "${PAUSE_STATE_FILE}" ]; then
        echo ""
        return 0
    fi

    local last_date
    last_date=$(grep -E "^[[:space:]]*LAST_PAUSE_DATE=" "${PAUSE_STATE_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')

    if [ -n "${last_date}" ] && echo "${last_date}" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        echo "${last_date}"
        return 0
    fi

    echo ""
    return 0
}

# Primary API: can the user activate pause right now?
# Returns 0 if yes, 1 if no (disabled, active pause, or cooldown not elapsed).
can_pause_now() {
    local pause_enabled
    pause_enabled=$(get_pause_enabled)

    if [ "${pause_enabled}" != "true" ]; then
        return 1
    fi

    if is_pause_active; then
        return 1
    fi

    if ! _pause_cooldown_elapsed; then
        return 1
    fi

    return 0
}

# Backward-compatible wrapper (cooldown-based, not calendar-day).
can_pause_today() {
    can_pause_now
}

# Activate pause for specified duration (minutes from config allowlist).
# Returns 0 on success, 1 on error or if pause is not allowed.
activate_pause() {
    local duration_minutes="$1"

    local pause_enabled
    pause_enabled=$(get_pause_enabled)
    if [ "${pause_enabled}" != "true" ]; then
        log_message "error" "Pause activation rejected: pause feature disabled"
        return 1
    fi

    if is_pause_active; then
        log_message "error" "Pause activation rejected: pause already active"
        return 1
    fi

    if ! _pause_cooldown_elapsed; then
        log_message "error" "Pause activation rejected: cooldown not elapsed"
        return 1
    fi

    if [ -z "${duration_minutes}" ] || [[ ! "${duration_minutes}" =~ ^[0-9]+$ ]]; then
        log_message "error" "Invalid pause duration: ${duration_minutes}"
        return 1
    fi

    if type pause_is_valid_duration_minutes >/dev/null 2>&1; then
        if ! pause_is_valid_duration_minutes "${duration_minutes}"; then
            log_message "error" "Invalid pause duration: ${duration_minutes} (not in allowlist)"
            return 1
        fi
    elif [ "${duration_minutes}" -ne 5 ] && [ "${duration_minutes}" -ne 10 ]; then
        log_message "error" "Invalid pause duration: ${duration_minutes}"
        return 1
    fi

    local current_time pause_end_timestamp today
    current_time=$(date +%s)
    pause_end_timestamp=$((current_time + (duration_minutes * 60)))
    today=$(date +%Y-%m-%d)

    mkdir -p "${CONFIG_DIR}"

    {
        echo "PAUSE_END_TIMESTAMP=${pause_end_timestamp}"
        echo "LAST_PAUSE_DATE=${today}"
        echo "LAST_PAUSE_TIMESTAMP=${current_time}"
    } > "${PAUSE_STATE_FILE}"

    chmod 0600 "${PAUSE_STATE_FILE}"

    local pause_end_time
    pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")
    log_message "info" "Pause activated for ${duration_minutes} minutes, expires at ${pause_end_time}"
    log_to_file "INFO" "Pause activated: Duration=${duration_minutes} minutes, End timestamp=${pause_end_timestamp}, End time=${pause_end_time}, Activation timestamp=${current_time}, Date=${today}"

    return 0
}

# Clear expired or invalid pause state
clear_pause_state() {
    if [ -f "${PAUSE_STATE_FILE}" ]; then
        rm -f "${PAUSE_STATE_FILE}"
        log_message "info" "Pause state cleared"
        log_to_file "INFO" "Pause state file removed"
    fi
}

# Check if pause expired and clear active pause while retaining cooldown fields.
check_and_clear_expired_pause() {
    if [ ! -f "${PAUSE_STATE_FILE}" ]; then
        return 0
    fi

    local last_pause_date last_pause_timestamp
    last_pause_date=$(get_last_pause_date)
    last_pause_timestamp=$(get_last_pause_timestamp)

    local pause_end_timestamp
    pause_end_timestamp=$(get_pause_end_timestamp)

    if [ -z "${pause_end_timestamp}" ]; then
        if [ -n "${last_pause_date}" ] || [ -n "${last_pause_timestamp}" ]; then
            _pause_write_retained_state "${last_pause_date}" "${last_pause_timestamp}"
            log_to_file "WARNING" "Pause state file had invalid timestamp, cleared PAUSE_END (kept cooldown fields)"
        else
            clear_pause_state
            log_to_file "WARNING" "Pause state file had invalid timestamp and no cooldown fields, cleared"
        fi
        return 0
    fi

    local current_time
    current_time=$(date +%s)

    if [ "${current_time}" -ge "${pause_end_timestamp}" ]; then
        if [ -n "${last_pause_date}" ] || [ -n "${last_pause_timestamp}" ]; then
            local temp_file
            temp_file=$(mktemp "${PAUSE_STATE_FILE}.tmp.XXXXXX" 2>/dev/null || echo "${PAUSE_STATE_FILE}.tmp")
            {
                [ -n "${last_pause_date}" ] && echo "LAST_PAUSE_DATE=${last_pause_date}"
                [ -n "${last_pause_timestamp}" ] && echo "LAST_PAUSE_TIMESTAMP=${last_pause_timestamp}"
            } > "${temp_file}"
            chmod 0600 "${temp_file}"

            if mv "${temp_file}" "${PAUSE_STATE_FILE}" 2>/dev/null; then
                log_to_file "INFO" "Pause expired, cleared PAUSE_END_TIMESTAMP (kept cooldown fields)"
            else
                rm -f "${temp_file}" 2>/dev/null
                log_to_file "ERROR" "Failed to update pause state file after expiration"
            fi
        else
            clear_pause_state
            log_to_file "INFO" "Pause expired, cleared pause state file (no cooldown fields found)"
        fi
    fi

    return 0
}
