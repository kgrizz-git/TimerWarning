#!/bin/bash

###############################################################################
# Sleep Warning System - Gamescope overlay debug logging (log-only)
#
# When get_gamescope_overlay_debug is true and env_type=gamescope, emit one
# DEBUG-GAMESCOPE block per spawn, countdown respawn, or pause notice.
# The 2-second atom poll must not emit another block for the same window.
#
# This module does not change geometry, atoms, button sets, auto-close, or
# the popup watchdog. Every debug xprop/xwininfo call is wrapped in
# a 2-second deadline plus a 1-second KILL grace period. The overlay census
# inspects at most 64 root children.
# A failed or timed-out probe is logged as "unavailable".
#
# Inputs (caller environment, snapshotted by gamescope_overlay_debug_on_apply):
#   env_type, dialog_tool, popup_position, pause_available, pause_duration
#   gamescope_debug_event, gamescope_debug_requested_w/h, gamescope_debug_override_w/h
#   FIND_WINDOW_LOOKUP_PATH, FIND_WINDOW_PID_VISIBLE_COUNT
#   GAMESCOPE_OVERLAY_DEBUG_SYNC=true runs probes in the caller (unit tests).
# Outputs: log_to_file INFO lines prefixed DEBUG-GAMESCOPE. No dialog title or body.
#
# Dependencies: config.sh (get_gamescope_overlay_debug), log_to_file optional.
# Requires: xprop/xwininfo when a live X display is probed.
# Each probe is bounded by timeout(1), gtimeout, or a bash watchdog
# (macOS CI has neither GNU timeout nor gtimeout).
###############################################################################

# True when the log-only flag is on. Uses the config getter; no second parser.
# Returns 0 when enabled, 1 otherwise.
gamescope_overlay_debug_enabled() {
    if ! type get_gamescope_overlay_debug >/dev/null 2>&1; then
        return 1
    fi
    [ "$(get_gamescope_overlay_debug)" = "true" ]
}

# Decode a gamescope focus-display property.
# gamescope 3.16.23 writes the display name with XChangeProperty format 32 and
# nitems=strlen+1 on a char*. libX11's _XData32 reads that as longs, so xprop
# shows 32-bit values. ":0" is typically "12346, 0, 0" (bytes 0x3a 0x30 0x00).
# Parameters: $1 raw xprop line or comma-separated CARDINAL items
# Prints the display string, or "unavailable".
gamescope_decode_cardinal_display() {
    local raw="${1:-}"
    local payload item lo b0 b1 b2 b3 b out="" stop=0 _ch
    if [ -z "${raw}" ] || [[ "${raw}" == *"not found"* ]]; then
        printf '%s\n' "unavailable"
        return 0
    fi
    if [[ "${raw}" == *"="* ]]; then
        payload="${raw#*=}"
    else
        payload="${raw}"
    fi
    payload=$(printf '%s' "${payload}" | tr -d '[:space:]')
    if [ -z "${payload}" ]; then
        printf '%s\n' "unavailable"
        return 0
    fi
    local IFS=','
    local -a _gs_items=()
    read -r -a _gs_items <<< "${payload}" || true
    for item in "${_gs_items[@]}"; do
        if ! [[ "${item}" =~ ^[0-9]+$ ]]; then
            continue
        fi
        lo=$((item & 4294967295))
        b0=$((lo & 255))
        b1=$(((lo >> 8) & 255))
        b2=$(((lo >> 16) & 255))
        b3=$(((lo >> 24) & 255))
        for b in "${b0}" "${b1}" "${b2}" "${b3}"; do
            if [ "${b}" -eq 0 ]; then
                stop=1
                break
            fi
            if [ "${b}" -ge 32 ] && [ "${b}" -le 126 ]; then
                printf -v _ch '%b' "\\$(printf '%03o' "${b}")"
                out+="${_ch}"
            fi
        done
        if [ "${stop}" -eq 1 ]; then
            break
        fi
    done
    if [ -z "${out}" ]; then
        printf '%s\n' "unavailable"
    else
        printf '%s\n' "${out}"
    fi
}

# Normalize an X window id to lowercase 0x hex. Decimal ids are converted.
# Parameters: $1 window id
_gs_debug_norm_wid() {
    local w="${1:-}"
    w=$(printf '%s' "${w}" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
    if [[ "${w}" =~ ^[0-9]+$ ]]; then
        printf '0x%x\n' "$((w))"
    elif [[ "${w}" =~ ^0x[0-9a-f]+$ ]]; then
        printf '0x%x\n' "$((w))"
    else
        printf '%s\n' "${w}"
    fi
}

# Run one debug probe with a 2s deadline and 1s KILL grace.
# Uses timeout, then gtimeout, then a bash watchdog so macOS CI (no GNU timeout)
# still runs the mocked census. Parameters: command and arguments.
_gs_debug_probe() {
    if command -v timeout >/dev/null 2>&1; then
        timeout --kill-after=1s 2s "$@" 2>/dev/null || true
        return 0
    fi
    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout --kill-after=1s 2s "$@" 2>/dev/null || true
        return 0
    fi

    local pid watcher
    "$@" 2>/dev/null &
    pid=$!
    (
        sleep 2 || exit 0
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

# Print the value after '=' for one property, or "unavailable".
# Parameters: $1 window id ("root" for the root window), $2 atom name
_gs_debug_xprop_value() {
    local id="${1:-}"
    local prop="${2:-}"
    local out val
    if [ -z "${id}" ] || [ -z "${prop}" ]; then
        printf '%s\n' "unavailable"
        return 0
    fi
    if [ "${id}" = "root" ]; then
        out=$(_gs_debug_probe xprop -root "${prop}")
    else
        out=$(_gs_debug_probe xprop -id "${id}" "${prop}")
    fi
    if [ -z "${out}" ] || [[ "${out}" == *"not found"* ]]; then
        printf '%s\n' "unavailable"
        return 0
    fi
    val="${out#*=}"
    val=$(printf '%s' "${val}" | tr '\n\r' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [ -z "${val}" ]; then
        printf '%s\n' "unavailable"
    else
        printf '%s\n' "${val}"
    fi
}

# Button flags we actually pass, matching the gamescope spawn paths.
# Does not invent a zenity Cancel. The pause notice is an info dialog whatever
# pause_available says, so kind=pause reports its own flags.
# Parameters: $1 tool, $2 pause_available, $3 pause minutes, $4 kind (optional)
gamescope_overlay_debug_button_summary() {
    local tool="${1:-}"
    local pause_ok="${2:-false}"
    local pause_min="${3:-}"
    local kind="${4:-}"
    if [ "${kind}" = "pause" ]; then
        case "${tool}" in
            zenity) printf '%s\n' "--info OK" ;;
            yad) printf '%s\n' "--info --button=OK:0" ;;
            kdialog) printf '%s\n' "--msgbox OK" ;;
            *) printf '%s\n' "unavailable" ;;
        esac
    elif [ "${pause_ok}" = "true" ] && [ -n "${pause_min}" ]; then
        case "${tool}" in
            zenity) printf '%s\n' "OK + --extra-button=Pause ${pause_min} min" ;;
            yad) printf '%s\n' "--button=Pause ${pause_min} min:42 --button=OK:0" ;;
            kdialog) printf '%s\n' "--warningyesno yes=Pause ${pause_min} min no=Dismiss" ;;
            *) printf '%s\n' "unavailable" ;;
        esac
    else
        case "${tool}" in
            zenity) printf '%s\n' "OK only" ;;
            yad) printf '%s\n' "no --button (yad default OK and Cancel)" ;;
            kdialog) printf '%s\n' "--sorry OK" ;;
            *) printf '%s\n' "unavailable" ;;
        esac
    fi
}

# Census of STEAM_OVERLAY children on the current DISPLAY.
# Walks xwininfo -root -children as top → bottom (first printed line is index 0).
# That direction is an assumption until calibrated on device; it is logged.
# gamescope 3.16.23: last window with width > 1200 and opacity >= running max
# wins. Absent opacity counts as 0xffffffff. Mapped and unmapped windows count.
# Parameters: $1 our window id (may be empty). Names equal to our dialog are omitted.
# Prints lines: root_size, child, predicted_overlay_wid, children_order, census_truncated.
gamescope_overlay_scan_children() {
    local our_wid="${1:-}"
    local our_norm="" snap line child_count=0 truncated=false
    local max_op=-1 predicted="" root_w="" root_h=""
    our_norm=$(_gs_debug_norm_wid "${our_wid}")
    # -children alone suppresses the default statistics, including Width/Height.
    snap=$(_gs_debug_probe xwininfo -root -children -stats)
    if [ -z "${snap}" ]; then
        printf '%s\n' "root_size=unavailable"
        printf '%s\n' "census=unavailable"
        printf '%s\n' "predicted_overlay_wid=unavailable"
        printf '%s\n' "children_order=assumed_top_first"
        printf '%s\n' "census_truncated=false"
        return 0
    fi
    while IFS= read -r line; do
        if [ -z "${root_w}" ] && [[ "${line}" =~ Width:[[:space:]]*([0-9]+) ]]; then
            root_w="${BASH_REMATCH[1]}"
        fi
        if [ -z "${root_h}" ] && [[ "${line}" =~ Height:[[:space:]]*([0-9]+) ]]; then
            root_h="${BASH_REMATCH[1]}"
        fi
    done <<< "${snap}"
    if [[ "${root_w}" =~ ^[0-9]+$ ]] && [[ "${root_h}" =~ ^[0-9]+$ ]]; then
        printf 'root_size=%sx%s\n' "${root_w}" "${root_h}"
    else
        printf '%s\n' "root_size=unavailable"
    fi

    while IFS= read -r line; do
        if ! [[ "${line}" =~ ^[[:space:]]+(0x[0-9a-fA-F]+)[[:space:]] ]]; then
            continue
        fi
        if [ "${child_count}" -ge 64 ]; then
            truncated=true
            break
        fi
        local wid width overlay_val opacity opacity_log map_state focus_val class_val
        local is_ours="false" name="" name_field="" wid_norm="" map_out=""
        wid="${BASH_REMATCH[1]}"
        child_count=$((child_count + 1))
        width=""
        if [[ "${line}" =~ ([0-9]+)x[0-9]+[+] ]]; then
            width="${BASH_REMATCH[1]}"
        fi
        if [[ "${line}" =~ \"([^\"]*)\" ]]; then
            name="${BASH_REMATCH[1]}"
        fi
        overlay_val=$(_gs_debug_xprop_value "${wid}" "STEAM_OVERLAY")
        if ! [[ "${overlay_val}" =~ ^[0-9]+$ ]] || [ "${overlay_val}" -eq 0 ]; then
            continue
        fi
        opacity_log=$(_gs_debug_xprop_value "${wid}" "_NET_WM_WINDOW_OPACITY")
        if [[ "${opacity_log}" =~ ^[0-9]+$ ]]; then
            opacity="${opacity_log}"
        elif [[ "${opacity_log}" =~ ^0x[0-9a-fA-F]+$ ]]; then
            opacity=$((opacity_log))
        else
            opacity=4294967295
            opacity_log="absent(0xffffffff)"
        fi
        map_out=$(_gs_debug_probe xwininfo -id "${wid}")
        map_state="unavailable"
        if [[ "${map_out}" =~ Map\ State:[[:space:]]*(Is[A-Za-z]+) ]]; then
            map_state="${BASH_REMATCH[1]}"
        fi
        focus_val=$(_gs_debug_xprop_value "${wid}" "STEAM_INPUT_FOCUS")
        class_val=$(_gs_debug_xprop_value "${wid}" "WM_CLASS")
        class_val=$(printf '%s' "${class_val}" | tr '\n\r' ' ')
        wid_norm=$(_gs_debug_norm_wid "${wid}")
        if [ -n "${our_norm}" ] && [ "${wid_norm}" = "${our_norm}" ]; then
            is_ours="true"
        fi
        # Never log our dialog title. Also drop a name that matches window_title.
        if [ "${is_ours}" = "true" ] || { [ -n "${name}" ] && [ -n "${window_title:-}" ] && [ "${name}" = "${window_title}" ]; }; then
            name_field=""
        elif [ -n "${name}" ]; then
            name=$(printf '%s' "${name}" | tr '\n\r' ' ')
            name_field=" name=${name}"
        fi
        if ! [[ "${width}" =~ ^[0-9]+$ ]]; then
            width="unavailable"
        elif [ "${width}" -gt 1200 ] && [ "${opacity}" -ge "${max_op}" ]; then
            max_op="${opacity}"
            predicted="${wid_norm}"
        fi
        printf 'child index=%s wid=%s map=%s width=%s opacity=%s steam_input_focus=%s wm_class=%s is_ours=%s%s\n' \
            "$((child_count - 1))" "${wid_norm}" "${map_state}" "${width}" "${opacity_log}" \
            "${focus_val}" "${class_val}" "${is_ours}" "${name_field}"
    done <<< "${snap}"

    if [ -z "${predicted}" ]; then
        predicted="unavailable"
    fi
    printf 'predicted_overlay_wid=%s\n' "${predicted}"
    printf '%s\n' "children_order=assumed_top_first"
    printf 'census_truncated=%s\n' "${truncated}"
}

# One DEBUG-GAMESCOPE block. Synchronous. Callers gate and background it.
# Parameters:
#   $1 kind (spawn|respawn|pause)
#   $2 window id (may be empty)
#   $3 lookup path
#   $4 --onlyvisible PID hit count (may be empty)
#   $5 $6 requested width height
#   $7 $8 override width height
#   $9 popup_position
#   $10 dialog_tool
#   $11 pause_available
#   $12 pause_duration
gamescope_overlay_debug_emit() {
    local kind="${1:-spawn}"
    local window_id="${2:-}"
    local lookup_path="${3:-}"
    local pid_hits="${4:-}"
    local req_w="${5:-}"
    local req_h="${6:-}"
    local ovr_w="${7:-}"
    local ovr_h="${8:-}"
    local pos="${9:-}"
    local tool="${10:-}"
    local pause_ok="${11:-false}"
    local pause_min="${12:-}"
    local buttons geom_w="" geom_h="" geom="unavailable"
    local rb_overlay="unavailable" rb_focus="unavailable" rb_opacity="unavailable"
    local census_out root_size="unavailable" focus_blob line
    local mouse_raw keyboard_raw focus_raw focused_raw scaling_raw scale_raw
    local mouse_dec keyboard_dec focus_dec focused_log extra_focus=""

    buttons=$(gamescope_overlay_debug_button_summary "${tool}" "${pause_ok}" "${pause_min}" "${kind}")
    if [ -z "${req_w}" ] || [ -z "${req_h}" ]; then
        req_w="unavailable"
        req_h=""
    fi
    if [ -z "${ovr_w}" ] || [ -z "${ovr_h}" ]; then
        ovr_w="unavailable"
        ovr_h=""
    fi
    if [ -z "${pos}" ]; then
        pos="unavailable"
    fi
    if [ -z "${tool}" ]; then
        tool="unavailable"
    fi
    if [ -z "${lookup_path}" ]; then
        lookup_path="unavailable"
    fi
    if [ -z "${pid_hits}" ]; then
        pid_hits="unavailable"
    fi
    if [ -z "${window_id}" ]; then
        window_id="unavailable"
    else
        local winfo
        winfo=$(_gs_debug_probe xwininfo -id "${window_id}")
        if [[ "${winfo}" =~ Width:[[:space:]]*([0-9]+) ]]; then
            geom_w="${BASH_REMATCH[1]}"
        fi
        if [[ "${winfo}" =~ Height:[[:space:]]*([0-9]+) ]]; then
            geom_h="${BASH_REMATCH[1]}"
        fi
        if [ -n "${geom_w}" ] && [ -n "${geom_h}" ]; then
            geom="${geom_w}x${geom_h}"
        fi
        rb_overlay=$(_gs_debug_xprop_value "${window_id}" "STEAM_OVERLAY")
        rb_focus=$(_gs_debug_xprop_value "${window_id}" "STEAM_INPUT_FOCUS")
        rb_opacity=$(_gs_debug_xprop_value "${window_id}" "_NET_WM_WINDOW_OPACITY")
    fi

    if [ "${window_id}" = "unavailable" ]; then
        census_out=$(gamescope_overlay_scan_children "")
    else
        census_out=$(gamescope_overlay_scan_children "${window_id}")
    fi
    root_size=$(printf '%s\n' "${census_out}" | awk -F= '/^root_size=/{print substr($0, index($0, "=") + 1); exit}')
    if [ -z "${root_size}" ]; then
        root_size="unavailable"
    fi

    focus_blob=$(_gs_debug_probe xprop -root \
        GAMESCOPE_MOUSE_FOCUS_DISPLAY \
        GAMESCOPE_KEYBOARD_FOCUS_DISPLAY \
        GAMESCOPE_FOCUS_DISPLAY \
        GAMESCOPE_FOCUSED_WINDOW \
        GAMESCOPE_SCALING_FILTER \
        STEAM_SCREEN_SCALE)
    mouse_raw=$(_gs_debug_focus_line "${focus_blob}" "GAMESCOPE_MOUSE_FOCUS_DISPLAY")
    keyboard_raw=$(_gs_debug_focus_line "${focus_blob}" "GAMESCOPE_KEYBOARD_FOCUS_DISPLAY")
    focus_raw=$(_gs_debug_focus_line "${focus_blob}" "GAMESCOPE_FOCUS_DISPLAY")
    focused_raw=$(_gs_debug_focus_line "${focus_blob}" "GAMESCOPE_FOCUSED_WINDOW")
    scaling_raw=$(_gs_debug_focus_line "${focus_blob}" "GAMESCOPE_SCALING_FILTER")
    scale_raw=$(_gs_debug_focus_line "${focus_blob}" "STEAM_SCREEN_SCALE")
    mouse_dec=$(gamescope_decode_cardinal_display "${mouse_raw}")
    keyboard_dec=$(gamescope_decode_cardinal_display "${keyboard_raw}")
    focus_dec=$(gamescope_decode_cardinal_display "${focus_raw}")
    if [ "${focused_raw}" = "unavailable" ]; then
        focused_log="unavailable"
    else
        focused_log="${focused_raw#*=}"
        focused_log=$(printf '%s' "${focused_log}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    fi
    if [ "${scaling_raw}" != "unavailable" ]; then
        extra_focus="${extra_focus} scaling_filter=${scaling_raw#*=}"
    fi
    if [ "${scale_raw}" != "unavailable" ]; then
        extra_focus="${extra_focus} screen_scale=${scale_raw#*=}"
    fi
    extra_focus=$(printf '%s' "${extra_focus}" | sed 's/^[[:space:]]*//')

    local requested override
    if [ "${req_h}" = "" ] && [ "${req_w}" = "unavailable" ]; then
        requested="unavailable"
    else
        requested="${req_w}x${req_h}"
    fi
    if [ "${ovr_h}" = "" ] && [ "${ovr_w}" = "unavailable" ]; then
        override="unavailable"
    else
        override="${ovr_w}x${ovr_h}"
    fi

    _gs_debug_log "DEBUG-GAMESCOPE begin kind=${kind} root_size=${root_size} requested=${requested} override=${override} popup_position=${pos} dialog_tool=${tool} pause_available=${pause_ok} pause_duration=${pause_min:-unavailable} buttons=${buttons} lookup=${lookup_path} wid=${window_id} pid_visible_hits=${pid_hits} geometry=${geom} steam_overlay=${rb_overlay} steam_input_focus=${rb_focus} opacity=${rb_opacity} mouse_focus_raw=${mouse_raw} mouse_focus=${mouse_dec} keyboard_focus_raw=${keyboard_raw} keyboard_focus=${keyboard_dec} focus_display_raw=${focus_raw} focus_display=${focus_dec} focused_window=${focused_log}${extra_focus:+ ${extra_focus}}"
    while IFS= read -r line; do
        case "${line}" in
            root_size=*) continue ;;
            "") continue ;;
        esac
        _gs_debug_log "DEBUG-GAMESCOPE ${line}"
    done <<< "${census_out}"
    _gs_debug_log "DEBUG-GAMESCOPE end kind=${kind}"
}

# Extract one atom line from an xprop -root blob. Prints "unavailable" if absent.
# Parameters: $1 blob, $2 atom name
_gs_debug_focus_line() {
    local blob="${1:-}"
    local atom="${2:-}"
    local line
    if [ -z "${blob}" ]; then
        printf '%s\n' "unavailable"
        return 0
    fi
    while IFS= read -r line; do
        if [[ "${line}" == "${atom}"* ]]; then
            if [[ "${line}" == *"not found"* ]]; then
                printf '%s\n' "unavailable"
            else
                printf '%s\n' "${line}"
            fi
            return 0
        fi
    done <<< "${blob}"
    printf '%s\n' "unavailable"
}

# Log one INFO line when log_to_file exists. Strips CR/LF from the message.
# Parameters: $1 message
_gs_debug_log() {
    local message="${1:-}"
    message=$(printf '%s' "${message}" | tr '\n\r' ' ')
    if type log_to_file >/dev/null 2>&1; then
        log_to_file "INFO" "${message}"
    fi
}

# Gate and emit one block after apply_gamescope_overlay_atoms.
# Does nothing unless the flag is on and env_type is gamescope.
# The same window id (or the same missed PID) is logged once, so the 2s poll
# does not emit again. Probes run in the background unless
# GAMESCOPE_OVERLAY_DEBUG_SYNC=true.
# Parameters: $1 window id, $2 lookup path, $3 popup pid, $4 optional kind
gamescope_overlay_debug_on_apply() {
    local window_id="${1:-}"
    local lookup_path="${2:-}"
    local target_pid="${3:-}"
    local kind="${4:-${gamescope_debug_event:-spawn}}"
    if [ "${env_type:-}" != "gamescope" ]; then
        return 0
    fi
    if ! gamescope_overlay_debug_enabled; then
        return 0
    fi
    local gate="${window_id:-miss:${target_pid:-none}}"
    if [ "${GAMESCOPE_DEBUG_LOGGED_KEY:-}" = "${gate}" ]; then
        return 0
    fi
    GAMESCOPE_DEBUG_LOGGED_KEY="${gate}"
    local req_w="${gamescope_debug_requested_w:-}"
    local req_h="${gamescope_debug_requested_h:-}"
    local ovr_w="${gamescope_debug_override_w:-}"
    local ovr_h="${gamescope_debug_override_h:-}"
    local pos="${popup_position:-}"
    local tool="${dialog_tool:-}"
    local pause_ok="${pause_available:-false}"
    local pause_min="${pause_duration:-}"
    local hits="${FIND_WINDOW_PID_VISIBLE_COUNT:-}"
    if [ "${GAMESCOPE_OVERLAY_DEBUG_SYNC:-}" = "true" ]; then
        gamescope_overlay_debug_emit "${kind}" "${window_id}" "${lookup_path}" "${hits}" \
            "${req_w}" "${req_h}" "${ovr_w}" "${ovr_h}" "${pos}" "${tool}" "${pause_ok}" "${pause_min}" || true
    else
        (
            gamescope_overlay_debug_emit "${kind}" "${window_id}" "${lookup_path}" "${hits}" \
                "${req_w}" "${req_h}" "${ovr_w}" "${ovr_h}" "${pos}" "${tool}" "${pause_ok}" "${pause_min}" || true
        ) &
    fi
    return 0
}

# Item 7: exit of a spawn, respawn, or pause notice. No X probes.
# Parameters: $1 exit code, $2 whether the pause handler ran (true/false), $3 kind
gamescope_overlay_debug_log_exit() {
    local code="${1:-}"
    local pause_ran="${2:-false}"
    local kind="${3:-${gamescope_debug_event:-spawn}}"
    local ts
    if [ "${env_type:-}" != "gamescope" ]; then
        return 0
    fi
    if ! gamescope_overlay_debug_enabled; then
        return 0
    fi
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    _gs_debug_log "DEBUG-GAMESCOPE exit kind=${kind} exit_code=${code} pause_handler_ran=${pause_ran} timestamp=${ts}"
}
