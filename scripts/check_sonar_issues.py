#!/usr/bin/env python3
"""Fail when a local SonarQube scan adds a BUG or VULNERABILITY.

Accepted debt lives in scripts/sonar-issues-baseline.json, keyed by rule and
file with a count. Line numbers are ignored because they shift under unrelated
edits. CODE_SMELL is printed by the scan and is not gated: severity is not
gated either, because a critical smell is often complexity rather than a defect.

--update only removes resolved keys or lowers a count. A new key or a higher
count stays a hand edit of the baseline, with a note.

A missing dump exits 0 when no scan state matches the commit being pushed.
If the state file names that commit and the dump is gone, the check fails.
A dump whose commit is not one of the commits being pushed is ignored, so a
leftover dump cannot block or approve a different commit. An empty dump does
not erase a non-empty baseline. SKIP_LOCAL_SONAR=1 exits 0.

Usage:
    python3 scripts/check_sonar_issues.py --strict
    python3 scripts/check_sonar_issues.py --strict --push <sha> [<sha>...]
    python3 scripts/check_sonar_issues.py --update
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_BASELINE = REPO_ROOT / "scripts" / "sonar-issues-baseline.json"
DEFAULT_ISSUES = REPO_ROOT / "tmp" / "sonar-latest-issues.json"
DEFAULT_STATE = REPO_ROOT / "tmp" / "sonar-state.json"
GATED_TYPES = ("BUG", "VULNERABILITY")


def issue_key(issue: dict[str, Any]) -> str:
    """Identity is rule plus path. The project key is the text before the first colon."""
    component = str(issue.get("component") or "")
    path = component.split(":", 1)[1] if ":" in component else (component or "?")
    return f"{issue.get('rule', '?')}|{path}"


def collect_gated(issues: list[dict[str, Any]]) -> dict[str, int]:
    """Count BUG and VULNERABILITY issues by rule and file."""
    counts: dict[str, int] = {}
    for issue in issues:
        if str(issue.get("type", "")).upper() not in GATED_TYPES:
            continue
        key = issue_key(issue)
        counts[key] = counts.get(key, 0) + 1
    return counts


def load_baseline(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"schema": 1, "gated_types": list(GATED_TYPES), "issues": {}}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise SystemExit(f"sonar-issues baseline unreadable: {exc}") from exc
    if not isinstance(data, dict) or not isinstance(data.get("issues"), dict):
        raise SystemExit(f"sonar-issues baseline malformed: {path}")
    for key, entry in data["issues"].items():
        if not isinstance(entry, dict):
            raise SystemExit(f"sonar-issues baseline malformed: {key!r} is not an object")
        try:
            int(entry.get("count", 1))
        except (TypeError, ValueError):
            raise SystemExit(
                f"sonar-issues baseline malformed: {key!r} count is {entry.get('count')!r}"
            ) from None
    return data


def load_dump(path: Path) -> dict[str, Any] | None:
    """Return the dump, None when it is absent, or exit on a corrupt strict dump."""
    if not path.exists():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"sonar-issues: could not read {path}: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
    if not isinstance(data, dict) or not isinstance(data.get("issues"), list):
        print(f"sonar-issues: {path} has no issues array.", file=sys.stderr)
        raise SystemExit(1)
    if not str(data.get("commit") or "").strip():
        print("sonar-issues: dump has no commit, so it cannot be matched to a scan.", file=sys.stderr)
        raise SystemExit(1)
    issues = data["issues"]
    if any(not isinstance(item, dict) for item in issues):
        print("sonar-issues: dump contains a non-object issue.", file=sys.stderr)
        raise SystemExit(1)
    if any(not str(item.get("type") or "").strip() for item in issues):
        print("sonar-issues: dump has issues with no type; refusing to treat that as clean.", file=sys.stderr)
        raise SystemExit(1)
    return data


def state_commit(path: Path) -> str:
    """Commit recorded by the scan, or empty when there is no usable state."""
    if not path.is_file():
        return ""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return ""
    if not isinstance(data, dict):
        return ""
    return str(data.get("commit") or "")


def compare(
    recorded: dict[str, Any], current: dict[str, int]
) -> tuple[list[str], list[str], list[str], list[str]]:
    """Return new keys, counts above the baseline, resolved keys, and lowered counts."""
    baseline = recorded.get("issues", {})
    new_keys = sorted(key for key in current if key not in baseline)
    over = sorted(
        key
        for key in current
        if key in baseline and current[key] > int(baseline[key].get("count", 1))
    )
    resolved = sorted(key for key in baseline if key not in current)
    shrunk = sorted(
        key
        for key in current
        if key in baseline and current[key] < int(baseline[key].get("count", 1))
    )
    return new_keys, over, resolved, shrunk


def apply_update(
    path: Path,
    baseline: dict[str, Any],
    current: dict[str, int],
    resolved: list[str],
    shrunk: list[str],
) -> None:
    """Drop gone keys and lower counts. Never add a key and never raise a count."""
    kept: dict[str, Any] = {}
    for key, entry in baseline.get("issues", {}).items():
        if key not in current:
            continue
        if key in shrunk:
            updated = dict(entry)
            updated["count"] = current[key]
            kept[key] = updated
        else:
            kept[key] = entry
    payload = {"schema": 1, "gated_types": list(GATED_TYPES), "issues": kept}
    # The path is the fixed baseline file. The text is the ratchet we just built.
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")  # NOSONAR pythonsecurity:S2083
    print(f"sonar-issues: ratcheted baseline down ({len(resolved)} resolved, {len(shrunk)} lowered).")


def head_commit() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def _expected(push: bool, commits: list[str]) -> list[str]:
    if push:
        return commits
    return [head_commit()]


def _missing_dump(issues_path: Path, state_path: Path, expected: list[str]) -> int:
    scanned = state_commit(state_path)
    if scanned and scanned in expected:
        print(
            "sonar-issues: a scan is recorded for this commit but the issue dump is missing. "
            "Run bash scripts/sonar_scan.sh again.",
            file=sys.stderr,
        )
        return 1
    print(f"sonar-issues: no issue dump at {issues_path}; run bash scripts/sonar_scan.sh to enable this gate.")
    return 0


def _vanish_message() -> int:
    print(
        "sonar-issues: every baselined bug and vulnerability is absent from this dump. "
        "That is more likely an empty dump than a fixed backlog, so it is not treated as clean.",
        file=sys.stderr,
    )
    print(
        "sonar-issues: re-run bash scripts/sonar_scan.sh. To accept an empty result, "
        "edit the baseline by hand and say why.",
        file=sys.stderr,
    )
    return 1


def _report_new(new_keys: list[str], over: list[str], current: dict[str, int], baseline: dict[str, Any], baseline_path: Path) -> None:
    print("sonar-issues: ungated BUG/VULNERABILITY issues:", file=sys.stderr)
    for key in new_keys:
        print(f"  NEW     {key} (x{current[key]})", file=sys.stderr)
    for key in over:
        allowed = int(baseline["issues"][key].get("count", 1))
        print(f"  EXCEEDS {key}: baseline allows {allowed}, found {current[key]}", file=sys.stderr)
    print(
        "sonar-issues: fix them, or add them to "
        f"{baseline_path} with a note explaining why they are accepted.",
        file=sys.stderr,
    )


def run(
    *,
    baseline_path: Path = DEFAULT_BASELINE,
    issues_path: Path = DEFAULT_ISSUES,
    state_path: Path = DEFAULT_STATE,
    strict: bool = False,
    update: bool = False,
    push: bool = False,
    commits: list[str] | None = None,
) -> int:
    """Return 0 when the push may proceed. Exit via SystemExit only for a bad dump."""
    if os.environ.get("SKIP_LOCAL_SONAR", "") == "1":
        print("sonar-issues: SKIP_LOCAL_SONAR=1 — skipping")
        return 0
    chosen = commits or []
    if push and not chosen:
        print("sonar-issues: push has no commits to check.")
        return 0
    expected = _expected(push, chosen)
    if not issues_path.exists():
        return _missing_dump(issues_path, state_path, expected)
    dump = load_dump(issues_path)
    if dump is None:
        return _missing_dump(issues_path, state_path, expected)
    scanned = str(dump.get("commit") or "")
    if scanned not in expected:
        print(f"sonar-issues: dump is for {scanned}, not this push. It was not used.")
        return 0
    return _finish(dump, baseline_path, strict=strict, update=update)


def _finish(dump: dict[str, Any], baseline_path: Path, *, strict: bool, update: bool) -> int:
    """Compare one dump with the baseline and return the gate status."""
    current = collect_gated(dump["issues"])
    baseline = load_baseline(baseline_path)
    new_keys, over, resolved, shrunk = compare(baseline, current)
    if baseline.get("issues") and not current:
        return _vanish_message()
    if update:
        return _apply(baseline_path, baseline, current, new_keys, over, resolved, shrunk)
    if new_keys or over:
        _report_new(new_keys, over, current, baseline, baseline_path)
        return 1 if strict else 0
    return _report_clean(current, resolved)


def _report_clean(current: dict[str, int], resolved: list[str]) -> int:
    instances = sum(current.values())
    print(
        f"sonar-issues: OK — {len(current)} gated rule/file key(s) "
        f"({instances} issue instance(s)), all baselined."
    )
    if resolved:
        print(f"sonar-issues: {len(resolved)} baselined issue(s) are gone. Run --update to lower the baseline.")
    return 0


def _apply(
    baseline_path: Path,
    baseline: dict[str, Any],
    current: dict[str, int],
    new_keys: list[str],
    over: list[str],
    resolved: list[str],
    shrunk: list[str],
) -> int:
    if resolved or shrunk:
        apply_update(baseline_path, baseline, current, resolved, shrunk)
    else:
        print("sonar-issues: baseline already minimal; nothing to ratchet.")
    if not new_keys and not over:
        return 0
    print("sonar-issues: new debt was not added to the baseline.", file=sys.stderr)
    for key in new_keys:
        print(f"  + {key}", file=sys.stderr)
    for key in over:
        allowed = int(baseline["issues"][key].get("count", 1))
        print(f"  ! {key}: baseline allows {allowed}, found {current[key]}", file=sys.stderr)
    return 1


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--update", action="store_true")
    parser.add_argument(
        "--push",
        action="store_true",
        help="The following arguments are commits being pushed. With none, only deletes were pushed.",
    )
    parser.add_argument("commits", nargs="*")
    args = parser.parse_args()
    raise SystemExit(
        run(
            strict=args.strict,
            update=args.update,
            push=args.push,
            commits=args.commits,
        )
    )


if __name__ == "__main__":
    main()
