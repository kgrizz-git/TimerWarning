# Core beliefs

Principles for humans and agents working on Linux Sleep Warning System.

## 1. Safety before features

See [docs/SAFETY.md](../docs/SAFETY.md). If a change could trap a user behind modals or make the system unconfigurable, do not merge it.

## 2. Repository knowledge is the system of record

Decisions belong in versioned files under `dev-docs/`, [docs/SAFETY.md](../docs/SAFETY.md), `AGENTS.md`, or enforced code—not only in chat, issues, or memory.

## 3. Agents need a map, not an encyclopedia

- Short [AGENTS.md](../AGENTS.md) = table of contents
- Deep developer detail lives in `dev-docs/` (progressive disclosure)
- End-user safety lives in `docs/` and `user-docs/`

## 4. Enforce invariants mechanically

Prefer code (`lib/popup-safety.sh`, validation modules) and CI/tests over prose alone.

## 5. Boring, legible bash

- Small modules under `lib/`
- Platform suffixes: `*-linux.sh`, `*-darwin.sh`, facades like `service-config.sh`
- One responsibility per file where practical

## 6. Continuous entropy control

When agents copy patterns, bad patterns spread. Refactor toward [docs/SAFETY.md](../docs/SAFETY.md) and [architecture/map.md](architecture/map.md) when touching related code.

## 7. Humans steer, agents execute

Humans prioritize, specify acceptance criteria, and validate outcomes. When agents fail, fix the **environment** (docs, tests, guardrails), not “try harder.”
