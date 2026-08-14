#!/usr/bin/env bash
#
# block-git-add-all.sh
#
# PreToolUse hook (Bash matcher) that blocks `git add .`, `git add -A`,
# and `git add --all`. Forces explicit staging of files.
#
# Reads JSON tool input from stdin. Blocks via exit code 2.
# Allows the command to proceed via exit code 0.

set -uo pipefail
# NOTE: deliberately NOT `set -e`. Under `-e` this hook exited 127 at its first
# extraction line when `jq` was missing — a non-blocking exit code, so the guard
# failed OPEN and `git add -A` proceeded unguarded. Error handling here is
# explicit so an unexpected condition can end in a BLOCK rather than a shrug.

# shellcheck source=lib/json-extract.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/json-extract.sh"

DANGER='git[[:space:]]+add[[:space:]]+(\.|-A|--all)([[:space:]]|\\|"|$)'

# Read JSON payload from stdin
PAYLOAD=$(cat)

# Extract the command field. A parse failure that still smells like `git add -A`
# blocks rather than passes — see json_extract_or_fail_closed.
COMMAND="$(json_extract_or_fail_closed 'command' "$PAYLOAD" "$DANGER" 'block-git-add-all')"
case $? in
  0) ;;   # parsed cleanly
  2)
    echo "🛑 BLOCKED: could not parse the hook payload, and it contains something" >&2
    echo "   that looks like 'git add .' / '-A' / '--all'. Refusing rather than" >&2
    echo "   guessing — an unreadable payload is not evidence of a safe command." >&2
    echo "" >&2
    echo "Hook source: ~/.claude/hooks/block-git-add-all.sh" >&2
    exit 2
    ;;
  *) exit 0 ;;   # unparseable but nothing alarming — not our concern
esac

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

# Match against the COMMANDS only. A heredoc body is data — a commit message, a
# file being written — and matching it blocked a commit whose message merely
# documented this guard. See strip_heredoc_bodies for the trade-off taken.
COMMAND_ONLY="$(strip_heredoc_bodies "$COMMAND")"

if echo "$COMMAND_ONLY" | grep -qE '(^|[;&|]|\s)git\s+add\s+(\.|-A|--all)(\s|$)'; then
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
