# Architecture map

High-level layout for agents navigating the codebase.

## Entry scripts (user-facing)

| Script | Role |
|--------|------|
| `sleep-warning.sh` | Main check: restricted hours → popup or exit |
| `configure.sh` | Interactive configuration wizard |
| `install.sh` | Platform branch: Linux systemd / macOS LaunchAgent |
| `manage.sh` | Enable/disable, status, logs |
| `status.sh` | Installation and config report |
| `uninstall.sh` | Remove scheduler, scripts, optional config |

## Core library flow (`sleep-warning.sh`)

```
sleep-warning.sh
  → platform.sh
  → config.sh, time-validation.sh, pause-state.sh
  → display-detection[-darwin].sh
  → popup-safety.sh
  → popup-display.sh → popup-display-darwin.sh (macOS)
  → popup-pid-management.sh
```

## Platform adapters

| Concern | Linux | macOS |
|---------|-------|-------|
| Scheduler | `service-config-linux.sh`, systemd units | `service-config-darwin.sh`, LaunchAgent plist |
| Dialogs | yad / zenity / kdialog | osascript (`*-darwin.sh`) |
| Display | X11 / Wayland | `display-detection-darwin.sh` |
| Window mgmt | wmctrl / xdotool | no-op / Phase 3 stubs |

Facade: `service-config.sh`, `scheduler-platform.sh` (manage/status/uninstall).

## Configuration pipeline

```
configure.sh
  → configure-core.sh, configure-config.sh (write + update_timer_file)
  → configure-validation.sh (24/7 block)
  → configure-input-*.sh, configure-dialogs[-darwin].sh
```

## Safety-critical modules (read before editing popups/schedulers)

- `lib/popup-safety.sh`
- `lib/configure-validation.sh`
- `lib/popup-pid-management.sh`
- `docs/SAFETY.md`

## Tests

- `tests/` — see [development/testing.md](../development/testing.md)
- Always-safe unit tests: `test-popup-safety-darwin.sh`, `test-platform-darwin.sh`
