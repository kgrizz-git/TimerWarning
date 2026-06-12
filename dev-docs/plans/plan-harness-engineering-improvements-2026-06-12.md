# Plan: Harness engineering improvements (post-refactor)

**Created:** 2026-06-12  
**Prerequisite:** Complete [plan-refactor-assessment-2026-06-12.md](plan-refactor-assessment-2026-06-12.md) (June refactor) first — file splits, facade layout, and `configure-*` module boundaries should be stable before changing CI tiers, Cursor rules, and doc maps.

**Context:** Assessment against [OpenAI harness engineering](https://openai.com/index/harness-engineering/) (see current notes in [docs/harness-engineering.md](../../docs/harness-engineering.md) — to be relocated; see Phase 4).

**Safety:** [docs/SAFETY.md](../../docs/SAFETY.md) invariants are non-negotiable. Harness work must not weaken per-day caps, popup lifetime ceilings, or escape hatches.

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
3. **Agent rule hygiene** — Fewer irrelevant always-on Cursor rules; one Bash/project conventions rule.
4. **Developer doc clarity** — Canonical vs archive map; harness changelog; reduce drift between `dev-docs/` assessments and live CI.
5. **Actionable errors** — Configure/runtime validation messages name the invariant and point to user safety docs.
6. **Pre-refactor entropy items** — File-size guardrail, optional pre-push hook, PR template — without duplicating refactor work on large `configure-*` files.

## Non-goals

- Copying OpenAI’s agent-only codebase or per-worktree app boot patterns (already excluded in harness notes).
- Moving user-facing safety rules out of `docs/SAFETY.md`.
- Rewriting the 71-test suite in one pass.
- Blocking this plan on Linux GUI/`expect` CI (Tier-B / scheduled only).

---

## Phase 0 — Prerequisite gate (refactor complete)

**Blocked until** [plan-refactor-assessment-2026-06-12.md](plan-refactor-assessment-2026-06-12.md) exit criteria are met (at minimum Phases 0–4 and configure display/UI splits that change `lib/` layout).

- [ ] Refactor plan marked complete in [TO_DO.md](../TO_DO.md) (or moved to [completed-plans/](../completed-plans/)).
- [ ] `./scripts/run-security-scan.sh --ci --with-tests` passes on macOS dev host.
- [ ] Record post-refactor line counts for former hotspots (`configure-display.sh`, `configure-ui.sh`, `show_warning`) in this plan (append metrics table).

**Exit criteria:** No open Phase 0–2 items on the June refactor plan that would invalidate paths referenced below.

---

## Phase 1 — Test tier manifest

**Problem:** Tier-A is implicit in `scripts/run-security-scan.sh`; ~5 of 71 test scripts run in CI; agents lack a single “must pass” list.

### Tasks

- [ ] Add `tests/tiers.yaml` (or `dev-docs/testing-assessments/test-tiers.md` + machine-readable YAML) defining:
  - **Tier-A** — Fast, headless, no live `HOME` config; required on every PR (daily caps, partial lock, popup-safety unit, time-picker minutes, platform-darwin, etc.).
  - **Tier-B** — Temp-`HOME` configure/`expect` subsets; optional PR, recommended pre-release.
  - **Tier-C** — Manual / GUI / SteamOS / multi-distro (document only).
- [ ] Add `scripts/run-tests.sh --tier a|b|c` that reads the manifest (wrapper; does not replace individual test scripts).
- [ ] Refactor `run-security-scan.sh --with-tests` to invoke Tier-A via `run-tests.sh` (single source of truth).
- [ ] Document in `tests/README.md` and `dev-docs/development/testing.md` (create under `dev-docs/` if `docs/development/testing.md` is relocated in Phase 4).

### Exit criteria

- [ ] `scripts/run-tests.sh --tier a` and `run-security-scan.sh --ci --with-tests` run the same scripts.
- [ ] Tier list reviewed against [TO_DO.md](../TO_DO.md) Linux popup verification items.

---

## Phase 2 — CI workflow expansion

**Problem:** Single `ubuntu-latest` job; Darwin-specific tests skipped in GitHub Actions.

### Tasks

- [ ] Update `.github/workflows/security.yml` (or split `ci.yml` + `security.yml`):
  - **Job: static-analysis** — Ubuntu: ShellCheck, Gitleaks, Semgrep (`run-security-scan.sh --ci`).
  - **Job: tier-a-tests** — Matrix `ubuntu-latest` + `macos-latest`: `run-tests.sh --tier a` (or `--with-tests`).
- [ ] Optional **scheduled** workflow (weekly): Tier-B subset with `timeout` on `expect` suites; artifacts on failure only.
- [ ] Document required checks in `dev-docs/development/ci.md` (new).
- [ ] Refresh [dev-docs/templates/safety-scan-template.md](../templates/safety-scan-template.md) CI checkboxes to match live workflows.

### Exit criteria

- [ ] PR to `main` runs Tier-A on both Linux and macOS runners.
- [ ] Failed macOS Tier-A blocks merge (once stable).

---

## Phase 3 — Cursor rule hygiene

**Problem:** Many always-on CodeGuard rules (crypto, K8s, Django, etc.) are irrelevant to Bash; they dilute `safety-guardrails` and `harness-engineering`.

### Tasks

- [ ] Audit `.cursor/rules/*.mdc`: list `alwaysApply: true` rules.
- [ ] Set generic CodeGuard packs to `alwaysApply: false` or path-scoped globs (e.g. only if adding Python/TS later).
- [ ] Keep always-on: `safety-guardrails.mdc`, `config-file-edits.mdc`, `harness-engineering.mdc` (update link after Phase 4 relocation).
- [ ] Add `.cursor/rules/project-conventions.mdc` — Bash facades, temp `HOME`, `timeout` + bounded stdin for `configure.sh`, ShellCheck `-S error`, backup-before-modify for `lib/`.
- [ ] Align `.github/copilot-instructions.md` with post-relocation harness doc path.

### Exit criteria

- [ ] ≤6 always-on project rules (safety + harness + config + conventions + any truly global creds/crypto guard if retained).
- [ ] `tests.mdc` remains requestable or always-on per team preference (document choice in `dev-docs/development/agent-setup.md`).

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
| `docs/development/ci.md` | (new in Phase 2) |
| `docs/architecture/map.md` | `dev-docs/architecture/map.md` |
| `docs/architecture/platforms.md` | `dev-docs/architecture/platforms.md` |

### Keep in `docs/` (end-user / safety)

| File | Reason |
|------|--------|
| `docs/SAFETY.md` | User safety contract |
| `docs/index.md` | User-oriented index (trim agent tables; link to `dev-docs/` for developers) |
| `docs/core-beliefs.md` | Short principles; or merge user-facing bullets into SAFETY + link dev detail |
| `docs/safety-linux-macos-analysis.md` | Safety deep-dive (user + reviewer audience) |

### Tasks

- [ ] Create `dev-docs/canonical-vs-archive.md` — what agents read vs historical `*-assessments/`, `safety-scans/`, `completed-plans/`.
- [ ] Add `dev-docs/harness-changelog.md` — dated harness fixes (doc/test/rule/CI), not product CHANGELOG.
- [ ] Add enhancement → module index to `dev-docs/architecture/map.md` (per [safety-linux-macos-analysis.md](../../docs/safety-linux-macos-analysis.md) follow-up #6).
- [ ] Move files per table; leave stub redirects in `docs/` for one release cycle (`Moved to dev-docs/...`) if external links exist.
- [ ] Update `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/harness-engineering.mdc`, `README.md` links.

### Exit criteria

- [ ] `docs/index.md` reads as end-user index; developer index at `dev-docs/README.md`.
- [ ] No broken links from root agent entry points.

---

## Phase 5 — Doc drift and template hygiene

### Tasks

- [ ] Add `scripts/check-doc-drift.sh` (lightweight):
  - Grep for known-stale phrases (old weekly-cap wording, obsolete enhancement-only paths).
  - Optional: `markdown-link-check` on `docs/`, `dev-docs/README.md`, `AGENTS.md` in CI (warn-only first).
- [ ] Sync safety-scan template checkboxes with Phase 2 CI.
- [ ] One-pass alignment: user `user-docs/CONFIGURATION.md`, `dev-docs/TECHNICAL_DETAILS.md` thresholds with `docs/SAFETY.md` (16 h/day) — file issues for any remaining drift.

### Exit criteria

- [ ] `check-doc-drift.sh` runs in CI (warn or error per team choice).
- [ ] Harness changelog has ≥1 entry per completed phase of this plan.

---

## Phase 6 — Actionable validation messages

**Problem:** Mechanical architecture includes errors that teach fixes; safety prose is strong but configure/runtime errors rarely cite invariants.

### Tasks

- [ ] Define stable invariant ids (e.g. `CAP-RESTRICTION-DAY`, `CAP-CONFIGURE-BLOCK-DAY`, `POPUP-WATCHDOG`) in `dev-docs/development/invariants.md`.
- [ ] Update `lib/configure-validation.sh` / `lib/daily-caps.sh` user-facing messages: invariant id + one line + link to `docs/SAFETY.md` anchor.
- [ ] Mirror ids in Semgrep or a small `tests/test-invariant-messages.sh` so messages do not rot.

### Exit criteria

- [ ] Every hard-block save path cites an invariant id and SAFETY link.
- [ ] No new bypass of configure-time hard block.

---

## Phase 7 — Safety harness parity (developer verification)

**Coordinate with** [TO_DO.md](../TO_DO.md) “Linux popup watchdog (verify on Linux build)” — do not duplicate; extend Tier-A manifest.

### Tasks

- [ ] Ensure `tests/test-popup-safety-linux.sh` is Tier-A on Linux runners (not alias-only in docs).
- [ ] Evaluate `validate_config_safety()` scope for configure/uninstall lock hours ([safety-linux-macos-analysis.md](../../docs/safety-linux-macos-analysis.md) §7.5) — implement or document explicit deferral.
- [ ] After Linux host verification, update `docs/safety-linux-macos-analysis.md` §5.1 only (user/reviewer doc).

### Exit criteria

- [ ] Tier-A green on Ubuntu for Linux popup-safety unit tests.
- [ ] Open items in TO_DO Linux verification checklist updated.

---

## Phase 8 — Contributor and git hygiene

### Tasks

- [ ] Add `dev-docs/CONTRIBUTING.md` (or root `CONTRIBUTING.md` linking dev-docs): clone → `./scripts/install-git-hooks.sh` → read `AGENTS.md` → `run-tests.sh --tier a`.
- [ ] Add `.github/pull_request_template.md` with `docs/SAFETY.md` review checklist (popup/scheduler/config changes).
- [ ] Optional: `scripts/install-git-hooks.sh` offers **pre-push** running `run-tests.sh --tier a` (opt-in, documented).
- [ ] Resolve `.cursor/hooks/state/continual-learning.json` — wire into documented agent workflow or remove if unused.
- [ ] Add `scripts/check-file-sizes.sh` — warn on `lib/*.sh` > 1000 lines (non-blocking; complements refactor).

### Exit criteria

- [ ] New contributor path documented in `dev-docs/README.md`.
- [ ] PR template used on next harness PR.

---

## Suggested execution order

```text
Phase 0 (refactor done)
  → Phase 1 (tiers) → Phase 2 (CI)
  → Phase 3 (rules) ∥ Phase 4 (doc rehome)  [can overlap carefully]
  → Phase 5 (drift) → Phase 6 (messages)
  → Phase 7 (Linux parity) ∥ Phase 8 (contributor)
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
- [plan-refactor-assessment-2026-06-12.md](plan-refactor-assessment-2026-06-12.md) — **do first**
- [refactor-assessment-2026-06-12-001417.md](../refactor-assessments/refactor-assessment-2026-06-12-001417.md)
- [docs/safety-linux-macos-analysis.md](../../docs/safety-linux-macos-analysis.md)

**Last updated:** 2026-06-12
