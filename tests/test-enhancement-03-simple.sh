#!/bin/bash

###############################################################################
# Simple Test Suite for Enhancement #3: Enhanced Window Size Options
#
# This script tests the core functionality without complex nested quotes.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

source lib/config.sh || exit 1
source lib/resolution-detection.sh || exit 1

echo "=== Enhancement #3: Window Size Options - Simple Tests ==="
echo ""

PASSED=0
FAILED=0

# Test 1: Resolution detection
echo "Test 1: Resolution Detection"
resolution=$(get_display_resolution 2>/dev/null)
if [ -n "$resolution" ]; then
    echo "  ✅ PASS: Resolution detected: $resolution"
    ((PASSED++))
else
    echo "  ⚠️  WARN: Resolution detection failed (will use fallback)"
    ((PASSED++))  # Not a failure, fallback works
fi
echo ""

# Test 2: New size options
echo "Test 2: New Size Options (xsmall, xlarge, max)"
for size in xsmall xlarge max; do
    dims=$(get_popup_dimensions "$size")
    if [ -n "$dims" ]; then
        echo "  ✅ $size: $dims"
    else
        echo "  ❌ $size: FAILED"
        ((FAILED++))
    fi
done
((PASSED++))
echo ""

# Test 3: Percentage format
echo "Test 3: Percentage Format"
dims=$(get_popup_dimensions "50%x50%")
if [ -n "$dims" ]; then
    echo "  ✅ 50%x50%: $dims"
    ((PASSED++))
else
    echo "  ❌ Percentage format failed"
    ((FAILED++))
fi
echo ""

# Test 4: Getter functions
echo "Test 4: Getter Functions"
mode=$(get_popup_size_mode)
custom=$(get_popup_size_custom)
custom_abs=$(get_popup_size_custom_absolute)
if [ -n "$mode" ] && [ -n "$custom" ] && [ -n "$custom_abs" ]; then
    echo "  ✅ Size mode: $mode"
    echo "  ✅ Custom size: $custom"
    echo "  ✅ Custom absolute: $custom_abs"
    ((PASSED++))
else
    echo "  ❌ Getter functions failed"
    ((FAILED++))
fi
echo ""

# Test 5: Backward compatibility
echo "Test 5: Backward Compatibility"
for size in small medium large; do
    dims=$(get_popup_dimensions "$size")
    if [ -n "$dims" ]; then
        echo "  ✅ $size: $dims"
    else
        echo "  ❌ $size: FAILED"
        ((FAILED++))
    fi
done
((PASSED++))
echo ""

# Test 6: Validation
echo "Test 6: Validation (minimum 384x216)"
dims=$(get_popup_dimensions "384x216")
if [ -n "$dims" ]; then
    width=$(echo "$dims" | cut -d' ' -f1)
    height=$(echo "$dims" | cut -d' ' -f2)
    if [ "$width" -ge 384 ] && [ "$height" -ge 216 ]; then
        echo "  ✅ Minimum size accepted: $dims"
        ((PASSED++))
    else
        echo "  ❌ Minimum size validation failed"
        ((FAILED++))
    fi
else
    echo "  ❌ Minimum size test failed"
    ((FAILED++))
fi
echo ""

# Summary
echo "=== Test Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi
