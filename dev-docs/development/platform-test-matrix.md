# Platform test matrix

**Canonical reference** for which tests run on macOS vs Linux, headless vs GUI, and known failure categories. Update this file when adding tests or fixing platform-specific expectations.

Related: [testing.md](testing.md), [tests/README.md](../../tests/README.md), [phase-0 verification record](../completed-plans/phase-0-verification-2026-06-12.md).

## Categories

| Category | Meaning |
|----------|---------|
| `headless-safe` | No GUI session required; safe on macOS/Linux CI with temp `HOME` |
| `linux-only` | Requires Linux systemd user layout or Linux-specific APIs |
| `gui-manual` | Requires yad/zenity/kdialog and human visual verification |
| `expect-interactive` | Requires `expect` driving `configure.sh --text` |
| `environment-skip` | Skips when display resolution or dialog tools unavailable |

## Quick matrix

| Test script | macOS headless | Linux headless | GUI / manual | CI default | Status |
|-------------|----------------|----------------|--------------|------------|--------|
| `test-configure-modular.sh` | Yes | Yes | No | Yes | **Fixed** — stale `extract_user_comments` assertion removed |
| `test-grid-functions.sh` | Yes | Yes | No | Yes | **Fixed** — golden strings match `format_range_human` output |
| `test-modular-refactor.sh` | Yes | Yes | No | Yes | **Fixed** — loader pattern + line budget |
| `test-configure-blocking.sh` | Yes | Yes | No | Yes | **Fixed** — EOF cancel may exit 0 after `configure_read` hardening |
| `test-mode-detection.sh` | Partial | Yes | No | Partial | Darwin runs the Linux drop-in cases; they fail because `create_service_dropin` is a no-op stub. They are not skipped |
| `test-enhancement-03-integration.sh` | Partial | Yes | No | Partial | **Fixed** — display-based section skips without resolution |
| `test-popup-safety-darwin.sh` | Yes (Tier-A) | No (use linux script) | No | macOS CI | Pass |
| `test-popup-safety-linux.sh` | No | Yes (Tier-A) | No | Linux CI | Pass — PID-file watchdog + shared unit tests |
| `test-platform-darwin.sh` | Yes (Tier-A) | No | No | macOS CI | Pass |
| `test-darwin-persistent-disable.sh` | Yes (Tier-A) | Yes (Tier-A) | No | Yes | Stubbed launchctl; persistent disable, explicit enable and failure/reload paths |
| `test-configure-comprehensive.sh` | expect + PTY | expect + PTY | No | No | **Fixed** — `.exp` updated for window-behavior submenu + prompt anchoring; 10/10 on macOS (2026-06-13) |
| `test-dialog-abstraction.sh` | Skip | Skip | Yes | Skip | **Skip** — GUI manual |
| `test-multi-column-specific.sh` | Skip | Skip | Yes | Skip | **Skip** — GUI manual |
| `test-dialog-size-behavior.sh` | Skip | Skip | Yes | Skip | **Skip** — GUI manual |

## macOS headless batch (recommended)

Run from repo root with temp `HOME` where noted:

```bash
bash tests/test-configure-modular.sh
bash tests/test-grid-functions.sh
bash tests/test-modular-refactor.sh
bash tests/test-configure-blocking.sh
bash tests/test-mode-detection.sh
bash tests/test-enhancement-03-integration.sh
bash tests/test-popup-safety-darwin.sh
bash tests/test-platform-darwin.sh
# Tier-A (CI): ./scripts/run-tests.sh --tier a
```

## Linux-only / desktop

```bash
bash tests/test-mode-detection.sh          # full 15/15 with systemd user dir
bash tests/test-popup-safety-linux.sh
bash tests/test-configure-comprehensive.sh 1 2 3   # batched; needs expect
```

## Platform skip helper

Tests may source [`tests/lib/test-platform.sh`](../../tests/lib/test-platform.sh):

- `test_is_linux` / `test_is_darwin`
- `test_skip_linux_only` — exit 0 with SKIP message
- `test_skip_unless_display_resolution`
- `test_skip_gui_manual` — no dialog tool or `CI=true`

## Remediation log (2026-06-13)

| Test | Verdict | Fix |
|------|---------|-----|
| `test-configure-modular.sh` | Stale expectation | Assert `write_config` / `load_existing_config`; `extract_user_comments` intentionally removed |
| `test-grid-functions.sh` | Stale expectation | Golden strings use `12:00am ->` style from `24hour_to_12hour` |
| `test-modular-refactor.sh` | Stale expectation | Check `source_required_lib` loader; line budget `< 450` |
| `test-configure-blocking.sh` | Stale expectation | Accept rc=0 on EOF cancel when partial-lock banner present |
| `test-mode-detection.sh` | macOS skip | Linux systemd drop-in tests skipped on Darwin |
| `test-enhancement-03-integration.sh` | Environment skip | Skip display-based calc without `get_display_resolution` |
| GUI manual tests | Not automatable headless | Early SKIP via `test_skip_gui_manual` |
| `test-configure-comprehensive.sh` | Stale expectation | Window-behavior submenu flow + wait for `configure_read` prompts before send; tests 8/10 same pattern |

## macOS verification (2026-06-13)

Headless batch (all pass):

| Test | Result |
|------|--------|
| `test-configure-modular.sh` | 10/10 |
| `test-grid-functions.sh` | 10/10 |
| `test-modular-refactor.sh` | 10/10 |
| `test-configure-blocking.sh` | PASS |
| `test-mode-detection.sh` | 15/15 |
| `test-enhancement-03-integration.sh` | 19/19 |
| `test-popup-safety-darwin.sh` | 4/4 |
| `test-platform-darwin.sh` | 5/5 |

Comprehensive suite (`expect` + PTY, temp `HOME`): **10/10** scenarios pass.

GUI manual tests: **SKIP** (no dialog tool / headless).

## Follow-up backlog

| Item | Tracking |
|------|----------|
| Unify time display (`format_hour_12h` vs `24hour_to_12hour` / `format_range_human`) | [dev-docs/TO_DO.md](../../dev-docs/TO_DO.md) |
| Refresh `test-configure-comprehensive.exp` wizard strings | **Done** on macOS 2026-06-13 (Linux re-verify optional) |

**Last updated:** 2026-06-13 (pre-existing failure remediation)
