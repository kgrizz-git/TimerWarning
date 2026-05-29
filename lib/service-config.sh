#!/bin/bash

###############################################################################
# Sleep Warning System - Service Configuration Facade
#
# Loads platform-specific service/timer implementation:
#   - lib/service-config-linux.sh  (systemd drop-ins)
#   - lib/service-config-darwin.sh (LaunchAgent)
###############################################################################

if [ -z "${SERVICE_CONFIG_FACADE_LOADED:-}" ]; then
    SERVICE_CONFIG_FACADE_LOADED=1
    _service_config_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [ -f "${_service_config_dir}/platform.sh" ]; then
        # shellcheck disable=SC1091
        source "${_service_config_dir}/platform.sh"
    fi

    if type is_darwin >/dev/null 2>&1 && is_darwin; then
        # shellcheck disable=SC1091
        source "${_service_config_dir}/service-config-darwin.sh"
    else
        # shellcheck disable=SC1091
        source "${_service_config_dir}/service-config-linux.sh"
    fi
    unset _service_config_dir
fi
