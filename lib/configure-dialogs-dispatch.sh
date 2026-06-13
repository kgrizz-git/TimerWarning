#!/bin/bash

###############################################################################
# Sleep Warning System - Linux dialog toolkit dispatch (yad / zenity / kdialog)
# Sourced by configure-dialogs.sh
###############################################################################

# Heuristic: argument looks like a column header (not row data).
_dialog_is_likely_column_name() {
    local arg="$1"
    [[ "${arg}" =~ ^[A-Za-z]$ ]] && return 0
    [[ ! "${arg}" =~ \  ]] && [[ "${arg}" =~ ^[A-Za-z]+$ ]] && [ ${#arg} -le 12 ] && return 0
    [[ "${arg}" =~ ^[A-Za-z][A-Za-z\ ]*[A-Za-z]$ ]] && [ ${#arg} -le 40 ] && return 0
    return 1
}

_show_entry_yad() {
    local title="$1"
    local text="$2"
    local default_value="$3"
    local extra_button="$4"

    if [ -n "${extra_button}" ]; then
        local result
        result=$(yad --entry --title="${title}" --text="${text}" \
            --entry-text="${default_value}" \
            --extra-button="${extra_button}" \
            --button="OK:0" --button="Cancel:1" \
            2>/dev/null)
        local exit_code=$?
        if [ ${exit_code} -eq 1 ] && [ "${result}" = "${extra_button}" ]; then
            echo "EXTRA_BUTTON:${extra_button}"
            return 1
        elif [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
            echo "${result%%|*}"
            return 0
        fi
        return 1
    fi

    local result
    result=$(yad --entry --title="${title}" --text="${text}" \
        --entry-text="${default_value}" \
        --button="OK:0" --button="Cancel:1" \
        2>/dev/null)
    local exit_code=$?
    if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
        echo "${result%%|*}"
    fi
    return ${exit_code}
}

_show_entry_zenity() {
    local title="$1"
    local text="$2"
    local default_value="$3"
    local extra_button="$4"

    if [ -n "${extra_button}" ]; then
        local tmpfile
        tmpfile=$(mktemp)
        zenity --entry --title="${title}" --text="${text}" \
            --entry-text="${default_value}" \
            --extra-button="${extra_button}" \
            > "${tmpfile}" 2>/dev/null
        local exit_code=$?
        local result
        result=$(cat "${tmpfile}" 2>/dev/null)
        rm -f "${tmpfile}"
        if [ ${exit_code} -eq 1 ] && [ "${result}" = "${extra_button}" ]; then
            echo "EXTRA_BUTTON:${extra_button}"
            return 1
        elif [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
            echo "${result}"
            return 0
        fi
        return 1
    fi

    local result
    result=$(zenity --entry --title="${title}" --text="${text}" \
        --entry-text="${default_value}" 2>/dev/null)
    local exit_code=$?
    if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
        echo "${result}"
    fi
    return ${exit_code}
}

_show_entry_kdialog() {
    local title="$1"
    local text="$2"
    local default_value="$3"

    local result
    result=$(kdialog --title "${title}" --inputbox "${text}" "${default_value}" \
        2>/dev/null)
    local exit_code=$?
    if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
        echo "${result}"
    fi
    return ${exit_code}
}

_show_multi_column_list_yad() {
    local title="$1"
    local text="$2"
    local width="$3"
    local height="$4"
    local print_column="$5"
    local -n _cols="$6"
    local -n _data="$7"

    local yad_args=("--list" "--title=${title}" "--text=${text}" \
        "--width=${width}" "--height=${height}" \
        "--fixed" \
        "--print-column=${print_column}" \
        "--separator=")

    local col_name
    for col_name in "${_cols[@]}"; do
        yad_args+=("--column=${col_name}")
    done
    yad_args+=("${_data[@]}")

    local result
    result=$(yad "${yad_args[@]}" 2>/dev/null)
    local exit_code=$?
    if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
        echo "${result%%|*}"
    else
        echo "${result}"
    fi
    return ${exit_code}
}

_show_multi_column_list_zenity() {
    local title="$1"
    local text="$2"
    local width="$3"
    local height="$4"
    local print_column="$5"
    local -n _cols="$6"
    local -n _data="$7"

    local zenity_args=("--list" "--title=${title}" "--text=${text}" \
        "--width=${width}" "--height=${height}" \
        "--print-column=${print_column}")

    local col_name
    for col_name in "${_cols[@]}"; do
        zenity_args+=("--column=${col_name}")
    done
    zenity_args+=("${_data[@]}")

    local result
    result=$(zenity "${zenity_args[@]}" 2>/dev/null)
    local exit_code=$?
    if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
        result=$(echo "${result}" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "${result}" ]; then
            echo "${result}"
            return 0
        fi
        return 1
    fi
    return ${exit_code}
}

_show_multi_column_list_kdialog() {
    local title="$1"
    local text="$2"
    local print_column="$5"
    local -n _cols="$6"
    local -n _data="$7"
    local num_columns=${#_cols[@]}

    local header_text="${text}"
    if [ ${num_columns} -gt 1 ]; then
        local header_line=""
        local col_idx
        for col_idx in $(seq 0 $((num_columns - 1))); do
            if [ ${col_idx} -gt 0 ]; then
                header_line="${header_line} | "
            fi
            header_line="${header_line}${_cols[${col_idx}]}"
        done
        header_text="${text}"$'\n\n'"Columns: ${header_line}"
    fi

    local kdialog_args=("--title" "${title}" "--menu" "${header_text}")
    local i=0
    local num_data=${#_data[@]}

    while [ $i -lt $num_data ]; do
        local tag="${_data[$i]}"
        local desc=""
        if [ ${num_columns} -gt 1 ]; then
            local col_idx=0
            while [ ${col_idx} -lt ${num_columns} ] && [ $((i + col_idx)) -lt ${num_data} ]; do
                if [ ${col_idx} -gt 0 ]; then
                    desc="${desc} | "
                fi
                desc="${desc}${_data[$((i + col_idx))]}"
                col_idx=$((col_idx + 1))
            done
        else
            desc="${tag}"
        fi
        kdialog_args+=("${tag}" "${desc}")
        i=$((i + num_columns))
    done

    local result
    result=$(kdialog "${kdialog_args[@]}" 2>/dev/null)
    local exit_code=$?
    if [ ${exit_code} -eq 0 ] && [ -n "${result}" ]; then
        local row_idx=0
        while [ ${row_idx} -lt ${num_data} ]; do
            if [ "${_data[${row_idx}]}" = "${result}" ]; then
                local target_col_idx=$((print_column - 1))
                if [ $((row_idx + target_col_idx)) -lt ${num_data} ]; then
                    echo "${_data[$((row_idx + target_col_idx))]}"
                else
                    echo "${result}"
                fi
                return ${exit_code}
            fi
            row_idx=$((row_idx + num_columns))
        done
        echo "${result}"
    fi
    return ${exit_code}
}
