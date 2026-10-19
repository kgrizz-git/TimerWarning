#!/bin/bash

###############################################################################
# Sleep Warning System - Interactive Configuration Wizard
#
# ⛔ AGENTS / AUTOMATION: this is an INTERACTIVE script. Its text-mode menus are
#    read loops that can SPIN FOREVER on EOF stdin (no terminal + no input),
#    burning CPU and growing redirected output WITHOUT BOUND. This once produced
#    ~465 GB of /tmp files and filled the disk. NEVER run it backgrounded with
#    redirected output and no timeout. Always: a `timeout`, controlled stdin
#    (`</dev/null` or finite valid input), and bounded output — then clean up
#    (`pkill -f configure.sh`). See CLAUDE.md "never run configure.sh unbounded".
#
# This script provides a user-friendly GUI interface for configuring restricted
# hours for the sleep warning system. It walks users through setting up
# restricted hours for each day of the week.
#
# Requirements:
# - bash
# - yad, zenity, or kdialog (for GUI mode) or fallback to text prompts
#
# Usage:
#   ./configure.sh [OPTIONS]
#   sleep-warning-configure [OPTIONS] (after installation)
#
# Options:
#   --text, --no-gui    Force text mode (disable GUI)
#   --gui               Force GUI mode (requires yad, zenity, or kdialog)
#   --help, -h          Show help message
#
# By default, GUI mode is used if a dialog tool (yad/zenity/kdialog) is available and a display is present.
#
# Output:
# - Updates ~/.config/sleep-warning/config/sleep-warning.conf with user selections (Enhancement #18)
###############################################################################

# Determine script directory and library search paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_LIB_DIR="${SCRIPT_DIR}/lib"
INSTALLED_LIB_DIR="${HOME}/.local/lib/sleep-warning"

for _bootstrap_lib in \
    "${INSTALLED_LIB_DIR}/_bootstrap-bash4.sh" \
    "${SCRIPT_LIB_DIR}/_bootstrap-bash4.sh"; do
    if [ -f "${_bootstrap_lib}" ]; then
        # shellcheck disable=SC1090
        source "${_bootstrap_lib}"
        _bootstrap_bash4 "${BASH_SOURCE[0]}" "$@"
        break
    fi
done
unset _bootstrap_lib

# Source shared library loader helper
LIB_HELPER_PATH=""
for candidate in \
    "${INSTALLED_LIB_DIR}/library-loader.sh" \
    "${SCRIPT_LIB_DIR}/library-loader.sh"; do
    if [ -z "${LIB_HELPER_PATH}" ] && [ -f "${candidate}" ]; then
        LIB_HELPER_PATH="${candidate}"
    fi
done

if [ -z "${LIB_HELPER_PATH}" ]; then
    echo "Error: library loader helper not found. Please reinstall the Sleep Warning System." >&2
    exit 1
fi

# shellcheck disable=SC1090
source "${LIB_HELPER_PATH}"
init_library_paths "${INSTALLED_LIB_DIR}" "${SCRIPT_LIB_DIR}"

LIB_DIR="$(detect_library_dir 2>/dev/null)"
if [ -z "${LIB_DIR}" ]; then
    LIB_DIR="${SCRIPT_LIB_DIR}"
fi

# Source library modules in dependency order
source_required_lib "configure-core.sh" || exit 1
if type ensure_day_vars >/dev/null 2>&1; then
    ensure_day_vars
fi
if type ensure_day_names >/dev/null 2>&1; then
    ensure_day_names
fi
source_required_lib "config.sh" || exit 1
source_required_lib "logging.sh" || exit 1
source_required_lib "time-validation.sh" || exit 1
source_required_lib "config-locking.sh" || exit 1  # Enhancement #18: Config file locking
source_required_lib "platform.sh" || exit 1
if is_darwin; then
    source_required_lib "display-detection-darwin.sh" || exit 1
else
    source_required_lib "display-detection.sh" || exit 1
fi
source_required_lib "desktop-environment.sh" || exit 1
source_required_lib "configure-dialogs.sh" || exit 1
if is_darwin; then
    source_optional_lib "configure-dialogs-darwin.sh" || true
fi
source_required_lib "configure-config.sh" || exit 1
source_required_lib "configure-validation.sh" || exit 1
source_required_lib "configure-time.sh" || exit 1
source_required_lib "time-calculations.sh" || exit 1
source_required_lib "configure-ui.sh" || exit 1
source_required_lib "configure-input-basic.sh" || exit 1
source_required_lib "configure-input-popup.sh" || exit 1
source_required_lib "configure-input-features.sh" || exit 1
source_required_lib "configure-input-time.sh" || exit 1
source_required_lib "configure-input-service.sh" || exit 1
source_required_lib "configure-display.sh" || exit 1
source_required_lib "configure-workflow.sh" || exit 1
source_required_lib "configure-partial-lock.sh" || exit 1
source_optional_lib "time-parsing.sh" || true
source_required_lib "service-config.sh" || exit 1

# Ensure we have a UTF-8 locale so GUI dialogs (yad/zenity) can render
# extended characters reliably. Without this, yad aborts when parsing
# strings containing symbols like the multiplication sign.
#
# Prefer dialog_prepare_utf8_locale (portable C.UTF-8) when available: a host
# LANG that already reports UTF-8 (e.g. en_US.UTF-8) is not enough for
# Nix-packaged yad, which falls back to plain C and then rejects em dashes.
ensure_utf8_locale() {
    if type dialog_prepare_utf8_locale >/dev/null 2>&1; then
        # Reset so a stale empty/partial decision cannot skip the portable switch.
        DIALOG_UTF8_CONFIRMED=""
        dialog_prepare_utf8_locale
        return
    fi

    # If locale command is missing, there's nothing we can do
    if ! command -v locale >/dev/null 2>&1; then
        return
    fi

    # Prefer portable C.* UTF-8 even when the current charmap already looks UTF-8.
    local candidate
    for candidate in "C.UTF-8" "C.utf8" "en_US.UTF-8" "en_US.utf8"; do
        if LC_ALL="${candidate}" locale charmap 2>/dev/null | grep -qi 'utf-8'; then
            export LC_ALL="${candidate}"
            export LANG="${candidate}"
            export LC_CTYPE="${candidate}"
            return
        fi
    done

    echo "WARNING: UTF-8 locale not available; GUI text may be limited." >&2
}

# Main function
main() {
    # Clean up any temp files this session created if the wizard is interrupted.
    _configure_cleanup_tmp() {
        rm -f "${CONFIG_DIR}"/*.tmp.* 2>/dev/null || true
    }
    _configure_session_cleanup() {
        _configure_cleanup_tmp
        if type _cd_darwin_daemon_stop >/dev/null 2>&1; then
            _cd_darwin_daemon_stop
        fi
    }
    trap '_configure_session_cleanup; exit 130' INT TERM
    trap '_configure_session_cleanup' EXIT

    ensure_utf8_locale

    local use_gui="false"
    local force_text=false
    local force_gui=false
    
    # Parse command-line arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --text|--no-gui)
                force_text=true
                shift
                ;;
            --gui)
                force_gui=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --text, --no-gui    Force text mode (disable GUI)"
                echo "  --gui               Force GUI mode (requires yad, zenity, or kdialog)"
                echo "  --help, -h          Show this help message"
                echo ""
                echo "By default, GUI mode is used if a dialog tool (yad/zenity/kdialog) is available and a display is present."
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Use --help for usage information." >&2
                exit 1
                ;;
        esac
    done
    
    # Determine GUI mode
    if [ "${force_text}" = "true" ]; then
        use_gui="false"
    elif [ "${force_gui}" = "true" ]; then
        if has_dialog_tool; then
            use_gui="true"
        else
            echo "Error: --gui flag specified but no dialog tool (yad/zenity/kdialog) is available." >&2
            echo "Please install yad, zenity, or kdialog, or use --text mode." >&2
            exit 1
        fi
    else
        # Auto-detect: use GUI if available
        if has_gui && has_dialog_tool; then
            use_gui="true"
        fi
    fi
    
    # macOS: start long-lived tkinter dialog helper early for faster screen switches.
    # Spawning before the welcome alert (osascript) hides Python cold-start latency.
    if [ "${use_gui}" = "true" ] && is_darwin && type _cd_darwin_daemon_start >/dev/null 2>&1; then
        _cd_darwin_daemon_start || true
    fi
    
    # Partial lock mode: tighten-only edits during restriction / configure-block / config-file lock hours.
    CONFIGURE_PARTIAL_LOCK_MODE=false
    if type configure_partial_lock_is_active >/dev/null 2>&1; then
        if configure_partial_lock_is_active; then
            CONFIGURE_PARTIAL_LOCK_MODE=true
        fi
    fi
    
    # Show welcome (full or limited)
    if [ "${CONFIGURE_PARTIAL_LOCK_MODE}" = "true" ]; then
        show_welcome "${use_gui}"
        if type configure_partial_lock_show_banner >/dev/null 2>&1; then
            configure_partial_lock_show_banner "${use_gui}"
        fi
    else
        show_welcome "${use_gui}"
    fi
    
    # Declare global arrays and variables BEFORE calling load_existing_config()
    # This ensures they exist in the parent shell
    declare -g -a config_lines=()
    declare -g -a summary_lines=()
    # Lock hours lines (Enhancement #19 Phase 2 - Additional Configurable Lock Hours)
    # This is a sparse array indexed 0-6 (Sunday-Saturday) with entries like:
    #   CONFIG_LOCK_HOURS_MONDAY=9-17
    declare -g -a lock_hours_lines=()
    # Uninstall lock hours lines (Enhancement #26 Phase 2 - Additional Uninstall Lock Hours)
    # This is a sparse array indexed 0-6 (Sunday-Saturday) with entries like:
    #   UNINSTALL_LOCK_HOURS_MONDAY=9-17
    declare -g -a uninstall_lock_hours_lines=()
    declare -g check_interval popup_size popup_size_mode popup_size_custom popup_size_custom_absolute popup_position min_display_time popup_immovable popup_auto_close configure_block_enabled uninstall_protection_mode pause_enabled pause_duration pause_cooldown_hours dialog_tool config_lock_enabled gaming_mode_experimental_enabled
    
    # Load existing configuration
    # Function sets global variables and populates global arrays directly
    load_existing_config

    if type configure_hours_data_changed >/dev/null 2>&1; then
        configure_hours_data_changed
    fi

    if [ "${CONFIGURE_PARTIAL_LOCK_MODE}" = "true" ] && type configure_partial_lock_capture_baseline >/dev/null 2>&1; then
        configure_partial_lock_capture_baseline
    fi
    
    # Ensure dialog_tool is initialized (set by load_existing_config(), but provide fallback)
    dialog_tool="${dialog_tool:-auto}"
    # Main configuration loop
    while true; do
        # Get section status indicators for restricted hours
        local status_data
        status_data=$(get_section_status)
        local weekdays_status weekends_status
        IFS='|' read -r weekdays_status weekends_status <<< "${status_data}"
        
        # Lock / uninstall lock status (refreshed when hour arrays change)
        local lock_hours_status="${CONFIGURE_LOCK_HOURS_STATUS:-[None]}"
        local uninstall_lock_hours_status="${CONFIGURE_UNINSTALL_LOCK_HOURS_STATUS:-[None]}"
        
        # Get current service mode for menu display (option 12)
        local current_service_mode
        current_service_mode=$(get_current_service_mode)
        if [ "${gaming_mode_experimental_enabled:-false}" = "true" ]; then
            current_service_mode="gaming"
        elif [ "${current_service_mode}" = "gaming" ] && [ "${gaming_mode_experimental_enabled:-}" = "false" ]; then
            current_service_mode="desktop"
        fi
        local service_mode_status="[${current_service_mode}]"
        
        # Calculate dialog tool status for menu display (in-memory dialog_tool)
        local dialog_tool_status=""
        local current_dialog_tool="${dialog_tool:-auto}"
        
        if [ "${current_dialog_tool}" = "auto" ]; then
            dialog_tool_status="[Automatic]"
        else
            # Check if selected tool is installed
            if command -v "${current_dialog_tool}" >/dev/null 2>&1; then
                dialog_tool_status="[${current_dialog_tool}]"
            else
                dialog_tool_status="[${current_dialog_tool} - not installed]"
            fi
        fi
        
        # Show main menu
        local menu_choice
        menu_choice=$(show_main_menu "${use_gui}" "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${popup_auto_close}" "${weekdays_status}" "${weekends_status}" "${configure_block_enabled}" "${lock_hours_status}" "${uninstall_protection_mode}" "${uninstall_lock_hours_status}" "${pause_enabled}" "${pause_duration}" "${pause_cooldown_hours}" "${dialog_tool_status}" "${config_lock_enabled}" "${popup_size_mode}" "${popup_size_custom}" "${popup_size_custom_absolute}" "${service_mode_status}")
        local menu_exit=$?
        
        if [ "${menu_exit}" -eq 2 ] || [ "${menu_choice}" = "CANCELLED" ]; then
            # User cancelled
            exit 0
        fi
        
        if [ "${menu_exit}" -ne 0 ]; then
            continue  # Show menu again
        fi
        
        # Handle menu choice
        case "${menu_choice}" in
            1)
                # Popup display frequency (Enhancement #30)
                local new_interval
                new_interval=$(get_check_interval "${use_gui}")
                if [ "${new_interval}" = "CANCELLED" ]; then
                    # User already confirmed cancellation in get_check_interval (configure-input-time.sh)
                    exit 0
                else
                    check_interval="${new_interval}"
                fi
                ;;
            2)
                # Window Behavior (submenu: size, position, min display time, immovable, auto-close, Back)
                while true; do
                    local sub_choice
                    sub_choice=$(show_window_behavior_submenu "${use_gui}" "${popup_size}" "${popup_size_mode}" "${popup_size_custom}" "${popup_size_custom_absolute}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${popup_auto_close}")
                    local sub_exit=$?
                    if [ ${sub_exit} -eq 2 ]; then
                        exit 0
                    fi
                    if [ ${sub_exit} -ne 0 ] || [ -z "${sub_choice}" ] || [ "${sub_choice}" = "6" ]; then
                        break
                    fi
                    case "${sub_choice}" in
                        1)
                            local new_size_mode size_rc
                            new_size_mode=$(get_popup_size_mode_config "${use_gui}")
                            size_rc=$?
                            if [ "${new_size_mode}" = "CANCELLED" ] || [ ${size_rc} -eq 2 ]; then exit 0; fi
                            if [ "${new_size_mode}" = "BACK" ] || [ ${size_rc} -eq 1 ]; then continue; fi
                            popup_size_mode="${new_size_mode}"
                            local new_size new_size_rc
                            new_size=$(get_popup_size_config "${use_gui}" "${popup_size_mode}")
                            new_size_rc=$?
                            if [ "${new_size}" = "CANCELLED" ] || [ ${new_size_rc} -eq 2 ]; then exit 0; fi
                            if [ "${new_size}" = "BACK" ] || [ ${new_size_rc} -eq 1 ]; then continue; fi
                            if echo "${new_size}" | grep -qE '^custom\|'; then
                                popup_size="custom"
                                popup_size_custom=$(echo "${new_size}" | cut -d'|' -f2)
                                if echo "${popup_size_custom}" | grep -qE '^[0-9]+%x[0-9]+%$'; then
                                    local width_percent height_percent
                                    width_percent=$(echo "${popup_size_custom}" | cut -d'x' -f1 | tr -d '%')
                                    height_percent=$(echo "${popup_size_custom}" | cut -d'x' -f2 | tr -d '%')
                                    popup_size_custom_absolute="$((2560 * width_percent / 100))x$((1440 * height_percent / 100))"
                                else
                                    popup_size_custom_absolute="${popup_size_custom}"
                                fi
                            else
                                popup_size="${new_size}"
                            fi
                            ;;
                        2)
                            local new_position pos_rc
                            new_position=$(get_popup_position_config "${use_gui}")
                            pos_rc=$?
                            if [ "${new_position}" = "CANCELLED" ] || [ ${pos_rc} -eq 2 ]; then exit 0; fi
                            if [ "${new_position}" = "BACK" ] || [ ${pos_rc} -eq 1 ]; then continue; fi
                            popup_position="${new_position}"
                            ;;
                        3)
                            local new_time time_rc
                            new_time=$(get_min_display_time_config "${use_gui}")
                            time_rc=$?
                            if [ "${new_time}" = "CANCELLED" ] || [ ${time_rc} -eq 2 ]; then exit 0; fi
                            if [ "${new_time}" = "BACK" ] || [ ${time_rc} -eq 1 ]; then continue; fi
                            min_display_time="${new_time}"
                            ;;
                        4)
                            local new_immovable imm_rc
                            new_immovable=$(get_popup_immovable_config "${use_gui}")
                            imm_rc=$?
                            if [ "${new_immovable}" = "CANCELLED" ] || [ ${imm_rc} -eq 2 ]; then exit 0; fi
                            if [ "${new_immovable}" = "BACK" ] || [ ${imm_rc} -eq 1 ]; then continue; fi
                            popup_immovable="${new_immovable}"
                            ;;
                        5)
                            local new_auto_close ac_rc
                            new_auto_close=$(get_popup_auto_close_config "${use_gui}")
                            ac_rc=$?
                            if [ "${new_auto_close}" = "CANCELLED" ] || [ ${ac_rc} -eq 2 ]; then exit 0; fi
                            if [ "${new_auto_close}" = "BACK" ] || [ ${ac_rc} -eq 1 ]; then continue; fi
                            popup_auto_close="${new_auto_close}"
                            ;;
                        *) break ;;
                    esac
                done
                ;;
            3)
                # Weekdays Configuration
                configure_weekdays_section "${use_gui}" config_lines summary_lines
                local weekdays_exit=$?
                if [ "${weekdays_exit}" -eq 2 ]; then
                    # User cancelled
                    exit 0
                fi
                configure_hours_data_changed
                ;;
            4)
                # Weekends Configuration
                configure_weekends_section "${use_gui}" config_lines summary_lines
                local weekends_exit=$?
                if [ "${weekends_exit}" -eq 2 ]; then
                    # User cancelled
                    exit 0
                fi
                configure_hours_data_changed
                ;;
            5)
                # Configuration Lock (Tighten-Only) and Config File Locking
                local security_result
                security_result=$(get_security_settings_config "${use_gui}" "${configure_block_enabled}" "${config_lock_enabled}")
                if [ "${security_result}" = "CANCELLED" ]; then
                    exit 0
                else
                    configure_block_enabled=$(echo "${security_result}" | cut -d'|' -f1)
                    config_lock_enabled=$(echo "${security_result}" | cut -d'|' -f2)
                fi
                ;;
            6)
                # Additional Configuration Lock Hours (Enhancement #19 Phase 2)
                configure_lock_hours_section "${use_gui}" lock_hours_lines
                local lock_exit=$?
                if [ "${lock_exit}" -eq 2 ]; then
                    exit 0
                fi
                configure_hours_data_changed
                ;;
            7)
                # Uninstall Protection Configuration (Enhancement #26)
                local new_protection_mode
                new_protection_mode=$(get_uninstall_protection_mode_config "${use_gui}")
                if [ "${new_protection_mode}" = "CANCELLED" ]; then
                    exit 0
                else
                    uninstall_protection_mode="${new_protection_mode}"
                fi
                ;;
            8)
                # Uninstall Lock Hours Configuration (Enhancement #26 Phase 2)
                configure_uninstall_lock_hours_section "${use_gui}" uninstall_lock_hours_lines
                local uninstall_lock_exit=$?
                if [ "${uninstall_lock_exit}" -eq 2 ]; then
                    exit 0
                fi
                configure_hours_data_changed
                ;;
            9)
                # View Weekly Hours Settings
                declare -g grid_result_var=""
                while true; do
                    grid_result_var=""
                    show_visual_grid "${use_gui}" config_lines summary_lines lock_hours_lines uninstall_lock_hours_lines
                    local grid_exit=$?
                    if [ "${grid_exit}" -ne 0 ] || [ "${grid_result_var}" = "BACK" ]; then
                        break
                    fi
                    local day_index="${grid_result_var}"
                    configure_day_from_grid "${day_index}" "${use_gui}" config_lines summary_lines lock_hours_lines uninstall_lock_hours_lines
                    local config_exit=$?
                    if [ "${config_exit}" -eq 2 ]; then
                        # User confirmed cancellation from within grid — exit wizard like other sections
                        exit 0
                    fi
                    configure_hours_data_changed
                done
                ;;
            10)
                # Pause Settings Configuration (Enhancement #21)
                local new_pause_enabled
                new_pause_enabled=$(get_pause_enabled_config "${use_gui}")
                if [ "${new_pause_enabled}" = "CANCELLED" ]; then
                    exit 0
                else
                    pause_enabled="${new_pause_enabled}"
                fi

                if [ "${pause_enabled}" = "true" ]; then
                    local new_pause_cooldown_hours
                    new_pause_cooldown_hours=$(get_pause_cooldown_hours_config "${use_gui}")
                    if [ "${new_pause_cooldown_hours}" = "CANCELLED" ]; then
                        exit 0
                    else
                        pause_cooldown_hours="${new_pause_cooldown_hours}"
                    fi

                    local new_pause_duration
                    new_pause_duration=$(get_pause_duration_config "${use_gui}")
                    if [ "${new_pause_duration}" = "CANCELLED" ]; then
                        exit 0
                    else
                        pause_duration="${new_pause_duration}"
                    fi
                fi
                ;;
            11)
                # Dialog Tool Selection (Enhancement #25) - Linux only
                if is_darwin; then
                    echo "Dialog tool selection is not used on macOS (osascript only)." >&2
                    continue
                fi
                local new_dialog_tool
                new_dialog_tool=$(get_dialog_tool_selection "${use_gui}")
                local selection_exit=$?
                
                if [ ${selection_exit} -eq 2 ]; then
                    # User confirmed cancellation - exit configuration
                    exit 0
                elif [ ${selection_exit} -eq 0 ]; then
                    # Valid selection made (including "auto" if user cancelled without confirming)
                    dialog_tool="${new_dialog_tool}"
                    configure_invalidate_dialog_tool_cache
                fi
                # If exit code is 1, function will have already re-prompted, so we continue the loop
                ;;
            12)
                # Service Mode Configuration (Enhancement #4) - Linux only
                if is_darwin; then
                    echo "Service mode configuration is not applicable on macOS." >&2
                    continue
                fi
                configure_service_mode "${use_gui}"
                local service_mode_exit=$?
                if [ "${service_mode_exit}" -eq 2 ]; then
                    # User cancelled
                    exit 0
                fi
                # Continue loop (service mode configuration doesn't affect other settings)
                ;;
            13)
                # Review and Save
                # Note: summary_lines is accessed globally by show_summary to preserve sparse array indices
                if show_summary "${use_gui}" "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${popup_auto_close}" "${configure_block_enabled}" "${popup_size_mode}" "${popup_size_custom}" "${popup_size_custom_absolute}"; then
                    # Validate minute precision compatibility with timer interval
                    if type check_minute_precision_compatibility >/dev/null 2>&1 && type get_timer_run_interval >/dev/null 2>&1; then
                        local compatibility_warning run_interval
                        run_interval=$(get_timer_run_interval "${check_interval}")
                        compatibility_warning=$(check_minute_precision_compatibility "${run_interval}" "${config_lines[@]}")
                        if [ $? -ne 0 ]; then
                            if ! show_question_dialog "Timer Interval Warning" "${compatibility_warning}\n\nDo you want to proceed anyway?" "Yes, Save" "No, Edit Interval" 600 350; then
                                continue  # Return to menu
                            fi
                        fi
                    fi
                    
                    # Validate per-day per-category 16-hour caps before saving (hard block — no override).
                    # Also run the legacy 24/7 check as a safety backstop.
                    local cap_violations=""
                    if type check_daily_caps >/dev/null 2>&1; then
                        local -a _cap_default_lines=()
                        if type append_missing_restriction_default_lines >/dev/null 2>&1; then
                            append_missing_restriction_default_lines _cap_default_lines "${config_lines[@]}"
                        fi
                        cap_violations=$(check_daily_caps \
                            "${configure_block_enabled:-false}" \
                            "${uninstall_protection_mode:-none}" \
                            "CONFIG_LOCK_ENABLED=${config_lock_enabled:-false}" \
                            "${config_lines[@]}" \
                            "${lock_hours_lines[@]}" \
                            "${uninstall_lock_hours_lines[@]}" \
                            "${_cap_default_lines[@]}")
                        if [ -n "${cap_violations}" ]; then
                            # Hard block — no "save anyway" path for cap violations.
                            show_cap_violation_error "${use_gui}" "${cap_violations}"
                            continue  # Return to menu, do NOT call write_config
                        fi
                    fi

                    # Legacy 24/7 (full-week) check as backstop for any gaps.
                    local validation_result
                    validation_result=$(check_restriction_coverage \
                        "${config_lines[@]}" \
                        "${lock_hours_lines[@]}" \
                        "${uninstall_lock_hours_lines[@]}")
                    if [ "${validation_result}" = "block" ]; then
                        show_24_7_error "${use_gui}"
                        continue
                    fi

                    # Validate popup timing (min display vs frequency) before save.
                    if type validate_popup_timing_config >/dev/null 2>&1; then
                        local timing_error
                        timing_error=$(validate_popup_timing_config "${min_display_time}" "${check_interval}" 2>&1)
                        if [ $? -ne 0 ]; then
                            show_error_dialog "Configuration Error" "${timing_error}"
                            continue
                        fi
                    fi

                    # Track safety-override flags (used for config-file comments only; no longer
                    # applied as part of the "warn" path — that path is removed).
                    local popup_size_overridden=""
                    local configure_block_overridden=""
                    local lock_hours_cleared=""
                    local uninstall_lock_hours_cleared=""
                    
                    # Partial lock: validate tighten-only changes vs session baseline.
                    if [ "${CONFIGURE_PARTIAL_LOCK_MODE}" = "true" ] && type configure_partial_lock_validate_proposed >/dev/null 2>&1; then
                        local partial_lock_errors
                        partial_lock_errors=$(configure_partial_lock_validate_proposed)
                        if [ -n "${partial_lock_errors}" ]; then
                            if type show_partial_lock_violation_error >/dev/null 2>&1; then
                                show_partial_lock_violation_error "${use_gui}" "${partial_lock_errors}"
                            else
                                show_cap_violation_error "${use_gui}" "${partial_lock_errors}"
                            fi
                            continue
                        fi
                    elif configure_partial_lock_is_active; then
                        # Full mode: block save if we crossed into configure-block hours mid-session.
                        show_config_locked_error "${use_gui}" "Configuration"
                        continue
                    fi

                    # Write configuration (with possibly modified values after safety overrides)
                    # Pass restriction config_lines, lock_hours_lines (Phase 2), and uninstall_lock_hours_lines (Enhancement #26 Phase 2),
                    # followed by optional safety override flags so write_config can add comments.
                    # Enhancement #3: Include popup_size_mode, popup_size_custom, and popup_size_custom_absolute
                    # Enhancement #22 extension: Include override flags for clearing additional hours
                    if [ -n "${DEBUG_CONFIG_WRITE:-}" ]; then
                        echo "DEBUG: LIB_DIR=${LIB_DIR}" >&2
                        echo "DEBUG: config_lines=${config_lines[*]}" >&2
                        echo "DEBUG: lock_hours_lines=${lock_hours_lines[*]}" >&2
                        echo "DEBUG: uninstall_lock_hours_lines=${uninstall_lock_hours_lines[*]}" >&2
                    fi

                    if write_config "${check_interval}" "${popup_size}" "${popup_position}" "${min_display_time}" "${popup_immovable}" "${popup_auto_close}" "${configure_block_enabled}" "${uninstall_protection_mode}" "${pause_enabled}" "${pause_duration}" "${pause_cooldown_hours}" "${dialog_tool}" "${config_lock_enabled}" "${popup_size_mode}" "${popup_size_custom}" "${popup_size_custom_absolute}" "${config_lines[@]}" "${lock_hours_lines[@]}" "${uninstall_lock_hours_lines[@]}" "${popup_size_overridden}" "${configure_block_overridden}" "${lock_hours_cleared}" "${uninstall_lock_hours_cleared}"; then
                        # Update timer file if it exists
                        if [ -f "${TIMER_FILE}" ]; then
                            if update_timer_file "${check_interval}"; then
                                show_success "${use_gui}" "${check_interval}"
                            else
                                local warning_msg="Configuration saved, but failed to update timer file.\n\nYou may need to manually update:\n${TIMER_FILE}\n\nThen run:\nsystemctl --user daemon-reload\nsystemctl --user restart ${SERVICE_NAME}.timer"
                                if [ "${use_gui}" = "true" ] && has_dialog_tool; then
                                    show_info_dialog "Warning" "${warning_msg}" 600 300
                                else
                                    echo "${warning_msg}" >&2
                                fi
                            fi
                        else
                            show_success "${use_gui}" "${check_interval}"
                        fi
                        exit 0
                    else
                        local write_rc=$?
                        if [ "${write_rc}" -eq 2 ]; then
                            show_cap_violation_error "${use_gui}" "${CONFIG_WRITE_CAP_VIOLATIONS}"
                            continue
                        fi
                        local error_msg="Error: Failed to write configuration file.\n\nPlease check permissions for:\n${CONFIG_DIR}"
                        if [ "${use_gui}" = "true" ] && has_dialog_tool; then
                            show_info_dialog "Error" "${error_msg}" 600 250
                        else
                            echo "${error_msg}" >&2
                        fi
                        # Return to menu instead of exiting on error
                    fi
                fi
                # User didn't confirm, return to menu
                ;;
        esac
    done
}

# Run main function
main "$@"
