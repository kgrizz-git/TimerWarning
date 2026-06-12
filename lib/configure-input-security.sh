#!/bin/bash

###############################################################################
# Sleep Warning System - Security / lock feature getters (configure wizard)
#
# Sourced by configure-input-features.sh. Requires configure-input-feature-helpers.sh.
###############################################################################

get_configure_block_enabled_config() {
    local use_gui="$1"
    local default_block_enabled
    default_block_enabled="$(_get_existing_bool_setting_from_config "CONFIGURE_BLOCK_ENABLED" "false")"

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        _prompt_bool_setting_gui_strict \
            "${use_gui}" \
            "Sleep Warning Configuration - Restrict Configuration Changes During Restricted Hours" \
            "Restrict configuration changes during restricted hours? (tighten-only)\n\nWhen enabled, the configuration and management wizards open in tighten-only mode during restricted hours: you can make restrictions stricter, but cannot loosen, remove, or disable them until restricted hours end. Disabling the service and uninstalling remain available.\n\nNote: This must be enabled for 'Additional Configuration Lock Hours' to take effect.\n\nCurrent setting: ${default_block_enabled}" \
            650 \
            400
        return $?
    fi

    echo "" >&2
    echo "Restrict Configuration Changes During Restricted Hours (tighten-only):" >&2
    echo "  When enabled, the configure and manage wizards open in tighten-only mode" >&2
    echo "  during restricted hours: you can make restrictions stricter, but cannot" >&2
    echo "  loosen, remove, or disable them until restricted hours end." >&2
    echo "  Disabling the service and uninstalling remain available." >&2
    echo "  Note: This must be enabled for 'Additional Configuration Lock Hours' to take effect." >&2
    echo "" >&2
    _prompt_bool_setting_text_yn \
        "${use_gui}" \
        "${default_block_enabled}" \
        "Restrict configuration changes during restricted hours? [y/n, default: ${default_block_enabled}]: "
}

get_security_settings_config() {
    local use_gui="$1"
    local current_configure_block="${2:-false}"
    local current_config_lock="${3:-false}"

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        while true; do
            local block_enabled_result
            block_enabled_result=$(show_list_dialog \
                "Sleep Warning Configuration - Configuration Lock (Tighten-Only) and Config File Locking" \
                "Restrict configuration changes during restricted hours? (tighten-only)\n\nWhen enabled, the configuration and management wizards open in tighten-only mode during restricted hours: you can make restrictions stricter, but cannot loosen, remove, or disable them until restricted hours end. Disabling the service and uninstalling remain available.\n\nNote: This must be enabled for 'Additional Configuration Lock Hours' to take effect.\n\nCurrent setting: ${current_configure_block}" \
                700 \
                400 \
                "true" "false")
            local exit_code=$?

            if [ ${exit_code} -ne 0 ] || [ -z "${block_enabled_result}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2
                fi
                continue
            fi

            local lock_enabled_result
            lock_enabled_result=$(show_list_dialog \
                "Sleep Warning Configuration - Configuration Lock (Tighten-Only) and Config File Locking" \
                "Enable config file locking during restricted hours?\n\nWhen enabled, the config file and directory are made read-only during restricted hours and any configured lock hours to prevent users from circumventing restrictions by changing settings.\n\nNote: Automatically disabled if restrictions exceed ${THRESHOLD_WARN} minutes/week (> $(get_threshold_warn_description)) for safety.\n\nCurrent setting: ${current_config_lock}" \
                700 \
                450 \
                "true" "false")
            exit_code=$?

            if [ ${exit_code} -ne 0 ] || [ -z "${lock_enabled_result}" ]; then
                if confirm_cancel "${use_gui}"; then
                    echo "CANCELLED"
                    return 2
                fi
                continue
            fi

            if type configure_partial_lock_reject_scalar_change >/dev/null 2>&1; then
                local _pl_cb="${_baseline_configure_block_enabled:-${current_configure_block}}"
                local _pl_cl="${_baseline_config_lock_enabled:-${current_config_lock}}"
                if ! configure_partial_lock_reject_scalar_change "configure_block_enabled" "${_pl_cb}" "${block_enabled_result}" "${use_gui}"; then
                    continue
                fi
                if ! configure_partial_lock_reject_scalar_change "config_lock_enabled" "${_pl_cl}" "${lock_enabled_result}" "${use_gui}"; then
                    continue
                fi
            fi

            echo "${block_enabled_result}|${lock_enabled_result}"
            return 0
        done
    fi

    echo "" >&2
    echo "Configuration Lock (Tighten-Only) and Config File Locking" >&2
    echo "" >&2
    echo "1. Restrict configuration changes during restricted hours (tighten-only)" >&2
    echo "   When enabled, the configure and manage wizards open in tighten-only mode" >&2
    echo "   during restricted hours: you can make restrictions stricter, but cannot" >&2
    echo "   loosen, remove, or disable them until restricted hours end." >&2
    echo "   Note: This must be enabled for 'Additional Configuration Lock Hours' to take effect." >&2
    echo "" >&2
    echo "2. Config file locking during restricted hours" >&2
    echo "   When enabled, the config file and directory are made read-only during" >&2
    echo "   restricted hours and any configured lock hours to prevent users from" >&2
    echo "   circumventing restrictions by changing settings." >&2
    echo "" >&2
    echo "   This is a deterrence mechanism, not true security. A determined user" >&2
    echo "   can still bypass it by changing permissions or stopping the timer." >&2
    echo "" >&2
    echo "   Note: Automatically disabled if restrictions exceed 6720 minutes/week" >&2
    echo "   (> 16 hours/day) for safety." >&2
    echo "" >&2

    local block_enabled
    block_enabled=$(_prompt_bool_setting_text_yn \
        "${use_gui}" \
        "${current_configure_block}" \
        "Restrict configuration changes during restricted hours? (tighten-only) [y/n, default: ${current_configure_block}]: ")

    local lock_enabled
    lock_enabled=$(_prompt_bool_setting_text_yn \
        "${use_gui}" \
        "${current_config_lock}" \
        "Enable config file locking during restricted hours? [y/n, default: ${current_config_lock}]: ")

    if type configure_partial_lock_reject_scalar_change >/dev/null 2>&1; then
        local _pl_cb="${_baseline_configure_block_enabled:-${current_configure_block}}"
        local _pl_cl="${_baseline_config_lock_enabled:-${current_config_lock}}"
        if ! configure_partial_lock_reject_scalar_change "configure_block_enabled" "${_pl_cb}" "${block_enabled}" "${use_gui}"; then
            return 2
        fi
        if ! configure_partial_lock_reject_scalar_change "config_lock_enabled" "${_pl_cl}" "${lock_enabled}" "${use_gui}"; then
            return 2
        fi
    fi

    echo "${block_enabled}|${lock_enabled}"
    return 0
}

get_config_lock_enabled_config() {
    local use_gui="$1"
    local default_lock_enabled
    default_lock_enabled="$(_get_existing_bool_setting_from_config "CONFIG_LOCK_ENABLED" "false")"

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        _prompt_bool_setting_gui_strict \
            "${use_gui}" \
            "Sleep Warning Configuration - Config File Locking" \
            "Enable config file locking during restricted hours?\n\nWhen enabled, the config file and directory are made read-only during restricted hours and any configured lock hours to prevent users from circumventing restrictions by changing settings.\n\nNote: Automatically disabled if restrictions exceed ${THRESHOLD_WARN} minutes/week (> $(get_threshold_warn_description)) for safety.\n\nCurrent setting: ${default_lock_enabled}" \
            700 \
            450
        return $?
    fi

    while true; do
        echo "" >&2
        echo "Config File Locking (Enhancement #18)" >&2
        echo "" >&2
        echo "When enabled, the config file and directory are made read-only during" >&2
        echo "restricted hours and any configured lock hours to prevent users from" >&2
        echo "circumventing restrictions by changing settings." >&2
        echo "" >&2
        echo "This is a deterrence mechanism, not true security. A determined user" >&2
        echo "can still bypass it by changing permissions or stopping the timer." >&2
        echo "" >&2
        echo "Note: Automatically disabled if restrictions exceed ${THRESHOLD_WARN} minutes/week" >&2
        echo "(> $(get_threshold_warn_description)) for safety." >&2
        echo "" >&2
        echo "Current setting: ${default_lock_enabled}" >&2
        echo "" >&2
        configure_read -p "Enable config file locking? [true/false]: " lock_enabled

        if [ -z "${lock_enabled}" ]; then
            if confirm_cancel "${use_gui}"; then
                echo "CANCELLED"
                return 2
            fi
            continue
        fi

        lock_enabled=$(echo "${lock_enabled}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

        if [ "${lock_enabled}" = "true" ] || [ "${lock_enabled}" = "1" ] || [ "${lock_enabled}" = "yes" ]; then
            echo "true"
            return 0
        elif [ "${lock_enabled}" = "false" ] || [ "${lock_enabled}" = "0" ] || [ "${lock_enabled}" = "no" ]; then
            echo "false"
            return 0
        fi
        echo "Invalid input. Please enter 'true' or 'false'." >&2
    done
}

get_uninstall_protection_mode_config() {
    local use_gui="$1"
    local default_mode
    default_mode="$(_get_existing_enum_setting_from_config "UNINSTALL_PROTECTION_MODE" "none" "none" "difficult")"

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        while true; do
            local mode_result mode_display
            if [ "${default_mode}" = "none" ]; then
                mode_display="No Protection"
            else
                mode_display="Difficult Uninstall (Recommended)"
            fi

            mode_result=$(show_list_dialog \
                "Sleep Warning Configuration - Uninstall Protection" \
                "Choose protection mode for uninstall.sh during restricted hours:\n\nCurrent setting: ${mode_display}\n\nOptions:\n- none - No protection, uninstall works normally during restricted hours\n- difficult - Difficult uninstall, requires confirmation phrase + 5 arithmetic questions (3 wrong answers allowed)\n\nDifficult mode allows legitimate uninstalls while deterring impulsive ones.\nIt requires significant effort and cognitive engagement.\n\nNote: Total block mode may be considered as future phase." \
                700 \
                500 \
                "none" "difficult")
            local exit_code=$?

            if [ -n "${mode_result}" ]; then
                mode_result=$(printf '%s' "${mode_result}" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            fi

            local mode_result_lower
            mode_result_lower=$(echo "${mode_result}" | tr '[:upper:]' '[:lower:]')

            if [ "${mode_result_lower}" = "none" ] || [ "${mode_result_lower}" = "difficult" ]; then
                if ! _configure_input_check_partial_lock_scalar \
                    "uninstall_protection_mode" \
                    "${_baseline_uninstall_protection_mode:-${default_mode}}" \
                    "${mode_result_lower}" \
                    "${use_gui}"; then
                    continue
                fi
                echo "${mode_result_lower}"
                return 0
            fi

            if confirm_cancel "${use_gui}"; then
                echo "CANCELLED"
                return 2
            fi
        done
    fi

    echo "" >&2
    echo "Uninstall Protection Mode:" >&2
    echo "  Choose protection mode for uninstall.sh during restricted hours:" >&2
    echo "" >&2
    echo "  Options:" >&2
    echo "    1) none - No protection, uninstall works normally" >&2
    echo "    2) difficult - Difficult uninstall, requires verification (recommended)" >&2
    echo "" >&2
    echo "  Difficult mode requires:" >&2
    echo "    - Confirmation phrase" >&2
    echo "    - 5 arithmetic questions, written in word form (3 wrong answers allowed)" >&2
    echo "" >&2
    echo "  Difficult mode allows legitimate uninstalls while deterring impulsive ones." >&2
    echo "  Note: Total block mode may be considered as future phase." >&2
    echo "" >&2
    while true; do
        local default_choice
        if [ "${default_mode}" = "none" ]; then
            default_choice="1"
        else
            default_choice="2"
        fi
        local choice
        configure_read -p "Select protection mode [1-2, default: ${default_choice}]: " choice
        choice=${choice:-${default_choice}}
        case "${choice}" in
            1|none|NONE)
                echo "none"
                return 0
                ;;
            2|difficult|DIFFICULT)
                echo "difficult"
                return 0
                ;;
            "")
                echo "${default_mode}"
                return 0
                ;;
            *)
                echo "Invalid choice. Please enter '1' for none or '2' for difficult." >&2
                ;;
        esac
    done
}
