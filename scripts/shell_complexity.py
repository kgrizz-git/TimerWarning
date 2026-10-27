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

NAME = r"[A-Za-z_][\w:.-]*"
# `function name {` or `function name() {`, and `name() {`. Two small patterns.
KEYWORD_DECL_RE = re.compile(rf"^(\s*)function\s+({NAME})(?:\s*\(\s*\))?\s*\{{?$")
PAREN_DECL_RE = re.compile(rf"^(\s*)({NAME})\s*\(\s*\)\s*\{{?$")
OPENERS = {"if", "for", "while", "until", "case", "select"}
CLOSERS = {"fi", "done", "esac"}
SEGMENT_RE = re.compile(r"&&|\|\||[;|&(){}\n]")
# `<<` or `<<-` (not `<<<`), then a delimiter that starts with a letter or underscore and runs to
# whitespace, a quote, or an operator.
HEREDOC_AT = re.compile(r"(?<!<)<<(?!<)-?\s*['\"]?([A-Za-z_][^\s'\"<>|&;()]*)")


def skip_in_string(raw: str, k: int, quote: str) -> tuple[int, str | None]:
    """Advance one character inside a quoted string. Return (index, open quote)."""
    if raw[k] == "\\" and quote == '"':
        return k + 2, quote
    if raw[k] == quote:
        return k + 1, None
    return k + 1, quote


def blank_line(raw: str, quote: str | None) -> tuple[str, str | None, list[str]]:
    """Drop quoted text and a trailing comment.

    Return (line, quote still open, heredoc delimiters opened outside quotes).
    """
    kept: list[str] = []
    delimiters: list[str] = []
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
        if ch == "<" and (marker := HEREDOC_AT.match(raw, k)):
            delimiters.append(marker.group(1))
        if ch in "'\"":
            quote = ch
        else:
            kept.append(ch)
        prev = ch
        k += 1
    return "".join(kept), quote, delimiters


def sanitize(lines: list[str]) -> list[str]:
    """Blank quoted strings, comments and heredoc bodies; keep the line count."""
    out: list[str] = []
    quote: str | None = None
    pending: list[str] = []  # heredoc delimiters whose bodies are still to come, in order
    for raw in lines:
        if pending:
            if raw.strip() == pending[0]:
                pending.pop(0)
            out.append("")
            continue
        line, quote, delimiters = blank_line(raw, quote)
        if quote is None:
            pending.extend(delimiters)
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


def declaration(line: str) -> tuple[str, str] | None:
    """Return (indent, name) when the sanitized line declares a function."""
    match = KEYWORD_DECL_RE.match(line) or PAREN_DECL_RE.match(line)
    return (match.group(1), match.group(2)) if match else None


def closing_line(clean: list[str], start: int, indent: str) -> int | None:
    """Index of the sanitized line that closes the function declared at `start`."""
    for j in range(start + 1, len(clean)):
        if clean[j].rstrip() == indent + "}":
            return j
    return None


def functions(lines: list[str]) -> list[tuple[str, int, int, int]]:
    """Return (name, start_line, length, depth) for each function."""
    clean = sanitize(lines)
    found = []
    i = 0
    while i < len(lines):
        decl = declaration(clean[i].rstrip())
        end = closing_line(clean, i, decl[0]) if decl else None
        if decl is None or end is None:
            i += 1
            continue
        name = decl[1]
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
