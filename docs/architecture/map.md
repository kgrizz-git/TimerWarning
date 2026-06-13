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
  → popup-display.sh → popup-display-linux.sh (Linux lifecycle) / popup-display-darwin.sh (macOS)
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
  → configure-partial-lock.sh (tighten-only mode when lock hours active)
  → daily-caps.sh (per-day 16 h cap per category — primary)
  → configure-validation.sh (weekly 24/7 backstop)
  → config-locking.sh (chmod lock; temp unlock on wizard save)
  → configure-input-*.sh, configure-dialogs[-darwin].sh
```

During restriction / configure-block / config-file lock hours, `configure.sh` and **Configure** in `manage.sh` stay open in **partial mode** (baseline captured at entry; loosening blocked for the session). Details: [SAFETY.md](../SAFETY.md).

## Safety-critical modules (read before editing popups/schedulers)

- `lib/popup-safety.sh`
- `lib/daily-caps.sh`
- `lib/configure-validation.sh`
- `lib/configure-partial-lock.sh`
- `lib/config-locking.sh`
- `lib/popup-pid-management.sh`
- `docs/SAFETY.md`

## Tests

- `tests/` — see [development/testing.md](../development/testing.md)
- Always-safe unit tests: `test-configure-partial-lock.sh`, `test-daily-caps.sh`, `test-popup-safety-darwin.sh`, `test-platform-darwin.sh`
