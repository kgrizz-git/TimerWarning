#!/usr/bin/env python3
"""The shell-coverage parser keeps nested xtrace lines.

A command substitution is traced as "++file:line:", not "+file:line:".
The old pattern treated the extra plus as part of the path and dropped it.
"""

from __future__ import annotations

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import shell_coverage_report as report  # noqa: E402


class ParserTests(unittest.TestCase):
    def test_nested_trace_counts_the_real_path(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            lib = root / "lib"
            lib.mkdir()
            source = lib / "sample.sh"
            source.write_text("echo one\necho two\n# comment\n\n", encoding="utf-8")
            log_dir = root / "logs"
            log_dir.mkdir()
            log = log_dir / "1.log"
            log.write_text(
                f"+{source}:1:echo one\n"
                f"++{source}:2:echo two\n"
                "+not a trace line\n",
                encoding="utf-8",
            )
            covered, statements, unparsed = report.count_hits(root, log_dir)
        self.assertEqual(covered, 2)
        self.assertEqual(statements, 2)
        self.assertEqual(unparsed, 1)


class SlackTests(unittest.TestCase):
    def _run(self, baseline, hits):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "lib").mkdir()
            source = (root / "lib" / "sample.sh").resolve()
            source.write_text("".join(f"echo {n}\n" for n in range(10)), encoding="utf-8")
            logs = root / "logs"
            logs.mkdir()
            (logs / "1.log").write_text(
                "".join(f"+{source}:{n}:echo\n" for n in range(1, hits + 1)),
                encoding="utf-8",
            )
            base = root / "base.json"
            base.write_text(json.dumps(baseline), encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(
                io.StringIO()
            ):
                return report.main(["x", str(root), str(logs), str(base), "0"])

    def test_slack_allows_a_small_drop(self):
        floor = {"covered_lines": 8, "statements": 10, "slack_lines": 1}
        self.assertEqual(self._run(floor, 7), 0)

    def test_drop_past_slack_fails(self):
        floor = {"covered_lines": 8, "statements": 10, "slack_lines": 1}
        self.assertEqual(self._run(floor, 6), 1)

    def test_slack_defaults_to_zero(self):
        floor = {"covered_lines": 8, "statements": 10}
        self.assertEqual(self._run(floor, 7), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
