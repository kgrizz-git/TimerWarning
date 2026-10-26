#!/bin/bash

###############################################################################
# Sleep Warning System - Popup Dialog Implementations (tool-specific)
#
# This module contains dialog-tool-specific popup spawning logic extracted from
# `lib/popup-display.sh` to reduce duplication and keep the orchestrator smaller.
#
# IMPORTANT:
# - This code relies on bash's dynamic scoping and expects certain variables to
#   exist in the caller's scope (normally `show_warning()` in `popup-display.sh`):
#   - dialog_tool, window_title, width, height, popup_position, window_tool
#   - pause_available, pause_duration
#   - zenity_output_file (for zenity pause button output; may be empty)
#   - popup_pid (set by this function)
# - It also expects functions from other modules to be available:
#   - calculate_popup_geometry, reposition_popup_window, check_window_tools
#   - log_to_file (optional but used in kdialog failure path)
#   - pause-state helpers: can_pause_now, activate_pause, get_pause_end_timestamp
#   - pid management: cleanup_popup_pid (from popup-pid-management.sh)
###############################################################################

# Resolve the app icon: installed copy beside this module, else the repo asset.
# Outputs: icon path on stdout, or nothing when no icon file exists.
_popup_icon_path() {
    local here
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || return 0
    if [[ -f "${here}/timerwarning-icon.png" ]]; then
        printf '%s' "${here}/timerwarning-icon.png"
    elif [[ -f "${here}/../assets/icon-256.png" ]]; then
        printf '%s' "${here}/../assets/icon-256.png"
    fi
}

# Print a dialog tool's help text with a 1s deadline and 1s KILL grace, so a
# stalled toolkit can never hold up a popup spawn. Parameters: command and args.
_popup_icon_help_probe() {
    if command -v timeout >/dev/null 2>&1; then
        timeout --kill-after=1s 1s "$@" 2>/dev/null || true
        return 0
    fi
    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout --kill-after=1s 1s "$@" 2>/dev/null || true
        return 0
    fi

    local pid watcher
    "$@" 2>/dev/null &
    pid=$!
    (
        sleep 1 || exit 0
        if kill -0 "${pid}" 2>/dev/null; then
            kill -TERM "${pid}" 2>/dev/null || true
            sleep 1
            kill -KILL "${pid}" 2>/dev/null || true
        fi
    ) >/dev/null 2>&1 &
    watcher=$!
    wait "${pid}" 2>/dev/null || true
    kill "${watcher}" 2>/dev/null || true
    wait "${watcher}" 2>/dev/null || true
    return 0
}

# Build window-icon arguments for a dialog tool.
# Only adds the flag when the icon exists and the tool's help lists the option,
# so an older or newer toolkit never fails to start over an unknown flag.
# The help probe is bounded and runs once per tool per process; countdown
# respawns reuse the cached answer.
# Parameters: $1 dialog tool (yad | zenity | kdialog).
# Outputs: sets `_dlg_icon` array in the caller's scope (may be empty).
_POPUP_ICON_SUPPORT_yad=""
_POPUP_ICON_SUPPORT_zenity=""
_POPUP_ICON_SUPPORT_kdialog=""
_popup_icon_args() {
    _dlg_icon=()
    local icon
    icon="$(_popup_icon_path)"
    [[ -n "${icon}" ]] || return 0
    case "$1" in
        yad)
            if [[ -z "${_POPUP_ICON_SUPPORT_yad}" ]]; then
                _POPUP_ICON_SUPPORT_yad=no
                _popup_icon_help_probe yad --help-all | grep -q -- '--window-icon' && _POPUP_ICON_SUPPORT_yad=yes
            fi
            [[ "${_POPUP_ICON_SUPPORT_yad}" = "yes" ]] && _dlg_icon=(--window-icon="${icon}")
            ;;
        zenity)
            if [[ -z "${_POPUP_ICON_SUPPORT_zenity}" ]]; then
                _POPUP_ICON_SUPPORT_zenity=no
                _popup_icon_help_probe zenity --help-general | grep -q -- '--window-icon' && _POPUP_ICON_SUPPORT_zenity=yes
            fi
            [[ "${_POPUP_ICON_SUPPORT_zenity}" = "yes" ]] && _dlg_icon=(--window-icon="${icon}")
            ;;
        kdialog)
            if [[ -z "${_POPUP_ICON_SUPPORT_kdialog}" ]]; then
                _POPUP_ICON_SUPPORT_kdialog=no
                _popup_icon_help_probe kdialog --help-all | grep -q -- '--icon' && _POPUP_ICON_SUPPORT_kdialog=yes
            fi
            [[ "${_POPUP_ICON_SUPPORT_kdialog}" = "yes" ]] && _dlg_icon=(--icon "${icon}")
            ;;
        *)
            ;;
    esac
    return 0
}

# Spawn a warning dialog using the currently selected dialog tool.
#
# Parameters:
# - $1: popup_text (already sanitized via dialog_safe_text by the caller)
#
# Outputs / side effects:
# - sets `popup_pid` in the caller's scope (PID of spawned dialog), or empty on failure
# - may set `zenity_output_file` in the caller's scope (zenity output capture file)
_popup_spawn_warning_dialog() {
    local popup_text="$1"

    # Ensure caller sees a cleared PID on failure.
    popup_pid=""
    local zenity_stderr_file=""

    local -a _dlg_prefix=()
    if [ "${POPUP_FORCE_X11_BACKEND:-false}" = "true" ]; then
        # Unset HiDPI scale vars so buffer size matches the requested window size
        # under gamescope (scale mismatch breaks fit-to-canvas math).
        _dlg_prefix=(env -u WAYLAND_DISPLAY -u GDK_SCALE -u GDK_DPI_SCALE -u QT_SCALE_FACTOR GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb)
    fi

    local -a _dlg_icon=()
    _popup_icon_args "${dialog_tool}"

    case "${dialog_tool}" in
        zenity)
            # zenity doesn't support position natively, only size
            # Check if pause button should be added (Enhancement #21)
            if [ -z "${zenity_output_file:-}" ]; then
                zenity_output_file=$(mktemp)
            fi
            zenity_stderr_file=$(mktemp) || return 1

            if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                # Add pause button based on configured duration
                local pause_button_label="Pause ${pause_duration} min"
                ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} zenity ${_dlg_icon[@]+"${_dlg_icon[@]}"} --warning \
                    --title="${window_title}" \
                    --text="${popup_text}" \
                    --modal \
                    --width="${width}" \
                    --height="${height}" \
                    --extra-button="${pause_button_label}" \
                    > "${zenity_output_file}" 2>"${zenity_stderr_file}" &
                popup_pid=$!
            else
                # No pause button
                ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} zenity ${_dlg_icon[@]+"${_dlg_icon[@]}"} --warning \
                    --title="${window_title}" \
                    --text="${popup_text}" \
                    --modal \
                    --width="${width}" \
                    --height="${height}" \
                    > "${zenity_output_file}" 2>"${zenity_stderr_file}" &
                popup_pid=$!
            fi

            # Reposition window after creation if position is top-left
            if [ -n "${window_tool}" ] && [ "${popup_position}" = "top-left" ]; then
                reposition_popup_window "${window_title}" "${window_tool}" "${popup_position}" "${width}" "${height}" &
            fi
            ;;

        yad)
            # yad supports both size and position via --geometry, --posx/--posy, or --center
            # Use --fixed to enforce dimensions (prevents YAD from auto-resizing based on text)
            # For center position, use --center flag (more reliable than geometry calculation)
            # For top-left, use --posx and --posy flags (more reliable than --geometry)
            # Check if pause button should be added (Enhancement #21)
            if [ "${popup_position}" = "center" ]; then
                # Use --center flag for proper centering
                if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                    # Add pause button based on configured duration
                    ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} yad ${_dlg_icon[@]+"${_dlg_icon[@]}"} --warning \
                        --title="${window_title}" \
                        --text="${popup_text}" \
                        --modal \
                        --width="${width}" \
                        --height="${height}" \
                        --center \
                        --fixed \
                        --on-top \
                        --button="Pause ${pause_duration} min:42" \
                        --button="OK:0" \
                        2>/dev/null &
                    popup_pid=$!
                else
                    # No pause button
                    ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} yad ${_dlg_icon[@]+"${_dlg_icon[@]}"} --warning \
                        --title="${window_title}" \
                        --text="${popup_text}" \
                        --modal \
                        --width="${width}" \
                        --height="${height}" \
                        --center \
                        --fixed \
                        --on-top \
                        2>/dev/null &
                    popup_pid=$!
                fi
            else
                # For top-left or other positions, calculate coordinates and use --posx/--posy
                local coords
                coords=$(calculate_popup_geometry "${popup_position}" "${width}" "${height}" "true")
                local pos_x pos_y
                pos_x=$(echo "${coords}" | cut -d' ' -f1)
                pos_y=$(echo "${coords}" | cut -d' ' -f2)

                if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                    # Add pause button based on configured duration
                    ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} yad ${_dlg_icon[@]+"${_dlg_icon[@]}"} --warning \
                        --title="${window_title}" \
                        --text="${popup_text}" \
                        --modal \
                        --width="${width}" \
                        --height="${height}" \
                        --posx="${pos_x}" \
                        --posy="${pos_y}" \
                        --fixed \
                        --on-top \
                        --button="Pause ${pause_duration} min:42" \
                        --button="OK:0" \
                        2>/dev/null &
                    popup_pid=$!
                else
                    # No pause button
                    ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} yad ${_dlg_icon[@]+"${_dlg_icon[@]}"} --warning \
                        --title="${window_title}" \
                        --text="${popup_text}" \
                        --modal \
                        --width="${width}" \
                        --height="${height}" \
                        --posx="${pos_x}" \
                        --posy="${pos_y}" \
                        --fixed \
                        --on-top \
                        2>/dev/null &
                    popup_pid=$!
                fi

                # Also reposition as backup in case --posx/--posy doesn't work properly (top-left only)
                if [ -n "${window_tool}" ] && [ "${popup_position}" = "top-left" ]; then
                    reposition_popup_window "${window_title}" "${window_tool}" "${popup_position}" "${width}" "${height}" &
                fi
            fi
            ;;

        kdialog)
            # Phase 4.2: use --warningyesno so kdialog shows a Pause button in addition
            # to the Dismiss (No) button.  Yes = "Pause N min", No = "Dismiss".
            # If pause is not available, fall back to --sorry (OK only).
            if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                local _kd_pause_label="Pause ${pause_duration} min"
                # --warningyesno: Yes button = left, No button = right
                # kdialog returns 0 for Yes (Pause), 1 for No (Dismiss)
                ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} kdialog ${_dlg_icon[@]+"${_dlg_icon[@]}"} --title "${window_title}" \
                    --warningyesno "${popup_text}" \
                    --yes-label "${_kd_pause_label}" \
                    --no-label "Dismiss" \
                    2>/dev/null &
            else
                ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} kdialog ${_dlg_icon[@]+"${_dlg_icon[@]}"} --title "${window_title}" \
                    --sorry "${popup_text}" \
                    2>/dev/null &
            fi
            popup_pid=$!
            # Give kdialog a moment to start
            sleep 0.2
            # Check if process is still running (if it exited immediately, popup failed)
            if ! kill -0 "${popup_pid}" 2>/dev/null; then
                if type log_to_file >/dev/null 2>&1; then
                    log_to_file "ERROR" "kdialog popup failed to start (PID ${popup_pid} exited immediately)"
                fi
                popup_pid=""
            fi

            # Reposition window after creation if position is top-left
            if [ -n "${popup_pid}" ] && [ -n "${window_tool}" ] && [ "${popup_position}" = "top-left" ]; then
                reposition_popup_window "${window_title}" "${window_tool}" "${popup_position}" "${width}" "${height}" &
            fi
            ;;
    esac

    # A background command has a PID even when GTK fails immediately. Treat
    # non-dismissal startup errors as failure so the dispatcher notifies users.
    # Preserve normal OK/cancel/pause statuses from a quickly dismissed dialog.
    if [ -n "${popup_pid}" ] && [ "${dialog_tool}" != "kdialog" ]; then
        sleep 0.2
        if ! kill -0 "${popup_pid}" 2>/dev/null; then
            local startup_rc=0
            wait "${popup_pid}" 2>/dev/null || startup_rc=$?
            case "${dialog_tool}:${startup_rc}" in
                yad:0|yad:252|zenity:0) ;;
                zenity:1)
                    # GTK initialization failures and ordinary Cancel both use
                    # status 1. A startup diagnostic distinguishes the failure;
                    # an explicit extra-button result remains a genuine pause.
                    if [ -s "${zenity_stderr_file}" ] && \
                        ! grep -qxF "Pause ${pause_duration} min" "${zenity_output_file}"; then
                        log_to_file "ERROR" "zenity failed at startup (exit 1 with diagnostic)"
                        popup_pid=""
                    fi
                    ;;
                *)
                    if [ "${pause_available}" != "true" ] || [ "${dialog_tool}" != "yad" ] || [ "${startup_rc}" != "42" ]; then
                        log_to_file "ERROR" "${dialog_tool} failed at startup (exit ${startup_rc})"
                        popup_pid=""
                    fi
                    ;;
            esac
        fi
    fi
    [ -z "${zenity_stderr_file}" ] || rm -f "${zenity_stderr_file}"
    return 0
}

# Background-only watchdog. Cancel its current sleep and reap it on every exit;
# killing a shell blocked in foreground sleep would orphan that sleep process.
_popup_notice_watchdog() {
    local notice_pid="$1" delay="$2"
    local sleeper_pid="" cancelled=false signal_name
    trap 'cancelled=true; if [ -n "${sleeper_pid}" ]; then kill -KILL "${sleeper_pid}" 2>/dev/null || true; fi' TERM INT HUP
    trap 'if [ -n "${sleeper_pid}" ]; then kill -KILL "${sleeper_pid}" 2>/dev/null || true; wait "${sleeper_pid}" 2>/dev/null || true; fi' EXIT
    for signal_name in TERM KILL; do
        sleep "${delay}" &
        sleeper_pid=$!
        [ "${cancelled}" = false ] || return 0
        wait "${sleeper_pid}" 2>/dev/null || return 0
        sleeper_pid=""
        [ "${cancelled}" = false ] || return 0
        kill -"${signal_name}" "${notice_pid}" 2>/dev/null || true
        delay=1
    done
}

# Background-only wrapper. Give atom setup its own process group, so cancellation
# terminates in-flight probes and their descendants as well as the worker shell.
# Job control is changed only inside this background process. The inner worker
# disables it so debug subjobs and command substitutions remain in that group.
_popup_notice_atoms_worker() {
    local atoms_group_pid="" cancelled=false
    trap 'cancelled=true; if [ -n "${atoms_group_pid}" ]; then kill -KILL -- "-${atoms_group_pid}" 2>/dev/null || true; fi' TERM INT HUP
    trap 'if [ -n "${atoms_group_pid}" ]; then kill -KILL -- "-${atoms_group_pid}" 2>/dev/null || true; wait "${atoms_group_pid}" 2>/dev/null || true; fi' EXIT
    set -m
    (
        set +m
        trap - TERM INT HUP EXIT
        apply_gamescope_overlay_atoms "$1" "$2" "$3" || true
        # Keep ownership of async debug work until it finishes or is cancelled.
        wait 2>/dev/null || true
    ) &
    atoms_group_pid=$!
    [ "${cancelled}" = false ] || return 0
    wait "${atoms_group_pid}" 2>/dev/null || true
}

# Show the "Pause Activated" notice.
# On gamescope, spawn a real X11 window in the background, tag it by that PID,
# then wait. Desktop kdialog keeps a passive notification (no X window to tag).
# Uses caller locals _dlg_prefix, _pause_info_timeout, dialog_tool, env_type, window_tool.
# Parameters: $1 pause end time (HH:MM or "unknown")
_popup_show_pause_activated_notice() {
    local pause_end_time="$1"
    local title="Pause Activated"
    local text="Warning popups paused until ${pause_end_time}"

    local info_pid=""
    local pause_w=400 pause_h=150
    local _gs_pause_req_w="${pause_w}"
    local _gs_pause_req_h="${pause_h}"
    # Desktop pause notices stay centered. Gamescope uses the same top-left
    # hit region as the warning dialog once the root-size override succeeds.
    local _pause_position="center"
    if [ "${env_type:-}" = "gamescope" ] && type gamescope_interactive_dialog_dimensions >/dev/null 2>&1; then
        local _pause_dims _pause_rc=0
        _pause_dims=$(gamescope_interactive_dialog_dimensions "${pause_w}" "${pause_h}") || _pause_rc=$?
        local _pw _ph
        _pw=$(echo "${_pause_dims}" | awk '{print $1}')
        _ph=$(echo "${_pause_dims}" | awk '{print $2}')
        if [ "${_pause_rc}" -eq 0 ] && [[ "${_pw}" =~ ^[0-9]+$ ]] && [[ "${_ph}" =~ ^[0-9]+$ ]]; then
            if type log_to_file >/dev/null 2>&1; then
                log_to_file "INFO" "gamescope pause notice size override: ${pause_w}x${pause_h} -> ${_pw}x${_ph} (top-left)"
            fi
            pause_w="${_pw}"
            pause_h="${_ph}"
            _pause_position="top-left"
        elif type log_to_file >/dev/null 2>&1; then
            log_to_file "WARNING" "gamescope pause notice: root size unavailable; keeping ${pause_w}x${pause_h}"
        fi
    fi
    case "${dialog_tool}" in
        zenity)
            ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} zenity --info \
                --title="${title}" \
                --text="${text}" \
                --width="${pause_w}" \
                --height="${pause_h}" \
                --timeout="${_pause_info_timeout}" \
                2>/dev/null &
            info_pid=$!
            ;;
        yad)
            local -a _pause_yad_pos=(--center)
            if [ "${_pause_position}" = "top-left" ]; then
                local _pause_coords _pause_x _pause_y
                _pause_coords=$(calculate_popup_geometry "top-left" "${pause_w}" "${pause_h}" "true")
                _pause_x=$(echo "${_pause_coords}" | cut -d' ' -f1)
                _pause_y=$(echo "${_pause_coords}" | cut -d' ' -f2)
                _pause_yad_pos=(--posx="${_pause_x}" --posy="${_pause_y}")
            fi
            ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} yad --info \
                --title="${title}" \
                --text="${text}" \
                --width="${pause_w}" \
                --height="${pause_h}" \
                "${_pause_yad_pos[@]}" \
                --fixed \
                --button="OK:0" \
                --timeout="${_pause_info_timeout}" \
                2>/dev/null &
            info_pid=$!
            ;;
        kdialog)
            # kdialog msgbox has no reliable width flag on SteamOS; atoms still applied.
            if [ "${env_type:-}" = "gamescope" ]; then
                ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} kdialog --title "${title}" --msgbox "${text}" 2>/dev/null &
            else
                ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} kdialog --passivepopup \
                    "${text}" "${_pause_info_timeout}" 2>/dev/null &
            fi
            info_pid=$!
            ;;
        *)
            return 0
            ;;
    esac

    # This is a new dialog PID: the warning's PID-file watchdog cannot kill it.
    # Arm an independent deadline before any X11 probes, even for tools with a
    # native --timeout (a stalled GUI event loop may never process that timeout).
    _popup_notice_watchdog "${info_pid}" "${_pause_info_timeout}" >/dev/null 2>&1 &
    local killer_pid=$!
    local notice_atoms_pid=""

    # zenity and kdialog have no position flags. Yad already passed --posx/--posy;
    # the move is the same backup the warning dialog uses when a window tool exists.
    if [ "${_pause_position}" = "top-left" ] && [ -n "${info_pid}" ] && [ -n "${window_tool:-}" ]; then
        reposition_popup_window "${title}" "${window_tool}" "top-left" "${pause_w}" "${pause_h}" &
    fi

    if [ -n "${info_pid}" ] && [ "${env_type:-}" = "gamescope" ] && type apply_gamescope_overlay_atoms >/dev/null 2>&1; then
        local _gs_prev_event="${gamescope_debug_event:-spawn}"
        local _gs_prev_rw="${gamescope_debug_requested_w:-}"
        local _gs_prev_rh="${gamescope_debug_requested_h:-}"
        local _gs_prev_ow="${gamescope_debug_override_w:-}"
        local _gs_prev_oh="${gamescope_debug_override_h:-}"
        gamescope_debug_event="pause"
        gamescope_debug_requested_w="${_gs_pause_req_w}"
        gamescope_debug_requested_h="${_gs_pause_req_h}"
        gamescope_debug_override_w="${pause_w}"
        gamescope_debug_override_h="${pause_h}"
        # Do not let a stalled display probe prevent reaping the bounded notice.
        _popup_notice_atoms_worker "${title}" "${window_tool:-}" "${info_pid}" >/dev/null 2>&1 &
        notice_atoms_pid=$!
        gamescope_debug_event="${_gs_prev_event}"
        gamescope_debug_requested_w="${_gs_prev_rw}"
        gamescope_debug_requested_h="${_gs_prev_rh}"
        gamescope_debug_override_w="${_gs_prev_ow}"
        gamescope_debug_override_h="${_gs_prev_oh}"
    fi

    local _pause_notice_rc=0
    if [ -n "${info_pid}" ]; then
        wait "${info_pid}" 2>/dev/null || _pause_notice_rc=$?
        kill "${killer_pid}" 2>/dev/null || true
        wait "${killer_pid}" 2>/dev/null || true
        if [ -n "${notice_atoms_pid}" ]; then
            kill "${notice_atoms_pid}" 2>/dev/null || true
            wait "${notice_atoms_pid}" 2>/dev/null || true
        fi
        if [ "${env_type:-}" = "gamescope" ] && type gamescope_overlay_debug_log_exit >/dev/null 2>&1; then
            gamescope_overlay_debug_log_exit "${_pause_notice_rc}" "false" "pause" || true
        fi
    fi
}

# Handle pause button/menu actions after a popup closes.
#
# Parameters:
# - $1: popup_exit_code (exit code from the dialog process)
#
# Behavior:
# - Returns 0 if a pause was successfully activated and the user was notified.
# - Returns 1 if pause was not activated (not clicked / invalid / not available).
#
# Notes:
# - This is intentionally tool-specific because zenity/yad/kdialog have different
#   button/exit-code semantics.
_popup_maybe_handle_pause_click() {
    local popup_exit_code="$1"

    # The caller already guards on pause availability, but keep this defensive.
    if [ "${pause_available}" != "true" ] || [ -z "${pause_duration}" ]; then
        return 1
    fi

    local -a _dlg_prefix=()
    local _pause_info_timeout=30
    if [ "${POPUP_FORCE_X11_BACKEND:-false}" = "true" ] || [ "${env_type:-}" = "gamescope" ]; then
        _dlg_prefix=(env -u WAYLAND_DISPLAY -u GDK_SCALE -u GDK_DPI_SCALE -u QT_SCALE_FACTOR GDK_BACKEND=x11 QT_QPA_PLATFORM=xcb)
        _pause_info_timeout=10
    fi

    case "${dialog_tool}" in
        zenity)
            # zenity: exit code 1 = extra button clicked
            if [ ${popup_exit_code} -eq 1 ]; then
                local button_label
                button_label=$(cat "${zenity_output_file}" 2>/dev/null | tr -d '\n')
                rm -f "${zenity_output_file}"

                if [ -n "${button_label}" ] && echo "${button_label}" | grep -q "Pause.*min"; then
                    # Extract duration from button label
                    local clicked_duration
                    clicked_duration=$(echo "${button_label}" | grep -oE '[0-9]+' | head -n1)

                    if [ -n "${clicked_duration}" ] && [ "${clicked_duration}" -eq "${pause_duration}" ]; then
                        # Activate pause
                        if activate_pause "${clicked_duration}"; then
                            # Show confirmation dialog
                            local pause_end_timestamp
                            pause_end_timestamp=$(get_pause_end_timestamp)
                            local pause_end_time
                            pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")

                            _popup_show_pause_activated_notice "${pause_end_time}"

                            if [ -n "${popup_pid}" ]; then
                                cleanup_popup_pid "${popup_pid}"
                            fi
                            return 0
                        fi
                    fi
                fi
            fi
            rm -f "${zenity_output_file}"
            ;;

        yad)
            # Use a reserved button status so GTK startup error 1 cannot become a pause.
            if [ ${popup_exit_code} -eq 42 ]; then
                # Pause button was clicked
                if activate_pause "${pause_duration}"; then
                    # Show confirmation dialog
                    local pause_end_timestamp
                    pause_end_timestamp=$(get_pause_end_timestamp)
                    local pause_end_time
                    pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")

                    _popup_show_pause_activated_notice "${pause_end_time}"

                    if [ -n "${popup_pid}" ]; then
                        cleanup_popup_pid "${popup_pid}"
                    fi
                    return 0
                fi
            fi
            ;;

        kdialog)
            # Phase 4.2: --warningyesno exit code 0 = "Pause N min" button was clicked.
            # Use configured pause_duration from config rather than hardcoded 5/10.
            if can_pause_now && [ ${popup_exit_code} -eq 0 ]; then
                if activate_pause "${pause_duration}"; then
                    local pause_end_timestamp
                    pause_end_timestamp=$(get_pause_end_timestamp)
                    local pause_end_time
                    pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null \
                        || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null \
                        || echo "unknown")
                    _popup_show_pause_activated_notice "${pause_end_time}"
                    if [ -n "${popup_pid}" ]; then
                        cleanup_popup_pid "${popup_pid}"
                    fi
                    return 0
                fi
            fi
            ;;
    esac

    return 1
}

