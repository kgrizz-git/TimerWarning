#!/usr/bin/env python3
"""Wait for a local SonarQube Compute Engine task and save unresolved issues.

The scanner has already uploaded the report. This script polls that task, then
downloads unresolved issues for the project. SONAR_TOKEN and SONAR_HOST_URL
come from the environment. The token is never read from argv and never printed.

Inputs:
    --task-id       ceTaskId from .scannerwork/report-task.txt
    --project-key   sonar.projectKey
    --commit        git commit that was scanned

The issue dump and the state file are always tmp/sonar-latest-issues.json and
tmp/sonar-state.json. They are not command-line arguments.

Outputs:
    On success, both JSON files and a type/rule count on stdout.
    On HTTP failure, Compute Engine failure, or timeout, exit 1 and leave any
    previous state files untouched.

Requirements: Python 3. The local SonarQube server must already be up.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from collections import Counter
from pathlib import Path
from typing import Any

PAGE_SIZE = 500
MAX_PAGES = 20
POLL_SECONDS = 120


def _request(url: str, token: str) -> tuple[int, dict[str, Any]]:
    """GET a SonarQube API url. The token stays in the Authorization header."""
    request = urllib.request.Request(
        url,
        headers={"Authorization": "Bearer " + token},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:300]
        print(f"SonarQube HTTP {exc.code} for {url.split('?', 1)[0]}: {detail}", file=sys.stderr)
        return exc.code, {}
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        print(f"SonarQube request failed: {exc}", file=sys.stderr)
        return 0, {}
    if not isinstance(payload, dict):
        print("SonarQube response was not a JSON object.", file=sys.stderr)
        return 0, {}
    if payload.get("errors"):
        print(f"SonarQube API errors: {payload['errors']}", file=sys.stderr)
        return 0, {}
    return 200, payload


def wait_for_task(host: str, token: str, task_id: str) -> None:
    """Poll api/ce/task until SUCCESS, or exit on failure or timeout."""
    deadline = time.monotonic() + POLL_SECONDS
    url = f"{host}/api/ce/task?id={task_id}"
    while time.monotonic() < deadline:
        status_code, payload = _request(url, token)
        if status_code != 200:
            raise SystemExit(1)
        status = str(payload.get("task", {}).get("status", ""))
        if status == "SUCCESS":
            return
        if status in {"FAILED", "CANCELED", "CANCELLED", "ERROR"}:
            print(f"Compute Engine task {task_id} finished with status {status}.", file=sys.stderr)
            raise SystemExit(1)
        time.sleep(5)
    print(f"Timed out waiting for Compute Engine task {task_id} after {POLL_SECONDS}s.", file=sys.stderr)
    raise SystemExit(1)


def take_page(collected: list[dict[str, Any]], batch: object, total: int) -> bool:
    """Append one issues page. Return True when the download is finished.

    An empty page before ``total`` is reached is a partial response, not a
    clean project. A non-object issue is the same: dropping it would under-count.
    """
    if not isinstance(batch, list) or any(not isinstance(issue, dict) for issue in batch):
        print("api/issues/search returned a page that is not a list of objects.", file=sys.stderr)
        raise SystemExit(1)
    if not batch and len(collected) < total:
        print(
            f"api/issues/search ended after {len(collected)} of {total} issues.",
            file=sys.stderr,
        )
        raise SystemExit(1)
    for issue in batch:
        collected.append(
            {
                "key": issue.get("key", ""),
                "rule": issue.get("rule", ""),
                "component": issue.get("component", ""),
                "type": issue.get("type", ""),
                "severity": issue.get("severity", ""),
                "message": issue.get("message", ""),
                "line": issue.get("line"),
            }
        )
    return len(collected) >= total or not batch


def fetch_issues(host: str, token: str, project_key: str) -> list[dict[str, Any]]:
    """Download every unresolved issue. Keep the fields the gate and the summary use."""
    collected: list[dict[str, Any]] = []
    total = None
    for page in range(1, MAX_PAGES + 1):
        url = (
            f"{host}/api/issues/search?componentKeys={project_key}"
            f"&resolved=false&ps={PAGE_SIZE}&p={page}"
        )
        status_code, payload = _request(url, token)
        if status_code != 200:
            raise SystemExit(1)
        batch = payload.get("issues")
        if total is None:
            total = int(payload.get("total", len(batch) if isinstance(batch, list) else 0))
        if take_page(collected, batch, total):
            return collected
    print(f"api/issues/search exceeded {MAX_PAGES} pages.", file=sys.stderr)
    raise SystemExit(1)


REPO_ROOT = Path(__file__).resolve().parent.parent
STATE_PATH = REPO_ROOT / "tmp" / "sonar-state.json"
ISSUES_PATH = REPO_ROOT / "tmp" / "sonar-latest-issues.json"


def _write(path: Path, payload: dict[str, Any]) -> None:
    """Write one JSON file under the repo tmp directory.

    path is one of the two fixed locations. The payload is the scan result.
    """
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")  # NOSONAR pythonsecurity:S8707
    os.replace(temporary, path)


def print_summary(issues: list[dict[str, Any]]) -> None:
    """Print counts by type, then by rule and severity. Nothing is gated here."""
    types = Counter(str(issue.get("type") or "UNKNOWN") for issue in issues)
    rules = Counter(
        (str(issue.get("rule") or "?"), str(issue.get("severity") or "?"))
        for issue in issues
    )
    type_text = ", ".join(f"{name} {count}" for name, count in sorted(types.items()))
    print(f"Unresolved: {len(issues)}" + (f" ({type_text})" if type_text else ""))
    for (rule, severity), count in sorted(rules.items()):
        print(f"  {rule} {severity} {count}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task-id", required=True)
    parser.add_argument("--project-key", required=True)
    parser.add_argument("--commit", required=True)
    args = parser.parse_args()

    token = os.environ.get("SONAR_TOKEN", "")
    host = os.environ.get("SONAR_HOST_URL", "http://localhost:9000").rstrip("/")
    if not token:
        print("SONAR_TOKEN is not set.", file=sys.stderr)
        raise SystemExit(1)

    wait_for_task(host, token, args.task_id)
    issues = fetch_issues(host, token, args.project_key)
    recorded = {
        "commit": args.commit,
        "host": host,
        "project_key": args.project_key,
    }
    _write(ISSUES_PATH, {**recorded, "issues": issues})
    _write(STATE_PATH, recorded)
    print_summary(issues)
    print(f"Scan recorded for {args.commit}")


if __name__ == "__main__":
    main()
