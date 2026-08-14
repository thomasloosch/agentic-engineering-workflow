#!/usr/bin/env bash
#
# block-force-push-to-main.sh
#
# PreToolUse hook (Bash matcher) that blocks force-push to main/master.
# Catches `git push --force`, `git push -f`, `git push --force-with-lease`
# when targeting main, master, or when the current branch is main/master.
#
# Reads JSON tool input from stdin. Blocks via exit code 2.

set -uo pipefail
# NOT `set -e` — see the note in block-git-add-all.sh. Under `-e` plus a missing
# `jq` this hook exited 127, which Claude Code treats as a non-blocking error, so
# a force-push to main was never actually guarded.

# shellcheck source=lib/json-extract.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/json-extract.sh"

DANGER='git[[:space:]]+push.*(--force|-f([[:space:]]|\\|"|$)|--force-with-lease)'

PAYLOAD=$(cat)

COMMAND="$(json_extract_or_fail_closed 'command' "$PAYLOAD" "$DANGER" 'block-force-push-to-main')"
case $? in
  0) ;;
  2)
    echo "🛑 BLOCKED: could not parse the hook payload, and it contains what looks" >&2
    echo "   like a force-push. Refusing rather than guessing — force-push to the" >&2
    echo "   canonical branch is unrecoverable, so an unreadable payload is not" >&2
    echo "   grounds to allow it." >&2
    echo "" >&2
    echo "Hook source: ~/.claude/hooks/block-force-push-to-main.sh" >&2
    exit 2
    ;;
  *) exit 0 ;;
esac

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Detect force-push patterns
# Patterns: --force, -f (as flag), --force-with-lease
IS_FORCE_PUSH=false
if echo "$COMMAND" | grep -qE 'git\s+push.*(--force(\s|$)|-f(\s|$)|--force-with-lease)'; then
  IS_FORCE_PUSH=true
fi

if [[ "$IS_FORCE_PUSH" == false ]]; then
  exit 0
fi

# At this point we have a force-push. Now check if it targets a protected branch.
# Patterns to block:
#   git push --force origin main
#   git push -f origin master
#   git push --force-with-lease origin main
#
# Also block if no target is given and current branch is main/master
# (because that implies pushing the current branch).

TARGET_BRANCH=""
# Try to parse "origin <branch>" or "<remote> <branch>"
if echo "$COMMAND" | grep -qE 'git\s+push.*\s(origin|upstream)\s+(main|master)(\s|$)'; then
  TARGET_BRANCH="main_or_master"
fi

# Also check current branch — if no explicit target, current branch is implied
CWD="$(json_string_value 'cwd' "$PAYLOAD" || true)"
CURRENT_BRANCH=""
if [[ -n "$CWD" && -d "$CWD/.git" ]]; then
  CURRENT_BRANCH=$(cd "$CWD" && git branch --show-current 2>/dev/null || echo "")
fi

# Block if: explicitly targets main/master, OR current branch is main/master
if [[ "$TARGET_BRANCH" == "main_or_master" ]] || [[ "$CURRENT_BRANCH" == "main" ]] || [[ "$CURRENT_BRANCH" == "master" ]]; then
  echo "🛑 BLOCKED: force-push to main/master is forbidden." >&2
  echo "" >&2
  echo "Command: $COMMAND" >&2
  echo "" >&2
  echo "Reason: force-push to the canonical branch is unrecoverable. If you" >&2
  echo "genuinely need this (e.g., scrubbing a leaked secret), run the command" >&2
  echo "in a regular terminal outside Claude Code, with full attention to what" >&2
  echo "you're doing." >&2
  echo "" >&2
  echo "Hook source: ~/.claude/hooks/block-force-push-to-main.sh" >&2
  exit 2
fi

exit 0
