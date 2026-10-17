#!/bin/bash

###############################################################################
# Sleep Warning System - Partial Configure Lock (Tighten-Only Mode)
#
# When configure or config-file lock hours are active, the wizard may run in
# partial mode: users may only change settings that increase lockout intensity,
# not weaken existing restrictions.
#
# Requires globals from configure.sh after load_existing_config():
#   config_lines[], lock_hours_lines[], uninstall_lock_hours_lines[]
#   check_interval, min_display_time, popup_* , configure_block_enabled, etc.
#
# Set CONFIGURE_PARTIAL_LOCK_MODE=true for the wizard session after capture.
###############################################################################

if [ -z "${CONFIGURE_PARTIAL_LOCK_LOADED:-}" ]; then
    CONFIGURE_PARTIAL_LOCK_LOADED=1

    # Session flag (set by configure.sh)
    CONFIGURE_PARTIAL_LOCK_MODE="${CONFIGURE_PARTIAL_LOCK_MODE:-false}"

    # Baseline snapshots (populated by configure_partial_lock_capture_baseline)
    declare -g -a _baseline_config_lines=()
    declare -g -a _baseline_lock_hours_lines=()
    declare -g -a _baseline_uninstall_lock_hours_lines=()
    declare -g _baseline_check_interval=""
    declare -g _baseline_min_display_time=""
    declare -g _baseline_popup_immovable=""
    declare -g _baseline_popup_auto_close=""
    declare -g _baseline_configure_block_enabled=""
    declare -g _baseline_config_lock_enabled=""
    declare -g _baseline_uninstall_protection_mode=""
    declare -g _baseline_pause_enabled=""
    declare -g _baseline_pause_duration=""
    declare -g _baseline_pause_cooldown_hours=""
    declare -g _baseline_popup_size=""
    declare -g _baseline_popup_size_mode=""
    declare -g _baseline_popup_size_custom=""
    declare -g _baseline_popup_size_custom_absolute=""
    declare -g _baseline_popup_position=""
    declare -g _baseline_dialog_tool=""
    declare -g _baseline_gaming_mode_experimental_enabled=""

    # True when script-block or config-file lock window is active right now.
    configure_partial_lock_is_active() {
        if type check_config_lock_time >/dev/null 2>&1; then
            if ! check_config_lock_time 2>/dev/null; then
                return 0
            fi
        fi
        if type is_config_lock_active >/dev/null 2>&1; then
            if is_config_lock_active 2>/dev/null; then
                return 0
            fi
        fi
        return 1
    }

    configure_partial_lock_mode_enabled() {
        [ "${CONFIGURE_PARTIAL_LOCK_MODE}" = "true" ]
    }

    _configure_partial_lock_normalize_bool() {
        local v="$1"
        case "${v}" in
            true|1|yes) echo "true" ;;
            *) echo "false" ;;
        esac
    }

    # Popup size ordering (fixed presets); custom compared separately.
    _configure_partial_lock_popup_size_rank() {
        local size="$1"
        case "${size}" in
            xsmall) echo 1 ;;
            small) echo 2 ;;
            medium) echo 3 ;;
            large) echo 4 ;;
            xlarge) echo 5 ;;
            max) echo 6 ;;
            *) echo 0 ;;
        esac
    }

    _configure_partial_lock_parse_csv_ranges() {
        local csv="$1"
        local -n _out_ref="$2"
        _out_ref=()
        if [ -z "${csv}" ]; then
            return 0
        fi
        local old_ifs="${IFS-}"
        IFS=','
        for _r in ${csv}; do
            _r=$(echo "${_r}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -n "${_r}" ] || continue
            if type normalize_time_range >/dev/null 2>&1; then
                local _norm
                _norm=$(normalize_time_range "${_r}" 2>/dev/null) || _norm="${_r}"
                _out_ref+=("${_norm}")
            else
                _out_ref+=("${_r}")
            fi
        done
        IFS="${old_ifs-$' \t\n'}"
    }

    # Every baseline range must appear unchanged in new (after normalize).
    # Returns 0 if add-only OK, 1 if violation.
    configure_partial_lock_ranges_add_only() {
        local old_csv="$1"
        local new_csv="$2"
        local -a old_ranges=() new_ranges=()
        _configure_partial_lock_parse_csv_ranges "${old_csv}" old_ranges
        _configure_partial_lock_parse_csv_ranges "${new_csv}" new_ranges

        if [ ${#old_ranges[@]} -eq 0 ]; then
            return 0
        fi

        if [ -z "${new_csv}" ] || [ ${#new_ranges[@]} -eq 0 ]; then
            return 1
        fi

        local _old _new _found
        for _old in "${old_ranges[@]}"; do
            _found=false
            for _new in "${new_ranges[@]}"; do
                if [ "${_old}" = "${_new}" ]; then
                    _found=true
                    break
                fi
            done
            if [ "${_found}" != "true" ]; then
                return 1
            fi
        done
        return 0
    }

    _configure_partial_lock_day_range_from_lines() {
        local -n _lines_ref="$1"
        local day_index="$2"
        local line="${_lines_ref[${day_index}]:-}"
        if [ -z "${line}" ]; then
            echo ""
            return 0
        fi
        echo "${line#*=}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
    }

    # field name, old, new — returns 0 if change allowed, 1 if loosening blocked.
    configure_partial_lock_validate_scalar() {
        local field="$1"
        local old_val="$2"
        local new_val="$3"

        case "${field}" in
            POPUP_DISPLAY_FREQUENCY|check_interval)
                if ! [[ "${old_val}" =~ ^[0-9]+$ ]] || ! [[ "${new_val}" =~ ^[0-9]+$ ]]; then
                    return 0
                fi
                # Lower interval = more frequent = tighten
                if [ "${new_val}" -gt "${old_val}" ]; then
                    return 1
                fi
                ;;
            POPUP_MIN_DISPLAY_TIME|min_display_time)
                if ! [[ "${old_val}" =~ ^[0-9]+$ ]] || ! [[ "${new_val}" =~ ^[0-9]+$ ]]; then
                    return 0
                fi
                if [ "${new_val}" -lt "${old_val}" ]; then
                    return 1
                fi
                ;;
            POPUP_IMMOVABLE|popup_immovable)
                old_val=$(_configure_partial_lock_normalize_bool "${old_val}")
                new_val=$(_configure_partial_lock_normalize_bool "${new_val}")
                if [ "${old_val}" = "true" ] && [ "${new_val}" = "false" ]; then
                    return 1
                fi
                ;;
            CONFIGURE_BLOCK_ENABLED|configure_block_enabled)
                old_val=$(_configure_partial_lock_normalize_bool "${old_val}")
                new_val=$(_configure_partial_lock_normalize_bool "${new_val}")
                if [ "${old_val}" = "true" ] && [ "${new_val}" = "false" ]; then
                    return 1
                fi
                ;;
            CONFIG_LOCK_ENABLED|config_lock_enabled)
                old_val=$(_configure_partial_lock_normalize_bool "${old_val}")
                new_val=$(_configure_partial_lock_normalize_bool "${new_val}")
                if [ "${old_val}" = "true" ] && [ "${new_val}" = "false" ]; then
                    return 1
                fi
                ;;
            GAMING_MODE_EXPERIMENTAL_ENABLED|gaming_mode_experimental_enabled)
                old_val=$(_configure_partial_lock_normalize_bool "${old_val}")
                new_val=$(_configure_partial_lock_normalize_bool "${new_val}")
                if [ "${old_val}" = "true" ] && [ "${new_val}" = "false" ]; then
                    return 1
                fi
                ;;
            UNINSTALL_PROTECTION_MODE|uninstall_protection_mode)
                if [ "${old_val}" = "difficult" ] && [ "${new_val}" = "none" ]; then
                    return 1
                fi
                ;;
            PAUSE_ENABLED|pause_enabled)
                old_val=$(_configure_partial_lock_normalize_bool "${old_val}")
                new_val=$(_configure_partial_lock_normalize_bool "${new_val}")
                if [ "${old_val}" = "false" ] && [ "${new_val}" = "true" ]; then
                    return 1
                fi
                ;;
            PAUSE_DURATION|pause_duration)
                if ! [[ "${old_val}" =~ ^[0-9]+$ ]] || ! [[ "${new_val}" =~ ^[0-9]+$ ]]; then
                    return 0
                fi
                if [ "${new_val}" -gt "${old_val}" ]; then
                    return 1
                fi
                ;;
            PAUSE_COOLDOWN_HOURS|pause_cooldown_hours)
                if ! [[ "${old_val}" =~ ^[0-9]+$ ]] || ! [[ "${new_val}" =~ ^[0-9]+$ ]]; then
                    return 0
                fi
                if [ "${new_val}" -lt "${old_val}" ]; then
                    return 1
                fi
                ;;
            POPUP_SIZE|popup_size)
                local old_rank new_rank
                old_rank=$(_configure_partial_lock_popup_size_rank "${old_val}")
                new_rank=$(_configure_partial_lock_popup_size_rank "${new_val}")
                if [ "${old_rank}" -gt 0 ] && [ "${new_rank}" -gt 0 ] && [ "${new_rank}" -lt "${old_rank}" ]; then
                    return 1
                fi
                ;;
            POPUP_SIZE_MODE|popup_size_mode)
                # display-based can use larger % — treat fixed -> display-based as neutral/tighten; display -> fixed only if size rank does not drop (handled via popup_size).
                if [ "${old_val}" = "display-based" ] && [ "${new_val}" = "fixed" ]; then
                    return 1
                fi
                ;;
            POPUP_POSITION|popup_position|DIALOG_TOOL|dialog_tool)
                if [ "${old_val}" != "${new_val}" ]; then
                    return 1
                fi
                ;;
            POPUP_SIZE_CUSTOM|popup_size_custom|POPUP_SIZE_CUSTOM_ABSOLUTE|popup_size_custom_absolute)
                if [ "${old_val}" != "${new_val}" ]; then
                    return 1
                fi
                ;;
            *)
                ;;
        esac
        return 0
    }

    configure_partial_lock_capture_baseline() {
        _baseline_config_lines=()
        _baseline_lock_hours_lines=()
        _baseline_uninstall_lock_hours_lines=()
        local i
        for i in 0 1 2 3 4 5 6; do
            [ -n "${config_lines[${i}]:-}" ] && _baseline_config_lines[${i}]="${config_lines[${i}]}"
            [ -n "${lock_hours_lines[${i}]:-}" ] && _baseline_lock_hours_lines[${i}]="${lock_hours_lines[${i}]}"
            [ -n "${uninstall_lock_hours_lines[${i}]:-}" ] && _baseline_uninstall_lock_hours_lines[${i}]="${uninstall_lock_hours_lines[${i}]}"
        done
        _baseline_check_interval="${check_interval:-10}"
        _baseline_min_display_time="${min_display_time:-30}"
        _baseline_popup_immovable="${popup_immovable:-true}"
        _baseline_popup_auto_close="${popup_auto_close:-true}"
        _baseline_configure_block_enabled="${configure_block_enabled:-false}"
        _baseline_config_lock_enabled="${config_lock_enabled:-false}"
        _baseline_uninstall_protection_mode="${uninstall_protection_mode:-difficult}"
        _baseline_pause_enabled="${pause_enabled:-true}"
        _baseline_pause_duration="${pause_duration:-5}"
        _baseline_pause_cooldown_hours="${pause_cooldown_hours:-24}"
        _baseline_popup_size="${popup_size:-medium}"
        _baseline_popup_size_mode="${popup_size_mode:-fixed}"
        _baseline_popup_size_custom="${popup_size_custom:-50%x50%}"
        _baseline_popup_size_custom_absolute="${popup_size_custom_absolute:-1280x720}"
        _baseline_popup_position="${popup_position:-center}"
        _baseline_dialog_tool="${dialog_tool:-auto}"
        _baseline_gaming_mode_experimental_enabled="${gaming_mode_experimental_enabled:-false}"
    }

    # Echo human-readable errors (one per line); empty = OK.
    configure_partial_lock_validate_proposed() {
        local errors=""
        local _err

        if ! configure_partial_lock_validate_scalar "check_interval" "${_baseline_check_interval}" "${check_interval:-10}"; then
            errors="${errors}Cannot increase popup check interval (less frequent) during lock hours.\n"
        fi
        if ! configure_partial_lock_validate_scalar "min_display_time" "${_baseline_min_display_time}" "${min_display_time:-30}"; then
            errors="${errors}Cannot decrease minimum popup display time during lock hours.\n"
        fi
        if ! configure_partial_lock_validate_scalar "popup_immovable" "${_baseline_popup_immovable}" "${popup_immovable:-true}"; then
            errors="${errors}Cannot disable immovable popup during lock hours.\n"
        fi
        if ! configure_partial_lock_validate_scalar "configure_block_enabled" "${_baseline_configure_block_enabled}" "${configure_block_enabled:-false}"; then
            errors="${errors}Cannot disable the configuration lock (tighten-only) during lock hours.\n"
        fi
        if ! configure_partial_lock_validate_scalar "config_lock_enabled" "${_baseline_config_lock_enabled}" "${config_lock_enabled:-false}"; then
            errors="${errors}Cannot disable config file locking during lock hours.\n"
        fi
        if ! configure_partial_lock_validate_scalar "gaming_mode_experimental_enabled" "${_baseline_gaming_mode_experimental_enabled:-false}" "${gaming_mode_experimental_enabled:-false}"; then
            errors="${errors}Cannot disable Experimental Gaming Mode during lock hours.\n"
        fi
        if ! configure_partial_lock_validate_scalar "uninstall_protection_mode" "${_baseline_uninstall_protection_mode}" "${uninstall_protection_mode:-difficult}"; then
            errors="${errors}Cannot weaken uninstall protection during lock hours.\n"
        fi
        if ! configure_partial_lock_validate_scalar "pause_enabled" "${_baseline_pause_enabled}" "${pause_enabled:-true}"; then
            errors="${errors}Cannot enable pause during lock hours.\n"
        fi
        if ! configure_partial_lock_validate_scalar "pause_duration" "${_baseline_pause_duration}" "${pause_duration:-5}"; then
            errors="${errors}Cannot increase pause duration during lock hours.\n"
        fi
        if ! configure_partial_lock_validate_scalar "pause_cooldown_hours" "${_baseline_pause_cooldown_hours}" "${pause_cooldown_hours:-24}"; then
            errors="${errors}Cannot shorten pause cooldown during lock hours.\n"
        fi
        if ! configure_partial_lock_validate_scalar "popup_size" "${_baseline_popup_size}" "${popup_size:-medium}"; then
            errors="${errors}Cannot decrease popup size during lock hours.\n"
        fi
        if ! configure_partial_lock_validate_scalar "popup_size_mode" "${_baseline_popup_size_mode}" "${popup_size_mode:-fixed}"; then
            errors="${errors}Cannot switch popup size mode to a less intrusive setting during lock hours.\n"
        fi
        if ! configure_partial_lock_validate_scalar "popup_position" "${_baseline_popup_position}" "${popup_position:-center}"; then
            errors="${errors}Cannot change popup position during lock hours.\n"
        fi
        if ! configure_partial_lock_validate_scalar "dialog_tool" "${_baseline_dialog_tool}" "${dialog_tool:-auto}"; then
            errors="${errors}Cannot change dialog tool during lock hours.\n"
        fi
        if [ "${_baseline_popup_size_custom}" != "${popup_size_custom:-50%x50%}" ] || \
           [ "${_baseline_popup_size_custom_absolute}" != "${popup_size_custom_absolute:-1280x720}" ]; then
            if ! configure_partial_lock_validate_scalar "popup_size_custom" "${_baseline_popup_size_custom}" "${popup_size_custom:-50%x50%}"; then
                errors="${errors}Cannot change custom popup size during lock hours.\n"
            fi
        fi

        local day_index old_rng new_rng
        for day_index in 0 1 2 3 4 5 6; do
            old_rng=$(_configure_partial_lock_day_range_from_lines _baseline_config_lines "${day_index}")
            new_rng=$(_configure_partial_lock_day_range_from_lines config_lines "${day_index}")
            if ! configure_partial_lock_ranges_add_only "${old_rng}" "${new_rng}"; then
                if type ensure_day_names >/dev/null 2>&1; then ensure_day_names; fi
                _err="${DAY_NAMES[${day_index}]:-Day${day_index}}"
                errors="${errors}Cannot remove or edit existing restriction hours for ${_err}; you may only add ranges.\n"
            fi
            old_rng=$(_configure_partial_lock_day_range_from_lines _baseline_lock_hours_lines "${day_index}")
            new_rng=$(_configure_partial_lock_day_range_from_lines lock_hours_lines "${day_index}")
            if ! configure_partial_lock_ranges_add_only "${old_rng}" "${new_rng}"; then
                if type ensure_day_names >/dev/null 2>&1; then ensure_day_names; fi
                _err="${DAY_NAMES[${day_index}]:-Day${day_index}}"
                errors="${errors}Cannot remove or edit existing configure-block hours for ${_err}; you may only add ranges.\n"
            fi
            old_rng=$(_configure_partial_lock_day_range_from_lines _baseline_uninstall_lock_hours_lines "${day_index}")
            new_rng=$(_configure_partial_lock_day_range_from_lines uninstall_lock_hours_lines "${day_index}")
            if ! configure_partial_lock_ranges_add_only "${old_rng}" "${new_rng}"; then
                if type ensure_day_names >/dev/null 2>&1; then ensure_day_names; fi
                _err="${DAY_NAMES[${day_index}]:-Day${day_index}}"
                errors="${errors}Cannot remove or edit existing uninstall-lock hours for ${_err}; you may only add ranges.\n"
            fi
        done

        # Trim trailing newline for display
        errors=$(printf '%b' "${errors}" | sed '/^$/d')
        echo "${errors}"
    }

    # Reject a single scalar change during partial mode (for per-field hooks).
    configure_partial_lock_reject_scalar_change() {
        local field="$1"
        local old_val="$2"
        local new_val="$3"
        local use_gui="${4:-false}"
        if ! configure_partial_lock_mode_enabled; then
            return 0
        fi
        if configure_partial_lock_validate_scalar "${field}" "${old_val}" "${new_val}"; then
            return 0
        fi
        local msg="That change is not allowed during lock hours (tighten-only mode)."
        case "${field}" in
            check_interval|POPUP_DISPLAY_FREQUENCY) msg="Cannot make popup checks less frequent during lock hours." ;;
            min_display_time|POPUP_MIN_DISPLAY_TIME) msg="Cannot decrease minimum display time during lock hours." ;;
            configure_block_enabled|CONFIGURE_BLOCK_ENABLED) msg="Cannot disable the configuration lock (tighten-only) during lock hours." ;;
            config_lock_enabled|CONFIG_LOCK_ENABLED) msg="Cannot disable config file locking during lock hours." ;;
            pause_duration|PAUSE_DURATION) msg="Cannot increase pause duration during lock hours." ;;
            pause_cooldown_hours|PAUSE_COOLDOWN_HOURS) msg="Cannot shorten pause cooldown during lock hours." ;;
        esac
        if [ "${use_gui}" = "true" ] && type show_error_dialog >/dev/null 2>&1; then
            show_error_dialog "Change Not Allowed" "${msg}"
        else
            echo "${msg}" >&2
        fi
        return 1
    }

    configure_partial_lock_show_banner() {
        local use_gui="$1"
        local msg
        msg=$'Limited configuration mode (lock hours active)\n\nYou may only make changes that increase lockout (more frequent popups, longer min display, add hours, enable locks).\n\nRemoving or weakening settings is blocked until unrestricted hours.'
        if [ "${use_gui}" = "true" ] && type show_info_dialog >/dev/null 2>&1; then
            show_info_dialog "Configuration — Limited Mode" "${msg}" 650 320
        else
            echo "" >&2
            echo "=== LIMITED CONFIGURATION MODE (lock hours) ===" >&2
            printf '%b\n' "${msg}" >&2
            echo "" >&2
        fi
    }

fi
