#!/usr/bin/env bash
#
# rotate-tdd-session-log.sh — rotate the TDD gate log at an explicit slice
# boundary ONLY.
#
# Two invocation modes:
#   1. `rotate-tdd-session-log.sh --new-slice` → truncate the gate log and write
#      a fresh `# SLICE <iso>` header. This is the ONLY path that truncates. Run
#      it once at the start of a TDD slice, before the first RED.
#   2. SessionStart hook (JSON payload on stdin) → NEVER truncate. A session
#      boundary (startup / resume / clear / compact) must not wipe an
#      in-progress slice: the desktop app fires `startup` on resume, and
#      truncating there erased mid-slice red→green history, making the gate's
#      verdict untrustworthy. So this path drains stdin and exits — a no-op.
set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
LOG="${TDD_LOG:-$PROJECT_DIR/.claude/logs/tdd-session.log}"

if [ "${1:-}" = "--new-slice" ]; then
  # Need somewhere to write: an explicit TDD_LOG, or a project dir to derive it.
  [ -z "$PROJECT_DIR" ] && [ -z "${TDD_LOG:-}" ] && exit 0
  ISO=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  LOG_DIR="$(dirname "$LOG")"
  [ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"
  printf '# SLICE %s new-slice\n' "$ISO" > "$LOG"
  exit 0
fi

# SessionStart hook path: consume the payload so the caller's write doesn't
# break, then do nothing. Rotation is now the explicit --new-slice action above.
cat >/dev/null 2>&1 || true
exit 0
