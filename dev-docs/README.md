# Developer documentation (`dev-docs/`)

Backlog, plans, enhancement specs, and audit history for the Sleep Warning System.

## Two documentation trees

| Tree | Audience | Start |
|------|----------|-------|
| **`docs/`** | End-users | [SAFETY.md](../docs/SAFETY.md), [docs/index.md](../docs/index.md) |
| **`user-docs/`** | End-users | [MACOS.md](../user-docs/MACOS.md), [CONFIGURATION.md](../user-docs/CONFIGURATION.md) |
| **`dev-docs/`** (here) | Developers and **all coding agents** | This file + [AGENTS.md](../AGENTS.md) |

See [canonical-vs-archive.md](canonical-vs-archive.md) for what is current vs historical.

## Start here

| Doc | Purpose |
|-----|---------|
| [**CONTRIBUTING.md**](CONTRIBUTING.md) | **New contributors** — clone, hooks, Tier-A, PR checklist |
| [**TO_DO.md**](TO_DO.md) | Short priority queue — what to work on next |
| [**development/agent-setup.md**](development/agent-setup.md) | Agent-agnostic entry (Cursor, Codex, Claude, OpenCode, Qwen, …) |
| [**agent-workflow.md**](agent-workflow.md) | Map → change → verify → document |
| [**harness-engineering.md**](harness-engineering.md) | OpenAI harness patterns in this repo |
| [**development/ci.md**](development/ci.md) | GitHub Actions jobs and local CI parity |
| [**architecture/map.md**](architecture/map.md) | Module layout and enhancement index |
| [**architecture/configure-flow.md**](architecture/configure-flow.md) | Configure wizard menu/dialog flow and save gates |
| [**development/testing.md**](development/testing.md) | Safe test practices |
| [**development/platform-test-matrix.md**](development/platform-test-matrix.md) | macOS vs Linux test matrix |
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
| [`plans/plan-harness-engineering-improvements-2026-06-12.md`](plans/plan-harness-engineering-improvements-2026-06-12.md) | **Complete** — Phases 0–8 (contributor guide, PR template, file-size check) |
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
| `code-assessments/`, `doc-assessments/`, `refactor-assessments/`, `testing-assessments/`, `safety-scans/` | Timestamped audit records (historical) |

## Conventions

- **Enhancement numbers** (`#16`, `#22`, …) match headings in `FUTURE_ENHANCEMENTS.md` and filenames under `enhancements/`.
- **Safety** overrides feature work — read [`docs/SAFETY.md`](../docs/SAFETY.md) before popup, scheduler, or config changes.
- **Tests** during restricted hours: use a temp `HOME`; see [`.cursor/rules/config-file-edits.mdc`](../.cursor/rules/config-file-edits.mdc).

**Last updated:** 2026-06-12 (Phase 8 contributor guide; harness Phases 1–7 complete)
