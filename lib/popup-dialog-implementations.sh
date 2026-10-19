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
                ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} zenity --warning \
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
                ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} zenity --warning \
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
                    ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} yad --warning \
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
                    ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} yad --warning \
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
                    ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} yad --warning \
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
                    ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} yad --warning \
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
                ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} kdialog --title "${window_title}" \
                    --warningyesno "${popup_text}" \
                    --yes-label "${_kd_pause_label}" \
                    --no-label "Dismiss" \
                    2>/dev/null &
            else
                ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} kdialog --title "${window_title}" \
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

# Show the "Pause Activated" notice.
# On gamescope, spawn a real X11 window in the background, tag it by that PID,
# then wait. Desktop kdialog keeps a passive notification (no X window to tag).
# Uses caller locals _dlg_prefix, _pause_info_timeout, dialog_tool, env_type, window_tool.
# Parameters: $1 pause end time (HH:MM or "unknown")
_popup_show_pause_activated_notice() {
    local pause_end_time="$1"
    local title="Pause Activated"
    local text="Warning popups paused until ${pause_end_time}"

    if [ "${dialog_tool}" = "kdialog" ] && [ "${env_type:-}" != "gamescope" ]; then
        ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} kdialog --passivepopup \
            "${text}" "${_pause_info_timeout}" 2>/dev/null
        return 0
    fi

    local info_pid=""
    local pause_w=400 pause_h=150
    if [ "${env_type:-}" = "gamescope" ] && type gamescope_interactive_dialog_dimensions >/dev/null 2>&1; then
        local _pause_dims _pause_rc=0
        _pause_dims=$(gamescope_interactive_dialog_dimensions "${pause_w}" "${pause_h}") || _pause_rc=$?
        local _pw _ph
        _pw=$(echo "${_pause_dims}" | awk '{print $1}')
        _ph=$(echo "${_pause_dims}" | awk '{print $2}')
        if [ "${_pause_rc}" -eq 0 ] && [[ "${_pw}" =~ ^[0-9]+$ ]] && [[ "${_ph}" =~ ^[0-9]+$ ]]; then
            if type log_to_file >/dev/null 2>&1; then
                log_to_file "INFO" "gamescope pause notice size override: ${pause_w}x${pause_h} -> ${_pw}x${_ph}"
            fi
            pause_w="${_pw}"
            pause_h="${_ph}"
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
            ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} yad --info \
                --title="${title}" \
                --text="${text}" \
                --width="${pause_w}" \
                --height="${pause_h}" \
                --center \
                --fixed \
                --button="OK:0" \
                --timeout="${_pause_info_timeout}" \
                2>/dev/null &
            info_pid=$!
            ;;
        kdialog)
            # kdialog msgbox has no reliable width flag on SteamOS; atoms still applied.
            ${_dlg_prefix[@]+"${_dlg_prefix[@]}"} kdialog --title "${title}" --msgbox "${text}" 2>/dev/null &
            info_pid=$!
            ;;
        *)
            return 0
            ;;
    esac

    if [ -n "${info_pid}" ] && [ "${env_type:-}" = "gamescope" ] && type apply_gamescope_overlay_atoms >/dev/null 2>&1; then
        apply_gamescope_overlay_atoms "${title}" "${window_tool:-}" "${info_pid}" || true
    fi

    if [ "${dialog_tool}" = "kdialog" ] && [ -n "${info_pid}" ]; then
        (
            sleep "${_pause_info_timeout}"
            kill "${info_pid}" 2>/dev/null || true
        ) &
        local killer_pid=$!
        wait "${info_pid}" 2>/dev/null || true
        kill "${killer_pid}" 2>/dev/null || true
        wait "${killer_pid}" 2>/dev/null || true
        return 0
    fi

    if [ -n "${info_pid}" ]; then
        wait "${info_pid}" 2>/dev/null || true
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

