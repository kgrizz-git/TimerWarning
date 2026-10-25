# Remaining Work Summary

Detailed backlog: testing gaps, master-plan phases, documentation, and “mostly implemented” follow-ups. **Short priority list:** [TO_DO.md](TO_DO.md). **Per-enhancement catalog:** [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md).

---

## Mostly implemented enhancements

Open work is testing, docs, or small gaps — not greenfield implementation.

| # | Remaining work | Spec |
|---|----------------|------|
| 2a | Test configure/manage/uninstall dialogs on all tools (YAD, Zenity, KDialog) | [enhancement-02a](enhancements/enhancement-02a-extend-dialog-tool-priority-to-config-wizard.md) |
| 3 | UI size tests; Wayland/gamescope resolution; multi-monitor | [enhancement-03](enhancements/enhancement-03-enhanced-window-size-options.md) |
| 4 | Manual SteamOS Desktop + Gaming Mode validation | [enhancement-04](enhancements/enhancement-04-systemd-service-environment-detection.md) |
| 9 | Manual sleep/hibernate and popup-queue tests | [enhancement-09](enhancements/enhancement-09-system-sleep-hibernate-detection.md) |
| 16c | GUI multiple ranges — test all dialog tools | [enhancement-16c](enhancements/enhancement-16c-multiple-range-entry-gui.md) |
| 18 | Residual test coverage | [enhancement-18](enhancements/enhancement-18-config-file-locking.md) |
| 20 | Weekday/weekend together for lock hours (match restriction flow) | [enhancement-20](enhancements/enhancement-20-additional-hours-config-locking.md) |
| 22 | Edge-case and integration tests for 24/7 prevention | [enhancement-22](enhancements/enhancement-22-prevent-24-7-restriction-configuration.md) |
| 22a | Validation edge cases (`start_hour == end_hour`, sparse days, IFS) | [enhancement-22a](enhancements/enhancement-22a-fix-validation-edge-cases.md) |
| 24–25 | Cross-tool and cross-environment dialog tests | [#24](enhancements/enhancement-24-unified-dialog-priority-yad-first.md) · [#25](enhancements/enhancement-25-user-selectable-dialog-tool.md) |
| 26 | Phase 1 integration tests; Phase 2 uninstall UI tests | [enhancement-26](enhancements/enhancement-26-prevent-uninstall-during-restricted-hours.md) |
| 27 | Verify PayPal links; Phase 2 after license | [enhancement-27](enhancements/enhancement-27-paypal-donation-links.md) |
| — | 24/7 + additional hours plan — Phase 5 testing (manual integration; smoke items in TO_DO) | [plan-extend-24-7…](completed-plans/plan-extend-24-7-prevention-to-additional-hours.md) |

---

## Master plan phases

From [linux-warning-system-plan.md](plans/master/linux-warning-system-plan.md). Phase checklists: [`plans/phases/`](plans/phases/).

| Phase | Open items |
|-------|------------|
| **3 — Installation** | Distribution testing (Debian/Ubuntu, Fedora/RHEL, Arch/SteamOS, openSUSE, Alpine) |
| **4 — Testing** | Edge cases; install/uninstall on clean systems; **SteamOS Gaming Mode validation** |
| **5 — Documentation** | Contributing / dev setup; licensing; donation verification |

---

## Testing and validation

- [ ] SteamOS Gaming Mode with full-screen games — **partial 2026-10-19:** overlay visible/stays up; **buttons click-through** (see [plan-gamescope-overlay-click-through-2026-10-19.md](completed-plans/plan-gamescope-overlay-click-through-2026-10-19.md) — archived; remaining manual checks are TO_DO smoke items)
- [ ] Edge cases: overnight ranges, invalid config, missing dependencies
- [ ] Multi-distribution install scripts
- [ ] Dialog tools (YAD / Zenity / KDialog) across X11, Wayland, KDE
- [ ] Display detection fallbacks; config validation edge cases
- [ ] Service persistence across Desktop ↔ Gaming mode transitions (Enhancement #4)

See [plan-phase-4-testing.md](plans/phases/plan-phase-4-testing.md). Record runs in [testing-assessments/test-history.md](testing-assessments/test-history.md).

---

## Documentation work

- [ ] Contributing guidelines and development setup
- [x] **Licensing** — Apache License 2.0 with the Commons Clause in root `LICENSE` (2026-10-24). Recorded in [LICENSE_OPTIONS.md](info/LICENSE_OPTIONS.md). GitHub license settings remain for the destination repository.
- [ ] **Donation links** — verify Phase 1; Phase 2 GitHub Sponsors after license
- [ ] **SteamOS locale** — Document Nix (preferred) and manual `locale-gen` paths in user docs. **Do not** run `locale-gen` from `install.sh` (read-only `/usr`, stripped glibc on SteamOS). Optional: detect missing UTF-8 locale and print instructions; set `LANG` in user service when a UTF-8 locale exists.

---

## Code quality (completed)

- [x] Split `lib/configure-input.sh` into modules — [completed plan](completed-plans/plan-split-configure-input.md)
- [x] Shared day-name helpers — [plan-code-quality](plans/phases/plan-code-quality-improvements.md)
- [x] Magic numbers → constants — same plan

Reference: [qi-assessment-2026-01-23](code-assessments/qi-assessment-2026-01-23-003550.md).

---

## Completed enhancements (reference)

Fully done (no tracking here): #2 (via #24), #7, #11, #14, #14b, #15, #16b, pause verification (5 questions / 3 wrong), 24/7 + additional hours validation code.

Details and history: [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md).

---

## Notes

- Enhancement numbers match [FUTURE_ENHANCEMENTS.md](FUTURE_ENHANCEMENTS.md) and `enhancements/enhancement-*.md`.
- Alternative architectures: [`alternatives/`](alternatives/) (not complementary backlog).
- One-off fix write-ups: [`fixes/`](fixes/).

**Last updated:** 2026-05-23 (deduplicated vs FUTURE_ENHANCEMENTS; paths under `plans/`)
