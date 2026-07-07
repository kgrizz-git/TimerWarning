#!/usr/bin/env bash

###############################################################################
# test-prune-backups.sh — Assert backups prune default is 5 commits
#
# Usage: bash tests/test-prune-backups.sh
# Exit: 0 pass, 1 fail
###############################################################################

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_PASS=0
_FAIL=0

_pass() { _PASS=$((_PASS + 1)); echo "  PASS  $1"; }
_fail() { _FAIL=$((_FAIL + 1)); echo "  FAIL  $1"; }

echo ""
echo "=== test-prune-backups.sh ==="

default_age="$(grep '^MAX_COMMIT_AGE=' "${ROOT}/scripts/prune-backups.sh" | head -1 | cut -d= -f2)"
if [ "${default_age}" = "5" ]; then
    _pass "MAX_COMMIT_AGE default is 5"
else
    _fail "MAX_COMMIT_AGE default is 5 (got ${default_age})"
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

cd "${TMP}"
git init -q
git config user.email "test@example.com"
git config user.name "Test"

mkdir -p backups
echo "old" > backups/old-backup.sh
git add backups/old-backup.sh
git commit -q -m "c1"

for i in 2 3 4 5 6 7 8 9 10 11 12; do
    echo "x" >> README.md
    git add README.md
    git commit -q -m "c${i}"
done

cp "${ROOT}/scripts/prune-backups.sh" ./prune-backups.sh
chmod +x ./prune-backups.sh

out="$(./prune-backups.sh --dry-run 2>&1 || true)"
if echo "${out}" | grep -q "Would prune"; then
    _pass "backup older than 5 commits flagged in dry-run"
else
    _fail "backup older than 5 commits flagged in dry-run"
fi

if [ -f backups/old-backup.sh ]; then
    _pass "dry-run did not delete backup file"
else
    _fail "dry-run did not delete backup file"
fi

cd "${TMP}"
mkdir staged-change
cd staged-change
git init -q
git config user.email "test@example.com"
git config user.name "Test"

mkdir -p backups
echo "old" > backups/keep-backup.sh
git add backups/keep-backup.sh
git commit -q -m "c1"

for i in 2 3 4 5 6 7 8; do
    echo "x" >> README.md
    git add README.md
    git commit -q -m "c${i}"
done

echo "updated" > backups/keep-backup.sh
git add backups/keep-backup.sh
cp "${ROOT}/scripts/prune-backups.sh" ./prune-backups.sh
chmod +x ./prune-backups.sh

./prune-backups.sh >/dev/null 2>&1 || true

if [ -f backups/keep-backup.sh ]; then
    _pass "staged backup changes are not pruned"
else
    _fail "staged backup changes are not pruned"
fi

if git diff --cached --quiet -- backups/keep-backup.sh; then
    _fail "staged backup update remains staged"
else
    _pass "staged backup update remains staged"
fi

cd "${TMP}"
mkdir unstaged-old-change
cd unstaged-old-change
git init -q
git config user.email "test@example.com"
git config user.name "Test"

mkdir -p backups
echo "old" > backups/edited-backup.sh
git add backups/edited-backup.sh
git commit -q -m "c1"

for i in 2 3 4 5 6 7 8; do
    echo "x" >> README.md
    git add README.md
    git commit -q -m "c${i}"
done

echo "uncommitted edit" >> backups/edited-backup.sh
cp "${ROOT}/scripts/prune-backups.sh" ./prune-backups.sh
chmod +x ./prune-backups.sh

./prune-backups.sh >/dev/null 2>&1 || true

if [ -f backups/edited-backup.sh ]; then
    _pass "old backup with unstaged edits is not pruned"
else
    _fail "old backup with unstaged edits is not pruned"
fi

if git diff --quiet -- backups/edited-backup.sh; then
    _fail "old backup unstaged edit remains unstaged"
else
    _pass "old backup unstaged edit remains unstaged"
fi

if git diff --cached --quiet -- backups/edited-backup.sh; then
    _pass "old backup unstaged edit is not staged"
else
    _fail "old backup unstaged edit is not staged"
fi

cd "${TMP}"
mkdir unrelated-stage
cd unrelated-stage
git init -q
git config user.email "test@example.com"
git config user.name "Test"

mkdir -p backups
echo "old" > backups/old-backup.sh
echo "recent" > backups/recent-backup.sh
git add backups
git commit -q -m "c1"

for i in 2 3 4 5 6 7 8; do
    echo "x" >> README.md
    git add README.md
    git commit -q -m "c${i}"
done

echo "recent committed change" > backups/recent-backup.sh
git add backups/recent-backup.sh
git commit -q -m "recent backup update"

echo "uncommitted work" >> backups/recent-backup.sh
cp "${ROOT}/scripts/prune-backups.sh" ./prune-backups.sh
chmod +x ./prune-backups.sh

./prune-backups.sh >/dev/null 2>&1 || true

if [ ! -f backups/old-backup.sh ]; then
    _pass "old backup is pruned in apply mode"
else
    _fail "old backup is pruned in apply mode"
fi

if git diff --cached --quiet -- backups/recent-backup.sh; then
    _pass "unrelated unstaged backup edits are not staged"
else
    _fail "unrelated unstaged backup edits are not staged"
fi

echo ""
if [ "${_FAIL}" -eq 0 ]; then
    echo "All ${_PASS} tests passed."
    exit 0
fi
echo "${_FAIL} failed, ${_PASS} passed."
exit 1
