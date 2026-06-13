# Agent workflow

Steps for AI agents (Cursor, Codex, Claude Code, OpenCode, Qwen, Windsurf, etc.) working in this repository.

**Tool-specific setup:** [development/agent-setup.md](development/agent-setup.md) — universal vs IDE-only layers.

## Before any task

1. Read [docs/SAFETY.md](../docs/SAFETY.md) — non-negotiable.
2. Skim [AGENTS.md](../AGENTS.md) and open the linked `dev-docs/` page for your task area.
3. Check [development/agent-setup.md](development/agent-setup.md); Cursor users may also read `.cursor/rules/config-file-edits.mdc` and `tests.mdc`.

## During implementation

- **Smallest correct diff** — match existing bash style in surrounding files.
- **Platform branch** — use `is_darwin` / facades; do not assume systemd on macOS.
- **Popup/timer changes** — must include bounded lifetime (see `lib/popup-safety.sh`).
- **Never** point automated tests at the user’s real `~/.config/sleep-warning/` during restricted hours.

## After implementation

1. Run `./scripts/run-tests.sh --tier a` or scripts from [testing-assessments/test-tiers.md](testing-assessments/test-tiers.md).
2. Update [docs/SAFETY.md](../docs/SAFETY.md) if user-facing safety rules changed; update `dev-docs/` for developer/harness changes.
3. Add CHANGELOG entry under `[Unreleased]` if user-visible ([development/versioning.md](development/versioning.md)).
4. Self-review using checklist in [docs/SAFETY.md](../docs/SAFETY.md#review-checklist-pr--agent-self-review).

## If stuck

Ask: **what capability is missing?** (doc, test, guardrail, helper)—then add that instead of retrying the same prompt.

## Harness context

See [harness-engineering.md](harness-engineering.md).
