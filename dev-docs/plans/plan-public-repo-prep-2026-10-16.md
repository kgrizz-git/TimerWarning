# Plan: Prepare TimerWarning for public release

**Created:** 2026-10-16

**Revised:** 2026-10-21

**Status:** Planning revised; implementation Phases 1–5 remain open.

**Working branch:** `chore/public-repo-prep-phase-1`, based on `main` at `86cfc7a`.

**Destination:** `kgrizz-git/TimerWarning`, private staging repository first.

**Safety reference:** [docs/SAFETY.md](../../docs/SAFETY.md).

## Current state and scope

PR #7 merged on 2026-10-21. It delivered experimental SteamOS Gaming Mode support,
safety fixes, and reviews; its old branch name did not mean publication preparation
was finished. The existing `kgrizz-git/LinuxTimerWarning` repository is still private.

| Work | Verified state on 2026-10-21 |
|------|-----------------------------|
| Safety and overlay implementation | Merged through `ed0e8be`; merge commit `86cfc7a` |
| Automated verification for PR #7 | Ubuntu/macOS Tier-A and Ubuntu static analysis passed; latest local Tier-A: 25 scripts, 3 platform/GUI skips |
| Deck hardware evidence | Popup visibility/min-display on Oct 19; click access and Enter exclusivity passed Oct 20, recorded in the [overlay plan](plan-gamescope-overlay-click-through-2026-10-19.md#manual-verification-checklist-on-deck) |
| Tracked `backups/` files | Already removed; no repeat deletion needed |
| License | No root `LICENSE`; README still has `[TO BE ADDED]` |
| Donation removal | PayPal links remain in README, GETTING_STARTED, and the Linux installer |
| Branding and docs | Old clone URLs, root summary, redirects, and completed-plan backlog remain |
| History sanitization / destination | Not performed / not created by this plan |

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
- Remove the existing PayPal donation links and historical donation identifier.
- Public author identity for the owner's commits:
  `kgrizz-git <216068303+kgrizz-git@users.noreply.github.com>`. Recheck local commit
  identity before new commits; do not assume global Git configuration is unchanged.
- The intended licensing policy is noncommercial availability with attribution.
  The previous plan proposed **CC BY-NC-SA 4.0**, with **PolyForm Noncommercial
  1.0.0** as an alternative. Do not silently substitute a permissive license or
  assume these two licenses have identical terms.

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
- [ ] Retire the remaining Cursor branch only after a separate deletion decision:
  its commit is not an ancestor of `main`, so it was retained rather than classed
  as a merged branch. Do not cherry-pick the old patch over newer safety code.

## Phase 1 — License and public contribution terms (next implementation slice)

1. Resolve the exact license before adding it. Keep CC BY-NC-SA as the previous
   proposal, but surface its software suitability explicitly: [Creative Commons
   recommends software-specific licenses for code](https://creativecommons.org/faq/#can-i-apply-a-creative-commons-license-to-software).
   A change to PolyForm or another license is an owner decision, not housekeeping.
2. Check third-party material and existing notices; establish what the owner can
   license. Preserve others' notices and attribution. Distinguish any separately
   licensed documentation/assets if applicable.
3. Add the exact official license text to root `LICENSE`, with the intended
   `Copyright (c) 2026 kgrizz-git` notice in the appropriate place. Keep explanatory
   README prose separate from the unmodified license text.
4. Replace README's placeholder with a short accurate summary and license link.
   Do not promise that every educational/nonprofit use is automatically permitted
   or invent a broader prohibition than the selected text. Under the proposed CC
   option, use its [official terms](https://creativecommons.org/licenses/by-nc-sa/4.0/)
   when describing NonCommercial, attribution, and ShareAlike.
5. Update root and developer contribution guides with contribution licensing
   consistent with the selected license. Correct conflicting advice in
   [LICENSE_OPTIONS.md](../info/LICENSE_OPTIONS.md), particularly blanket claims
   that noncommercial licenses permit internal business use.
6. Describe the repository as publicly available/source-available if the chosen
   license restricts commercial use; do not advertise it as OSI open source.

**Acceptance:** exact license selected and applied, no license placeholder,
consistent contribution terms, third-party notices retained, no runtime changes.

## Phase 2 — Public-facing docs, branding, and donation removal

- [ ] Remove donation sections from `README.md` and `GETTING_STARTED.md`, and the
  post-install donation message from `lib/install-linux.sh`. Reconcile the PayPal
  enhancement spec and TO_DO; archive obsolete requests rather than implementing
  donation verification or Sponsors as part of this preparation.
- [ ] Use `TimerWarning (Sleep Warning System for Linux & macOS)` and the planned
  `kgrizz-git/TimerWarning` clone URL/directory in installation examples. Update
  references in README, GETTING_STARTED, user docs, contribution guides,
  `CLAUDE.md`, `.github/copilot-instructions.md`, and Cursor rules as applicable.
  Do not rename installed `sleep-warning*` executables, config paths, or services.
- [ ] State **Desktop Mode supported; Gaming Mode experimental, opt-in**. Cite
  the Oct 19–20 Deck results accurately. Remove both the old “does not work” claim
  and unqualified claims that no hardware test has happened. Keep remaining
  manual checks visible: pause-enabled buttons/notice, countdown input, touch,
  QAM after closure, forced timeout, and docked/undocked coverage as recorded.
- [ ] Document current features: pause durations/cooldowns, 15-minute wizard
  schedule resolution and `HH:MM` examples, daily per-category caps, watchdog,
  and tighten-only configuration. Do not promise arbitrary minute entry where
  wizard inputs are restricted to quarter-hour values.
- [ ] Keep emergency commands accurate: Linux stop/disable; macOS `bootout` for
  immediate stop plus `disable` for persistence, with explicit re-enable steps.
- [ ] Check install/status/help output for stale branding and privacy material.

**Acceptance:** no active donation message, consistent branding and platform
claims, current recovery instructions, unchanged installed identifiers/behavior.

## Phase 3 — Repository and documentation cleanup

1. Remove `GENERALIZATION_SUMMARY.txt` after preserving anything still useful.
2. Inventory redirect stubs under `docs/` and `dev-docs/CONFIGURE_GUI_FLOW.md`;
   update inbound links before removing obsolete stubs. Keep the user/developer
   documentation boundary and update `docs/index.md`, canonical-doc guidance,
   and `scripts/check-doc-drift.sh` together.
3. Add `*.bundle` and local `.cursor/plans/` to `.gitignore` as appropriate.
   Ignoring a path does not untrack it or remove history: inspect tracked files
   first and preserve useful plans in the normal archive. Remove only identified
   repository-local junk; do not sweep unrelated folders or installed config.
4. Audit completed-plan candidates individually, including harness engineering,
   refactor, safety-scan, pause, status-display, and popup-size plans. Move only
   completed/superseded work to `dev-docs/completed-plans/`; keep unresolved
   requirements active. In particular, the additional-hours-on-unrestricted-days
   proposal is still listed as open and must not be archived as implemented.
5. Review the old weekday-GUI notes and tracked `.cursor/plans/` files before
   moving them to completed plans or assessments. Repair relative links and
   links from AGENTS, SAFETY, developer README, and TO_DO.
6. Improve stale-plan detection for bolded completion statuses, with focused
   tests if changing the script. Preview retention tools before any `--apply`;
   use current age/reference rules, not the old plan's hardcoded deletion list.
7. Retain safety guidance, user instructions, contributor guidance, and tests.
   Public release does not require implementing the entire feature backlog.

**Acceptance:** strict doc checks pass, archived work is traceable, unresolved
work remains visible, root/docs are coherent, no accidental safety-doc loss.

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

**Next action:** begin Phase 1 on `chore/public-repo-prep-phase-1`, resolving the
license choice/suitability first. This revision does not install a license,
rewrite history, create the destination, or change repository visibility.
