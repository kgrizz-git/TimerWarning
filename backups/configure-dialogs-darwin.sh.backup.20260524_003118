#!/bin/bash

###############################################################################
# Sleep Warning System - macOS Configuration Dialogs (osascript)
#
# Phase 2: timer + hours + review/save. Phase 4: additional list/multi-column stubs.
###############################################################################

if [ -z "${CONFIGURE_DIALOGS_DARWIN_LOADED:-}" ]; then
    CONFIGURE_DIALOGS_DARWIN_LOADED=1

    _cd_darwin_escape() {
        local s="$1"
        s="${s//\\/\\\\}"
        s="${s//\"/\\\"}"
        s="${s//$'\n'/ }"
        printf '%s' "${s}"
    }

    _cd_darwin_run() {
        osascript -e "$1" 2>/dev/null
    }

    show_info_dialog() {
        local title="$1"
        local message="$2"
        local _w="${3:-500}"
        local _h="${4:-200}"
        _cd_darwin_run "display alert \"$(_cd_darwin_escape "${message}")\" with title \"$(_cd_darwin_escape "${title}")\" buttons {\"OK\"} default button \"OK\""
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
        local result
        result=$(_cd_darwin_run "button returned of (display alert \"$(_cd_darwin_escape "${message}")\" with title \"$(_cd_darwin_escape "${title}")\" buttons {\"${no_label}\", \"${yes_label}\"} default button \"${yes_label}\")")
        [ "${result}" = "${yes_label}" ]
    }

    show_entry_dialog() {
        local title="$1"
        local message="$2"
        local default_value="${3:-}"
        local result
        result=$(_cd_darwin_run "text returned of (display dialog \"$(_cd_darwin_escape "${message}")\" with title \"$(_cd_darwin_escape "${title}")\" default answer \"$(_cd_darwin_escape "${default_value}")\" buttons {\"Cancel\", \"OK\"} default button \"OK\")")
        if [ -z "${result}" ]; then
            echo "CANCELLED"
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
        local apple_items=""
        local item
        for item in "${items[@]}"; do
            apple_items="${apple_items}\"$(_cd_darwin_escape "${item}")\", "
        done
        apple_items="${apple_items%, }"
        local result
        result=$(_cd_darwin_run "choose from list {${apple_items}} with title \"$(_cd_darwin_escape "${title}")\" with prompt \"$(_cd_darwin_escape "${message}")\"")
        if [ -z "${result}" ] || [ "${result}" = "false" ]; then
            echo "CANCELLED"
            return 1
        fi
        echo "${result}"
        return 0
    }

    show_text_info_dialog() {
        local title="$1"
        local _w="${2:-700}"
        local _h="${3:-500}"
        local content
        content=$(cat)
        show_info_dialog "${title}" "${content}" "${_w}" "${_h}"
    }

    show_multi_column_list_dialog() {
        # Phase 4: combine option + description for choose-from-list
        local title="$1"
        local message="$2"
        local _w="${3:-700}"
        local _h="${4:-500}"
        shift 4
        shift 3  # column count + two column headers
        local options=()
        while [ $# -ge 2 ]; do
            options+=("${1} — ${2}")
            shift 2
        done
        local raw
        raw=$(show_list_dialog "${title}" "${message}" "${_w}" "${_h}" "${options[@]}")
        if [ "${raw}" = "CANCELLED" ]; then
            echo "CANCELLED"
            return 1
        fi
        echo "${raw%% — *}"
    }

    show_time_selection_dialog() {
        local title="$1"
        local start_time="${2:-}"
        local end_time="${3:-}"
        local day_name="${4:-}"
        local hint="${5:-}"
        local default_val=""
        if [ -n "${start_time}" ] || [ -n "${end_time}" ]; then
            default_val="${start_time}-${end_time}"
        fi
        local msg="Enter time range (e.g. 11:30pm-5:30am)"
        [ -n "${day_name}" ] && msg="${msg} for ${day_name}"
        [ -n "${hint}" ] && msg="${msg}. ${hint}"
        show_entry_dialog "${title}" "${msg}" "${default_val}"
    }

    manage_ranges_dialog() {
        show_info_dialog "Not Available" "Visual range editor GUI is not yet available on macOS. Use weekdays/weekends text configuration or --text mode."
        return 1
    }
fi
