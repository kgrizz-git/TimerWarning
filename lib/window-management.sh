#!/bin/bash

###############################################################################
# Sleep Warning System - Window Management Module
#
# This module handles all window manipulation functionality including:
# - Window manager tool detection (wmctrl/xdotool)
# - Window state detection (X11 and Wayland)
# - Window manipulation (keep on top, make immovable, etc.)
# - Popup geometry calculation
#
# Dependencies: config.sh (for get_popup_immovable())
#
# Usage: Source this file after config.sh
#   source lib/config.sh
#   source lib/window-management.sh
###############################################################################

# Check if window manager tools are available
check_window_tools() {
    if command -v wmctrl >/dev/null 2>&1; then
        echo "wmctrl"
        return 0
    elif command -v xdotool >/dev/null 2>&1; then
        echo "xdotool"
        return 0
    else
        return 1
    fi
}

# Detect active window state (X11)
detect_window_state_x11() {
    local tool="$1"
    local state="unknown"
    local window_title=""
    
    # Use xdotool if available (works with both wmctrl and xdotool tool selection)
    if command -v xdotool >/dev/null 2>&1; then
        # Get active window ID
        local active_id
        active_id=$(xdotool getactivewindow 2>/dev/null)
        
        if [ -n "${active_id}" ]; then
            # Get window title
            window_title=$(xdotool getwindowname "${active_id}" 2>/dev/null)
            
            # Check window state using xprop (most reliable)
            if command -v xprop >/dev/null 2>&1; then
                local net_wm_state
                net_wm_state=$(xprop -id "${active_id}" _NET_WM_STATE 2>/dev/null)
                
                if echo "${net_wm_state}" | grep -q "_NET_WM_STATE_FULLSCREEN"; then
                    state="fullscreen"
                elif echo "${net_wm_state}" | grep -q "_NET_WM_STATE_MAXIMIZED_HORZ" && echo "${net_wm_state}" | grep -q "_NET_WM_STATE_MAXIMIZED_VERT"; then
                    state="maximized"
                else
                    state="windowed"
                fi
            else
                # Fallback: check window geometry (less reliable)
                local geometry
                geometry=$(xdotool getwindowgeometry "${active_id}" 2>/dev/null)
                # Without xprop, we can't reliably detect fullscreen
                state="windowed (detection limited)"
            fi
        fi
    elif [ "${tool}" = "wmctrl" ] && command -v wmctrl >/dev/null 2>&1; then
        # Fallback to wmctrl if xdotool not available
        # Get active window using wmctrl (limited)
        local active_list
        active_list=$(wmctrl -l 2>/dev/null | head -n1)
        if [ -n "${active_list}" ]; then
            # Extract window title (last field)
            window_title=$(echo "${active_list}" | awk '{$1=$2=$3=""; print $0}' | sed 's/^[[:space:]]*//')
            # wmctrl alone can't reliably detect fullscreen state
            state="windowed (detection limited)"
        fi
    fi
    
    # Output format: state|title
    echo "${state}|${window_title}"
}

# Detect active window state (Wayland)
detect_window_state_wayland() {
    local env_type="$1"
    local state="unknown"
    local window_title=""
    
    # Wayland window state detection is limited
    if [ "${env_type}" = "gamescope" ]; then
        # gamescope-specific: check if a game is running
        if pgrep -x gamescope >/dev/null 2>&1; then
            # Try to detect if we're in a game (limited detection)
            # Most games in gamescope will be fullscreen
            state="fullscreen (gamescope)"
            window_title="gamescope session"
        else
            state="unknown (gamescope)"
        fi
    else
        # Try swaymsg if available (Sway/i3)
        if command -v swaymsg >/dev/null 2>&1; then
            local focused
            focused=$(swaymsg -t get_tree | grep -A 10 '"focused": true' 2>/dev/null | head -n20)
            if [ -n "${focused}" ]; then
                # Extract window title if available
                window_title=$(echo "${focused}" | grep -o '"name": "[^"]*"' 2>/dev/null | head -n1 | cut -d'"' -f4)
                # Check if fullscreen
                local fullscreen_mode
                fullscreen_mode=$(echo "${focused}" | grep -o '"fullscreen_mode": [0-9]*' 2>/dev/null | cut -d' ' -f2)
                if [ -n "${fullscreen_mode}" ] && [ "${fullscreen_mode}" != "0" ]; then
                    state="fullscreen"
                else
                    state="windowed"
                fi
            fi
        else
            # Limited detection on Wayland without swaymsg
            state="unknown (wayland - limited detection)"
        fi
    fi
    
    # Output format: state|title
    echo "${state}|${window_title}"
}

# Detect window state (wrapper function)
detect_window_state() {
    local env_type="$1"
    local window_tool="$2"
    
    case "${env_type}" in
        x11)
            if [ -n "${window_tool}" ]; then
                detect_window_state_x11 "${window_tool}"
            else
                echo "unknown|"
            fi
            ;;
        wayland|gamescope)
            detect_window_state_wayland "${env_type}"
            ;;
        *)
            echo "unknown|"
            ;;
    esac
}

# Make window unclosable and unminimizable using window manager tools
make_window_unclosable() {
    local window_title="$1"
    local tool="$2"
    local timeout="$3"

    # gamescope composites via STEAM_OVERLAY atoms, not wmctrl/xdotool loops.
    if [ "${env_type:-}" = "gamescope" ]; then
        return 0
    fi
    
    if [ -z "${tool}" ] || [ "${timeout}" -eq 0 ]; then
        return 0
    fi
    
    # Check if immovable window feature is enabled
    local popup_immovable
    popup_immovable=$(get_popup_immovable)
    
    # Wait a moment for window to appear
    sleep 0.5
    
    case "${tool}" in
        wmctrl)
            # Find window by title
            local window_id
            window_id=$(wmctrl -l | grep "${window_title}" | head -n1 | awk '{print $1}')
            
            if [ -n "${window_id}" ]; then
                # Make window sticky (stays on all desktops)
                wmctrl -i -r "${window_id}" -b add,sticky 2>/dev/null
                # Keep window on top (xprop commands disabled - they cause windows to close on KDE)
                # if command -v xprop >/dev/null 2>&1; then
                #     xprop -id "${window_id}" -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_ABOVE _NET_WM_STATE_STAYS_ON_TOP 2>/dev/null
                # fi
                wmctrl -i -r "${window_id}" -b add,above 2>/dev/null
                wmctrl -i -a "${window_id}" 2>/dev/null  # Also activate/raise
                
                # If immovable is enabled, start position monitoring
                if [ "${popup_immovable}" = "true" ]; then
                    make_window_immovable "${window_id}" "${tool}" "${timeout}" &
                fi
            fi
            ;;
        xdotool)
            # Find window by title
            local window_id
            window_id=$(xdotool search --name "${window_title}" 2>/dev/null | head -n1)
            
            if [ -n "${window_id}" ]; then
                # Keep window on top (xprop commands disabled - they cause windows to close on KDE)
                # Set window type to DIALOG
                # xprop -id "${window_id}" -f _NET_WM_WINDOW_TYPE 32a -set _NET_WM_WINDOW_TYPE _NET_WM_WINDOW_TYPE_DIALOG 2>/dev/null
                # Set window state to ABOVE and STAYS_ON_TOP (this works on KDE!)
                # xprop -id "${window_id}" -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_ABOVE _NET_WM_STATE_STAYS_ON_TOP 2>/dev/null
                # Also raise and focus
                xdotool windowraise "${window_id}" 2>/dev/null
                xdotool windowfocus "${window_id}" 2>/dev/null
                xdotool windowraise "${window_id}" 2>/dev/null
                
                # If immovable is enabled, start position monitoring
                if [ "${popup_immovable}" = "true" ]; then
                    make_window_immovable "${window_id}" "${tool}" "${timeout}" &
                fi
            fi
            ;;
    esac
}

# Last successful lookup path for find_window_id_for_popup (net_client_list|xdotool_pid|
# xdotool_name|wmctrl_name|xwininfo_tree). Empty if none found. Callers may read this
# after a successful find for diagnostics (gamescope overlay logging).
FIND_WINDOW_LOOKUP_PATH=""

# Keep pre-spawn geometry queries bounded even without GNU timeout (macOS).
# A subshell owns the probe and its cleanup; no background timer can leak.
_gamescope_root_info() (
    local output probe_pid="" rc=0 attempt=0
    output=$(mktemp "${TMPDIR:-/tmp}/sleep-warning-root.XXXXXX") || return 1
    trap 'if [ -n "${probe_pid}" ]; then kill -KILL "${probe_pid}" 2>/dev/null || true; wait "${probe_pid}" 2>/dev/null || true; fi; rm -f "${output}"' EXIT
    trap 'exit 1' TERM INT
    xwininfo -root >"${output}" 2>/dev/null &
    probe_pid=$!
    while kill -0 "${probe_pid}" 2>/dev/null; do
        if [ "${attempt}" -ge 20 ]; then
            return 1
        fi
        sleep 0.1
        attempt=$((attempt + 1))
    done
    wait "${probe_pid}" || rc=$?
    probe_pid=""
    [ "${rc}" -eq 0 ] || return 1
    cat "${output}"
)

# Read X11 root window size for the current DISPLAY ("WIDTH HEIGHT").
# Used for gamescope interactive overlay sizing (nested :0 canvas, not the TV panel).
# Returns 0 on success, 1 if xwininfo missing or sizes are non-numeric.
gamescope_get_x11_root_size() {
    if ! command -v xwininfo >/dev/null 2>&1; then
        return 1
    fi
    local info width height
    info=$(_gamescope_root_info) || return 1
    width=$(printf '%s\n' "${info}" | awk -F: '/Width:/ {gsub(/ /,"",$2); print $2; exit}')
    height=$(printf '%s\n' "${info}" | awk -F: '/Height:/ {gsub(/ /,"",$2); print $2; exit}')
    if [[ "${width}" =~ ^[0-9]+$ ]] && [[ "${height}" =~ ^[0-9]+$ ]] && [ "${width}" -gt 0 ] && [ "${height}" -gt 0 ]; then
        echo "${width} ${height}"
        return 0
    fi
    return 1
}

# Compute gamescope interactive dialog size: full root width and height at least
# two thirds of the root (capped at root_h). gamescope 3.16.23 treats
# STEAM_OVERLAY windows with nWidth <= 1200 as notifications (visible, no input).
# Full canvas width keeps the width-axis fit-scale at about 1.0. The tall floor
# keeps the bottom button row inside the pointer band seen on device.
# Parameters:
#   $1: fallback width (used only if root size unavailable)
#   $2: fallback height (preferred height; raised to at least root_h*2/3)
# Prints "WIDTH HEIGHT". Returns 0 when root size was read, 1 when falling back.
gamescope_interactive_dialog_dimensions() {
    local fallback_w="${1:-400}"
    local fallback_h="${2:-250}"
    local root_wh root_w root_h width height floor_h

    if ! [[ "${fallback_w}" =~ ^[0-9]+$ ]]; then
        fallback_w=400
    fi
    if ! [[ "${fallback_h}" =~ ^[0-9]+$ ]]; then
        fallback_h=250
    fi

    root_wh=$(gamescope_get_x11_root_size) || {
        echo "${fallback_w} ${fallback_h}"
        return 1
    }
    root_w=$(echo "${root_wh}" | awk '{print $1}')
    root_h=$(echo "${root_wh}" | awk '{print $2}')

    # Full nested/canvas width (never TV-native sizing; caller uses gamescope DISPLAY).
    # gamescope 3.16.23 needs nWidth > 1200 for interactive overlay; if root is narrower,
    # last resort is 1201 (may clip — better than silent notification classification).
    width="${root_w}"
    if [ "${root_w}" -le 1200 ]; then
        width=1201
        if type log_to_file >/dev/null 2>&1; then
            log_to_file "WARNING" "gamescope root width ${root_w} <= 1200; using width 1201 last-resort for interactive overlay (may clip)"
        fi
    fi

    # Height is max(fallback, root_h*2/3). A floor under 200px uses 200 when
    # the canvas allows, then the result is capped at root_h.
    floor_h=$((root_h * 2 / 3))
    if [ "${floor_h}" -lt 200 ] && [ "${root_h}" -ge 200 ]; then
        floor_h=200
    elif [ "${floor_h}" -lt 200 ]; then
        floor_h="${root_h}"
    fi
    height="${fallback_h}"
    if [ "${height}" -lt "${floor_h}" ]; then
        height="${floor_h}"
    fi
    if [ "${height}" -gt "${root_h}" ]; then
        height="${root_h}"
    fi

    echo "${width} ${height}"
    return 0
}

# Find X11 window ID for a popup dialog using _NET_WM_PID (xprop), xdotool --pid,
# wmctrl/xdotool title, or xwininfo. Sets FIND_WINDOW_LOOKUP_PATH on success.
# Parameters:
#   $1: window_title
#   $2: tool (wmctrl, xdotool, or empty)
#   $3: popup_pid (optional numeric PID)
find_window_id_for_popup() {
    local window_title="$1"
    local tool="${2:-}"
    local target_pid="${3:-}"
    local wid=""
    FIND_WINDOW_LOOKUP_PATH=""
    FIND_WINDOW_PID_VISIBLE_COUNT=""

    # 1) Prefer PID match via xprop _NET_CLIENT_LIST -> _NET_WM_PID (works without wmctrl/xdotool)
    #    Note: gamescope often has no usable _NET_CLIENT_LIST; then we fall through.
    if [ -n "${target_pid}" ] && [[ "${target_pid}" =~ ^[0-9]+$ ]] && command -v xprop >/dev/null 2>&1; then
        local client_list
        client_list=$(xprop -root _NET_CLIENT_LIST 2>/dev/null || true)
        # "not found" has no '#'. cut would then pass every word to xprop -id.
        if [[ "${client_list}" == *'#'* ]]; then
            client_list=$(printf '%s\n' "${client_list}" | cut -d'#' -f2 | tr ',' ' ')
        else
            client_list=""
        fi
        local candidate_wid wpid
        for candidate_wid in ${client_list}; do
            [[ "${candidate_wid}" =~ ^0x[0-9a-fA-F]+$ ]] || continue
            wpid=$(xprop -id "${candidate_wid}" _NET_WM_PID 2>/dev/null | awk -F'=' '{print $2}' | tr -d '[:space:]')
            if [ "${wpid}" = "${target_pid}" ]; then
                FIND_WINDOW_LOOKUP_PATH="net_client_list"
                echo "${candidate_wid}"
                return 0
            fi
        done
    fi

    # 1b) xdotool by PID (reliable under gamescope when _NET_CLIENT_LIST is empty).
    # If multiple IDs share the PID, prefer a title match; otherwise fall through to name search.
    # --onlyvisible skips the never-mapped GTK/Qt client-leader window, which also carries
    # _NET_WM_PID and is created before the dialog toplevel (tagging it would be a no-op).
    if [ -n "${target_pid}" ] && [[ "${target_pid}" =~ ^[0-9]+$ ]] && command -v xdotool >/dev/null 2>&1; then
        local pid_wids pid_count pid_wid matched_wid
        pid_wids=$(xdotool search --onlyvisible --pid "${target_pid}" 2>/dev/null || true)
        pid_count=0
        matched_wid=""
        for pid_wid in ${pid_wids}; do
            pid_count=$((pid_count + 1))
            if [ -n "${window_title}" ] && command -v xdotool >/dev/null 2>&1; then
                local pid_name
                pid_name=$(xdotool getwindowname "${pid_wid}" 2>/dev/null || true)
                if [ "${pid_name}" = "${window_title}" ]; then
                    matched_wid="${pid_wid}"
                fi
            fi
        done
        FIND_WINDOW_PID_VISIBLE_COUNT="${pid_count}"
        if [ -n "${matched_wid}" ]; then
            FIND_WINDOW_LOOKUP_PATH="xdotool_pid"
            echo "${matched_wid}"
            return 0
        fi
        if [ "${pid_count}" -eq 1 ]; then
            FIND_WINDOW_LOOKUP_PATH="xdotool_pid"
            echo "${pid_wids}" | head -n1
            return 0
        fi
        # Multiple PID hits with no title match: fall through to name / xwininfo.
    fi

    # 2) Fallback to wmctrl / xdotool title match
    case "${tool}" in
        wmctrl)
            if command -v wmctrl >/dev/null 2>&1 && [ -n "${window_title}" ]; then
                wid=$(wmctrl -l 2>/dev/null | grep -F "${window_title}" | head -n1 | awk '{print $1}')
                if [ -n "${wid}" ]; then
                    FIND_WINDOW_LOOKUP_PATH="wmctrl_name"
                fi
            fi
            ;;
        xdotool)
            if command -v xdotool >/dev/null 2>&1 && [ -n "${window_title}" ]; then
                wid=$(xdotool search --name "${window_title}" 2>/dev/null | head -n1)
                if [ -n "${wid}" ]; then
                    FIND_WINDOW_LOOKUP_PATH="xdotool_name"
                fi
            fi
            ;;
    esac
    if [ -n "${wid}" ]; then
        echo "${wid}"
        return 0
    fi

    # 3) Fallback to xwininfo title match (part of standard X11 utilities on SteamOS)
    if command -v xwininfo >/dev/null 2>&1 && [ -n "${window_title}" ]; then
        wid=$(xwininfo -root -tree 2>/dev/null | grep -F "\"${window_title}\"" | head -n1 | awk '{print $1}')
        if [ -n "${wid}" ]; then
            FIND_WINDOW_LOOKUP_PATH="xwininfo_tree"
            echo "${wid}"
            return 0
        fi
    fi

    FIND_WINDOW_LOOKUP_PATH=""
    return 1
}

# Apply SteamOS Gaming Mode (gamescope) overlay atoms so the X11 dialog is composited
# above fullscreen games and receives controller/touch input focus.
# Sets STEAM_OVERLAY=1 and STEAM_INPUT_FOCUS=1 (mode 1, not 2 — keep keyboard on dialog).
# Optionally sets opaque _NET_WM_WINDOW_OPACITY to reduce Steam overlay opacity ties.
# Logs lookup path, geometry, and atom read-back once per window ID.
# Parameters:
#   $1: window_title
#   $2: tool (wmctrl/xdotool or empty)
#   $3: popup_pid (optional numeric PID)
#
# gamescope 3.16.23 (steamcompmgr.cpp): classification uses nWidth > 1200 && opacity >= maxOpacity
# for overlayWindow (else notificationWindow). Input pick:
#   if (VirtualConnectorIsSingleOutput() && overlayWindow && overlayWindow->inputFocusMode)
#       inputFocusWindow = overlayWindow; else inputFocusWindow = focusWindow (the game).
# See gamescope_interactive_dialog_dimensions for full-width sizing.
apply_gamescope_overlay_atoms() {
    local window_title="$1"
    local tool="${2:-}"
    local target_pid="${3:-}"

    if ! command -v xprop >/dev/null 2>&1; then
        if type log_to_file >/dev/null 2>&1; then
            log_to_file "WARNING" "xprop not available; cannot set STEAM_OVERLAY atoms for gamescope"
        fi
        _gamescope_debug_after_apply "" "" "${target_pid}"
        return 1
    fi

    local max_attempts=30
    local attempt=0
    local window_id=""
    local lookup_path=""
    # Temp file keeps FIND_WINDOW_LOOKUP_PATH out of a command-substitution subshell.
    local _wid_tmp
    _wid_tmp=$(mktemp) || return 1

    while [ "${attempt}" -lt "${max_attempts}" ]; do
        FIND_WINDOW_LOOKUP_PATH=""
        if find_window_id_for_popup "${window_title}" "${tool}" "${target_pid}" > "${_wid_tmp}"; then
            window_id=$(tr -d '[:space:]' < "${_wid_tmp}")
            lookup_path="${FIND_WINDOW_LOOKUP_PATH:-}"
            if [ -n "${window_id}" ]; then
                break
            fi
        fi
        window_id=""
        if [ -n "${target_pid}" ] && [[ "${target_pid}" =~ ^[0-9]+$ ]] && ! kill -0 "${target_pid}" 2>/dev/null; then
            FIND_WINDOW_LOOKUP_PATH=""
            if find_window_id_for_popup "${window_title}" "${tool}" "${target_pid}" > "${_wid_tmp}"; then
                window_id=$(tr -d '[:space:]' < "${_wid_tmp}")
                lookup_path="${FIND_WINDOW_LOOKUP_PATH:-}"
            fi
            break
        fi
        sleep 0.1
        attempt=$((attempt + 1))
    done
    rm -f "${_wid_tmp}"

    if [ -z "${window_id}" ]; then
        if type log_to_file >/dev/null 2>&1; then
            log_to_file "WARNING" "Could not find X11 window ID for gamescope overlay (title: ${window_title}, PID: ${target_pid:-none})"
        fi
        _gamescope_debug_after_apply "" "${lookup_path}" "${target_pid}"
        return 1
    fi

    local overlay_ok=true
    if ! xprop -id "${window_id}" -f STEAM_OVERLAY 32c -set STEAM_OVERLAY 1 2>/dev/null; then
        overlay_ok=false
    fi
    # STEAM_INPUT_FOCUS=1 (not 2): mode 2 routes keyboard back to the game on 3.16.23.
    if ! xprop -id "${window_id}" -f STEAM_INPUT_FOCUS 32c -set STEAM_INPUT_FOCUS 1 2>/dev/null; then
        overlay_ok=false
    fi
    # Best-effort opaque opacity so we win/tie Steam overlay opacity contests.
    xprop -id "${window_id}" -f _NET_WM_WINDOW_OPACITY 32c -set _NET_WM_WINDOW_OPACITY 0xffffffff 2>/dev/null || true

    if [ "${overlay_ok}" != "true" ]; then
        if type log_to_file >/dev/null 2>&1; then
            log_to_file "WARNING" "Failed to apply gamescope STEAM_OVERLAY / STEAM_INPUT_FOCUS atoms to window ${window_id} (PID: ${target_pid:-unknown})"
        fi
        _gamescope_debug_after_apply "${window_id}" "${lookup_path}" "${target_pid}"
        return 1
    fi

    # Log once per window. The background poll calls this every couple of seconds.
    if [ "${GAMESCOPE_ATOMS_LOGGED_WID:-}" != "${window_id}" ]; then
        GAMESCOPE_ATOMS_LOGGED_WID="${window_id}"
        if type log_to_file >/dev/null 2>&1; then
            local geom_w="" geom_h="" rb_overlay="" rb_focus=""
            if command -v xwininfo >/dev/null 2>&1; then
                local winfo
                winfo=$(xwininfo -id "${window_id}" 2>/dev/null || true)
                geom_w=$(printf '%s\n' "${winfo}" | awk -F: '/Width:/ {gsub(/ /,"",$2); print $2; exit}')
                geom_h=$(printf '%s\n' "${winfo}" | awk -F: '/Height:/ {gsub(/ /,"",$2); print $2; exit}')
            fi
            rb_overlay=$(xprop -id "${window_id}" STEAM_OVERLAY 2>/dev/null | awk -F'=' '{gsub(/ /,"",$2); print $2}' || true)
            rb_focus=$(xprop -id "${window_id}" STEAM_INPUT_FOCUS 2>/dev/null | awk -F'=' '{gsub(/ /,"",$2); print $2}' || true)
            log_to_file "INFO" "Applied gamescope STEAM_OVERLAY=1 and STEAM_INPUT_FOCUS=1 to window ${window_id} (PID: ${target_pid:-unknown}, lookup: ${lookup_path:-unknown}, geometry: ${geom_w:-?}x${geom_h:-?}, readback overlay=${rb_overlay:-?} focus=${rb_focus:-?})"
        fi
    fi
    # Log-only. The gate inside this call skips the 2s atom poll.
    _gamescope_debug_after_apply "${window_id}" "${lookup_path}" "${target_pid}"
    return 0
}

# Keep window on top of other windows (with retries for reliability)
keep_window_on_top() {
    local window_title="$1"
    local tool="$2"
    local max_attempts="${3:-5}"  # Default 5 attempts if not specified
    local target_pid="${4:-${popup_pid:-}}"

    # Atom polling for gamescope is started separately in the background.
    # Doing it here blocks the popup loop for up to 3 seconds per attempt and
    # repeats from the 0.5s stay-on-top timer whenever wmctrl or xdotool exists.
    if [ "${env_type:-}" = "gamescope" ]; then
        return 0
    fi
    
    if [ -z "${tool}" ]; then
        return 0
    fi
    
    local attempt=0
    local window_id=""
    
    # Try to find window with retries
    while [ "${attempt}" -lt "${max_attempts}" ] && [ -z "${window_id}" ]; do
        sleep 0.2
        case "${tool}" in
            wmctrl)
                window_id=$(wmctrl -l | grep "${window_title}" | head -n1 | awk '{print $1}')
                ;;
            xdotool)
                window_id=$(xdotool search --name "${window_title}" 2>/dev/null | head -n1)
                ;;
        esac
        attempt=$((attempt + 1))
    done
    
    if [ -z "${window_id}" ]; then
        return 0  # Window not found, can't set on top
    fi
    
    # Try xprop approach for setting window properties (works well with zenity on KDE)
    # Use multiple state atoms for better compatibility
    if command -v xprop >/dev/null 2>&1; then
        # Verify window exists before setting properties
        if xprop -id "${window_id}" _NET_WM_NAME >/dev/null 2>&1; then
            # Set the ABOVE state using xprop (more reliable than wmctrl for some dialogs)
            xprop -id "${window_id}" -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_ABOVE 2>/dev/null || true
        fi
    fi
    
    # Also apply standard methods for compatibility with other window managers
    case "${tool}" in
        wmctrl)
            # Set above flag
            wmctrl -i -r "${window_id}" -b add,above 2>/dev/null
            # Activate and raise the window
            wmctrl -i -a "${window_id}" 2>/dev/null
            ;;
        xdotool)
            # Raise and focus the window multiple times for better reliability
            xdotool windowraise "${window_id}" 2>/dev/null
            xdotool windowfocus "${window_id}" 2>/dev/null
            sleep 0.1
            xdotool windowraise "${window_id}" 2>/dev/null
            xdotool windowactivate "${window_id}" 2>/dev/null
            ;;
    esac
}

# Keep window on top periodically (runs in background)
keep_window_on_top_periodic() {
    local window_title="$1"
    local tool="$2"
    local popup_pid="$3"
    local duration="${4:-300}"  # Default 5 minutes if not specified
    
    if [ -z "${tool}" ]; then
        return 0
    fi
    
    # Check every 0.5 seconds to ensure window stays on top (more aggressive)
    local elapsed=0
    local check_count=$((duration * 2))  # Check twice per second
    local check_num=0
    
    while [ "${check_num}" -lt "${check_count}" ]; do
        # Check if popup process is still running
        if [ -n "${popup_pid}" ] && ! kill -0 "${popup_pid}" 2>/dev/null; then
            # Process ended, stop monitoring
            break
        fi
        
        # Apply stay-on-top every 0.5 seconds
        keep_window_on_top "${window_title}" "${tool}" 2  # Quick retry (2 attempts)
        
        sleep 0.5
        check_num=$((check_num + 1))
    done
}

# Make window immovable by monitoring and restoring position (Method 4)
make_window_immovable() {
    local window_id="$1"
    local tool="$2"
    local timeout="$3"
    
    if [ -z "${window_id}" ] || [ -z "${tool}" ] || [ "${timeout}" -eq 0 ]; then
        return 0
    fi
    
    # Get initial position
    local initial_x initial_y
    case "${tool}" in
        xdotool)
            initial_x=$(xdotool getwindowgeometry "${window_id}" 2>/dev/null | grep Position | awk '{print $2}' | cut -d',' -f1)
            initial_y=$(xdotool getwindowgeometry "${window_id}" 2>/dev/null | grep Position | awk '{print $2}' | cut -d',' -f2)
            ;;
        wmctrl)
            local geometry
            geometry=$(wmctrl -lG 2>/dev/null | grep "${window_id}" | awk '{print $3, $4}')
            initial_x=$(echo "${geometry}" | awk '{print $1}')
            initial_y=$(echo "${geometry}" | awk '{print $2}')
            ;;
    esac
    
    if [ -z "${initial_x}" ] || [ -z "${initial_y}" ]; then
        # Could not get initial position, skip monitoring
        return 0
    fi
    
    # Monitor position for the duration of the timeout
    # Check 5 times per second (every 200ms)
    local check_count=$((timeout * 5))
    local check_num=0
    
    while [ "${check_num}" -lt "${check_count}" ]; do
        sleep 0.2
        
        # Check current position
        local current_x current_y
        case "${tool}" in
            xdotool)
                current_x=$(xdotool getwindowgeometry "${window_id}" 2>/dev/null | grep Position | awk '{print $2}' | cut -d',' -f1)
                current_y=$(xdotool getwindowgeometry "${window_id}" 2>/dev/null | grep Position | awk '{print $2}' | cut -d',' -f2)
                ;;
            wmctrl)
                local geometry
                geometry=$(wmctrl -lG 2>/dev/null | grep "${window_id}" | awk '{print $3, $4}')
                current_x=$(echo "${geometry}" | awk '{print $1}')
                current_y=$(echo "${geometry}" | awk '{print $2}')
                ;;
        esac
        
        # If position changed, restore it
        if [ -n "${current_x}" ] && [ -n "${current_y}" ]; then
            if [ "${current_x}" != "${initial_x}" ] || [ "${current_y}" != "${initial_y}" ]; then
                # Position changed, restore it
                case "${tool}" in
                    xdotool)
                        xdotool windowmove "${window_id}" "${initial_x}" "${initial_y}" 2>/dev/null
                        ;;
                    wmctrl)
                        wmctrl -i -r "${window_id}" -e 0,"${initial_x}","${initial_y}",-1,-1 2>/dev/null
                        ;;
                esac
            fi
        fi
        
        check_num=$((check_num + 1))
    done
}

# Re-enable window closing after timeout
reenable_window_closing() {
    local window_title="$1"
    local tool="$2"
    
    if [ -z "${tool}" ]; then
        return 0
    fi
    
    case "${tool}" in
        wmctrl)
            local window_id
            window_id=$(wmctrl -l | grep "${window_title}" | head -n1 | awk '{print $1}')
            if [ -n "${window_id}" ]; then
                wmctrl -i -r "${window_id}" -b remove,sticky 2>/dev/null
            fi
            ;;
        xdotool)
            local window_id
            window_id=$(xdotool search --name "${window_title}" 2>/dev/null | head -n1)
            if [ -n "${window_id}" ]; then
                xdotool set_window --overrideredirect 0 "${window_id}" 2>/dev/null
            fi
            ;;
    esac
}

# Calculate popup position coordinates (for yad --geometry or window repositioning)
# Supports only center and top-left positions (simplified for maintainability)
# Returns format: "WIDTHxHEIGHT+X+Y" for yad geometry or "X Y" if only_coords is true
calculate_popup_geometry() {
    local position="$1"
    local width="$2"
    local height="$3"
    local only_coords="${4:-false}"  # If true, only return "X Y" instead of full geometry

    # Gamescope top-left is the nested canvas origin. Desktop margins can push a
    # full-width window off-screen. Skip the screen probe (unset under set -u).
    if [ "${env_type:-}" = "gamescope" ] && [ "${position}" = "top-left" ]; then
        if [ "${only_coords}" = "true" ]; then
            echo "0 0"
        else
            echo "${width}x${height}+0+0"
        fi
        return 0
    fi

    # Get screen dimensions (requires xrandr or xdpyinfo).
    # Empty defaults let the 1920x1080 fallback run under set -u.
    local screen_width="" screen_height=""
    if command -v xrandr >/dev/null 2>&1; then
        local screen_info geometry
        
        # Try to get primary display first (usually the main screen)
        screen_info=$(xrandr --current 2>/dev/null | grep -E " connected primary " | head -n1)
        if [ -z "${screen_info}" ]; then
            # No primary display, get first connected display
            screen_info=$(xrandr --current 2>/dev/null | grep -E " connected " | head -n1)
        fi
        
        if [ -n "${screen_info}" ]; then
            # Extract geometry using regex pattern (handles both primary and non-primary displays)
            # Pattern: WIDTHxHEIGHT+X+Y (e.g., "1920x1080+0+0" or "1280x800+2560+640")
            geometry=$(echo "${screen_info}" | grep -oE '[0-9]+x[0-9]+\+[0-9]+\+[0-9]+' | head -n1)
            
            if [ -n "${geometry}" ]; then
                # Extract width and height from geometry string
                screen_width=$(echo "${geometry}" | cut -d'x' -f1)
                screen_height=$(echo "${geometry}" | cut -d'x' -f2 | cut -d'+' -f1)
            fi
        fi
    elif command -v xdpyinfo >/dev/null 2>&1; then
        local dimensions
        dimensions=$(xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}')
        if [ -n "${dimensions}" ]; then
            screen_width=$(echo "${dimensions}" | cut -d'x' -f1)
            screen_height=$(echo "${dimensions}" | cut -d'x' -f2)
        fi
    fi
    
    # Validate dimensions are numeric and reasonable
    if ! [[ "${screen_width}" =~ ^[0-9]+$ ]] || ! [[ "${screen_height}" =~ ^[0-9]+$ ]] || \
       [ "${screen_width}" -lt 640 ] || [ "${screen_height}" -lt 480 ]; then
        # Invalid dimensions, use safe default (1920x1080)
        screen_width=1920
        screen_height=1080
    fi
    
    # Define margins that account for window decorations and panels
    # - Window decorations (title bar + borders): ~40-50px
    # - Taskbar/panel: ~40-60px
    # - Safety buffer: ~10-20px
    local margin_x=30        # Horizontal margin (left/right)
    local margin_y_top=60    # Top margin (accounts for title bar + panels)
    local margin_y_bottom=80 # Bottom margin (accounts for taskbar + title bar + decorations)
    
    local x y
    
    case "${position}" in
        center)
            x=$(( (screen_width - width) / 2 ))
            y=$(( (screen_height - height) / 2 ))
            ;;
        top-left)
            x=${margin_x}
            y=${margin_y_top}
            ;;
        *)
            # Default to center for invalid positions
            x=$(( (screen_width - width) / 2 ))
            y=$(( (screen_height - height) / 2 ))
            ;;
    esac
    
    # Bounds checking: ensure window stays fully on screen
    # Account for the fact that window managers add decorations to the content area
    local min_x=${margin_x}
    local min_y=${margin_y_top}
    local max_x=$(( screen_width - width - margin_x ))
    local max_y=$(( screen_height - height - margin_y_bottom ))
    
    # Clamp x coordinate
    if [ "${x}" -lt "${min_x}" ]; then
        x=${min_x}
    elif [ "${x}" -gt "${max_x}" ]; then
        x=${max_x}
    fi
    
    # Clamp y coordinate
    if [ "${y}" -lt "${min_y}" ]; then
        y=${min_y}
    elif [ "${y}" -gt "${max_y}" ]; then
        y=${max_y}
    fi
    
    if [ "${only_coords}" = "true" ]; then
        echo "${x} ${y}"
    else
        echo "${width}x${height}+${x}+${y}"
    fi
}

# Reposition popup window after creation (for dialog tools that don't support position)
# This is a workaround for zenity and kdialog which lack built-in position control
reposition_popup_window() {
    local window_title="$1"
    local tool="$2"
    local position="$3"
    local width="$4"
    local height="$5"
    local max_attempts="${6:-10}"  # Default 10 attempts if not specified
    
    if [ -z "${tool}" ] || [ "${position}" = "center" ]; then
        # No tool available or center position (default), skip repositioning
        return 0
    fi

    # gamescope publishes no _NET_CLIENT_LIST, so `wmctrl -l` finds nothing.
    # Its ConfigureRequest handler honors plain moves, so xdotool works there.
    if [ "${env_type:-}" = "gamescope" ] && [ "${tool}" = "wmctrl" ] && command -v xdotool >/dev/null 2>&1; then
        tool="xdotool"
    fi
    
    # Wait for window to be fully created and rendered
    sleep 1.0
    
    # Try to find and reposition window with retries
    local attempt=0
    local window_id=""
    
    while [ "${attempt}" -lt "${max_attempts}" ] && [ -z "${window_id}" ]; do
        case "${tool}" in
            wmctrl)
                window_id=$(wmctrl -l | grep "${window_title}" | head -n1 | awk '{print $1}')
                ;;
            xdotool)
                window_id=$(xdotool search --name "${window_title}" 2>/dev/null | head -n1)
                ;;
        esac
        
        if [ -z "${window_id}" ]; then
            sleep 0.2
            attempt=$((attempt + 1))
        fi
    done
    
    if [ -z "${window_id}" ]; then
        # Window not found, can't reposition
        return 1
    fi
    
    # Calculate target position
    local coords
    coords=$(calculate_popup_geometry "${position}" "${width}" "${height}" "true")
    local target_x target_y
    target_x=$(echo "${coords}" | cut -d' ' -f1)
    target_y=$(echo "${coords}" | cut -d' ' -f2)
    
    # Move window to target position
    case "${tool}" in
        wmctrl)
            # wmctrl format: -e gravity,x,y,width,height (use 0 for gravity, -1 to keep size)
            wmctrl -i -r "${window_id}" -e "0,${target_x},${target_y},-1,-1" 2>/dev/null
            ;;
        xdotool)
            xdotool windowmove "${window_id}" "${target_x}" "${target_y}" 2>/dev/null
            ;;
    esac
    
    return 0
}

# Log-only gamescope diagnostics. No-op until the debug module is sourced
# and GAMESCOPE_OVERLAY_DEBUG is on. Does not change atoms or geometry.
_gamescope_debug_after_apply() {
    if type gamescope_overlay_debug_on_apply >/dev/null 2>&1; then
        gamescope_overlay_debug_on_apply "${1:-}" "${2:-}" "${3:-}" || true
    fi
}

_WM_DEBUG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${_WM_DEBUG_DIR}/gamescope-overlay-debug.sh"
unset _WM_DEBUG_DIR
