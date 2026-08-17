#!/usr/bin/env bash
#
# Tests for the Claude Code LIFECYCLE hooks (hooks/*.sh).
#
# Contract under test: each hook is handed a JSON payload on stdin and signals
# its verdict through its EXIT CODE. Claude Code treats exit 2 as "block this
# tool call" and every other non-zero as a non-blocking error. That asymmetry is
# the whole reason this suite exists: a hook that dies at 127 has not "failed to
# run", it has failed OPEN — the dangerous command proceeds and nothing says so.
#
# These hooks depended on `jq`, which is absent from this MINGW runtime, so all
# four exited 127 before reaching a single line of their own logic. They were
# silently unenforcing (issue: hook revival). The tests below pin the behaviour
# through the REAL invocation path — piping JSON into the executable exactly as
# Claude Code does — not by sourcing internals, so a regression that breaks
# argument handling or reintroduces a missing binary is caught rather than
# stepped around (verification.md catch 5).
set -uo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILED=0

pass() { echo "  ✔ $1"; }
fail() { echo "  ✖ $1"; echo "      $2"; FAILED=1; }

# Build a PreToolUse Bash payload. Mirrors the real shape Claude Code sends.
# The command is embedded raw, so callers pass already-JSON-safe text.
bash_payload() {  # bash_payload <command> [cwd]
  printf '{"session_id":"test","hook_event_name":"PreToolUse","tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s","description":"test"}}' \
    "${2:-$HOOKS_DIR}" "$1"
}

# Run a hook the way Claude Code does: execute it, feed JSON on stdin, keep the
# exit code. stderr is folded in because the hook's explanation is the payload a
# human sees when it blocks.
run_hook() {  # run_hook <hook-file> <payload> ; echoes output, returns exit code
  printf '%s' "$2" | "$HOOKS_DIR/$1" 2>&1
}

echo "▶ lifecycle hooks"

# 1. block-git-add-all must BLOCK (exit 2) on `git add -A`.
#    Not "must exit non-zero" — 127 is non-zero and means the guard died without
#    blocking anything. Only 2 actually stops the command.
out=$(run_hook "block-git-add-all.sh" "$(bash_payload 'git add -A')")
rc=$?
if [ "$rc" -eq 2 ]; then
  pass "block-git-add-all: 'git add -A' → exit 2 (blocked)"
elif [ "$rc" -eq 127 ]; then
  fail "block-git-add-all: 'git add -A' → exit 2 (blocked)" \
       "got 127 — the hook died on a missing binary and FAILED OPEN. Output:
$out"
else
  fail "block-git-add-all: 'git add -A' → exit 2 (blocked)" \
       "got exit $rc, expected 2. Output:
$out"
fi

# 2. block-git-add-all must ALLOW explicit staging. A guard that blocks every
#    `git add` is as useless as one that blocks none — it just gets disabled.
for allowed in 'git add file1.md' 'git add src/foo.ts src/bar.ts' 'git add -p' 'git add -u'; do
  out=$(run_hook "block-git-add-all.sh" "$(bash_payload "$allowed")")
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "block-git-add-all: '$allowed' → allowed"
  else
    fail "block-git-add-all: '$allowed' → allowed" "got exit $rc, expected 0. Output:
$out"
  fi
done

# 3. The escaped-quote case. This is the one a naive `sed` extraction gets wrong:
#    an escaped quote inside the command value can terminate the match early and
#    truncate the command — silently hiding a `git add -A` that appears after it.
out=$(run_hook "block-git-add-all.sh" "$(bash_payload 'echo \"hello\" && git add -A')")
rc=$?
if [ "$rc" -eq 2 ]; then
  pass "block-git-add-all: escaped quotes before 'git add -A' → still blocked"
else
  fail "block-git-add-all: escaped quotes before 'git add -A' → still blocked" \
       "got exit $rc, expected 2 — extraction probably truncated at the escaped quote. Output:
$out"
fi

# 3b. A HEREDOC BODY that merely mentions the pattern must NOT be blocked.
#     Found the hard way: the first real commit after reviving these hooks was
#     refused, because its commit message documented the `git add -A` probe used to
#     verify the hook. The guard inspects the raw command string, so writing about
#     the guard tripped the guard. Text after a `<<` marker is DATA — a commit
#     message, a file body — not a command, and blocking on it makes the hook
#     unusable for exactly the work that documents it.
payload=$(bash_payload 'cat > /tmp/msg.txt << \"EOF\"\nfix: verified the guard\n\n  git add -A   -> BLOCKED\nEOF\ngit commit -F /tmp/msg.txt')
out=$(run_hook "block-git-add-all.sh" "$payload")
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "block-git-add-all: pattern inside a heredoc body → allowed"
else
  fail "block-git-add-all: pattern inside a heredoc body → allowed" \
       "got exit $rc, expected 0 — the hook is matching data, not commands. Output:
$out"
fi

# 3c. But a real `git add -A` BEFORE a heredoc must still be blocked. The fix for
#     3b must not become a bypass: appending a heredoc to any command would
#     otherwise disable the guard entirely.
payload=$(bash_payload 'git add -A && cat > /tmp/m.txt << \"EOF\"\nnotes\nEOF')
out=$(run_hook "block-git-add-all.sh" "$payload")
rc=$?
if [ "$rc" -eq 2 ]; then
  pass "block-git-add-all: real 'git add -A' before a heredoc → still blocked"
else
  fail "block-git-add-all: real 'git add -A' before a heredoc → still blocked" \
       "got exit $rc, expected 2 — the heredoc fix became a bypass. Output:
$out"
fi

# 4. Unparseable payload carrying the dangerous pattern must FAIL CLOSED.
#    The #16 lesson: when a guard cannot establish the truth, refusing is correct
#    and waving the command through is the actual defect.
out=$(printf '%s' 'this is not json at all but mentions git add -A somewhere' | "$HOOKS_DIR/block-git-add-all.sh" 2>&1)
rc=$?
if [ "$rc" -eq 2 ]; then
  pass "block-git-add-all: unparseable payload + danger pattern → fails CLOSED"
else
  fail "block-git-add-all: unparseable payload + danger pattern → fails CLOSED" \
       "got exit $rc, expected 2. Output:
$out"
fi

# 5. Unparseable payload with nothing alarming must not block. Fail-closed must be
#    scoped to actual danger, or every malformed payload becomes a hard stop.
out=$(printf '%s' 'not json, nothing dangerous here' | "$HOOKS_DIR/block-git-add-all.sh" 2>&1)
rc=$?
if [ "$rc" -eq 0 ]; then
  pass "block-git-add-all: unparseable payload, no danger → allowed"
else
  fail "block-git-add-all: unparseable payload, no danger → allowed" \
       "got exit $rc, expected 0. Output:
$out"
fi

# ── block-force-push-to-main ──────────────────────────────────────────────────
# Needs a repo whose current branch is main, in an isolated fixture — never the
# real repo (verification.md catch 6).
TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT
MAINREPO="$TESTDIR/on-main"
mkdir -p "$MAINREPO" || exit 1
( cd "$MAINREPO" || exit 1
  git init -q -b main .
  git -c user.email=t@e -c user.name=t commit -q --allow-empty -m init ) >/dev/null 2>&1

# 6. Force-push explicitly targeting main → blocked.
out=$(run_hook "block-force-push-to-main.sh" "$(bash_payload 'git push --force origin main' "$MAINREPO")")
rc=$?
[ "$rc" -eq 2 ] && pass "block-force-push: '--force origin main' → exit 2" \
  || fail "block-force-push: '--force origin main' → exit 2" "got exit $rc. Output:
$out"

# 7. Force-push with no explicit target while ON main → blocked (current branch implied).
out=$(run_hook "block-force-push-to-main.sh" "$(bash_payload 'git push -f' "$MAINREPO")")
rc=$?
[ "$rc" -eq 2 ] && pass "block-force-push: '-f' while on main → exit 2" \
  || fail "block-force-push: '-f' while on main → exit 2" "got exit $rc. Output:
$out"

# 8. A NORMAL push must not be blocked.
out=$(run_hook "block-force-push-to-main.sh" "$(bash_payload 'git push' "$MAINREPO")")
rc=$?
[ "$rc" -eq 0 ] && pass "block-force-push: plain 'git push' → allowed" \
  || fail "block-force-push: plain 'git push' → allowed" "got exit $rc. Output:
$out"

# 9. Force-push to a NON-protected branch must not be blocked.
FEATREPO="$TESTDIR/on-feature"
mkdir -p "$FEATREPO" || exit 1
( cd "$FEATREPO" || exit 1
  git init -q -b feature/x .
  git -c user.email=t@e -c user.name=t commit -q --allow-empty -m init ) >/dev/null 2>&1
out=$(run_hook "block-force-push-to-main.sh" "$(bash_payload 'git push --force origin feature/x' "$FEATREPO")")
rc=$?
[ "$rc" -eq 0 ] && pass "block-force-push: force-push to feature branch → allowed" \
  || fail "block-force-push: force-push to feature branch → allowed" "got exit $rc. Output:
$out"

# ── warn-direct-commit-to-main: RETIRED 2026-08-17 ────────────────────────────
# Three tests removed with the hook. It exited 0 and wrote to stderr, which never
# surfaces in this runtime, so it warned no one for its entire life while its
# presence read as coverage. Blocking instead would have contradicted ADR-0001,
# where direct-to-main is the expected path for a solo repo — a guard firing on
# correct behaviour. See the amended ADR-0002 for the decision and its revisit
# trigger (a project gains collaborators -> build a BLOCKING version, not a warning).
#
# 13. Nothing may reintroduce a warn-only hook. A hook that exits 0 with a message
#     is indistinguishable from a hook that does nothing, so this asserts the
#     retired file stays gone rather than trusting anyone to remember why.
if [ -e "$HOOKS_DIR/warn-direct-commit-to-main.sh" ]; then
  fail "warn-direct-commit stays retired" \
       "the hook is back. A warn-only hook is mute here — make it block or leave it out."
else
  pass "warn-direct-commit stays retired"
fi

# ── auto-update-last-reviewed ─────────────────────────────────────────────────
# Rewrites a date in the GLOBAL CLAUDE.md. It keys on $HOME, so the test overrides
# HOME to a fixture — it must never touch the real ~/.claude/CLAUDE.md.

# 13. Editing the global CLAUDE.md refreshes the date.
FAKEHOME="$TESTDIR/home"
mkdir -p "$FAKEHOME/.claude" || exit 1
printf '# Global\n<!-- Last reviewed: 2020-01-01. -->\n' > "$FAKEHOME/.claude/CLAUDE.md"
payload=$(printf '{"hook_event_name":"PostToolUse","tool_input":{"file_path":"%s/.claude/CLAUDE.md"}}' "$FAKEHOME")
out=$(printf '%s' "$payload" | HOME="$FAKEHOME" "$HOOKS_DIR/auto-update-last-reviewed.sh" 2>&1)
rc=$?
today=$(date -I)
if [ "$rc" -eq 0 ] && grep -q "Last reviewed: $today" "$FAKEHOME/.claude/CLAUDE.md"; then
  pass "auto-update-last-reviewed: global CLAUDE.md edit → date refreshed"
else
  fail "auto-update-last-reviewed: global CLAUDE.md edit → date refreshed" \
       "got exit $rc; file now: $(cat "$FAKEHOME/.claude/CLAUDE.md")"
fi

# 14. Editing an unrelated file leaves it alone.
printf '# Global\n<!-- Last reviewed: 2020-01-01. -->\n' > "$FAKEHOME/.claude/CLAUDE.md"
payload=$(printf '{"hook_event_name":"PostToolUse","tool_input":{"file_path":"%s/somewhere/else.md"}}' "$FAKEHOME")
out=$(printf '%s' "$payload" | HOME="$FAKEHOME" "$HOOKS_DIR/auto-update-last-reviewed.sh" 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && grep -q 'Last reviewed: 2020-01-01' "$FAKEHOME/.claude/CLAUDE.md"; then
  pass "auto-update-last-reviewed: unrelated file → date untouched"
else
  fail "auto-update-last-reviewed: unrelated file → date untouched" \
       "got exit $rc; file now: $(cat "$FAKEHOME/.claude/CLAUDE.md")"
fi

# 15. No hook may INVOKE `jq`. This is the actual root cause, asserted directly
#     rather than inferred from behaviour — a future edit could reintroduce `jq`
#     and every test above would still pass on any machine that happens to have it.
#
#     Comment lines are stripped before matching: these hooks now carry comments
#     explaining the jq removal, and a bare `grep jq` flags that prose as a
#     violation. The first version of this check did exactly that and reported all
#     four hooks as still broken — an assertion measuring the wrong thing, which is
#     a false RED. Cheaper than a false green, but still a defect in the test.
jq_users=""
for hook in "$HOOKS_DIR"/*.sh; do
  case "$hook" in *hooks.test.sh) continue ;; esac   # this file names jq in prose
  if grep -vE '^[[:space:]]*#' "$hook" | grep -qE '(^|[|;&$(`[:space:]])jq([[:space:]]|$)'; then
    jq_users="$jq_users $(basename "$hook")"
  fi
done
if [ -n "$jq_users" ]; then
  fail "no hook invokes jq" "still invoking jq:$jq_users"
else
  pass "no hook invokes jq"
fi

echo ""
if [ "$FAILED" -eq 0 ]; then echo "ALL GREEN"; else echo "SOME RED"; fi
exit "$FAILED"
