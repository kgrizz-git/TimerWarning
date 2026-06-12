#!/bin/bash

###############################################################################
# Sleep Warning System - Configure Input Feature Helpers
#
# Shared primitives for boolean/enum/list getter prompts in the configure
# wizard. Sourced by configure-input-features.sh and its submodules.
#
# Dependencies (must be loaded before this file):
# - configure-core.sh (CONFIG_FILE, configure_read, has_dialog_tool)
# - configure-dialogs.sh (show_list_dialog)
# - configure-ui.sh (confirm_cancel)
# Optional:
# - configure-partial-lock.sh (configure_partial_lock_reject_scalar_change)
###############################################################################

# Read a boolean-like config value from CONFIG_FILE and normalize to "true" or
# "false". If the key is not present (or doesn't parse), returns the default.
_get_existing_bool_setting_from_config() {
    local key="$1"
    local default_value="$2"

    if [ -z "${key}" ]; then
        echo "${default_value}"
        return 0
    fi

    if [ -f "${CONFIG_FILE}" ]; then
        local existing_value
        existing_value=$(grep -E "^[[:space:]]*${key}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -n "${existing_value}" ]; then
            if [ "${existing_value}" = "true" ] || [ "${existing_value}" = "1" ] || [ "${existing_value}" = "yes" ]; then
                echo "true"
                return 0
            elif [ "${existing_value}" = "false" ] || [ "${existing_value}" = "0" ] || [ "${existing_value}" = "no" ]; then
                echo "false"
                return 0
            fi
        fi
    fi

    echo "${default_value}"
    return 0
}

# Read an enum-like config value when it matches one of the allowed tokens.
# Args: key, default, allowed values (one or more)
_get_existing_enum_setting_from_config() {
    local key="$1"
    local default_value="$2"
    shift 2

    if [ -z "${key}" ]; then
        echo "${default_value}"
        return 0
    fi

    if [ -f "${CONFIG_FILE}" ]; then
        local existing_value
        existing_value=$(grep -E "^[[:space:]]*${key}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ -n "${existing_value}" ]; then
            local allowed
            for allowed in "$@"; do
                if [ "${existing_value}" = "${allowed}" ]; then
                    echo "${existing_value}"
                    return 0
                fi
            done
        fi
    fi

    echo "${default_value}"
    return 0
}

# Optional partial-lock scalar check. Returns 0 when the change is allowed.
_configure_input_check_partial_lock_scalar() {
    local field="$1"
    local baseline="$2"
    local new_value="$3"
    local use_gui="$4"

    if [ -z "${field}" ]; then
        return 0
    fi
    if type configure_partial_lock_reject_scalar_change >/dev/null 2>&1; then
        configure_partial_lock_reject_scalar_change "${field}" "${baseline}" "${new_value}" "${use_gui}"
        return $?
    fi
    return 0
}

# Standard GUI prompt for a "true/false" setting using show_list_dialog.
# Optional partial lock: args 6–7 are field name and baseline value.
_prompt_bool_setting_gui_strict() {
    local use_gui="$1"
    local title="$2"
    local message="$3"
    local width="$4"
    local height="$5"
    local pl_field="${6:-}"
    local pl_baseline="${7:-}"

    while true; do
        local result
        result=$(show_list_dialog "${title}" "${message}" "${width}" "${height}" "true" "false")
        local exit_code=$?

        if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
            if [ -n "${pl_field}" ]; then
                if ! _configure_input_check_partial_lock_scalar "${pl_field}" "${pl_baseline}" "${result}" "${use_gui}"; then
                    continue
                fi
            fi
            echo "${result}"
            return 0
        fi

        if confirm_cancel "${use_gui}"; then
            echo "CANCELLED"
            return 2
        fi
    done
}

# Text-mode y/n (or yes/no/true/false) prompt with default on empty input.
# Optional partial lock: args 5–6 are field name and baseline value.
_prompt_bool_setting_text_yn() {
    local use_gui="$1"
    local default_value="$2"
    local prompt="$3"
    local pl_field="${4:-}"
    local pl_baseline="${5:-}"

    while true; do
        local choice value
        configure_read -p "${prompt}" choice
        choice=${choice:-${default_value}}
        case "${choice}" in
            y|Y|yes|YES|true|TRUE|1)
                value="true"
                ;;
            n|N|no|NO|false|FALSE|0)
                value="false"
                ;;
            "")
                value="${default_value}"
                ;;
            *)
                echo "Invalid choice. Please enter 'y' for yes or 'n' for no." >&2
                continue
                ;;
        esac

        if [ -n "${pl_field}" ]; then
            if ! _configure_input_check_partial_lock_scalar "${pl_field}" "${pl_baseline}" "${value}" "${use_gui}"; then
                continue
            fi
        fi

        echo "${value}"
        return 0
    done
}

# GUI list dialog with cancel/retry and optional partial-lock check after selection.
# Args: use_gui, title, message, width, height, pl_field, pl_baseline, option1, option2, ...
_prompt_list_setting_gui_strict() {
    local use_gui="$1"
    local title="$2"
    local message="$3"
    local width="$4"
    local height="$5"
    local pl_field="${6:-}"
    local pl_baseline="${7:-}"
    shift 7

    while true; do
        local result
        result=$(show_list_dialog "${title}" "${message}" "${width}" "${height}" "$@")
        local exit_code=$?

        if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
            if [ -n "${pl_field}" ]; then
                if ! _configure_input_check_partial_lock_scalar "${pl_field}" "${pl_baseline}" "${result}" "${use_gui}"; then
                    continue
                fi
            fi
            echo "${result}"
            return 0
        fi

        if confirm_cancel "${use_gui}"; then
            echo "CANCELLED"
            return 2
        fi
    done
}

# Text-mode prompt with default on empty; validates via named function (must return 0).
# Args: use_gui, default, prompt, validator_func_name, pl_field, pl_baseline, invalid_msg
_prompt_validated_setting_text() {
    local use_gui="$1"
    local default_value="$2"
    local prompt="$3"
    local validator_func="$4"
    local pl_field="${5:-}"
    local pl_baseline="${6:-}"
    local invalid_msg="${7:-Invalid choice.}"

    while true; do
        local choice
        configure_read -p "${prompt}" choice
        choice=${choice:-${default_value}}

        if type "${validator_func}" >/dev/null 2>&1; then
            if ! "${validator_func}" "${choice}"; then
                echo "${invalid_msg}" >&2
                continue
            fi
        fi

        if [ -n "${pl_field}" ]; then
            if ! _configure_input_check_partial_lock_scalar "${pl_field}" "${pl_baseline}" "${choice}" "${use_gui}"; then
                continue
            fi
        fi

        echo "${choice}"
        return 0
    done
}
