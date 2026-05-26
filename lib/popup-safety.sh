#!/bin/bash

###############################################################################
# Sleep Warning System - Popup Safety Guardrails
#
# Prevents unbounded modal dialogs: hard watchdog timeouts, caps on min display
# time, and forced auto-close on macOS MVP.
###############################################################################

if [ -z "${POPUP_SAFETY_LOADED:-}" ]; then
    POPUP_SAFETY_LOADED=1

    # Hard ceiling per popup invocation (seconds)
    POPUP_ABSOLUTE_MAX_SECONDS="${POPUP_ABSOLUTE_MAX_SECONDS:-120}"
    # configure-core.sh may already define this as readonly; do not reassign.
    if [ -z "${DARWIN_MAX_MIN_DISPLAY_TIME+x}" ]; then
        DARWIN_MAX_MIN_DISPLAY_TIME=60
    fi
    DARWIN_FORCE_AUTO_CLOSE="${DARWIN_FORCE_AUTO_CLOSE:-true}"
    POPUP_AUTO_CLOSE_DELAY_SECONDS="${POPUP_AUTO_CLOSE_DELAY_SECONDS:-10}"

    _popup_darwin_max_min_cap() {
        echo "${DARWIN_MAX_MIN_DISPLAY_TIME:-60}"
    }

    popup_is_darwin() {
        if type is_darwin >/dev/null 2>&1; then
            is_darwin
            return $?
        fi
        [ "$(uname -s 2>/dev/null)" = "Darwin" ]
    }

    # Clamp min display and force auto-close on darwin
    popup_assert_safe_config() {
        local min_display="$1"
        local auto_close="$2"

        if popup_is_darwin; then
            local _max_min
            _max_min=$(_popup_darwin_max_min_cap)
            if [ "${min_display}" -gt "${_max_min}" ]; then
                min_display="${_max_min}"
            fi
            if [ "${DARWIN_FORCE_AUTO_CLOSE}" = "true" ]; then
                auto_close="true"
            fi
        fi
        echo "${min_display}|${auto_close}"
    }

    popup_compute_watchdog_seconds() {
        local min_display="$1"
        local auto_close="$2"
        local computed=0

        if [ "${min_display}" -gt 0 ]; then
            computed=$((min_display + POPUP_AUTO_CLOSE_DELAY_SECONDS + 15))
        elif [ "${auto_close}" = "true" ]; then
            computed=$((POPUP_AUTO_CLOSE_DELAY_SECONDS + 15))
        else
            computed=60
        fi

        if [ "${computed}" -gt "${POPUP_ABSOLUTE_MAX_SECONDS}" ]; then
            computed="${POPUP_ABSOLUTE_MAX_SECONDS}"
        fi
        if [ "${computed}" -lt 15 ]; then
            computed=15
        fi
        echo "${computed}"
    }

    # Run spawn function in background; wait up to watchdog_seconds then kill PID
    # Usage: popup_run_with_watchdog spawn_fn watchdog_seconds
    # spawn_fn should set popup_pid in caller scope
    popup_run_with_watchdog() {
        local spawn_fn="$1"
        local watchdog_seconds="$2"
        local waited=0
        local poll_interval=1

        popup_pid=""
        "${spawn_fn}" || true

        if [ -z "${popup_pid}" ] || ! [[ "${popup_pid}" =~ ^[0-9]+$ ]]; then
            return 1
        fi

        while [ "${waited}" -lt "${watchdog_seconds}" ]; do
            if ! kill -0 "${popup_pid}" 2>/dev/null; then
                wait "${popup_pid}" 2>/dev/null
                local exit_code=$?
                return "${exit_code}"
            fi
            sleep "${poll_interval}"
            waited=$((waited + poll_interval))
        done

        if type log_to_file >/dev/null 2>&1; then
            log_to_file "WARNING" "Popup watchdog fired after ${watchdog_seconds}s; killing PID ${popup_pid}"
        fi
        kill -TERM "${popup_pid}" 2>/dev/null
        sleep 1
        kill -KILL "${popup_pid}" 2>/dev/null
        wait "${popup_pid}" 2>/dev/null || true
        popup_pid=""
        return 124
    }

    popup_safe_get_min_display_time() {
        local min_time
        if type get_min_display_time >/dev/null 2>&1; then
            min_time=$(get_min_display_time)
        else
            min_time=30
        fi
        if popup_is_darwin; then
            local _max_min
            _max_min=$(_popup_darwin_max_min_cap)
            if [ "${min_time}" -gt "${_max_min}" ]; then
                min_time="${_max_min}"
            fi
        fi
        echo "${min_time}"
    }

    popup_safe_get_auto_close() {
        local auto_close
        if type get_popup_auto_close >/dev/null 2>&1; then
            auto_close=$(get_popup_auto_close)
        else
            auto_close="true"
        fi
        if popup_is_darwin && [ "${DARWIN_FORCE_AUTO_CLOSE}" = "true" ]; then
            auto_close="true"
        fi
        echo "${auto_close}"
    }
fi
