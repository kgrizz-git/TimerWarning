#!/usr/bin/env bash

###############################################################################
# test-prune-dev-docs-archive.sh — Archive retention script behavior
#
# Usage: bash tests/test-prune-dev-docs-archive.sh
# Exit: 0 pass, 1 fail
###############################################################################

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT}/scripts/prune-dev-docs-archive.sh"
_PASS=0
_FAIL=0

_pass() { _PASS=$((_PASS + 1)); echo "  PASS  $1"; }
_fail() { _FAIL=$((_FAIL + 1)); echo "  FAIL  $1"; }

echo ""
echo "=== test-prune-dev-docs-archive.sh ==="

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

setup_repo() {
    cd "${TMP}"
    rm -rf .git dev-docs 2>/dev/null || true
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    mkdir -p dev-docs/testing-assessments dev-docs/refactor-assessments
    cp "${SCRIPT}" ./prune-dev-docs-archive.sh
    chmod +x ./prune-dev-docs-archive.sh
}

# --- protect canonical files ---
setup_repo
echo "# tiers" > dev-docs/testing-assessments/test-tiers.md
echo "# old" > dev-docs/testing-assessments/testing-assessment-2020-01-01-000000.md
git add -A
git commit -q -m "init"
for i in 1 2 3 4 5 6 7 8 9 10 11; do
    echo "c${i}" >> README.md
    git add README.md
    git commit -q -m "c${i}"
done

out="$(ARCHIVE_MIN_DAYS=0 ARCHIVE_MIN_COMMITS=0 ARCHIVE_KEEP_LATEST=0 ./prune-dev-docs-archive.sh 2>&1 || true)"
if echo "${out}" | grep -q "testing-assessment-2020-01-01-000000.md"; then
    _pass "old timestamped assessment eligible"
else
    _fail "old timestamped assessment eligible"
fi
if echo "${out}" | grep -q "test-tiers.md"; then
    _fail "test-tiers.md must never be eligible"
else
    _pass "test-tiers.md never eligible"
fi

# --- keep latest in folder ---
setup_repo
echo "# a" > dev-docs/refactor-assessments/refactor-assessment-2020-01-01-000001.md
echo "# b" > dev-docs/refactor-assessments/refactor-assessment-2020-06-01-000001.md
git add -A
git commit -q -m "init"
for i in 1 2 3 4 5 6 7 8 9 10 11; do
    echo "c${i}" >> README.md
    git add README.md
    git commit -q -m "c${i}"
done

out="$(ARCHIVE_MIN_DAYS=0 ARCHIVE_MIN_COMMITS=0 ARCHIVE_KEEP_LATEST=1 ./prune-dev-docs-archive.sh 2>&1 || true)"
if echo "${out}" | grep -q "refactor-assessment-2020-06-01-000001.md"; then
    _fail "newest refactor assessment should be kept (keep-latest=1)"
else
    _pass "newest refactor assessment kept with keep-latest=1"
fi
if echo "${out}" | grep -q "refactor-assessment-2020-01-01-000001.md"; then
    _pass "older refactor assessment eligible when keep-latest=1"
else
    _fail "older refactor assessment eligible when keep-latest=1"
fi

# --- dry-run vs apply ---
setup_repo
echo "# old" > dev-docs/testing-assessments/testing-assessment-2020-01-01-000000.md
git add -A
git commit -q -m "init"
for i in 1 2 3 4 5 6 7 8 9 10 11; do
    echo "c${i}" >> README.md
    git add README.md
    git commit -q -m "c${i}"
done

./prune-dev-docs-archive.sh >/dev/null 2>&1 || true
if [ -f dev-docs/testing-assessments/testing-assessment-2020-01-01-000000.md ]; then
    _pass "dry-run default does not delete"
else
    _fail "dry-run default does not delete"
fi

ARCHIVE_MIN_DAYS=0 ARCHIVE_MIN_COMMITS=0 ARCHIVE_KEEP_LATEST=0 ./prune-dev-docs-archive.sh --apply >/dev/null 2>&1 || true
if [ ! -f dev-docs/testing-assessments/testing-assessment-2020-01-01-000000.md ]; then
    _pass "--apply deletes eligible file"
else
    _fail "--apply deletes eligible file"
fi

# --- fail closed when commit age cannot be computed ---
setup_repo
echo "# old" > dev-docs/testing-assessments/testing-assessment-2020-01-01-000000.md
git add -A
git commit -q -m "init"
for i in 1 2 3 4 5 6 7 8 9 10 11; do
    echo "c${i}" >> README.md
    git add README.md
    git commit -q -m "c${i}"
done

REAL_GIT="$(command -v git)"
mkdir -p fake-bin
cat > fake-bin/git <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "rev-list" ]; then
    exit 1
fi
exec "${REAL_GIT}" "\$@"
EOF
chmod +x fake-bin/git

PATH="${PWD}/fake-bin:${PATH}" ARCHIVE_MIN_DAYS=0 ARCHIVE_MIN_COMMITS=0 ARCHIVE_KEEP_LATEST=0 ./prune-dev-docs-archive.sh --apply >/dev/null 2>&1 || true
if [ -f dev-docs/testing-assessments/testing-assessment-2020-01-01-000000.md ]; then
    _pass "--apply keeps file when commit age cannot be computed"
else
    _fail "--apply keeps file when commit age cannot be computed"
fi

# --- live repo smoke: script exits 0 ---
cd "${ROOT}"
if "${SCRIPT}" >/dev/null 2>&1; then
    _pass "live repo dry-run exits 0"
else
    _fail "live repo dry-run exits 0"
fi

echo ""
if [ "${_FAIL}" -eq 0 ]; then
    echo "All ${_PASS} tests passed."
    exit 0
fi
echo "${_FAIL} failed, ${_PASS} passed."
exit 1
