#!/usr/bin/env bash
#
# Regression tests for completed-plan archive pruning.
#
# Manual --apply pruning must fail closed when git history age cannot be
# computed; otherwise shallow or partial clones can delete tracked docs.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT}/scripts/prune-completed-plans.sh"
TMP="$(mktemp -d)"
_PASS=0
_FAIL=0

cleanup() {
    rm -rf "${TMP}" 2>/dev/null || true
}
trap cleanup EXIT

_pass() {
    _PASS=$((_PASS + 1))
    echo "  PASS  $1"
}

_fail() {
    _FAIL=$((_FAIL + 1))
    echo "  FAIL  $1"
}

echo ""
echo "=== test-prune-completed-plans.sh ==="

cd "${TMP}"
git init -q
git config user.email "test@example.com"
git config user.name "Test"
mkdir -p dev-docs/completed-plans
cp "${SCRIPT}" ./prune-completed-plans.sh
chmod +x ./prune-completed-plans.sh

echo "# completed" > dev-docs/completed-plans/plan-old-2020-01-01.md
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

PATH="${PWD}/fake-bin:${PATH}" ARCHIVE_MIN_DAYS=0 ARCHIVE_MIN_COMMITS=0 ./prune-completed-plans.sh --apply >/dev/null 2>&1 || true
if [ -f dev-docs/completed-plans/plan-old-2020-01-01.md ]; then
    _pass "--apply keeps completed plan when commit age cannot be computed"
else
    _fail "--apply keeps completed plan when commit age cannot be computed"
fi

echo ""
if [ "${_FAIL}" -eq 0 ]; then
    echo "All ${_PASS} tests passed."
    exit 0
fi
echo "${_FAIL} failed, ${_PASS} passed."
exit 1
