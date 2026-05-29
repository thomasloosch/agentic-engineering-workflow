#!/usr/bin/env bash
#
# auto-update-last-reviewed.sh
#
# PostToolUse hook (Edit|Write matcher) that updates the
# "Last reviewed: YYYY-MM-DD" comment in ~/.claude/CLAUDE.md whenever
# the file is edited.
#
# Trade-off: this updates on every edit, including trivial ones (a typo fix
# would reset the 90-day clock). Accepted because:
#   - The alternative (manual update) means the staleness warning lingers
#     after every real edit, which trains you to ignore it.
#   - If you want a "no, that wasn't really a review" path, edit the file
#     and immediately revert the date back manually.
#
# Reads JSON tool input from stdin. Exit 0 always.

set -euo pipefail

PAYLOAD=$(cat)
FILE_PATH=$(echo "$PAYLOAD" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only act on the global CLAUDE.md
# Match both ~/.claude/CLAUDE.md and the absolute expansion
GLOBAL_CLAUDE_MD="$HOME/.claude/CLAUDE.md"
if [[ "$FILE_PATH" != "$GLOBAL_CLAUDE_MD" ]]; then
  exit 0
fi

if [[ ! -f "$GLOBAL_CLAUDE_MD" ]]; then
  exit 0
fi

# Check if a Last reviewed line exists
if ! grep -q 'Last reviewed: [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' "$GLOBAL_CLAUDE_MD"; then
  # No marker found — don't try to inject one, just exit
  exit 0
fi

TODAY=$(date -I)

# Update the date in place (portable across GNU and BSD sed)
if sed --version >/dev/null 2>&1; then
  # GNU sed (Linux, WSL2)
  sed -i "s/Last reviewed: [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/Last reviewed: $TODAY/" "$GLOBAL_CLAUDE_MD"
else
  # BSD sed (macOS)
  sed -i '' "s/Last reviewed: [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/Last reviewed: $TODAY/" "$GLOBAL_CLAUDE_MD"
fi

# Silent success — no output needed for a PostToolUse maintenance task
exit 0
