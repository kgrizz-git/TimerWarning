# Canonical docs vs archive

Two **active** documentation trees plus historical records. Any coding agent (Cursor, Codex, Claude, OpenCode, Qwen, …) should use the **canonical** paths below—not chat memory.

## Two directories (active)

| Tree | Audience | Start here |
|------|----------|------------|
| **`docs/`** | End-users | [docs/index.md](../docs/index.md), [docs/SAFETY.md](../docs/SAFETY.md) |
| **`user-docs/`** | End-users | [MACOS.md](../user-docs/MACOS.md), [CONFIGURATION.md](../user-docs/CONFIGURATION.md) |
| **`dev-docs/`** | Developers and agents | [README.md](README.md), [AGENTS.md](../AGENTS.md) |

**Rule:** User-facing safety prose stays in `docs/SAFETY.md`. Developer harness, architecture, CI, and plans stay in `dev-docs/`.

## Canonical reads (agents)

1. [docs/SAFETY.md](../docs/SAFETY.md)
2. [AGENTS.md](../AGENTS.md)
3. [development/agent-setup.md](development/agent-setup.md)
4. [agent-workflow.md](agent-workflow.md)
5. Task area: [architecture/](architecture/), [development/](development/), [TO_DO.md](TO_DO.md)

## Stubs in `docs/`

Moved developer pages leave a short **Moved** stub under `docs/` for one release cycle (e.g. `docs/harness-engineering.md` → `dev-docs/harness-engineering.md`). Follow the stub link.

## Archive (historical — do not treat as current spec)

| Location | Contents |
|----------|----------|
| `dev-docs/*-assessments/` | Timestamped code/doc/refactor/testing audits |
| `dev-docs/safety-scans/` | Point-in-time safety scan records |
| `dev-docs/completed-plans/` | Superseded implementation plans |
| `dev-docs/templates/` | Copy-paste templates for new assessments |

When archive text conflicts with [docs/SAFETY.md](../docs/SAFETY.md) or current `lib/` code, **code + SAFETY win**.

Retention and pruning: [development/doc-retention.md](development/doc-retention.md).

## IDE-specific (optional)

| Tool | Extra entry |
|------|-------------|
| Cursor | `.cursor/rules/` |
| Claude Code | `CLAUDE.md` |
| GitHub Copilot | `.github/copilot-instructions.md` |

Universal harness does not require any of these.
