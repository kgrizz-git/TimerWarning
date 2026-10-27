#!/usr/bin/env python3
"""Measure shell function length and control-structure nesting.

Not cyclomatic complexity. For each function it reports:
    length: lines from the declaration to the closing brace.
    depth:  deepest nesting of if/for/while/until/case/select inside it.

A function starts at `name() {` or `function name {` and ends at the next line
that is only `}` at the same indent. Comments, quoted strings and heredoc
bodies are ignored when counting nesting.

Usage:
    shell_complexity.py [--max-length N] [--max-depth N] FILE...
    shell_complexity.py [--max-length N] [--max-depth N] --stdin NAME
Exit 1 when any function is above a ceiling. With no ceilings, print the table.
"""

from __future__ import annotations

import argparse
import re
import sys

DECL_RE = re.compile(r"^(\s*)(?:function\s+([A-Za-z_][\w:.-]*)|([A-Za-z_][\w:.-]*)\s*\(\s*\))\s*\{?\s*(?:#.*)?$")
OPENERS = {"if", "for", "while", "until", "case", "select"}
CLOSERS = {"fi", "done", "esac"}
SEGMENT_RE = re.compile(r"&&|\|\||[;|&(){}\n]")


HEREDOC_START = re.compile(r"(?<!<)<<-?\s*(['\"]?)([A-Za-z_]\w*)\1")


def sanitize(lines: list[str]) -> list[str]:
    """Blank quoted strings, comments and heredoc bodies; keep the line count."""
    out = []
    quote = None  # "'" or '"' while inside a string that spans lines
    heredoc_end = None
    for raw in lines:
        if heredoc_end is not None:
            if raw.strip() == heredoc_end:
                heredoc_end = None
            out.append("")
            continue
        kept = []
        prev = " "
        k = 0
        while k < len(raw):
            ch = raw[k]
            if quote:
                if ch == "\\" and quote == '"':
                    k += 2
                    continue
                if ch == quote:
                    quote = None
                k += 1
                continue
            if ch in "'\"":
                quote = ch
            elif ch == "\\":
                k += 2
                prev = "x"
                continue
            elif ch == "#" and prev in " \t;|&(":
                break
            else:
                kept.append(ch)
            prev = ch
            k += 1
        line = "".join(kept)
        marker = HEREDOC_START.search(raw) if not quote else None
        if marker and "<<" in line:
            heredoc_end = marker.group(2)
        out.append(line)
    return out


def functions(lines: list[str]) -> list[tuple[str, int, int, int]]:
    """Return (name, start_line, length, depth) for each function."""
    clean = sanitize(lines)
    found = []
    i = 0
    while i < len(lines):
        match = DECL_RE.match(clean[i])
        if not match:
            i += 1
            continue
        indent = match.group(1)
        name = match.group(2) or match.group(3)
        end = None
        for j in range(i + 1, len(lines)):
            if lines[j].rstrip() == indent + "}":
                end = j
                break
        if end is None:
            i += 1
            continue
        found.append((name, i + 1, end - i + 1, deepest(clean[i + 1 : end])))
        i = end + 1
    return found


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


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-length", type=int)
    parser.add_argument("--max-depth", type=int)
    parser.add_argument("--stdin", metavar="NAME")
    parser.add_argument("files", nargs="*")
    args = parser.parse_args(argv[1:])
    sources = []
    if args.stdin:
        sources.append((args.stdin, sys.stdin.read().splitlines()))
    for path in args.files:
        with open(path, encoding="utf-8", errors="replace") as handle:
            sources.append((path, handle.read().splitlines()))
    failed = 0
    for name, lines in sources:
        for func, start, length, depth in functions(lines):
            over = []
            if args.max_length is not None and length > args.max_length:
                over.append(f"length {length} > {args.max_length}")
            if args.max_depth is not None and depth > args.max_depth:
                over.append(f"nesting {depth} > {args.max_depth}")
            if over:
                failed += 1
                print(f"{name}:{start}: {func}: {', '.join(over)}", file=sys.stderr)
            elif args.max_length is None and args.max_depth is None:
                print(f"{length}\t{depth}\t{name}:{start}\t{func}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
