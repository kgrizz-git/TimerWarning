# Documentation index

This directory is the **system of record** for humans and coding agents working in this repository. Prefer updating these files over chat-only decisions.

## Read first (non-negotiable)

| Doc | Why |
|-----|-----|
| [SAFETY.md](SAFETY.md) | **#1 priority:** avoid user lockout, stuck modals, 24/7 warnings, unrecoverable config |
| [safety-linux-macos-analysis.md](safety-linux-macos-analysis.md) | Deep dive: Linux heritage vs macOS reproduction, gaps, and doc drift |
| [core-beliefs.md](core-beliefs.md) | Operating principles including safety and agent-first norms |

## Harness engineering (agent-first workflow)

| Doc | Why |
|-----|-----|
| [harness-engineering.md](harness-engineering.md) | How we apply [OpenAI harness engineering](references/openai-harness-engineering.md) in this repo |
| [agent-workflow.md](agent-workflow.md) | Day-to-day steps for agents: map → change → verify → document |

## Architecture and platforms

| Doc | Why |
|-----|-----|
| [architecture/map.md](architecture/map.md) | Module layout, platform adapters (Linux systemd vs macOS launchd) |
| [architecture/platforms.md](architecture/platforms.md) | Linux vs macOS file matrix |
| [development/testing.md](development/testing.md) | Safe test practices (temp HOME, timeouts, no live config during blocked hours) |
| [development/versioning.md](development/versioning.md) | Semver, CHANGELOG entries, release tagging |
| [../dev-docs/CONFIGURE_GUI_FLOW.md](../dev-docs/CONFIGURE_GUI_FLOW.md) | Configure GUI dialog paths, cancel semantics, immovable prompt trap |

## User-facing docs

| Doc | Audience |
|-----|----------|
| [../user-docs/MACOS.md](../user-docs/MACOS.md) | macOS install, troubleshooting, emergency stop |
| [../user-docs/CONFIGURATION.md](../user-docs/CONFIGURATION.md) | Config file reference |
| [../README.md](../README.md) | Project overview and quick start |

## Developer backlog (`dev-docs/`)

| Doc | Why |
|-----|-----|
| [../dev-docs/README.md](../dev-docs/README.md) | Map of plans, enhancements, templates, audits |
| [../dev-docs/TO_DO.md](../dev-docs/TO_DO.md) | Short active priority queue |
| [../dev-docs/FUTURE_ENHANCEMENTS.md](../dev-docs/FUTURE_ENHANCEMENTS.md) | Numbered enhancement catalog |
| [../dev-docs/REMAINING_WORK_SUMMARY.md](../dev-docs/REMAINING_WORK_SUMMARY.md) | Detailed backlog (testing, phases, docs) |

## Maintenance

When you change behavior, update the relevant doc in the same PR. If a rule is important enough to enforce, encode it in code (`lib/popup-safety.sh`, validation) or in [`.cursor/rules/`](../.cursor/rules/), not only in prose.
