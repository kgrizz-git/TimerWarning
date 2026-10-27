#!/usr/bin/env python3
"""Compare bash xtrace hits under lib/*.sh with the per-OS floor.

Reads logs written by scripts/shell-coverage-env.sh. Each trace line looks
like "+/path/file.sh:12:" or "++/path/file.sh:12:" when the line ran inside
a command substitution. The path is everything after the leading plus signs.

Inputs:
    repo root, log directory, "1" to print without comparing. The floor is
    scripts/shell-coverage-baseline.json.
Outputs:
    Prints covered/statements. Exits 1 when this OS is below its floor.
Requirements:
    Python 3.9+. The baseline holds "darwin" and "linux" objects, each with
    covered_lines, statements and optional slack_lines (default 0), which lets
    a run fall that many lines under its floor. A top-level ratio is still
    accepted as a fallback for an OS with no object of its own.
"""

from __future__ import annotations

import json
import platform
import re
import sys
from pathlib import Path

# One or more plus signs, then path, line number, and the traced text.
LINE_RE = re.compile(r"^\++([^:\n+][^:\n]*):(\d+):")

# The floor lives beside this script. It is not a command-line argument.
BASELINE = Path(__file__).resolve().parent / "shell-coverage-baseline.json"


def countable_lines(lib: Path) -> dict[str, set[int]]:
    """Map each lib/*.sh file to its non-blank, non-comment line numbers."""
    counted: dict[str, set[int]] = {}
    for path in sorted(lib.glob("*.sh")):
        good: set[int] = set()
        text = path.read_text(encoding="utf-8", errors="replace").splitlines()
        for number, line in enumerate(text, start=1):
            stripped = line.strip()
            if stripped and not stripped.startswith("#"):
                good.add(number)
        counted[str(path.resolve())] = good
    return counted


def resolve_source(raw: str, root: Path, cache: dict[str, Path]) -> Path:
    """Resolve a traced path once; relative paths are taken from the repo root."""
    source = cache.get(raw)
    if source is None:
        source = Path(raw)
        if not source.is_absolute():
            source = root / source
        source = source.resolve()
        cache[raw] = source
    return source


def scan_log(
    log: Path,
    root: Path,
    lib: Path,
    counted: dict[str, set[int]],
    cache: dict[str, Path],
    hits: set[tuple[str, int]],
) -> int:
    """Add this log's lib/*.sh hits to `hits`. Return its unparsed plus-lines."""
    unparsed = 0
    with log.open("r", encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            match = LINE_RE.match(raw)
            if match is None:
                unparsed += raw.startswith("+")
                continue
            source = resolve_source(match.group(1), root, cache)
            if not source.is_relative_to(lib) or source.suffix != ".sh":
                continue
            number = int(match.group(2))
            if number in counted.get(str(source), ()):
                hits.add((str(source), number))
    return unparsed


def count_hits(root: Path, log_dir: Path) -> tuple[int, int, int]:
    """Return covered lines, countable lines, and unparsed plus-lines."""
    lib = (root / "lib").resolve()
    counted = countable_lines(lib)
    statements = sum(len(lines) for lines in counted.values())
    hits: set[tuple[str, int]] = set()
    cache: dict[str, Path] = {}
    unparsed = sum(
        scan_log(log, root, lib, counted, cache, hits)
        for log in sorted(log_dir.glob("*.log"))
    )
    return len(hits), statements, unparsed


def select_floor(baseline: dict, os_name: str) -> tuple[int, int, int] | None:
    """Return (covered, statements, slack) for this OS, or None if malformed.

    A per-OS object wins and carries its own slack. Otherwise the top-level
    ratio applies to every OS.
    """
    entry = baseline.get(os_name)
    if not isinstance(entry, dict):
        entry = baseline
    try:
        return (
            int(entry["covered_lines"]),
            int(entry["statements"]),
            int(entry.get("slack_lines", 0)),
        )
    except (KeyError, TypeError, ValueError):
        return None


def check_floor(baseline: dict, os_name: str, covered: int, statements: int) -> int:
    """Compare a measured ratio with the floor. Return 0 when it passes."""
    floor = select_floor(baseline, os_name)
    if floor is None:
        print(f"shell coverage: no usable {os_name} floor in the baseline.", file=sys.stderr)
        return 1
    base_covered, base_statements, slack = floor
    if base_statements <= 0 or slack < 0:
        print(
            "shell coverage: baseline statements must be positive and slack not negative.",
            file=sys.stderr,
        )
        return 1
    # Slack absorbs run-to-run noise from timing-dependent lines in the trace.
    if (covered + slack) * base_statements < base_covered * statements:
        print(
            f"shell coverage: {os_name} {covered}/{statements} is below the floor "
            f"{base_covered}/{base_statements} minus {slack} lines of slack.",
            file=sys.stderr,
        )
        return 1
    print(
        f"shell coverage: {os_name} floor is {base_covered}/{base_statements} "
        f"({100.0 * base_covered / base_statements:.2f}%), slack {slack} lines."
    )
    return 0


def main(argv: list[str]) -> int:
    """Print the ratio and, unless measuring, compare this OS to its floor."""
    root = Path(argv[1]).resolve()
    log_dir = Path(argv[2])
    measure_only = argv[3] == "1"
    covered, statements, unparsed = count_hits(root, log_dir)
    if statements <= 0:
        print("shell coverage: lib/*.sh has no countable lines.", file=sys.stderr)
        return 1
    print(f"shell coverage: {covered}/{statements} lines.")
    if unparsed:
        print(
            f"shell coverage: {unparsed} xtrace lines did not match file:line.",
            file=sys.stderr,
        )
    if measure_only:
        return 0
    baseline = json.loads(BASELINE.read_text(encoding="utf-8"))
    return check_floor(baseline, platform.system().lower(), covered, statements)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
