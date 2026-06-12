#!/bin/bash

###############################################################################
# Sleep Warning System - macOS Configuration Dialogs (osascript + tkinter)
#
# Simple prompts use AppleScript (activate before each dialog so it opens in
# front). Multi-column lists use tkinter when available; all tkinter windows use
# configure_dialogs_darwin_window.apply_initial_frontmost() on open.
###############################################################################

if [ -z "${CONFIGURE_DIALOGS_DARWIN_LOADED:-}" ]; then
    CONFIGURE_DIALOGS_DARWIN_LOADED=1

    _CD_DARWIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    _cd_darwin_escape() {
        local s="$1"
        s="${s//\\/\\\\}"
        s="${s//\"/\\\"}"
        s="${s//$'\n'/ }"
        printf '%s' "${s}"
    }

    # Convert literal \n sequences to real newlines (shared Linux dialog strings).
    _cd_darwin_preprocess_message() {
        local s="$1"
        s="${s//\\n/$'\n'}"
        printf '%s' "${s}"
    }

    _cd_darwin_run_applescript() {
        osascript - "$@" 2>/dev/null
    }

    _cd_darwin_trim() {
        local s="$1"
        s="${s//$'\r'/}"
        s="${s//$'\n'/}"
        s="${s#"${s%%[![:space:]]*}"}"
        s="${s%"${s##*[![:space:]]}"}"
        printf '%s' "${s}"
    }

    _cd_darwin_is_likely_column_name() {
        local arg="$1"
        [[ "${arg}" =~ ^[A-Za-z]$ ]] && return 0
        [[ ! "${arg}" =~ \  ]] && [[ "${arg}" =~ ^[A-Za-z]+$ ]] && [ ${#arg} -le 12 ] && return 0
        [[ "${arg}" =~ ^[A-Za-z][A-Za-z\ ]*[A-Za-z]$ ]] && [ ${#arg} -le 40 ] && return 0
        return 1
    }

    # Parse show_multi_column_list_dialog args after title, message, width, height.
    # Sets: _cd_print_column, _cd_num_columns, _cd_column_names[], _cd_data[]
    _cd_darwin_parse_multi_column_args() {
        _cd_print_column="${1:-1}"
        shift || true

        _cd_column_names=()
        _cd_num_columns=0

        if [ $# -ge 4 ]; then
            local fourth_arg="$4"
            if _cd_darwin_is_likely_column_name "${fourth_arg}"; then
                _cd_column_names=("$1" "$2" "$3" "$4")
                _cd_num_columns=4
                shift 4
            elif [ $# -ge 3 ] && _cd_darwin_is_likely_column_name "$3"; then
                _cd_column_names=("$1" "$2" "$3")
                _cd_num_columns=3
                shift 3
            else
                _cd_column_names=("$1" "$2")
                _cd_num_columns=2
                shift 2
            fi
        elif [ $# -ge 3 ] && _cd_darwin_is_likely_column_name "$3"; then
            _cd_column_names=("$1" "$2" "$3")
            _cd_num_columns=3
            shift 3
        elif [ $# -ge 2 ]; then
            _cd_column_names=("$1" "$2")
            _cd_num_columns=2
            shift 2
        elif [ $# -ge 1 ]; then
            _cd_column_names=("$1")
            _cd_num_columns=1
            shift 1
        fi

        _cd_data=("$@")
    }

    # Produce a JSON-encoded string (with surrounding double-quotes).
    # Pure-bash: no subprocess, so safe to call dozens of times per dialog.
    # Handles the characters that appear in config wizard strings (ASCII + UTF-8 text).
    _cd_darwin_json_escape() {
        local s="$1"
        s="${s//\\/\\\\}"        # \ → \\ (must be first)
        s="${s//\"/\\\"}"        # " → \"
        s="${s//$'\t'/\\t}"      # tab → \t
        s="${s//$'\n'/\\n}"      # newline → \n
        s="${s//$'\r'/\\r}"      # CR → \r
        printf '"%s"' "${s}"
    }

    # Cached result: "" = unchecked, "yes" = available, "no" = unavailable
    _DARWIN_TKINTER_AVAILABLE=""

    _cd_darwin_has_tkinter() {
        if [ -z "${_DARWIN_TKINTER_AVAILABLE}" ]; then
            if command -v python3 >/dev/null 2>&1 && python3 -c "import tkinter" >/dev/null 2>&1; then
                _DARWIN_TKINTER_AVAILABLE="yes"
            else
                _DARWIN_TKINTER_AVAILABLE="no"
            fi
        fi
        [ "${_DARWIN_TKINTER_AVAILABLE}" = "yes" ]
    }

    _cd_darwin_has_table_dialog() {
        [ -f "${_CD_DARWIN_DIR}/configure-dialogs-darwin-table.py" ] && _cd_darwin_has_tkinter
    }

    _cd_darwin_has_list_dialog() {
        [ -f "${_CD_DARWIN_DIR}/configure_dialogs_darwin_list_ui.py" ] && _cd_darwin_has_tkinter
    }

    _cd_darwin_has_time_dialog() {
        [ -f "${_CD_DARWIN_DIR}/configure-dialogs-darwin-time.py" ] && _cd_darwin_has_tkinter
    }

    _cd_darwin_has_text_dialog() {
        [ -f "${_CD_DARWIN_DIR}/configure-dialogs-darwin-text.py" ] && _cd_darwin_has_tkinter
    }

    _CD_DARWIN_DAEMON_ACTIVE=""
    _CD_DARWIN_DAEMON_PID=""
    _CD_DARWIN_DAEMON_RFD=""
    _CD_DARWIN_DAEMON_WFD=""
    _CD_DARWIN_DAEMON_LAST_RESPONSE=""
    _CD_RESP_OK=""
    _CD_RESP_CANCELLED=""
    _CD_RESP_SHOWN=""
    _CD_RESP_VALUE=""
    _CD_RESP_VALUE_FETCHED=""
    _CD_FIRST_OSASCRIPT_DIALOG="pending"
    _CD_LAST_DIALOG_END_MS=0
    _CD_LAST_DIALOG_WAS_TK="no"

    _cd_darwin_now_ms() {
        if [ -n "${EPOCHREALTIME:-}" ]; then
            awk -v t="${EPOCHREALTIME}" 'BEGIN{printf "%.0f", t * 1000}'
        else
            echo $(($(date +%s) * 1000))
        fi
    }

    _cd_darwin_profile_log() {
        [ "${CONFIGURE_PROFILE:-}" = "1" ] || return 0
        echo "CONFIGURE_PROFILE dialog=${1} prep_ms=${2} ui_ms=${3}${4:+ ${4}}" >&2
    }

    # Pure-bash JSON boolean probe (daemon responses use unquoted true/false).
    _cd_darwin_json_field_true() {
        local json="$1"
        local field="$2"
        [[ "${json}" =~ \"${field}\"[[:space:]]*:[[:space:]]*true ]]
    }

    _cd_darwin_parse_last_response() {
        local json="${_CD_DARWIN_DAEMON_LAST_RESPONSE}"
        _CD_RESP_OK="no"
        _CD_RESP_CANCELLED="no"
        _CD_RESP_SHOWN="no"
        _CD_RESP_VALUE=""
        _CD_RESP_VALUE_FETCHED=""
        if _cd_darwin_json_field_true "${json}" "ok"; then
            _CD_RESP_OK="yes"
        fi
        if _cd_darwin_json_field_true "${json}" "cancelled"; then
            _CD_RESP_CANCELLED="yes"
        fi
        if _cd_darwin_json_field_true "${json}" "shown"; then
            _CD_RESP_SHOWN="yes"
        fi
    }

    _cd_darwin_response_extract_simple_value() {
        local json="${_CD_DARWIN_DAEMON_LAST_RESPONSE}"
        # Fast path for daemon values without JSON escapes. This covers menu
        # numbers, day names, time ranges, and most labels without spawning
        # python3 on every dialog transition.
        if [[ "${json}" =~ \"value\"[[:space:]]*:[[:space:]]*\"([^\"\\]*)\" ]]; then
            printf '%s' "${BASH_REMATCH[1]}"
            return 0
        fi
        return 1
    }

    _cd_darwin_response_extract_value() {
        if [ "${_CD_RESP_VALUE_FETCHED}" = "yes" ]; then
            printf '%s' "${_CD_RESP_VALUE}"
            return 0
        fi
        if _CD_RESP_VALUE="$(_cd_darwin_response_extract_simple_value)"; then
            _CD_RESP_VALUE_FETCHED="yes"
            printf '%s' "${_CD_RESP_VALUE}"
            return 0
        fi
        _CD_RESP_VALUE=$(
            python3 -c 'import json,sys; d=json.load(sys.stdin); v=d.get("value"); print("" if v is None else v)' \
                <<< "${_CD_DARWIN_DAEMON_LAST_RESPONSE}" 2>/dev/null || true
        )
        _CD_RESP_VALUE_FETCHED="yes"
        printf '%s' "${_CD_RESP_VALUE}"
    }

    _cd_darwin_response_is_ok() {
        [ "${_CD_RESP_OK:-no}" = "yes" ]
    }

    _cd_darwin_response_is_cancelled() {
        [ "${_CD_RESP_CANCELLED:-no}" = "yes" ]
    }

    # True when the daemon reported that the dialog window actually became
    # visible. A clean cancel of a shown window must NOT trigger the one-shot
    # fallback (that re-opened a duplicate window over the next menu).
    _cd_darwin_response_was_shown() {
        [ "${_CD_RESP_SHOWN:-no}" = "yes" ]
    }

    _cd_darwin_mark_dialog_end() {
        local backend="${1:-osascript}"
        _CD_LAST_DIALOG_END_MS=$(_cd_darwin_now_ms)
        if [ "${backend}" = "tk" ]; then
            _CD_LAST_DIALOG_WAS_TK="yes"
        else
            _CD_LAST_DIALOG_WAS_TK="no"
        fi
    }

    _cd_darwin_should_osascript_activate() {
        if [ "${_CD_FORCE_OSASCRIPT_ACTIVATE:-}" = "1" ]; then
            return 0
        fi
        if [ "${_CD_FIRST_OSASCRIPT_DIALOG:-pending}" = "pending" ]; then
            _CD_FIRST_OSASCRIPT_DIALOG="done"
            return 0
        fi
        if [ "${_CD_LAST_DIALOG_WAS_TK}" = "yes" ]; then
            return 0
        fi
        local now elapsed
        now=$(_cd_darwin_now_ms)
        if [ "${_CD_LAST_DIALOG_END_MS:-0}" -gt 0 ]; then
            elapsed=$((now - _CD_LAST_DIALOG_END_MS))
            if [ "${elapsed}" -lt 500 ]; then
                return 1
            fi
        fi
        return 0
    }

    _cd_darwin_osascript_activate_snippet() {
        if _cd_darwin_should_osascript_activate; then
            printf '    tell current application to activate\n'
        fi
    }

    _cd_darwin_daemon_stop() {
        if [ "${_CD_DARWIN_DAEMON_ACTIVE:-}" != "yes" ]; then
            return 0
        fi
        if [ -n "${_CD_DARWIN_DAEMON_WFD:-}" ]; then
            { printf '{"op":"quit"}\n' >&"${_CD_DARWIN_DAEMON_WFD}"; } 2>/dev/null || true
            read -r -t 3 -u "${_CD_DARWIN_DAEMON_RFD}" _ 2>/dev/null || true
            # Close the duplicated file descriptors
            exec {_CD_DARWIN_DAEMON_WFD}>&- 2>/dev/null || true
            exec {_CD_DARWIN_DAEMON_RFD}<&- 2>/dev/null || true
        fi
        if [ -n "${_CD_DARWIN_DAEMON_PID:-}" ]; then
            kill "${_CD_DARWIN_DAEMON_PID}" 2>/dev/null || true
            wait "${_CD_DARWIN_DAEMON_PID}" 2>/dev/null || true
        fi
        _CD_DARWIN_DAEMON_ACTIVE=""
        _CD_DARWIN_DAEMON_PID=""
        _CD_DARWIN_DAEMON_RFD=""
        _CD_DARWIN_DAEMON_WFD=""
    }

    _cd_darwin_daemon_start() {
        if [ "${_CD_DARWIN_DAEMON_ACTIVE:-}" = "yes" ]; then
            return 0
        fi
        if ! _cd_darwin_has_tkinter; then
            return 1
        fi
        local py_script="${_CD_DARWIN_DIR}/configure-dialogs-darwin-daemon.py"
        if [ ! -f "${py_script}" ]; then
            return 1
        fi

        coproc _CD_DARWIN_CP { python3 "${py_script}"; }

        # Duplicate coproc file descriptors to dynamically allocated stable descriptors
        # so they remain open and are inherited by subshells (command substitutions).
        if [ -n "${_CD_DARWIN_CP[0]:-}" ] && [ -n "${_CD_DARWIN_CP[1]:-}" ]; then
            exec {_CD_DARWIN_DAEMON_RFD}<&"${_CD_DARWIN_CP[0]}"
            exec {_CD_DARWIN_DAEMON_WFD}>&"${_CD_DARWIN_CP[1]}"
            _CD_DARWIN_DAEMON_PID=${_CD_DARWIN_CP_PID}
        else
            return 1
        fi

        local ready=""
        if ! read -r -t 30 -u "${_CD_DARWIN_DAEMON_RFD}" ready; then
            _cd_darwin_daemon_stop
            return 1
        fi
        if ! _cd_darwin_json_field_true "${ready}" "ready"; then
            _cd_darwin_daemon_stop
            return 1
        fi
        _CD_DARWIN_DAEMON_ACTIVE="yes"
        return 0
    }

    _cd_darwin_daemon_request() {
        local json_line="$1"
        if [ "${_CD_DARWIN_DAEMON_ACTIVE:-}" != "yes" ]; then
            return 1
        fi
        if ! printf '%s\n' "${json_line}" >&"${_CD_DARWIN_DAEMON_WFD}"; then
            _cd_darwin_daemon_stop
            return 1
        fi
        _CD_DARWIN_DAEMON_LAST_RESPONSE=""
        if ! read -r -t 600 -u "${_CD_DARWIN_DAEMON_RFD}" _CD_DARWIN_DAEMON_LAST_RESPONSE; then
            _cd_darwin_daemon_stop
            return 1
        fi
        _cd_darwin_parse_last_response
        _cd_darwin_mark_dialog_end tk
        return 0
    }

    _cd_darwin_build_table_json() {
        local title="$1"
        local message="$2"
        local width="$3"
        local height="$4"
        local print_column="$5"

        printf '{'
        printf '"title":%s,' "$(_cd_darwin_json_escape "${title}")"
        printf '"message":%s,' "$(_cd_darwin_json_escape "${message}")"
        printf '"width":%s,' "${width:-900}"
        printf '"height":%s,' "${height:-500}"
        printf '"print_column":%s,' "${print_column:-1}"
        printf '"columns":['
        local col first_col=1
        for col in "${_cd_column_names[@]}"; do
            [ "${first_col}" -eq 1 ] || printf ','
            first_col=0
            printf '%s' "$(_cd_darwin_json_escape "${col}")"
        done
        printf '],'
        printf '"rows":['
        local i=0 num_data="${#_cd_data[@]}" first_row=1
        while [ "${i}" -lt "${num_data}" ]; do
            [ "${first_row}" -eq 1 ] || printf ','
            first_row=0
            printf '['
            local c=0 first_cell=1
            while [ "${c}" -lt "${_cd_num_columns}" ] && [ $((i + c)) -lt "${num_data}" ]; do
                [ "${first_cell}" -eq 1 ] || printf ','
                first_cell=0
                printf '%s' "$(_cd_darwin_json_escape "${_cd_data[$((i + c))]}")"
                c=$((c + 1))
            done
            printf ']'
            i=$((i + _cd_num_columns))
        done
        printf ']'
        printf '}'
    }

    _cd_darwin_build_list_json() {
        local title="$1"
        local message="$2"
        local width="$3"
        local height="$4"
        shift 4

        # Defensive: width/height must be numeric or the JSON is malformed and the
        # daemon silently fails to show a window. Fall back to sane defaults if a
        # caller passes the dimensions in the wrong position.
        [[ "${width}" =~ ^[0-9]+$ ]] || width=500
        [[ "${height}" =~ ^[0-9]+$ ]] || height=300

        printf '{'
        printf '"title":%s,' "$(_cd_darwin_json_escape "${title}")"
        printf '"message":%s,' "$(_cd_darwin_json_escape "${message}")"
        printf '"width":%s,' "${width:-500}"
        printf '"height":%s,' "${height:-300}"
        printf '"items":['
        local item first=1
        for item in "$@"; do
            [ "${first}" -eq 1 ] || printf ','
            first=0
            printf '%s' "$(_cd_darwin_json_escape "${item}")"
        done
        printf ']'
        printf '}'
    }

    _cd_darwin_show_text_dialog() {
        local title="$1"
        local text="$2"
        local width="${3:-700}"
        local height="${4:-500}"
        local with_buttons="${5:-}"

        local prep_start prep_end ui_start ui_end json_payload
        prep_start=$(_cd_darwin_now_ms)

        json_payload=$(
            printf '{'
            printf '"title":%s,' "$(_cd_darwin_json_escape "${title}")"
            printf '"width":%s,' "${width}"
            printf '"height":%s,' "${height}"
            printf '"text":%s' "$(_cd_darwin_json_escape "${text}")"
            if [ "${with_buttons}" = "save" ]; then
                printf ','
                printf '"default_button":%s,' "$(_cd_darwin_json_escape "Yes, Save")"
                printf '"buttons":[%s,%s]' \
                    "$(_cd_darwin_json_escape "Yes, Save")" \
                    "$(_cd_darwin_json_escape "Back to Main Menu")"
            fi
            printf '}'
        )
        prep_end=$(_cd_darwin_now_ms)
        ui_start=${prep_end}

        local choice="" rc=1
        if _cd_darwin_daemon_start && _cd_darwin_daemon_request "{\"op\":\"text\",${json_payload:1}"; then
            if _cd_darwin_response_is_ok && ! _cd_darwin_response_is_cancelled; then
                choice=$(_cd_darwin_response_extract_value)
                rc=0
                if [ "${with_buttons}" = "save" ] && [ "${choice}" != "Yes, Save" ]; then
                    rc=1
                fi
            fi
        else
            local json_file py_script
            json_file=$(mktemp "${TMPDIR:-/tmp}/sw-darwin-text.XXXXXX.json")
            py_script="${_CD_DARWIN_DIR}/configure-dialogs-darwin-text.py"
            printf '%s\n' "${json_payload}" >"${json_file}"
            if [ -f "${py_script}" ]; then
                choice=$(python3 "${py_script}" <"${json_file}" 2>/dev/null)
                rc=$?
            fi
            rm -f "${json_file}"
        fi

        ui_end=$(_cd_darwin_now_ms)
        _cd_darwin_profile_log "text" "$((prep_end - prep_start))" "$((ui_end - ui_start))"

        if [ -n "${choice}" ]; then
            printf '%s\n' "${choice}"
        fi
        return "${rc}"
    }

    # Combined scrollable summary + save/back (avoids osascript after tkinter).
    # stdout: button label; return 0 = save, 1 = back/cancel
    show_summary_save_dialog_darwin() {
        local title="$1"
        local text="$2"
        local width="${3:-700}"
        local height="${4:-520}"
        local choice

        choice=$(_cd_darwin_show_text_dialog "${title}" "${text}" "${width}" "${height}" "save")
        choice=$(_cd_darwin_trim "${choice}")
        if [ "${choice}" = "Yes, Save" ]; then
            return 0
        fi
        return 1
    }

    _cd_darwin_run_table_oneshot() {
        local json_payload="$1"
        local json_file py_script result="" rc=1
        json_file=$(mktemp "${TMPDIR:-/tmp}/sw-darwin-table.XXXXXX.json")
        py_script="${_CD_DARWIN_DIR}/configure-dialogs-darwin-table.py"
        printf '%s\n' "${json_payload}" >"${json_file}"
        if [ -f "${py_script}" ]; then
            result=$(python3 "${py_script}" <"${json_file}" 2>/dev/null)
            rc=$?
        fi
        rm -f "${json_file}"
        if [ ${rc} -eq 0 ] && [ -n "${result}" ]; then
            echo "${result}"
            return 0
        fi
        return 1
    }

    _cd_darwin_show_table_with_json() {
        local json_payload="$1"
        local prep_ms="${2:-0}"
        local ui_start ui_end result="" rc=1
        ui_start=$(_cd_darwin_now_ms)

        local daemon_shown=0
        if [ "${CONFIGURE_DARWIN_NO_DAEMON:-}" != "1" ] && \
            _cd_darwin_daemon_start && \
            _cd_darwin_daemon_request "{\"op\":\"table\",${json_payload:1}"; then
            if _cd_darwin_response_was_shown; then
                daemon_shown=1
            fi
            if _cd_darwin_response_is_ok && ! _cd_darwin_response_is_cancelled; then
                result=$(_cd_darwin_response_extract_value)
                rc=0
            fi
        fi

        ui_end=$(_cd_darwin_now_ms)
        _cd_darwin_profile_log "table" "${prep_ms}" "$((ui_end - ui_start))"

        if [ ${rc} -eq 0 ] && [ -n "${result}" ]; then
            echo "${result}"
            return 0
        fi

        if [ "${daemon_shown}" -eq 1 ]; then
            return 1
        fi

        _cd_darwin_run_table_oneshot "${json_payload}"
        return $?
    }

    _cd_darwin_show_table_dialog() {
        local title="$1"
        local message="$2"
        local width="$3"
        local height="$4"
        local print_column="$5"
        # Uses _cd_column_names[], _cd_data[], _cd_num_columns from _cd_darwin_parse_multi_column_args.

        local prep_start prep_end json_payload
        prep_start=$(_cd_darwin_now_ms)
        
        if [ "${_CONFIGURE_GRID_CACHE_VALID:-false}" = "true" ] && \
           [ "${title}" = "${_CONFIGURE_GRID_TABLE_JSON_TITLE:-}" ] && \
           [ -n "${_CONFIGURE_GRID_TABLE_JSON:-}" ]; then
            json_payload="${_CONFIGURE_GRID_TABLE_JSON}"
            prep_end=$(_cd_darwin_now_ms)
        else
            json_payload=$(_cd_darwin_build_table_json "${title}" "${message}" "${width}" "${height}" "${print_column}")
            prep_end=$(_cd_darwin_now_ms)
            if [ "${_CONFIGURE_GRID_CACHE_VALID:-false}" = "true" ] && [ "${title}" = "View Weekly Hours Settings" ]; then
                _CONFIGURE_GRID_TABLE_JSON_TITLE="${title}"
                _CONFIGURE_GRID_TABLE_JSON="${json_payload}"
            fi
        fi

        _cd_darwin_show_table_with_json "${json_payload}" "$((prep_end - prep_start))"
    }

    _cd_darwin_show_time_dialog() {
        local title="$1"
        local start_time="${2:-}"
        local end_time="${3:-}"
        local day_name="${4:-}"
        local hint="${5:-}"

        local start_data="11 00 PM"
        local end_data="5 00 AM"
        if type parse_normalized_time_to_12h >/dev/null 2>&1; then
            if [ -n "${start_time}" ]; then
                start_data=$(parse_normalized_time_to_12h "${start_time}")
            fi
            if [ -n "${end_time}" ]; then
                end_data=$(parse_normalized_time_to_12h "${end_time}")
            fi
        fi

        local sh sm sap eh em eap
        read -r sh sm sap <<< "${start_data}"
        read -r eh em eap <<< "${end_data}"

        local prep_start prep_end ui_start ui_end json_payload result rc=1
        prep_start=$(_cd_darwin_now_ms)
        json_payload=$(
            printf '{'
            printf '"title":%s,' "$(_cd_darwin_json_escape "${title}")"
            printf '"day_name":%s,' "$(_cd_darwin_json_escape "${day_name}")"
            printf '"hint_text":%s,' "$(_cd_darwin_json_escape "${hint}")"
            printf '"width":520,"height":360,'
            printf '"start":{"hour":%s,"minute":%s,"ampm":%s},' "${sh}" "$(_cd_darwin_json_escape "${sm}")" "$(_cd_darwin_json_escape "${sap}")"
            printf '"end":{"hour":%s,"minute":%s,"ampm":%s}' "${eh}" "$(_cd_darwin_json_escape "${em}")" "$(_cd_darwin_json_escape "${eap}")"
            printf '}'
        )
        prep_end=$(_cd_darwin_now_ms)
        ui_start=${prep_end}

        if _cd_darwin_daemon_start && _cd_darwin_daemon_request "{\"op\":\"time\",${json_payload:1}"; then
            if _cd_darwin_response_is_ok && ! _cd_darwin_response_is_cancelled; then
                result=$(_cd_darwin_response_extract_value)
                rc=0
            fi
        else
            local json_file py_script
            json_file=$(mktemp "${TMPDIR:-/tmp}/sw-darwin-time.XXXXXX.json")
            py_script="${_CD_DARWIN_DIR}/configure-dialogs-darwin-time.py"
            printf '%s\n' "${json_payload}" >"${json_file}"
            if [ -f "${py_script}" ]; then
                result=$(python3 "${py_script}" <"${json_file}" 2>/dev/null)
                rc=$?
            fi
            rm -f "${json_file}"
        fi

        ui_end=$(_cd_darwin_now_ms)
        _cd_darwin_profile_log "time" "$((prep_end - prep_start))" "$((ui_end - ui_start))"

        if [ ${rc} -eq 0 ] && [ -n "${result}" ]; then
            echo "${result}"
            return 0
        fi
        return 1
    }

    # ⚠️ macOS Z-ORDER WARNING:
    # show_question_dialog and show_info_dialog use osascript display alert.
    # On macOS 13+, display alert dialogs may appear BEHIND the terminal after
    # a tkinter dialog closes. Callers in the configure path should prefer
    # show_list_dialog (for questions) or show_text_dialog (for info) when
    # the dialog immediately follows a tkinter window.
    # See: dev-docs/weekday-gui-bug-assessment.md
    show_info_dialog() {
        local title="$1"
        local message="$2"
        local _w="${3:-500}"
        local _h="${4:-200}"
        local prep_start ui_start ui_end
        prep_start=$(_cd_darwin_now_ms)
        message=$(_cd_darwin_preprocess_message "${message}")
        ui_start=$(_cd_darwin_now_ms)
        _cd_darwin_run_applescript "${title}" "${message}" <<APPLESCRIPT
on run argv
$(_cd_darwin_osascript_activate_snippet)
    set theTitle to item 1 of argv
    set theMessage to item 2 of argv
    display alert theMessage with title theTitle buttons {"OK"} default button "OK"
end run
APPLESCRIPT
        ui_end=$(_cd_darwin_now_ms)
        _cd_darwin_mark_dialog_end osascript
        _cd_darwin_profile_log "info" "$((ui_start - prep_start))" "$((ui_end - ui_start))"
        return 0
    }

    show_error_dialog() {
        show_info_dialog "${1}" "${2}" "${3:-500}" "${4:-200}"
    }

    show_question_dialog() {
        local title="$1"
        local message="$2"
        local yes_label="${3:-Yes}"
        local no_label="${4:-No}"
        local _w="${5:-600}"
        local _h="${6:-400}"
        local result prep_start ui_start ui_end
        prep_start=$(_cd_darwin_now_ms)
        message=$(_cd_darwin_preprocess_message "${message}")
        ui_start=$(_cd_darwin_now_ms)
        result=$(_cd_darwin_run_applescript "${title}" "${message}" "${yes_label}" "${no_label}" <<APPLESCRIPT
on run argv
$(_cd_darwin_osascript_activate_snippet)
    set theTitle to item 1 of argv
    set theMessage to item 2 of argv
    set yesBtn to item 3 of argv
    set noBtn to item 4 of argv
    try
        set btn to button returned of (display alert theMessage with title theTitle buttons {noBtn, yesBtn} default button yesBtn cancel button noBtn)
        return btn
    on error number -128
        return noBtn
    end try
end run
APPLESCRIPT
)
        ui_end=$(_cd_darwin_now_ms)
        _cd_darwin_mark_dialog_end osascript
        _cd_darwin_profile_log "question" "$((ui_start - prep_start))" "$((ui_end - ui_start))"
        result=$(_cd_darwin_trim "${result}")
        [ "${result}" = "${yes_label}" ]
    }

    # macOS-safe confirmation after list/time dialogs (display alert z-order bug).
    show_confirm_dialog() {
        local title="$1"
        local message="$2"
        local yes_label="${3:-Yes}"
        local no_label="${4:-No}"
        local _w="${5:-520}"
        local _h="${6:-250}"
        local choice
        message=$(_cd_darwin_preprocess_message "${message}")
        choice=$(show_list_dialog "${title}" "${message}" "${_w}" "${_h}" "${yes_label}" "${no_label}")
        local list_rc=$?
        if [ ${list_rc} -ne 0 ] || [ -z "${choice}" ]; then
            return 1
        fi
        [ "${choice}" = "${yes_label}" ]
    }

    show_entry_dialog() {
        local title="$1"
        local message="$2"
        local default_value="${3:-}"
        local result prep_start ui_start ui_end
        prep_start=$(_cd_darwin_now_ms)
        message=$(_cd_darwin_preprocess_message "${message}")
        ui_start=$(_cd_darwin_now_ms)
        result=$(_cd_darwin_run_applescript "${title}" "${message}" "${default_value}" <<APPLESCRIPT
on run argv
$(_cd_darwin_osascript_activate_snippet)
    set theTitle to item 1 of argv
    set theMessage to item 2 of argv
    set defaultVal to item 3 of argv
    try
        set theResult to text returned of (display dialog theMessage with title theTitle default answer defaultVal buttons {"Cancel", "OK"} default button "OK" cancel button "Cancel")
        return theResult
    on error number -128
        return ""
    end try
end run
APPLESCRIPT
)
        ui_end=$(_cd_darwin_now_ms)
        _cd_darwin_mark_dialog_end osascript
        _cd_darwin_profile_log "entry" "$((ui_start - prep_start))" "$((ui_end - ui_start))"
        result=$(_cd_darwin_trim "${result}")
        if [ -z "${result}" ]; then
            return 1
        fi
        echo "${result}"
        return 0
    }

    show_list_dialog() {
        local title="$1"
        local message="$2"
        local _w="${3:-500}"
        local _h="${4:-300}"
        shift 4
        local items=("$@")
        local prep_start prep_end ui_start ui_end json_payload
        prep_start=$(_cd_darwin_now_ms)
        message=$(_cd_darwin_preprocess_message "${message}")

        # Prefer the tkinter daemon so menus/prompts share the weekly grid's root
        # (consistent z-order, no per-prompt osascript process). Fall back to
        # `choose from list` if the daemon is unavailable or never showed a window.
        if [ "${CONFIGURE_DARWIN_NO_DAEMON:-}" != "1" ] \
            && _cd_darwin_has_list_dialog \
            && _cd_darwin_daemon_start; then
            json_payload=$(_cd_darwin_build_list_json "${title}" "${message}" "${_w}" "${_h}" "${items[@]}")
            prep_end=$(_cd_darwin_now_ms)
            ui_start=${prep_end}
            if _cd_darwin_daemon_request "{\"op\":\"list\",${json_payload:1}"; then
                if _cd_darwin_response_was_shown; then
                    if _cd_darwin_response_is_ok && ! _cd_darwin_response_is_cancelled; then
                        local daemon_value
                        daemon_value=$(_cd_darwin_response_extract_value)
                        ui_end=$(_cd_darwin_now_ms)
                        _cd_darwin_profile_log "list" "$((prep_end - prep_start))" "$((ui_end - ui_start))"
                        [ -n "${daemon_value}" ] || return 1
                        printf '%s\n' "${daemon_value}"
                        return 0
                    fi
                    ui_end=$(_cd_darwin_now_ms)
                    _cd_darwin_profile_log "list" "$((prep_end - prep_start))" "$((ui_end - ui_start))"
                    return 1
                fi
                _cd_darwin_profile_log "list" "$((prep_end - prep_start))" "0" "fallback=osascript invisible_daemon"
            fi
        else
            prep_end=$(_cd_darwin_now_ms)
        fi

        ui_start=$(_cd_darwin_now_ms)
        local result
        _CD_FORCE_OSASCRIPT_ACTIVATE=1
        result=$(_cd_darwin_run_applescript "${title}" "${message}" "${items[@]}" <<APPLESCRIPT
on run argv
$(_cd_darwin_osascript_activate_snippet)
    set theTitle to item 1 of argv
    set thePrompt to item 2 of argv
    set theItems to {}
    repeat with i from 3 to (count of argv)
        set end of theItems to item i of argv
    end repeat
    try
        set picked to choose from list theItems with title theTitle with prompt thePrompt OK button name "OK" cancel button name "Cancel"
        if picked is false then
            return ""
        end if
        return item 1 of picked as text
    on error number -128
        return ""
    end try
end run
APPLESCRIPT
)
        _CD_FORCE_OSASCRIPT_ACTIVATE=""
        ui_end=$(_cd_darwin_now_ms)
        _cd_darwin_mark_dialog_end osascript
        _cd_darwin_profile_log "list-osascript" "$((prep_end - prep_start))" "$((ui_end - ui_start))"
        result=$(_cd_darwin_trim "${result}")
        if [ -z "${result}" ] || [ "${result}" = "false" ]; then
            return 1
        fi
        echo "${result}"
        return 0
    }

    show_text_info_dialog() {
        local title="$1"
        local content=""
        local _w=700
        local _h=500

        # Linux-compatible: title, text, width, height
        if [ $# -ge 4 ] || { [ $# -ge 2 ] && ! [[ "${2}" =~ ^[0-9]+$ ]]; }; then
            content="$2"
            _w="${3:-700}"
            _h="${4:-500}"
        else
            _w="${2:-700}"
            _h="${3:-500}"
            content=$(cat)
        fi

        content=$(_cd_darwin_preprocess_message "${content}")
        if _cd_darwin_has_text_dialog; then
            _cd_darwin_show_text_dialog "${title}" "${content}" "${_w}" "${_h}"
            return $?
        fi
        show_info_dialog "${title}" "${content}" "${_w}" "${_h}"
    }

    show_multi_column_list_dialog() {
        local title="$1"
        local message="$2"
        local width="${3:-700}"
        local height="${4:-500}"
        shift 4

        _cd_darwin_parse_multi_column_args "$@"

        # Three or more columns: tkinter table (matches yad/zenity grid layout).
        if [ "${_cd_num_columns}" -ge 3 ] && _cd_darwin_has_table_dialog; then
            _cd_darwin_show_table_dialog \
                "${title}" "${message}" "${width}" "${height}" "${_cd_print_column}"
            return $?
        fi

        # Two columns (or table fallback): single-line rows in choose from list.
        local options=()
        local i=0
        local num_data="${#_cd_data[@]}"
        while [ "${i}" -lt "${num_data}" ]; do
            local row_display=""
            local c=0
            while [ "${c}" -lt "${_cd_num_columns}" ] && [ $((i + c)) -lt "${num_data}" ]; do
                local cell="${_cd_data[$((i + c))]}"
                if [ "${c}" -eq 0 ]; then
                    row_display="${cell}"
                elif [ -n "${cell}" ]; then
                    row_display="${row_display} — ${cell}"
                fi
                c=$((c + 1))
            done
            options+=("${row_display}")
            i=$((i + _cd_num_columns))
        done

        local raw
        raw=$(show_list_dialog "${title}" "${message}" "${width}" "${height}" "${options[@]}")
        local list_rc=$?
        if [ ${list_rc} -ne 0 ] || [ -z "${raw}" ]; then
            return 1
        fi

        local idx=0
        for idx in "${!options[@]}"; do
            if [ "${options[${idx}]}" = "${raw}" ]; then
                local row_start=$((idx * _cd_num_columns))
                local col_idx=$((_cd_print_column - 1))
                echo "${_cd_data[$((row_start + col_idx))]}"
                return 0
            fi
        done

        # Fallback: first column before em dash separator.
        echo "${raw%% — *}"
        return 0
    }

    show_time_selection_dialog() {
        local title="$1"
        local start_time="${2:-}"
        local end_time="${3:-}"
        local day_name="${4:-}"
        local hint="${5:-}"

        if _cd_darwin_has_time_dialog; then
            _cd_darwin_show_time_dialog "${title}" "${start_time}" "${end_time}" "${day_name}" "${hint}"
            return $?
        fi

        local default_val=""
        if [ -n "${start_time}" ] || [ -n "${end_time}" ]; then
            default_val="${start_time}-${end_time}"
        fi
        local msg="Enter time range (e.g. 11:30pm-5:30am)"
        [ -n "${day_name}" ] && msg="${msg} for ${day_name}"
        [ -n "${hint}" ] && msg="${msg}. ${hint}"
        show_entry_dialog "${title}" "${msg}" "${default_val}"
    }
fi
