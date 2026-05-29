#!/bin/bash

###############################################################################
# Sleep Warning System - macOS Popup Dialog Implementations
#
# Provides two popup paths and a dispatcher:
#
#   1. Fullscreen tkinter blocker  (popup-blocker-darwin.py)
#      - Dark full-screen overlay; OK button locked for min_display_seconds
#      - Optional pyobjc boost to NSScreenSaverWindowLevel when available
#      - Falls back to osascript automatically if Python is missing
#
#   2. osascript display alert     (original, kept as fallback)
#      - Small system alert sheet; always available
#
# Public functions (called by popup-display-darwin.sh):
#   _popup_spawn_warning_dialog_darwin base_message full_message
#   _popup_maybe_handle_pause_click_darwin
#   _darwin_display_notification title message
#
# Internal functions:
#   _darwin_escape_applescript   — escapes text for AppleScript strings
#   _popup_json_escape           — pure-bash JSON string escape
#   _popup_darwin_has_blocker    — true if Python blocker is usable
#   _popup_spawn_blocker_darwin  — spawns popup-blocker-darwin.py
#   _popup_spawn_osascript_darwin — spawns legacy osascript alert
###############################################################################

if [ -z "${POPUP_DIALOG_DARWIN_LOADED:-}" ]; then
    POPUP_DIALOG_DARWIN_LOADED=1

    # ── AppleScript string escaping ──────────────────────────────────────────
    _darwin_escape_applescript() {
        local s="$1"
        s="${s//\\/\\\\}"
        s="${s//\"/\\\"}"
        printf '%s' "${s}"
    }

    # ── Pure-bash JSON string escaping ───────────────────────────────────────
    # Escapes a string for embedding as a JSON value (between double quotes).
    _popup_json_escape() {
        local s="$1"
        s="${s//\\/\\\\}"          # \ → \\
        s="${s//\"/\\\"}"          # " → \"
        local tab=$'\t'
        s="${s//${tab}/\\t}"       # TAB → \t
        local nl=$'\n'
        s="${s//${nl}/\\n}"        # LF → \n
        local cr=$'\r'
        s="${s//${cr}/\\r}"        # CR → \r
        printf '%s' "${s}"
    }

    # ── Blocker availability check ───────────────────────────────────────────
    # Returns 0 (true) when popup-blocker-darwin.py and python3 are available.
    _popup_darwin_has_blocker() {
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        [ -f "${script_dir}/popup-blocker-darwin.py" ] \
            && command -v python3 >/dev/null 2>&1
    }

    # ── Fullscreen blocker spawn ─────────────────────────────────────────────
    # Uses variables from the caller (show_warning_darwin) scope:
    #   min_display_time, popup_auto_close, pause_available, pause_duration,
    #   POPUP_AUTO_CLOSE_DELAY_SECONDS, POPUP_DARWIN_RESULT_FILE
    #
    # Args:
    #   $1 — base_message (message without countdown suffix, for clean display)
    _popup_spawn_blocker_darwin() {
        local base_text="$1"
        popup_pid=""

        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        local blocker="${script_dir}/popup-blocker-darwin.py"

        POPUP_DARWIN_RESULT_FILE="${POPUP_DARWIN_RESULT_FILE:-$(mktemp)}"
        : > "${POPUP_DARWIN_RESULT_FILE}"

        # Compute auto_close_seconds for the Python script:
        #   If auto-close is enabled: min_display + delay (or just delay if no min)
        local min_secs="${min_display_time:-0}"
        local auto_close_secs=0
        if [ "${popup_auto_close:-false}" = "true" ]; then
            local delay="${POPUP_AUTO_CLOSE_DELAY_SECONDS:-10}"
            if [ "${min_secs}" -gt 0 ]; then
                auto_close_secs=$((min_secs + delay))
            else
                auto_close_secs="${delay}"
            fi
        fi

        # Determine pause params
        local pa="false"
        local pd=0
        if [ "${pause_available:-false}" = "true" ] && [ -n "${pause_duration:-}" ]; then
            pa="true"
            pd="${pause_duration}"
        fi

        # Build JSON payload using pure-bash escaping
        local esc_msg esc_title esc_rf
        esc_msg="$(_popup_json_escape "${base_text}")"
        esc_title="$(_popup_json_escape "ALERT: Restricted time window")"
        esc_rf="$(_popup_json_escape "${POPUP_DARWIN_RESULT_FILE}")"

        local json_payload
        json_payload=$(cat <<JSON
{
  "title": "${esc_title}",
  "message": "${esc_msg}",
  "min_display_seconds": ${min_secs},
  "auto_close_seconds": ${auto_close_secs},
  "pause_available": ${pa},
  "pause_duration_minutes": ${pd},
  "result_file": "${esc_rf}"
}
JSON
)

        echo "${json_payload}" | python3 "${blocker}" >/dev/null 2>&1 &
        popup_pid=$!
        return 0
    }

    # ── Legacy osascript alert spawn ─────────────────────────────────────────
    # Phase 2.3: Enforces min_display_time and auto-close for the osascript
    # fallback path by running a re-spawn loop inside a background subshell.
    # The outer popup_run_with_watchdog in show_warning_darwin provides the
    # absolute POPUP_ABSOLUTE_MAX_SECONDS ceiling.
    #
    # Uses variables from the caller scope:
    #   min_display_time, popup_auto_close, POPUP_AUTO_CLOSE_DELAY_SECONDS,
    #   pause_available, pause_duration, POPUP_DARWIN_RESULT_FILE.
    #
    # Args:
    #   $1 — full_message (message with countdown suffix, used by osascript)
    _popup_spawn_osascript_darwin() {
        local popup_text="$1"
        popup_pid=""

        if ! command -v osascript >/dev/null 2>&1; then
            return 1
        fi

        local title="ALERT: Restricted time window"
        local safe_text safe_title
        safe_text="$(_darwin_escape_applescript "${popup_text}")"
        safe_title="$(_darwin_escape_applescript "${title}")"

        POPUP_DARWIN_RESULT_FILE="${POPUP_DARWIN_RESULT_FILE:-$(mktemp)}"
        : > "${POPUP_DARWIN_RESULT_FILE}"

        # Capture timing settings from outer scope into local vars for subshell
        local _min_disp="${min_display_time:-0}"
        local _auto_close="${popup_auto_close:-false}"
        local _ac_delay="${POPUP_AUTO_CLOSE_DELAY_SECONDS:-10}"
        local _pa="${pause_available:-false}"
        local _pd="${pause_duration:-}"
        local _result_file="${POPUP_DARWIN_RESULT_FILE}"

        # Build buttons fragment (reused across re-spawns)
        local _buttons_fragment
        if [ "${_pa}" = "true" ] && [ -n "${_pd}" ]; then
            _buttons_fragment="buttons {\"OK\", \"Pause ${_pd} min\"} default button \"OK\""
        else
            _buttons_fragment="buttons {\"OK\"} default button \"OK\""
        fi

        # Background subshell: re-opens osascript until min_display_time is met,
        # then applies auto-close (giving up after) on the final presentation.
        # SIGTERM from the watchdog will stop the loop and kill the current dialog.
        (
            _inner_osc_pid=""
            trap '
                [ -n "${_inner_osc_pid}" ] && kill "${_inner_osc_pid}" 2>/dev/null
                exit 0
            ' TERM INT

            _start_epoch=$(date +%s)

            while true; do
                _now=$(date +%s)
                _elapsed=$((_now - _start_epoch))
                _remaining=$((_min_disp - _elapsed))

                # On this round, has min-display elapsed yet?
                if [ "${_remaining}" -le 0 ] && [ "${_auto_close}" = "true" ]; then
                    # Final dialog: auto-closes after delay
                    _giving_up=" giving up after ${_ac_delay}"
                else
                    _giving_up=""
                fi

                _applescript="set dialogResult to button returned of (display alert \"${safe_text}\" with title \"${safe_title}\" ${_buttons_fragment} as warning${_giving_up})
do shell script \"echo \" & quoted form of dialogResult & \" > \" & quoted form of \"${_result_file}\""

                osascript -e "${_applescript}" >/dev/null 2>&1 &
                _inner_osc_pid=$!
                wait "${_inner_osc_pid}" 2>/dev/null
                _inner_osc_pid=""

                _now=$(date +%s)
                _elapsed=$((_now - _start_epoch))

                # If min-display satisfied (or auto-close fired), exit loop
                if [ "${_elapsed}" -ge "${_min_disp}" ]; then
                    break
                fi
                # User dismissed before min-display — re-open immediately
            done
        ) &
        popup_pid=$!
        return 0
    }

    # ── Dispatcher ───────────────────────────────────────────────────────────
    # Tries the fullscreen blocker first; falls back to osascript.
    #
    # Args:
    #   $1 — full_message  (full text with countdown suffix, for osascript)
    #   $2 — base_message  (text without suffix, for the blocker — optional,
    #                        defaults to full_message)
    _popup_spawn_warning_dialog_darwin() {
        local full_msg="$1"
        local base_msg="${2:-${full_msg}}"
        popup_pid=""

        if _popup_darwin_has_blocker; then
            _popup_spawn_blocker_darwin "${base_msg}"
            if [ -n "${popup_pid}" ] && [[ "${popup_pid}" =~ ^[0-9]+$ ]]; then
                # Phase 2.2: Give the process 0.3 s to start then verify it is still alive.
                # python3 exits immediately if tkinter/pyobjc is missing or JSON is bad.
                sleep 0.3
                if kill -0 "${popup_pid}" 2>/dev/null; then
                    return 0
                fi
                # Process died — capture exit code and log for diagnosis
                local _blocker_exit=0
                wait "${popup_pid}" 2>/dev/null
                _blocker_exit=$?
                if type log_to_file >/dev/null 2>&1; then
                    log_to_file "WARNING" \
                        "macOS: Python blocker (PID ${popup_pid}) exited immediately (code ${_blocker_exit}); falling back to osascript"
                fi
                popup_pid=""
            fi
            if type log_to_file >/dev/null 2>&1; then
                log_to_file "WARNING" "macOS: blocker failed to spawn, falling back to osascript"
            fi
        fi

        _popup_spawn_osascript_darwin "${full_msg}"
    }

    # ── Pause result handler ─────────────────────────────────────────────────
    # Reads POPUP_DARWIN_RESULT_FILE; activates pause if the Pause button was
    # clicked. Works for both the blocker and osascript paths (both write
    # "Pause N min" to the result file).
    _popup_maybe_handle_pause_click_darwin() {
        local result=""
        if [ -n "${POPUP_DARWIN_RESULT_FILE:-}" ] && [ -f "${POPUP_DARWIN_RESULT_FILE}" ]; then
            result=$(cat "${POPUP_DARWIN_RESULT_FILE}" 2>/dev/null | tr -d '\n')
            rm -f "${POPUP_DARWIN_RESULT_FILE}" 2>/dev/null
        fi
        [ -z "${result}" ] && return 1
        case "${result}" in
            Pause*)
                if type activate_pause >/dev/null 2>&1 && [ -n "${pause_duration:-}" ]; then
                    activate_pause "${pause_duration}"
                    if type log_to_file >/dev/null 2>&1; then
                        log_to_file "INFO" "User activated pause for ${pause_duration} minutes (macOS)"
                    fi
                fi
                return 0
                ;;
        esac
        return 1
    }

    # ── System notification fallback ─────────────────────────────────────────
    _darwin_display_notification() {
        local ntitle="$1"
        local nmsg="$2"
        local safe_title safe_msg
        safe_title="$(_darwin_escape_applescript "${ntitle}")"
        safe_msg="$(_darwin_escape_applescript "${nmsg}")"
        osascript -e "display notification \"${safe_msg}\" with title \"${safe_title}\"" \
            >/dev/null 2>&1
    }

fi
