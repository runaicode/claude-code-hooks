#!/usr/bin/env bash
# =============================================================================
# test-on-save.sh — Run relevant tests when source files change
#
# Maps source files to their corresponding test files and runs only those tests.
# Supports common test file naming conventions across multiple languages.
#
# Usage:  .claude/hooks/test-on-save.sh <filepath>
# Exit:   0 = tests pass/no tests found, 1 = test failures
# =============================================================================

set -euo pipefail

FILE="${1:-}"

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
    exit 0
fi

DIR=$(dirname "$FILE")
BASENAME=$(basename "$FILE")
NAME="${BASENAME%.*}"
EXT="${BASENAME##*.}"

# Skip if the changed file is itself a test file
if [[ "$NAME" =~ ^test_ || "$NAME" =~ _test$ || "$NAME" =~ \.test$ || "$NAME" =~ \.spec$ || "$BASENAME" =~ _test\. || "$BASENAME" =~ \.test\. || "$BASENAME" =~ \.spec\. ]]; then
    # Run the test file directly
    TEST_FILE="$FILE"
else
    TEST_FILE=""
fi

find_python_test() {
    # Convention: src/module.py -> tests/test_module.py or test_module.py
    local candidates=(
        "$DIR/test_${NAME}.py"
        "$DIR/tests/test_${NAME}.py"
        "${DIR}/../tests/test_${NAME}.py"
        "tests/test_${NAME}.py"
        "test_${NAME}.py"
    )
    for candidate in "${candidates[@]}"; do
        if [[ -f "$candidate" ]]; then
            TEST_FILE="$candidate"
            return
        fi
    done
}

find_js_test() {
    # Convention: Component.tsx -> Component.test.tsx or __tests__/Component.test.tsx
    local candidates=(
        "$DIR/${NAME}.test.${EXT}"
        "$DIR/${NAME}.spec.${EXT}"
        "$DIR/${NAME}.test.js"
        "$DIR/${NAME}.spec.js"
        "$DIR/${NAME}.test.ts"
        "$DIR/${NAME}.spec.ts"
        "$DIR/__tests__/${NAME}.test.${EXT}"
        "$DIR/__tests__/${NAME}.test.js"
        "$DIR/__tests__/${NAME}.test.ts"
    )
    for candidate in "${candidates[@]}"; do
        if [[ -f "$candidate" ]]; then
            TEST_FILE="$candidate"
            return
        fi
    done
}

find_go_test() {
    # Convention: module.go -> module_test.go (same directory)
    local candidate="$DIR/${NAME}_test.go"
    if [[ -f "$candidate" ]]; then
        TEST_FILE="$candidate"
    fi
}

find_rust_test() {
    # Rust tests are usually in the same file or in tests/ directory
    if grep -q '#\[cfg(test)\]' "$FILE" 2>/dev/null; then
        TEST_FILE="$FILE"  # Inline tests
    elif [[ -f "tests/${NAME}.rs" ]]; then
        TEST_FILE="tests/${NAME}.rs"
    fi
}

# Find the test file if we don't already have one
if [[ -z "$TEST_FILE" ]]; then
    case "$EXT" in
        py)           find_python_test ;;
        js|jsx|mjs)   find_js_test ;;
        ts|tsx)       find_js_test ;;
        go)           find_go_test ;;
        rs)           find_rust_test ;;
    esac
fi

# No test file found
if [[ -z "$TEST_FILE" ]]; then
    echo "[test-on-save] No test file found for $BASENAME"
    exit 0
fi

echo "[test-on-save] Running tests: $TEST_FILE"

# Run the appropriate test runner
case "$EXT" in
    py)
        if command -v pytest &>/dev/null; then
            pytest "$TEST_FILE" -x --tb=short -q 2>&1 | tail -20
        elif command -v python3 &>/dev/null; then
            python3 -m unittest "$TEST_FILE" 2>&1 | tail -20
        fi
        ;;
    js|jsx|mjs|ts|tsx)
        if command -v npx &>/dev/null; then
            if [[ -f "vitest.config.ts" || -f "vitest.config.js" ]]; then
                npx vitest run "$TEST_FILE" --reporter=verbose 2>&1 | tail -30
            else
                npx jest "$TEST_FILE" --verbose 2>&1 | tail -30
            fi
        fi
        ;;
    go)
        go test -v -run "" "./$DIR/..." 2>&1 | tail -20
        ;;
    rs)
        if [[ "$TEST_FILE" == "$FILE" ]]; then
            cargo test --quiet 2>&1 | tail -20
        else
            cargo test --test "$NAME" --quiet 2>&1 | tail -20
        fi
        ;;
esac

EXIT_CODE=${PIPESTATUS[0]:-$?}

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "[test-on-save] All tests passed"
else
    echo "[test-on-save] Tests FAILED"
fi

exit $EXIT_CODE
