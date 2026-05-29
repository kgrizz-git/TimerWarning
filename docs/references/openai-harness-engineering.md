# Reference: OpenAI harness engineering (Feb 2026)

**Source:** [Harness engineering: leveraging Codex in an agent-first world](https://openai.com/index/harness-engineering/) — Ryan Lopopolo, OpenAI.

## One-line summary

Humans design **environments, intent, and feedback loops**; agents execute. The repository—not chat—is the system of record.

## Takeaways we adopted

1. **Empty-repo discipline** — Structure and rules are intentional from day one (AGENTS.md + `docs/`).
2. **Engineers as environment designers** — Missing capability → add tools/docs/tests, not “try harder.”
3. **Map, not encyclopedia** — Short AGENTS.md; progressive disclosure via `docs/`.
4. **Mechanical architecture** — Linters/tests/rules; error messages should say how to fix.
5. **In-repo knowledge only** — If it isn’t in git, agents and future humans won’t reliably see it.
6. **Agent legibility** — Prefer inspectable bash modules and boring platform APIs.
7. **Golden principles / garbage collection** — Encode taste once ([SAFETY.md](../SAFETY.md), core-beliefs); enforce continuously.
8. **Throughput-aware process** — Small PRs, fast correction; still **safety overrides speed** in this project.

## Project-specific twist: physical safety

OpenAI’s article focuses on engineering velocity. This product can **block a person’s computer**, so our harness prioritizes [SAFETY.md](../SAFETY.md) above velocity. Any harness change must pass the safety review checklist there.

## Local mapping

| Article concept | Local doc |
|-----------------|-----------|
| Knowledge store layout | [docs/index.md](../index.md) |
| Core beliefs | [core-beliefs.md](../core-beliefs.md) |
| Enforcement / invariants | [SAFETY.md](../SAFETY.md), `lib/popup-safety.sh` |
| Architecture boundaries | [architecture/map.md](../architecture/map.md) |
| How agents should work | [agent-workflow.md](../agent-workflow.md) |
