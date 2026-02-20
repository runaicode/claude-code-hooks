# Claude Code Hooks

> Useful hooks, scripts, and automation for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI.

By [RunAICode.ai](https://runaicode.ai)

## What Are Hooks?

Claude Code hooks are shell commands that execute in response to events like tool calls. They let you automate linting, validation, notifications, and more — triggered by Claude's actions.

## Available Hooks

### Pre-commit
- **Lint on edit** — Auto-run ESLint/Prettier when Claude edits a file
- **Type check** — Run TypeScript compiler before allowing commits
- **Security scan** — Check for secrets/credentials in staged files

### Post-action
- **Auto-format** — Format code after Claude writes it
- **Test runner** — Auto-run relevant tests after code changes
- **Notification** — Send Slack/Discord alerts on significant changes

### Context Management
- **Session state** — Auto-save progress for context recovery
- **Compaction handler** — Preserve critical state on context compression

## Installation

```bash
# Clone this repo
git clone https://github.com/runaicode/claude-code-hooks.git

# Copy hooks to your Claude Code config
cp claude-code-hooks/hooks/* ~/.claude/hooks/
```

## Contributing

Built a useful hook? Share it. We test everything before merging.

## License

MIT

---

*Part of the [RunAICode](https://github.com/runaicode) collection*
