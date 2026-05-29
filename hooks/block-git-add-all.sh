#!/usr/bin/env bash
#
# block-git-add-all.sh
#
# PreToolUse hook (Bash matcher) that blocks `git add .`, `git add -A`,
# and `git add --all`. Forces explicit staging of files.
#
# Reads JSON tool input from stdin. Blocks via exit code 2.
# Allows the command to proceed via exit code 0.

set -euo pipefail

# Read JSON payload from stdin
PAYLOAD=$(cat)

# Extract the command field
COMMAND=$(echo "$PAYLOAD" | jq -r '.tool_input.command // empty')

# If no command, allow (not our concern)
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Match git add followed by . or -A or --all (as standalone arguments)
# Patterns to block:
#   git add .
#   git add -A
#   git add --all
#   git add -A .
#   sudo git add .
#
# Patterns to allow (must not block):
#   git add file1.md
#   git add src/foo.ts src/bar.ts
#   git add -p
#   git add -u (only modified/deleted, not new — different beast, allowed)

if echo "$COMMAND" | grep -qE '(^|[;&|]|\s)git\s+add\s+(\.|-A|--all)(\s|$)'; then
  echo "🛑 BLOCKED: 'git add .' / 'git add -A' / 'git add --all' is forbidden." >&2
  echo "" >&2
  echo "Reason: agents create out-of-scope files (test configs, generated artifacts," >&2
  echo "strategy docs) that get silently committed. Stage files explicitly:" >&2
  echo "" >&2
  echo "  git add file1.md file2.ts" >&2
  echo "" >&2
  echo "Or stage interactively to review each change:" >&2
  echo "" >&2
  echo "  git add -p" >&2
  echo "" >&2
  echo "Hook source: ~/.claude/hooks/block-git-add-all.sh" >&2
  exit 2
fi

exit 0
