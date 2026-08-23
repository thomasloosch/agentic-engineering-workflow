#!/usr/bin/env bash
#
# Tests for rotate-tdd-session-log.sh. Each test seeds a log with known content,
# invokes the hook, and asserts the resulting log STATE (preserved, or
# truncated+header) — not merely that the script ran.
#
# Contract under test: the gate log rotates ONLY on an explicit `--new-slice`
# invocation. Every SessionStart source (startup/resume/clear/compact) must
# PRESERVE the log — truncating on a session boundary erased in-progress slice
# records when the desktop app fired `startup` on a resume that continued the
# same slice.
set -uo pipefail

HOOK="$(dirname "$0")/rotate-tdd-session-log.sh"
SEED='SEEDED-SLICE-RECORDS'
FAILED=0

setup() {
  TESTDIR=$(mktemp -d)
  export CLAUDE_PROJECT_DIR="$TESTDIR"
  mkdir -p "$TESTDIR/.claude/logs"
  LOG="$TESTDIR/.claude/logs/tdd-session.log"
  printf '%s\n' "$SEED" > "$LOG"
}
teardown() { rm -rf "$TESTDIR"; }

pass() { echo "  ✔ $1"; }
fail() { echo "  ✖ $1"; echo "      $2"; FAILED=1; }

session_start() {  # session_start <source>
  printf '{"hook_event_name":"SessionStart","source":"%s"}' "$1" | bash "$HOOK"
}

assert_preserved() {  # assert_preserved <label>
  if grep -q "$SEED" "$LOG"; then pass "$1"
  else fail "$1" "expected '$SEED' to remain; log is now: [$(cat "$LOG")]"; fi
}

echo "▶ rotate-tdd-session-log"

# SessionStart sources must NEVER truncate — a resume/startup mid-slice would
# otherwise erase the red→green records the detector judges.
for src in startup resume clear compact; do
  setup
  session_start "$src"
  assert_preserved "SessionStart $src → log preserved (NOT truncated)"
  teardown
done

# --new-slice is the ONLY truncation path: fresh log + SLICE header.
setup
bash "$HOOK" --new-slice
if ! grep -q "$SEED" "$LOG" && grep -qE '^# SLICE .* new-slice$' "$LOG"; then
  pass "--new-slice → truncated + SLICE header written"
else
  fail "--new-slice → truncated + SLICE header written" "expected '$SEED' gone and a SLICE header; log is now: [$(cat "$LOG")]"
fi
teardown

# #12 part 2 — the slice baseline needs the commit the slice STARTED from, stamped
# here because this is the only moment that reliably predates the slice's own tests.
setup
git -C "$TESTDIR" init -q 2>/dev/null
git -C "$TESTDIR" -c user.email=t@e -c user.name=t commit -q --allow-empty -m base 2>/dev/null
bash "$HOOK" --new-slice
EXPECTED_SHA=$(git -C "$TESTDIR" rev-parse HEAD 2>/dev/null)
if grep -qE "^# BASE $EXPECTED_SHA$" "$LOG"; then
  pass "--new-slice → BASE header stamps the slice's start commit"
else
  fail "--new-slice → BASE header stamps the slice's start commit" "expected '# BASE $EXPECTED_SHA'; log is now: [$(cat "$LOG")]"
fi
teardown

# Not a git repo (or git unavailable): the stamp is simply omitted. The detector
# treats a missing BASE as "no baseline", i.e. today's noisy-but-safe behaviour —
# it must never fall back to a guessed ref, which would exempt the slice's own tests.
setup
bash "$HOOK" --new-slice
if grep -qE '^# SLICE .* new-slice$' "$LOG" && ! grep -q '^# BASE' "$LOG"; then
  pass "--new-slice outside a git repo → SLICE header, no BASE stamp"
else
  fail "--new-slice outside a git repo → SLICE header, no BASE stamp" "expected a SLICE header and no BASE line; log is now: [$(cat "$LOG")]"
fi
teardown

echo ""
if [ "$FAILED" -eq 0 ]; then echo "ALL GREEN"; else echo "SOME RED"; fi
exit "$FAILED"
