## Plan: Update warning threshold to 16h/day + fix tests

Date: 2026-01-25

### Goal

Align the “high restriction” warning threshold across **code + docs + tests** to **16 hours/day** (i.e., **6720 minutes/week**) and repair out-of-date tests (including expect scripts) after the modular refactor and config path migration.

### Constraints / Safety

- Do **not** modify the user’s installed config under `~/.config/sleep-warning/` while running tests.
- Prefer running tests under a temporary `HOME` whenever a script writes `${HOME}/.config/...`.
- Do not change tests “to force pass” unless the test is genuinely outdated (refactor/path/prompt drift) or is a non-functional threshold check.

### Implementation checklist

#### A) Code threshold update (16h/day)
- [ ] Update restriction coverage warning threshold constant to **6720 minutes/week**
- [ ] Update user-facing warning text to say “more than 16 hours/day”
- [ ] Ensure safety overrides (disable config locking / configure blocking, popup size restriction) trigger under the new threshold
- [ ] Ensure docs match the new threshold (already partially updated by user)

#### B) Update non-interactive tests that are now outdated
- [ ] Fix `tests/test-configure-text-mode.sh` (no longer grepping monolithic `configure.sh`; use module locations / updated menu options)
- [ ] Fix `tests/test-grid-functions.sh` (stop extracting functions from `configure.sh`; source `lib/configure-time.sh`/`lib/configure-core.sh`)
- [ ] Update “size threshold” tests so they warn rather than fail for known large files / modest main-script size drift
  - `tests/test-configure-modular.sh`
  - `tests/test-modular-refactor.sh`

#### C) Fix expect scripts (but do not run them yet)
- [ ] Update expect-based scripts to the new config path and any prompt/menu output drift
- [ ] Specifically fix:
  - `tests/test-with-expect.sh`
  - `tests/test-configure-comprehensive.sh` / `tests/test-configure-comprehensive.exp`
  - `tests/test-configure-expect.exp`

#### D) Verification (non-interactive only for now)
- [ ] Re-run updated non-interactive tests (with temp `HOME` when needed)
- [ ] Re-run the Enhancement #18 harness `tests/test-config-locking.sh`

