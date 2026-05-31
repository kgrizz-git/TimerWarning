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

    case "${dialog_tool}" in
        zenity)
            # zenity doesn't support position natively, only size
            # Check if pause button should be added (Enhancement #21)
            if [ -z "${zenity_output_file:-}" ]; then
                zenity_output_file=$(mktemp)
            fi

            if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
                # Add pause button based on configured duration
                local pause_button_label="Pause ${pause_duration} min"
                zenity --warning \
                    --title="${window_title}" \
                    --text="${popup_text}" \
                    --modal \
                    --width="${width}" \
                    --height="${height}" \
                    --extra-button="${pause_button_label}" \
                    > "${zenity_output_file}" 2>/dev/null &
                popup_pid=$!
            else
                # No pause button
                zenity --warning \
                    --title="${window_title}" \
                    --text="${popup_text}" \
                    --modal \
                    --width="${width}" \
                    --height="${height}" \
                    > "${zenity_output_file}" 2>/dev/null &
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
                    yad --warning \
                        --title="${window_title}" \
                        --text="${popup_text}" \
                        --modal \
                        --width="${width}" \
                        --height="${height}" \
                        --center \
                        --fixed \
                        --on-top \
                        --button="Pause ${pause_duration} min:${pause_duration}" \
                        --button="OK:0" \
                        2>/dev/null &
                    popup_pid=$!
                else
                    # No pause button
                    yad --warning \
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
                    yad --warning \
                        --title="${window_title}" \
                        --text="${popup_text}" \
                        --modal \
                        --width="${width}" \
                        --height="${height}" \
                        --posx="${pos_x}" \
                        --posy="${pos_y}" \
                        --fixed \
                        --on-top \
                        --button="Pause ${pause_duration} min:${pause_duration}" \
                        --button="OK:0" \
                        2>/dev/null &
                    popup_pid=$!
                else
                    # No pause button
                    yad --warning \
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
                kdialog --title "${window_title}" \
                    --warningyesno "${popup_text}" \
                    --yes-label "${_kd_pause_label}" \
                    --no-label "Dismiss" \
                    2>/dev/null &
            else
                kdialog --title "${window_title}" \
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

                            zenity --info \
                                --title="Pause Activated" \
                                --text="Warning popups paused until ${pause_end_time}" \
                                --width=400 \
                                --height=150 \
                                --timeout=30 \
                                2>/dev/null

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
            # yad: exit code matches button value
            if [ ${popup_exit_code} -eq "${pause_duration}" ]; then
                # Pause button was clicked
                if activate_pause "${pause_duration}"; then
                    # Show confirmation dialog
                    local pause_end_timestamp
                    pause_end_timestamp=$(get_pause_end_timestamp)
                    local pause_end_time
                    pause_end_time=$(date -d "@${pause_end_timestamp}" +"%H:%M" 2>/dev/null || date -r "${pause_end_timestamp}" +"%H:%M" 2>/dev/null || echo "unknown")

                    yad --info \
                        --title="Pause Activated" \
                        --text="Warning popups paused until ${pause_end_time}" \
                        --width=400 \
                        --height=150 \
                        --button="OK:0" \
                        --timeout=30 \
                        2>/dev/null

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
                    kdialog --passivepopup \
                        "Warning popups paused until ${pause_end_time}" 30 2>/dev/null
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

