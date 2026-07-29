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
  # Stamp the commit the slice starts FROM (#12 part 2). The detector resolves the
  # slice baseline — the tests that already existed — by reading test files at this
  # ref, so pre-existing tests are no longer misread as test-after when a recorded
  # run happens to include them.
  #
  # This is the only moment that reliably predates the slice's own tests, which is
  # why it is stamped here and not derived later: HEAD moves as the slice commits,
  # and a later HEAD would exempt the very tests being judged.
  #
  # Best-effort by design. No git, no repo, detached weirdness → no stamp, and the
  # detector then applies no baseline at all. That is the safe direction: the old
  # false-positive noise, never a silently-exempted test.
  GIT_DIR_CTX="${PROJECT_DIR:-$LOG_DIR}"
  SHA=$(git -C "$GIT_DIR_CTX" rev-parse HEAD 2>/dev/null || true)
  [ -n "$SHA" ] && printf '# BASE %s\n' "$SHA" >> "$LOG"
  exit 0
fi

# SessionStart hook path: consume the payload so the caller's write doesn't
# break, then do nothing. Rotation is now the explicit --new-slice action above.
cat >/dev/null 2>&1 || true
exit 0
