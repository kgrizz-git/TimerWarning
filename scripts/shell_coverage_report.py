#!/usr/bin/env python3
"""Compare bash xtrace hits under lib/*.sh with the per-OS floor.

Reads logs written by scripts/shell-coverage-env.sh. Each trace line looks
like "+/path/file.sh:12:" or "++/path/file.sh:12:" when the line ran inside
a command substitution. The path is everything after the leading plus signs.

Inputs:
    repo root, log directory, baseline JSON, "1" to print without comparing.
Outputs:
    Prints covered/statements. Exits 1 when this OS is below its floor.
Requirements:
    Python 3. The baseline holds a top-level ratio; per-OS "darwin" and
    "linux" objects override it when present.
"""

from __future__ import annotations

import json
import platform
import re
import sys
from pathlib import Path

# One or more plus signs, then path, line number, and the traced text.
LINE_RE = re.compile(r"^(\++)([^:\n]+):(\d+):")


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


def count_hits(root: Path, log_dir: Path) -> tuple[int, int, int]:
    """Return covered lines, countable lines, and unparsed plus-lines."""
    lib = (root / "lib").resolve()
    counted = countable_lines(lib)
    statements = sum(len(lines) for lines in counted.values())
    hits: set[tuple[str, int]] = set()
    unparsed = 0
    resolved_cache: dict[str, Path] = {}
    for log in sorted(log_dir.glob("*.log")):
        with log.open("r", encoding="utf-8", errors="replace") as handle:
            for raw in handle:
                match = LINE_RE.match(raw)
                if match is None:
                    if raw.startswith("+"):
                        unparsed += 1
                    continue
                raw_source = match.group(2)
                source = resolved_cache.get(raw_source)
                if source is None:
                    source = Path(raw_source)
                    if not source.is_absolute():
                        source = root / source
                    source = source.resolve()
                    resolved_cache[raw_source] = source
                try:
                    source.relative_to(lib)
                except ValueError:
                    continue
                if source.suffix != ".sh":
                    continue
                number = int(match.group(3))
                if number in counted.get(str(source), ()):
                    hits.add((str(source), number))
    return len(hits), statements, unparsed


def main(argv: list[str]) -> int:
    """Print the ratio and, unless measuring, compare this OS to its floor."""
    root = Path(argv[1]).resolve()
    log_dir = Path(argv[2])
    baseline_path = Path(argv[3])
    measure_only = argv[4] == "1"
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

    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    os_name = platform.system().lower()
    floor = baseline.get(os_name)
    if not isinstance(floor, dict):
        # Flat fallback: a top-level ratio applies to every OS until that OS
        # gets its own entry. An OS entry, when present, overrides the flat one.
        if isinstance(baseline.get("covered_lines"), int) and isinstance(
            baseline.get("statements"), int
        ):
            floor = {
                "covered_lines": baseline["covered_lines"],
                "statements": baseline["statements"],
            }
        else:
            print(
                f"shell coverage: no {os_name} floor in {baseline_path}.",
                file=sys.stderr,
            )
            return 1
    try:
        base_covered = int(floor["covered_lines"])
        base_statements = int(floor["statements"])
    except (KeyError, TypeError, ValueError):
        print(
            f"shell coverage: malformed floor in {baseline_path}.",
            file=sys.stderr,
        )
        return 1
    if base_statements <= 0:
        print("shell coverage: baseline statements must be positive.", file=sys.stderr)
        return 1
    if covered * base_statements < base_covered * statements:
        print(
            f"shell coverage: {os_name} {covered}/{statements} is below the floor "
            f"{base_covered}/{base_statements}.",
            file=sys.stderr,
        )
        return 1
    print(
        f"shell coverage: {os_name} floor is {base_covered}/{base_statements} "
        f"({100.0 * base_covered / base_statements:.2f}%)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
