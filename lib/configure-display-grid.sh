#!/bin/bash

###############################################################################
# Sleep Warning System - Weekly hours visual grid (configure wizard)
# Sourced by configure-display.sh
###############################################################################

# Build or reuse cached weekly grid row data for show_visual_grid.
# Populates global _CONFIGURE_GRID_* arrays (including Back row).
_configure_build_grid_cache() {
    # Use distinct nameref names; $1 may be "summary_lines_ref" (already a nameref upstream).
    local -n _cg_summary="$1"
    local -n _cg_lock="$2"
    local -n _cg_uninstall="$3"

    if [ "${_CONFIGURE_GRID_CACHE_VALID}" = "true" ]; then
        return 0
    fi

    _CONFIGURE_GRID_DAY_NAMES=()
    _CONFIGURE_GRID_RESTRICTED=()
    _CONFIGURE_GRID_LOCK=()
    _CONFIGURE_GRID_UNINSTALL=()

    local day_index day_name restricted_hours lock_hours uninstall_lock_hours
    for day_index in 0 1 2 3 4 5 6; do
        day_name="${DAY_NAMES[${day_index}]}"
        restricted_hours=""
        lock_hours=""

        if [ -n "${_cg_summary[${day_index}]}" ]; then
            local line="${_cg_summary[${day_index}]}"
            local range
            range=$(echo "${line}" | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [ "${range}" = "(no restrictions)" ] || [ -z "${range}" ]; then
                local inherited
                inherited=$(get_inherited_restrictions "${day_index}" "$1" || true)
                if [ -n "${inherited}" ]; then
                    restricted_hours="${inherited}"
                else
                    restricted_hours="[no restrictions]"
                fi
            else
                restricted_hours=$(format_ranges_human "${range}" "${day_name}")
            fi
        else
            local inherited
            inherited=$(get_inherited_restrictions "${day_index}" "$1" || true)
            if [ -n "${inherited}" ]; then
                restricted_hours="${inherited}"
            else
                restricted_hours="[no restrictions]"
            fi
        fi

        if [ -n "${_cg_lock[${day_index}]:-}" ]; then
            local lock_entry="${_cg_lock[${day_index}]}"
            local lock_range
            lock_range=$(echo "${lock_entry}" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -n "${lock_range}" ]; then
                lock_hours=$(format_ranges_human "${lock_range}" "${day_name}")
            else
                lock_hours="[no lock hours]"
            fi
        else
            lock_hours="[no lock hours]"
        fi

        if [ -n "${_cg_uninstall[${day_index}]:-}" ]; then
            local uninstall_lock_entry="${_cg_uninstall[${day_index}]}"
            local uninstall_lock_range
            uninstall_lock_range=$(echo "${uninstall_lock_entry}" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [ -n "${uninstall_lock_range}" ]; then
                uninstall_lock_hours=$(format_ranges_human "${uninstall_lock_range}" "${day_name}")
            else
                uninstall_lock_hours="[no uninstall lock hours]"
            fi
        else
            uninstall_lock_hours="[no uninstall lock hours]"
        fi

        _CONFIGURE_GRID_DAY_NAMES+=("${day_name}")
        _CONFIGURE_GRID_RESTRICTED+=("${restricted_hours}")
        _CONFIGURE_GRID_LOCK+=("${lock_hours}")
        _CONFIGURE_GRID_UNINSTALL+=("${uninstall_lock_hours}")
    done

    _CONFIGURE_GRID_DAY_NAMES+=("[Back]")
    _CONFIGURE_GRID_RESTRICTED+=("Return to Main Menu")
    _CONFIGURE_GRID_LOCK+=("")
    _CONFIGURE_GRID_UNINSTALL+=("")

    _CONFIGURE_GRID_TABLE_JSON=""
    if type _cd_darwin_build_table_json >/dev/null 2>&1; then
        local -a _cg_table_columns=("Day" "Restricted Hours" "Config Lock Hours" "Uninstall Lock Hours")
        local -a _cg_table_data=()
        local _cg_i
        for _cg_i in "${!_CONFIGURE_GRID_DAY_NAMES[@]}"; do
            _cg_table_data+=("${_CONFIGURE_GRID_DAY_NAMES[${_cg_i}]}")
            _cg_table_data+=("${_CONFIGURE_GRID_RESTRICTED[${_cg_i}]}")
            _cg_table_data+=("${_CONFIGURE_GRID_LOCK[${_cg_i}]}")
            _cg_table_data+=("${_CONFIGURE_GRID_UNINSTALL[${_cg_i}]}")
        done
        _cd_column_names=("${_cg_table_columns[@]}")
        _cd_num_columns=4
        _cd_data=("${_cg_table_data[@]}")
        _CONFIGURE_GRID_TABLE_JSON=$(
            _cd_darwin_build_table_json \
                "View Weekly Hours Settings" \
                "Select a day to edit its restricted hours, lock hours, or uninstall lock hours:" \
                1050 \
                500 \
                1
        )
        _CONFIGURE_GRID_TABLE_JSON_TITLE="View Weekly Hours Settings"
    fi

    _CONFIGURE_GRID_CACHE_VALID=true
}

# Format one text-mode grid row (restricted / lock / uninstall lock display strings).
# Parameters: day_index, summary_lines_ref, lock_hours_lines_ref, uninstall_lock_hours_lines_ref
# Sets: _fgr_restricted, _fgr_lock, _fgr_uninstall (caller-local names via nameref outputs).
_format_grid_row() {
    local day_index="$1"
    local -n _fgr_summary="$2"
    local -n _fgr_lock_lines="$3"
    local -n _fgr_uninstall_lines="$4"
    local -n _fgr_restricted="$5"
    local -n _fgr_lock="$6"
    local -n _fgr_uninstall="$7"

    local day_name="${DAY_NAMES[${day_index}]}"
    _fgr_restricted=""
    _fgr_lock=""
    _fgr_uninstall=""

    if [ -n "${_fgr_summary[${day_index}]}" ]; then
        local line="${_fgr_summary[${day_index}]}"
        local range
        range=$(echo "${line}" | cut -d':' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        if [ "${range}" = "(no restrictions)" ] || [ -z "${range}" ]; then
            local inherited
            inherited=$(get_inherited_restrictions "${day_index}" "$2")
            if [ $? -eq 0 ] && [ -n "${inherited}" ]; then
                _fgr_restricted="${inherited}"
            else
                _fgr_restricted="[no restrictions]"
            fi
        else
            _fgr_restricted=$(format_ranges_human "${range}" "${day_name}")
        fi
    else
        local inherited
        inherited=$(get_inherited_restrictions "${day_index}" "$2")
        if [ $? -eq 0 ] && [ -n "${inherited}" ]; then
            _fgr_restricted="${inherited}"
        else
            _fgr_restricted="[no restrictions]"
        fi
    fi

    if [ -n "${_fgr_lock_lines[${day_index}]:-}" ]; then
        local lock_entry="${_fgr_lock_lines[${day_index}]}"
        local lock_range
        lock_range=$(echo "${lock_entry}" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "${lock_range}" ]; then
            _fgr_lock=$(format_ranges_human "${lock_range}" "${day_name}")
        else
            _fgr_lock="[no lock hours]"
        fi
    else
        _fgr_lock="[no lock hours]"
    fi

    if [ -n "${_fgr_uninstall_lines[${day_index}]:-}" ]; then
        local uninstall_lock_entry="${_fgr_uninstall_lines[${day_index}]}"
        local uninstall_lock_range
        uninstall_lock_range=$(echo "${uninstall_lock_entry}" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "${uninstall_lock_range}" ]; then
            _fgr_uninstall=$(format_ranges_human "${uninstall_lock_range}" "${day_name}")
        else
            _fgr_uninstall="[no uninstall lock hours]"
        fi
    else
        _fgr_uninstall="[no uninstall lock hours]"
    fi
}

# Text-mode grid selection loop; sets grid_result_var and returns 0 on valid choice.
_validate_grid_edit() {
    while true; do
        configure_read -p "Select option [0-7]: " choice
        case "${choice}" in
            0)
                declare -g grid_result_var="BACK"
                return 0
                ;;
            1|2|3|4|5|6|7)
                declare -g grid_result_var="$((choice - 1))"
                return 0
                ;;
            *)
                echo "Invalid option. Please enter 0-7." >&2
                ;;
        esac
    done
}

show_visual_grid() {
    local use_gui="$1"
    local -n config_lines_ref="$2"  # Pass by reference
    local -n summary_lines_ref="$3"  # Pass by reference
    local -n lock_hours_lines_ref="$4"  # Pass by reference (Enhancement #19 Phase 2 - lock hours)
    local -n uninstall_lock_hours_lines_ref="$5"  # Pass by reference (Enhancement #26 Phase 2 - uninstall lock hours)

    if [ -n "${DEBUG_CONFIG_WRITE:-}" ]; then
        echo "DEBUG: show_visual_grid DAY_NAMES=${DAY_NAMES[*]}" >&2
    fi
    
    if [ "${use_gui}" = "true" ] && has_dialog_tool; then
        # GUI mode
        while true; do
            _configure_build_grid_cache summary_lines_ref lock_hours_lines_ref uninstall_lock_hours_lines_ref

            local day_names=("${_CONFIGURE_GRID_DAY_NAMES[@]}")
            local restricted_hours_list=("${_CONFIGURE_GRID_RESTRICTED[@]}")
            local lock_hours_list=("${_CONFIGURE_GRID_LOCK[@]}")
            local uninstall_lock_hours_list=("${_CONFIGURE_GRID_UNINSTALL[@]}")

            if [ -n "${DEBUG_CONFIG_WRITE:-}" ]; then
                echo "DEBUG: show_visual_grid local day_names(after)=${day_names[*]}" >&2
            fi

            local selected exit_code
            if [ -n "${_CONFIGURE_GRID_TABLE_JSON:-}" ] \
                && type _cd_darwin_show_table_with_json >/dev/null 2>&1; then
                selected=$(_cd_darwin_show_table_with_json "${_CONFIGURE_GRID_TABLE_JSON}" 0)
                exit_code=$?
            else
                # Build data array in alternating format for multi-column dialog
                # Format: col1_row1, col2_row1, col3_row1, col4_row1, col1_row2, ...
                local grid_data=()
                for i in "${!day_names[@]}"; do
                    grid_data+=("${day_names[${i}]}")
                    grid_data+=("${restricted_hours_list[${i}]}")
                    grid_data+=("${lock_hours_list[${i}]}")
                    grid_data+=("${uninstall_lock_hours_list[${i}]}")
                done

                # Debug: Log what we're sending to dialog (if DEBUG_GRID is set)
                if [ -n "${DEBUG_GRID:-}" ]; then
                    echo "DEBUG: Grid data array (alternating Day, Restricted Hours, Lock Hours, Uninstall Lock Hours):" >&2
                    for i in "${!grid_data[@]}"; do
                        echo "  [${i}]: '${grid_data[${i}]}'" >&2
                    done
                fi

                selected=$(show_multi_column_list_dialog \
                    "View Weekly Hours Settings" \
                    "Select a day to edit its restricted hours, lock hours, or uninstall lock hours:" \
                    1050 \
                    500 \
                    1 \
                    "Day" \
                    "Restricted Hours" \
                    "Config Lock Hours" \
                    "Uninstall Lock Hours" \
                    "${grid_data[@]}")
                exit_code=$?
            fi
            
            # Check if user cancelled (empty choice and non-zero exit)
            if [ ${exit_code} -ne 0 ] && [ -z "${selected}" ]; then
                exit_code=1
            elif [ -n "${selected}" ]; then
                exit_code=0
            fi
            
            if [ -n "${DEBUG_GRID:-}" ]; then
                echo "DEBUG: dialog exit code: ${exit_code}" >&2
                echo "DEBUG: Selected value: '${selected}'" >&2
            fi
            
            if [ "${exit_code}" -ne 0 ] || [ -z "${selected}" ]; then
                # User cancelled - return to main menu
                declare -g grid_result_var="BACK"
                return 0
            fi
            
            # Extract day name from selection
            # With --print-column=1, we get just the Day column (first column)
            local selected_day
            selected_day=$(echo "${selected}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Check if "Back to Menu" was selected
            if [ "${selected_day}" = "[Back]" ]; then
                declare -g grid_result_var="BACK"
                return 0
            fi
            
            # Find day index
            local day_index=-1
            for i in 0 1 2 3 4 5 6; do
                if [ "${DAY_NAMES[${i}]}" = "${selected_day}" ]; then
                    day_index=${i}
                    break
                fi
            done
            
            if [ "${day_index}" -lt 0 ]; then
                # Invalid selection
                show_info_dialog \
                    "Invalid Selection" \
                    "Invalid day selection." \
                    400 \
                    150
                continue
            fi
            
            # Store day index in global variable
            declare -g grid_result_var="${day_index}"
            return 0
        done
    else
        # Text mode
        while true; do
            echo ""
            echo "=== Visual Day/Time Grid ==="
            echo ""
            echo "Select a day to edit its restricted hours or lock hours:"
            echo ""
            
            # Display grid with tab-separated table format
            # Header
            printf "%-3s\t%-9s\t%-30s\t%-30s\t%s\n" "#" "Day" "Restricted Hours" "Lock Hours" "Uninstall Lock Hours"
            printf "%-3s\t%-9s\t%-30s\t%-30s\t%s\n" "---" "---" "----------------" "----------" "---------------------"
            
            for day_index in 0 1 2 3 4 5 6; do
                local day_name="${DAY_NAMES[${day_index}]}"
                local restricted_hours lock_hours uninstall_lock_hours
                _format_grid_row \
                    "${day_index}" \
                    summary_lines_ref \
                    lock_hours_lines_ref \
                    uninstall_lock_hours_lines_ref \
                    restricted_hours \
                    lock_hours \
                    uninstall_lock_hours
                printf "%d.\t%-9s\t%-30s\t%-30s\t%s\n" \
                    $((day_index + 1)) "${day_name}:" \
                    "${restricted_hours}" "${lock_hours}" "${uninstall_lock_hours}"
            done

            echo ""
            echo "0. Back to Main Menu"
            echo ""
            _validate_grid_edit
        done
    fi
}
