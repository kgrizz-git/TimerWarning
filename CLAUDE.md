# CLAUDE.md — agent guidance for LinuxTimerWarning

Full agent map and safety docs: @AGENTS.md (the canonical guide; this file adds
the operational warning below plus a brief project shape).

## ⛔ CRITICAL: never run `configure.sh` (or any interactive prompt) unbounded

`configure.sh` and its `lib/configure-*.sh` menus are **interactive read loops**.
When stdin is not a terminal and input runs out (EOF), several loops historically
**spin forever** — re-printing a menu/"Invalid option" at 100% CPU. If their output
is redirected to a file, that file grows **without bound**.

This already happened: dozens of backgrounded `configure.sh --text` processes ran
for days and produced three `/tmp` files totaling **~465 GB** (`/tmp/cfg-out.txt`,
`/tmp/cfg-out2.txt`, `/tmp/configure-output.txt`), filling the disk.

**Rules for running it — always all three:**
1. **Bound the runtime** with a watchdog: `timeout 15 ./configure.sh --text ...`
   (the test suite does this; rc 124 = it hit the timeout, i.e. it was spinning).
2. **Control stdin** — never leave it attached to a dead/EOF pipe. Use
   `</dev/null` (forces immediate clean exit) or feed finite, valid input.
3. **Bound the output** — capture to the harness, a `head -c`, or a small file you
   then truncate. Never `> /tmp/whatever.txt 2>&1 &` and walk away.

Example (safe): `printf '13\n' | timeout 15 ./configure.sh --text 2>&1 | head -200`

**Never** background it with redirected output and no timeout
(`./configure.sh ... > out.txt 2>&1 &`). If you must background, add `timeout`,
`</dev/null`, and check/kill it before ending your turn.

**After driving it, clean up**: `pkill -f LinuxTimerWarning/configure.sh` and remove
any temp output files. Don't leave runaway processes between sessions.

The interactive read loops are being hardened to exit on EOF instead of spinning
(see [lib/configure-display.sh](lib/configure-display.sh) `show_main_menu`), but the
guard above applies regardless — treat any interactive script this way.

## Project shape (brief)

- Cross-platform (Linux + macOS) sleep/timer warning system, mostly Bash under `lib/`.
- macOS configure dialogs: osascript for simple alerts + a long-lived tkinter
  **daemon** (`lib/configure-dialogs-darwin-daemon.py`) for list/table/time/text.
- Requires bash ≥ 4 for the wizard; on macOS use `/opt/homebrew/bin/bash` to run the
  coproc-based tests (default `/bin/bash` is 3.2).
- Tests live in `tests/`; many are headless-safe, GUI ones need a session.

## Conventions

- Changes are logged in [CHANGELOG.md](CHANGELOG.md) under `## [Unreleased]`.
- Run `shellcheck -S error` on changed shell files (matches CI / pre-commit).
