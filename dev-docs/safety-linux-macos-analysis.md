# Safety analysis: Linux heritage vs macOS / harness docs

**Purpose:** Compare the safety principles and goals that existed in the Linux codebase and user documentation **before** macOS support, how they were implemented, how the new macOS layer and `docs/SAFETY.md` reproduce them, and where gaps or differences remain.

**Audience:** Developers, reviewers, and agents changing popups, schedulers, or configuration.

**Related:** [docs/SAFETY.md](../docs/SAFETY.md) (operating rules), [user-docs/CONFIGURATION.md](../user-docs/CONFIGURATION.md) (user-facing safety features), [user-docs/MACOS.md](../user-docs/MACOS.md) (macOS emergency playbook).

---

## Executive summary

The Linux project evolved safety through numbered **enhancements** (#9, #15, #18–#22, #26, unicode dialog safety) with deep coverage in `user-docs/CONFIGURATION.md`, safety-scan templates, and extensive tests. Core invariants:

1. Never allow 24/7 restriction schedules to be saved (or to take effect at runtime).
2. Popups must not stack indefinitely; users must be able to dismiss or wait them out.
3. “Self-control” features (config lock, configure blocking, difficult uninstall) must not combine with extreme schedules to brick recovery.
4. Always leave a **manual escape path** (`manual-uninstall-guide`, manage/disable, kill dialog process).

macOS work **reuses shared validation and configure logic** and adds **`lib/popup-safety.sh`** (watchdog, caps, forced auto-close) because osascript modals are harder to bound than Linux yad/zenity auto-close timers.

The new **`docs/SAFETY.md`** and harness docs correctly elevate these rules but **emphasize macOS mechanisms** more than Linux equivalents. Several **documentation sources still cite obsolete thresholds** (9660 min/week = 23 h/day) while code uses **6720** (16 h/day). **Linux does not yet use the shared popup watchdog** module.

---

## 1. Prior safety principles and goals (Linux era)

These goals appear repeatedly in enhancement specs, `user-docs/CONFIGURATION.md`, safety-scan checklists, and configure UI copy.

| # | Principle | User-facing goal | Rationale |
|---|-----------|------------------|-----------|
| P1 | **No accidental 24/7 lockout** | Cannot save a schedule that covers all 24×7 hours (combined restriction + lock + uninstall-lock hours) | Warnings every check interval with no window to fix config |
| P2 | **High-restriction warnings** | If combined restricted time **> 16 h/day** (6720 min/week), warn and apply safety overrides on save | Very little unrestricted time to recover from mistakes |
| P3 | **Runtime config sanity** | If someone hand-edits config to 24/7, runtime falls back to safe defaults | Configure-time validation can be bypassed |
| P4 | **Popup queue prevention** | Only one warning dialog at a time; skip duplicate if still within check interval | Modal pile-up (Enhancement #9) |
| P5 | **Bounded popup lifetime** | Min display (0–300 s) + optional auto-close (+10 s); timing validated vs check interval | User not stuck forever (Enhancement #15, #9) |
| P6 | **Dialog robustness** | UTF-8 / ASCII sanitization so yad/zenity do not crash and respawn loops | SteamOS / `LANG=C` (unicode-dialog-safety) |
| P7 | **Configure/manage blocking** | Optional block of `configure.sh` / `manage.sh` during restricted or lock hours | Self-control (Enhancement #19) |
| P8 | **Config file locking** | Optional read-only config dir during restricted or lock hours | Deterrence (Enhancement #18); auto-disabled on high restrictions |
| P9 | **Difficult uninstall** | Optional verification during restricted or uninstall-lock hours | Self-control (Enhancement #26) |
| P10 | **Manual uninstall always available** | `manual-uninstall-guide` never blocked | Ultimate escape hatch |
| P11 | **Safe test / dev practice** | Cursor rules: no live config edits during blocked hours; test schedules capped | Agent/human development safety |

**Design tension (intentional):** P7–P9 **reduce** circumvention during restricted hours while P10 and manage/disable **guarantee** recovery. Safety overrides on P2 explicitly **disable** P7–P8 when schedules are aggressive.

---

## 2. How Linux implemented them

### 2.1 Configuration and validation

| Mechanism | Implementation | Key files |
|-----------|----------------|-----------|
| 24/7 block at save | `check_restriction_coverage()` → `block` if total ≥ 10080 min/week | `lib/configure-validation.sh`, `configure.sh` |
| High-restriction warn | → `warn` if total > 6720; user confirm + overrides | Same + `lib/configure-ui.sh` |
| Combined hour types | Restriction + `CONFIG_LOCK_HOURS_*` + `UNINSTALL_LOCK_HOURS_*` merged | `lib/configure-validation.sh` |
| Safety overrides on warn | Popup size clamp, `CONFIGURE_BLOCK_ENABLED=false`, `CONFIG_LOCK_ENABLED=false`, clear lock hour lines | `configure.sh`, `lib/configure-config.sh` |
| Popup timing conflict | `POPUP_MIN_DISPLAY_TIME` must not exceed `CHECK_INTERVAL` | `validate_popup_timing_config()` |
| Runtime 24/7 fallback | `validate_config_safety()` in main script; uses **restriction hours only** | `sleep-warning.sh` |
| User documentation | Long sections on 24/7 prevention, lock hours, overrides | `user-docs/CONFIGURATION.md` |

Threshold constants (authoritative in code):

```78:85:lib/configure-core.sh
HOURS_PER_DAY_WARN=16      # Warning threshold: > 16 hours/day
HOURS_PER_DAY_BLOCK=24     # Block threshold: >= 24 hours/day (24/7 restrictions)
...
THRESHOLD_WARN=$((HOURS_PER_DAY_WARN * MINUTES_PER_HOUR * DAYS_PER_WEEK))      # Currently 6720
THRESHOLD_BLOCK=$((HOURS_PER_DAY_BLOCK * MINUTES_PER_HOUR * DAYS_PER_WEEK))     # 10080
```

### 2.2 Popups and dialogs (Linux)

| Mechanism | Implementation | Key files |
|-----------|----------------|-----------|
| Duplicate prevention | PID file + age vs check interval; close stale | `lib/popup-pid-management.sh`, `lib/popup-display.sh` |
| Min display loop | Main script waits up to `min_display_time`, updates countdown | `lib/popup-display.sh` |
| Auto-close | Background `auto_close_popup()` sleeps 10 s then `close_popup_process` | `lib/popup-display.sh` |
| Pause | Dialog buttons + `lib/pause-state.sh` | `lib/popup-dialog-implementations.sh` |
| Locale safety | `unicode-dialog-safety.sh`, `ensure_utf8_locale_for_dialogs` | `lib/popup-display.sh` |
| **Hard watchdog** | **Not present** — no `POPUP_ABSOLUTE_MAX_SECONDS` kill on Linux path | — |

Linux bounds popups **softly** via min-display + auto-close + user OK button, not a hard process kill ceiling.

### 2.3 Recovery and self-control (Linux)

| Mechanism | Implementation |
|-----------|----------------|
| Disable timer | `sleep-warning-manage`, `systemctl --user stop sleep-warning.timer` |
| Uninstall | `sleep-warning-uninstall` (+ difficult verification when enabled) |
| Manual guide | `manual-uninstall-guide.sh` → installed as `manual-uninstall-guide` |
| Config lock apply | `apply_config_directory_lock()` early in `sleep-warning.sh` |
| Configure block | `check_config_lock_time()` at start of `configure.sh` / `manage.sh` |

### 2.4 Tests and process (Linux)

- `tests/test-24-7-prevention-additional-hours.sh` — validation with lock/uninstall hours
- `tests/test-config-locking.sh`, `tests/test-configure-blocking.sh`, `tests/test-uninstall-lock-hours.sh`
- `tests/test-non-utf-dialog-safety.sh` — dialog string safety
- `dev-docs/templates/safety-scan-template.md` — repeatable audit checklist (updated to 6720 warn threshold)
- `.cursor/rules/config-file-edits.mdc`, `tests.mdc` — dev/agent constraints

---

## 3. How macOS / new code reproduces them

### 3.1 Shared (both platforms)

These paths are **unchanged in behavior** for macOS except where platform facades swap scheduler/popup backends:

| Prior principle | macOS reproduction |
|-----------------|-------------------|
| P1, P2 configure-time | Same `configure.sh` → `check_restriction_coverage()` with all three hour types |
| P3 runtime fallback | Same `validate_config_safety()` in `sleep-warning.sh` (**restriction hours only** — same as Linux) |
| P4 duplicate popups | Same `popup-pid-management.sh` used from `popup-display-darwin.sh` |
| P7–P9 self-control | Same config keys; `configure.sh` / `manage.sh` / `uninstall.sh` run on macOS |
| P10 manual guide | Installed by `lib/install-darwin.sh` |
| P11 dev rules | Extended in `docs/SAFETY.md`, `.cursor/rules/safety-guardrails.mdc` |

Scheduler escape hatch is platform-specific but equivalent:

- Linux: `systemctl --user stop sleep-warning.timer`
- macOS: `launchctl bootout gui/$(id -u)/com.sleep-warning` (`lib/scheduler-platform.sh`, `user-docs/MACOS.md`)

### 3.2 macOS-specific additions

| Prior principle | macOS addition | Key files |
|-----------------|------------------|-----------|
| P5 bounded popup | **`lib/popup-safety.sh`**: `POPUP_ABSOLUTE_MAX_SECONDS` (330), `popup_run_with_watchdog`, `popup_compute_watchdog_seconds` | Wired in `lib/popup-display-darwin.sh` |
| P5 forced auto-close | `DARWIN_FORCE_AUTO_CLOSE=true` overrides config | `lib/popup-safety.sh`, install default in `lib/install-darwin.sh` |
| P5 min display cap | Max 60 s on Darwin (`DARWIN_MAX_MIN_DISPLAY_TIME`) vs 300 s Linux | `popup_safe_get_min_display_time()` |
| P5 fallback if GUI fails | Notification fallback when osascript spawn fails | `lib/popup-display-darwin.sh` |
| P6 dialog robustness | AppleScript string escaping (`_darwin_escape_applescript`) | `lib/popup-dialog-implementations-darwin.sh` |
| Tests | `tests/test-popup-safety-darwin.sh` | Watchdog unit tests |

```68:76:lib/popup-display-darwin.sh
    local watchdog_seconds
    watchdog_seconds=$(popup_compute_watchdog_seconds "${min_display_time}" "${popup_auto_close}")

    _popup_spawn_warning_dialog() {
        _popup_spawn_warning_dialog_darwin "${message}"
    }

    popup_run_with_watchdog _popup_spawn_warning_dialog "${watchdog_seconds}"
```

### 3.3 New documentation (`docs/SAFETY.md`, harness)

| Prior source | New doc coverage |
|--------------|------------------|
| CONFIGURATION.md 24/7 sections | Summarized as rules #1–#4 in `docs/SAFETY.md` |
| Safety-scan themes | Condensed checklist + code touchpoints |
| Enhancement cross-refs | Partial — enhancements not enumerated by number |
| Linux emergency paths | Listed alongside macOS in `docs/SAFETY.md` § escape hatch |
| Agent/dev rules | Stronger in `docs/SAFETY.md`, [dev-docs/development/testing.md](development/testing.md), Cursor rules |
| Harness map | `AGENTS.md`, [dev-docs/harness-engineering.md](harness-engineering.md), `docs/index.md` |

---

## 4. Comparison matrix

| Safety concern | Linux (prior) | macOS / new | Match? |
|----------------|---------------|-------------|--------|
| Block 24/7 save (all hour types) | Yes | Yes (shared) | ✅ Full |
| Per-day 16 h cap hard block | Yes | Yes (shared `check_daily_caps`) | ✅ Full |
| Runtime per-day cap fallback | Yes (`check_daily_caps`, all categories) | Same | ✅ Full |
| Duplicate popup skip | Yes | Yes | ✅ Full |
| Min display time | 0–300 s | Capped 60 s | ⚠️ Stricter on macOS (intentional) |
| Auto-close | Configurable | Forced on for new installs | ⚠️ Stricter on macOS (intentional) |
| Hard popup watchdog | Yes (`popup_start_pid_file_watchdog`) | Yes (`popup_run_with_watchdog`) | ✅ Full (mechanisms differ) |
| `validate_popup_timing_config` | Yes | Yes (shared configure) | ✅ Full |
| Unicode/locale dialog safety | Extensive | Escape-only | ⚠️ Different strategy |
| Config lock / configure block | Full | Full (shared code) | ✅ Full |
| Difficult uninstall | Full | Full (shared code) | ✅ Full |
| Manual uninstall guide content | systemd steps only | Same script (no launchctl section) | ❌ **Gap** |
| Emergency docs | README, CONFIGURATION | + MACOS.md, SAFETY.md | ✅ Improved |
| Linux popup safety tests | Tier-A `test-popup-safety-linux.sh` (Ubuntu CI) | N/A | ✅ Unit |
| macOS popup safety tests | Tier-A `test-popup-safety-darwin.sh` | `test-popup-safety-darwin.sh` | ✅ Unit |
| Dev/agent config rules | `.cursor/rules` | + `docs/SAFETY.md`, safety-guardrails | ✅ Improved |

---

## 5. Gaps and differences (detailed)

### 5.1 Linux popup watchdog (updated 2026-06-12)

**Code (2026-05-30):** `lib/popup-display-linux.sh` uses `popup_compute_watchdog_seconds` plus `popup_start_pid_file_watchdog` (reads `POPUP_PID_FILE` so respawns stay bounded). macOS uses `popup_run_with_watchdog` on the spawn function.

**Harness (2026-06-12, Phase 7):** `tests/test-popup-safety-linux.sh` is **Tier-A on `linux` runners** (`ubuntu-latest` in GitHub Actions). It runs shared `popup-safety.sh` unit tests plus a **PID-file watchdog kill** test and asserts `popup-display-linux.sh` wiring.

**Remaining gap (optional):** No integration test that wedges yad/zenity/kdialog on a display host — see TO_DO integration checklist and [plan-safety-scan-fixes-2026-05-30.md](../plans/plan-safety-scan-fixes-2026-05-30.md).

### 5.2 Runtime validation scope (resolved 2026-06-12)

**Prior finding:** Older audits said `validate_config_safety()` only passed restriction lines to `check_restriction_coverage()`.

**Current behavior:** `sleep-warning.sh` → `validate_config_safety()` calls `check_daily_caps()` with restriction lines, `CONFIG_LOCK_HOURS_*`, `UNINSTALL_LOCK_HOURS_*`, and feature flags (`CONFIGURE_BLOCK_ENABLED`, `UNINSTALL_PROTECTION_MODE`). All three per-day categories are enforced at runtime; unsafe configs fall back to defaults.

**Legacy fallback:** If `check_daily_caps` is unavailable, weekly `check_restriction_coverage` on restriction lines only still runs.

**Deferred:** Weekly 24/7 backstop at runtime (restriction-only legacy path) — configure-time `check_restriction_coverage` remains the backstop for manual edits that bypass daily-caps module load failures only.

### 5.3 Documentation threshold drift (9660 vs 6720)

**Status (2026-06-12):** User `CONFIGURATION.md` and `TECHNICAL_DETAILS.md` aligned with per-day 16 h cap (harness Phase 5). Historical `safety-scans/` copies may still cite 9660.

**Recommendation:** Treat archive scans as historical; canonical user docs are `docs/SAFETY.md` and `user-docs/CONFIGURATION.md`.

### 5.4 `manual-uninstall-guide.sh` is Linux-centric (macOS gap)

**Finding:** Guide steps reference systemd units only; no `launchctl bootout`, LaunchAgent plist paths, or macOS log locations.

**Risk:** macOS user following manual guide during difficult-uninstall scenario may miss scheduler removal steps (though `uninstall.sh` handles Darwin via `scheduler-platform.sh`).

**Recommendation:** Add macOS section to manual guide or branch on `is_darwin`.

### 5.5 `docs/SAFETY.md` skews toward macOS mechanisms

**Finding:** Popup safety table highlights `DARWIN_FORCE_AUTO_CLOSE`, 60 s cap, osascript watchdog. Linux equivalents (`auto_close_popup`, 300 s max, `close_popup_process`) are not listed symmetrically.

**Risk:** Agents editing Linux popups may underestimate need for bounded lifetime or over-assume watchdog exists.

**Recommendation:** Add a “Linux popup bounds” subsection mirroring the macOS table.

### 5.6 macOS configure GUI scope vs safety features

**Finding:** GUI on macOS uses `lib/configure-dialogs-darwin.sh`; full menu parity was added for Phase 4, but Linux-only items (dialog tool, service mode) are skipped. Security/lock menus remain available through shared `configure.sh` text/GUI flows.

**Status:** Not a safety regression — validation runs on save regardless of UI. Text mode exposes all options.

### 5.7 Test coverage asymmetry

| Area | Linux tests | macOS tests |
|------|-------------|-------------|
| 24/7 + lock hours validation | `test-24-7-prevention-additional-hours.sh` | Same script runs on either OS |
| Popup watchdog | `test-popup-safety-linux.sh` (Tier-A, Linux CI) | `test-popup-safety-darwin.sh` (Tier-A, macOS CI) |
| Config lock / configure block | Dedicated suites | Shared logic; not re-run in darwin-specific suite |

### 5.8 Harness docs vs enhancement catalog

**Finding:** Harness docs ([dev-docs/harness-engineering.md](harness-engineering.md), [dev-docs/core-beliefs.md](core-beliefs.md)) encode principles well but **do not map enhancement IDs** (#18, #22, etc.) that older dev-docs use.

**Impact:** Agents tracing “Enhancement #22” from old docs may not find it in `docs/SAFETY.md`.

**Recommendation:** Optional appendix mapping enhancement numbers → current modules.

---

## 6. Wiring assessment: was new code aligned with prior principles?

| Change | Aligned with prior goals? | Notes |
|--------|---------------------------|-------|
| `lib/popup-safety.sh` | ✅ Yes — strengthens P5 | Darwin-first; module is platform-aware but Linux not hooked up |
| `popup-display-darwin.sh` watchdog | ✅ Yes | Direct response to osascript modal risk |
| Forced auto-close + 60 s cap on macOS | ✅ Yes — stricter than Linux | Matches macOS plan “safety guardrails mandatory” |
| Shared validation unchanged | ✅ Yes | P1/P2 preserved |
| `install-darwin.sh` `POPUP_AUTO_CLOSE=true` | ✅ Yes | Safe defaults on first install |
| `docs/SAFETY.md` | ✅ Mostly | Should add Linux popup bound details |
| Cursor `safety-guardrails.mdc` | ✅ Yes | Extends prior `.cursor/rules` |
| No change to Linux popup path | ⚠️ Partial | New safety module not retrofitted |

**Conclusion:** macOS work **correctly prioritizes** the same principles with **stronger mechanical enforcement** on popups. Documentation consolidation **captures the intent** but **under-documents Linux-specific mechanisms** and inherits **threshold doc drift** from older sources.

---

## 7. Recommended follow-ups (priority order)

1. ~~**Doc fix:** Align CONFIGURATION.md, TECHNICAL_DETAILS with per-day 16 h cap ([docs/SAFETY.md](../docs/SAFETY.md)).~~ Done 2026-06-12 (harness Phase 5).
2. **SAFETY.md:** Add Linux popup bounds table (symmetric with macOS notes).
3. ~~**Code/tests:** `tests/test-popup-safety-linux.sh` in Tier-A on Linux CI.~~ Done 2026-06-12 (harness Phase 7).
4. **manual-uninstall-guide.sh:** macOS steps for LaunchAgent + paths.
5. ~~**Runtime validation:** Include lock/uninstall-lock hours in `validate_config_safety()`.~~ Done — uses `check_daily_caps` with all hour types (documented §5.2).
6. **Enhancement index:** Short mapping in `docs/SAFETY.md` or [dev-docs/architecture/map.md](architecture/map.md).
7. **Optional:** `tests/test-popup-safety-linux-integration.sh` — wedge yad/zenity on a display host.

---

## 8. Source index (for reviewers)

| Topic | Primary sources |
|-------|-----------------|
| 24/7 prevention spec | `dev-docs/enhancements/enhancement-22-prevent-24-7-restriction-configuration.md` |
| Validation implementation | `lib/configure-validation.sh`, `configure.sh` (review/save) |
| Runtime fallback | `sleep-warning.sh` → `validate_config_safety()` |
| Linux popups | `lib/popup-display.sh`, `lib/popup-pid-management.sh` |
| Linux auto-close | `lib/popup-display.sh` → `auto_close_popup()` |
| Unicode safety | `lib/unicode-dialog-safety.sh` |
| macOS popups | `lib/popup-display-darwin.sh`, `lib/popup-safety.sh` |
| User safety prose | `user-docs/CONFIGURATION.md` § 24/7, lock, uninstall |
| macOS playbook | `user-docs/MACOS.md` |
| Operating rules (new) | `docs/SAFETY.md` |
| Safety audits | `dev-docs/templates/safety-scan-template.md` |
| Agent constraints | `.cursor/rules/safety-guardrails.mdc`, `config-file-edits.mdc`, `tests.mdc` |

---

*Last updated: 2026-06-12 — harness Phase 7 Linux Tier-A popup tests; runtime `check_daily_caps` scope documented.*
