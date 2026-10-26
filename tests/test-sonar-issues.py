#!/usr/bin/env python3
"""Gate behavior for scripts/check_sonar_issues.py. No SonarQube server required."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CHECK = ROOT / "scripts" / "check_sonar_issues.py"


def run_check(baseline: Path, issues: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(CHECK), "--baseline", str(baseline), "--issues", str(issues), *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


class SonarIssueGateTests(unittest.TestCase):
    def setUp(self) -> None:
        self._dir = tempfile.TemporaryDirectory(prefix="sonar-issues.")
        self.root = Path(self._dir.name)
        self.baseline = self.root / "baseline.json"
        self.issues = self.root / "issues.json"
        self.baseline.write_text(
            json.dumps({"schema": 1, "gated_types": ["BUG", "VULNERABILITY"], "issues": {}}) + "\n",
            encoding="utf-8",
        )

    def tearDown(self) -> None:
        self._dir.cleanup()

    def write_dump(self, issues: list[dict], commit: str = "abc") -> None:
        self.issues.write_text(
            json.dumps({"commit": commit, "host": "http://localhost:9000", "issues": issues}) + "\n",
            encoding="utf-8",
        )

    def test_missing_dump_exits_zero(self) -> None:
        result = run_check(self.baseline, self.root / "missing.json", "--strict", "--push", "abc")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("no issue dump", result.stdout)

    def test_code_smell_is_not_gated(self) -> None:
        self.write_dump(
            [{"rule": "python:S3776", "component": "timer-warning:lib/a.py", "type": "CODE_SMELL", "severity": "CRITICAL"}]
        )
        result = run_check(self.baseline, self.issues, "--strict", "--push", "abc")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_new_bug_fails_strict(self) -> None:
        self.write_dump(
            [{"rule": "python:S123", "component": "timer-warning:lib/a.py", "type": "BUG", "severity": "MAJOR"}]
        )
        result = run_check(self.baseline, self.issues, "--strict", "--push", "abc")
        self.assertEqual(result.returncode, 1)
        self.assertIn("NEW", result.stderr)
        self.assertIn("python:S123|lib/a.py", result.stderr)

    def test_same_count_passes_and_update_does_not_add(self) -> None:
        self.baseline.write_text(
            json.dumps(
                {
                    "schema": 1,
                    "issues": {"python:S123|lib/a.py": {"count": 1, "note": "accepted"}},
                }
            )
            + "\n",
            encoding="utf-8",
        )
        self.write_dump(
            [
                {"rule": "python:S123", "component": "timer-warning:lib/a.py", "type": "VULNERABILITY"},
                {"rule": "python:S123", "component": "timer-warning:lib/a.py", "type": "BUG"},
            ]
        )
        over = run_check(self.baseline, self.issues, "--strict", "--push", "abc")
        self.assertEqual(over.returncode, 1, over.stderr)
        self.assertIn("EXCEEDS", over.stderr)
        added = run_check(self.baseline, self.issues, "--update", "--push", "abc")
        self.assertEqual(added.returncode, 1)
        kept = json.loads(self.baseline.read_text(encoding="utf-8"))
        self.assertEqual(kept["issues"]["python:S123|lib/a.py"]["count"], 1)

    def test_update_lowers_and_removes(self) -> None:
        self.baseline.write_text(
            json.dumps(
                {
                    "schema": 1,
                    "issues": {
                        "python:S1|lib/a.py": {"count": 2, "note": "two"},
                        "python:S2|lib/b.py": {"count": 1, "note": "gone"},
                    },
                }
            )
            + "\n",
            encoding="utf-8",
        )
        self.write_dump(
            [{"rule": "python:S1", "component": "timer-warning:lib/a.py", "type": "BUG"}]
        )
        result = run_check(self.baseline, self.issues, "--update", "--push", "abc")
        self.assertEqual(result.returncode, 0, result.stderr)
        kept = json.loads(self.baseline.read_text(encoding="utf-8"))
        self.assertEqual(kept["issues"]["python:S1|lib/a.py"]["count"], 1)
        self.assertNotIn("python:S2|lib/b.py", kept["issues"])

    def test_other_commit_is_ignored(self) -> None:
        self.write_dump(
            [{"rule": "python:S123", "component": "timer-warning:lib/a.py", "type": "BUG"}],
            commit="old",
        )
        result = run_check(self.baseline, self.issues, "--strict", "--push", "new")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("not this push", result.stdout)

    def test_delete_only_push_passes(self) -> None:
        result = run_check(self.baseline, self.issues, "--strict", "--push")
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
