#!/bin/bash
# Direct-source smoke: lib/install-linux.sh defines expected entry points.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
LIB_DIR="${HOME}/.local/lib/sleep-warning"
CONFIG_DIR="${HOME}/.config/sleep-warning"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
RED=''; GREEN=''; YELLOW=''; BLUE=''; NC=''
AUTO_YES=false
FORCE_INSTALL=false
RE_ENABLE_SCHEDULER=""
print_success() { :; }
print_error() { :; }
print_warning() { :; }
print_info() { :; }
command_exists() { command -v "$1" >/dev/null 2>&1; }
migrate_config_to_subdirectory() { :; }
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/install-linux.sh"
for fn in main_linux install_files create_directories reload_systemd enable_timer; do
    if ! type "$fn" >/dev/null 2>&1; then
        echo "FAIL: missing function $fn"
        exit 1
    fi
done
echo "PASS: install-linux.sh direct-source smoke"
