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
    local socket_path
    for socket_path in "${XDG_RUNTIME_DIR}"/wayland-* "${XDG_RUNTIME_DIR}"/gamescope-*; do
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
    if pgrep -x gamescope >/dev/null 2>&1; then
        return 0
    fi
    if [ -n "${GAMESCOPE_SESSION:-}" ] && [ "${GAMESCOPE_SESSION}" != "0" ] && [ "${GAMESCOPE_SESSION}" != "false" ]; then
        return 0
    fi
    return 1
}

# Check whether Experimental Gaming Mode overlay support is enabled in settings/config.
# Strictly honors GAMING_MODE_EXPERIMENTAL_ENABLED=false even if GAMESCOPE_SESSION=1 is set.
is_gaming_mode_enabled() {
    if type get_gaming_mode_experimental_enabled >/dev/null 2>&1; then
        [ "$(get_gaming_mode_experimental_enabled)" = "true" ]
        return $?
    fi
    if [ -n "${GAMING_MODE_EXPERIMENTAL_ENABLED:-}" ]; then
        local env_val
        env_val=$(echo "${GAMING_MODE_EXPERIMENTAL_ENABLED}" | tr -d '[:space:]"'\''' | tr '[:upper:]' '[:lower:]')
        case "${env_val}" in
            true|1|yes) return 0 ;;
            *) return 1 ;;
        esac
    fi
    local cfg_file="${CONFIG_FILE:-${HOME:-}/.config/sleep-warning/config/sleep-warning.conf}"
    if [ -f "${cfg_file}" ]; then
        local cfg_val
        cfg_val=$(grep -E "^[[:space:]]*GAMING_MODE_EXPERIMENTAL_ENABLED=" "${cfg_file}" 2>/dev/null | tail -n1 | cut -d'=' -f2 | tr -d '[:space:]"'\''' | tr '[:upper:]' '[:lower:]')
        if [ -n "${cfg_val}" ]; then
            case "${cfg_val}" in
                true|1|yes) return 0 ;;
                *) return 1 ;;
            esac
        fi
    fi
    if [ -n "${HOME:-}" ] && [ -f "${HOME}/.config/systemd/user/sleep-warning.service.d/mode-gaming.conf" ]; then
        return 0
    fi
    return 1
}

# Resolve the Xwayland display for gamescope overlay windows.
# On SteamOS Gaming Mode, :0 is the Steam UI / overlay Xwayland plane and :1 is the game Xwayland plane.
get_gamescope_x11_display() {
    if [ -S "/tmp/.X11-unix/X0" ]; then
        echo ":0"
        return 0
    fi
    if [ "${DISPLAY:-}" = ":0" ] && is_x11_display_accessible ":0"; then
        echo ":0"
        return 0
    fi
    if [ -n "${DISPLAY:-}" ] && validate_display_format "${DISPLAY}" && is_x11_display_accessible "${DISPLAY}"; then
        echo "${DISPLAY}"
        return 0
    fi
    if [ -S "/tmp/.X11-unix/X1" ]; then
        echo ":1"
        return 0
    fi
    echo ":0"
    return 0
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
                if is_gaming_mode_enabled && is_gamescope_running; then
                    append_display_detection_step "gamescope:process"
                    echo "gamescope"
                    return 0
                fi
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
            if is_gaming_mode_enabled && is_gamescope_running; then
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
            if is_gaming_mode_enabled && is_gamescope_running; then
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
                if is_gaming_mode_enabled && is_gamescope_running; then
                    append_display_detection_step "gamescope:process"
                    DISPLAY_DETECTION_NOTE="Fallback used; see detection path."
                    echo "gamescope"
                    return 0
                fi
                DISPLAY_DETECTION_NOTE="Fallback used; see detection path."
                echo "x11"
                return 0
            fi
            if [ "${session_type}" = "wayland" ]; then
                append_display_detection_step "loginctl:type=wayland"
                if is_gaming_mode_enabled && is_gamescope_running; then
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
    if is_gaming_mode_enabled && is_gamescope_running; then
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
        gamescope)
            local gs_x11
            gs_x11=$(get_gamescope_x11_display)
            if [ -n "${gs_x11}" ]; then
                echo "${gs_x11}"
                return 0
            fi
            if [ -n "${WAYLAND_DISPLAY}" ] && is_wayland_display_accessible "${WAYLAND_DISPLAY}"; then
                echo "${WAYLAND_DISPLAY}"
                return 0
            fi
            ;;
        wayland)
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
        gamescope)
            get_gamescope_x11_display
            return 0
            ;;
        wayland)
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

###############################################################################
# System Mode Detection (Enhancement #4)
#
# These functions detect whether the system is running in Desktop Mode
# (X11/KDE Plasma) vs Gaming Mode (Wayland/gamescope) for systemd service
# configuration purposes.
###############################################################################

# Detect system mode: "desktop" (X11/KDE Plasma) or "gaming" (Wayland/gamescope)
# Returns: "desktop", "gaming", or "unknown" (if detection fails)
# Exit code: 0 if mode detected, 1 if unknown
#
# This function leverages existing display detection functions to determine
# the system mode. Gaming Mode is detected when gamescope is running or when
# Wayland is detected in a SteamOS-like environment. Desktop Mode is detected
# when X11 is the primary display protocol.
detect_system_mode() {
    # Primary detection: Check for gamescope (strongest indicator of Gaming Mode)
    if is_gamescope_running; then
        echo "gaming"
        return 0
    fi
    
    # Secondary detection: Use display environment detection
    local env_type
    env_type=$(detect_display_environment)
    
    case "${env_type}" in
        gamescope)
            # gamescope detected via display environment
            echo "gaming"
            return 0
            ;;
        wayland)
            # Wayland detected - could be Gaming Mode or other Wayland session
            # Check for SteamOS-specific indicators
            # On SteamOS, Gaming Mode typically uses gamescope, but if we detect
            # Wayland without gamescope, we'll treat it as gaming mode if
            # there's no X11 fallback available
            if [ -z "${DISPLAY}" ] || ! validate_display_format "${DISPLAY}"; then
                # No valid X11 display, likely Gaming Mode
                echo "gaming"
                return 0
            fi
            # Has both Wayland and X11 - check which is primary
            # If WAYLAND_DISPLAY is set and accessible, prefer gaming mode
            if [ -n "${WAYLAND_DISPLAY}" ] && is_wayland_display_accessible "${WAYLAND_DISPLAY}"; then
                echo "gaming"
                return 0
            fi
            # Fallback: if we have X11, assume desktop mode
            if [ -n "${DISPLAY}" ] && validate_display_format "${DISPLAY}"; then
                echo "desktop"
                return 0
            fi
            # Ambiguous: Wayland but unclear
            echo "unknown"
            return 1
            ;;
        x11)
            # X11 detected - Desktop Mode (KDE Plasma on SteamOS)
            echo "desktop"
            return 0
            ;;
        *)
            # Unknown or no display detected
            # Try loginctl as fallback
            if command -v loginctl >/dev/null 2>&1; then
                local session_id
                session_id=$(get_loginctl_session_id)
                if [ -n "${session_id}" ]; then
                    local session_type
                    session_type=$(loginctl show-session "${session_id}" -p Type --value 2>/dev/null)
                    case "${session_type}" in
                        x11)
                            echo "desktop"
                            return 0
                            ;;
                        wayland)
                            # Check if gamescope might be running (process check)
                            if pgrep -x gamescope >/dev/null 2>&1; then
                                echo "gaming"
                                return 0
                            fi
                            echo "gaming"
                            return 0
                            ;;
                    esac
                fi
            fi
            echo "unknown"
            return 1
            ;;
    esac
}

# Get display identifier for detected system mode
# Parameters:
#   $1: System mode ("desktop" or "gaming")
# Returns: Display identifier (DISPLAY value for desktop, WAYLAND_DISPLAY for gaming)
#          or "unknown" if identifier cannot be determined
# Exit code: 0 if identifier found, 1 if unknown
#
# This function retrieves the appropriate display identifier for the given
# system mode, which can be used to configure systemd service environment
# variables.
get_mode_display_identifier() {
    local mode="$1"
    
    if [ -z "${mode}" ]; then
        # Auto-detect mode if not provided
        mode=$(detect_system_mode)
    fi
    
    case "${mode}" in
        desktop)
            # For Desktop Mode, return X11 DISPLAY value
            local display_id
            display_id=$(get_display_identifier "x11")
            if [ -n "${display_id}" ] && [ "${display_id}" != "unknown" ]; then
                echo "${display_id}"
                return 0
            fi
            # Fallback: try common X11 display
            if [ -S "/tmp/.X11-unix/X0" ]; then
                echo ":0"
                return 0
            fi
            echo "unknown"
            return 1
            ;;
        gaming)
            # For Gaming Mode, return Wayland display identifier
            local wayland_id
            wayland_id=$(get_display_identifier "wayland")
            if [ -n "${wayland_id}" ] && [ "${wayland_id}" != "unknown" ]; then
                echo "${wayland_id}"
                return 0
            fi
            # Fallback: try to find Wayland socket
            local candidate
            candidate=$(find_wayland_socket_candidate)
            if [ -n "${candidate}" ]; then
                echo "${candidate}"
                return 0
            fi
            echo "unknown"
            return 1
            ;;
        *)
            # Unknown mode
            echo "unknown"
            return 1
            ;;
    esac
}
