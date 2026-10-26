# Plan: Enforce lint, types, complexity, and file size

**Created:** 2026-10-26

**Status:** Draft. Not started. This document is the work. Do not add the tools, configs, or hook changes until this plan is accepted.

**Branch:** `chore/quality-gates`, from `main` at `f7a22a9`. It is not stacked on `chore/public-polish`.

**Safety reference:** [docs/SAFETY.md](../../docs/SAFETY.md). These gates do not change popup, scheduler, or config behavior. The three invariants stay as they are.

## What is already enforced

| Check | Pre-commit | Pre-push | CI (`.github/workflows/security.yml`) |
|-------|------------|----------|----------------------------------------|
| ShellCheck `-S error` on production shell | Staged `*.sh`, skips `tests/` and `backups/` | — | `./scripts/run-security-scan.sh --ci` |
| Gitleaks | Staged diff | — | Full history scan in that same script |
| Semgrep project rules (`eval`, `curl \| bash`) | — | — | Same script |
| Tier-A tests | — | Opt-in file `.githooks/enable-pre-push` | Ubuntu and macOS |
| `lib/*.sh` line cap, 900 | — | — | — |

`./scripts/check-file-sizes.sh` is manual. Without `--strict` it warns and exits 0. `lib/configure-dialogs-darwin.sh` is the only allowlisted file. Two other shell files are already over the cap and are not allowlisted: `lib/config.sh` (908) and `lib/window-management.sh` (933), counted on 2026-10-26. Turning on `--strict` as it exists today would fail before any new code is written.

There is no type checker, no Python linter, and no complexity limit in the hooks or in CI. SonarCloud comments on pull requests come from the GitHub app. This plan does not replace that app and does not add a Sonar quality gate.

Python on `main` at `f7a22a9` is the macOS UI and one test: 9 files under `lib/` and `tests/test-darwin-modal-dialog.py`. The largest is `lib/popup-blocker-darwin.py` at 430 lines. None exceed 500. `tests/test-popup-icon-tk.py` is on `chore/public-polish` and is not on this branch.

## Decisions

1. **CI is the enforcement.** A laptop can skip a hook. The GitHub Actions job cannot. Every new check runs in CI on pull requests and on pushes to `main`.
2. **Pre-commit stays fast and staged.** It looks at the files in the commit. It does not type-check the tree and it does not run Tier-A.
3. **Pre-push takes the slower whole-tree checks.** Tier-A stays behind `INSTALL_PRE_PUSH=1`. The new pre-push checks run whenever the hooks are installed, including when that opt-in file is absent. Today `.githooks/pre-push` exits 0 immediately without that file. The change is to run the quality script first, then Tier-A only when the opt-in file exists.
4. **Missing local tools warn and skip, matching ShellCheck.** CI installs the tools and fails if they are missing. `SKIP_*` remains a local emergency valve. CI does not honor it.
5. **Do not boil the ocean.** Existing violations are baselined or allowlisted. The gate fails on new violations and on growth past a recorded size. It does not require a drive-by cleanup of `config.sh` or `window-management.sh`.
6. **Bash has no complexity tool worth adopting.** ShellCheck stays the shell linter. Shell complexity in this plan means a small repo script for function length and brace nesting, not a third-party cyclomatic scanner. Python complexity is Ruff's McCabe check (`C901`).
7. **basedpyright, not stock pyright.** It has a committed baseline, so the first run does not have to make the tkinter code fully typed. Pin the version in `pyproject.toml`. In CI, basedpyright locks the baseline by default when it detects CI. Pre-push must not rewrite `.basedpyright/baseline.json`. Use `--baselinemode=lock` there. That flag is documented as experimental ([command-line reference](https://docs.basedpyright.com/latest/configuration/command-line/)). On implementation day, confirm the flag still exists and use the documented replacement if it does not. Do not set `CI=true` locally as a substitute.
8. **Ruff v1 is a narrow rule set:** Pyflakes (`F`), pycodestyle errors (`E`), and McCabe (`C901`). Do not enable the full Ruff catalog. The McCabe ceiling is chosen in the baseline step below, not in this draft.

## Where each check runs

| Check | Pre-commit | Pre-push | CI |
|-------|------------|----------|----|
| ShellCheck `-S error` | Staged production shell (already) | — | Already |
| Gitleaks | Staged (already) | — | Already |
| Semgrep project rules | — | — | Already |
| Ruff `E` and `F` | Staged `*.py` | — | Whole tree |
| Ruff McCabe `C901` | — | Whole tree | Whole tree |
| basedpyright, baseline locked | — | Whole tree, `--baselinemode=lock` | Whole tree, CI lock |
| File-size ratchet | Staged `lib/*.sh` and `lib/*.py` | Whole `lib/` | Whole `lib/` |
| Shell function length and nesting | — | `lib/*.sh` and entry scripts | Same |
| Tier-A | — | Unchanged opt-in | Unchanged |

Pre-commit file size and Ruff apply only to files in the index. A commit that does not touch Python does not run Ruff. A commit that does not touch `lib/` does not run the size ratchet.

## Caps to implement

**File size.** Keep the shell cap at 900 lines for `lib/*.sh`. Add a 500-line cap for `lib/*.py`. Tests stay uncapped. `lib/configure-dialogs-darwin.sh` stays allowlisted.

The ratchet, for every non-allowlisted file:

- Under the cap: fail if the file would exceed the cap.
- Already over the cap (`config.sh`, `window-management.sh`): record the current line count in the script and fail if the file grows. Shrinking is allowed. Do not fail the branch merely because those two files are already over 900.

**Shell functions.** During implementation, measure function length and maximum brace depth under `lib/*.sh` and the root entry scripts. Set the ceilings at the measured maximum, and list every function that sits on that ceiling in the script's header. New functions, and any edit that pushes an existing function past the ceiling, fail. The script is `scripts/check-shell-complexity.sh`. It does not claim to compute cyclomatic complexity.

**Python McCabe.** Run Ruff `C901` once, with no ceiling, and set `[tool.ruff.lint.mccabe] max-complexity` to that measured maximum if it is above 10, otherwise 10. Record the number in `pyproject.toml` and in this plan when it is known.

## Files the implementation will add or edit

Add:

- `pyproject.toml` with the Ruff and basedpyright settings, including `baselineFile`.
- `.basedpyright/baseline.json`, produced by `basedpyright --writebaseline` after the config exists.
- `scripts/check-shell-complexity.sh`.
- A dev extra or `[project.optional-dependencies] dev` pin for `ruff` and `basedpyright`. There is no project venv today. CI installs that extra. Document `pip install -e '.[dev]'` or `pip install` of those two pins. Do not commit a virtualenv.

Edit:

- `scripts/check-file-sizes.sh` so it understands the Python cap and the ratchet.
- `scripts/pre-commit-checks.sh` and `scripts/pre-push-checks.sh`.
- `.githooks/pre-push` so quality checks run without `.githooks/enable-pre-push`.
- `.github/workflows/security.yml` with one new step, or one script the step calls, after the existing security scan. The job installs Ruff and basedpyright.
- `scripts/install-git-hooks.sh` help text.
- `dev-docs/CONTRIBUTING.md` and `dev-docs/development/security-scanning.md`.
- `dev-docs/harness-changelog.md`. No product changelog entry and no version bump: installed popup behavior does not change.

Do not edit popup, scheduler, or config code to satisfy a new lint in the same change as the gate, except a baseline ignore that records current diagnostics. If the baseline is empty because the chosen Ruff rules are already clean, do not add ignore comments.

## Implementation order

- [ ] Measure shell function length, brace depth, and Python McCabe. Write the ceilings into the config and the script header.
- [ ] Add `pyproject.toml`, the dependency pin, and the basedpyright baseline. Confirm `--baselinemode=lock` against the pinned version's docs.
- [ ] Teach `check-file-sizes.sh` the Python cap and the ratchet. `./scripts/check-file-sizes.sh --strict` exits 0 on current `main` after the ratchet records `config.sh` and `window-management.sh`.
- [ ] Add `scripts/check-shell-complexity.sh`. It exits 0 on current `main`.
- [ ] Wire pre-commit (staged Ruff `E`/`F`, staged size ratchet).
- [ ] Wire pre-push (McCabe, basedpyright lock, full size ratchet, shell complexity). Leave Tier-A opt-in.
- [ ] Wire CI to the same commands, with tools installed in the job, and with no `SKIP_*` bypass.
- [ ] Update the contributor and security-scanning docs, and `dev-docs/harness-changelog.md`.
- [ ] Run the new CI script locally, then `./scripts/run-security-scan.sh --ci`. Do not run `configure.sh`.

## Out of scope

- Splitting `config.sh`, `window-management.sh`, or `configure-dialogs-darwin.sh`.
- Formatting (Black, Ruff format, shfmt) and import sorting.
- Typing the macOS UI beyond what the baseline already allows. New Python fails the baseline; old diagnostics stay ignored until a later cleanup.
- MyPy, Pyright upstream, Pylint, or a second Python linter.
- Changing SonarCloud, Semgrep, ShellCheck severity, or Tier-A.
- Branch protection on `main`. That remains in the public-repo plan.
