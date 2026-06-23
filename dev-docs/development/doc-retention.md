# Documentation retention policy

Mechanical garbage collection for historical developer docs. Canonical vs archive boundaries: [canonical-vs-archive.md](../canonical-vs-archive.md).

## Summary

| Category | Location | Retention | Pre-commit |
|----------|----------|-----------|------------|
| Code backups | `backups/` | Last change ≥ **5** commits behind `HEAD` | Auto-delete |
| Timestamped assessments & safety scans | `dev-docs/*-assessments/`, `dev-docs/safety-scans/` | ≥ **30 days** AND ≥ **10 commits** | Report-only |
| Completed plans | `dev-docs/completed-plans/` | ≥ **90 days** AND ≥ **20 commits** | Manual `--apply` only |
| Templates & living docs | `dev-docs/templates/`, `test-tiers.md`, `test-history.md` | Never auto-delete | — |

**Delete when both thresholds are met** (keep until the later gate clears). A file touched in recent commits stays even if the filename date is old; a brand-new file stays even if commit velocity is high.

## Never auto-delete

- `dev-docs/templates/` — source templates for new assessments
- `dev-docs/testing-assessments/test-tiers.md`, `test-history.md` — canonical harness docs
- Anything under `dev-docs/enhancements/` — spec-bound, not point-in-time audits
- Active plans under `dev-docs/plans/` (non-timestamped filenames)
- Files referenced from protected paths (see scripts below)
- Files with `retain: true` in the first 10 lines of YAML frontmatter

## Timestamped archive patterns

Scripts match basenames like:

- `refactor-assessment-2026-06-12-001417.md`
- `testing-assessment-2026-01-26-160020.md`
- `safety-scan-2026-05-30-011454.md`
- Other `*-YYYY-MM-DD-HHMMSS.md` under assessment folders

Non-matching files in those directories are left untouched.

## Commands

### Backups (auto on every commit)

```bash
./scripts/prune-backups.sh --dry-run    # preview
./scripts/prune-backups.sh              # delete + stage (pre-commit default)
```

Default: `backups/`, **5** commits (`MAX_COMMIT_AGE=5`).

### Archive assessments & safety scans

```bash
./scripts/prune-dev-docs-archive.sh              # dry-run (default)
./scripts/prune-dev-docs-archive.sh --apply      # delete eligible + git add -u
```

Environment overrides:

- `ARCHIVE_MIN_DAYS=30`
- `ARCHIVE_MIN_COMMITS=10`
- `ARCHIVE_KEEP_LATEST=1` — always keep newest timestamped file per folder

Pre-commit runs **dry-run only** and prints eligible count. Skip: `SKIP_ARCHIVE_REPORT=1 git commit ...`

### Completed plans (manual housekeeping)

```bash
./scripts/prune-completed-plans.sh --dry-run
./scripts/prune-completed-plans.sh --apply
```

Defaults: **90** days, **20** commits. Not wired to pre-commit.

### Stale active plans (warn-only)

```bash
./scripts/check-stale-plans.sh           # print findings, exit 0
./scripts/check-stale-plans.sh --strict  # exit 1 if any complete plan still in dev-docs/plans/
```

Move flagged files to `dev-docs/completed-plans/` with a "Superseded / archived" banner.

## Notes, fixes, and test history

- **`dev-docs/notes/`**, **`dev-docs/fixes/`** — prune manually once work is captured in CHANGELOG or `completed-plans/`. Same 30+10 rule applies when running archive script on timestamped names only (most notes are not timestamped).
- **`test-history.md`** — living document; trim superseded entries when Tier-A CI covers the test. Do not delete the file.
- **Historical safety-scan records** — do not edit old scan files to update hook wording; they are point-in-time snapshots.

## Local agent cache

`.cursor/hooks/state/` is gitignored runtime cache for Cursor hooks. Safe to delete locally; durable agent memory belongs in [AGENTS.md](../../AGENTS.md) and `dev-docs/`, not hook state files.

## Related

- [security-scanning.md](security-scanning.md) — pre-commit ShellCheck + gitleaks
- [CONTRIBUTING.md](../CONTRIBUTING.md) — git hooks table
- [harness-engineering.md](../harness-engineering.md) — entropy / garbage collection
