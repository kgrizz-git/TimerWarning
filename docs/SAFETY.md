# Safety guardrails (highest priority)

> **This project intentionally blocks computer use during configured restricted hours — that is the entire feature.** The job of these guardrails is *not* to weaken the lockout. It is to make sure the lockout obeys the **per-day cap**, always terminates eventually, and always leaves the user a way to disable the system permanently.

## What this app is for (read this first)

Sleep Warning is an impulse-control / time-management tool. The user *wants* to be locked out of their computer during configured windows. So:

- Popups **should** stay on top and steal focus during their min-display window. That is the lockout working as designed.
- Popups **should** disable Cmd+Tab / Mission Control / Spotlight where possible (deferred to Accessibility API work).
- The user **should not** be able to quickly dismiss a popup during restricted hours just by clicking around.

What still must be true:

1. The user cannot accidentally configure more than **16 hours per day** of any single lockout category. Hard, mechanical cap. Not weekly average.
2. Popups have a finite maximum duration. That maximum may grow as the project matures (the current 120-second cap on macOS is a temporary limit, not a permanent rule), but it is always finite.
3. There is always at least one documented escape hatch the user can reach to disable the entire system.

## The per-day 16-hour cap (the central invariant)

**On any given calendar day, none of the following may exceed 16 hours of merged coverage:**

| Category | Inputs that count (merge overlapping intervals before measuring) |
|----------|------------------------------------------------------------------|
| **Restriction** (popup hours) | `SUNDAY=…` … `SATURDAY=…` for that weekday, plus any overnight carry from the prior day |
| **Configure block** | `CONFIG_LOCK_HOURS_<DAY>` ∪ (restriction hours for that day **if** `CONFIGURE_BLOCK_ENABLED=true`) |
| **Uninstall block** | `UNINSTALL_LOCK_HOURS_<DAY>` ∪ (restriction hours for that day **if** uninstall protection is enabled) |

The three caps are **independent**. A user can have:

- 16 hours of restriction (popups), AND
- 16 hours of configure-block, AND
- 16 hours of uninstall-block

…all on the same day, **as long as each category's merged total is ≤ 16 hours per day**. Overlapping intervals within a category count once (so `0-12,12-23` = 23 h = over cap, not 23 h treated as 11 h + 12 h).

This must be enforced at **three** points:

| Where | Behavior on violation |
|-------|----------------------|
| Configure wizard `write_config` | Hard block. No "save anyway" override. |
| Runtime startup of `sleep-warning.sh` (`validate_config_safety`) | Fall back to safe defaults; warn in log. |
| Manual `--text` edit + reload | Same runtime fallback fires. |

A weekly average is **not** acceptable. A single day over 16 hours in any category is a violation.

## Popup lifetime (the second invariant)

Popups during restricted hours **may** be:

- Fullscreen, on top, focus-stealing, and not-easy-to-dismiss.
- Held open for the configured min-display time.
- Auto-closed after the configured auto-close delay.

Popups **must never** be:

- Truly indefinite. Even with focus stealing, every spawn path must have an absolute terminal watchdog.
- Stacked unboundedly (the scheduler must not pile on a second popup while the first is still alive).
- Silently absent: if the primary popup tool fails to start, the dispatcher must fall back to a working alternative, or surface a notification — not log success and move on.

The current macOS hard cap is `POPUP_ABSOLUTE_MAX_SECONDS=120`. This number is expected to **grow** as we build longer-form lockouts. The invariant is "finite and bounded by an explicit cap," not "≤ 120 s forever."

## Always-available escape hatch (the third invariant)

The user can always permanently disable the system through at least one documented path. These paths are not blocked by `CONFIGURE_BLOCK_ENABLED` or `CONFIG_LOCK_ENABLED`:

| Platform | Disable | Uninstall |
|----------|---------|-----------|
| Linux | `systemctl --user stop sleep-warning.timer && systemctl --user disable sleep-warning.timer` | `~/.local/bin/sleep-warning-uninstall` |
| macOS | `launchctl bootout gui/$(id -u)/com.sleep-warning` | `~/.local/bin/sleep-warning-uninstall` |

`sleep-warning-manage` is **convenience**, not the escape hatch. Disable service, status, and logs remain available during lock hours. **Configure** opens in **tighten-only partial mode** (see below) instead of being fully blocked.

### Partial configure during lock hours (tighten-only)

When restriction hours, configure-block hours, or config-file lock (`CONFIG_LOCK_ENABLED`) are active, `sleep-warning-configure` and **Configure** in `sleep-warning-manage` enter **limited mode**:

| Allowed (tighten) | Blocked (loosen) |
|-------------------|------------------|
| More frequent popups (lower `POPUP_DISPLAY_FREQUENCY`) | Slower popup frequency |
| Longer minimum display time | Shorter min display |
| Add time ranges (existing ranges unchanged) | Remove, edit, or clear existing ranges |
| Enable `CONFIGURE_BLOCK_ENABLED` / `CONFIG_LOCK_ENABLED` | Disable those flags |
| Stronger uninstall protection (`none` → `difficult`) | Weaken protection |
| Disable pause, shorter pause duration, larger popup | Enable pause, longer pause, smaller popup |
| Toggle `POPUP_AUTO_CLOSE` either way | Change position, dialog tool, service mode |

`POPUP_AUTO_CLOSE=false` is **not** treated as loosening: popups still end via min-display and the absolute watchdog (`lib/popup-safety.sh`). On macOS, `DARWIN_FORCE_AUTO_CLOSE` may still force auto-close at runtime.

Saves still run `check_daily_caps` and `check_restriction_coverage` (16 h/day per category, weekly backstop). Session baseline is captured at wizard entry; tighten-only rules apply for the **whole session** even if the clock leaves lock before save.

Implementation: `lib/configure-partial-lock.sh`; tests: `tests/test-configure-partial-lock.sh`.

`sleep-warning-uninstall` is itself an escape hatch and is subject to the **uninstall-block per-day 16 h cap** (above). It must therefore work for at least 8 hours of every day, no matter how the user configured uninstall protection.

## Non-negotiable rules for changes

1. **Per-day cap is mechanical, not advisory.** Validation must compute merged per-day minutes per category and hard-block if any > 960. The runtime fallback must do the same check (not just "is it 24/7").
2. **Wizard output and validator must speak the same format.** If the wizard writes `HH:MM`, the validator must parse `HH:MM`. No silent "skipped because not an integer" paths.
3. **Every popup spawn path has a watchdog.** Linux yad/zenity/kdialog, macOS Python blocker, macOS osascript fallback — all of them. Watchdog is the absolute ceiling, regardless of how the popup blocks interaction in the meantime.
4. **Lock checks re-run before save.** A wizard entered during a free hour must not be able to save a new config locking the user out at the current moment without re-checking.
5. **Disable paths report truth.** `launchctl bootout` / `systemctl stop` failures must not be swallowed into success messages.
6. **Uninstall removes the agent.** macOS `uninstall.sh` must check `~/Library/LaunchAgents/com.sleep-warning.plist` in its "installed" detection and in `verify_removal`.
7. **Development:** Do not modify installed `~/.config/sleep-warning/` during restricted or blocked hours. Use temp `HOME` for tests (see [.cursor/rules/config-file-edits.mdc](../.cursor/rules/config-file-edits.mdc)).

## What is *not* a safety bug (clarification)

These behaviors used to be flagged in older audits. They are **intentional**:

- Periodic focus stealing during a popup (`focus_force()` on macOS, `wmctrl/xdotool` loops on Linux). The popup is supposed to grab and hold focus. Future work to use the Accessibility API to block Cmd+Tab is an *enhancement*, not a fix.
- Closing the popup and respawning it during min-display if the user dismisses early. The user is trying to escape an active lockout window; respawning is the lockout working.
- `--topmost` / `lift()` / `NSScreenSaverWindowLevel`. All intentional.
- `sleep-warning-manage` opening configure in tighten-only partial mode during lock hours — intentional; escape hatch (disable timer, uninstall) unchanged.

## Code touchpoints (keep in sync)

When changing behavior, review these files together:

- `lib/popup-safety.sh` — caps and watchdog (must be wired into all spawn paths)
- `lib/popup-display.sh` / `lib/popup-display-darwin.sh` — spawn and wait
- `lib/safety-invariants.sh` — stable invariant IDs in hard-block messages (catalog: `dev-docs/development/invariants.md`)
- `lib/configure-validation.sh` — per-day per-category cap enforcement
- `lib/configure-partial-lock.sh` — tighten-only edits during lock hours
- `sleep-warning.sh` — runtime validation fallback (same per-day per-category logic)
- `install.sh` / `lib/install-darwin.sh` — safe defaults on first install
- `uninstall.sh` — full removal including LaunchAgent on macOS

## PR / agent self-review checklist

- [ ] No day in any category (restriction, configure-block, uninstall-block) can exceed 16 h merged.
- [ ] Cap enforced at both configure-time **and** runtime, on both integer-hour and `HH:MM` configs.
- [ ] Every popup spawn path goes through `popup_run_with_watchdog` (or equivalent absolute kill).
- [ ] Popup duration may grow; cap value is configurable in `lib/popup-safety.sh`, not hardcoded in many places.
- [ ] If primary popup fails, fallback path actually fires (verified, not just attempted).
- [ ] Uninstall path detects and removes the LaunchAgent on macOS and reports real status.
- [ ] Tests use temp `HOME` or read-only fixtures.
- [ ] Documented escape hatch verified for the platform you changed.

## If safety and features conflict

**Safety wins, where "safety" means the three invariants above** — per-day cap, finite popup lifetime, always-available escape hatch. **Lockout intensity within those bounds is a feature, not something to weaken.**

## Further reading

- [safety-linux-macos-analysis.md](safety-linux-macos-analysis.md) — how Linux safety patterns map to macOS, gaps, and documentation drift.
- [../dev-docs/plans/plan-real-bugs-fix-2026-05-24.md](../dev-docs/plans/plan-real-bugs-fix-2026-05-24.md) — current bug-fix plan derived from the 2026-05-24 audit.
- [../dev-docs/code-assessments/bug-and-lockout-review-2026-05-24-203354.md](../dev-docs/code-assessments/bug-and-lockout-review-2026-05-24-203354.md) — full audit report.
