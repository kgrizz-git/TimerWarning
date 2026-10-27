#!/usr/bin/env python3
"""Measure shell function length and control-structure nesting.

Not cyclomatic complexity. For each function it reports:
    length: lines from the declaration to the closing brace.
    depth:  deepest nesting of if/for/while/until/case/select inside it.

A function starts at `name() {` or `function name {` and ends at the next line
that is only `}` at the same indent. Comments, quoted strings and heredoc
bodies are ignored when counting nesting.

The shell is read from stdin, one file per run. scripts/check-shell-complexity.sh
feeds it each file, or a staged blob.

Usage:
    shell_complexity.py [--max-length N] [--max-depth N] NAME < source
Exit 1 when a function is above a ceiling. With no ceilings, print the table.
"""

from __future__ import annotations

import argparse
import re
import sys

DECL_RE = re.compile(r"^(\s*)(?:function\s+([A-Za-z_][\w:.-]*)|([A-Za-z_][\w:.-]*)\s*\(\s*\))\s*\{?$")
OPENERS = {"if", "for", "while", "until", "case", "select"}
CLOSERS = {"fi", "done", "esac"}
SEGMENT_RE = re.compile(r"&&|\|\||[;|&(){}\n]")
HEREDOC_START = re.compile(r"(?<!<)<<-?\s*['\"]?([A-Za-z_]\w*)")


def skip_in_string(raw: str, k: int, quote: str) -> tuple[int, str | None]:
    """Advance one character inside a quoted string. Return (index, open quote)."""
    if raw[k] == "\\" and quote == '"':
        return k + 2, quote
    if raw[k] == quote:
        return k + 1, None
    return k + 1, quote


def blank_line(raw: str, quote: str | None) -> tuple[str, str | None]:
    """Drop quoted text and a trailing comment. Return (line, quote still open)."""
    kept: list[str] = []
    prev = " "
    k = 0
    while k < len(raw):
        if quote:
            k, quote = skip_in_string(raw, k, quote)
            continue
        ch = raw[k]
        if ch == "\\":
            k += 2
            prev = "x"
            continue
        if ch == "#" and prev in " \t;|&(":
            break
        if ch in "'\"":
            quote = ch
        else:
            kept.append(ch)
        prev = ch
        k += 1
    return "".join(kept), quote


def sanitize(lines: list[str]) -> list[str]:
    """Blank quoted strings, comments and heredoc bodies; keep the line count."""
    out: list[str] = []
    quote: str | None = None
    heredoc_end: str | None = None
    for raw in lines:
        if heredoc_end is not None:
            if raw.strip() == heredoc_end:
                heredoc_end = None
            out.append("")
            continue
        line, quote = blank_line(raw, quote)
        marker = HEREDOC_START.search(raw) if quote is None else None
        if marker and "<<" in line:
            heredoc_end = marker.group(1)
        out.append(line)
    return out


def deepest(body: list[str]) -> int:
    """Deepest control nesting in a sanitized function body."""
    depth = best = 0
    for line in body:
        for segment in SEGMENT_RE.split(line):
            words = segment.split()
            if not words:
                continue
            if words[0] in OPENERS:
                depth += 1
                best = max(best, depth)
            elif words[0] in CLOSERS:
                depth = max(0, depth - 1)
    return best


def closing_line(lines: list[str], start: int, indent: str) -> int | None:
    """Index of the line that closes the function declared at `start`."""
    for j in range(start + 1, len(lines)):
        if lines[j].rstrip() == indent + "}":
            return j
    return None


def functions(lines: list[str]) -> list[tuple[str, int, int, int]]:
    """Return (name, start_line, length, depth) for each function."""
    clean = sanitize(lines)
    found = []
    i = 0
    while i < len(lines):
        match = DECL_RE.match(clean[i].rstrip())
        end = closing_line(lines, i, match.group(1)) if match else None
        if match is None or end is None:
            i += 1
            continue
        name = match.group(2) or match.group(3)
        found.append((name, i + 1, end - i + 1, deepest(clean[i + 1 : end])))
        i = end + 1
    return found


def over_limits(length: int, depth: int, args: argparse.Namespace) -> list[str]:
    """Describe each ceiling this function is above."""
    over = []
    if args.max_length is not None and length > args.max_length:
        over.append(f"length {length} > {args.max_length}")
    if args.max_depth is not None and depth > args.max_depth:
        over.append(f"nesting {depth} > {args.max_depth}")
    return over


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-length", type=int)
    parser.add_argument("--max-depth", type=int)
    parser.add_argument("name", help="name to report for the source on stdin")
    args = parser.parse_args(argv[1:])
    measuring = args.max_length is None and args.max_depth is None
    failed = 0
    for func, start, length, depth in functions(sys.stdin.read().splitlines()):
        over = over_limits(length, depth, args)
        if over:
            failed += 1
            print(f"{args.name}:{start}: {func}: {', '.join(over)}", file=sys.stderr)
        elif measuring:
            print(f"{length}\t{depth}\t{args.name}:{start}\t{func}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
