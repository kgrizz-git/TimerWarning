# Test tiers

Machine manifest: [`tests/tiers.yaml`](../../tests/tiers.yaml)  
Runner: [`scripts/run-tests.sh`](../../scripts/run-tests.sh)

Agent-agnostic — Cursor, Codex, Claude Code, OpenCode, Qwen, humans, and CI use the same lists.

## Tier A — PR gate (required)

Fast, headless, no live installed config. Default timeout 300s per script.

| Script | Notes |
|--------|-------|
| `test-daily-caps.sh` | Per-day 16 h cap math |
| `test-review-regressions.sh` | Runtime cap resolution, uninstall cancel status, popup fallbacks |
| `test-safety-review-fixes.sh` | Overnight day assignment, effective config-lock caps, standalone fallback, write boundary, hung redraw, startup and disable failures |
| `test-invariant-messages.sh` | Hard-block invariant IDs in messages |
| `test-time-picker-minutes.sh` | GUI time picker helpers (headless) |
| `test-popup-safety-darwin.sh` | Watchdog unit tests — **macOS CI only** |
| `test-popup-safety-linux.sh` | Watchdog + PID-file kill — **Linux CI only** |
| `test-configure-partial-lock.sh` | Tighten-only configure wizard |
| `test-popup-size-config.sh` | Popup size getters, fixed and display-based dimensions, 95% clamp |
| `test-config-safety.sh` | Default hours, runtime cap inputs, runtime cap gate, wizard default fill |
| `test-time-calculations.sh` | Range durations, weekly intervals, next unrestricted time, restriction end time |
| `test-config-locked-message.sh` | Text of the configure lock error: active range, end time, end day |
| `test-scheduler-platform.sh` | systemd and launchd helpers with a stubbed `systemctl` |
| `test-resolution-detection-stubbed.sh` | xrandr, Wayland and gamescope resolution detection with stub tools |
| `test-configure-dialogs-darwin-ui.py` | macOS configure dialogs with fake tkinter widgets (run by the Python coverage gate, not `run-tests.sh`) |
| `test-platform-darwin.sh` | Platform detection, plist math — **macOS only** |
| `test-darwin-configure-gui.sh` | **macOS only**; **requires GUI** — skipped when `CI_HEADLESS=1` |

```bash
./scripts/run-tests.sh --tier a
CI_HEADLESS=1 ./scripts/run-tests.sh --tier a   # headless / sandbox
```

Invoked by `./scripts/run-security-scan.sh --with-tests`. GitHub Actions runs Tier-A on **ubuntu-latest** and **macos-latest** with `CI_HEADLESS=1` — popup-safety scripts are **platform-scoped** (Linux vs Darwin). See [ci.md](../development/ci.md).

## Tier B — Pre-release (optional on PR)

Temp-`HOME` and module smokes. Run in batches with `timeout`; see [platform-test-matrix.md](../development/platform-test-matrix.md).

```bash
./scripts/run-tests.sh --tier b
```

Includes the configure text-mode, modular, blocking, and GUI-split scripts. They call `configure.sh`, so they stay out of Tier-A. The lock-hour phases, Darwin grid cache, and pause and popup interval scripts that used to be here moved to Tier-A on 2026-10-28, because the shell coverage floor only counts Tier-A.

## Tier C — Manual / multi-host

Documented in [platform-test-matrix.md](../development/platform-test-matrix.md): `expect` comprehensive suites, Linux yad/zenity/kdialog GUI, SteamOS, fresh install on multiple distros.

```bash
./scripts/run-tests.sh --tier c   # prints doc link only
```

## Adding a script to a tier

1. Edit `tests/tiers.yaml`.
2. Run `./scripts/run-tests.sh --tier a --list` (or `b`) to verify resolution.
3. Note in CHANGELOG if CI behavior changes.
