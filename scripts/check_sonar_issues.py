#!/usr/bin/env python3
"""Fail when a local SonarQube scan adds a BUG or VULNERABILITY.

Accepted debt lives in scripts/sonar-issues-baseline.json, keyed by rule and
file with a count. Line numbers are ignored because they shift under unrelated
edits. CODE_SMELL is printed by the scan and is not gated: severity is not
gated either, because a critical smell is often complexity rather than a defect.

--update only removes resolved keys or lowers a count. A new key or a higher
count stays a hand edit of the baseline, with a note.

A missing dump exits 0 so a machine that has not scanned can still push.
A dump whose commit is not one of the commits being pushed is ignored, so a
leftover dump cannot block or approve a different commit. SKIP_LOCAL_SONAR=1
exits 0.

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
        print(f"sonar-issues: no issue dump at {path}; run bash scripts/sonar_scan.sh to enable this gate.")
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"sonar-issues: could not read {path}: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
    if not isinstance(data, dict) or not isinstance(data.get("issues"), list):
        print(f"sonar-issues: {path} has no issues array.", file=sys.stderr)
        raise SystemExit(1)
    untyped = [item for item in data["issues"] if isinstance(item, dict) and not str(item.get("type") or "").strip()]
    if untyped:
        print("sonar-issues: dump has issues with no type; refusing to treat that as clean.", file=sys.stderr)
        raise SystemExit(1)
    return data


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
    payload = dict(baseline)
    payload["issues"] = kept
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
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


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--issues", type=Path, default=DEFAULT_ISSUES)
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--update", action="store_true")
    parser.add_argument(
        "--push",
        action="store_true",
        help="The following arguments are commits being pushed. With none, only deletes were pushed.",
    )
    parser.add_argument("commits", nargs="*")
    args = parser.parse_args()

    if os.environ.get("SKIP_LOCAL_SONAR", "") == "1":
        print("sonar-issues: SKIP_LOCAL_SONAR=1 — skipping")
        return

    if args.push and not args.commits:
        print("sonar-issues: push has no commits to check.")
        return

    dump = load_dump(args.issues)
    if dump is None:
        return

    expected = args.commits if args.push else [head_commit()]
    scanned = str(dump.get("commit", ""))
    if scanned not in expected:
        print(
            f"sonar-issues: dump is for {scanned or 'an unknown commit'}, "
            "not this push. It was not used."
        )
        return

    issues = [item for item in dump["issues"] if isinstance(item, dict)]
    current = collect_gated(issues)
    baseline = load_baseline(args.baseline)
    new_keys, over, resolved, shrunk = compare(baseline, current)

    if args.update:
        if resolved or shrunk:
            apply_update(args.baseline, baseline, current, resolved, shrunk)
        else:
            print("sonar-issues: baseline already minimal; nothing to ratchet.")
        if new_keys or over:
            print("sonar-issues: new debt was not added to the baseline.", file=sys.stderr)
            for key in new_keys:
                print(f"  + {key}", file=sys.stderr)
            for key in over:
                allowed = int(baseline["issues"][key].get("count", 1))
                print(f"  ! {key}: baseline allows {allowed}, found {current[key]}", file=sys.stderr)
            raise SystemExit(1)
        return

    if new_keys or over:
        print("sonar-issues: ungated BUG/VULNERABILITY issues:", file=sys.stderr)
        for key in new_keys:
            print(f"  NEW     {key} (x{current[key]})", file=sys.stderr)
        for key in over:
            allowed = int(baseline["issues"][key].get("count", 1))
            print(f"  EXCEEDS {key}: baseline allows {allowed}, found {current[key]}", file=sys.stderr)
        print(
            "sonar-issues: fix them, or add them to "
            f"{args.baseline} with a note explaining why they are accepted.",
            file=sys.stderr,
        )
        if args.strict:
            raise SystemExit(1)
        return

    instances = sum(current.values())
    print(
        f"sonar-issues: OK — {len(current)} gated rule/file key(s) "
        f"({instances} issue instance(s)), all baselined."
    )
    if resolved:
        print(f"sonar-issues: {len(resolved)} baselined issue(s) are gone. Run --update to lower the baseline.")


if __name__ == "__main__":
    main()
