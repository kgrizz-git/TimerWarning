# Plan: Harness engineering improvements (post-refactor)

> **Archived 2026-10-25.** Phases 0–8 complete since 2026-06-12. Residual items
> at archive time: optional weekly Tier-B scheduled workflow (deferred, not
> decided) and slice-verification checkboxes (security scan, CI runners, agent
> smoke, CHANGELOG) covered by normal CI. Historical record.

**Created:** 2026-06-12  
**Status:** **Complete** — Phases 0–8 closed 2026-06-12.

**Prerequisite:** [plan-refactor-assessment-2026-06-12.md](plan-refactor-assessment-2026-06-12.md) (June refactor) — **complete** (Phases 0–10 code work shipped; residual open items are manual smoke / Linux-host verification only and do not block this plan).

**Context:** Assessment against [OpenAI harness engineering](https://openai.com/index/harness-engineering/) (see [dev-docs/harness-engineering.md](../harness-engineering.md)).

**Safety:** [docs/SAFETY.md](../../docs/SAFETY.md) invariants are non-negotiable. Harness work must not weaken per-day caps, popup lifetime ceilings, or escape hatches.

---

## Agent-agnostic harness (not Cursor-only)

The harness serves **any** coding agent that can read the repo and run shell commands: Cursor, GitHub Copilot/Codex, Claude Code, OpenCode, Qwen, Windsurf, etc.

| Layer | Scope | Examples |
|-------|--------|----------|
| **Universal** | All agents + humans + CI | `AGENTS.md`, `docs/SAFETY.md`, `dev-docs/`, `tests/tiers.yaml`, `scripts/run-tests.sh`, GitHub Actions, `CONTRIBUTING` |
| **IDE-specific (optional)** | One tool only | `.cursor/rules/` (Cursor), `CLAUDE.md` (Claude Code), `.github/copilot-instructions.md` (Copilot) |

Phases 1–2, 5–8 are **universal**. Phase 3 is **Cursor rule hygiene** (optional layer — trim noise in `.cursor/rules/`; repo docs remain canonical). Phase 4 rehomes developer docs to `dev-docs/` for all agents.

Entry doc for any agent: [dev-docs/development/agent-setup.md](../development/agent-setup.md).

---

## Doc boundary (end-users vs developers)

| Tree | Audience | Contents |
|------|----------|----------|
| **`docs/`** | End-users (and safety readers) | What the product does, how to stay safe, install/configure at a user level — e.g. `SAFETY.md`, user-oriented architecture summaries if needed |
| **`dev-docs/`** | Developers and coding agents | Plans, assessments, harness workflow, CI/test tiers, agent conventions, backlog |
| **Repo root** | Agents (entry map) | `AGENTS.md` (~100 lines) — table of contents only; links into `dev-docs/` and user `docs/` |

This plan **does not** grow `AGENTS.md`. Agent/harness detail lands under `dev-docs/`. User-visible safety prose stays in `docs/SAFETY.md` (and `user-docs/` where appropriate).

---

## Goals

1. **Mechanical test gating** — One manifest for Tier-A/B/C tests; CI and local runs use the same list.
2. **CI breadth** — macOS runner for headless Darwin suites; path to Linux integration coverage without blocking every PR.
3. **IDE rule hygiene (Cursor optional layer)** — Fewer irrelevant always-on `.cursor/rules/`; one Bash/project conventions rule; universal guidance stays in `dev-docs/`.
4. **Developer doc clarity** — Canonical vs archive map; harness changelog; reduce drift between `dev-docs/` assessments and live CI.
5. **Actionable errors** — Configure/runtime validation messages name the invariant and point to user safety docs.
6. **Contributor hygiene** — File-size guardrail (900-line cap, matching refactor success metrics), optional pre-push hook, PR template.

## Non-goals

- Copying OpenAI’s agent-only codebase or per-worktree app boot patterns (already excluded in harness notes).
- Moving user-facing safety rules out of `docs/SAFETY.md`.
- Rewriting the 71-test suite in one pass.
- Blocking this plan on Linux GUI/`expect` CI (Tier-B / scheduled only).

---

## Phase 0 — Prerequisite gate (refactor complete)

**Closed:** 2026-06-12

- [x] Refactor plan marked complete in [TO_DO.md](../TO_DO.md).
- [x] Tier-A core unit tests pass on macOS dev host (`test-daily-caps`, `test-time-picker-minutes`, `test-popup-safety-darwin`, `test-configure-partial-lock`). Full `run-security-scan.sh --ci --with-tests` also runs `test-darwin-configure-gui.sh` (tkinter daemon — requires GUI-capable session; may fail headless/CI sandbox).
- [x] Post-refactor line counts recorded (below).

### Post-refactor metrics (June 2026 baseline for harness work)

| Metric | Pre-refactor | Post-refactor |
|--------|--------------|---------------|
| `lib/configure-display.sh` | 1,338 | **195** (facade; submodules: `configure-display-summary.sh`, `-menu.sh`, `-grid.sh`) |
| `lib/configure-ui.sh` | 1,291 | **621** (+ `configure-ui-errors.sh` 554) |
| `lib/configure-input-features.sh` | 937 | **37** (facade; `-security.sh`, `-pause.sh`, `-dialog-tool.sh`, `-feature-helpers.sh`) |
| `lib/configure-config.sh` | 871 | **84** (facade; `-config-load.sh`, `-config-write.sh`) |
| `install.sh` | 1,077 | **313** (+ `install-linux.sh` 772) |
| `show_warning()` in `popup-display.sh` | 519 | **169** (+ `popup-display-linux.sh`) |
| Largest `lib/*.sh` (excl. justified Darwin dialogs) | 1,338 | **939** (`configure-dialogs-darwin.sh`; within 900-line exception) |
| `configure-*` modules under `lib/` | ~12 monoliths | **29** facades + submodules |

**Exit criteria:** Met — `lib/` facades and configure splits are stable; proceed to Phase 1.

---

## Phase 1 — Test tier manifest

**Problem:** Tier-A is implicit in `scripts/run-security-scan.sh`; ~5 of 71 test scripts run in CI; agents lack a single “must pass” list.

### Tasks

- [x] Add `tests/tiers.yaml` + human guide [dev-docs/testing-assessments/test-tiers.md](../testing-assessments/test-tiers.md).
- [x] Add `scripts/run-tests.sh --tier a|b|c` (agent-agnostic; `CI_HEADLESS=1` skips GUI-only Tier-A scripts).
- [x] Refactor `run-security-scan.sh --with-tests` to invoke Tier-A via `run-tests.sh`.
- [x] Add [dev-docs/development/agent-setup.md](../development/agent-setup.md) — universal vs IDE-specific layers.
- [x] Document in `tests/README.md`; relocated to `dev-docs/development/testing.md`.

### Exit criteria

- [x] `scripts/run-tests.sh --tier a` and `run-security-scan.sh --ci --with-tests` run the same scripts (modulo `CI_HEADLESS` / GUI skip).
- [ ] Tier list reviewed against [TO_DO.md](../TO_DO.md) Linux popup verification items. — **Done Phase 7:** Tier-A `test-popup-safety-linux.sh` on Linux CI; integration items remain in TO_DO.

---

## Phase 2 — CI workflow expansion

**Problem:** Single `ubuntu-latest` job; Darwin-specific tests skipped in GitHub Actions.

### Tasks

- [x] Update `.github/workflows/security.yml`:
  - **Job: static-analysis** — Ubuntu: ShellCheck, Gitleaks, Semgrep (`run-security-scan.sh --ci`).
  - **Job: tier-a-tests** — Matrix `ubuntu-latest` + `macos-latest`: `CI_HEADLESS=1 ./scripts/run-tests.sh --tier a`.
- [ ] Optional **scheduled** workflow (weekly): Tier-B subset with `timeout` on `expect` suites; artifacts on failure only — deferred.
- [x] Document required checks in `dev-docs/development/ci.md` (new).
- [x] Refresh [dev-docs/templates/safety-scan-template.md](../templates/safety-scan-template.md) CI checkboxes to match live workflows.

### Exit criteria

- [x] PR to `main` runs Tier-A on both Linux and macOS runners (workflow committed; verify on next push).
- [x] Failed macOS Tier-A blocks merge (separate matrix job; `fail-fast: false` per OS).

---

## Phase 3 — IDE rule hygiene (Cursor optional layer)

**Problem:** Many always-on CodeGuard rules in `.cursor/rules/` (crypto, K8s, Django, etc.) are irrelevant to Bash; they dilute project rules for Cursor users. **Non-Cursor agents never load these** — they use `AGENTS.md` + `dev-docs/` only.

### Tasks

- [x] Audit `.cursor/rules/*.mdc`: list `alwaysApply: true` rules (documented in [development/agent-setup.md](../development/agent-setup.md#cursor-rules-optional)).
- [x] Set generic CodeGuard packs to `alwaysApply: false` — disabled always-on on `codeguard-1-crypto-algorithms`, `codeguard-1-digital-certificates`; other CodeGuard rules remain glob-scoped / requestable.
- [x] Keep always-on: `safety-guardrails.mdc`, `config-file-edits.mdc`, `harness-engineering.mdc`, `project-conventions.mdc`, `codeguard-1-hardcoded-credentials.mdc` (5 project + 1 creds = 6 total).
- [x] Add `.cursor/rules/project-conventions.mdc` — mirrored in `dev-docs/development/agent-setup.md`.
- [x] Align `.github/copilot-instructions.md` and `CLAUDE.md` with `dev-docs/` harness paths.

### Exit criteria

- [x] ≤6 always-on project rules (6: five project + hardcoded-credentials).
- [x] `tests.mdc` remains **requestable** (`alwaysApply: false`); documented in [development/agent-setup.md](../development/agent-setup.md).

---

## Phase 4 — Rehome developer docs (`docs/` → `dev-docs/`)

**Problem:** Harness and agent workflow currently live under `docs/` but belong in `dev-docs/` per repo convention.

### Move map (target)

| Current | Target |
|---------|--------|
| `docs/harness-engineering.md` | `dev-docs/harness-engineering.md` |
| `docs/agent-workflow.md` | `dev-docs/agent-workflow.md` |
| `docs/references/openai-harness-engineering.md` | `dev-docs/references/openai-harness-engineering.md` |
| `docs/development/testing.md` | `dev-docs/development/testing.md` |
| `docs/development/security-scanning.md` | `dev-docs/development/security-scanning.md` |
| `docs/development/versioning.md` | `dev-docs/development/versioning.md` |
| `docs/development/platform-test-matrix.md` | `dev-docs/development/platform-test-matrix.md` |
| `docs/development/ci.md` | (new in Phase 2) |
| `docs/architecture/map.md` | `dev-docs/architecture/map.md` |
| `docs/architecture/platforms.md` | `dev-docs/architecture/platforms.md` |

### Keep in `docs/` (end-user / safety)

| File | Reason |
|------|--------|
| `docs/SAFETY.md` | User safety contract |
| `docs/index.md` | User-oriented index; links to `dev-docs/` for developers |

### Also moved to `dev-docs/` (developer / reviewer)

| Former `docs/` path | Target |
|---------------------|--------|
| `docs/core-beliefs.md` | `dev-docs/core-beliefs.md` |
| `docs/safety-linux-macos-analysis.md` | `dev-docs/safety-linux-macos-analysis.md` |

### Tasks

- [x] Create `dev-docs/canonical-vs-archive.md` — what agents read vs historical `*-assessments/`, `safety-scans/`, `completed-plans/`.
- [x] Add `dev-docs/harness-changelog.md` — dated harness fixes (doc/test/rule/CI), not product CHANGELOG.
- [x] Add enhancement → module index to `dev-docs/architecture/map.md`.
- [x] Move files per table; leave stub redirects in `docs/` for one release cycle.
- [x] Update `AGENTS.md`, `.cursor/rules/harness-engineering.mdc`, `README.md`, `tests/README.md`, script comments (CLAUDE.md / copilot-instructions already point at AGENTS.md).

### Exit criteria

- [x] `docs/index.md` reads as end-user index; developer index at `dev-docs/README.md`.
- [x] Root agent entry points (`AGENTS.md`, `dev-docs/README.md`) link to canonical paths.

---

## Phase 5 — Doc drift and template hygiene

### Tasks

- [x] Add `scripts/check-doc-drift.sh` (lightweight):
  - Grep for known-stale phrases (old weekly-cap wording, obsolete enhancement-only paths).
  - Relative link check on `AGENTS.md`, `dev-docs/README.md`, `docs/index.md`, `docs/SAFETY.md`.
- [x] Sync safety-scan template checkboxes with Phase 2 CI.
- [x] One-pass alignment: `user-docs/CONFIGURATION.md`, `dev-docs/TECHNICAL_DETAILS.md` with `docs/SAFETY.md` (per-day 16 h/category cap).

### Exit criteria

- [x] `check-doc-drift.sh` runs in CI (warn-only; `--strict` for local gate).
- [x] Harness changelog has ≥1 entry per completed phase of this plan.

---

## Phase 6 — Actionable validation messages

**Problem:** Mechanical architecture includes errors that teach fixes; safety prose is strong but configure/runtime errors rarely cite invariants.

### Tasks

- [x] Define stable invariant ids (e.g. `CAP-RESTRICTION-DAY`, `CAP-CONFIGURE-BLOCK-DAY`, `POPUP-WATCHDOG`) in `dev-docs/development/invariants.md`.
- [x] Update `lib/configure-validation.sh` / `lib/daily-caps.sh` user-facing messages: invariant id + one line + link to `docs/SAFETY.md` anchor.
- [x] Mirror ids in `tests/test-invariant-messages.sh` (Tier-A) so messages do not rot.

### Exit criteria

- [x] Every hard-block save path cites an invariant id and SAFETY link.
- [x] No new bypass of configure-time hard block.

---

## Phase 7 — Safety harness parity (developer verification)

**Coordinate with** [TO_DO.md](../TO_DO.md) “Linux popup watchdog (verify on Linux build)” — do not duplicate; extend Tier-A manifest.

### Tasks

- [x] Ensure `tests/test-popup-safety-linux.sh` is Tier-A on Linux runners (not alias-only in docs).
- [x] Evaluate `validate_config_safety()` scope for configure/uninstall lock hours — **already uses `check_daily_caps` with all hour types**; documented in [safety-linux-macos-analysis.md](../safety-linux-macos-analysis.md) §5.2.
- [x] Update [safety-linux-macos-analysis.md](../safety-linux-macos-analysis.md) §5.1 (unit tests in Ubuntu CI; integration optional).

### Exit criteria

- [x] Tier-A green on Ubuntu for Linux popup-safety unit tests (manifest + CI matrix; verify on next push).
- [x] Open items in TO_DO Linux verification checklist updated.

---

## Phase 8 — Contributor and git hygiene

### Tasks

- [x] Add `dev-docs/CONTRIBUTING.md` (or root `CONTRIBUTING.md` linking dev-docs): clone → `./scripts/install-git-hooks.sh` → read `AGENTS.md` → `run-tests.sh --tier a`.
- [x] Add `.github/pull_request_template.md` with `docs/SAFETY.md` review checklist (popup/scheduler/config changes).
- [x] Optional: `scripts/install-git-hooks.sh` offers **pre-push** running `run-tests.sh --tier a` (opt-in, documented).
- [x] Resolve `.cursor/hooks/state/continual-learning.json` — already **gitignored**; documented in CONTRIBUTING (Cursor-local, not repo harness).
- [x] Add `scripts/check-file-sizes.sh` — warn on `lib/*.sh` > **900** lines (non-blocking; allowlist `configure-dialogs-darwin.sh`).

### Exit criteria

- [x] New contributor path documented in `dev-docs/README.md`.
- [x] PR template committed (`.github/pull_request_template.md` — used on next PR to repo).

---

## Suggested execution order

```text
Phase 0 ✓ → … → Phase 7 ✓ → Phase 8 ✓ (harness plan complete)
```

Phases 3+4 touch many links — do Phase 4 before or atomically with Phase 3 rule link updates.

---

## Verification (whole plan)

- [ ] `./scripts/run-security-scan.sh --ci --with-tests` on macOS and Linux.
- [ ] GitHub Actions green on sample PR (both runners).
- [ ] Agent smoke: fresh clone → `AGENTS.md` → `dev-docs/agent-workflow.md` → run Tier-A — no dead links.
- [ ] [CHANGELOG.md](../../CHANGELOG.md) entry under `[Unreleased]` when user-visible doc moves affect README/install paths.

---

## References

- [OpenAI harness engineering (Feb 2026)](https://openai.com/index/harness-engineering/)
- [plan-refactor-assessment-2026-06-12.md](plan-refactor-assessment-2026-06-12.md) — prerequisite (complete)
- [refactor-assessment-2026-06-12-001417.md](../refactor-assessments/refactor-assessment-2026-06-12-001417.md)
- [safety-linux-macos-analysis.md](../safety-linux-macos-analysis.md)

**Last updated:** 2026-06-12 (Phase 8 contributor hygiene — plan complete)
