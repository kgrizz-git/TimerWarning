#!/usr/bin/env bash

###############################################################################
# run-tests.sh — Run test tiers from tests/tiers.yaml
#
# Agent-agnostic PR gate: same lists for Cursor, Codex, Claude Code, OpenCode,
# Qwen, humans, and CI.
#
# Usage:
#   ./scripts/run-tests.sh --tier a
#   ./scripts/run-tests.sh --tier b
#   ./scripts/run-tests.sh --tier c          # lists Tier-C docs only
#   SKIP_GUI_TESTS=1 ./scripts/run-tests.sh --tier a   # omit GUI-only scripts
#   CI_HEADLESS=1 ./scripts/run-tests.sh --tier a      # same as SKIP_GUI_TESTS
#
# See: dev-docs/testing-assessments/test-tiers.md
###############################################################################

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="${ROOT}/tests/tiers.yaml"
TIER=""
LIST_ONLY=false

usage() {
    cat <<'EOF'
Usage: run-tests.sh --tier a|b|c [--list]

  --tier a|b|c   Run scripts in tier_a or tier_b; tier c prints manual-test docs
  --list         Print resolved script list without running

Environment:
  SKIP_GUI_TESTS=1   Skip scripts marked requires_gui
  CI_HEADLESS=1      Same as SKIP_GUI_TESTS (for CI without display)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --tier)
            shift
            TIER="${1:-}"
            ;;
        --list)
            LIST_ONLY=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "run-tests.sh: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [ -z "${TIER}" ]; then
    echo "run-tests.sh: --tier is required" >&2
    usage >&2
    exit 2
fi

if [ ! -f "${MANIFEST}" ]; then
    echo "run-tests.sh: manifest not found: ${MANIFEST}" >&2
    exit 1
fi

_os_name() {
    uname -s 2>/dev/null || echo unknown
}

_platform_matches() {
    local want="$1"
    local os
    os="$(_os_name)"
    case "${want}" in
        darwin)
            [ "${os}" = "Darwin" ]
            ;;
        linux)
            [ "${os}" = "Linux" ]
            ;;
        all|'')
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

_should_skip_gui() {
    local requires_gui="$1"
    if [ "${requires_gui}" != "true" ]; then
        return 1
    fi
    if [ "${SKIP_GUI_TESTS:-0}" = "1" ] || [ "${CI_HEADLESS:-0}" = "1" ]; then
        return 0
    fi
    return 1
}

# Run a command with a wall-clock limit. Exit 124 on timeout (GNU timeout convention).
# macOS runners lack GNU timeout; Homebrew coreutils installs gtimeout; else bash watchdog.
_run_with_timeout() {
    local secs="$1"
    shift

    if command -v timeout >/dev/null 2>&1; then
        timeout "${secs}" "$@"
        return $?
    fi
    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout "${secs}" "$@"
        return $?
    fi

    local pid watcher rc=0
    "$@" &
    pid=$!
    (
        sleep "${secs}" || exit 0
        if kill -0 "${pid}" 2>/dev/null; then
            kill -TERM "${pid}" 2>/dev/null || true
            sleep 2
            kill -KILL "${pid}" 2>/dev/null || true
        fi
    ) &
    watcher=$!

    if ! wait "${pid}"; then
        rc=$?
    fi
    kill "${watcher}" 2>/dev/null || true
    wait "${watcher}" 2>/dev/null || true

    case "${rc}" in
        143|137) return 124 ;;
        *) return "${rc}" ;;
    esac
}

# Emit tab-separated rows: script platform requires_gui
# Parses the small YAML subset in tests/tiers.yaml (no PyYAML dependency).
_resolve_tier_scripts() {
    local tier_key="tier_${1}"
    python3 - "${MANIFEST}" "${tier_key}" <<'PY'
import re
import sys
from pathlib import Path

manifest = Path(sys.argv[1])
tier_key = sys.argv[2]
text = manifest.read_text(encoding="utf-8")

# Locate tier block
pattern = re.compile(rf"^{re.escape(tier_key)}:\s*$", re.M)
match = pattern.search(text)
if not match:
    sys.exit(0)

block = text[match.end():]
# Stop at next top-level key (word + colon at column 0)
next_key = re.search(r"^[a-z_][a-z0-9_]*:\s*$", block, re.M)
if next_key:
    block = block[: next_key.start()]

scripts_section = re.search(r"^\s*scripts:\s*$", block, re.M)
if not scripts_section:
    sys.exit(0)

lines = block[scripts_section.end() :].splitlines()

current_name = None
current_platform = ""
current_gui = "false"

def emit(name, platform, gui):
    if name:
        print(f"{name}\t{platform or 'all'}\t{gui}")

for raw in lines:
    if re.match(r"^[a-z_][a-z0-9_]*:\s*$", raw):
        break
    if not raw.strip() or raw.lstrip().startswith("#"):
        continue
    stripped = raw.strip()
    if stripped.startswith("- name:"):
        emit(current_name, current_platform, current_gui)
        current_name = stripped.split(":", 1)[1].strip()
        current_platform = ""
        current_gui = "false"
        continue
    if stripped.startswith("- "):
        emit(current_name, current_platform, current_gui)
        current_name = stripped[2:].split("#", 1)[0].strip()
        current_platform = ""
        current_gui = "false"
        continue
    if stripped.startswith("platform:"):
        current_platform = stripped.split(":", 1)[1].strip()
        continue
    if stripped.startswith("requires_gui:"):
        current_gui = stripped.split(":", 1)[1].strip().lower()
        continue

emit(current_name, current_platform, current_gui)
PY
}

_run_tier_c() {
    local docs_line
    docs_line="$(awk '/^tier_c:/{f=1;next} f && /^  docs:/{print $2; exit}' "${MANIFEST}")"
    echo "=== Tier-C (manual / multi-host) ==="
    echo "No automated run. See: ${ROOT}/${docs_line:-dev-docs/development/platform-test-matrix.md}"
    return 0
}

main() {
    local failed=0
    local ran=0
    local skipped=0

    case "${TIER}" in
        c|C)
            _run_tier_c
            exit 0
            ;;
        a|A|b|B)
            ;;
        *)
            echo "run-tests.sh: unknown tier: ${TIER} (use a, b, or c)" >&2
            exit 2
            ;;
    esac

    local tier_lower tier_upper
    tier_lower="$(printf '%s' "${TIER}" | tr '[:upper:]' '[:lower:]')"
    tier_upper="$(printf '%s' "${tier_lower}" | tr '[:lower:]' '[:upper:]')"

    echo "=== Tier-${tier_upper} tests ==="

    while IFS=$'\t' read -r script platform requires_gui; do
        [ -z "${script}" ] && continue
        local path="${ROOT}/tests/${script}"

        if ! _platform_matches "${platform}"; then
            echo "SKIP (platform ${platform}): ${script}"
            skipped=$((skipped + 1))
            continue
        fi

        if _should_skip_gui "${requires_gui}"; then
            echo "SKIP (requires_gui): ${script}"
            skipped=$((skipped + 1))
            continue
        fi

        if [ ! -f "${path}" ]; then
            echo "MISSING: ${path}" >&2
            failed=1
            continue
        fi

        if [ "${LIST_ONLY}" = true ]; then
            echo "RUN: ${script}"
            ran=$((ran + 1))
            continue
        fi

        echo "--- ${script} ---"
        if ! _run_with_timeout 300 bash "${path}"; then
            echo "FAIL: ${script}" >&2
            failed=1
        fi
        ran=$((ran + 1))
    done < <(_resolve_tier_scripts "${tier_lower}")

    if [ "${ran}" -eq 0 ] && [ "${skipped}" -eq 0 ]; then
        echo "run-tests.sh: no scripts resolved for tier ${tier_lower}" >&2
        exit 1
    fi

    echo "Tier-${tier_upper}: ${ran} run, ${skipped} skipped"
    if [ "${failed}" -ne 0 ]; then
        echo "run-tests.sh: one or more tests failed." >&2
        exit 1
    fi
    echo "run-tests.sh: tier ${tier_lower} passed."
}

main
