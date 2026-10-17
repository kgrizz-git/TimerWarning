# Plan: Public Repository Preparation (`TimerWarning` — License, README, Repo/Doc Cleanup, Commit History Rewrite, and New Repo)

**Date:** 2026-10-16  
**Branch:** `chore/public-repo-prep`  
**Target New Repository:** `kgrizz-git/TimerWarning` (created `--private` initially)  
**Status:** Not started. Phases 1–4 below (license, PayPal removal, doc/stub cleanup, history rewrite, new repo) are still open. This branch also contains the experimental gamescope overlay, which is separate from this plan. Tracked `backups/*` snapshots were removed; do not treat that as Phases 1–3 being complete.  
**Safety Reference:** [docs/SAFETY.md](../../docs/SAFETY.md) (no runtime/safety behavior changes)

---

## Locked-In Decisions

1. **New Repository Name (`TimerWarning`):**
   - Verified that `kgrizz-git/TimerWarning` is available on GitHub.
   - We will create `kgrizz-git/TimerWarning` as a **private** repository first and push only the cleaned, history-rewritten `main` branch to it (leaving your existing `LinuxTimerWarning` repo untouched as a private backup until you no longer need it).
   - Update clone URLs and repo references (`https://github.com/kgrizz-git/TimerWarning.git`, `cd TimerWarning`) in `README.md`, `GETTING_STARTED.md`, `user-docs/MACOS.md`, `dev-docs/CONTRIBUTING.md`, `CLAUDE.md`, `.github/copilot-instructions.md`, and `.cursor/rules/project-conventions.mdc`.
2. **Clear Platform & SteamOS Gaming Mode Messaging:**
   - **Supported OSes:** Explicitly state in `README.md` and `GETTING_STARTED.md` that **TimerWarning supports Linux and macOS** (and is **not** designed for or supported on Windows).
   - **SteamOS Gaming Mode:** Update `README.md`, `GETTING_STARTED.md`, `user-docs/USER_GUIDE.md`, and `dev-docs/STEAMOS_GAMING_MODE.md` to state clearly that **SteamOS Desktop Mode is supported**, whereas **SteamOS Gaming Mode (`gamescope`) does not currently work / is unsupported** (instead of the old "partially compatible" wording).
3. **PayPal Links (`FMVBCJ2CT7L7S`):**
   - Remove the PayPal donation links from all 3 files (`README.md`, `GETTING_STARTED.md`, and `lib/install-linux.sh`), archive/remove the PayPal todo references, and scrub `FMVBCJ2CT7L7S` from historical commit blobs during the Phase 4 rewrite.
4. **Git Config Identity:**
   - Confirmed — both `--global` and `--local` git config are set to `kgrizz-git <216068303+kgrizz-git@users.noreply.github.com>`.

---

## Phase 1: Add a License Allowing Not-for-Profit Usage (`CC BY-NC-SA 4.0`)

1. **Create [`LICENSE`](../../LICENSE) at repository root:**
   - Use **Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (`CC BY-NC-SA 4.0`)** (or `PolyForm Noncommercial 1.0.0` if preferred), with copyright line:
     `Copyright (c) 2026 kgrizz-git`
   - Include a clear summary header at the top of `LICENSE` and under `## License` in `README.md`:
     - Free to use, modify, and share for **personal, educational, academic research, charitable, and not-for-profit purposes** with attribution and under the same license.
     - Commercial or for-profit usage is prohibited without separate permission from the author.
     - Software is provided `"AS IS"`, without warranty of any kind.
2. **Update `## License` in [`README.md`](../../README.md#L346-L349) and [`CONTRIBUTING.md`](../../CONTRIBUTING.md) / [`dev-docs/CONTRIBUTING.md`](../../dev-docs/CONTRIBUTING.md):**
   - Replace `[TO BE ADDED]` in `README.md` with the license summary and link to [`LICENSE`](../../LICENSE).
   - Add an `Inbound = Outbound` note in `CONTRIBUTING.md` / `dev-docs/CONTRIBUTING.md` stating that contributions are licensed under the repository's `LICENSE`.

---

## Phase 2: Touch Up `README.md`, `GETTING_STARTED.md`, `user-docs/`, & `lib/install-linux.sh`

### 2.1 Remove PayPal Links (All 3 Active Sites)
1. **[`README.md`](../../README.md#L58-L65):** Remove `## Support Development` section with PayPal `FMVBCJ2CT7L7S` link.
2. **[`GETTING_STARTED.md`](../../GETTING_STARTED.md#L354-L361):** Remove `## Support Development` section with PayPal `FMVBCJ2CT7L7S` link.
3. **[`lib/install-linux.sh`](../../lib/install-linux.sh#L645-L650):** Remove the post-install terminal PayPal donation message from `install_print_summary()`.

### 2.2 Platform Clarity, SteamOS Gaming Mode, & Feature Updates
1. **Title & Platform Scope (`README.md` & `GETTING_STARTED.md`):**
   - Title: `# TimerWarning (Sleep Warning System for Linux & macOS)`
   - Explicitly note: **Works on Linux (`systemd`) and macOS (`LaunchAgent`). Windows is not supported.**
   - Update clone URLs from `LinuxTimerWarning` to `TimerWarning`.
2. **Honest SteamOS Gaming Mode Status (`README.md`, `GETTING_STARTED.md`, `user-docs/USER_GUIDE.md`, `dev-docs/STEAMOS_GAMING_MODE.md`):**
   - State clearly under `Disclaimer`, `Supported Systems`, and `USER_GUIDE.md`:
     - **SteamOS Desktop Mode:** Supported (uses standard KDE Plasma desktop environment).
     - **SteamOS Gaming Mode:** **Not supported / does not currently work** (Gaming Mode's isolated `gamescope` compositor prevents standard desktop dialog tools from appearing over the Gaming Mode UI).
3. **Modernize Feature & Configuration Docs (`README.md` & `GETTING_STARTED.md`):**
   - Update `## Features` to reflect Linux & macOS support, configurable pause durations (`1, 2, 3, 5, 10, 15` minutes) and cooldowns (`6, 8, 12, 24` hours), **15-minute `HH:MM` schedule resolution**, and mechanical safety guardrails (**16h/day per-category cap**, **finite popup watchdog**, and **tighten-only partial configure mode during lock hours**).
   - Add `HH:MM` examples (e.g., `22:30-06:15`) alongside integer-hour examples in `## Configuration`.
   - Include macOS equivalents (`launchctl bootout gui/$(id -u)/com.sleep-warning`, `~/.zshrc`, [`user-docs/MACOS.md`](../../user-docs/MACOS.md)) alongside Linux `systemctl` commands in `Prerequisites`, `Installation`, `Manual Control`, `Uninstallation`, `Requirements`, and `Troubleshooting`.

---

## Phase 3: Clean Up Docs & Repository Structure

### 3.1 Root Directory & Redirect Stub Cleanup
1. **Delete [`GENERALIZATION_SUMMARY.txt`](../../GENERALIZATION_SUMMARY.txt) from repo root.**
2. **Delete all 7 tracked `backups/*` files.**
3. **Remove the 13 expired `# Moved` redirect stubs under `docs/` and `dev-docs/`:**
   - Delete `docs/agent-workflow.md`, `docs/core-beliefs.md`, `docs/harness-engineering.md`, `docs/safety-linux-macos-analysis.md`, `docs/architecture/{map,platforms}.md`, `docs/development/{platform-test-matrix,security-scanning,testing,versioning}.md`, `docs/references/openai-harness-engineering.md`, `docs/superpowers/plans/2026-06-14-bug-review-fixes.md`, and `dev-docs/CONFIGURE_GUI_FLOW.md`.
   - Leaves `docs/` with only `docs/SAFETY.md` and `docs/index.md`. Update `docs/index.md`, `dev-docs/canonical-vs-archive.md`, and `scripts/check-doc-drift.sh`.
4. **Update `.gitignore`:**
   - Add `*.bundle` and `.cursor/plans/` to `.gitignore`, and delete any local untracked `.DS_Store` files.

### 3.2 Archive Completed Plans & Triage `dev-docs/`
1. **Move completed/superseded plans from `dev-docs/plans/` into `dev-docs/completed-plans/`:**
   - `plan-harness-engineering-improvements-2026-06-12.md`
   - `phase-0-verification-2026-06-12.md`
   - `plan-real-bugs-fix-2026-05-24.md`
   - `plan-refactor-assessment-2026-06-12.md`
   - `refactor-plan-high-priority-2026-02-05.md`
   - `plan-safety-scan-fixes-2026-05-30.md`
   - `plan-configurable-pause-interval.md`
   - `plan-status-restricted-hours-display-16b.md`
   - `plan-popup-percentage-size-labels.md`
   - `plan-extend-24-7-prevention-to-additional-hours.md`
   - `plan-additional-hours-no-restrictions.md`
2. **Move root `dev-docs/` bug-fix docs & `.cursor/plans/`:**
   - `dev-docs/weekday-gui-bug-fix-plan.md` → `dev-docs/completed-plans/`
   - `dev-docs/weekday-gui-bug-assessment.md` → `dev-docs/code-assessments/`
   - Move the 8 completed `.cursor/plans/*.plan.md` files → `dev-docs/completed-plans/`.
3. **Update references & scripts:**
   - Update relative links in `AGENTS.md`, `docs/SAFETY.md`, `dev-docs/README.md`, and `dev-docs/TO_DO.md`.
   - Tighten `scripts/check-stale-plans.sh` regex so markdown-bolded `**Status:** **Complete**` and `**Status:** **fully implemented**` are detected automatically.
   - Run `./scripts/prune-dev-docs-archive.sh --apply` (prunes `safety-scan-2026-05-29-003308.md` while keeping `safety-scan-2026-05-30-011454.md`).

---

## Phase 4: Rewrite History & Push to New Private `kgrizz-git/TimerWarning` Repo

1. **Merge `chore/public-repo-prep` into `main`** once Phases 1–3 pass all verification gates (and move this plan `plan-public-repo-prep-2026-10-16.md` into `dev-docs/completed-plans/`).
2. **Create a safety backup bundle outside the repo:**
   ```bash
   git bundle create /Users/kgrizz-git/MyCode/LinuxTimerWarning-pre-rewrite.bundle --all
   ```
3. **Rewrite commit author/committer metadata AND scrub `FMVBCJ2CT7L7S` across all history:**
   - Map `kgrizz-git <216068303+kgrizz-git@users.noreply.github.com>` and `kgrizz-git <216068303+kgrizz-git@users.noreply.github.com>` → `kgrizz-git <216068303+kgrizz-git@users.noreply.github.com>`.
   - Scrub `FMVBCJ2CT7L7S` from all historical file blobs across every revision.
4. **Verify 100% clean history & blobs:**
   ```bash
   git log main --format="%an <%ae> | %cn <%ce>" | sort -u
   git log main --grep="grizzard" -i
   git rev-list main | xargs git grep -i -E "kevingrizzard|kevin\.grizzard|FMVBCJ2CT7L7S" || true
   ```
5. **Create new private GitHub repository `kgrizz-git/TimerWarning` and push clean `main`:**
   ```bash
   gh repo create kgrizz-git/TimerWarning --private --description "Configurable late-night computer usage warning & lockout system for Linux (systemd) and macOS (LaunchAgent)"
   git remote add timerwarning https://github.com/kgrizz-git/TimerWarning.git
   git push -u timerwarning main
   ```

---

## Verification Gates

1. `./scripts/check-doc-drift.sh --strict` — exits `0`.
2. `./scripts/check-stale-plans.sh --strict` — exits `0`.
3. `./scripts/run-security-scan.sh --ci` — ShellCheck, Gitleaks, and Semgrep pass with `0` findings.
4. `CI_HEADLESS=1 ./scripts/run-tests.sh --tier a` — Tier-A test suite passes.
5. Zero occurrences of `kgrizz-git`, `216068303+kgrizz-git@users.noreply.github.com`, or `FMVBCJ2CT7L7S` in commit headers, commit messages, or historical file blobs on `main`.
