#!/usr/bin/env python3
"""Unit tests for scripts/sonarcloud_pr_issues.py.

The SonarCloud API and the gh and git calls are mocked, so nothing here touches the
network. Run: python3 tests/test-sonarcloud-pr-issues.py
"""

from __future__ import annotations

import io
import sys
import unittest
import urllib.error
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from typing import Any
from unittest import mock

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import sonarcloud_pr_issues as sc  # noqa: E402

HEAD = "e21e27272667f1f10751139c88461d70ed004a65"
OLD = "34d6ca52f8a978c7c018efb9bdc98562eb9241d7"


def issue(path: str, line: int, rule: str = "shell:S7688", severity: str = "MAJOR") -> dict[str, Any]:
    return {
        "component": f"kgrizz-git_TimerWarning:{path}",
        "line": line,
        "rule": rule,
        "severity": severity,
        "message": "Use '[[' instead of '['.",
    }


def pulls(sha: str | None, key: str = "3") -> dict[str, Any]:
    pull: dict[str, Any] = {"key": key}
    if sha is not None:
        pull["commit"] = {"sha": sha}
    return {"pullRequests": [pull]}


class FormatTests(unittest.TestCase):
    def test_format_strips_the_project_key(self):
        text = sc.format_issue(issue("lib/a.sh", 12, "shelldre:S131", "CRITICAL"))
        self.assertEqual(text, "lib/a.sh:12 shelldre:S131 CRITICAL Use '[[' instead of '['.")

    def test_format_tolerates_missing_fields(self):
        self.assertEqual(sc.format_issue({}), ":? ? ? ")


class FetchIssuesTests(unittest.TestCase):
    def test_one_page(self):
        data = {"total": 2, "issues": [issue("a.sh", 1), issue("b.sh", 2)]}
        with mock.patch.object(sc, "fetch_json", return_value=data) as fetch:
            self.assertEqual(len(sc.fetch_issues("3")), 2)
        params = fetch.call_args.args[1]
        self.assertEqual(params["pullRequest"], "3")
        self.assertEqual(params["inNewCodePeriod"], "true")
        self.assertEqual(params["resolved"], "false")

    def test_pages_until_the_total_is_reached(self):
        pages = [
            {"total": 3, "issues": [issue("a.sh", 1), issue("a.sh", 2)]},
            {"total": 3, "issues": [issue("a.sh", 3)]},
        ]
        with mock.patch.object(sc, "fetch_json", side_effect=pages) as fetch:
            self.assertEqual(len(sc.fetch_issues("3")), 3)
        self.assertEqual([c.args[1]["p"] for c in fetch.call_args_list], ["1", "2"])

    def test_an_empty_page_stops_the_loop(self):
        with mock.patch.object(sc, "fetch_json", return_value={"total": 5, "issues": []}) as fetch:
            self.assertEqual(sc.fetch_issues("3"), [])
        self.assertEqual(fetch.call_count, 1)


class AnalyzedCommitTests(unittest.TestCase):
    def test_finds_the_pull_request(self):
        with mock.patch.object(sc, "fetch_json", return_value=pulls(HEAD)):
            self.assertEqual(sc.analyzed_commit("3"), HEAD)

    def test_other_pull_requests_are_ignored(self):
        with mock.patch.object(sc, "fetch_json", return_value=pulls(HEAD, key="9")):
            self.assertIsNone(sc.analyzed_commit("3"))

    def test_a_pull_request_without_a_commit(self):
        with mock.patch.object(sc, "fetch_json", return_value=pulls(None)):
            self.assertIsNone(sc.analyzed_commit("3"))


class WaitTests(unittest.TestCase):
    def test_returns_at_once_when_the_commit_matches(self):
        with mock.patch.object(sc, "analyzed_commit", return_value=HEAD), \
                mock.patch.object(sc.time, "sleep") as sleep:
            self.assertTrue(sc.wait_for_commit("3", HEAD, 60))
        sleep.assert_not_called()

    def test_polls_until_the_commit_matches(self):
        with mock.patch.object(sc, "analyzed_commit", side_effect=[OLD, OLD, HEAD]), \
                mock.patch.object(sc.time, "sleep") as sleep:
            self.assertTrue(sc.wait_for_commit("3", HEAD, 60, poll=5))
        self.assertEqual(sleep.call_count, 2)

    def test_gives_up_after_the_deadline(self):
        clock = iter([0.0, 5.0, 11.0])
        with mock.patch.object(sc, "analyzed_commit", return_value=OLD), \
                mock.patch.object(sc.time, "sleep"), \
                mock.patch.object(sc.time, "monotonic", side_effect=lambda: next(clock)):
            self.assertFalse(sc.wait_for_commit("3", HEAD, 10, poll=5))


class MainTests(unittest.TestCase):
    def run_main(self, argv: list[str], *, head: str = HEAD, analyzed: str | None = HEAD,
                 issues: list[dict[str, Any]] | None = None, pr: str = "3") -> tuple[int, str, str]:
        def fake_run_text(command: list[str]) -> str:
            return pr if command[0] == "gh" else head

        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(sc, "run_text", side_effect=fake_run_text), \
                mock.patch.object(sc, "analyzed_commit", return_value=analyzed), \
                mock.patch.object(sc, "fetch_issues", return_value=issues or []), \
                redirect_stdout(out), redirect_stderr(err):
            code = sc.main(argv)
        return code, out.getvalue(), err.getvalue()

    def test_clean_pull_request(self):
        code, out, _err = self.run_main([])
        self.assertEqual(code, 0)
        self.assertIn("analyzed at e21e272", out)
        self.assertIn("0 new issue(s)", out)

    def test_issues_exit_one_and_are_sorted(self):
        found = [issue("tests/b.sh", 9), issue("lib/a.sh", 30), issue("lib/a.sh", 4)]
        code, out, _err = self.run_main([], issues=found)
        self.assertEqual(code, 1)
        lines = [line for line in out.splitlines() if "S7688" in line]
        self.assertEqual([line.split()[0] for line in lines], ["lib/a.sh:4", "lib/a.sh:30", "tests/b.sh:9"])
        self.assertIn("3 new issue(s)", out)

    def test_a_clean_but_stale_analysis_is_not_a_pass(self):
        code, out, _err = self.run_main([], analyzed=OLD)
        self.assertEqual(code, 2)
        self.assertIn("local HEAD is e21e272", out)

    def test_issues_win_over_staleness(self):
        code, _out, _err = self.run_main([], analyzed=OLD, issues=[issue("a.sh", 1)])
        self.assertEqual(code, 1)

    def test_no_analysis_yet(self):
        code, _out, err = self.run_main([], analyzed=None)
        self.assertEqual(code, 2)
        self.assertIn("no analysis yet", err)

    def test_no_pull_request_found(self):
        code, _out, err = self.run_main([], pr="")
        self.assertEqual(code, 2)
        self.assertIn("no PR number", err)

    def test_an_explicit_pr_number_skips_gh(self):
        with mock.patch.object(sc, "run_text", return_value=HEAD) as run_text, \
                mock.patch.object(sc, "analyzed_commit", return_value=HEAD), \
                mock.patch.object(sc, "fetch_issues", return_value=[]), \
                redirect_stdout(io.StringIO()):
            self.assertEqual(sc.main(["7"]), 0)
        self.assertEqual([c.args[0][0] for c in run_text.call_args_list], ["git"])

    def test_wait_timeout_exits_two(self):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(sc, "run_text", return_value=HEAD), \
                mock.patch.object(sc, "wait_for_commit", return_value=False) as wait, \
                redirect_stdout(out), redirect_stderr(err):
            code = sc.main(["3", "--wait", "30"])
        self.assertEqual(code, 2)
        wait.assert_called_once_with("3", HEAD, 30)
        self.assertIn("not analyzed at e21e272", err.getvalue())

    def test_wait_without_a_local_head_exits_two_and_never_polls(self):
        err = io.StringIO()
        with mock.patch.object(sc, "run_text", return_value=""), \
                mock.patch.object(sc, "wait_for_commit") as wait, \
                mock.patch.object(sc, "analyzed_commit") as analyzed, \
                redirect_stdout(io.StringIO()), redirect_stderr(err):
            code = sc.main(["3", "--wait", "30"])
        self.assertEqual(code, 2)
        wait.assert_not_called()
        analyzed.assert_not_called()
        self.assertIn("needs the local HEAD", err.getvalue())

    def test_no_head_without_wait_still_reports(self):
        with mock.patch.object(sc, "run_text", return_value=""), \
                mock.patch.object(sc, "analyzed_commit", return_value=HEAD), \
                mock.patch.object(sc, "fetch_issues", return_value=[]), \
                redirect_stdout(io.StringIO()):
            self.assertEqual(sc.main(["3"]), 0)

    def test_api_errors_exit_two(self):
        err = io.StringIO()
        with mock.patch.object(sc, "run_text", return_value=HEAD), \
                mock.patch.object(sc, "analyzed_commit", side_effect=urllib.error.URLError("offline")), \
                redirect_stdout(io.StringIO()), redirect_stderr(err):
            code = sc.main(["3"])
        self.assertEqual(code, 2)
        self.assertIn("could not read the API", err.getvalue())


class RunTextTests(unittest.TestCase):
    def test_returns_stdout_on_success(self):
        done = mock.Mock(returncode=0, stdout="abc\n")
        with mock.patch.object(sc.subprocess, "run", return_value=done):
            self.assertEqual(sc.run_text(["git", "rev-parse", "HEAD"]), "abc")

    def test_returns_empty_on_failure(self):
        done = mock.Mock(returncode=1, stdout="boom\n")
        with mock.patch.object(sc.subprocess, "run", return_value=done):
            self.assertEqual(sc.run_text(["gh", "pr", "view"]), "")

    def test_returns_empty_when_the_command_is_missing(self):
        with mock.patch.object(sc.subprocess, "run", side_effect=FileNotFoundError):
            self.assertEqual(sc.run_text(["gh"]), "")


if __name__ == "__main__":
    unittest.main()
