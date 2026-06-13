#!/bin/bash

###############################################################################
# Sleep Warning System - Complex Display Functions Module
#
# This module provides complex display functions including menus, grids, and
# summary views for the configuration wizard.
#
# Functions:
# - get_section_status()  - Get status indicators for menu display
# - show_main_menu() / show_window_behavior_submenu() - configure-display-menu.sh
# - show_visual_grid()    - configure-display-grid.sh
# - show_summary()        - configure-display-summary.sh
#
# Dependencies:
# - configure-core.sh (for has_dialog_tool, DAY_NAMES, CONFIG_FILE)
# - configure-dialogs.sh (for dialog abstraction functions)
# - configure-time.sh (for format_ranges_human, detect_overlaps, get_inherited_restrictions)
# - configure-ui.sh (for confirm_cancel)
###############################################################################

get_section_status() {
    # Access global config_lines array directly
    local weekdays_status="[not configured]"
    local weekends_status="[not configured]"
    
    # Check weekdays (indices 1-5: Monday-Friday)
    local has_weekdays=false
    for i in 1 2 3 4 5; do
        if [ -n "${config_lines[${i}]}" ]; then
            has_weekdays=true
            break
        fi
    done
    
    if [ "${has_weekdays}" = "true" ]; then
        weekdays_status="[configured]"
    fi
    
    # Check weekends (indices 0, 6: Sunday, Saturday)
    local has_weekends=false
    for i in 0 6; do
        if [ -n "${config_lines[${i}]}" ]; then
            has_weekends=true
            break
        fi
    done
    
    if [ "${has_weekends}" = "true" ]; then
        weekends_status="[configured]"
    fi
    
    echo "${weekdays_status}|${weekends_status}"
}

_get_effective_popup_size_mode() {
    # Determine effective popup size mode.
    #
    # Parameters:
    #   $1 - popup_size_mode_override (optional): "fixed" or "display-based"
    #
    # Output:
    #   Echoes "fixed" or "display-based"
    local popup_size_mode_override="${1:-}"
    local size_mode="fixed"

    if [ -n "${popup_size_mode_override}" ]; then
        size_mode="${popup_size_mode_override}"
    elif [ "${CONFIGURE_ALLOW_DISK_FALLBACK:-}" = "1" ] && [ -f "${CONFIG_FILE}" ]; then
        local existing_mode
        existing_mode=$(grep -E "^[[:space:]]*${CONFIG_KEY_POPUP_SIZE_MODE}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
        if [ "${existing_mode}" = "display-based" ]; then
            size_mode="display-based"
        fi
    fi

    echo "${size_mode}"
}

format_popup_size_display() {
    # Format a popup size label for display in menus/summaries.
    #
    # Parameters:
    #   $1 - popup_size (e.g., "medium", "custom", "1280x720", "50%x50%")
    #   $2 - popup_size_mode_override (optional): "fixed" or "display-based"
    #   $3 - popup_size_custom_override (optional): e.g., "95%x95%"
    #   $4 - popup_size_custom_absolute_override (optional): e.g., "2432x1368"
    #   $5 - mult_char (optional): "x" or "×" for width/height display
    #   $6 - style (optional): "menu" or "summary"
    #
    # Output:
    #   Echoes a human-friendly label, keeping behavior consistent with existing UI.
    local popup_size="$1"
    local popup_size_mode_override="${2:-}"
    local popup_size_custom_override="${3:-}"
    local popup_size_custom_absolute_override="${4:-}"
    local mult_char="${5:-x}"
    local style="${6:-summary}"

    local size_mode
    size_mode="$(_get_effective_popup_size_mode "${popup_size_mode_override}")"

    local popup_size_display="${popup_size}"

    if [ "${size_mode}" = "display-based" ]; then
        case "${popup_size}" in
            xsmall) popup_size_display="${popup_size} [15%${mult_char}15%]" ;;
            small) popup_size_display="${popup_size} [20%${mult_char}20%]" ;;
            medium) popup_size_display="${popup_size} [30%${mult_char}30%]" ;;
            large) popup_size_display="${popup_size} [50%${mult_char}50%]" ;;
            xlarge) popup_size_display="${popup_size} [75%${mult_char}75%]" ;;
            max) popup_size_display="${popup_size} [90%${mult_char}90%]" ;;
            custom)
                # Prefer provided overrides; fall back to config file.
                local custom_size=""
                if [ -n "${popup_size_custom_override}" ]; then
                    custom_size="${popup_size_custom_override}"
                elif [ "${CONFIGURE_ALLOW_DISK_FALLBACK:-}" = "1" ] && [ -f "${CONFIG_FILE}" ]; then
                    custom_size=$(grep -E "^[[:space:]]*${CONFIG_KEY_POPUP_SIZE_CUSTOM}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
                fi
                if [ -n "${custom_size}" ]; then
                    popup_size_display="custom [${custom_size}]"
                else
                    popup_size_display="custom [50%${mult_char}50%]"
                fi
                ;;
            *)
                # Custom pixel format or percentage format stored directly in POPUP_SIZE.
                if echo "${popup_size}" | grep -qE '^[0-9]+%x[0-9]+%$'; then
                    if [ "${style}" = "menu" ]; then
                        # Preserve original menu behavior: show value twice for raw percentage sizes.
                        popup_size_display="${popup_size} [${popup_size}]"
                    else
                        popup_size_display="${popup_size}"
                    fi
                elif echo "${popup_size}" | grep -qE '^[0-9]+x[0-9]+$'; then
                    if [ "${style}" = "menu" ]; then
                        # Preserve original menu behavior: show value + [valuepx].
                        popup_size_display="${popup_size} [${popup_size}px]"
                    else
                        popup_size_display="${popup_size}px"
                    fi
                fi
                ;;
        esac
    else
        # Fixed pixel mode - show absolute dimensions.
        case "${popup_size}" in
            xsmall) popup_size_display="${popup_size} [384${mult_char}216]" ;;
            small) popup_size_display="${popup_size} [400${mult_char}250]" ;;
            medium) popup_size_display="${popup_size} [800${mult_char}500]" ;;
            large) popup_size_display="${popup_size} [1230${mult_char}720]" ;;
            xlarge) popup_size_display="${popup_size} [1845${mult_char}1080]" ;;
            max) popup_size_display="${popup_size} [2214${mult_char}1296]" ;;
            custom)
                # Prefer provided overrides; fall back to config file.
                local custom_absolute=""
                if [ -n "${popup_size_custom_absolute_override}" ] && echo "${popup_size_custom_absolute_override}" | grep -qE '^[0-9]+x[0-9]+$'; then
                    custom_absolute="${popup_size_custom_absolute_override}"
                elif [ "${CONFIGURE_ALLOW_DISK_FALLBACK:-}" = "1" ] && [ -f "${CONFIG_FILE}" ]; then
                    custom_absolute=$(grep -E "^[[:space:]]*${CONFIG_KEY_POPUP_SIZE_CUSTOM_ABSOLUTE}=" "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '[:space:]')
                fi
                if [ -n "${custom_absolute}" ] && echo "${custom_absolute}" | grep -qE '^[0-9]+x[0-9]+$'; then
                    # Note: keep the original "WIDTHxHEIGHT" value in brackets.
                    popup_size_display="custom [${custom_absolute}]"
                else
                    popup_size_display="custom [1280${mult_char}720]"
                fi
                ;;
            *)
                # Custom pixel format stored directly in POPUP_SIZE.
                if echo "${popup_size}" | grep -qE '^[0-9]+x[0-9]+$'; then
                    if [ "${style}" = "menu" ]; then
                        # Preserve original menu behavior: show value twice for raw pixel sizes.
                        popup_size_display="${popup_size} [${popup_size}]"
                    else
                        popup_size_display="${popup_size}"
                    fi
                fi
                ;;
        esac
    fi

    echo "${popup_size_display}"
}


_CONFIGURE_DISPLAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1090
source "${_CONFIGURE_DISPLAY_DIR}/config-keys.sh"
# shellcheck disable=SC1090
source "${_CONFIGURE_DISPLAY_DIR}/configure-display-menu.sh"
source "${_CONFIGURE_DISPLAY_DIR}/configure-display-grid.sh"
source "${_CONFIGURE_DISPLAY_DIR}/configure-display-summary.sh"
unset _CONFIGURE_DISPLAY_DIR
