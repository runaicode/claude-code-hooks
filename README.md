# Claude Code Hooks

Ready-to-use hook scripts for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that automate linting, testing, formatting, security scanning, and commit message enforcement.

## What Are Claude Code Hooks?

Claude Code supports hooks that run automatically at specific points in its workflow. Hooks are configured in `.claude/settings.json` and can run:

- **Before a command executes** (`PreToolUse`) — validate, lint, or block operations
- **After a command executes** (`PostToolUse`) — test, format, or verify changes
- **On notifications** (`Notification`) — send alerts or log events

## Available Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| [auto-lint.sh](hooks/auto-lint.sh) | After file write | Runs language-appropriate linter on changed files |
| [test-on-save.sh](hooks/test-on-save.sh) | After file write | Runs relevant tests when source files change |
| [format-staged.sh](hooks/format-staged.sh) | Before commit | Auto-formats all staged files |
| [security-scan.sh](hooks/security-scan.sh) | After file write | Checks for hardcoded secrets, SQL injection, and common vulnerabilities |
| [commit-msg-format.sh](hooks/commit-msg-format.sh) | Before commit | Enforces conventional commit message format |

## Installation

### 1. Copy hooks to your project

```bash
# Clone this repo
git clone https://github.com/runaicode/claude-code-hooks.git

# Copy hooks to your project
cp -r claude-code-hooks/hooks /path/to/your/project/.claude/hooks/

# Make executable
chmod +x /path/to/your/project/.claude/hooks/*.sh
```

### 2. Configure in settings.json

Add hook configurations to your `.claude/settings.json` (project-level) or `~/.claude/settings.json` (global):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/auto-lint.sh $FILEPATH"
          },
          {
            "type": "command",
            "command": ".claude/hooks/security-scan.sh $FILEPATH"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/format-staged.sh"
          }
        ]
      }
    ]
  }
}
```

### 3. Use individual hooks

You can also run any hook manually:

```bash
# Lint a specific file
.claude/hooks/auto-lint.sh src/app.py

# Security scan a directory
.claude/hooks/security-scan.sh src/

# Check a commit message
echo "feat: add login" | .claude/hooks/commit-msg-format.sh
```

## Hook Details

### auto-lint.sh

Detects the language of a changed file and runs the appropriate linter:

- **Python**: `ruff check` (falls back to `flake8`, then `pylint`)
- **JavaScript/TypeScript**: `eslint` (falls back to `biome`)
- **Go**: `golangci-lint` (falls back to `go vet`)
- **Rust**: `cargo clippy`
- **Shell**: `shellcheck`

### test-on-save.sh

Maps source files to their test files and runs only the relevant tests:

- `src/utils.py` runs `tests/test_utils.py`
- `src/components/Button.tsx` runs `src/components/Button.test.tsx`
- Supports pytest, Jest, go test, and cargo test

### format-staged.sh

Formats all git-staged files before commit:

- **Python**: `black` + `isort`
- **JavaScript/TypeScript**: `prettier`
- **Go**: `gofmt`
- **Rust**: `rustfmt`
- Re-stages files after formatting

### security-scan.sh

Scans for common security issues:

- Hardcoded API keys and tokens (regex patterns for AWS, GitHub, Stripe, etc.)
- SQL injection patterns (string concatenation in queries)
- Command injection (unsanitized shell execution)
- Insecure functions (`eval`, `exec`, `dangerouslySetInnerHTML`)
- Hardcoded passwords and connection strings

### commit-msg-format.sh

Enforces [Conventional Commits](https://www.conventionalcommits.org/) format:

- Required format: `type(scope): description`
- Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
- Maximum 72 characters for subject line
- Optional body and footer sections

## Customization

Each hook is a standalone bash script that you can modify. Common customizations:

- Add/remove linters in `auto-lint.sh`
- Change test file naming conventions in `test-on-save.sh`
- Add custom regex patterns to `security-scan.sh`
- Modify allowed commit types in `commit-msg-format.sh`

## Requirements

- Bash 4.0+
- Git
- Language-specific tools (linters, formatters) installed for the hooks you use

## License

MIT — use these hooks in any project.
