## Summary

<!-- What changed and why (1–3 sentences). -->

## Test plan

- [ ] `CI_HEADLESS=1 ./scripts/run-tests.sh --tier a`
- [ ] `./scripts/run-security-scan.sh --ci` (if `lib/` or `*.sh` entrypoints changed)
- [ ] Other: <!-- e.g. Tier-B script, manual GUI check -->

## Safety review

Complete when this PR touches **popups**, **schedulers**, **install defaults**, or **config validation**. Full rules: [docs/SAFETY.md](../docs/SAFETY.md).

- [ ] **Per-day 16 h cap** — No calendar day exceeds 16 h merged in any category (restriction, configure-block, uninstall-block). Configure-time hard block unchanged.
- [ ] **Popup lifetime** — Every spawn path has a finite absolute watchdog (`lib/popup-safety.sh` or Linux PID-file equivalent).
- [ ] **Escape hatch** — `launchctl bootout` / `systemctl --user stop` + `sleep-warning-uninstall` still documented and working.
- [ ] **Tests** — Temp `HOME` or fixtures only; no edits to live `~/.config/sleep-warning/` during restricted hours.
- [ ] **HH:MM parity** — Wizard and validator use the same time formats.
- [ ] **CHANGELOG** — `[Unreleased]` updated if user-visible ([dev-docs/development/versioning.md](../dev-docs/development/versioning.md)).

## Harness / docs only

Skip Safety checkboxes above if this PR is docs/tests/CI only. Note harness changes in [dev-docs/harness-changelog.md](../dev-docs/harness-changelog.md) when applicable.
