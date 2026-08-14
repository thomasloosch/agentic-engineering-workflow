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

set -uo pipefail
# NOT `set -e` — under `-e` plus a missing `jq` this exited 127 before printing
# anything, so the warning it exists to produce never appeared.

# shellcheck source=lib/json-extract.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/json-extract.sh"

PAYLOAD=$(cat)

# This hook only ever warns (always exits 0), so there is no fail-closed branch to
# take: an unparseable payload means "say nothing", which is the same as its normal
# quiet path. Using the plain extractor is deliberate, not an oversight.
COMMAND="$(json_string_value 'command' "$PAYLOAD" || true)"

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
CWD="$(json_string_value 'cwd' "$PAYLOAD" || true)"
if [[ -z "$CWD" || ! -d "$CWD/.git" ]]; then
  exit 0  # Not a git repo or no cwd info — let it pass
fi

CURRENT_BRANCH=$(cd "$CWD" && git branch --show-current 2>/dev/null || echo "")

if [[ "$CURRENT_BRANCH" == "main" ]] || [[ "$CURRENT_BRANCH" == "master" ]]; then
  echo "⚠️  Committing directly to $CURRENT_BRANCH." >&2
  echo "" >&2
  echo "Engineering Standard #10 is project-conditional — for solo repos, direct-to-main is expected (ADR-0001); for collaborative repos, branch + PR." >&2
  echo "" >&2
  echo "If this is intentional (bootstrap commit, hotfix, etc.), proceed." >&2
  echo "To suppress this warning for a known-deliberate commit, prefix with:" >&2
  echo "" >&2
  echo "  ALLOW_MAIN_COMMIT=1 git commit -m \"...\"" >&2
  echo "" >&2
  echo "Hook source: ~/.claude/hooks/warn-direct-commit-to-main.sh" >&2
fi

exit 0
