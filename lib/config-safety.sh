#!/bin/bash

# Shared safe defaults, effective cap inputs, and runtime lock/protection gate.
# Runtime collectors depend on config.sh; the writer uses only default filling.

get_default_hours_for_day() {
    local day_num="$1"
    case "${day_num}" in
        0) echo "1-5" ;;       # Sunday: 1:00 AM to 4:59 AM
        1|2|3|4|5) echo "0-5" ;;  # Mon–Fri: midnight to 4:59 AM
        6) echo "1-5" ;;       # Saturday: 1:00 AM to 4:59 AM
        *) return 1 ;;
    esac
}

# Last assigned value of a config key. Returns 1 when the key is absent so
# callers can tell "omitted" from "present but empty".
_config_last_assigned_value() {
    local key="$1"
    local line
    if [ ! -f "${CONFIG_FILE}" ]; then
        return 1
    fi
    line=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "${CONFIG_FILE}" 2>/dev/null | tail -n1)
    if [ -z "${line}" ]; then
        return 1
    fi
    echo "${line}" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    return 0
}

# Same hour string parse_config enforces: drop all whitespace, then
# normalize_time_range when that helper is loaded (HH:MM-HH:MM, including
# mixed "22-06:00" and "22:00-6"). Garbage stays garbage so the cap fails closed.
_config_hours_as_runtime() {
    local raw="$1"
    local normalized
    raw=$(printf '%s' "${raw}" | tr -d '[:space:]')
    if [ -z "${raw}" ]; then
        echo ""
        return 0
    fi
    if type normalize_time_range >/dev/null 2>&1; then
        normalized=$(normalize_time_range "${raw}")
        if [ -n "${normalized}" ]; then
            echo "${normalized}"
            return 0
        fi
    fi
    echo "${raw}"
}

# Fill the arrays check_daily_caps reads, using the same hours and flags the
# running features use.
# Absent restriction days get get_default_hours_for_day (parse_config's fallback).
# An explicit empty day stays empty. Lock-hour keys stay empty when omitted.
# Flags come from get_configure_block_enabled and get_uninstall_protection_mode.
#
# Namerefs: restriction lines, configure-lock lines, uninstall-lock lines,
# configure-block flag, uninstall-protection mode.
collect_runtime_daily_cap_inputs() {
    local -n _cap_config="$1"
    local -n _cap_lock="$2"
    local -n _cap_uninstall="$3"
    local -n _cap_cbe="$4"
    local -n _cap_upm="$5"
    local i day_name rval

    _cap_config=()
    _cap_lock=()
    _cap_uninstall=()

    for i in 0 1 2 3 4 5 6; do
        day_name=$(_config_day_num_to_name_upper "${i}") || continue
        if rval=$(_config_last_assigned_value "${day_name}"); then
            rval=$(_config_hours_as_runtime "${rval}")
            _cap_config[i]="${day_name}=${rval}"
        else
            rval=$(get_default_hours_for_day "${i}")
            _cap_config[i]="${day_name}=${rval}"
        fi
        if rval=$(_config_last_assigned_value "${CONFIG_KEY_PREFIX_CONFIG_LOCK_HOURS}_${day_name}"); then
            rval=$(_config_hours_as_runtime "${rval}")
            _cap_lock[i]="${CONFIG_KEY_PREFIX_CONFIG_LOCK_HOURS}_${day_name}=${rval}"
        fi
        if rval=$(_config_last_assigned_value "${CONFIG_KEY_PREFIX_UNINSTALL_LOCK_HOURS}_${day_name}"); then
            rval=$(_config_hours_as_runtime "${rval}")
            _cap_uninstall[i]="${CONFIG_KEY_PREFIX_UNINSTALL_LOCK_HOURS}_${day_name}=${rval}"
        fi
    done

    _cap_cbe=$(get_configure_block_enabled)
    _cap_upm=$(get_uninstall_protection_mode)
    _cap_lock+=("CONFIG_LOCK_ENABLED=$(get_config_lock_enabled)")
}

# Shared runtime gate for configure/config-file locks and uninstall protection.
# Re-read the file on each check, including after a wizard save. Unsafe configs
# release locks/protection; sleep-warning.sh independently uses safe popup defaults.
runtime_daily_caps_are_safe() {
    [ -f "${CONFIG_FILE}" ] || return 0
    local _caps_dir
    _caps_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if ! type check_daily_caps >/dev/null 2>&1; then
        # shellcheck disable=SC1091
        source "${_caps_dir}/daily-caps.sh" || return 1
    fi
    if ! type normalize_time_range >/dev/null 2>&1; then
        # shellcheck disable=SC1091
        source "${_caps_dir}/time-parsing.sh" || return 1
    fi
    local _runtime_cfg=() _runtime_lock=() _runtime_uninstall=()
    local _runtime_cbe _runtime_upm
    collect_runtime_daily_cap_inputs _runtime_cfg _runtime_lock _runtime_uninstall _runtime_cbe _runtime_upm
    check_daily_caps "${_runtime_cbe}" "${_runtime_upm}" \
        "${_runtime_cfg[@]}" "${_runtime_lock[@]}" "${_runtime_uninstall[@]}" >/dev/null
}

# Append DAY=default lines for restriction days that are absent from the
# arguments. An explicit "TUESDAY=" stays absent from the output so it remains
# empty. Lock-hour lines are ignored. Used by the wizard save gate so it
# checks the same hours the runtime cap check will apply after save.
append_missing_restriction_default_lines() {
    local -n _cap_missing="$1"
    shift
    local _seen=(0 0 0 0 0 0 0)
    local _names=("SUNDAY" "MONDAY" "TUESDAY" "WEDNESDAY" "THURSDAY" "FRIDAY" "SATURDAY")
    local _arg _i _def
    for _arg in "$@"; do
        case "${_arg}" in
            SUNDAY=*) _seen[0]=1 ;;
            MONDAY=*) _seen[1]=1 ;;
            TUESDAY=*) _seen[2]=1 ;;
            WEDNESDAY=*) _seen[3]=1 ;;
            THURSDAY=*) _seen[4]=1 ;;
            FRIDAY=*) _seen[5]=1 ;;
            SATURDAY=*) _seen[6]=1 ;;
        esac
    done
    for _i in 0 1 2 3 4 5 6; do
        if [ "${_seen[_i]}" -eq 0 ]; then
            _def=$(get_default_hours_for_day "${_i}")
            _cap_missing+=("${_names[_i]}=${_def}")
        fi
    done
}

