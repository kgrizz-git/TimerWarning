# Copilot instructions — LinuxTimerWarning

For the full agent guide see [AGENTS.md](../AGENTS.md), [dev-docs/README.md](../dev-docs/README.md), and [docs/SAFETY.md](../docs/SAFETY.md).

**Developer docs:** [dev-docs/development/agent-setup.md](../dev-docs/development/agent-setup.md) (tool-agnostic). **Tests:** `./scripts/run-tests.sh --tier a`.

## ⛔ Operational hazard — never run `configure.sh` unbounded

`configure.sh` and the `lib/configure-*.sh` menus are **interactive read loops**.
With non-interactive stdin at EOF (no terminal + no input) they **spin forever**,
pegging a CPU and growing redirected output WITHOUT bound. This once produced
~465 GB of `/tmp` files (`/tmp/cfg-out.txt`, `cfg-out2.txt`, `configure-output.txt`)
and filled the disk.

When running it, use **all three**:
1. a `timeout` (e.g. `timeout 15 ./configure.sh --text`),
2. controlled stdin — `</dev/null` (clean immediate exit) or finite valid input,
3. bounded output (pipe to `head`, capture small, don't redirect to an unbounded file).

Then clean up: `pkill -f LinuxTimerWarning/configure.sh` and delete any temp output.
**Never** `./configure.sh ... > out.txt 2>&1 &` and walk away.

Safe example: `printf '13\n' | timeout 15 ./configure.sh --text 2>&1 | head -200`

## Safety basics

Before changing popups, schedulers, config validation, or install defaults, read
[docs/SAFETY.md](../docs/SAFETY.md): per-day 16 h cap (per category), popups must
always end (finite watchdog), and the uninstall/escape hatch must always work.

## Other

- Wizard needs bash ≥ 4; on macOS use `/opt/homebrew/bin/bash` for coproc-based tests.
- Log changes in [CHANGELOG.md](../CHANGELOG.md) under `## [Unreleased]`.
- Run `shellcheck -S error` on changed shell files.
