#!/bin/bash

###############################################################################
# Sleep Warning System - macOS Installation Helpers
#
# Sourced by install.sh when running on Darwin.
###############################################################################

install_darwin_check_dependencies() {
    local missing=0
    if ! command -v bash >/dev/null 2>&1; then
        print_error "bash is required"
        missing=1
    elif [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
        print_error "bash 4+ is required (macOS /bin/bash is 3.2)"
        echo "  Install: brew install bash" >&2
        echo "  Then re-run: ./install.sh" >&2
        missing=1
    fi
    if ! command -v osascript >/dev/null 2>&1; then
        print_error "osascript is required (should be pre-installed on macOS)"
        missing=1
    fi
    if ! command -v launchctl >/dev/null 2>&1; then
        print_error "launchctl is required"
        missing=1
    fi
    [ "${missing}" -eq 0 ]
}

install_darwin_check_existing() {
    local installed=false
    if [ -f "${INSTALL_DIR}/sleep-warning.sh" ]; then
        installed=true
    fi
    if [ -f "${HOME}/Library/LaunchAgents/com.sleep-warning.plist" ]; then
        installed=true
    fi
    if [ "${installed}" = true ] && [ "${FORCE_INSTALL}" = false ]; then
        print_warning "Sleep Warning System appears to be already installed on macOS"
        echo "Use --force to reinstall."
        exit 1
    fi
}

install_darwin_create_directories() {
    print_info "Creating necessary directories..."
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${CONFIG_DIR}/config"
    mkdir -p "${CONFIG_DIR}/logs"
    mkdir -p "${HOME}/Library/LaunchAgents"
    print_success "Directories created"
    migrate_config_to_subdirectory
}

install_darwin_ensure_path() {
    local local_bin_path="${HOME}/.local/bin"
    local path_export='export PATH="$HOME/.local/bin:$PATH"'
    if echo "${PATH}" | grep -q "${local_bin_path}"; then
        print_info "~/.local/bin is already in PATH"
        return 0
    fi
    local zprofile="${HOME}/.zprofile"
    local bashrc="${HOME}/.bashrc"
    if [ -f "${zprofile}" ] && ! grep -q '\.local/bin' "${zprofile}" 2>/dev/null; then
        {
            echo ""
            echo "# Added by Sleep Warning System installer"
            echo "${path_export}"
        } >> "${zprofile}"
        print_success "Added ~/.local/bin to PATH in ~/.zprofile"
        return 0
    fi
    if [ -f "${bashrc}" ] && ! grep -q '\.local/bin' "${bashrc}" 2>/dev/null; then
        {
            echo ""
            echo "# Added by Sleep Warning System installer"
            echo "${path_export}"
        } >> "${bashrc}"
        print_success "Added ~/.local/bin to PATH in ~/.bashrc"
        return 0
    fi
    echo "${path_export}" >> "${zprofile}"
    print_success "Created ~/.zprofile with PATH entry"
}

# Phase 3.4: detect whether the LaunchAgent is currently unloaded ("disabled").
# Returns 0 if disabled (plist exists but agent not loaded), 1 otherwise.
install_darwin_is_launch_agent_disabled() {
    local _plist="${HOME}/Library/LaunchAgents/com.sleep-warning.plist"
    [ ! -f "${_plist}" ] && return 1
    if ! command -v launchctl >/dev/null 2>&1; then
        return 1
    fi
    local _domain="gui/$(id -u)"
    if launchctl print "${_domain}/com.sleep-warning" >/dev/null 2>&1; then
        return 1   # loaded → not disabled
    fi
    return 0
}

# Phase 3.4: prompt user before re-loading a previously unloaded LaunchAgent
# during --force reinstall. Honors --re-enable / --no-re-enable for scripting.
install_darwin_prompt_reenable() {
    [ "${FORCE_INSTALL}" = false ] && { RE_ENABLE_SCHEDULER="true"; return 0; }
    if [ -n "${RE_ENABLE_SCHEDULER}" ]; then
        return 0
    fi
    if [ ! -f "${HOME}/Library/LaunchAgents/com.sleep-warning.plist" ]; then
        RE_ENABLE_SCHEDULER="true"
        return 0
    fi
    if install_darwin_is_launch_agent_disabled; then
        print_warning "LaunchAgent (com.sleep-warning) is currently unloaded (disabled)."
        echo "  You previously stopped it via sleep-warning-manage or launchctl bootout."
        echo "  Reinstalling with --force will overwrite the plist but will NOT"
        echo "  re-load the agent unless you say so."
        echo ""
        if [ "${AUTO_YES}" = true ]; then
            echo "  --yes was passed → leaving LaunchAgent unloaded."
            echo "  (Pass --re-enable to override.)"
            RE_ENABLE_SCHEDULER="false"
            return 0
        fi
        local reply
        read -r -p "  Re-load LaunchAgent on install? [y/N]: " reply
        case "${reply}" in
            y|Y|yes|YES)
                RE_ENABLE_SCHEDULER="true"
                ;;
            *)
                RE_ENABLE_SCHEDULER="false"
                print_info "LaunchAgent will remain unloaded. Re-load later with:"
                echo "  launchctl bootstrap gui/\$(id -u) ${HOME}/Library/LaunchAgents/com.sleep-warning.plist"
                ;;
        esac
    else
        RE_ENABLE_SCHEDULER="true"
    fi
}

install_darwin_install_files() {
    print_info "Installing files..."
    mkdir -p "${LIB_DIR}"
    if [ -d "${SCRIPT_DIR}/lib" ]; then
        cp "${SCRIPT_DIR}/lib"/*.sh "${LIB_DIR}/"
        chmod +x "${LIB_DIR}"/*.sh
        if compgen -G "${SCRIPT_DIR}/lib"/*.py > /dev/null; then
            cp "${SCRIPT_DIR}/lib"/*.py "${LIB_DIR}/"
            chmod +x "${LIB_DIR}"/*.py 2>/dev/null || true
        fi
        print_success "Library modules installed"
    fi
    cp "${SCRIPT_DIR}/sleep-warning.sh" "${INSTALL_DIR}/sleep-warning.sh"
    chmod +x "${INSTALL_DIR}/sleep-warning.sh"
    [ -f "${SCRIPT_DIR}/configure.sh" ] && cp "${SCRIPT_DIR}/configure.sh" "${INSTALL_DIR}/sleep-warning-configure" && chmod +x "${INSTALL_DIR}/sleep-warning-configure"
    [ -f "${SCRIPT_DIR}/manage.sh" ] && cp "${SCRIPT_DIR}/manage.sh" "${INSTALL_DIR}/sleep-warning-manage" && chmod +x "${INSTALL_DIR}/sleep-warning-manage"
    [ -f "${SCRIPT_DIR}/status.sh" ] && cp "${SCRIPT_DIR}/status.sh" "${INSTALL_DIR}/sleep-warning-status" && chmod +x "${INSTALL_DIR}/sleep-warning-status"
    [ -f "${SCRIPT_DIR}/uninstall.sh" ] && cp "${SCRIPT_DIR}/uninstall.sh" "${INSTALL_DIR}/sleep-warning-uninstall" && chmod +x "${INSTALL_DIR}/sleep-warning-uninstall"
    [ -f "${SCRIPT_DIR}/manual-uninstall-guide.sh" ] && cp "${SCRIPT_DIR}/manual-uninstall-guide.sh" "${INSTALL_DIR}/manual-uninstall-guide" && chmod +x "${INSTALL_DIR}/manual-uninstall-guide"

    local new_config="${CONFIG_DIR}/config/sleep-warning.conf"
    if [ ! -f "${new_config}" ] && [ -f "${SCRIPT_DIR}/sleep-warning.conf" ]; then
        cp "${SCRIPT_DIR}/sleep-warning.conf" "${new_config}"
        # Ensure macOS safety defaults
        if ! grep -q '^POPUP_AUTO_CLOSE=' "${new_config}" 2>/dev/null; then
            echo "POPUP_AUTO_CLOSE=true" >> "${new_config}"
        fi
        print_success "Default configuration installed"
    fi

    local interval
    interval=$(get_check_interval)
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/lib/service-config-darwin.sh"

    # Phase 3.4: prompt before re-loading a previously unloaded agent
    install_darwin_prompt_reenable

    if [ "${RE_ENABLE_SCHEDULER}" = "false" ]; then
        # Just write the plist; do not bootstrap the agent.
        print_warning "Writing LaunchAgent plist but NOT loading it (per user choice)."
        # service-config-darwin's install_launch_agent both writes AND loads.
        # Since we want write-only, fall back to write_launch_agent_plist if available;
        # otherwise call install_launch_agent and immediately bootout.
        if type write_launch_agent_plist >/dev/null 2>&1; then
            write_launch_agent_plist "${interval}" || {
                print_error "Failed to write LaunchAgent plist"
                exit 1
            }
        else
            install_launch_agent "${interval}" || {
                print_error "Failed to install LaunchAgent"
                exit 1
            }
            # Unload so the user-chosen disabled state is preserved
            if type remove_launch_agent >/dev/null 2>&1; then
                # remove_launch_agent also deletes the plist; we want it kept.
                # Use launchctl bootout directly instead.
                launchctl bootout "gui/$(id -u)/com.sleep-warning" 2>/dev/null || true
            fi
        fi
        print_info "To load LaunchAgent later: launchctl bootstrap gui/\$(id -u) ${HOME}/Library/LaunchAgents/com.sleep-warning.plist"
    else
        install_launch_agent "${interval}" || {
            print_error "Failed to install LaunchAgent"
            exit 1
        }
        print_success "LaunchAgent installed (interval: ${interval} minutes)"
    fi
}

install_darwin_verify() {
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/lib/service-config-darwin.sh"
    local status
    status=$(get_launch_agent_status_text)
    case "${status}" in
        running|loaded)
            print_success "LaunchAgent is active (${status})"
            ;;
        *)
            print_warning "LaunchAgent status: ${status}"
            ;;
    esac
}

install_darwin_print_summary() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Sleep Warning System Installation Complete (macOS)!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Installed files:"
    echo "  - Main script: ${INSTALL_DIR}/sleep-warning.sh"
    echo "  - Configuration: ${CONFIG_DIR}/config/sleep-warning.conf"
    echo "  - LaunchAgent: ${HOME}/Library/LaunchAgents/com.sleep-warning.plist"
    echo "  - Logs: ${CONFIG_DIR}/logs/"
    echo ""
    echo "Next steps:"
    echo "  1. Configure: sleep-warning-configure (or --text)"
    echo "  2. Status: sleep-warning-status"
    echo "  3. Manage: sleep-warning-manage"
    echo "  4. Emergency stop: launchctl bootout gui/\$(id -u)/com.sleep-warning"
    echo "  5. Uninstall: sleep-warning-uninstall"
    echo ""
    echo "See user-docs/MACOS.md for troubleshooting."
    echo ""
}

main_darwin() {
    echo -e "${BLUE}Sleep Warning System - Installation (macOS)${NC}"
    show_disclaimer
    install_darwin_check_existing
    print_info "Checking dependencies..."
    if ! install_darwin_check_dependencies; then
        exit 1
    fi
    print_success "Dependencies OK (bash, osascript, launchctl)"
    install_darwin_create_directories
    install_darwin_ensure_path
    install_darwin_install_files
    if [ -f "${CONFIG_DIR}/config/sleep-warning.conf" ]; then
        if [ -f "${SCRIPT_DIR}/lib/config.sh" ] && [ -f "${SCRIPT_DIR}/lib/time-parsing.sh" ]; then
            export CONFIG_FILE="${CONFIG_DIR}/config/sleep-warning.conf"
            # shellcheck disable=SC1091
            source "${SCRIPT_DIR}/lib/time-parsing.sh"
            # shellcheck disable=SC1091
            source "${SCRIPT_DIR}/lib/config.sh"
            type migrate_config_to_minute_format >/dev/null 2>&1 && migrate_config_to_minute_format || true
        fi
    fi
    install_darwin_verify
    install_darwin_print_summary
}
