# Safety fix reviews — 2026-10-18

Reviewed baseline: `8ee459b..5b568cb` on `chore/public-repo-prep`, plus the subsequent popup and review follow-ups. Reviewers were read-only; offline checks used temporary HOME directories.

- **LongCat 2.5 Preview Free:** `opencode/opencode-go/longcat-2.5-preview-free` through Paseo. Confirmed the osascript-child termination and expiry-during-respawn fixes; reported no remaining high-severity safety issue.
- **Sonnet 5.5:** `claude/claude-sonnet-5-5`, auto mode, through Paseo. Antigravity's full-access launch was rejected by automatic approval review; its provider does not support the repository-required auto mode. The same model was reviewed through the Claude provider instead. Sonnet compared runtime coverage against cap accounting minute by minute across about 25 formats and ran the cap/regression suites successfully.

## Applied follow-ups

- Retry countdown spawns at most three times within the same watchdog deadline; notify after persistent failure.
- Check watchdog setup status and its live PID; close and clean up the dialog if supervision cannot start. Sweep expiry markers older than ten minutes while preserving recent latches.
- Return a distinct writer safety status with structured cap details and no raw stdout; show the actual cap error in configure. Normalize mixed-case config-file-lock flags.
- Remove the environment flag that could skip macOS module loading; load missing implementations by function availability.
- Preserve Zenity cancellation while detecting status-1 startup diagnostics, close the expiry-during-spawn race, and force-terminate/reap TERM-ignoring osascript children.

## Findings retained or rejected after verification

- **Uninstall abort on scheduler stop failure:** intentional. Do not delete files while the scheduler may still run. Report the failure and retain the manual-uninstall guide; no new force bypass was added.
- **Experimental Gaming Mode toggle:** intentionally permitted in both directions during partial lock. The shared allow-arm and `test-gamescope-overlay.sh` assertions pin this policy; the extra calls do not impose a tightening restriction.
- **Unverified remote X display without probe tools:** retain notification fallback rather than claim an unverified display is accessible. Existing tests pin this behavior.
- **Repeated Bash wait:** reproduced an exited child's status twice (`42`, then `42`), with the fast-pause regression also exercising this path. Reinstating a liveness guard would lose valid fast clicks. A genuine non-child PID should still be reported.
- **YAD status 252:** valid Escape/window-manager dismissal, not a command-line error; verified against the [upstream manual](https://github.com/v1cont/yad/blob/master/data/yad.1). Keep it accepted and covered by a regression.
- **24:00 carry claim:** `22:00-24:00` has start < end and produces no next-day tail; directly checked the helper and added regression coverage.
- **Repeated time-parser sourcing:** the existing function-availability guard avoids redundant loading in normal operation. Re-defining pure functions is harmless; an additional loaded flag could prevent restoring an unset function.

## Verification

`./scripts/run-security-scan.sh --ci --with-tests` passed with a temporary HOME and bounded logs: ShellCheck, Gitleaks, Semgrep, and 19 applicable headless Tier-A scripts; three expected platform/GUI skips. The gamescope socket test required execution outside the sandbox. Additional config-lock/configure, writer, Linux watchdog, and time-endpoint tests passed. No installed config, live scheduler, or GUI was changed.
