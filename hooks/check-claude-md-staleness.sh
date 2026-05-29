#!/usr/bin/env bash
#
# check-claude-md-staleness.sh
#
# SessionStart hook that warns if ~/.claude/CLAUDE.md has not been reviewed
# in 90+ days. Looks for the HTML comment "<!-- Last reviewed: YYYY-MM-DD -->"
# in the file. If missing, warns differently.
#
# Output goes to stderr to be visible without blocking. Exit code always 0.
# SessionStart hooks cannot block anyway.

set -euo pipefail

CLAUDE_MD="$HOME/.claude/CLAUDE.md"

# If file doesn't exist, nothing to check
if [[ ! -f "$CLAUDE_MD" ]]; then
  exit 0
fi

# Extract the Last reviewed date from the HTML comment
# Expected format: <!-- Last reviewed: 2026-05-26. ... -->
LAST_REVIEWED=$(grep -oE 'Last reviewed: [0-9]{4}-[0-9]{2}-[0-9]{2}' "$CLAUDE_MD" 2>/dev/null | head -1 | sed 's/Last reviewed: //' || true)

if [[ -z "$LAST_REVIEWED" ]]; then
  echo "⚠️  Global CLAUDE.md has no 'Last reviewed' marker. Add '<!-- Last reviewed: $(date -I) -->' near the top and prune the file." >&2
  exit 0
fi

# Calculate age in days (portable: works on both GNU and BSD date)
if date --version >/dev/null 2>&1; then
  # GNU date (Linux, WSL2)
  LAST_TS=$(date -d "$LAST_REVIEWED" +%s 2>/dev/null || echo 0)
else
  # BSD date (macOS)
  LAST_TS=$(date -j -f "%Y-%m-%d" "$LAST_REVIEWED" +%s 2>/dev/null || echo 0)
fi

if [[ "$LAST_TS" -eq 0 ]]; then
  # Couldn't parse — bail silently rather than spam
  exit 0
fi

NOW_TS=$(date +%s)
DAYS_OLD=$(( (NOW_TS - LAST_TS) / 86400 ))

if [[ "$DAYS_OLD" -gt 90 ]]; then
  echo "⚠️  Global CLAUDE.md last reviewed $DAYS_OLD days ago ($LAST_REVIEWED). Time for a quarterly prune — run /memory to see what auto-memory has captured, remove duplicates, and update the 'Last reviewed' date." >&2
fi

exit 0
