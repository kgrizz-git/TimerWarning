# Developer documentation (`dev-docs/`)

Backlog, plans, enhancement specs, and audit history for the Sleep Warning System. **End-user docs:** [`user-docs/`](../user-docs/) and [`docs/`](../docs/index.md) (safety and user-oriented reference). **Developer/agent harness:** this tree (`dev-docs/`), plus the root map [AGENTS.md](../AGENTS.md).

## Start here

| Doc | Purpose |
|-----|---------|
| [**TO_DO.md**](TO_DO.md) | Short priority queue — what to work on next |
| [**REMAINING_WORK_SUMMARY.md**](REMAINING_WORK_SUMMARY.md) | Detailed backlog (testing, docs, master-plan phases) |
| [**FUTURE_ENHANCEMENTS.md**](FUTURE_ENHANCEMENTS.md) | Numbered enhancement catalog with status |
| [**TECHNICAL_DETAILS.md**](TECHNICAL_DETAILS.md) | Implementation reference (linked from user docs) |
| [**STEAMOS_GAMING_MODE.md**](STEAMOS_GAMING_MODE.md) | SteamOS / Gaming Mode compatibility |

## Plans

| Location | Contents |
|----------|----------|
| [`plans/master/`](plans/master/) | [Master implementation plan](plans/master/linux-warning-system-plan.md) |
| [`plans/phases/`](plans/phases/) | Phase 1–5 checklists, code-quality plan |
| [`plans/`](plans/) | Active feature plans (in progress) |
| [`plans/plan-harness-engineering-improvements-2026-06-12.md`](plans/plan-harness-engineering-improvements-2026-06-12.md) | Post-refactor: CI tiers, Cursor rules, doc rehome (`docs/` → `dev-docs/`) — **after** [June refactor plan](plans/plan-refactor-assessment-2026-06-12.md) |
| [`completed-plans/`](completed-plans/) | Finished or superseded implementation plans (archive) |

## Enhancement specs

| Location | Contents |
|----------|----------|
| [`enhancements/`](enhancements/) | Numbered enhancement specs (`enhancement-NN-*.md`) |
| [`alternatives/`](alternatives/) | Alternative architecture approaches |
| [`fixes/`](fixes/) | Completed one-off fix write-ups |

## Reference and audits

| Location | Contents |
|----------|----------|
| [`info/`](info/) | Reusable research (dialog tools, distribution, Wayland, etc.) |
| [`notes/`](notes/) | One-off analyses and debug notes |
| [`templates/`](templates/) | Copy-paste templates for assessments and safety scans |
| [`templates-generalized/`](templates-generalized/) | Portable template copies for other repos |
| `code-assessments/`, `doc-assessments/`, `refactor-assessments/`, `testing-assessments/`, `safety-scans/` | Timestamped audit records (historical) |

## Conventions

- **Enhancement numbers** (`#16`, `#22`, …) match headings in `FUTURE_ENHANCEMENTS.md` and filenames under `enhancements/`.
- **Safety** overrides feature work — read [`docs/SAFETY.md`](../docs/SAFETY.md) before popup, scheduler, or config changes.
- **Tests** during restricted hours: use a temp `HOME`; see [`.cursor/rules/config-file-edits.mdc`](../.cursor/rules/config-file-edits.mdc).

**Last updated:** 2026-06-12 (doc boundary note; harness plan linked)
