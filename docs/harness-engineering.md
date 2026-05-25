# Harness engineering in this repository

We adapt practices from OpenAI’s article [**Harness engineering: leveraging Codex in an agent-first world**](https://openai.com/index/harness-engineering/) (Feb 2026). Full notes: [references/openai-harness-engineering.md](references/openai-harness-engineering.md).

## What harness engineering means here

Engineering effort focuses on **environment design**—docs, tests, guardrails, and structure—so agents (and humans) can change this bash codebase reliably without trapping end users.

We are not an agent-only repo; we still write and review shell code directly. The **patterns** still apply.

## How this repo implements the article

| OpenAI principle | Our implementation |
|------------------|-------------------|
| **AGENTS.md as map (~100 lines)** | [AGENTS.md](../AGENTS.md) points to `docs/`; details live below |
| **`docs/` as system of record** | [docs/index.md](index.md) |
| **Safety / golden principles** | [SAFETY.md](SAFETY.md) — treated as #1; encoded in `lib/popup-safety.sh` |
| **Mechanical enforcement** | Tests (`test-popup-safety-darwin.sh`), validation (`configure-validation.sh`), cursor rules |
| **Agent legibility** | [architecture/map.md](architecture/map.md), platform facades |
| **Boring technology** | Bash, systemd, launchd, osascript—stable, inspectable |
| **Entropy / garbage collection** | Doc updates with behavior changes; refactor platform adapters instead of duplicating |
| **Depth-first capability building** | Platform layer before features (macOS adapter, popup-safety, scheduler-platform) |

## Agent workflow (summary)

1. Read [SAFETY.md](SAFETY.md) and [AGENTS.md](../AGENTS.md).
2. Open the relevant `docs/architecture/` or `docs/development/` page.
3. Make the smallest change that satisfies the task.
4. Run targeted tests ([development/testing.md](development/testing.md)).
5. Update docs and CHANGELOG if behavior changed ([development/versioning.md](development/versioning.md)).

See [agent-workflow.md](agent-workflow.md).

## What we deliberately do not copy

- Fully agent-generated codebase / zero human code
- Minimal merge gates tuned for 3.5 PRs/day per engineer
- Chrome DevTools / per-worktree app boot for UI agents (not applicable to this CLI/GUI bash project)

## When to extend this harness

Add a new doc page when:

- A failure mode repeats (e.g. lockout scare → expand SAFETY.md)
- A new platform or scheduler is added → `architecture/platforms.md`
- A new invariant exists → code + test + one paragraph in SAFETY or core-beliefs

Do **not** grow AGENTS.md into a megadoc—add a `docs/` page and link it.
