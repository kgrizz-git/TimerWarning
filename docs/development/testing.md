# Development and testing

## Safety-first testing rules

Full rules: [SAFETY.md](../SAFETY.md). Summary:

| Rule | Limit |
|------|-------|
| Restricted hours in test config | ≤ 6 hours per day total |
| Check interval in tests | ≥ 5 minutes |
| Min popup display in tests | ≤ 60 seconds |
| Live installed config | **Do not modify** during restricted/blocked hours |
| Test HOME | Use `mktemp -d` isolation when install/configure runs |

## Recommended commands

```bash
# macOS / Linux — unit tests (safe, no GUI)
bash tests/test-platform-darwin.sh
bash tests/test-popup-safety-darwin.sh

# Linux-only suites — run on Linux host
# See tests/README.md
```

## Execution guidelines

- Run at most **3** heavy tests at a time (especially `expect` suites).
- Always use **timeout** (60–300s) for interactive tests.

## Documenting runs

Record results in `dev-docs/testing-assessments/test-history.md` per project convention.

## Agent installs

Do not run `./install.sh` against a developer’s primary macOS account without confirming they know emergency stop:

`launchctl bootout gui/$(id -u)/com.sleep-warning`

Prefer temp `HOME` installs during agent sessions.
