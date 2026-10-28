#!/bin/bash

###############################################################################
# Tests scripts/check-sonar-shell-newcode.sh in a throwaway git repository:
# it reports `[` tests added since the merge base, and only those. Existing
# tests, moved or re-indented lines, deletions, and `[[ ]]` stay quiet. Untracked
# files count in full.
# Skips when shellcheck is not installed. Runs with a temp HOME and temp repo.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="${SCRIPT_DIR}/scripts/check-sonar-shell-newcode.sh"

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "SKIP: shellcheck is not installed"
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
export HOME="${WORK}/home"
mkdir -p "${HOME}"

_PASS=0
_FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "${actual}" == "${expected}" ]]; then
        _PASS=$(( _PASS + 1 )); echo "  PASS  ${desc} (${actual})"
    else
        _FAIL=$(( _FAIL + 1 )); echo "  FAIL  ${desc}: expected '${expected}', got '${actual}'"
    fi
}

REPO="${WORK}/repo"
git_in_repo() {
    git -C "${REPO}" -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false "$@"
}

new_repo() {
    rm -rf "${REPO}"
    mkdir -p "${REPO}"
    git_in_repo init -q -b main
}

# run_check: prints "rc|lines" where lines are the reported file:line pairs.
run_check() {
    local out rc
    out="$(cd "${REPO}" && "${CHECK}" "$@" 2>/dev/null)"
    rc=$?
    printf '%s|%s' "${rc}" "$(printf '%s\n' "${out}" | grep -E '^[^ ]+:[0-9]+:[0-9]+:' | cut -d: -f1,2 | sort -u | paste -sd' ' -)"
}

commit_all() {
    local message="$1"
    git_in_repo add -A
    git_in_repo commit -q -m "${message}"
}

# The base file has two old `[ ]` tests that must never be reported.
write_base() {
    cat > "${REPO}/a.sh" <<'BASE'
#!/bin/bash
old_one() {
    if [ -n "$1" ]; then
        echo one
    fi
}
old_two() {
    [ -e /tmp ] && echo two
}
BASE
}

echo "=== a new '[' test is reported, old ones are not ==="
new_repo; write_base; commit_all base
git_in_repo checkout -q -b feature
printf 'added() {\n    if [ -z "$1" ]; then echo none; fi\n}\n' >> "${REPO}/a.sh"
commit_all change
check "only the added line is reported" "1|a.sh:11" "$(run_check main)"

echo "=== '[[ ]]' is clean ==="
new_repo; write_base; commit_all base
git_in_repo checkout -q -b feature
printf 'added() {\n    if [[ -z "$1" ]]; then echo none; fi\n}\n' >> "${REPO}/a.sh"
commit_all change
check "a double-bracket test passes" "0|" "$(run_check main)"

echo "=== several '[' on one line are each counted ==="
new_repo; write_base; commit_all base
git_in_repo checkout -q -b feature
printf 'added() {\n    if [ -z "$1" ] || [ -z "$2" ]; then echo none; fi\n}\n' >> "${REPO}/a.sh"
commit_all change
out="$(cd "${REPO}" && "${CHECK}" main 2>&1)"
check "the summary counts both" "2" "$(printf '%s\n' "${out}" | sed -n "s/.*: \([0-9]*\) added '\[' test.*/\1/p")"

echo "=== a re-indented old line is not new ==="
new_repo; write_base; commit_all base
git_in_repo checkout -q -b feature
sed -i.bak 's/^    \[ -e \/tmp \] \&\& echo two/        [ -e \/tmp ] \&\& echo two/' "${REPO}/a.sh" && rm -f "${REPO}/a.sh.bak"
commit_all reindent
check "re-indenting keeps the line old" "0|" "$(run_check main)"

echo "=== a deletion is clean ==="
new_repo; write_base; commit_all base
git_in_repo checkout -q -b feature
printf '#!/bin/bash\n' > "${REPO}/a.sh"
commit_all delete
check "removing tests reports nothing" "0|" "$(run_check main)"

echo "=== uncommitted changes count ==="
new_repo; write_base; commit_all base
git_in_repo checkout -q -b feature
printf 'added() {\n    [ -z "$1" ] && echo none\n}\n' >> "${REPO}/a.sh"
check "a working-tree edit is reported" "1|a.sh:11" "$(run_check main)"

echo "=== untracked files count in full ==="
new_repo; write_base; commit_all base
git_in_repo checkout -q -b feature
printf '#!/bin/bash\nif [ -n "$1" ]; then echo x; fi\n' > "${REPO}/new.sh"
check "an untracked file is reported" "1|new.sh:2" "$(run_check main)"

echo "=== untracked file without a trailing newline ==="
new_repo; write_base; commit_all base
git_in_repo checkout -q -b feature
printf '#!/bin/bash\nif [ -n "$1" ]; then echo x; fi' > "${REPO}/no-newline.sh"
check "the last line is counted" "1|no-newline.sh:2" "$(run_check main)"
printf '[ -n "$1" ] && echo x' > "${REPO}/one-line.sh"
check "a single line with no newline is counted" "1|no-newline.sh:2 one-line.sh:1" "$(run_check main)"

echo "=== other files are ignored ==="
new_repo; write_base; commit_all base
git_in_repo checkout -q -b feature
printf 'if [ -n "$1" ]; then echo x; fi\n' > "${REPO}/notes.txt"
commit_all text
check "non-shell files are skipped" "0|" "$(run_check main)"

echo "=== setup problems ==="
new_repo; write_base; commit_all base
check "an unknown base ref exits 2" "2|" "$(run_check no-such-ref)"

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
[[ "${_FAIL}" -eq 0 ]] || exit 1
