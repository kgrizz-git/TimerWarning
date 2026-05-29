# Versioning and releases

This project uses [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html) and documents changes in [CHANGELOG.md](../../CHANGELOG.md) using [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.

**Version source of truth:** `CHANGELOG.md` + git tags (`vMAJOR.MINOR.PATCH`). There is no embedded version constant in install scripts today.

## Day-to-day (agents and contributors)

When you ship user-visible or safety-relevant behavior:

1. Add an entry under **`## [Unreleased]`** in [CHANGELOG.md](../../CHANGELOG.md).
2. Use the correct subsection: **Added**, **Changed**, **Deprecated**, **Removed**, **Fixed**, **Security**.
3. Write for end users — what changed and why it matters, not internal refactors unless they affect behavior or safety.
4. Do **not** bump the version number or create a git tag unless the user explicitly asks for a release.

Internal-only changes (dev-docs reorg, agent harness docs, test-only work) may skip CHANGELOG unless the change is notable for maintainers.

## Semver bump rules (this project)

| Bump | When | Examples |
|------|------|----------|
| **MAJOR** (`X.0.0`) | Breaking change for installed users: config schema change requiring migration, removed CLI flags, scheduler identity change, behavior that invalidates existing configs without a safe fallback | Renaming config keys without backward compatibility; removing emergency-stop paths |
| **MINOR** (`x.Y.0`) | New backward-compatible capability | macOS support, new configure option, new popup safety guard, new platform adapter |
| **PATCH** (`x.y.Z`) | Backward-compatible bug fix or small UX polish | Cancel-menu loop fix, dialog z-order fix, typo in user-facing text |

**Safety fixes:** Treat regressions that could cause lockout, stuck modals, or 24/7 warnings as high priority. Document under **Fixed** or **Security** in CHANGELOG. If the fix changes documented emergency-stop behavior, consider a **MINOR** or **MAJOR** bump depending on user impact.

**Pre-1.0 nuance:** Current released baseline is `1.0.0`. Follow normal semver rules from here.

## CHANGELOG entry quality

Good:

```markdown
### Fixed
- **macOS configure cancel flow:** Cancel on time-range entry no longer loops back to the same dialog.
```

Avoid:

```markdown
### Changed
- Refactored popup-display.sh
```

## Cutting a release (human-initiated)

Only when explicitly requested:

1. Decide the version from accumulated `[Unreleased]` entries (semver rules above).
2. In [CHANGELOG.md](../../CHANGELOG.md):
   - Rename `## [Unreleased]` → `## [X.Y.Z] - YYYY-MM-DD`
   - Add a fresh empty `## [Unreleased]` section at the top.
3. Commit the changelog update.
4. Tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
5. Push branch and tag when the user asks to publish.
6. Optional: create a GitHub Release from the tag; copy the version section from CHANGELOG into release notes (see [dev-docs/info/DISTRIBUTION_OPTIONS_DETAILED.md](../../dev-docs/info/DISTRIBUTION_OPTIONS_DETAILED.md)).

Agents: do not tag or push releases unless the user explicitly requests it.

## Related docs

| Doc | Role |
|-----|------|
| [agent-workflow.md](../agent-workflow.md) | When to update CHANGELOG after a change |
| [testing.md](testing.md) | Verify before release |
| [SAFETY.md](../SAFETY.md) | Safety checklist before popup/scheduler/config releases |
