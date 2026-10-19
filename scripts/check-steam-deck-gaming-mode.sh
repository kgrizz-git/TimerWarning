#!/usr/bin/env bash
# Read-only hardware preflight. Does not start a popup or change a service/config.
set -eo pipefail

case "${1:-}" in
    -h|--help)
        cat <<'EOF'
Usage: bash scripts/check-steam-deck-gaming-mode.sh
Run on the Deck in Gaming Mode, from its session or an SSH shell with the
session's display credentials. Reads the current user's config; never sources it.
No popup, installation, service changes, or config writes are performed.
Exit: 0 = preflight ready (visual test still required), 1 = not ready,
      2 = unsupported platform, missing timeout, or invalid arguments,
      124 = diagnostics exceeded their 25-second deadline.
See dev-docs/development/steam-deck-first-check.md for the agent test prompt.
EOF
        exit 0 ;;
    '') ;;
    *) echo 'Unexpected argument; use --help.' >&2; exit 2 ;;
esac

if [ "$(uname -s)" != Linux ]; then
    echo 'SKIP: run this hardware preflight on Linux / the Steam Deck.'
    exit 2
fi
if ! command -v timeout >/dev/null 2>&1; then
    echo 'BLOCKED: GNU timeout is required to bound display/session probes.'
    exit 2
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# Bound the entire worker, including potentially stalled X11 and user-bus calls.
# head also bounds diagnostic output. The worker never dumps config/environment.
timeout --kill-after=2s 25s bash -s -- "$repo_root" <<'WORKER' | head -c 16384
set -eo pipefail
repo_root=$1
# Optional library logging must not write into the installed state directory.
log_to_file() { :; }
log_message() { :; }
# shellcheck source=lib/config.sh
source "$repo_root/lib/config.sh"
# shellcheck source=lib/display-detection.sh
source "$repo_root/lib/display-detection.sh"
# shellcheck source=lib/desktop-environment.sh
source "$repo_root/lib/desktop-environment.sh"

failures=0
ready() { printf 'PASS: %s\n' "$1"; }
blocked() { printf 'BLOCKED: %s\n' "$1"; failures=$((failures + 1)); }

echo 'Steam Deck Gaming Mode preflight (read-only; no popup)'
if is_gamescope_running; then
    ready 'gamescope session/process detected (not proof of Deck hardware)'
else
    blocked 'gamescope not detected; run in Gaming Mode with its session environment'
fi

if [ "$(get_gaming_mode_experimental_enabled)" = true ]; then
    ready 'experimental overlay enabled in effective config/environment'
else
    blocked 'experimental overlay is disabled (default); this script will not enable it'
fi

route=$(detect_display_environment || true)
printf 'Production display route: %s\n' "${route:-unknown}"
if [ "$route" = gamescope ]; then
    ready 'production detection selects gamescope overlay routing'
else
    blocked 'production detection does not select gamescope overlay routing'
fi

display_id=$(get_gamescope_x11_display || true)
if [ -n "$display_id" ]; then
    printf 'Overlay X11 display: %s\n' "$display_id"
    if command -v xdpyinfo >/dev/null 2>&1 || command -v xset >/dev/null 2>&1; then
        ready 'X11 connection probe succeeded'
    else
        blocked 'only a socket was checked; install/use xdpyinfo or xset to verify authorization'
    fi
else
    blocked 'no accessible overlay X11 display; SSH may lack session credentials'
fi

tool_count=0
for tool in yad zenity kdialog; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf 'Available dialog tool: %s\n' "$tool"
        tool_count=$((tool_count + 1))
    fi
done
if [ "$tool_count" -eq 0 ]; then blocked 'no supported dialog executable found'; fi
selected_tool=$(check_dialog_tool "$route" "$(get_dialog_tool_config)" || true)
printf 'Production dialog selection: %s\n' "${selected_tool:-none}"
if command -v xprop >/dev/null 2>&1; then
    ready 'xprop available for overlay/focus atoms (not yet tested on a window)'
else
    blocked 'xprop missing; overlay/focus atoms cannot be applied'
fi

if command -v systemctl >/dev/null 2>&1; then
    echo 'Installed timer status (informational; inactive/not installed is allowed):'
    if ! timeout --kill-after=1s 3s systemctl --user --no-pager show sleep-warning.timer \
        --property=LoadState,ActiveState,UnitFileState; then
        echo 'WARN: user service manager unavailable; escape hatch not verified'
    fi
else
    echo 'WARN: systemctl missing; escape hatch not verified'
fi
echo 'Escape hatch (shown only, NOT executed):'
echo '  systemctl --user stop sleep-warning.timer && systemctl --user disable sleep-warning.timer'
echo 'UNVERIFIED: fullscreen visibility, controller input, actual dialog startup/lifetime,'
echo 'scheduled service environment, and stop/disable execution. See the agent prompt.'
if [ "$failures" -ne 0 ]; then
    printf 'NOT READY: %s preflight blocker(s); no settings were changed.\n' "$failures"
    exit 1
fi
echo 'PREFLIGHT READY: continue with a supervised visual test; compatibility is not proven.'
WORKER
