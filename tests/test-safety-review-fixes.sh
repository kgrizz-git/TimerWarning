#!/usr/bin/env bash
# Safety review regressions. Headless, temporary HOME, no live scheduler calls.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
export HOME="${TMP}/home"
mkdir -p "${HOME}"
trap 'chmod -R u+rwX "${TMP}" 2>/dev/null || true; rm -rf "${TMP}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
source "${ROOT}/lib/config.sh"
source "${ROOT}/lib/time-parsing.sh"
source "${ROOT}/lib/time-validation.sh"
source "${ROOT}/lib/daily-caps.sh"
source "${ROOT}/lib/config-locking.sh"

(
    check_daily_caps true difficult 'MONDAY=08:00-16:00,16:00-08:00'
    if is_restricted_time 0300 '08:00-16:00,16:00-08:00' self; then
        fail 'Monday overnight range applied to Monday morning'
    fi
    is_restricted_time 0900 '08:00-16:00,16:00-08:00' self
    is_restricted_time 2300 '08:00-16:00,16:00-08:00' self
    is_time_in_previous_day_overnight_tail 0300 '16:00-08:00'
    is_time_in_previous_day_overnight_tail 0300 '23:00-06:00'
    if is_restricted_time 0800 '23:00-06:00' self; then
        fail 'non-active current-day range matched'
    fi
    echo 'PASS: overnight self/carry matches cap accounting'
)

(
    if check_daily_caps false none 'CONFIG_LOCK_ENABLED=true' \
        'MONDAY=00:00-16:00' 'CONFIG_LOCK_HOURS_MONDAY=16:00-23:00' >/dev/null; then
        fail 'config-file locking bypassed configure-block cap'
    fi
    check_daily_caps false none 'CONFIG_LOCK_ENABLED=true' \
        'MONDAY=00:00-08:00' 'CONFIG_LOCK_HOURS_MONDAY=08:00-16:00'
    echo 'PASS: config-file locking participates in merged configure cap'
)

(
    mkdir -p "$(dirname "${CONFIG_FILE}")"
    date() { if [ "${1:-}" = +%w ]; then echo 1; else command date "$@"; fi; }
    get_current_time() { echo 1200; }
    printf '%s\n' 'MONDAY=00:00-23:00' 'CONFIGURE_BLOCK_ENABLED=true' \
        'CONFIG_LOCK_ENABLED=true' 'UNINSTALL_PROTECTION_MODE=difficult' > "${CONFIG_FILE}"
    if runtime_daily_caps_are_safe; then fail 'unsafe config accepted'; fi
    check_config_lock_time || fail 'unsafe config left configure blocked'
    [ "$(check_uninstall_protection_time)" = none ] || fail 'unsafe uninstall protection remained'
    if is_config_lock_active; then fail 'unsafe config left file locking active'; fi
    printf '%s\n' 'MONDAY=08:00-16:00' 'CONFIGURE_BLOCK_ENABLED=true' \
        'CONFIG_LOCK_ENABLED=true' 'UNINSTALL_PROTECTION_MODE=difficult' > "${CONFIG_FILE}"
    runtime_daily_caps_are_safe
    if check_config_lock_time; then fail 'safe config lost configure protection'; fi
    [ "$(check_uninstall_protection_time)" = difficult ] || fail 'safe uninstall protection lost'
    is_config_lock_active || fail 'safe file locking lost'
    echo 'PASS: standalone gates release unsafe locks and re-read repaired config'
)

(
    source "${ROOT}/lib/configure-core.sh"
    source "${ROOT}/lib/configure-config-write.sh"
    printf '%s\n' original > "${CONFIG_FILE}"
    if write_config 10 medium center 30 true true true difficult true 5 24 auto false \
        fixed '50%x50%' 1280x720 'MONDAY=00:00-23:00' >/dev/null; then
        fail 'direct write_config bypassed daily caps'
    fi
    [ "$(cat "${CONFIG_FILE}")" = original ] || fail 'rejected save modified config'
    echo 'PASS: write boundary rejects unsafe schedules without changing config'
)

(
    source "${ROOT}/lib/popup-pid-management.sh"
    source "${ROOT}/lib/popup-safety.sh"
    source "${ROOT}/lib/popup-display-linux.sh"
    POPUP_PID_FILE="${TMP}/redraw.pid"
    _popup_watchdog_expired_file="${TMP}/redraw.expired"
    : > "${_popup_watchdog_expired_file}"
    base_message=test; window_tool=''; env_type=x11
    dialog_safe_text() { printf '%s' "$1"; }
    log_to_file() { :; }
    _popup_spawn_warning_dialog() { fail 'respawn after absolute expiry'; }
    bash -c 'trap "" TERM; exec sleep 60' & popup_pid=$!
    old_pid="${popup_pid}"
    trap 'kill -KILL "${old_pid}" "${wd:-}" 2>/dev/null || true' EXIT
    sleep 0.2
    save_popup_pid "${popup_pid}"
    popup_start_pid_file_watchdog 1 "${POPUP_PID_FILE}" "${_popup_watchdog_expired_file}" >/dev/null
    wd="${POPUP_WATCHDOG_LAST_PID}"
    if _popup_linux_update_countdown 10; then fail 'redraw respawned after expiry'; fi
    wait "${wd}" || true
    if kill -0 "${old_pid}" 2>/dev/null; then fail 'hung redraw survived watchdog'; fi
    [ -s "${_popup_watchdog_expired_file}" ] || fail 'watchdog expiry not latched'
    trap - EXIT
    echo 'PASS: watchdog kills TERM-ignoring redraw and prevents respawn'
)

(
    source "${ROOT}/lib/popup-dialog-implementations.sh"
    source "${ROOT}/lib/popup-display-linux.sh"
    log_to_file() { :; }
    dialog_tool=yad; window_title=test; width=100; height=100
    popup_position=center; window_tool=''; pause_available=true; pause_duration=1
    _popup_lock_fd=''
    yad() { return 1; }
    _popup_spawn_warning_dialog test || true
    [ -z "${popup_pid}" ] || fail 'YAD startup error mistaken for a 1-minute pause'
    notified=false
    _popup_linux_notify_send_fallback() { notified=true; }
    _popup_linux_on_spawn_failure
    [ "${notified}" = true ] || fail 'missing notification on spawn failure'
    yad() { return 42; }
    _popup_spawn_warning_dialog test || true
    [ -n "${popup_pid}" ] || fail 'fast genuine pause classified as failure'
    popup_auto_close=false
    paused=false
    activate_pause() { paused=true; return 0; }
    get_pause_end_timestamp() { echo 0; }
    _popup_show_pause_activated_notice() { :; }
    cleanup_popup_pid() { :; }
    _popup_linux_wait_without_min_display || fail 'already-exited pause click lost'
    [ "${paused}" = true ] || fail 'fast pause did not activate'
    dialog_tool=zenity; pause_available=false; zenity_output_file="${TMP}/zenity.out"
    zenity() { return 255; }
    _popup_spawn_warning_dialog test || true
    [ -z "${popup_pid}" ] || fail 'Zenity startup error accepted'
    echo 'PASS: failed GUI startup notifies; fast pause remains valid'
)

(
    source "${ROOT}/lib/popup-display-darwin.sh"
    POPUP_DARWIN_SKIP_MODULE_SOURCE=1
    POPUP_PID_FILE="${TMP}/darwin.pid"
    detect_display_environment() { echo aqua; }
    get_display_identifier() { echo 1; }
    get_popup_display_frequency() { echo 10; }
    get_popup_size() { echo medium; }
    get_popup_position() { echo center; }
    popup_safe_get_min_display_time() { echo 0; }
    popup_safe_get_auto_close() { echo true; }
    get_popup_dimensions() { echo '400 300'; }
    _popup_get_interval_text() { echo interval; }
    get_next_unrestricted_time() { echo later; }
    _popup_build_base_message() { echo warning; }
    dialog_safe_text() { printf '%s' "$1"; }
    _popup_build_initial_countdown_suffix() { :; }
    can_pause_now() { return 1; }
    cleanup_stale_pid() { :; }
    is_popup_running() { :; }
    log_to_file() { :; }
    popup_compute_watchdog_seconds() { echo 1; }
    _popup_spawn_warning_dialog_darwin() { popup_pid=12345; }
    source "${ROOT}/lib/popup-pid-management.sh"
    # No real GUI: inspect registration while the watchdog owns the live popup.
    is_popup_running() { :; }
    popup_run_with_watchdog() {
        "$1"
        [ "$(cat "${POPUP_PID_FILE}")" = 12345 ] || fail 'macOS popup not registered during wait'
        popup_pid=''
        return 124
    }
    show_warning_darwin
    [ ! -f "${POPUP_PID_FILE}" ] || fail 'macOS watchdog left stale registration'
    echo 'PASS: macOS registers during watchdog wait and cleans on expiry'
)

(
    source "${ROOT}/lib/service-config-linux.sh"
    calls=''
    systemctl() { calls="${calls} ${2}"; [ "${2}" != stop ]; }
    if disable_scheduled_service; then fail 'stop failure masked by disable success'; fi
    [[ "${calls}" == *disable* ]] || fail 'disable was not attempted after stop failure'
    systemctl() { [ "${2}" != disable ]; }
    if disable_scheduled_service; then fail 'disable failure was masked'; fi
    systemctl() { return 0; }
    disable_scheduled_service
    echo 'PASS: Linux disable returns both stop and disable failures'
)

echo 'All safety review regressions passed.'
