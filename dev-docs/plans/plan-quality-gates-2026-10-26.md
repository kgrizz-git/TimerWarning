# Plan: Enforce lint, types, complexity, and file size

**Created:** 2026-10-26

**Status:** Draft, revised after review on 2026-10-26. The lint, type, complexity, and file-size gates below are not started. Two gates are already implemented on this branch: Python line coverage, and the local SonarQube freshness check plus BUG/VULNERABILITY ratchet. Do not add the other tools, configs, or hook changes until this plan is accepted.

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
| Local SonarQube freshness | — | `scripts/check-sonar-freshness.sh` when `SONAR_TOKEN` is set | — |
| Local SonarQube BUG/VULNERABILITY ratchet | — | `scripts/check_sonar_issues.py` when a scan dump exists | — |
| Python line coverage of `lib/*.py` | — | `scripts/check-python-coverage.sh` | Ubuntu static-analysis job, under xvfb |

`./scripts/check-file-sizes.sh` is manual. Without `--strict` it warns and exits 0. `lib/configure-dialogs-darwin.sh` is the only allowlisted file. Two other shell files are already over the cap and are not allowlisted: `lib/config.sh` (908) and `lib/window-management.sh` (933), counted on 2026-10-26. Turning on `--strict` as it exists today would fail before any new code is written.

There is no type checker, no Python linter, and no complexity limit in the hooks or in CI. SonarCloud comments on pull requests come from the GitHub app. This plan does not replace that app and does not add a SonarCloud quality gate. The local freshness check and BUG/VULNERABILITY ratchet on this branch are separate: they do not run in CI, and the Community Build does not see the Shell or `pythonsecurity` rules SonarCloud reports.

Python on `main` at `f7a22a9` was the macOS UI and one test: 10 files under `lib/` (the configure-dialog modules and `lib/popup-blocker-darwin.py`) and `tests/test-darwin-modal-dialog.py`. The largest was `lib/popup-blocker-darwin.py` at 430 lines. None exceeded 500. Merging `main` later brought `tests/test-popup-icon-tk.py` onto this branch.

## Python line coverage (implemented)

Measured on 2026-10-26 after `tests/test-popup-blocker-darwin.py`: **260 of 826 statements (31.5%)** when tkinter can open a window, and **238 of 826 (28.8%)** when that probe fails. The popup-blocker tests mock tkinter, so they count in both. The configure-dialog UI modules are still unread as code. Shell has no line-coverage number in this check.

[`scripts/check-python-coverage.sh`](../../scripts/check-python-coverage.sh) runs `tests/test-*.py` under `coverage.py`. A display run must stay at or above `260/826`. A headless run must stay at or above `238/826`. Both ratios are in [`scripts/python-coverage-baseline.json`](../../scripts/python-coverage-baseline.json). Pre-push runs it on every push and picks the floor from the same tkinter probe the tests use. The Ubuntu `Static analysis` job installs `python3-tk` and runs it under `xvfb`, so CI uses the display floor. `SKIP_PYTHON_COVERAGE=1` skips locally and is for emergencies. A machine without a display does not need that skip. CI does not honor it.

The GitHub ruleset `Mainrules1` rejects a code-coverage drop, and `minimum_coverage` is unset. Nothing in this repo uploads a coverage report to GitHub, so that ruleset rule still has no artifact to compare. The floor above is what pre-push and CI enforce.

## Decisions

1. **CI runs on the public repo; the ruleset does not require these jobs yet.** `kgrizz-git/TimerWarning` is public. `main` is protected by the active ruleset `Mainrules1` on the default branch. The classic branch-protection API returns 404 because this is a ruleset, not a legacy protection rule. The ruleset blocks deleting `main`, force-pushing it, and changing it except through a pull request. It requires zero approving reviews. It also blocks on CodeQL errors and high-or-higher code-scanning alerts, code-quality errors, and any code-coverage drop. The repository owner can bypass it. It does not list the Security workflow as a required status check, so a failing `Static analysis (Ubuntu)` or Tier-A job does not by itself block the merge, and `[skip ci]` can still skip those jobs. Hooks remain local: they run only after `./scripts/install-git-hooks.sh`, and `--no-verify` or `SKIP_*` skips them. To make these gates block merges, add required status checks on `Mainrules1` for `Static analysis (Ubuntu)` (the job that will contain the new quality step), `Tier-A (ubuntu-latest)`, and `Tier-A (macos-latest)`. This plan does not edit the ruleset.
2. **Pre-commit stays fast and staged.** It looks at the files in the commit. Complexity is part of that: Ruff McCabe on staged Python, and the shell function-length script on staged production shell. It does not type-check the tree and it does not run Tier-A. CI runs the same complexity checks on the whole tree.
3. **Pre-push takes the slower whole-tree checks.** Tier-A stays behind `INSTALL_PRE_PUSH=1`. The new pre-push checks run whenever the hooks are installed, including when that opt-in file is absent. Today `.githooks/pre-push` exits 0 immediately without that file. The change is to run the quality script first, then Tier-A only when the opt-in file exists.
4. **Missing local tools warn and skip, matching ShellCheck.** CI installs the tools and fails if they are missing. `SKIP_*` remains a local emergency valve. CI does not honor it.
5. **Do not boil the ocean.** Existing violations are baselined or allowlisted. Ruff `E` and `F` are not assumed clean: the implementation records the current diagnostics before the hook or CI can fail on them. The gate fails on new violations and on growth past a recorded size. It does not require a drive-by cleanup of `config.sh` or `window-management.sh`.
6. **Bash has no complexity tool worth adopting.** ShellCheck stays the shell linter. Shell complexity in this plan means a small repo script for function length and brace nesting, not a third-party cyclomatic scanner. Python complexity is Ruff's McCabe check (`C901`).
7. **basedpyright, not stock pyright.** It has a committed baseline, so the first run does not have to make the tkinter code fully typed. Pin the basedpyright version in `pyproject.toml`, and set `pythonVersion` to the Python that the Ubuntu static-analysis job uses to run it. Generate `.basedpyright/baseline.json` with that pinned tool in that same environment (the job, or a container of the same image), then commit it. In CI, basedpyright locks the baseline by default when it detects CI. Pre-push must not rewrite the baseline. Use `--baselinemode=lock` there. That flag is documented as experimental ([command-line reference](https://docs.basedpyright.com/latest/configuration/command-line/)). On implementation day, confirm the flag still exists and use the documented replacement if it does not. Do not set `CI=true` locally as a substitute. Lock mode fails when the diagnostic set differs in either direction, so a cleanup that removes a baselined diagnostic must rerun `basedpyright --writebaseline` in that same environment and commit the new file. Document that workflow in the security-scanning doc.
8. **The first Ruff rule set is narrow:** Pyflakes (`F`), pycodestyle errors (`E`), and McCabe (`C901`). Pin a current Ruff release. Do not enable the full Ruff catalog, and do not treat the name "Ruff v1" as a version pin. `E` includes E501. Ruff's default line length is 88. At `f7a22a9`, 14 Python lines exceed 88, none exceed 120, and the longest is 103 characters in `lib/configure_dialogs_darwin_list_ui.py`. Set `line-length` explicitly during implementation and remeasure; either keep 88 and record the current E501 diagnostics, or choose another length and ignore E501. Record every other current `E` and `F` diagnostic the same way (`ruff check --add-noqa` or `per-file-ignores`). `ruff check` must exit 0 on `main` before pre-commit or CI calls it. The McCabe ceiling is chosen in the baseline step below, not in this draft.

## Where each check runs

| Check | Pre-commit | Pre-push | CI |
|-------|------------|----------|----|
| ShellCheck `-S error` | Staged production shell (already) | — | Already |
| Gitleaks | Staged (already) | — | Already |
| Semgrep project rules | — | — | Already |
| Ruff `E` and `F` | Staged `*.py` | — | Whole tree |
| Ruff McCabe `C901` | Staged `*.py` | — | Whole tree |
| Shell function length and nesting | Staged production `*.sh` (skips `tests/` and `backups/`) | — | `lib/*.sh` and entry scripts |
| basedpyright, baseline locked | — | Whole tree, `--baselinemode=lock` | Whole tree, CI lock |
| File-size ratchet | Staged `lib/*.sh` and `lib/*.py` | Whole `lib/` | Whole `lib/` |
| Tier-A | — | Unchanged opt-in | Unchanged |

Pre-commit file size, Ruff, and shell complexity apply only to the index blob, not the working tree. `scripts/pre-commit-checks.sh` today takes staged names from `git diff --cached --name-only` and then runs ShellCheck on those paths as they exist on disk. The new checks must not copy that. For each staged path, read `git show ":$path"`: Ruff with `ruff check --stdin-filename "$path" -`, the size ratchet with the line count of that blob, and the shell-complexity script with that blob's contents. A partially staged file is judged by the staged text. A commit that does not touch Python does not run Ruff. A commit that does not touch shell does not run the shell complexity script. A commit that does not touch `lib/` does not run the size ratchet. CI and pre-push read the committed tree. CI always runs McCabe and the shell complexity script on the whole tree.

## Caps to implement

**File size.** Keep the shell cap at 900 lines for `lib/*.sh`. Add a 500-line cap for `lib/*.py`. Tests stay uncapped. `lib/configure-dialogs-darwin.sh` stays exempt from the 900 cap. It does not stay exempt from a growth limit.

The ratchet:

- Under the cap: fail if the file would exceed the cap. No recorded ceiling.
- Already over the cap: record a ceiling in the script and fail if the file is above it. The ceilings at `f7a22a9` are `lib/config.sh` 908, `lib/window-management.sh` 933, and `lib/configure-dialogs-darwin.sh` 939. Do not fail the branch merely because those files are already over 900.
- When an over-cap file shrinks, the same commit lowers its recorded ceiling to the new line count. The check fails while the file is under its recorded ceiling, so a shrink that leaves the old number in place does not pass. Once the file is at or under 900, remove its ceiling and apply the normal cap.

**Shell functions.** During implementation, measure function length and maximum brace depth under `lib/*.sh` and the root entry scripts. Set the ceilings at the measured maximum, and list every function that sits on that ceiling in the script's header. New functions, and any edit that pushes an existing function past the ceiling, fail. The script is `scripts/check-shell-complexity.sh`. It does not claim to compute cyclomatic complexity.

**Python McCabe.** Run Ruff `C901` once, with no ceiling, and set `[tool.ruff.lint.mccabe] max-complexity` to that measured maximum if it is above 10, otherwise 10. Record the number in `pyproject.toml` and in this plan when it is known.

## Files the implementation will add or edit

Add:

- `pyproject.toml` with the Ruff and basedpyright settings, including `baselineFile`.
- `.basedpyright/baseline.json`, produced by `basedpyright --writebaseline` with the pinned tool and the Ubuntu job's Python, after `pythonVersion` is set.
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

Do not edit popup, scheduler, or config code to satisfy a new lint in the same change as the gate, except a baseline ignore that records current diagnostics. E501 is already present, so that baseline will not be empty. If some other selected rule is clean, do not add ignores for it.

## Implementation order

- [ ] Measure shell function length, brace depth, Python McCabe, and `ruff check --select E,F`. Write the ceilings into the config and the script header. Set `line-length` and record current `E`/`F` diagnostics so `ruff check` exits 0 on `main`.
- [ ] Add `pyproject.toml` and the dependency pins. Set basedpyright `pythonVersion` to the Ubuntu static-analysis job's Python. Generate the baseline in that environment and confirm `--baselinemode=lock` against the pinned version's docs. `basedpyright --baselinemode=lock` exits 0 on that baseline.
- [ ] Teach `check-file-sizes.sh` the Python cap and the ratchet, including a ceiling for `configure-dialogs-darwin.sh`. A shrink that leaves the old ceiling in place fails. `./scripts/check-file-sizes.sh --strict` exits 0 on current `main` after the three ceilings match the current line counts.
- [ ] Add `scripts/check-shell-complexity.sh`. It exits 0 on current `main`. It can read a path or a blob from stdin so pre-commit can pass the index text.
- [ ] Wire pre-commit (staged Ruff `E`/`F` and `C901`, staged shell complexity, staged size ratchet), each reading `git show ":$path"` rather than the working tree.
- [ ] Wire pre-push (basedpyright lock, full size ratchet). Leave Tier-A opt-in. Complexity is not repeated here; pre-commit and CI own it.
- [ ] Wire CI to Ruff (`E`, `F`, `C901`), shell complexity, basedpyright, and the size ratchet, with tools installed in the job and no `SKIP_*` bypass.
- [ ] Update the contributor and security-scanning docs, and `dev-docs/harness-changelog.md`.
- [ ] Run the new CI script locally, then `./scripts/run-security-scan.sh --ci`. Do not run `configure.sh`.

## Out of scope

- Splitting `config.sh`, `window-management.sh`, or `configure-dialogs-darwin.sh`.
- Formatting (Black, Ruff format, shfmt) and import sorting.
- Typing the macOS UI beyond what the baseline already allows. New Python fails the baseline; old diagnostics stay ignored until a later cleanup.
- MyPy, Pyright upstream, Pylint, or a second Python linter.
- Changing SonarCloud, Semgrep, ShellCheck severity, or Tier-A.
- Editing `Mainrules1`. The ruleset already protects `main`. Decision 1 names the three Security checks to add there if these gates should block merges.
