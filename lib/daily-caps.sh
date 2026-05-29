#!/bin/bash

###############################################################################
# Sleep Warning System - Per-Day Per-Category Cap Enforcement
#
# This module provides the central safety invariant: on any calendar day,
# no restriction category (popup restriction, configure-block, uninstall-block)
# may have more than 16 hours (960 minutes) of merged coverage.
#
# Unlike the older check_restriction_coverage() which computes a weekly average,
# these functions enforce a hard per-calendar-day cap per category.
#
# Functions:
#   _parse_range_to_minute_intervals  - single range string → minute pairs
#   _compute_day_merged_minutes        - total merged minutes on one calendar day
#   check_daily_caps                   - main invariant enforcer
#
# Dependencies: none (pure bash + awk/sort)
#
# Usage:
#   source lib/daily-caps.sh
#
#   # Configure-time (save gate):
#   violations=$(check_daily_caps "${configure_block_enabled}" \
#       "${uninstall_protection_mode}" \
#       "${config_lines[@]}" "${lock_hours_lines[@]}" "${uninstall_lock_hours_lines[@]}")
#   if [ $? -ne 0 ]; then
#       # violations contains "day_name|category|minutes" lines
#   fi
#
#   # Runtime (sleep-warning.sh validate_config_safety):
#   same call signature
###############################################################################

if [ -z "${DAILY_CAPS_LOADED:-}" ]; then
    DAILY_CAPS_LOADED=1

    # Maximum restricted minutes per calendar day per category (16 hours)
    readonly _DAILY_CAP_MAX_MINUTES=960

    ##########################################################################
    # _parse_range_to_minute_intervals
    #
    # Converts a comma-separated list of time ranges to [start_min, end_min)
    # pairs for a given calendar day context.
    #
    # Parameters:
    #   $1 - ranges_csv: comma-separated range string
    #        Both formats supported: integer hour ("7-23") and HH:MM ("07:00-23:00")
    #   $2 - day_role: "self" (ranges belong to day D) or
    #                  "carry" (ranges from day D-1, overnight portion only)
    #
    # Output (stdout): lines of "start_min end_min"
    #   "self"  non-overnight (s<e):  emits "s e"
    #   "self"  overnight (s>e):      emits "s 1440"  (the D portion)
    #   "carry" overnight (s>e):      emits "0 e"     (the D portion from D-1)
    #   "carry" non-overnight:        ignored
    #
    # All arithmetic uses 10# prefix to avoid octal interpretation.
    ##########################################################################
    _parse_range_to_minute_intervals() {
        local ranges_csv="$1"
        local day_role="${2:-self}"

        [ -z "${ranges_csv}" ] && return 0

        local saved_IFS="${IFS}"
        local IFS=','
        local parts=()
        read -ra parts <<< "${ranges_csv}"
        IFS="${saved_IFS}"

        local r
        for r in "${parts[@]}"; do
            # Trim whitespace
            r="${r## }"
            r="${r%% }"
            [ -z "${r}" ] && continue

            local start_part end_part
            # Try HH:MM-HH:MM first, then H-H / HH-HH
            if [[ "${r}" =~ ^([0-9]{1,2}:[0-9]{2})-([0-9]{1,2}:[0-9]{2})$ ]]; then
                start_part="${BASH_REMATCH[1]}"
                end_part="${BASH_REMATCH[2]}"
            elif [[ "${r}" =~ ^([0-9]{1,2})-([0-9]{1,2})$ ]]; then
                start_part="${BASH_REMATCH[1]}"
                end_part="${BASH_REMATCH[2]}"
            else
                continue  # Unrecognised format — skip silently
            fi

            local start_min end_min
            if [[ "${start_part}" == *":"* ]]; then
                local _sh="${start_part%%:*}" _sm="${start_part##*:}"
                (( 10#${_sh} > 23 || 10#${_sm} > 59 )) && continue
                start_min=$(( 10#${_sh} * 60 + 10#${_sm} ))
            else
                (( 10#${start_part} > 23 )) && continue
                start_min=$(( 10#${start_part} * 60 ))
            fi

            if [[ "${end_part}" == *":"* ]]; then
                local _eh="${end_part%%:*}" _em="${end_part##*:}"
                (( 10#${_eh} > 23 || 10#${_em} > 59 )) && continue
                end_min=$(( 10#${_eh} * 60 + 10#${_em} ))
            else
                (( 10#${end_part} > 23 )) && continue
                end_min=$(( 10#${end_part} * 60 ))
            fi

            if [ "${day_role}" = "self" ]; then
                if [ "${start_min}" -lt "${end_min}" ]; then
                    echo "${start_min} ${end_min}"
                elif [ "${start_min}" -gt "${end_min}" ]; then
                    # Overnight: the portion on day D is [start_min, 1440)
                    echo "${start_min} 1440"
                fi
                # start_min == end_min → zero-length, skip
            elif [ "${day_role}" = "carry" ]; then
                # Only overnight ranges produce carry onto the next day
                if [ "${start_min}" -gt "${end_min}" ] && [ "${end_min}" -gt 0 ]; then
                    echo "0 ${end_min}"
                fi
            fi
        done
    }

    ##########################################################################
    # _compute_day_merged_minutes
    #
    # Returns the total merged minutes covered on a single calendar day,
    # taking into account both the day's own ranges and any overnight carry
    # from the previous day.
    #
    # Parameters:
    #   $1 - self_ranges: comma-sep ranges belonging to this day
    #   $2 - prev_ranges: comma-sep ranges from the previous day
    #                     (only overnight portions are used)
    #
    # Output: integer, total merged minutes (0 to 1440)
    ##########################################################################
    _compute_day_merged_minutes() {
        local self_ranges="$1"
        local prev_ranges="$2"
        local intervals_text=""

        local more
        if [ -n "${self_ranges}" ]; then
            more=$(_parse_range_to_minute_intervals "${self_ranges}" "self")
            [ -n "${more}" ] && intervals_text="${intervals_text}${more}"$'\n'
        fi
        if [ -n "${prev_ranges}" ]; then
            more=$(_parse_range_to_minute_intervals "${prev_ranges}" "carry")
            [ -n "${more}" ] && intervals_text="${intervals_text}${more}"$'\n'
        fi

        if [ -z "${intervals_text}" ]; then
            echo 0
            return
        fi

        # Sort by start minute then merge overlapping intervals, sum total minutes.
        echo "${intervals_text}" | sort -k1,1n -k2,2n | awk '
            BEGIN { s = -1; e = -1; total = 0 }
            /^[[:space:]]*$/ { next }
            {
                if (s < 0) { s = $1; e = $2; next }
                if ($1 <= e) {
                    if ($2 > e) e = $2
                } else {
                    total += e - s
                    s = $1; e = $2
                }
            }
            END {
                if (s >= 0) total += e - s
                print total
            }
        '
    }

    ##########################################################################
    # _join_ranges_csv
    #
    # Comma-joins two range strings, skipping empty ones.
    # "$1,$2" but handles empty $1 or $2 without introducing bare commas.
    ##########################################################################
    _join_ranges_csv() {
        local a="$1" b="$2"
        if [ -n "${a}" ] && [ -n "${b}" ]; then
            echo "${a},${b}"
        elif [ -n "${a}" ]; then
            echo "${a}"
        elif [ -n "${b}" ]; then
            echo "${b}"
        fi
    }

    ##########################################################################
    # check_daily_caps — central safety invariant enforcer
    #
    # Checks that no calendar day in any of the three restriction categories
    # exceeds 16 hours (960 minutes) of merged coverage.
    #
    # Three independent categories per day:
    #   restriction    — popup warning hours (restriction ranges only)
    #   configure_block — configure/manage block hours:
    #                      if configure_block_enabled=true:
    #                        merge(restriction_ranges, lock_hours_ranges)
    #                      else: lock_hours_ranges only
    #   uninstall_block — uninstall difficulty hours:
    #                      if uninstall_protection_mode=difficult:
    #                        merge(restriction_ranges, uninstall_lock_hours_ranges)
    #                      else: uninstall_lock_hours_ranges only
    #
    # Parameters:
    #   $1 - configure_block_enabled: "true" | anything else = false
    #   $2 - uninstall_protection_mode: "difficult" | anything else
    #   $3...$N - line strings in one of three formats:
    #       "DAYNAME=RANGES"                       (restriction)
    #       "CONFIG_LOCK_HOURS_DAYNAME=RANGES"     (configure-block lock hours)
    #       "UNINSTALL_LOCK_HOURS_DAYNAME=RANGES"  (uninstall lock hours)
    #     Where DAYNAME ∈ {SUNDAY,MONDAY,...,SATURDAY}
    #     and RANGES is a comma-separated list of ranges (integer or HH:MM).
    #
    # Returns:
    #   0 — all (day, category) pairs are ≤ 960 minutes
    #   1 — one or more violations; for each violation prints to stdout:
    #         "DayName|category|minutes"
    #         e.g. "Monday|restriction|1020"
    ##########################################################################
    check_daily_caps() {
        local configure_block_enabled="${1:-false}"
        local uninstall_protection_mode="${2:-none}"
        shift 2

        local _NAMES=("Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday" "Saturday")
        local _UPPER=("SUNDAY" "MONDAY" "TUESDAY" "WEDNESDAY" "THURSDAY" "FRIDAY" "SATURDAY")

        local restriction_ranges=("" "" "" "" "" "" "")
        local lock_ranges=("" "" "" "" "" "" "")
        local uninstall_ranges=("" "" "" "" "" "" "")

        # Parse all incoming line strings into per-day arrays
        local arg dname range_val day_idx
        for arg in "$@"; do
            if [[ "${arg}" =~ ^CONFIG_LOCK_HOURS_(SUNDAY|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)=(.*)$ ]]; then
                dname="${BASH_REMATCH[1]}"
                range_val="${BASH_REMATCH[2]}"
                case "${dname}" in
                    SUNDAY)    lock_ranges[0]="${range_val}" ;;
                    MONDAY)    lock_ranges[1]="${range_val}" ;;
                    TUESDAY)   lock_ranges[2]="${range_val}" ;;
                    WEDNESDAY) lock_ranges[3]="${range_val}" ;;
                    THURSDAY)  lock_ranges[4]="${range_val}" ;;
                    FRIDAY)    lock_ranges[5]="${range_val}" ;;
                    SATURDAY)  lock_ranges[6]="${range_val}" ;;
                esac
            elif [[ "${arg}" =~ ^UNINSTALL_LOCK_HOURS_(SUNDAY|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)=(.*)$ ]]; then
                dname="${BASH_REMATCH[1]}"
                range_val="${BASH_REMATCH[2]}"
                case "${dname}" in
                    SUNDAY)    uninstall_ranges[0]="${range_val}" ;;
                    MONDAY)    uninstall_ranges[1]="${range_val}" ;;
                    TUESDAY)   uninstall_ranges[2]="${range_val}" ;;
                    WEDNESDAY) uninstall_ranges[3]="${range_val}" ;;
                    THURSDAY)  uninstall_ranges[4]="${range_val}" ;;
                    FRIDAY)    uninstall_ranges[5]="${range_val}" ;;
                    SATURDAY)  uninstall_ranges[6]="${range_val}" ;;
                esac
            elif [[ "${arg}" =~ ^(SUNDAY|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)=(.*)$ ]]; then
                dname="${BASH_REMATCH[1]}"
                range_val="${BASH_REMATCH[2]}"
                case "${dname}" in
                    SUNDAY)    restriction_ranges[0]="${range_val}" ;;
                    MONDAY)    restriction_ranges[1]="${range_val}" ;;
                    TUESDAY)   restriction_ranges[2]="${range_val}" ;;
                    WEDNESDAY) restriction_ranges[3]="${range_val}" ;;
                    THURSDAY)  restriction_ranges[4]="${range_val}" ;;
                    FRIDAY)    restriction_ranges[5]="${range_val}" ;;
                    SATURDAY)  restriction_ranges[6]="${range_val}" ;;
                esac
            fi
        done

        local violations=0

        for day_idx in 0 1 2 3 4 5 6; do
            local day_name="${_NAMES[${day_idx}]}"
            local prev_idx=$(( (day_idx + 6) % 7 ))

            local self_r="${restriction_ranges[${day_idx}]:-}"
            local prev_r="${restriction_ranges[${prev_idx}]:-}"
            local self_l="${lock_ranges[${day_idx}]:-}"
            local prev_l="${lock_ranges[${prev_idx}]:-}"
            local self_u="${uninstall_ranges[${day_idx}]:-}"
            local prev_u="${uninstall_ranges[${prev_idx}]:-}"

            # ---- Category: restriction ----------------------------------------
            local restrict_mins
            restrict_mins=$(_compute_day_merged_minutes "${self_r}" "${prev_r}")
            if [ "${restrict_mins}" -gt "${_DAILY_CAP_MAX_MINUTES}" ]; then
                echo "${day_name}|restriction|${restrict_mins}"
                violations=$(( violations + 1 ))
            fi

            # ---- Category: configure_block ------------------------------------
            local cfg_self cfg_prev cfg_mins
            if [ "${configure_block_enabled}" = "true" ]; then
                cfg_self=$(_join_ranges_csv "${self_r}" "${self_l}")
                cfg_prev=$(_join_ranges_csv "${prev_r}" "${prev_l}")
            else
                cfg_self="${self_l}"
                cfg_prev="${prev_l}"
            fi
            cfg_mins=$(_compute_day_merged_minutes "${cfg_self}" "${cfg_prev}")
            if [ "${cfg_mins}" -gt "${_DAILY_CAP_MAX_MINUTES}" ]; then
                echo "${day_name}|configure_block|${cfg_mins}"
                violations=$(( violations + 1 ))
            fi

            # ---- Category: uninstall_block ------------------------------------
            local un_self un_prev un_mins
            if [ "${uninstall_protection_mode}" = "difficult" ]; then
                un_self=$(_join_ranges_csv "${self_r}" "${self_u}")
                un_prev=$(_join_ranges_csv "${prev_r}" "${prev_u}")
            else
                un_self="${self_u}"
                un_prev="${prev_u}"
            fi
            un_mins=$(_compute_day_merged_minutes "${un_self}" "${un_prev}")
            if [ "${un_mins}" -gt "${_DAILY_CAP_MAX_MINUTES}" ]; then
                echo "${day_name}|uninstall_block|${un_mins}"
                violations=$(( violations + 1 ))
            fi
        done

        [ "${violations}" -eq 0 ]
    }

fi
