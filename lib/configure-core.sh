#!/bin/bash

###############################################################################
# Sleep Warning System - Configuration Core Module
#
# This module provides core utilities, constants, and helper functions used
# throughout the configuration wizard.
#
# Functions:
# - has_zenity()             - Check if zenity is available (legacy, uses get_dialog_tool)
# - has_dialog_tool()        - Check if any dialog tool is available
# - get_dialog_tool()        - Get the currently selected dialog tool
# - has_gui()                - Check if GUI is available
# - minutes_to_oncalendar()  - Convert minutes to systemd OnCalendar format
# - format_hour_12h()        - Format hour to 12-hour format with AM/PM
# - format_endpoint_12h()    - Format a range endpoint (H, HH:MM, 24:00) to 12-hour format
# - get_threshold_warn_description()  - Get human-readable warning threshold description
# - get_threshold_block_description() - Get human-readable block threshold description
# - day_num_to_name_upper()  - Convert day number to uppercase day name (for config file)
# - day_num_to_name_title()  - Convert day number to titlecase day name (for display)
#
# Dependencies:
#   - desktop-environment.sh (for check_dialog_tool and detect_display_environment)
#   - config.sh (for get_dialog_tool_config, Enhancement #25)
#     Note: Functions handle case where dependencies are not yet loaded
#
# Global Variables/Constants:
# - SCRIPT_NAME              - Script identifier for configuration
# - CONFIG_DIR               - Configuration directory path
# - CONFIG_FILE              - Configuration file path
# - SYSTEMD_USER_DIR         - Systemd user directory path
# - TIMER_FILE               - Timer file path
# - SERVICE_NAME             - Service name for systemd
# - DAY_NAMES                - Array of day names (Sunday-Saturday)
# - DAY_VARS                 - Array of day variable names for config file
# - HOURS_PER_DAY_WARN       - Warning threshold in hours/day (default: 23)
# - HOURS_PER_DAY_BLOCK      - Block threshold in hours/day (default: 24)
# - THRESHOLD_WARN           - Warning threshold in minutes/week (calculated)
# - THRESHOLD_BLOCK          - Block threshold in minutes/week (calculated)
#
# Dependencies: None (base module)
###############################################################################

# configure_read: EOF-safe replacement for interactive `read -p`/`read -rp`.
#
# Interactive menu/prompt loops re-read on invalid input. If stdin is closed or
# non-interactive (e.g. the wizard was backgrounded with redirected output and
# no terminal), a bare `read` returns instantly at EOF and the surrounding loop
# spins forever — pegging a CPU and growing any redirected output WITHOUT bound.
# This once filled the disk with ~465 GB of /tmp files. See CLAUDE.md / AGENTS.md.
#
# On EOF we print CANCELLED to stdout (so `$(...)` callers that check for it see a
# cancel) and exit 2. Every prompt here runs inside a command-substitution
# subshell, so this exits that subshell — callers already treat rc 2 / "CANCELLED"
# as a normal cancel — without bypassing the main shell's EXIT-trap cleanup. A
# normal blank line (Enter) is NOT EOF: `read` succeeds and the caller loops as
# before, so interactive behaviour is unchanged.
configure_read() {
    if read "$@"; then
        return 0
    fi
    local _rc=$?
    if [ "${_rc}" -gt 128 ]; then
        # Timeout (read -t) or interrupting signal, not EOF — let the caller decide.
        return "${_rc}"
    fi
    echo "CANCELLED"
    echo "" >&2
    echo "Input stream closed (EOF); aborting configuration to avoid an endless prompt loop." >&2
    exit 2
}

# Script configuration
SCRIPT_NAME="sleep-warning-configure"
CONFIG_DIR="${HOME}/.config/sleep-warning"
# Enhancement #18: Config file is now in subdirectory
CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
SERVICE_NAME="sleep-warning"
# Platform-aware timer config path (systemd timer or LaunchAgent plist)
if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
    TIMER_FILE="${HOME}/Library/LaunchAgents/com.sleep-warning.plist"
else
    TIMER_FILE="${SYSTEMD_USER_DIR}/sleep-warning.timer"
fi

# Day names array
declare -a DAY_NAMES=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
declare -a DAY_VARS=("SUNDAY" "MONDAY" "TUESDAY" "WEDNESDAY" "THURSDAY" "FRIDAY" "SATURDAY")

# Ensure DAY_NAMES/DAY_VARS are initialized in case a caller clears them unexpectedly.
ensure_day_names() {
    if [ ${#DAY_NAMES[@]} -eq 0 ]; then
        DAY_NAMES=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
    fi
}

ensure_day_vars() {
    if [ ${#DAY_VARS[@]} -eq 0 ]; then
        DAY_VARS=("SUNDAY" "MONDAY" "TUESDAY" "WEDNESDAY" "THURSDAY" "FRIDAY" "SATURDAY")
    fi
}

# Restriction validation thresholds (Enhancement #22)
# These define when to warn or block configuration based on total restricted minutes per week
# Calculated as: hours_per_day × 60 minutes × 7 days
# To change thresholds, modify HOURS_PER_DAY_WARN or HOURS_PER_DAY_BLOCK
HOURS_PER_DAY_WARN=12      # Warning threshold: > 12 hours/day weekly average
HOURS_PER_DAY_BLOCK=16     # Block threshold: > 16 hours/day weekly average
                           # (Mirrors per-day hard cap in lib/daily-caps.sh; comparison
                           #  uses strict ">" so configs that max 16 h every day
                           #  still pass — the per-day cap is the primary enforcer.)
readonly MINUTES_PER_HOUR=60
readonly DAYS_PER_WEEK=7
readonly MINUTES_PER_DAY=$((MINUTES_PER_HOUR * 24))      # 1440 minutes per day
readonly MINUTES_PER_WEEK=$((MINUTES_PER_DAY * DAYS_PER_WEEK))  # 10080 minutes per week
THRESHOLD_WARN=$((HOURS_PER_DAY_WARN * MINUTES_PER_HOUR * DAYS_PER_WEEK))      # Currently 6720
THRESHOLD_BLOCK=$((HOURS_PER_DAY_BLOCK * MINUTES_PER_HOUR * DAYS_PER_WEEK))     # 10080

# Hour range constants (for validation)
readonly MIN_HOUR=0
readonly MAX_HOUR=23

# Time range constants (for minimum display time validation)
readonly MIN_DISPLAY_TIME=0
readonly MAX_DISPLAY_TIME=300
# macOS safety cap for POPUP_MIN_DISPLAY_TIME (see lib/popup-safety.sh).
# Now matches the Linux ceiling (MAX_DISPLAY_TIME) so both platforms allow up to 300s.
readonly DARWIN_MAX_MIN_DISPLAY_TIME="${DARWIN_MAX_MIN_DISPLAY_TIME:-300}"

# Maximum POPUP_MIN_DISPLAY_TIME allowed in the configure wizard (platform-aware).
get_max_min_display_time_limit() {
    if type is_darwin >/dev/null 2>&1 && is_darwin; then
        echo "${DARWIN_MAX_MIN_DISPLAY_TIME}"
        return 0
    fi
    if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
        echo "${DARWIN_MAX_MIN_DISPLAY_TIME}"
        return 0
    fi
    echo "${MAX_DISPLAY_TIME}"
}

# Check interval constants (for validation)
readonly MIN_CHECK_INTERVAL=1
readonly MAX_CHECK_INTERVAL=60

# Session cache for dialog tool detection (invalidated when DIALOG_TOOL changes on Linux).
_CONFIGURE_CACHED_HAS_DIALOG_TOOL=""
_CONFIGURE_CACHED_DIALOG_TOOL=""

configure_invalidate_dialog_tool_cache() {
    _CONFIGURE_CACHED_HAS_DIALOG_TOOL=""
    _CONFIGURE_CACHED_DIALOG_TOOL=""
}

# Refresh main-menu lock-hour status flags from in-memory arrays.
configure_refresh_lock_status_flags() {
    CONFIGURE_LOCK_HOURS_STATUS="[None]"
    CONFIGURE_UNINSTALL_LOCK_HOURS_STATUS="[None]"
    local i lock_value uninstall_lock_value
    for i in 0 1 2 3 4 5 6; do
        if [ -n "${lock_hours_lines[${i}]:-}" ]; then
            lock_value="${lock_hours_lines[${i}]#*=}"
            lock_value="${lock_value//[[:space:]]/}"
            if [ -n "${lock_value}" ]; then
                CONFIGURE_LOCK_HOURS_STATUS="[Configured]"
                break
            fi
        fi
    done
    for i in 0 1 2 3 4 5 6; do
        if [ -n "${uninstall_lock_hours_lines[${i}]:-}" ]; then
            uninstall_lock_value="${uninstall_lock_hours_lines[${i}]#*=}"
            uninstall_lock_value="${uninstall_lock_value//[[:space:]]/}"
            if [ -n "${uninstall_lock_value}" ]; then
                CONFIGURE_UNINSTALL_LOCK_HOURS_STATUS="[Configured]"
                break
            fi
        fi
    done
}

# Weekly grid display cache (invalidated when hour arrays change).
_CONFIGURE_GRID_CACHE_VALID=false
declare -g -a _CONFIGURE_GRID_DAY_NAMES=()
declare -g -a _CONFIGURE_GRID_RESTRICTED=()
declare -g -a _CONFIGURE_GRID_LOCK=()
declare -g -a _CONFIGURE_GRID_UNINSTALL=()
_CONFIGURE_GRID_TABLE_JSON=""
_CONFIGURE_GRID_TABLE_JSON_TITLE=""

configure_invalidate_grid_cache() {
    _CONFIGURE_GRID_CACHE_VALID=false
    _CONFIGURE_GRID_TABLE_JSON=""
    _CONFIGURE_GRID_TABLE_JSON_TITLE=""
}

configure_hours_data_changed() {
    configure_invalidate_grid_cache
    configure_refresh_lock_status_flags
}

# Check if any dialog tool is available
# Requires desktop-environment.sh to be sourced
has_dialog_tool() {
    if [ -n "${_CONFIGURE_CACHED_HAS_DIALOG_TOOL}" ]; then
        [ "${_CONFIGURE_CACHED_HAS_DIALOG_TOOL}" = "yes" ]
        return $?
    fi

    if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
        if command -v osascript >/dev/null 2>&1; then
            _CONFIGURE_CACHED_HAS_DIALOG_TOOL="yes"
        else
            _CONFIGURE_CACHED_HAS_DIALOG_TOOL="no"
        fi
        [ "${_CONFIGURE_CACHED_HAS_DIALOG_TOOL}" = "yes" ]
        return $?
    fi

    if type check_dialog_tool >/dev/null 2>&1 && type detect_display_environment >/dev/null 2>&1; then
        local env_type
        env_type=$(detect_display_environment 2>/dev/null || echo "x11")
        local tool
        tool=$(check_dialog_tool "${env_type}" 2>/dev/null)
        if [ -n "${tool}" ]; then
            _CONFIGURE_CACHED_HAS_DIALOG_TOOL="yes"
            _CONFIGURE_CACHED_DIALOG_TOOL="${tool}"
        else
            _CONFIGURE_CACHED_HAS_DIALOG_TOOL="no"
            _CONFIGURE_CACHED_DIALOG_TOOL=""
        fi
        [ -n "${tool}" ]
        return $?
    fi

    # Fallback: check for any tool directly
    if command -v yad >/dev/null 2>&1 || \
       command -v zenity >/dev/null 2>&1 || \
       command -v kdialog >/dev/null 2>&1; then
        _CONFIGURE_CACHED_HAS_DIALOG_TOOL="yes"
        return 0
    fi
    _CONFIGURE_CACHED_HAS_DIALOG_TOOL="no"
    return 1
}

# Get the currently selected dialog tool
# Respects user preference from DIALOG_TOOL config (Enhancement #25)
# Requires desktop-environment.sh and config.sh to be sourced
get_dialog_tool() {
    if [ -n "${_CONFIGURE_CACHED_DIALOG_TOOL}" ]; then
        echo "${_CONFIGURE_CACHED_DIALOG_TOOL}"
        return 0
    fi

    if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
        if command -v osascript >/dev/null 2>&1; then
            _CONFIGURE_CACHED_DIALOG_TOOL="osascript"
            _CONFIGURE_CACHED_HAS_DIALOG_TOOL="yes"
            echo "osascript"
            return 0
        fi
        _CONFIGURE_CACHED_HAS_DIALOG_TOOL="no"
        return 1
    fi

    if type check_dialog_tool >/dev/null 2>&1 && type detect_display_environment >/dev/null 2>&1; then
        local env_type
        env_type=$(detect_display_environment 2>/dev/null || echo "x11")

        # Prefer in-memory dialog_tool from load_existing_config(); avoid config file grep.
        local user_preference=""
        if [ -n "${dialog_tool:-}" ]; then
            user_preference="${dialog_tool}"
        elif type get_dialog_tool_config >/dev/null 2>&1; then
            user_preference=$(get_dialog_tool_config 2>/dev/null || echo "auto")
        else
            user_preference="auto"
        fi

        local tool
        tool=$(check_dialog_tool "${env_type}" "${user_preference}")
        if [ -n "${tool}" ]; then
            _CONFIGURE_CACHED_DIALOG_TOOL="${tool}"
            _CONFIGURE_CACHED_HAS_DIALOG_TOOL="yes"
            echo "${tool}"
            return 0
        fi
        _CONFIGURE_CACHED_HAS_DIALOG_TOOL="no"
        return 1
    fi

    # Fallback: return first available tool
    if command -v yad >/dev/null 2>&1; then
        _CONFIGURE_CACHED_DIALOG_TOOL="yad"
        echo "yad"
    elif command -v zenity >/dev/null 2>&1; then
        _CONFIGURE_CACHED_DIALOG_TOOL="zenity"
        echo "zenity"
    elif command -v kdialog >/dev/null 2>&1; then
        _CONFIGURE_CACHED_DIALOG_TOOL="kdialog"
        echo "kdialog"
    fi
}

# Check if zenity is available (legacy function for backward compatibility)
# Now uses get_dialog_tool() to check for any dialog tool
has_zenity() {
    local tool
    tool=$(get_dialog_tool)
    [ -n "${tool}" ]
}

# Check if GUI is available
# Now checks both DISPLAY and dialog tool availability
has_gui() {
    if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
        command -v osascript >/dev/null 2>&1 && osascript -e 'return "ok"' >/dev/null 2>&1
        return $?
    fi
    # Check for display
    if [ -z "${DISPLAY}" ] && [ ! -S "/tmp/.X11-unix/X0" ] && ! command -v loginctl >/dev/null 2>&1; then
        return 1
    fi
    # Check for dialog tool
    has_dialog_tool
}

# Convert minutes to systemd OnCalendar format
minutes_to_oncalendar() {
    local minutes="$1"
    
    # Systemd timer format: *:0/N means every N minutes starting from minute 0
    # This works for any N from 1 to 60
    # Examples:
    #   *:0/1  = every minute
    #   *:0/5  = every 5 minutes (at :00, :05, :10, etc.)
    #   *:0/10 = every 10 minutes (at :00, :10, :20, etc.)
    #   *:0/15 = every 15 minutes (at :00, :15, :30, :45)
    echo "*:0/${minutes}"
}

# Format hour to 12-hour format with AM/PM
format_hour_12h() {
    local hour="$1"
    if [ "${hour}" -eq 0 ]; then
        echo "12:00 AM"
    elif [ "${hour}" -eq 12 ]; then
        echo "12:00 PM"
    elif [ "${hour}" -lt 12 ]; then
        echo "${hour}:00 AM"
    else
        echo "$((hour - 12)):00 PM"
    fi
}

# Format a range endpoint as "H:MM AM/PM".
# Accepts a bare hour ("5", "05") or "H:MM" / "HH:MM", the forms parse_config and
# the lock-hour readers return. A bare hour prints ":00", so "5" matches
# format_hour_12h. An end of 24 or 24:00 is midnight and prints "12:00 AM".
# Prints nothing and returns 1 for anything else.
format_endpoint_12h() {
    local part="${1//[[:space:]]/}"
    local hour minute display ampm
    if [[ "${part}" =~ ^([0-9]{1,2})(:([0-9]{2}))?$ ]]; then
        hour=$((10#${BASH_REMATCH[1]}))
        minute=$((10#${BASH_REMATCH[3]:-0}))
    else
        return 1
    fi
    if [[ "${minute}" -gt 59 || "${hour}" -gt 24 || ( "${hour}" -eq 24 && "${minute}" -ne 0 ) ]]; then
        return 1
    fi
    ampm="AM"
    if [[ "${hour}" -ge 12 && "${hour}" -lt 24 ]]; then
        ampm="PM"
    fi
    display=$((hour % 12))
    if [[ "${display}" -eq 0 ]]; then
        display=12
    fi
    printf '%d:%02d %s\n' "${display}" "${minute}" "${ampm}"
}

# Get human-readable description of warning threshold
# Returns: "X hours/day" format
get_threshold_warn_description() {
    echo "${HOURS_PER_DAY_WARN} hours/day"
}

# Get human-readable description of block threshold
# Returns: "24/7" or "X hours/day" format
get_threshold_block_description() {
    if [ "${HOURS_PER_DAY_BLOCK}" -eq 24 ]; then
        echo "24/7"
    else
        echo "${HOURS_PER_DAY_BLOCK} hours/day"
    fi
}

# Convert day number to uppercase day name (for config file)
# Parameters:
#   $1 - day_num (0-6, Sunday=0, Saturday=6)
# Returns: Uppercase day name (e.g., "SUNDAY", "MONDAY")
# Exit codes: 0 on success, 1 on invalid day number
# This function uses the DAY_VARS array for consistency
day_num_to_name_upper() {
    local day_num="$1"
    if [ "${day_num}" -ge 0 ] && [ "${day_num}" -le 6 ]; then
        echo "${DAY_VARS[${day_num}]}"
    else
        return 1
    fi
}

# Convert day number to titlecase day name (for display)
# Parameters:
#   $1 - day_num (0-6, Sunday=0, Saturday=6)
# Returns: Titlecase day name (e.g., "Sunday", "Monday")
# Exit codes: 0 on success, 1 on invalid day number
# This function uses the DAY_NAMES array for consistency
day_num_to_name_title() {
    local day_num="$1"
    if [ "${day_num}" -ge 0 ] && [ "${day_num}" -le 6 ]; then
        echo "${DAY_NAMES[${day_num}]}"
    else
        return 1
    fi
}
