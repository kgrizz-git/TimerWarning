# Agent workflow

Steps for AI agents (Cursor, Codex, etc.) working in this repository.

## Before any task

1. Read [SAFETY.md](SAFETY.md) — non-negotiable.
2. Skim [AGENTS.md](../AGENTS.md) and open the linked doc for your task area.
3. Check `.cursor/rules/config-file-edits.mdc` and `tests.mdc` if touching config, tests, or install.

## During implementation

- **Smallest correct diff** — match existing bash style in surrounding files.
- **Platform branch** — use `is_darwin` / facades; do not assume systemd on macOS.
- **Popup/timer changes** — must include bounded lifetime (see `lib/popup-safety.sh`).
- **Never** point automated tests at the user’s real `~/.config/sleep-warning/` during restricted hours.

## After implementation

1. Run relevant tests ([development/testing.md](development/testing.md)).
2. Update `docs/` if behavior or safety rules changed.
3. Add CHANGELOG entry under `[Unreleased]` if user-visible ([versioning.md](development/versioning.md)).
4. Self-review using checklist in [SAFETY.md](SAFETY.md#review-checklist-pr--agent-self-review).

## If stuck

Ask: **what capability is missing?** (doc, test, guardrail, helper)—then add that instead of retrying the same prompt.

## Harness context

See [harness-engineering.md](harness-engineering.md).
