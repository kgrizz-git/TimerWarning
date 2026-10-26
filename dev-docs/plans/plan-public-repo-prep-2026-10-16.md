# Plan: Prepare TimerWarning for public release

**Created:** 2026-10-16

**Revised:** 2026-10-25

**Status:** Phases 1–4 applied. `kgrizz-git/TimerWarning` is public. On 2026-10-25 its CI was green, the full-history Gitleaks scan was clean, and the tracked file list matched the source. `main` still has no branch protection (the protection API returns 404). Phase 5 still includes setting that protection and archiving this plan.

**Working branch:** `chore/public-repo-prep-phase-1` for phases 1–4, based on `main` at `86cfc7a`. That name is historical; it is not the branch for later icon work.

**Destination:** `kgrizz-git/TimerWarning`. Created private, now public.

**Safety reference:** [docs/SAFETY.md](../../docs/SAFETY.md).

## Current state and scope

PR #7 merged on 2026-10-21. It delivered experimental SteamOS Gaming Mode support,
safety fixes, and reviews; its old branch name did not mean publication preparation
was finished. The existing `kgrizz-git/LinuxTimerWarning` repository is still private.

| Work | Verified state on 2026-10-21 |
|------|-----------------------------|
| Safety and overlay implementation | Merged through `ed0e8be`; merge commit `86cfc7a` |
| Automated verification for PR #7 | Ubuntu/macOS Tier-A and Ubuntu static analysis passed; latest local Tier-A: 25 scripts, 3 platform/GUI skips |
| Deck hardware evidence | Popup visibility/min-display on Oct 19; click access and Enter exclusivity passed Oct 20, recorded in the [overlay plan](../completed-plans/plan-gamescope-overlay-click-through-2026-10-19.md#manual-verification-checklist-on-deck) |
| Tracked `backups/` files | Already removed; no repeat deletion needed |
| License | Apache License 2.0 with the Commons Clause, applied 2026-10-24 in root `LICENSE`. Source-available, not OSI open source |
| Donation removal | PayPal links remain in README, GETTING_STARTED, and the Linux installer |
| Branding and docs | Old clone URLs, root summary, redirects, and completed-plan backlog remain |
| History sanitization / destination | Sanitized history is this repository. Source `LinuxTimerWarning` `06dbdbc` was the unsanitized base. PayPal links remain. |

This work prepares licensing, documentation, repository contents, and a sanitized
publication copy. Runtime enhancements and broad new hardware certification are
separate work. Preserve the three safety invariants and the verified Deck geometry.

## Decisions to preserve

- Public-facing name: **TimerWarning**. Support Linux with systemd and macOS with
  a user LaunchAgent; Windows is unsupported.
- Keep the existing repository private as the development/history backup. Perform
  history rewriting only in a disposable, separate export clone.
- Create the destination **private**, publish only the reviewed export `main`,
  verify its CI/settings, and treat making it public as a separate final step.
- PayPal donation links stay until the owner reopens removal (deferred 2026-10-24).
  Do not add donation verification or GitHub Sponsors during this preparation.
- Public author identity for the owner's commits:
  `kgrizz-git <216068303+kgrizz-git@users.noreply.github.com>`. Recheck local commit
  identity before new commits; do not assume global Git configuration is unchanged.
- License, chosen by the owner on 2026-10-24: **Apache License 2.0** with the
  **Commons Clause License Condition v1.0**. Personal use, modification,
  redistribution, and internal corporate use stay allowed. Selling the software,
  as the Commons Clause defines Sell, does not. CC BY-NC-SA 4.0 and PolyForm
  Noncommercial 1.0.0 were considered and not selected. The combination is
  source-available, not OSI open source. Do not replace it with a permissive
  license or describe those three licenses as the same terms.

## Phase 0 — Branch housekeeping and plan review

- [x] Confirm PR #7 merged and current checkout is based on merged `main`.
- [x] Create `chore/public-repo-prep-phase-1` for this revision and the next phase.
- [x] Delete fully merged remote branches: `WIP`, `WIP-mac`, and
  `copilot/copy-templates-generalize`.
- [x] Delete merged local branches: `WIP`, `WIP-mac`, `chore/public-repo-prep`, and
  `cursor/critical-bug-investigation-6462` (the last two remotes were already gone).
- [x] Inspect `cursor/critical-bug-investigation-a628`, closed PR #2, commit
  `cea8362`. Its overnight-carry and pause-watchdog fixes have newer equivalents
  in `main`; its backup snapshots are not material to merge. The original
  overnight regression passes against current libraries, and the current Linux
  watchdog-cleanup regression passes with stub dialogs and isolated scratch/HOME.
  Tests were bounded; no live service, GUI, or installed configuration was used.
- [x] Delete the superseded remote Cursor branch after explicit owner approval
  on 2026-10-21. Its commit was not merged, but the fixes were independently
  verified on `main`; no local branch existed. Do not cherry-pick the old patch
  over newer safety code.

## Phase 1 — License and public contribution terms

Applied 2026-10-24 on `chore/public-repo-prep-phase-1`. No runtime change.

- [x] Owner selected the Apache License 2.0 with the Commons Clause License
  Condition v1.0. CC BY-NC-SA and PolyForm Noncommercial were not selected.
  Creative Commons recommends a software license for code; the Commons Clause is
  a software condition on Apache 2.0.
- [x] Third-party audit: no vendored source, no existing copyright headers, and
  no separately licensed assets in the tree. External programs the scripts call
  keep their own licenses. Nothing of theirs was relicensed.
- [x] Root `LICENSE` has `Copyright (c) 2026 kgrizz-git`, the Commons Clause with
  Software, License, and Licensor filled in, and the official Apache 2.0 text
  unmodified, including its appendix. README prose stays outside that text.
- [x] README placeholder replaced with a short summary and a link to `LICENSE`.
  The summary uses the Commons Clause definition of Sell and does not add a
  broader ban.
- [x] Root and developer contribution guides require contributions under the
  same combined terms. [LICENSE_OPTIONS.md](../info/LICENSE_OPTIONS.md) records
  the decision and no longer says noncommercial licenses blanket-permit internal
  business use.
- [x] Docs call the project source-available, not OSI open source.

**Acceptance:** met for this slice. GitHub license settings for the destination
repository remain in Phase 5. Per-file copyright headers were not added.

## Phase 2 — Public-facing docs, branding, and donation removal

- [ ] Remove donation sections from `README.md` and `GETTING_STARTED.md`, and the
  post-install donation message from `lib/install-linux.sh`. **Deferred by the
  owner on 2026-10-24.** Leave the existing PayPal links in place for now. Do not
  add donation verification or GitHub Sponsors as part of this preparation.
- [x] Use `TimerWarning (Sleep Warning System for Linux & macOS)` and the
  `kgrizz-git/TimerWarning` clone URL/directory in installation examples.
  Done in `f7a22a9`, the first commit on this repository. Installed
  `sleep-warning*` executables, config paths, and services keep those names.
- [x] State **Desktop Mode supported; Gaming Mode experimental, opt-in**. Cite
  the Oct 19–20 Deck results accurately. Remove both the old “does not work” claim
  and unqualified claims that no hardware test has happened. Keep remaining
  manual checks visible: pause-enabled buttons/notice, countdown input, touch,
  QAM after closure, forced timeout, and docked/undocked coverage as recorded.
  Updated 2026-10-24 in README, GETTING_STARTED, user docs, and the SteamOS
  summary. Names and clone URLs were left unchanged.
- [x] Document current features: pause durations/cooldowns, 15-minute wizard
  schedule resolution and `HH:MM` examples, daily per-category caps, watchdog,
  and tighten-only configuration. Do not promise arbitrary minute entry where
  wizard inputs are restricted to quarter-hour values. Text mode and hand-edited
  config still accept any valid minute. Corrected the pause docs that said the
  limit resets at midnight; the cooldown is 6, 8, 12, or 24 hours from the last
  pause.
- [x] Keep emergency commands accurate: Linux stop/disable; macOS `bootout` for
  immediate stop plus `disable` for persistence, with explicit re-enable steps.
  Updated in GETTING_STARTED, the user guide, and CONFIGURATION. `user-docs/MACOS.md`
  already had both macOS steps.
- [ ] Check install/status/help output for the public name, and for private
  material other than the PayPal link the owner is keeping. The name itself
  landed in `f7a22a9`. The 2026-10-24 scan of install, status, and help strings
  found the PayPal business id and no personal email or home-directory path.

**Acceptance:** PayPal links remain until the owner reopens that item. Branding
and platform claims are consistent, recovery instructions are current, and
installed identifiers and behavior are unchanged.

## Phase 3 — Repository and documentation cleanup

Done 2026-10-25 on `chore/public-repo-prep-phase-1`. No runtime change.

1. Remove `GENERALIZATION_SUMMARY.txt` after preserving anything still useful.
   Done 2026-10-24. The generalized template directory is not in this repo.
   The record is [note-template-generalization-summary.md](../completed-plans/note-template-generalization-summary.md).
2. Inventory redirect stubs under `docs/` and `dev-docs/CONFIGURE_GUI_FLOW.md`;
   update inbound links before removing obsolete stubs. Keep the user/developer
   documentation boundary and update `docs/index.md`, canonical-doc guidance,
   and `scripts/check-doc-drift.sh` together. Done 2026-10-25: all `Moved`
   stubs under `docs/` (architecture, development, harness, agent-workflow,
   core-beliefs, safety analysis, references, superpowers) and
   `dev-docs/CONFIGURE_GUI_FLOW.md` removed. Live docs already pointed at
   `dev-docs/`; historical Markdown links (CHANGELOG, dated assessments/scans) now also
   resolve to their canonical destinations. The live safety-scan plan pointer
   was retargeted to `dev-docs/`. `docs/index.md`, `canonical-vs-archive.md`, and the drift
   script's exclusion list updated together.
3. Add `*.bundle` and local `.cursor/plans/` to `.gitignore` as appropriate.
   `*.bundle` and `.cursor/plans/` were added on 2026-10-24. Eight plans were
   still tracked; ignoring the path did not untrack them. Their frontmatter
   todos are complete. Done 2026-10-25: all eight moved to
   `dev-docs/completed-plans/` after retargeting inbound links (the dev-docs
   pause plan's sync notes; the archived May refactor plan's pointer now
   resolves via git history). Verified against code: the conditional osascript
   `activate` throttle the performance plan body still calls unimplemented is
   shipped (`_cd_darwin_should_osascript_activate`,
   `lib/configure-dialogs-darwin.sh`); only the manual z-order QA remains,
   kept visible as a [TO_DO smoke item](../TO_DO.md#smoke-tests).
4. Audit completed-plan candidates individually, including harness engineering,
   refactor, safety-scan, pause, status-display, and popup-size plans. Move only
   completed/superseded work to `dev-docs/completed-plans/`; keep unresolved
   requirements active. In particular, the additional-hours-on-unrestricted-days
   proposal is still listed as open and was not archived. Done 2026-10-25:
   archived the percentage-size, phase-0, Feb refactor (superseded), pause,
   harness, real-bugs, June refactor, gamescope click-through, extend-24/7,
   and 16b status-display plans with archive banners; kept additional-hours,
   popup-frequency (needs review), safety-scan (unimplemented integration
   test), SteamOS overlay (partial verification), and this plan active.
   Repaired relative links from AGENTS, SAFETY, developer README, TO_DO,
   REMAINING_WORK_SUMMARY, STEAMOS_GAMING_MODE, enhancement-22, and the
   platform test matrix.
5. Review the old weekday-GUI notes and tracked `.cursor/plans/` files before
   moving them to completed plans or assessments. Repair relative links and
   links from AGENTS, SAFETY, developer README, and TO_DO. Done 2026-10-25:
   review correction: the [weekday fix plan](weekday-gui-bug-fix-plan.md) remains active
   for Phase 2 systematic dialog hardening; only the targeted fixes shipped.
   Its assessment stays in place because
   `lib/configure-dialogs-darwin.sh` references it.
6. Improve stale-plan detection for bolded completion statuses, with focused
   tests if changing the script. Preview retention tools before any `--apply`;
   use current age/reference rules, not the old plan's hardcoded deletion list.
   Evaluated 2026-10-25: after the archiving above, no remaining active plan
   carries a completable bolded status the script misses (remaining matches
   are genuinely open work), so the script is unchanged. No test added — no
   behavior change to pin. Retention scripts previewed dry-run only; no
   archives deleted.
7. Retain safety guidance, user instructions, contributor guidance, and tests.
   Public release does not require implementing the entire feature backlog.
   Kept: SAFETY, user docs, CONTRIBUTING, tests, and the open backlog untouched.

**Acceptance:** strict doc/stale-plan checks pass, archived work is traceable via
banners, unresolved work (additional-hours proposal, popup-frequency review,
safety-scan integration test, weekday dialog hardening, SteamOS verification, smoke list) remains visible,
root/docs are coherent, no safety-doc loss.

## Phase 4 — Sanitize history in a separate publication clone

Start only after Phases 1–3 are reviewed, committed, tested, and merged through a
PR into source `main`. Keep this plan active until publication is finished.

1. Record the exact source `main` SHA and inventory prerequisites/PRs. Verify
   every intended implementation commit is included; no unsubmitted base slices.
2. Create and verify a complete private backup bundle outside the working tree.
   It contains unsanitized history: never upload it or include it in the export.
3. Create a separate export clone of the reviewed `main`. Do not rewrite source
   `main`, force-push the existing remote, or export old branches, tags, stashes,
   remote-tracking refs, PR refs, backup refs, or local agent state.
4. Build a private sanitization manifest outside the export: owner identity
   aliases, personal email/name variants, home-directory paths, donation ID,
   private endpoints, and any discovered secrets. Keep actual match results out
   of public CI logs. Public handle/no-reply identity is intentionally retained.
5. Rewrite owner author/committer aliases, matching co-author trailers and other
   message content, and sensitive file content/paths across exported history.
   Preserve legitimate third-party attribution and notices. Exclude historic
   backups/local artifacts where required. Record old-to-new SHA mapping privately.
6. Verify **all objects reachable from the exact export refs**, not just HEAD:
   commit metadata/messages, tree paths and blobs, binary artifacts, and any tags
   deliberately added later. A clean current tree or Gitleaks pass alone does not
   prove personal-data removal. `grep ... || true` is not a passing privacy gate:
   distinguish forbidden matches, allowed matches, and scan/tool errors.
7. Run `git fsck`, review the rewritten tip against the approved source tree
   (only intended sanitization differences), then rerun doc, test, and security
   gates in the export clone. Keep all rewrite recipes/manifests/reports that
   contain private originals outside the publication repository.

**Acceptance:** verified backup, isolated rewritten `main`, no unexplained tree
changes or forbidden reachable material, reproducible private audit record.

## Phase 5 — Private staging, then public release

1. Recheck destination name/access at execution time; the Oct 16 availability
   check is historical. Create `kgrizz-git/TimerWarning` **private** if absent;
   inspect rather than overwrite any existing repository.
2. Push only the sanitized `main` ref with a normal push to the new destination;
   never `--mirror`, `--all`, an unsanitized tag, or a hook/protection bypass.
3. Configure default branch, required checks/PR protection, Actions permissions,
   and desired repository metadata. Review integrations and artifacts for old
   private links/data; do not import old private issues, logs, or review threads.
4. Verify the destination's Ubuntu/macOS CI, documentation/clone links, license,
   and install instructions from a fresh checkout. Use temp HOME, bounded tests,
   and no installed-config or live-service changes for automation.
5. Present the exact destination, sanitized SHA, scan/test evidence, and visibility
   change for owner approval. Make the repository public only after that approval.
   Branch protection cannot be set while the repository is private on the free
   plan (GitHub returns 403), so configure it right after the visibility change.
6. Verify public clone/access and public metadata. Archive this plan under
   `dev-docs/completed-plans/` after final status and any residual work are recorded.
   Keep source `LinuxTimerWarning` private unless separately directed.

## Verification and delivery gates

| Slice | Required evidence |
|-------|-------------------|
| This planning revision | Diff/link review; doc/stale-plan checks with existing failures recorded; no runtime changes |
| Phases 1–3 | `./scripts/check-doc-drift.sh --strict`; `./scripts/check-stale-plans.sh --strict`; license/link/donation/branding checks |
| Shell or entrypoint changes | Targeted regressions, temp-HOME `CI_HEADLESS=1 ./scripts/run-tests.sh --tier a`, and `./scripts/run-security-scan.sh --ci`; normal hooks intact |
| Sanitized export | All preceding checks plus reachable-history privacy scan, `git fsck`, source/export comparison |
| Public release | Private destination CI green, settings reviewed, explicit public-visibility approval, fresh public clone verified |

Follow the operational rules in AGENTS: never unbounded configure menus; timeout,
controlled stdin, and bounded output are all required if a menu test is necessary.
Never run mode-detection tests against real HOME or edit the installed config.

For each slice, report implemented, reviewed, committed, pushed, PR-submitted,
CI-green, and merged states separately. Branch cleanup is not release completion.

**Next action:** Review destination CI and repository settings. Make this
repository public only after a separate owner approval. PayPal removal stays
deferred. Do not rewrite this history again, and do not change the private
source repository's history.
