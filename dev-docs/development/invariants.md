# Safety invariant IDs

Stable identifiers for configure-time **hard blocks** and runtime safety logs. User-facing rules live in [docs/SAFETY.md](../../docs/SAFETY.md); code constants in [lib/safety-invariants.sh](../../lib/safety-invariants.sh).

## Per-day cap (primary)

| ID | Category | Configure save | Runtime (`validate_config_safety`) |
|----|----------|----------------|-------------------------------------|
| `CAP-RESTRICTION-DAY` | Popup / restriction hours | `show_cap_violation_error` (save + wizard input) | Log + fallback |
| `CAP-CONFIGURE-BLOCK-DAY` | Configure-block merged hours | `show_cap_violation_error` (save + wizard input) | Log + fallback |
| `CAP-UNINSTALL-BLOCK-DAY` | Uninstall-block merged hours | `show_cap_violation_error` (save + wizard input) | Log + fallback |

**SAFETY link:** [docs/SAFETY.md#the-per-day-16-hour-cap-the-central-invariant](../../docs/SAFETY.md#the-per-day-16-hour-cap-the-central-invariant)

Violation payload from `check_daily_caps`: `DayName|category|minutes` (category maps to ID via `safety_invariant_id_for_category`).

## Weekly 24/7 backstop

| ID | When | Surface |
|----|------|---------|
| `CAP-WEEKLY-247` | Merged week totals indicate 24/7 lockout | `show_24_7_error` |

**SAFETY link:** same per-day cap section (weekly backstop is defense in depth).

## Partial configure lock

| ID | When | Surface |
|----|------|---------|
| `PARTIAL-LOCK-TIGHTEN` | Proposed save loosens settings during lock hours | `show_partial_lock_violation_error` |

**SAFETY link:** [docs/SAFETY.md#partial-configure-during-lock-hours-tighten-only](../../docs/SAFETY.md#partial-configure-during-lock-hours-tighten-only)

## Popup timing and lifetime

| ID | When | Surface |
|----|------|---------|
| `POPUP-TIMING-MIN-DISPLAY` | `POPUP_MIN_DISPLAY_TIME` > `CHECK_INTERVAL` | `validate_popup_timing_config` (wizard input) |
| `POPUP-WATCHDOG` | Popup exceeded absolute max seconds | `lib/popup-safety.sh` (runtime) |

**SAFETY link:** [docs/SAFETY.md#popup-lifetime-the-second-invariant](../../docs/SAFETY.md#popup-lifetime-the-second-invariant)

## Message format

Hard-block dialogs and stderr lines include:

1. **`[INVARIANT-ID]`** — stable id
2. **One-line summary** — what failed
3. **`docs/SAFETY.md#…`** — relative path + anchor (works in repo and installed docs tree)

Example:

```text
[CAP-RESTRICTION-DAY] Restriction hours exceed 16 h on at least one calendar day.
docs/SAFETY.md#the-per-day-16-hour-cap-the-central-invariant
```

## Tests

- `tests/test-invariant-messages.sh` — ids present in hard-block surfaces (Tier-A)
- `tests/test-daily-caps.sh` — cap math unchanged

## Runtime validation

`sleep-warning.sh` → `validate_config_safety()` uses `check_daily_caps()` with restriction, configure-lock, and uninstall-lock lines (same categories as configure-time save). See [safety-linux-macos-analysis.md](../safety-linux-macos-analysis.md) §5.2.

## Adding a new invariant

1. Add `readonly INV_*` and summary in `lib/safety-invariants.sh`
2. Document here and link from `docs/SAFETY.md` if user-visible
3. Extend `tests/test-invariant-messages.sh`
4. Entry in [dev-docs/harness-changelog.md](../harness-changelog.md)
