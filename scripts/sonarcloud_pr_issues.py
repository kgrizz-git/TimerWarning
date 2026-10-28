#!/usr/bin/env python3
"""Print the SonarCloud new-code issues for a pull request, the way the PR sees them.

The local SonarQube Community Build has no Shell analyzer, so scripts/sonar_scan.sh
cannot report SonarCloud's shell findings (S7688, S1192, S7679, S131, S1066). This
script reads them from SonarCloud's public API after a push. No token is needed
because the project is public.

SonarCloud analyzes the pull request head within a minute or two of a push. By
default the script reports whatever the last analysis found and says which commit
that was. --wait SECONDS polls until the analysis matches the local HEAD.

Usage:
    python3 scripts/sonarcloud_pr_issues.py            # PR of the current branch
    python3 scripts/sonarcloud_pr_issues.py 3 --wait 180

Exit status:
    0  no new issues, and the analysis is for the local HEAD
    1  new issues, even when the analysis is for another commit
    2  no new issues but the analysis is for another commit, or the PR, the local
       HEAD (with --wait), or the API could not be read
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from typing import Any

API = "https://sonarcloud.io/api"
PROJECT = "kgrizz-git_TimerWarning"
PAGE_SIZE = 500


def fetch_json(path: str, params: dict[str, str]) -> dict[str, Any]:
    """GET one SonarCloud API path and return the decoded JSON object."""
    url = f"{API}/{path}?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=30) as response:
        return json.load(response)


def run_text(command: list[str]) -> str:
    """Run a command and return its stripped stdout, or an empty string on failure."""
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=False)
    except OSError:
        return ""
    return result.stdout.strip() if result.returncode == 0 else ""


def analyzed_commit(pr: str) -> str | None:
    """Return the commit SonarCloud last analyzed for this pull request, if any."""
    data = fetch_json("project_pull_requests/list", {"project": PROJECT})
    for pull in data.get("pullRequests", []):
        if str(pull.get("key")) == pr:
            return pull.get("commit", {}).get("sha")
    return None


def wait_for_commit(pr: str, sha: str, seconds: int, poll: int = 10) -> bool:
    """Poll until the analysis is for *sha*. Return False if *seconds* run out."""
    deadline = time.monotonic() + seconds
    while True:
        if analyzed_commit(pr) == sha:
            return True
        if time.monotonic() >= deadline:
            return False
        time.sleep(poll)


def fetch_issues(pr: str) -> list[dict[str, Any]]:
    """Return every unresolved new-code issue on the pull request."""
    issues: list[dict[str, Any]] = []
    page = 1
    while True:
        data = fetch_json(
            "issues/search",
            {
                "componentKeys": PROJECT,
                "pullRequest": pr,
                "resolved": "false",
                "inNewCodePeriod": "true",
                "ps": str(PAGE_SIZE),
                "p": str(page),
            },
        )
        batch = data.get("issues", [])
        issues.extend(batch)
        if not batch or len(issues) >= int(data.get("total", 0)):
            return issues
        page += 1


def format_issue(issue: dict[str, Any]) -> str:
    """One line: path:line RULE SEVERITY message."""
    path = str(issue.get("component", "")).split(":", 1)[-1]
    line = issue.get("line", "?")
    return f"{path}:{line} {issue.get('rule', '?')} {issue.get('severity', '?')} {issue.get('message', '')}"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n\n")[0])
    parser.add_argument("pr", nargs="?", help="pull request number (default: the current branch's PR)")
    parser.add_argument("--wait", type=int, default=0, metavar="SECONDS",
                        help="wait up to this long for the analysis of the local HEAD")
    args = parser.parse_args(argv)

    pr = args.pr or run_text(["gh", "pr", "view", "--json", "number", "-q", ".number"])
    if not pr:
        print("sonarcloud: no PR number given and gh found none for this branch.", file=sys.stderr)
        return 2
    head = run_text(["git", "rev-parse", "HEAD"])

    if args.wait > 0 and not head:
        print("sonarcloud: --wait needs the local HEAD commit, but git did not return one.", file=sys.stderr)
        return 2

    try:
        if args.wait > 0 and not wait_for_commit(pr, head, args.wait):
            print(f"sonarcloud: PR #{pr} was not analyzed at {head[:7]} within {args.wait}s.", file=sys.stderr)
            return 2
        analyzed = analyzed_commit(pr)
        issues = fetch_issues(pr)
    except (OSError, ValueError) as exc:
        print(f"sonarcloud: could not read the API: {exc}", file=sys.stderr)
        return 2

    if analyzed is None:
        print(f"sonarcloud: PR #{pr} has no analysis yet.", file=sys.stderr)
        return 2
    stale = bool(head) and analyzed != head
    print(f"sonarcloud: PR #{pr} analyzed at {analyzed[:7]}" + (f" (local HEAD is {head[:7]})" if stale else ""))

    for issue in sorted(issues, key=lambda i: (str(i.get("component")), int(i.get("line") or 0))):
        print(format_issue(issue))
    print(f"sonarcloud: {len(issues)} new issue(s).")
    if issues:
        return 1
    return 2 if stale else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
