#!/usr/bin/env bash
# =============================================================================
# security-scan.sh — Scan files for hardcoded secrets and security anti-patterns
#
# Checks for common security issues: API keys, passwords, SQL injection patterns,
# insecure functions, and other vulnerabilities.
#
# Usage:  .claude/hooks/security-scan.sh <filepath_or_directory>
# Exit:   0 = clean, 1 = issues found
# =============================================================================

set -euo pipefail

TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
    echo "[security-scan] No target specified"
    exit 0
fi

ISSUES=0

scan_file() {
    local file=$1
    local basename=$(basename "$file")
    local ext="${file##*.}"
    
    # Skip binary files, images, and lock files
    case "$basename" in
        *.png|*.jpg|*.gif|*.ico|*.woff*|*.ttf|*.eot|*.svg)  return 0 ;;
        package-lock.json|yarn.lock|Cargo.lock|poetry.lock)  return 0 ;;
        *.min.js|*.min.css|*.map)                             return 0 ;;
    esac
    
    [[ -f "$file" ]] || return 0
    
    local findings=""
    
    # --- Hardcoded Secrets ---
    
    # AWS Access Keys
    if grep -nP 'AKIA[0-9A-Z]{16}' "$file" 2>/dev/null; then
        findings+="  CRITICAL: AWS Access Key ID found\n"
        ISSUES=$((ISSUES + 1))
    fi
    
    # AWS Secret Keys
    if grep -nP '["\x27][A-Za-z0-9/+=]{40}["\x27]' "$file" 2>/dev/null | grep -qi 'secret\|aws'; then
        findings+="  CRITICAL: Possible AWS Secret Key found\n"
        ISSUES=$((ISSUES + 1))
    fi
    
    # GitHub tokens
    if grep -nP '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{36,}' "$file" 2>/dev/null; then
        findings+="  CRITICAL: GitHub token found\n"
        ISSUES=$((ISSUES + 1))
    fi
    
    # Generic API keys (common patterns)
    if grep -nPi '(api[_-]?key|api[_-]?secret|apikey)\s*[=:]\s*["\x27][A-Za-z0-9]{20,}["\x27]' "$file" 2>/dev/null; then
        findings+="  HIGH: Hardcoded API key found\n"
        ISSUES=$((ISSUES + 1))
    fi
    
    # Stripe keys
    if grep -nP '(sk|pk)_(test|live)_[A-Za-z0-9]{20,}' "$file" 2>/dev/null; then
        findings+="  CRITICAL: Stripe key found\n"
        ISSUES=$((ISSUES + 1))
    fi
    
    # Hardcoded passwords
    if grep -nPi '(password|passwd|pwd)\s*[=:]\s*["\x27][^"\x27]{4,}["\x27]' "$file" 2>/dev/null | grep -vP '(example|placeholder|changeme|your_|TODO|FIXME|<|{{|\$\{)'; then
        findings+="  HIGH: Possible hardcoded password found\n"
        ISSUES=$((ISSUES + 1))
    fi
    
    # Private keys
    if grep -n 'BEGIN.*PRIVATE KEY' "$file" 2>/dev/null; then
        findings+="  CRITICAL: Private key found in source code\n"
        ISSUES=$((ISSUES + 1))
    fi
    
    # Connection strings with credentials
    if grep -nPi '(mysql|postgres|mongodb|redis)://[^:]+:[^@]+@' "$file" 2>/dev/null; then
        findings+="  HIGH: Database connection string with credentials\n"
        ISSUES=$((ISSUES + 1))
    fi
    
    # --- Insecure Patterns ---
    
    # eval() usage (JS/Python)
    if [[ "$ext" =~ ^(js|ts|py|jsx|tsx)$ ]]; then
        if grep -nP '\beval\s*\(' "$file" 2>/dev/null; then
            findings+="  MEDIUM: eval() usage — risk of code injection\n"
            ISSUES=$((ISSUES + 1))
        fi
    fi
    
    # SQL injection patterns (string concatenation in queries)
    if grep -nPi "(execute|query|raw)\s*\(.*[\"']\s*\+\s*|f[\"'].*SELECT.*{|\.format\(.*SELECT" "$file" 2>/dev/null; then
        findings+="  HIGH: Possible SQL injection — use parameterized queries\n"
        ISSUES=$((ISSUES + 1))
    fi
    
    # Shell injection
    if grep -nP '(os\.system|subprocess\.(call|run|Popen))\s*\(.*\+' "$file" 2>/dev/null; then
        findings+="  HIGH: Possible command injection — use shell=False with list args\n"
        ISSUES=$((ISSUES + 1))
    fi
    
    # dangerouslySetInnerHTML (React XSS)
    if grep -n 'dangerouslySetInnerHTML' "$file" 2>/dev/null; then
        findings+="  MEDIUM: dangerouslySetInnerHTML — ensure content is sanitized\n"
        ISSUES=$((ISSUES + 1))
    fi
    
    # Disabled SSL verification
    if grep -nPi '(verify\s*=\s*False|NODE_TLS_REJECT_UNAUTHORIZED\s*=\s*["\x27]0|rejectUnauthorized\s*:\s*false)' "$file" 2>/dev/null; then
        findings+="  MEDIUM: SSL verification disabled\n"
        ISSUES=$((ISSUES + 1))
    fi
    
    # Output findings
    if [[ -n "$findings" ]]; then
        echo "[security-scan] Issues in $basename:"
        echo -e "$findings"
    fi
}

# Scan single file or directory
if [[ -d "$TARGET" ]]; then
    echo "[security-scan] Scanning directory: $TARGET"
    while IFS= read -r -d '' file; do
        scan_file "$file"
    done < <(find "$TARGET" -type f -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' -not -path '*/__pycache__/*' -print0 2>/dev/null)
else
    scan_file "$TARGET"
fi

if [[ $ISSUES -eq 0 ]]; then
    echo "[security-scan] Clean — no issues found"
else
    echo "[security-scan] Found $ISSUES potential security issue(s)"
fi

exit $([[ $ISSUES -eq 0 ]] && echo 0 || echo 1)
