# Safety guardrails (highest priority)

> **This project can block computer use if implemented wrong.** Treat safety as a release gate, not a nice-to-have—especially during development and agent-driven changes.

## What “lockout” means here

A user is **locked out** or **effectively trapped** when they cannot:

- Dismiss a warning popup for a long time (or at all)
- Change configuration to fix the problem
- Stop scheduled checks
- Uninstall or disable the system

We must never ship changes that make these outcomes likely.

## Non-negotiable product rules

### 1. No 24/7 warnings

- **Configure-time:** `check_restriction_coverage()` must return `block` before saving schedules that cover the entire week.
- **Runtime:** `sleep-warning.sh` must fall back to safe defaults if the on-disk config would imply 24/7 restriction.
- **Tests:** Never point tests at a live config with 24/7 hours.

### 2. Popups must always end

| Mechanism | Location |
|-----------|----------|
| Hard watchdog (`POPUP_ABSOLUTE_MAX_SECONDS`, default **120s**) | `lib/popup-safety.sh` |
| Forced auto-close on macOS MVP | `DARWIN_FORCE_AUTO_CLOSE` in `lib/popup-safety.sh` |
| Capped min display (60s on macOS) | `popup_safe_get_min_display_time()` |
| Duplicate popup prevention | `lib/popup-pid-management.sh` |
| User Pause button | `lib/pause-state.sh` + dialog implementations |

**Never** add a code path that runs a **blocking** modal in the main script without a watchdog (no unbounded `osascript delay` in `sleep-warning.sh`).

### 3. Always provide an escape hatch

Document and preserve these recovery paths (see [user-docs/MACOS.md](../user-docs/MACOS.md) and Linux manage/uninstall):

- Disable scheduler: `sleep-warning-manage` or `systemctl --user stop sleep-warning.timer` (Linux) / `launchctl bootout gui/$(id -u)/com.sleep-warning` (macOS)
- Kill stuck UI: `killall osascript` (macOS) / close dialog process (Linux)
- Edit config when allowed: `sleep-warning-configure --text`
- Uninstall: `sleep-warning-uninstall` or manual guide

### 4. Config lock ≠ surprise bricking

Config locking (Enhancement #18) makes the config directory read-only during restricted hours. That is intentional—but:

- Users must still be able to recover via manage/disable/uninstall flows documented above.
- Do not combine config lock with 24/7 restrictions or broken popups.

## Development and agent rules (critical)

These apply to **everyone** (humans and AI agents) modifying this repo:

1. **Do not edit the installed config** at `~/.config/sleep-warning/` during restricted or blocked hours (see `.cursor/rules/config-file-edits.mdc`).
2. **Use an isolated temp `HOME`** for tests that write config or install launchd/systemd units.
3. **Test schedules:** max 6 hours restricted per day, check interval ≥ 5 minutes, min popup display ≤ 60s in tests (see `.cursor/rules/tests.mdc`).
4. **Before merging popup or scheduler changes:** run `tests/test-popup-safety-darwin.sh` on macOS and relevant Linux tests; manually verify emergency stop once if GUI changed.
5. **When adding a new modal or timer:** ask “What happens if this hangs?” and add watchdog/skip/timeout.

### Safe local development pattern

```bash
# Use a throwaway HOME — never your only daily-driver profile without an escape plan
export HOME="$(mktemp -d)"
cd /path/to/LinuxTimerWarning
./install.sh
# ... test ...
launchctl bootout gui/$(id -u)/com.sleep-warning 2>/dev/null || true
rm -rf "$HOME"
```

On Linux, use temp `HOME` and user systemd scope similarly.

## Code touchpoints (keep in sync)

When changing behavior, review these files together:

- `lib/popup-safety.sh` — caps and watchdog
- `lib/popup-display.sh` / `lib/popup-display-darwin.sh` — spawn and wait
- `lib/configure-validation.sh` — 24/7 block
- `sleep-warning.sh` — runtime validation fallback
- `install.sh` / `lib/install-darwin.sh` — safe defaults on first install

## Review checklist (PR / agent self-review)

- [ ] Cannot save 24/7 restriction schedule
- [ ] Popup path has bounded lifetime (watchdog or documented equivalent)
- [ ] No new blocking UI without kill path
- [ ] Tests use temp `HOME` or read-only fixtures
- [ ] Emergency disable documented if UX changed
- [ ] `docs/SAFETY.md` or linked docs updated if rules changed

## If safety and features conflict

**Safety wins.** Ship a smaller feature rather than risk lockout.
