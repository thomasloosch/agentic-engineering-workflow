#!/usr/bin/env bash
#
# warn-direct-commit-to-main.sh
#
# PreToolUse hook (Bash matcher) that warns when committing directly to main
# or master. Does NOT block — just prints a visible warning so you get a
# moment to think.
#
# To proceed with a deliberate main commit, prefix with ALLOW:
#   ALLOW_MAIN_COMMIT=1 git commit -m "..."
#
# Reads JSON tool input from stdin. Exit 0 always (non-blocking).

set -euo pipefail

PAYLOAD=$(cat)
COMMAND=$(echo "$PAYLOAD" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Only act on `git commit` commands (not git config, not git commit-tree, etc.)
if ! echo "$COMMAND" | grep -qE '(^|[;&|]|\s)git\s+commit(\s|$)'; then
  exit 0
fi

# If explicit override is set, skip the warning
if echo "$COMMAND" | grep -qE 'ALLOW_MAIN_COMMIT=1'; then
  exit 0
fi

# Determine current branch from cwd
CWD=$(echo "$PAYLOAD" | jq -r '.cwd // empty')
if [[ -z "$CWD" || ! -d "$CWD/.git" ]]; then
  exit 0  # Not a git repo or no cwd info — let it pass
fi

CURRENT_BRANCH=$(cd "$CWD" && git branch --show-current 2>/dev/null || echo "")

if [[ "$CURRENT_BRANCH" == "main" ]] || [[ "$CURRENT_BRANCH" == "master" ]]; then
  echo "⚠️  Committing directly to $CURRENT_BRANCH." >&2
  echo "" >&2
  echo "Engineering Standard #10: changes go via feature branch + PR." >&2
  echo "" >&2
  echo "If this is intentional (bootstrap commit, hotfix, etc.), proceed." >&2
  echo "To suppress this warning for a known-deliberate commit, prefix with:" >&2
  echo "" >&2
  echo "  ALLOW_MAIN_COMMIT=1 git commit -m \"...\"" >&2
  echo "" >&2
  echo "Hook source: ~/.claude/hooks/warn-direct-commit-to-main.sh" >&2
fi

exit 0
