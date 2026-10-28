#!/usr/bin/env python3
"""The shell-coverage parser keeps nested xtrace lines.

A command substitution is traced as "++file:line:", not "+file:line:".
The old pattern treated the extra plus as part of the path and dropped it.
"""

from __future__ import annotations

import contextlib
import io
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
    def _check(self, baseline, covered):
        with contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(
            io.StringIO()
        ):
            return report.check_floor(baseline, "darwin", covered, 10)

    def test_slack_allows_a_small_drop(self):
        floor = {"covered_lines": 8, "statements": 10, "slack_lines": 1}
        self.assertEqual(self._check(floor, 7), 0)

    def test_drop_past_slack_fails(self):
        floor = {"covered_lines": 8, "statements": 10, "slack_lines": 1}
        self.assertEqual(self._check(floor, 6), 1)

    def test_slack_defaults_to_zero(self):
        floor = {"covered_lines": 8, "statements": 10}
        self.assertEqual(self._check(floor, 7), 1)

    def test_os_object_overrides_the_flat_floor(self):
        floor = {
            "covered_lines": 8,
            "statements": 10,
            "slack_lines": 5,
            "darwin": {"covered_lines": 9, "statements": 10},
        }
        self.assertEqual(self._check(floor, 8), 1)

    def test_malformed_floor_fails(self):
        self.assertEqual(self._check({"darwin": {"covered_lines": 1}}, 10), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
