#!/usr/bin/env python3
"""Gate behavior for scripts/check_sonar_issues.py. No SonarQube server required."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


GATE = load_module("check_sonar_issues", ROOT / "scripts" / "check_sonar_issues.py")
COLLECT = load_module("sonar_collect", ROOT / "scripts" / "sonar_collect.py")


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

    def invoke(self, **kwargs: object) -> tuple[int, str, str]:
        out, err = io.StringIO(), io.StringIO()
        commits = kwargs.get("commits", ["abc"])
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = GATE.run(
                baseline_path=self.baseline,
                issues_path=kwargs.get("issues", self.issues),
                state_path=self.root / "state.json",
                strict=bool(kwargs.get("strict", False)),
                update=bool(kwargs.get("update", False)),
                push=bool(kwargs.get("push", True)),
                commits=list(commits) if commits is not None else None,
            )
        return code, out.getvalue(), err.getvalue()

    def test_missing_dump_exits_zero(self) -> None:
        code, out, err = self.invoke(issues=self.root / "missing.json", strict=True)
        self.assertEqual(code, 0, err)
        self.assertIn("no issue dump", out)

    def test_missing_dump_fails_when_state_matches(self) -> None:
        (self.root / "state.json").write_text(json.dumps({"commit": "abc", "host": "http://127.0.0.1:9000"}) + "\n", encoding="utf-8")
        code, _out, err = self.invoke(issues=self.root / "missing.json", strict=True)
        self.assertEqual(code, 1)
        self.assertIn("issue dump is missing", err)

    def test_code_smell_is_not_gated(self) -> None:
        self.write_dump(
            [{"rule": "python:S3776", "component": "timer-warning:lib/a.py", "type": "CODE_SMELL", "severity": "CRITICAL"}]
        )
        code, _out, err = self.invoke(strict=True)
        self.assertEqual(code, 0, err)

    def test_new_bug_fails_strict(self) -> None:
        self.write_dump(
            [{"rule": "python:S123", "component": "timer-warning:lib/a.py", "type": "BUG", "severity": "MAJOR"}]
        )
        code, _out, err = self.invoke(strict=True)
        self.assertEqual(code, 1)
        self.assertIn("NEW", err)
        self.assertIn("python:S123|lib/a.py", err)

    def test_same_count_passes_and_update_does_not_add(self) -> None:
        self.baseline.write_text(
            json.dumps({"schema": 1, "issues": {"python:S123|lib/a.py": {"count": 1, "note": "accepted"}}}) + "\n",
            encoding="utf-8",
        )
        self.write_dump(
            [
                {"rule": "python:S123", "component": "timer-warning:lib/a.py", "type": "VULNERABILITY"},
                {"rule": "python:S123", "component": "timer-warning:lib/a.py", "type": "BUG"},
            ]
        )
        code, _out, err = self.invoke(strict=True)
        self.assertEqual(code, 1, err)
        self.assertIn("EXCEEDS", err)
        code, _out, err = self.invoke(update=True)
        self.assertEqual(code, 1, err)
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
        self.write_dump([{"rule": "python:S1", "component": "timer-warning:lib/a.py", "type": "BUG"}])
        code, _out, err = self.invoke(update=True)
        self.assertEqual(code, 0, err)
        kept = json.loads(self.baseline.read_text(encoding="utf-8"))
        self.assertEqual(kept["issues"]["python:S1|lib/a.py"]["count"], 1)
        self.assertNotIn("python:S2|lib/b.py", kept["issues"])

    def test_empty_dump_does_not_wipe_baseline(self) -> None:
        self.baseline.write_text(
            json.dumps({"schema": 1, "issues": {"python:S1|lib/a.py": {"count": 1, "note": "kept"}}}) + "\n",
            encoding="utf-8",
        )
        self.write_dump([])
        code, _out, err = self.invoke(update=True)
        self.assertEqual(code, 1)
        self.assertIn("not treated as clean", err)
        kept = json.loads(self.baseline.read_text(encoding="utf-8"))
        self.assertEqual(kept["issues"]["python:S1|lib/a.py"]["count"], 1)

    def test_other_commit_is_ignored(self) -> None:
        self.write_dump(
            [{"rule": "python:S123", "component": "timer-warning:lib/a.py", "type": "BUG"}],
            commit="old",
        )
        code, out, err = self.invoke(strict=True, commits=["new"])
        self.assertEqual(code, 0, err)
        self.assertIn("not this push", out)

    def test_delete_only_push_passes(self) -> None:
        code, _out, err = self.invoke(strict=True, commits=[])
        self.assertEqual(code, 0, err)

    def test_non_object_issue_is_rejected(self) -> None:
        self.issues.write_text(json.dumps({"commit": "abc", "issues": ["nope"]}) + "\n", encoding="utf-8")
        with self.assertRaises(SystemExit):
            self.invoke(strict=True)

    def test_dump_without_commit_is_rejected(self) -> None:
        self.issues.write_text(json.dumps({"issues": []}) + "\n", encoding="utf-8")
        with self.assertRaises(SystemExit):
            self.invoke(strict=True)


class IssuePageTests(unittest.TestCase):
    def test_empty_page_before_total_is_rejected(self) -> None:
        with self.assertRaises(SystemExit):
            COLLECT.take_page([], [], 3)

    def test_full_page_finishes(self) -> None:
        done = COLLECT.take_page([], [{"rule": "python:S1", "type": "BUG"}], 1)
        self.assertTrue(done)


if __name__ == "__main__":
    unittest.main(verbosity=2)
