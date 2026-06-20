#!/usr/bin/env bash
#
# rotate-tdd-session-log.sh — driven test-first; branching added per cycle.
set -uo pipefail

PAYLOAD=$(cat)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
[ -z "$PROJECT_DIR" ] && exit 0

LOG="$PROJECT_DIR/.claude/logs/tdd-session.log"
ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
SOURCE=$(printf '%s' "$PAYLOAD" \
  | grep -oE '"source"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | sed -E 's/.*"([^"]*)"$/\1/' || true)

if [ "$SOURCE" = "startup" ] || [ "$SOURCE" = "clear" ]; then
  LOG_DIR="$(dirname "$LOG")"
  [ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"
  printf '# SESSION %s %s\n' "$ISO" "$SOURCE" > "$LOG"
fi

exit 0
