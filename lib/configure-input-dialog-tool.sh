#!/bin/bash

###############################################################################
# Sleep Warning System - Dialog tool selection getter (configure wizard)
#
# Sourced by configure-input-features.sh.
###############################################################################

get_dialog_tool_selection() {
    local use_gui="$1"

    local current_setting
    if type get_dialog_tool_config >/dev/null 2>&1; then
        current_setting=$(get_dialog_tool_config 2>/dev/null || echo "auto")
    else
        current_setting="auto"
    fi

    local recommended_tool=""
    local env_type
    if type detect_display_environment >/dev/null 2>&1; then
        env_type=$(detect_display_environment 2>/dev/null || echo "x11")
    else
        env_type="x11"
    fi

    if type check_dialog_tool >/dev/null 2>&1; then
        recommended_tool=$(check_dialog_tool "${env_type}" "" 2>/dev/null || echo "")
    else
        if command -v yad >/dev/null 2>&1; then
            recommended_tool="yad"
        elif command -v zenity >/dev/null 2>&1; then
            recommended_tool="zenity"
        elif command -v kdialog >/dev/null 2>&1; then
            recommended_tool="kdialog"
        fi
    fi

    local installed_tools=()
    local tool_descriptions=()

    installed_tools+=("auto")
    if [ -n "${recommended_tool}" ]; then
        tool_descriptions+=("Automatic (recommended) - Will use: ${recommended_tool} (priority: YAD → Zenity → KDialog)")
    else
        tool_descriptions+=("Automatic (recommended) - Uses priority: YAD → Zenity → KDialog")
    fi

    if command -v yad >/dev/null 2>&1; then
        installed_tools+=("yad")
        if [ "${recommended_tool}" = "yad" ]; then
            tool_descriptions+=("yad - Enhanced GTK dialog (best positioning, Wayland support) [Recommended by automatic priority]")
        else
            tool_descriptions+=("yad - Enhanced GTK dialog (best positioning, Wayland support)")
        fi
    fi
    if command -v zenity >/dev/null 2>&1; then
        installed_tools+=("zenity")
        if [ "${recommended_tool}" = "zenity" ]; then
            tool_descriptions+=("zenity - Standard GTK dialog (fallback) [Recommended by automatic priority]")
        else
            tool_descriptions+=("zenity - Standard GTK dialog (fallback)")
        fi
    fi
    if command -v kdialog >/dev/null 2>&1; then
        installed_tools+=("kdialog")
        if [ "${recommended_tool}" = "kdialog" ]; then
            tool_descriptions+=("kdialog - KDE dialog (KDE integration) [Recommended by automatic priority]")
        else
            tool_descriptions+=("kdialog - KDE dialog (KDE integration)")
        fi
    fi

    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        local dialog_msg="Select which dialog tool to use for popup windows:\n\n"
        dialog_msg="${dialog_msg}Current setting: ${current_setting}\n"
        if [ -n "${recommended_tool}" ]; then
            dialog_msg="${dialog_msg}Recommended: ${recommended_tool} (selected by automatic priority system)\n"
        fi
        dialog_msg="${dialog_msg}\nNote: If you don't make a selection or cancel, the system will use 'Automatic' mode, which will select ${recommended_tool:-"the best available tool"} based on priority (YAD → Zenity → KDialog).\n\n"
        dialog_msg="${dialog_msg}Only installed tools are shown. If you select a tool that becomes unavailable, the system will automatically fall back to the priority system."

        local choice
        choice=$(show_list_dialog \
            "Dialog Tool Selection" \
            "${dialog_msg}" \
            650 \
            450 \
            "${tool_descriptions[@]}")
        local exit_code=$?

        if [ ${exit_code} -ne 0 ] || [ -z "${choice}" ]; then
            if confirm_cancel "${use_gui}"; then
                echo "CANCELLED"
                return 2
            fi
            echo "auto"
            return 0
        fi

        local selected_tool
        selected_tool=$(echo "${choice}" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')

        case "${selected_tool}" in
            automatic|auto)
                echo "auto"
                return 0
                ;;
            yad|zenity|kdialog)
                if command -v "${selected_tool}" >/dev/null 2>&1; then
                    echo "${selected_tool}"
                    return 0
                fi
                show_info_dialog \
                    "Tool Not Available" \
                    "The selected tool '${selected_tool}' is not installed.\n\nPlease select another option." \
                    500 \
                    200
                return 1
                ;;
            *)
                echo "auto"
                return 0
                ;;
        esac
    fi

    echo "" >&2
    echo "=== Dialog Tool Selection ===" >&2
    echo "" >&2
    echo "Current setting: ${current_setting}" >&2
    if [ -n "${recommended_tool}" ]; then
        echo "Recommended: ${recommended_tool} (selected by automatic priority system)" >&2
    fi
    echo "" >&2
    echo "Note: If you don't make a selection, the system will use 'Automatic' mode," >&2
    echo "      which will select ${recommended_tool:-"the best available tool"} based on priority (YAD → Zenity → KDialog)." >&2
    echo "" >&2
    echo "Select dialog tool:" >&2
    local i=1
    for tool in "${installed_tools[@]}"; do
        local desc="${tool_descriptions[$((i-1))]}"
        echo "  ${i}) ${desc}" >&2
        i=$((i + 1))
    done
    echo "" >&2

    while true; do
        local choice
        configure_read -p "Select option [1-${#installed_tools[@]}, Enter for Automatic]: " choice
        if [ -z "${choice}" ]; then
            echo "auto"
            return 0
        fi
        if [ "${choice}" -ge 1 ] && [ "${choice}" -le ${#installed_tools[@]} ]; then
            local selected_tool="${installed_tools[$((choice-1))]}"
            if [ "${selected_tool}" != "auto" ] && ! command -v "${selected_tool}" >/dev/null 2>&1; then
                echo "Error: Tool '${selected_tool}' is not installed. Please select another option." >&2
                continue
            fi
            echo "${selected_tool}"
            return 0
        fi
        echo "Invalid option. Please enter 1-${#installed_tools[@]}." >&2
    done
}
