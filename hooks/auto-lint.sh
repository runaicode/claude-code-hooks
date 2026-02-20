#!/usr/bin/env bash
# =============================================================================
# auto-lint.sh — Automatically lint files after Claude Code writes/edits them
# 
# Detects the file's language and runs the appropriate linter. Falls back
# gracefully if the preferred linter isn't installed.
#
# Usage:  .claude/hooks/auto-lint.sh <filepath>
# Exit:   0 = pass/no linter available, 1 = lint errors found
# =============================================================================

set -euo pipefail

FILE="${1:-}"

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
    echo "[auto-lint] No file provided or file doesn't exist"
    exit 0
fi

EXT="${FILE##*.}"
BASENAME=$(basename "$FILE")
EXIT_CODE=0

lint_python() {
    if command -v ruff &>/dev/null; then
        echo "[auto-lint] Running ruff on $BASENAME"
        ruff check "$FILE" --fix --quiet || EXIT_CODE=1
    elif command -v flake8 &>/dev/null; then
        echo "[auto-lint] Running flake8 on $BASENAME"
        flake8 "$FILE" --max-line-length=120 || EXIT_CODE=1
    elif command -v pylint &>/dev/null; then
        echo "[auto-lint] Running pylint on $BASENAME"
        pylint "$FILE" --disable=C0114,C0115,C0116 --max-line-length=120 || EXIT_CODE=1
    else
        echo "[auto-lint] No Python linter found (install ruff, flake8, or pylint)"
    fi
}

lint_javascript() {
    if command -v eslint &>/dev/null; then
        echo "[auto-lint] Running eslint on $BASENAME"
        eslint "$FILE" --fix --quiet 2>/dev/null || EXIT_CODE=1
    elif command -v biome &>/dev/null; then
        echo "[auto-lint] Running biome on $BASENAME"
        biome check "$FILE" --write 2>/dev/null || EXIT_CODE=1
    else
        echo "[auto-lint] No JS/TS linter found (install eslint or biome)"
    fi
}

lint_go() {
    if command -v golangci-lint &>/dev/null; then
        echo "[auto-lint] Running golangci-lint on $BASENAME"
        golangci-lint run "$FILE" 2>/dev/null || EXIT_CODE=1
    elif command -v go &>/dev/null; then
        echo "[auto-lint] Running go vet on $BASENAME"
        go vet "$FILE" 2>/dev/null || EXIT_CODE=1
    else
        echo "[auto-lint] No Go linter found"
    fi
}

lint_rust() {
    if command -v cargo &>/dev/null; then
        echo "[auto-lint] Running cargo clippy"
        cargo clippy --quiet 2>/dev/null || EXIT_CODE=1
    else
        echo "[auto-lint] cargo not found"
    fi
}

lint_shell() {
    if command -v shellcheck &>/dev/null; then
        echo "[auto-lint] Running shellcheck on $BASENAME"
        shellcheck "$FILE" -S warning || EXIT_CODE=1
    else
        echo "[auto-lint] shellcheck not found"
    fi
}

lint_ruby() {
    if command -v rubocop &>/dev/null; then
        echo "[auto-lint] Running rubocop on $BASENAME"
        rubocop "$FILE" --autocorrect --format quiet 2>/dev/null || EXIT_CODE=1
    else
        echo "[auto-lint] rubocop not found"
    fi
}

# Route to the correct linter based on file extension
case "$EXT" in
    py)           lint_python ;;
    js|jsx|mjs)   lint_javascript ;;
    ts|tsx)       lint_javascript ;;
    go)           lint_go ;;
    rs)           lint_rust ;;
    sh|bash|zsh)  lint_shell ;;
    rb)           lint_ruby ;;
    *)
        # Check shebang for shell scripts without extension
        if head -1 "$FILE" 2>/dev/null | grep -qE '^#!.*\b(bash|sh|zsh)\b'; then
            lint_shell
        fi
        ;;
esac

if [[ $EXIT_CODE -ne 0 ]]; then
    echo "[auto-lint] Issues found in $BASENAME"
fi

exit $EXIT_CODE
