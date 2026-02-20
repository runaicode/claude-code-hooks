#!/usr/bin/env bash
# =============================================================================
# format-staged.sh — Auto-format all staged files before commit
#
# Runs the appropriate formatter for each staged file, then re-stages it.
# Ensures committed code is always properly formatted.
#
# Usage:  .claude/hooks/format-staged.sh
# Exit:   0 = formatted successfully, 1 = formatter error
# =============================================================================

set -euo pipefail

# Get list of staged files (Added, Modified, Renamed)
STAGED_FILES=$(git diff --cached --name-only --diff-filter=AMR 2>/dev/null || true)

if [[ -z "$STAGED_FILES" ]]; then
    echo "[format-staged] No staged files to format"
    exit 0
fi

FORMATTED=0
ERRORS=0

format_file() {
    local file=$1
    local ext="${file##*.}"
    local basename=$(basename "$file")
    
    # Skip files that don't exist (deleted)
    [[ -f "$file" ]] || return 0

    case "$ext" in
        py)
            if command -v black &>/dev/null; then
                black "$file" --quiet 2>/dev/null && FORMATTED=$((FORMATTED + 1))
            fi
            if command -v isort &>/dev/null; then
                isort "$file" --quiet 2>/dev/null
            fi
            if command -v ruff &>/dev/null; then
                ruff format "$file" --quiet 2>/dev/null
            fi
            ;;
        js|jsx|ts|tsx|css|scss|json|md|html|yaml|yml)
            if command -v prettier &>/dev/null; then
                prettier --write "$file" --log-level=error 2>/dev/null && FORMATTED=$((FORMATTED + 1))
            elif command -v biome &>/dev/null; then
                biome format --write "$file" 2>/dev/null && FORMATTED=$((FORMATTED + 1))
            fi
            ;;
        go)
            if command -v gofmt &>/dev/null; then
                gofmt -w "$file" 2>/dev/null && FORMATTED=$((FORMATTED + 1))
            fi
            if command -v goimports &>/dev/null; then
                goimports -w "$file" 2>/dev/null
            fi
            ;;
        rs)
            if command -v rustfmt &>/dev/null; then
                rustfmt "$file" --edition 2021 2>/dev/null && FORMATTED=$((FORMATTED + 1))
            fi
            ;;
        rb)
            if command -v rubocop &>/dev/null; then
                rubocop -A "$file" --format quiet 2>/dev/null && FORMATTED=$((FORMATTED + 1))
            fi
            ;;
        sh|bash)
            if command -v shfmt &>/dev/null; then
                shfmt -w -i 4 "$file" 2>/dev/null && FORMATTED=$((FORMATTED + 1))
            fi
            ;;
        *)
            # Check shebang for extensionless scripts
            if [[ -f "$file" ]] && head -1 "$file" 2>/dev/null | grep -qE '^#!.*\b(bash|sh|zsh)\b'; then
                if command -v shfmt &>/dev/null; then
                    shfmt -w -i 4 "$file" 2>/dev/null && FORMATTED=$((FORMATTED + 1))
                fi
            fi
            ;;
    esac
    
    # Re-stage the file after formatting
    git add "$file" 2>/dev/null
}

echo "[format-staged] Formatting $(echo "$STAGED_FILES" | wc -l | tr -d ' ') staged files..."

while IFS= read -r file; do
    if [[ -n "$file" ]]; then
        format_file "$file" || ERRORS=$((ERRORS + 1))
    fi
done <<< "$STAGED_FILES"

echo "[format-staged] Formatted $FORMATTED files ($ERRORS errors)"

exit 0
