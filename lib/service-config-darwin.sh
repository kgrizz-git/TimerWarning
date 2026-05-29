#!/bin/bash

###############################################################################
# Sleep Warning System - macOS LaunchAgent Service Configuration
#
# Manages ~/Library/LaunchAgents/com.sleep-warning.plist and launchctl.
###############################################################################

if [ -z "${SERVICE_CONFIG_DARWIN_LOADED:-}" ]; then
    SERVICE_CONFIG_DARWIN_LOADED=1

    LAUNCH_AGENT_LABEL="com.sleep-warning"

    launch_agent_plist_path() {
        echo "${HOME}/Library/LaunchAgents/${LAUNCH_AGENT_LABEL}.plist"
    }

    sleep_warning_script_path() {
        echo "${HOME}/.local/bin/sleep-warning.sh"
    }

    sleep_warning_log_dir() {
        echo "${HOME}/.config/sleep-warning/logs"
    }

    # Stubs for Linux-only configure_service_for_mode API
    get_service_dropin_path() {
        echo ""
    }

    configure_service_for_mode() {
        return 0
    }

    get_current_service_mode() {
        echo "none"
    }

    remove_service_dropin() {
        return 0
    }

    create_service_dropin() {
        return 0
    }

    _launchd_domain() {
        echo "gui/$(id -u)"
    }

    _ensure_log_dir() {
        mkdir -p "$(sleep_warning_log_dir)" 2>/dev/null || return 1
    }

    # Record the python3 used for fullscreen popups (install/configure time).
    write_blocker_python_path() {
        local path_file="${HOME}/.config/sleep-warning/blocker-python.path"
        local py=""
        mkdir -p "${HOME}/.config/sleep-warning" 2>/dev/null || return 0
        py="$(command -v python3 2>/dev/null || true)"
        if [ -n "${py}" ]; then
            printf '%s\n' "${py}" >"${path_file}"
        fi
    }

    # Write LaunchAgent plist with StartInterval in seconds
    write_launch_agent_plist() {
        local interval_minutes="$1"
        local interval_seconds=$((interval_minutes * 60))

        if ! [[ "${interval_minutes}" =~ ^[0-9]+$ ]] || [ "${interval_minutes}" -lt 1 ] || [ "${interval_minutes}" -gt 60 ]; then
            echo "Error: Invalid check interval: ${interval_minutes}" >&2
            return 1
        fi

        _ensure_log_dir || return 1
        local plist_path script_path log_dir bash_path
        plist_path="$(launch_agent_plist_path)"
        script_path="$(sleep_warning_script_path)"
        log_dir="$(sleep_warning_log_dir)"
        bash_path="$(command -v bash)"
        local _sc_dir
        _sc_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        if [ -f "${_sc_dir}/ensure-bash4.sh" ]; then
            # shellcheck disable=SC1091
            source "${_sc_dir}/ensure-bash4.sh"
            bash_path="$(resolve_bash4_path 2>/dev/null || echo "${bash_path}")"
        fi
        mkdir -p "$(dirname "${plist_path}")" 2>/dev/null || return 1
        write_blocker_python_path || true

        local path_env="/usr/bin:/bin"
        [ -d "/usr/local/bin" ] && path_env="/usr/local/bin:${path_env}"
        [ -d "/opt/homebrew/bin" ] && path_env="/opt/homebrew/bin:${path_env}"

        cat > "${plist_path}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCH_AGENT_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${bash_path}</string>
        <string>${script_path}</string>
    </array>
    <key>StartInterval</key>
    <integer>${interval_seconds}</integer>
    <key>RunAtLoad</key>
    <false/>
    <key>LimitLoadToSessionType</key>
    <array>
        <string>Aqua</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>${path_env}</string>
        <key>HOME</key>
        <string>${HOME}</string>
    </dict>
    <key>StandardOutPath</key>
    <string>${log_dir}/launchd-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${log_dir}/launchd-stderr.log</string>
</dict>
</plist>
EOF
    }

    launch_agent_bootout() {
        if ! command -v launchctl >/dev/null 2>&1; then
            return 0
        fi
        # Try domain/label form first (preferred on macOS 10.13+), fall back to plist path.
        # Ignore errors when the agent is simply not loaded (that is a normal state).
        launchctl bootout "$(_launchd_domain)/${LAUNCH_AGENT_LABEL}" 2>/dev/null \
            || launchctl bootout "$(_launchd_domain)" "$(launch_agent_plist_path)" 2>/dev/null \
            || true   # "not found" is OK here; remove_launch_agent() checks more strictly
    }

    launch_agent_bootstrap() {
        if ! command -v launchctl >/dev/null 2>&1; then
            echo "Error: launchctl not found" >&2
            return 1
        fi
        local plist_path
        plist_path="$(launch_agent_plist_path)"
        if [ ! -f "${plist_path}" ]; then
            echo "Error: LaunchAgent plist not found: ${plist_path}" >&2
            return 1
        fi
        launch_agent_bootout
        launchctl bootstrap "$(_launchd_domain)" "${plist_path}" 2>/dev/null \
            || launchctl load -w "${plist_path}" 2>/dev/null
    }

    launch_agent_kickstart() {
        if command -v launchctl >/dev/null 2>&1; then
            launchctl kickstart -k "$(_launchd_domain)/${LAUNCH_AGENT_LABEL}" 2>/dev/null || true
        fi
    }

    install_launch_agent() {
        local interval="${1:-10}"
        write_launch_agent_plist "${interval}" || return 1
        launch_agent_bootstrap || return 1
        launch_agent_kickstart
        return 0
    }

    # Phase 3.1: surface bootout failures instead of masking them with || true
    remove_launch_agent() {
        local _plist_path
        _plist_path="$(launch_agent_plist_path)"
        local _bootout_ok=true

        if command -v launchctl >/dev/null 2>&1; then
            local _domain
            _domain="$(_launchd_domain)"
            # Try domain/label form first (macOS 10.13+), then plist form
            if ! launchctl bootout "${_domain}/${LAUNCH_AGENT_LABEL}" 2>/dev/null; then
                if ! launchctl bootout "${_domain}" "${_plist_path}" 2>/dev/null; then
                    # Agent may simply not be loaded — that is acceptable
                    if launchctl print "${_domain}/${LAUNCH_AGENT_LABEL}" >/dev/null 2>&1; then
                        # It IS loaded but we couldn't bootout — this is an error
                        echo "ERROR: launchctl bootout failed for ${LAUNCH_AGENT_LABEL}" >&2
                        _bootout_ok=false
                    fi
                fi
            fi
        fi

        rm -f "${_plist_path}" 2>/dev/null

        if [ "${_bootout_ok}" = "false" ]; then
            return 1
        fi
        return 0
    }

    is_launch_agent_loaded() {
        launchctl print "$(_launchd_domain)/${LAUNCH_AGENT_LABEL}" >/dev/null 2>&1
    }

    is_launch_agent_running() {
        local state
        state=$(launchctl print "$(_launchd_domain)/${LAUNCH_AGENT_LABEL}" 2>/dev/null | grep -E '^\s*state = ' | head -n1 | sed 's/.*= //')
        [ "${state}" = "running" ] || [ "${state}" = "active" ]
    }

    # Called from configure-config update_timer_file
    update_timer_file_platform() {
        local interval="$1"
        if [ ! -f "$(launch_agent_plist_path)" ]; then
            return 0
        fi
        write_launch_agent_plist "${interval}" || return 1
        launch_agent_bootout
        launch_agent_bootstrap || return 1
        return 0
    }

    generate_timer_file() {
        local interval="${1:-10}"
        install_launch_agent "${interval}"
    }

    reload_scheduled_service() {
        launch_agent_bootout
        launch_agent_bootstrap
    }

    enable_scheduled_service() {
        launch_agent_bootstrap
        launch_agent_kickstart
    }

    disable_scheduled_service() {
        launch_agent_bootout
    }

    get_launch_agent_status_text() {
        if [ ! -f "$(launch_agent_plist_path)" ]; then
            echo "not_installed"
            return 0
        fi
        if is_launch_agent_loaded; then
            if is_launch_agent_running; then
                echo "running"
            else
                echo "loaded"
            fi
        else
            echo "installed_not_loaded"
        fi
    }
fi
