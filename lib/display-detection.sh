#!/bin/bash

###############################################################################
# Sleep Warning System - Display Detection Module
#
# This module handles all display environment detection including:
# - X11 display detection and validation
# - Wayland display detection and validation
# - gamescope detection
# - loginctl fallback detection
# - Display environment tracing and debugging
#
# Dependencies: None (standalone module)
#
# Usage: Source this file to access display detection functions
#   source lib/display-detection.sh
###############################################################################

# Display detection trace (populated by detect_display_environment)
DISPLAY_DETECTION_PATH=""
DISPLAY_DETECTION_NOTE=""

# Append a display detection step to the trace
append_display_detection_step() {
    local step="$1"
    if [ -z "${DISPLAY_DETECTION_PATH}" ]; then
        DISPLAY_DETECTION_PATH="${step}"
    else
        DISPLAY_DETECTION_PATH="${DISPLAY_DETECTION_PATH} -> ${step}"
    fi
}

# Validate X11 DISPLAY format (e.g., :0, :1, :0.0)
validate_display_format() {
    local display_value="$1"
    if echo "${display_value}" | grep -qE '^:[0-9]+(\.[0-9]+)?$'; then
        return 0
    fi
    return 1
}

# Check X11 display accessibility (best-effort)
is_x11_display_accessible() {
    local display_value="$1"
    if command -v xdpyinfo >/dev/null 2>&1; then
        DISPLAY="${display_value}" xdpyinfo >/dev/null 2>&1
        return $?
    fi
    if command -v xset >/dev/null 2>&1; then
        DISPLAY="${display_value}" xset q >/dev/null 2>&1
        return $?
    fi
    # If no tool is available, assume accessible
    return 0
}

# Check Wayland socket accessibility
is_wayland_display_accessible() {
    local wayland_value="$1"
    if [ -z "${XDG_RUNTIME_DIR}" ]; then
        return 1
    fi
    if [ -S "${XDG_RUNTIME_DIR}/${wayland_value}" ]; then
        return 0
    fi
    return 1
}

# Find a Wayland socket candidate in XDG_RUNTIME_DIR
find_wayland_socket_candidate() {
    if [ -z "${XDG_RUNTIME_DIR}" ]; then
        return 1
    fi
    local candidate=""
    for socket_path in "${XDG_RUNTIME_DIR}"/wayland-*; do
        if [ -S "${socket_path}" ]; then
            candidate=$(basename "${socket_path}")
            echo "${candidate}"
            return 0
        fi
    done
    return 1
}

# Detect Wayland via compositor helper tools (best-effort)
detect_wayland_with_helpers() {
    local candidate="$1"
    if [ -z "${candidate}" ]; then
        return 1
    fi
    if command -v swaymsg >/dev/null 2>&1; then
        WAYLAND_DISPLAY="${candidate}" swaymsg -t get_version >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            DISPLAY_DETECTION_NOTE="Helper detection used: swaymsg"
            append_display_detection_step "helper:swaymsg"
            return 0
        fi
    fi
    if command -v wlr-randr >/dev/null 2>&1; then
        WAYLAND_DISPLAY="${candidate}" wlr-randr >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            DISPLAY_DETECTION_NOTE="Helper detection used: wlr-randr"
            append_display_detection_step "helper:wlr-randr"
            return 0
        fi
    fi
    if command -v wayland-info >/dev/null 2>&1; then
        WAYLAND_DISPLAY="${candidate}" wayland-info >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            DISPLAY_DETECTION_NOTE="Helper detection used: wayland-info"
            append_display_detection_step "helper:wayland-info"
            return 0
        fi
    fi
    return 1
}

# Detect if gamescope is running (best-effort)
is_gamescope_running() {
    if pgrep -x gamescope >/dev/null 2>&1 || [ -n "${GAMESCOPE_SESSION}" ]; then
        return 0
    fi
    return 1
}

# Get a loginctl session id for the current user (prefer active non-tty)
get_loginctl_session_id() {
    if ! command -v loginctl >/dev/null 2>&1; then
        return 1
    fi
    local fallback_session=""
    local current_user
    current_user=$(whoami)
    while read -r session_id _uid user _seat tty; do
        if [ "${user}" != "${current_user}" ]; then
            continue
        fi
        if echo "${tty}" | grep -qE '^tty'; then
            continue
        fi
        if loginctl show-session "${session_id}" -p Active --value 2>/dev/null | grep -q "^yes$"; then
            echo "${session_id}"
            return 0
        fi
        if [ -z "${fallback_session}" ]; then
            fallback_session="${session_id}"
        fi
    done < <(loginctl list-sessions --no-legend 2>/dev/null)

    if [ -n "${fallback_session}" ]; then
        echo "${fallback_session}"
        return 0
    fi
    return 1
}

# Detect display environment type (X11, Wayland, gamescope)
detect_display_environment() {
    DISPLAY_DETECTION_PATH=""
    DISPLAY_DETECTION_NOTE=""
    local fallback_used=false

    # 1) X11 (DISPLAY)
    if [ -n "${DISPLAY}" ]; then
        if validate_display_format "${DISPLAY}"; then
            if is_x11_display_accessible "${DISPLAY}"; then
                append_display_detection_step "env:DISPLAY"
                echo "x11"
                return 0
            fi
            append_display_detection_step "env:DISPLAY (inaccessible)"
            fallback_used=true
        else
            append_display_detection_step "env:DISPLAY (invalid)"
            fallback_used=true
        fi
    else
        append_display_detection_step "env:DISPLAY (unset)"
        fallback_used=true
    fi

    # 2) Wayland (WAYLAND_DISPLAY + XDG_RUNTIME_DIR)
    if [ -n "${WAYLAND_DISPLAY}" ]; then
        if is_wayland_display_accessible "${WAYLAND_DISPLAY}"; then
            append_display_detection_step "env:WAYLAND_DISPLAY"
            if is_gamescope_running; then
                append_display_detection_step "gamescope:process"
                if [ "${fallback_used}" = "true" ]; then
                    DISPLAY_DETECTION_NOTE="Fallback used; see detection path."
                fi
                echo "gamescope"
                return 0
            fi
            if [ "${fallback_used}" = "true" ]; then
                DISPLAY_DETECTION_NOTE="Fallback used; see detection path."
            fi
            echo "wayland"
            return 0
        fi
        append_display_detection_step "env:WAYLAND_DISPLAY (socket missing)"
        fallback_used=true
    else
        append_display_detection_step "env:WAYLAND_DISPLAY (unset)"
        fallback_used=true
    fi

    # 2b) Wayland helper detection (swaymsg/wlr-randr/wayland-info)
    local helper_candidate
    helper_candidate=$(find_wayland_socket_candidate)
    if [ -n "${helper_candidate}" ]; then
        append_display_detection_step "socket:${helper_candidate}"
        if detect_wayland_with_helpers "${helper_candidate}"; then
            WAYLAND_DISPLAY="${helper_candidate}"
            if is_gamescope_running; then
                append_display_detection_step "gamescope:process"
                if [ "${fallback_used}" = "true" ]; then
                    DISPLAY_DETECTION_NOTE="Fallback used; see detection path. ${DISPLAY_DETECTION_NOTE}"
                fi
                echo "gamescope"
                return 0
            fi
            if [ "${fallback_used}" = "true" ]; then
                DISPLAY_DETECTION_NOTE="Fallback used; see detection path. ${DISPLAY_DETECTION_NOTE}"
            fi
            echo "wayland"
            return 0
        fi
        fallback_used=true
    fi

    # 3) loginctl fallback
    if command -v loginctl >/dev/null 2>&1; then
        local session_id
        session_id=$(get_loginctl_session_id)
        if [ -n "${session_id}" ]; then
            local session_type
            session_type=$(loginctl show-session "${session_id}" -p Type --value 2>/dev/null)
            if [ "${session_type}" = "x11" ]; then
                append_display_detection_step "loginctl:type=x11"
                DISPLAY_DETECTION_NOTE="Fallback used; see detection path."
                echo "x11"
                return 0
            fi
            if [ "${session_type}" = "wayland" ]; then
                append_display_detection_step "loginctl:type=wayland"
                if is_gamescope_running; then
                    append_display_detection_step "gamescope:process"
                    DISPLAY_DETECTION_NOTE="Fallback used; see detection path."
                    echo "gamescope"
                    return 0
                fi
                DISPLAY_DETECTION_NOTE="Fallback used; see detection path."
                echo "wayland"
                return 0
            fi
            append_display_detection_step "loginctl:type=${session_type}"
        else
            append_display_detection_step "loginctl:no-session"
        fi
    else
        append_display_detection_step "loginctl:unavailable"
    fi

    # 4) gamescope fallback (last resort)
    if is_gamescope_running; then
        append_display_detection_step "gamescope:fallback"
        DISPLAY_DETECTION_NOTE="Fallback used; see detection path."
        echo "gamescope"
        return 0
    fi

    DISPLAY_DETECTION_NOTE="No display detected"
    echo "unknown"
    return 1
}

# Get display identifier (DISPLAY or WAYLAND_DISPLAY value)
get_display_identifier() {
    local env_type="$1"
    
    case "${env_type}" in
        x11)
            if [ -n "${DISPLAY}" ] && validate_display_format "${DISPLAY}" && is_x11_display_accessible "${DISPLAY}"; then
                echo "${DISPLAY}"
                return 0
            fi
            ;;
        wayland|gamescope)
            if [ -n "${WAYLAND_DISPLAY}" ] && is_wayland_display_accessible "${WAYLAND_DISPLAY}"; then
                echo "${WAYLAND_DISPLAY}"
                return 0
            fi
            ;;
    esac
    
    # Fallback: try to get from loginctl
    if command -v loginctl >/dev/null 2>&1; then
        local session_id
        session_id=$(get_loginctl_session_id)
        if [ -n "${session_id}" ] && [ "${env_type}" = "x11" ]; then
            local display_env
            display_env=$(loginctl show-session "${session_id}" -p Display --value 2>/dev/null)
            if [ -n "${display_env}" ] && validate_display_format "${display_env}"; then
                echo "${display_env}"
                return 0
            fi
        fi
    fi
    
    # Last resort for X11
    if [ "${env_type}" = "x11" ] && [ -S "/tmp/.X11-unix/X0" ]; then
        echo ":0"
        return 0
    fi
    
    echo "unknown"
    return 1
}

# Get DISPLAY environment variable, with fallback (enhanced for Wayland and gamescope)
get_display() {
    local env_type="$1"
    if [ -z "${env_type}" ]; then
        env_type=$(detect_display_environment)
    fi
    
    case "${env_type}" in
        x11)
            local display_id
            display_id=$(get_display_identifier "x11")
            if [ -n "${display_id}" ] && [ "${display_id}" != "unknown" ]; then
                echo "${display_id}"
                return 0
            fi
            ;;
        wayland|gamescope)
            local wayland_id
            wayland_id=$(get_display_identifier "wayland")
            if [ -n "${wayland_id}" ] && [ "${wayland_id}" != "unknown" ]; then
                # For Wayland, try to find X11 display as fallback for tools that need it
                if [ -S "/tmp/.X11-unix/X0" ]; then
                    echo ":0"
                    return 0
                fi
                # Return wayland display identifier (will be used to set WAYLAND_DISPLAY in show_warning)
                echo "${wayland_id}"
                return 0
            fi
            ;;
    esac
    
    # Last resort: try common X11 display values
    if [ -S "/tmp/.X11-unix/X0" ]; then
        echo ":0"
        return 0
    fi
    
    return 1
}
