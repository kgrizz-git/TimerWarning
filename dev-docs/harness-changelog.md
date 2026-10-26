# Harness changelog

Dated **harness** changes (docs, tests, CI, agent workflow)—not product [CHANGELOG.md](../CHANGELOG.md).

## 2026-10-26 — Sonar gate fails closed

- The `.env` mode check uses GNU `stat -c` before BSD `stat -f`, so Ubuntu Tier-A no longer dies on `8#`.
- A push whose scan state matches the commit fails when the issue dump is missing, has no commit, or would erase every baselined bug. An empty API page before the reported total is a failed scan.
- The collector writes only `tmp/sonar-state.json` and `tmp/sonar-latest-issues.json`. Those paths are not command-line arguments.

## 2026-10-26 — Local Sonar issue ratchet

- `scripts/sonar_scan.sh` refuses a dirty tree, waits for the Compute Engine task without putting the token on a command line, and writes `tmp/sonar-latest-issues.json` with counts by type and by rule.
- Pre-push checks each pushed commit against that scan and the recorded host. A ref delete is not checked. `scripts/check_sonar_issues.py` fails when a `BUG` or `VULNERABILITY` count rises for the same rule and file. Code smells and severity are not gated. The baseline starts empty.
- `.env` should be mode `0600`. The loader accepts a leading `export` and a trailing comment, and warns when group or other can read the file.
- The local Community Build analyzes Python only. This ratchet does not see the shell rules SonarCloud reports on pull requests.

## 2026-10-26 — Local SonarQube before push

- `.env` is gitignored. Copy `.env.example` and set `SONAR_TOKEN` there. `SONAR_HOST_URL` is optional and defaults to `http://localhost:9000`. The token is not stored in the repo.
- `scripts/sonar_scan.sh` runs the scanner, waits for the Compute Engine task, and records the commit in `tmp/sonar-state.json`. `sonar-project.properties` is for that local server only. Cloud automatic analysis ignores it.
- Pre-push does not run the scanner. When a token is set, `scripts/check-sonar-freshness.sh` requires that recorded commit to match `HEAD`. `SKIP_LOCAL_SONAR=1` skips the check. Tier-A remains opt-in. This does not replace the SonarCloud GitHub app.

## 2026-10-25 — Publication Phase 3: stubs removed, completed plans archived

- Removed all `Moved` redirect stubs under `docs/` and `dev-docs/CONFIGURE_GUI_FLOW.md`. Live docs already pointed at `dev-docs/`; `docs/index.md`, `canonical-vs-archive.md`, and `scripts/check-doc-drift.sh` updated together.
- Moved the eight tracked `.cursor/plans/` drafts to `dev-docs/completed-plans/` after retargeting inbound and repository-relative links. Verified the osascript `activate` throttle is shipped in code; only manual z-order QA remains ([TO_DO smoke](TO_DO.md#smoke-tests)).
- Archived ten completed/superseded dev-docs plans with banners (percentage-size, phase-0, Feb + June refactor, pause, harness, real-bugs, gamescope click-through, extend-24/7, 16b status display). The weekday plan remains active under `plans/` for unimplemented systematic dialog hardening. Assessment stays in place (referenced by `lib/configure-dialogs-darwin.sh`).
- New [TO_DO smoke section](TO_DO.md#smoke-tests) collects the manual-only remainders. Kept active: weekday dialog hardening, additional-hours proposal, popup-frequency review, safety-scan integration test, SteamOS overlay verification. No archives deleted; retention scripts previewed dry-run only.

## 2026-10-24 — Publication docs, rename deferred

- Public name and clone URL changes wait for the first commit on the new private repository, before it is made public.
- User docs now match pause durations 1, 2, 3, 5, 10, or 15 and the hour-based cooldown. PayPal links stay.
- `*.bundle` and `.cursor/plans/` are gitignored. Eight already-tracked Cursor plans stay until their links are retargeted. The root generalization summary was archived and removed.

## 2026-10-24 — Project license and contribution terms

- Root `LICENSE`: Apache License 2.0 with the Commons Clause. Source-available, not OSI open source.
- [CONTRIBUTING.md](CONTRIBUTING.md) and the root pointer: contributions are submitted under those combined terms.
- [info/LICENSE_OPTIONS.md](info/LICENSE_OPTIONS.md) records the decision and corrects the claim that noncommercial licenses allow internal business use.

## 2026-06-23 — Doc archive retention

- [development/doc-retention.md](development/doc-retention.md) — policy for assessments, safety scans, completed plans, backups.
- `scripts/prune-dev-docs-archive.sh` — dry-run default; pre-commit report-only.
- `scripts/prune-completed-plans.sh`, `scripts/check-stale-plans.sh` — manual housekeeping.
- Backups prune default: **5** commits (was 3).

## 2026-06-12 — Phase 8 contributor hygiene (plan complete)

- [CONTRIBUTING.md](CONTRIBUTING.md), root pointer, PR template, `check-file-sizes.sh`, opt-in pre-push hook.
- Cursor `continual-learning.json` — gitignored local state; documented.

## 2026-06-12 — Phase 7 Linux popup Tier-A

- `tests/test-popup-safety-linux.sh` — Tier-A on Linux runners; PID-file watchdog unit test + `popup-display-linux.sh` wiring check.
- Platform-scoped Tier-A popup tests in `tests/tiers.yaml` (Darwin vs Linux CI).
- Documented `validate_config_safety()` full `check_daily_caps` scope in [safety-linux-macos-analysis.md](../safety-linux-macos-analysis.md) §5.2.

## 2026-06-12 — Phase 6 invariant messages

- Added [lib/safety-invariants.sh](../../lib/safety-invariants.sh) and [development/invariants.md](development/invariants.md).
- Hard-block dialogs (`show_cap_violation_error`, `show_24_7_error`, `show_partial_lock_violation_error`, `validate_popup_timing_config`) cite `[INVARIANT-ID]` + `docs/SAFETY.md` anchor.
- Tier-A: `tests/test-invariant-messages.sh`.

## 2026-06-12 — Phase 5 doc drift

- Added `scripts/check-doc-drift.sh` (warn-only in CI; `--strict` locally).
- Aligned [user-docs/CONFIGURATION.md](../user-docs/CONFIGURATION.md) and [TECHNICAL_DETAILS.md](TECHNICAL_DETAILS.md) with per-day 16 h cap in [docs/SAFETY.md](../docs/SAFETY.md).
- Updated safety-scan template links; fixed stale paths in canonical dev-docs.

## 2026-06-12 — Phase 3 Cursor rule hygiene

- **Always-on (6):** `safety-guardrails`, `config-file-edits`, `harness-engineering`, `project-conventions`, `hardcoded-credentials`, plus creds rule documented in [development/agent-setup.md](development/agent-setup.md).
- **Disabled always-on:** `codeguard-1-crypto-algorithms`, `codeguard-1-digital-certificates`.
- Added [project-conventions.mdc](../../.cursor/rules/project-conventions.mdc); updated `tests.mdc`, Copilot instructions, `CLAUDE.md`.

## 2026-06-12 — Phase 4 doc rehome

- **Two-tree model:** `docs/` = end-users (`SAFETY.md`, user index); `dev-docs/` = developers and all coding agents.
- Moved architecture, development, harness, agent-workflow, core-beliefs, safety analysis, and OpenAI reference from `docs/` → `dev-docs/`.
- Left **Moved** stubs under `docs/` for one release cycle.
- Added [canonical-vs-archive.md](canonical-vs-archive.md), enhancement index in [architecture/map.md](architecture/map.md).

## 2026-06-12 — Phase 2 CI matrix

- Split `.github/workflows/security.yml`: `static-analysis` (Ubuntu) + `tier-a-tests` (Ubuntu + macOS).
- Added [development/ci.md](development/ci.md).
- `run-security-scan.sh --with-tests` sets `CI_HEADLESS=1` when `CI=true`.

## 2026-06-12 — Phase 1 test tiers

- Added `tests/tiers.yaml`, `scripts/run-tests.sh`, [testing-assessments/test-tiers.md](testing-assessments/test-tiers.md).
- Added [development/agent-setup.md](development/agent-setup.md) — agent-agnostic vs IDE-specific layers.

## 2026-06-12 — Post-refactor gate

- June 2026 refactor complete; harness plan unblocked.
- Documented `configure.sh` unbounded-run hazard in AGENTS.md / CLAUDE.md (prior incident).
