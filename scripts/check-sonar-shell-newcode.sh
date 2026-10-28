#!/usr/bin/env bash
# Approximate SonarCloud's shell rule S7688 ("use [[ instead of [") on new code.
#
# The local SonarQube Community Build has no Shell analyzer, so sonar_scan.sh
# never sees .sh files. SonarCloud does analyze them, and S7688 is the rule it
# reports most. ShellCheck's optional check require-double-brackets (SC2292)
# flags the same constructs, once per `[`, as Sonar does.
#
# Only lines added since the merge base are reported, which matches Sonar's
# new-code view. A line that only moved, with the same text as a removed line, is
# skipped. Untracked .sh files count in full. Existing `[ ]` tests stay alone:
# the codebase uses them everywhere.
#
# Checked against SonarCloud on PR #3: it found every S7688 finding Sonar
# reported (28 of 28). It can report a few extra lines, such as a changed line
# whose old version Sonar already tracked as an existing issue.
#
# This does not cover Sonar's other shell rules (S1192 repeated literals, S7679
# positional parameters, S131 case without a default, S1066 nested ifs). For the
# real result after a push, run scripts/sonarcloud_pr_issues.py.
#
# Usage: ./scripts/check-sonar-shell-newcode.sh [BASE_REF]
#   BASE_REF defaults to origin/main, then main.
# Exit: 0 clean, 1 findings, 2 setup problem.

set -euo pipefail

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "check-sonar-shell-newcode: shellcheck is not installed." >&2
    exit 2
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "${ROOT}"

base_ref="${1:-}"
if [[ -z "${base_ref}" ]]; then
    for candidate in origin/main main; do
        if git rev-parse --verify --quiet "${candidate}^{commit}" >/dev/null; then
            base_ref="${candidate}"
            break
        fi
    done
fi
if [[ -z "${base_ref}" ]] || ! base_sha="$(git merge-base "${base_ref}" HEAD 2>/dev/null)"; then
    echo "check-sonar-shell-newcode: no base ref (pass one, e.g. origin/main)." >&2
    exit 2
fi

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

# Added line numbers of one file since the merge base, one per line.
added_lines() {
    git diff -U0 "${base_sha}" -- "$1" | awk '
        /^@@/ {
            split($3, range, ",")
            start = substr(range[1], 2) + 0
            count = (range[2] == "" ? 1 : range[2] + 0)
            for (i = 0; i < count; i++) print start + i
        }'
}

# Text of the lines the diff removed, without indentation. An added line with
# the same text is a moved or re-indented line, which Sonar treats as old code.
removed_text() {
    git diff -U0 "${base_sha}" -- "$1" | grep -E '^-' | grep -vE '^--- ' | sed -E 's/^-[[:space:]]*//' || true
}

# Changed or new shell files: tracked changes first, then untracked files.
{
    git diff --name-only --diff-filter=AM "${base_sha}" -- '*.sh'
    git ls-files --others --exclude-standard -- '*.sh'
} | sort -u | grep -v '^backups/' > "${work}/files" || true

findings=0
while IFS= read -r file; do
    [[ -f "${file}" ]] || continue
    if git ls-files --error-unmatch -- "${file}" >/dev/null 2>&1; then
        added_lines "${file}" > "${work}/added"
        removed_text "${file}" > "${work}/removed"
    else
        seq 1 "$(wc -l < "${file}")" > "${work}/added"
        : > "${work}/removed"
    fi
    [[ -s "${work}/added" ]] || continue
    shellcheck -o require-double-brackets -S style -f gcc "${file}" 2>/dev/null \
        | awk -F: -v added="${work}/added" -v removed="${work}/removed" -v src="${file}" '
            BEGIN {
                while ((getline line < added) > 0) want[line] = 1
                while ((getline line < removed) > 0) gone[line] = 1
                while ((getline line < src) > 0) {
                    sub(/^[[:space:]]+/, "", line)
                    text[++total] = line
                }
            }
            /\[SC2292\]/ && ($2 in want) && !(text[$2] in gone) { print }' > "${work}/hits" || true
    if [[ -s "${work}/hits" ]]; then
        findings=$((findings + $(wc -l < "${work}/hits")))
        sed 's/: note: Prefer \[\[ \]\] over \[ \] for tests in Bash\/Ksh\/Busybox\. \[SC2292\]/: use [[ ]] instead of [ ]/' "${work}/hits"
    fi
done < "${work}/files"

if [[ "${findings}" -gt 0 ]]; then
    echo "check-sonar-shell-newcode: ${findings} added '[' test(s) that SonarCloud flags as S7688." >&2
    exit 1
fi
echo "check-sonar-shell-newcode: no new '[' tests since ${base_ref}."
