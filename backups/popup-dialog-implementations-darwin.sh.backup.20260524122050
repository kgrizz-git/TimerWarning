#!/bin/bash

###############################################################################
# Sleep Warning System - macOS Popup Dialog (osascript)
#
# Spawns display alert in background; sets popup_pid and writes button choice
# to POPUP_DARWIN_RESULT_FILE for pause handling.
###############################################################################

if [ -z "${POPUP_DIALOG_DARWIN_LOADED:-}" ]; then
    POPUP_DIALOG_DARWIN_LOADED=1

    _darwin_escape_applescript() {
        # Escape backslashes and double quotes for AppleScript strings
        local s="$1"
        s="${s//\\/\\\\}"
        s="${s//\"/\\\"}"
        printf '%s' "${s}"
    }

    _popup_spawn_warning_dialog_darwin() {
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

        local pause_button_label=""
        local applescript

        if [ "${pause_available}" = "true" ] && [ -n "${pause_duration}" ]; then
            pause_button_label="Pause ${pause_duration} min"
            applescript=$(cat <<APPLESCRIPT
set dialogResult to button returned of (display alert "${safe_text}" with title "${safe_title}" buttons {"OK", "${pause_button_label}"} default button "OK" as warning)
do shell script "echo " & quoted form of dialogResult & " > " & quoted form of "${POPUP_DARWIN_RESULT_FILE}"
APPLESCRIPT
)
        else
            applescript=$(cat <<APPLESCRIPT
set dialogResult to button returned of (display alert "${safe_text}" with title "${safe_title}" buttons {"OK"} default button "OK" as warning)
do shell script "echo " & quoted form of dialogResult & " > " & quoted form of "${POPUP_DARWIN_RESULT_FILE}"
APPLESCRIPT
)
        fi

        osascript -e "${applescript}" >/dev/null 2>&1 &
        popup_pid=$!
        return 0
    }

    _popup_maybe_handle_pause_click_darwin() {
        local result=""
        if [ -n "${POPUP_DARWIN_RESULT_FILE:-}" ] && [ -f "${POPUP_DARWIN_RESULT_FILE}" ]; then
            result=$(cat "${POPUP_DARWIN_RESULT_FILE}" 2>/dev/null | tr -d '\n')
            rm -f "${POPUP_DARWIN_RESULT_FILE}" 2>/dev/null
        fi
        if [ -z "${result}" ]; then
            return 1
        fi
        case "${result}" in
            Pause*)
                if type activate_pause >/dev/null 2>&1 && [ -n "${pause_duration}" ]; then
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

    _darwin_display_notification() {
        local title="$1"
        local message="$2"
        local safe_title safe_message
        safe_title="$(_darwin_escape_applescript "${title}")"
        safe_message="$(_darwin_escape_applescript "${message}")"
        osascript -e "display notification \"${safe_message}\" with title \"${safe_title}\"" >/dev/null 2>&1
    }
fi
