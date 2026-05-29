# Claude Code Hooks

This directory contains user-level hooks that fire deterministically at lifecycle events in Claude Code. Hooks are the enforcement layer — they run every time their event fires, regardless of what the model decides.

Configured in `~/.claude/settings.json` under the `hooks` key.

## What's here

| Script | Event | Effect |
|---|---|---|
| `check-claude-md-staleness.sh` | SessionStart | Warns at session start if global CLAUDE.md hasn't been reviewed in 90+ days |
| `block-git-add-all.sh` | PreToolUse (Bash) | Blocks `git add .`, `git add -A`, `git add --all` |
| `block-force-push-to-main.sh` | PreToolUse (Bash) | Blocks force-push to main/master branches |
| `warn-direct-commit-to-main.sh` | PreToolUse (Bash) | Warns (does not block) when committing directly to main/master |
| `auto-update-last-reviewed.sh` | PostToolUse (Edit|Write) | Updates the "Last reviewed" date in global CLAUDE.md when the file is edited |

## Override mechanisms

Most hooks are intentionally hard to bypass — that's the point. The exceptions:

- **Direct commit to main warning** — to silence the warning for a deliberate commit, prefix with `ALLOW_MAIN_COMMIT=1`.
- **Force-push and `git add .`** — no in-tool override. If you genuinely need either, run the command in a regular terminal outside Claude Code.

## Exit code conventions (Anthropic spec)

- `0` — allow / proceed silently
- `2` — block the action (only on blocking-capable events: PreToolUse, UserPromptSubmit, Stop)
- Other non-zero — non-blocking error (action proceeds, error logged)

SessionStart and PostToolUse hooks cannot block. They run for observability and side-effects only.

## Debugging

If a hook isn't firing as expected:

1. Run `/hooks` inside Claude Code to see the configured hooks
2. Check the script is executable: `ls -la ~/.claude/hooks/`
3. Test the script directly: `echo '{"tool_input":{"command":"git add ."}}' | ~/.claude/hooks/block-git-add-all.sh; echo "exit: $?"`
4. Use the InstructionsLoaded hook with verbose logging if needed (see Anthropic docs)

## Adding new hooks

1. Write the script in this directory, make it executable
2. Add an entry in `~/.claude/settings.json` under the appropriate event
3. Test by running the relevant command in a Claude Code session
4. Document it in the table above

## Things to NOT do

- Don't put project-specific hooks here — those belong in `<project>/.claude/settings.json`
- Don't write hooks that depend on a specific shell beyond bash; the script header is `#!/usr/bin/env bash`
- Don't make hooks slow — they run on every event match. Aim for <100ms execution
- Don't write hooks that modify files outside the user's expressed intent (auto-update-last-reviewed is the explicit exception, scoped to a single known file)
