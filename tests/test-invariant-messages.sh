#!/bin/bash

###############################################################################
# test-invariant-messages.sh — Hard-block surfaces cite stable safety invariant IDs
#
# Prevents message rot after Phase 6 harness work. Does not run the wizard.
#
# Usage:
#   bash tests/test-invariant-messages.sh
#
# Exit: 0 all pass, 1 any failure
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="${SCRIPT_DIR}/lib"

_PASS=0
_FAIL=0

_pass() { _PASS=$(( _PASS + 1 )); echo "  PASS  $1"; }
_fail() { _FAIL=$(( _FAIL + 1 )); echo "  FAIL  $1"; }

assert_file_contains() {
    local file="$1" pattern="$2" desc="$3"
    if grep -qF "${pattern}" "${file}" 2>/dev/null; then
        _pass "${desc}"
    else
        _fail "${desc} (missing '${pattern}' in ${file})"
    fi
}

echo ""
echo "=== safety-invariants.sh helpers ==="
# shellcheck disable=SC1091
source "${LIB}/safety-invariants.sh" || { echo "FATAL: cannot source safety-invariants.sh" >&2; exit 1; }

tag="$(safety_invariant_tag "${INV_CAP_RESTRICTION_DAY}")"
if [[ "${tag}" == *"[${INV_CAP_RESTRICTION_DAY}]"* ]] && [[ "${tag}" == *"16 h"* ]]; then
    _pass "safety_invariant_tag CAP-RESTRICTION-DAY"
else
    _fail "safety_invariant_tag CAP-RESTRICTION-DAY (got: ${tag})"
fi

link="$(safety_invariant_doc_link "${INV_CAP_WEEKLY_247}")"
if [ "${link}" = "docs/SAFETY.md#the-per-day-16-hour-cap-the-central-invariant" ]; then
    _pass "safety_invariant_doc_link CAP-WEEKLY-247"
else
    _fail "safety_invariant_doc_link CAP-WEEKLY-247 (got: ${link})"
fi

id="$(safety_invariant_id_for_category "configure_block")"
if [ "${id}" = "${INV_CAP_CONFIGURE_BLOCK_DAY}" ]; then
    _pass "safety_invariant_id_for_category configure_block"
else
    _fail "category map configure_block (got: ${id})"
fi

echo ""
echo "=== configure hard-block surfaces ==="
assert_file_contains "${LIB}/configure-ui-errors.sh" "INV_CAP_RESTRICTION_DAY" \
    "show_cap_violation_error cites CAP-RESTRICTION-DAY"
assert_file_contains "${LIB}/configure-ui-errors.sh" "INV_PARTIAL_LOCK_TIGHTEN" \
    "show_partial_lock_violation_error cites PARTIAL-LOCK-TIGHTEN"

assert_file_contains "${LIB}/configure-ui-errors.sh" "safety_invariant_id_for_category" \
    "show_cap_violation_error maps categories to invariant ids"
assert_file_contains "${LIB}/configure-ui-errors.sh" "safety_invariant_doc_link" \
    "show_cap_violation_error includes SAFETY doc link"

assert_file_contains "${LIB}/configure-ui.sh" "INV_CAP_WEEKLY_247" \
    "show_24_7_error cites CAP-WEEKLY-247"
assert_file_contains "${LIB}/configure-ui.sh" "safety_invariant_footer" \
    "show_24_7_error uses safety_invariant_footer"

assert_file_contains "${LIB}/configure-validation.sh" "${INV_POPUP_TIMING_MIN_DISPLAY}" \
    "validate_popup_timing_config cites POPUP-TIMING-MIN-DISPLAY"
assert_file_contains "${LIB}/configure-validation.sh" "docs/SAFETY.md" \
    "validate_popup_timing_config includes SAFETY doc path"

assert_file_contains "${SCRIPT_DIR}/sleep-warning.sh" "safety_invariant_tag" \
    "validate_config_safety logs invariant tag"
assert_file_contains "${LIB}/popup-safety.sh" "[POPUP-WATCHDOG]" \
    "popup-safety watchdog logs cite POPUP-WATCHDOG"

echo ""
echo "=== stale save-anyway wording removed from wizard help ==="
if grep -qF "choose to save anyway" "${LIB}/configure-ui.sh" 2>/dev/null; then
    _fail "configure-ui.sh still contains 'choose to save anyway'"
else
    _pass "configure-ui.sh help text has no save-anyway for 16h cap"
fi

echo ""
echo "Results: ${_PASS} passed, ${_FAIL} failed"
if [ "${_FAIL}" -gt 0 ]; then
    exit 1
fi
exit 0
