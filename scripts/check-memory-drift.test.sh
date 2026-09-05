#!/usr/bin/env bash
#
# Tests for check-memory-drift.sh (#22).
#
# Contract: the checker reports ONLY assertions in the STATE block that the issue
# board / the ADRs / this repo contradict, and it reports NOTHING otherwise. Both
# halves are load-bearing. A checker that cries wolf trains you to ignore it, which
# turns it into a guard protecting nothing (verification.md catch 3a) — so roughly
# half the cases below are false-positive proofs rather than detections.
#
# Every case builds a throwaway git repo under mktemp -d and never touches this
# repo's own .git, index, or live memory files (catch 6). Directory changes are
# guarded explicitly rather than relying on set -e.
#
# `gh` is stubbed by putting a fake on PATH, so the checker is exercised through its
# real invocation path (it shells out to `gh` exactly as in production) without
# needing network or auth. The stub's own behaviour is driven by GH_STUB_CLOSED.
set -uo pipefail

CHECKER="$(cd "$(dirname "$0")" && pwd)/check-memory-drift.sh"
REAL_REPO="$(cd "$(dirname "$0")/.." && pwd)"
TODAY="$(date +%F)"
FAILED=0

pass() { echo "  ✔ $1"; }
fail() { echo "  ✖ $1"; echo "      $2"; FAILED=1; }

echo "▶ check-memory-drift"

TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

STUBBIN="$TESTDIR/stubbin"
mkdir -p "$STUBBIN" || exit 1
cat > "$STUBBIN/gh" <<'STUB'
#!/usr/bin/env bash
# Fake `gh` for tests. Answers only: gh issue view <N> --json state --jq .state
# Issue numbers listed in $GH_STUB_CLOSED are CLOSED; every other issue is OPEN.
# GH_STUB_FAIL=1 makes it fail the way an unauthenticated / offline gh does.
set -u
if [ "${GH_STUB_FAIL:-}" = "1" ]; then
  echo "fake gh: HTTP 401: Bad credentials" >&2
  exit 1
fi
if [ "${1:-}" != "issue" ] || [ "${2:-}" != "view" ]; then
  echo "fake gh: unsupported invocation: $*" >&2
  exit 1
fi
for c in ${GH_STUB_CLOSED:-}; do
  if [ "$c" = "${3:-}" ]; then echo CLOSED; exit 0; fi
done
echo OPEN
STUB
chmod +x "$STUBBIN/gh"
# Both stub knobs are EXPORTED: the stub is a separate process, so a plain shell
# variable would never reach it. GH_STUB_FAIL silently stayed empty when it was not
# exported, and case 15 passed the failing-gh case a healthy gh — green through a
# path the test was not exercising at all.
export GH_STUB_CLOSED=""
export GH_STUB_FAIL=""

# A throwaway repo carrying the checker, one ADR, and a committed memory file.
make_repo() {  # make_repo <root> ; echoes repo path
  local repo="$1/r"
  mkdir -p "$repo/scripts" "$repo/.claude/memory" "$repo/docs/adr" || return 1
  cp "$CHECKER" "$repo/scripts/check-memory-drift.sh" || return 1
  chmod +x "$repo/scripts/check-memory-drift.sh"
  printf '# ADR-0002\n' > "$repo/docs/adr/0002-a-real-decision.md"
  ( cd "$repo" || exit 1
    git init -q .
    git config user.email t@e; git config user.name t
    git add -A >/dev/null 2>&1
    git commit -q -m baseline ) || return 1
  echo "$repo"
}

# Write the memory file from a STATE body and commit it, so `git log -- <file>`
# has something to report (the freshness check reads it).
write_state() {  # write_state <repo> <state-body> [last-updated-date]
  local repo="$1" body="$2" updated="${3:-$TODAY}"
  {
    printf '# Current State — fixture\n\n'
    printf 'Last updated: %s\n\n' "$updated"
    printf -- '---\n\n## Current State\n\n'
    printf '%s\n' "$body"
    printf -- '\n---\n\n## Log — historical, append-only\n\n'
    printf '### 2026-01-01 — history\n\n'
    printf 'NEXT: #901 — a dead pointer that lives in the LOG and must be ignored.\n'
    printf 'It cites ADR-9901 and `deadbee` too. None of it is current state.\n'
  } > "$repo/.claude/memory/current-state.md"
  ( cd "$repo" || exit 1
    git add -A >/dev/null 2>&1
    git commit -q -m "state" --allow-empty ) || return 1
}

run_checker() {  # run_checker <repo> [args...] ; echoes output, sets rc via $?
  local repo="$1"; shift
  ( cd "$repo" || exit 1; PATH="$STUBBIN:$PATH" ./scripts/check-memory-drift.sh "$@" ) 2>&1
}

# ---------------------------------------------------------------------------
# 1. A NEXT line pointing at a CLOSED issue is the headline case: the orientation
#    doc's primary instruction is dead work.
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t1")
if [ -z "$REPO" ]; then
  fail "NEXT at a closed issue -> reported" "fixture build failed"
else
  write_state "$REPO" '### NEXT — #18, the acceptance harness

Some detail. Also cites ADR-0002, which exists.'
  GH_STUB_CLOSED="18" out=$(run_checker "$REPO"); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '#18' && printf '%s' "$out" | grep -qi 'closed'; then
    pass "NEXT at a closed issue -> reported"
  else
    fail "NEXT at a closed issue -> reported" "rc=$rc, output:
$out"
  fi
fi

# ---------------------------------------------------------------------------
# 2. The same line pointing at an OPEN issue is NOT drift. Without this the
#    detection above is satisfied by a checker that flags every NEXT line.
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t2")
if [ -z "$REPO" ]; then
  fail "NEXT at an open issue -> silent" "fixture build failed"
else
  write_state "$REPO" '### NEXT — #18, the acceptance harness

Some detail. Also cites ADR-0002, which exists.'
  GH_STUB_CLOSED="" out=$(run_checker "$REPO"); rc=$?
  if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
    pass "NEXT at an open issue -> silent"
  else
    fail "NEXT at an open issue -> silent" "rc=$rc, expected NO output, got:
$out"
  fi
fi

# ---------------------------------------------------------------------------
# 3. A stated blocker that no longer exists. Same shape as 1 but through the
#    parked / blocked on / awaiting vocabulary rather than NEXT.
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t3")
if [ -z "$REPO" ]; then
  fail "blocked-on a closed issue -> reported" "fixture build failed"
else
  write_state "$REPO" '### Parked, with triggers

- **#40 the widget** — blocked on #41, which must land first.
- **#42 the gadget** — awaiting #43.
- Cites ADR-0002, which exists.'
  GH_STUB_CLOSED="41 43" out=$(run_checker "$REPO"); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '#41' && printf '%s' "$out" | grep -q '#43'; then
    pass "blocked-on a closed issue -> reported"
  else
    fail "blocked-on a closed issue -> reported" "rc=$rc, output:
$out"
  fi
fi

# ---------------------------------------------------------------------------
# 4. The Log is out of scope. Every fixture's Log carries a dead NEXT (#901), a
#    nonexistent ADR and an unresolvable SHA; none of it may ever be reported.
#    This is the structural half of #22: Log entries are ALLOWED to be superseded,
#    and a checker that policed them would flag the entire history of the repo.
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t4")
if [ -z "$REPO" ]; then
  fail "Log content is never reported" "fixture build failed"
else
  write_state "$REPO" '### NEXT — #18, the acceptance harness

Cites ADR-0002, which exists.'
  GH_STUB_CLOSED="901" out=$(run_checker "$REPO"); rc=$?
  if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
    pass "Log content is never reported"
  else
    fail "Log content is never reported" "rc=$rc, expected NO output, got:
$out"
  fi
fi

# ---------------------------------------------------------------------------
# 5. An ADR cited in the STATE block with no file behind it: a decision the doc
#    tells you to go read, that cannot be read.
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t5")
if [ -z "$REPO" ]; then
  fail "missing ADR -> reported, present ADR -> silent" "fixture build failed"
else
  write_state "$REPO" '### NEXT — #18, the acceptance harness

Settled by ADR-0002. Superseded by ADR-0099, which was never written.'
  GH_STUB_CLOSED="" out=$(run_checker "$REPO"); rc=$?
  # Match the FINDING sentence, not the bare id: every finding echoes its source
  # line, which legitimately contains ADR-0002. Asserting on the bare id here
  # produced a false RED against correct output — catch 3a in miniature.
  if [ "$rc" -eq 0 ] \
     && printf '%s' "$out" | grep -q 'ADR-0099 is cited but' \
     && ! printf '%s' "$out" | grep -q 'ADR-0002 is cited but'; then
    pass "missing ADR -> reported, present ADR -> silent"
  else
    fail "missing ADR -> reported, present ADR -> silent" "rc=$rc, output:
$out"
  fi
fi

# ---------------------------------------------------------------------------
# 6. A backticked SHA that is not a commit here is a claim of evidence that
#    cannot be checked. A real one must stay silent, or the rule is just "flag
#    every SHA".
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t6")
if [ -z "$REPO" ]; then
  fail "unresolvable SHA -> reported, real SHA -> silent" "fixture build failed"
else
  REAL_SHA=$( cd "$REPO" && git rev-parse --short=7 HEAD )
  write_state "$REPO" "### NEXT — #18, the acceptance harness

Landed as \`$REAL_SHA\`. The boundary was \`deadbee\`, which is not a commit.
Cites ADR-0002."
  GH_STUB_CLOSED="" out=$(run_checker "$REPO"); rc=$?
  if [ "$rc" -eq 0 ] \
     && printf '%s' "$out" | grep -q "deadbee\` is not a commit" \
     && ! printf '%s' "$out" | grep -q "$REAL_SHA\` is not a commit"; then
    pass "unresolvable SHA -> reported, real SHA -> silent"
  else
    fail "unresolvable SHA -> reported, real SHA -> silent" "rc=$rc, real=$REAL_SHA, output:
$out"
  fi
fi

# ---------------------------------------------------------------------------
# 7. SHAs belonging to ANOTHER repo are out of scope, and the way the file says
#    so is a `... repo: \`<path>\`` declaration inside the subsection.
#
#    This is the one place the narrowness rule has real teeth. The live STATE
#    block cites three commits that are not in this repo at all — two in the
#    semver probe, one in npm/node-semver upstream — under a subsection that
#    opens by naming the probe repo. Checking those against this repo's object
#    store reports three findings that are all wrong, every run, forever. The
#    scope of a SHA claim is per-subsection because that is where the file
#    already declares it.
#
#    The suppression must be BOUNDED: an unresolvable SHA in a subsection that
#    declares nothing is still reported.
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t7")
if [ -z "$REPO" ]; then
  fail "declared-external subsection scopes SHA checks" "fixture build failed"
else
  write_state "$REPO" '### NEXT — #18, the acceptance harness

- Probe repo: `~/projects/semver-probe`, bootstrapped and wired.
- Pre-build boundary: `f294741` — cases from `npm/node-semver`
  @ `6e05b7637396ac66522cff8731f07cfe0ef49a29`.

### Instruments

- Cites ADR-0002 and `cafe123`, which is not a commit anywhere.'
  GH_STUB_CLOSED="" out=$(run_checker "$REPO"); rc=$?
  if [ "$rc" -eq 0 ] \
     && printf '%s' "$out" | grep -q "cafe123\` is not a commit" \
     && ! printf '%s' "$out" | grep -q "f294741\` is not a commit" \
     && ! printf '%s' "$out" | grep -q "6e05b7637396ac66522cff8731f07cfe0ef49a29\` is not a commit"; then
    pass "declared-external subsection scopes SHA checks"
  else
    fail "declared-external subsection scopes SHA checks" "rc=$rc, output:
$out"
  fi
fi

# ---------------------------------------------------------------------------
# 8. The freshness marker itself going stale. Every other check reads the file's
#    claims; this one reads the file's claim ABOUT ITSELF, and it is the cheapest
#    signal that someone edited the state without re-dating it.
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t8")
if [ -z "$REPO" ]; then
  fail "stale Last-updated -> reported" "fixture build failed"
else
  write_state "$REPO" '### NEXT — #18, the acceptance harness

Cites ADR-0002.' "2020-01-01"
  GH_STUB_CLOSED="" out=$(run_checker "$REPO"); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '2020-01-01'; then
    pass "stale Last-updated -> reported"
  else
    fail "stale Last-updated -> reported" "rc=$rc, output:
$out"
  fi
fi

# ---------------------------------------------------------------------------
# 9. No freshness marker at all -> the check CANNOT run, so the checker must exit
#    non-zero and say so. Reporting "clean" here would be the fail-open shape of
#    catch 2a: a check that never reached its own logic returning the success value.
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t9")
if [ -z "$REPO" ]; then
  fail "no Last-updated marker -> hard error" "fixture build failed"
else
  write_state "$REPO" '### NEXT — #18

Cites ADR-0002.'
  ( cd "$REPO" || exit 1
    grep -v '^Last updated:' .claude/memory/current-state.md > tmp.md
    mv tmp.md .claude/memory/current-state.md
    git add -A >/dev/null 2>&1; git commit -q -m "drop marker" )
  GH_STUB_CLOSED="" out=$(run_checker "$REPO"); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'last updated'; then
    pass "no Last-updated marker -> hard error"
  else
    fail "no Last-updated marker -> hard error" "rc=$rc, output:
$out"
  fi
fi

# ---------------------------------------------------------------------------
# 10. Zero findings -> zero output, so this can never become the nagging session
#     ritual that was retired for firing whether or not it had anything to say.
#     `--verbose` on the SAME fixture must show it actually checked things:
#     silence alone is indistinguishable from a checker that did nothing.
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t10")
if [ -z "$REPO" ]; then
  fail "clean -> zero output, --verbose proves it looked" "fixture build failed"
else
  REAL_SHA=$( cd "$REPO" && git rev-parse --short=7 HEAD )
  write_state "$REPO" "### NEXT — #18, the acceptance harness

Settled by ADR-0002, landed as \`$REAL_SHA\`. Parked: #19 stays open."
  GH_STUB_CLOSED="" quiet=$(run_checker "$REPO"); rc_q=$?
  GH_STUB_CLOSED="" loud=$(run_checker "$REPO" --verbose); rc_l=$?
  if [ "$rc_q" -eq 0 ] && [ -z "$quiet" ] \
     && [ "$rc_l" -eq 0 ] && printf '%s' "$loud" | grep -qE 'OK — [1-9][0-9]* assertion'; then
    pass "clean -> zero output, --verbose proves it looked"
  else
    fail "clean -> zero output, --verbose proves it looked" "rc_q=$rc_q quiet='$quiet'
rc_l=$rc_l loud='$loud'"
  fi
fi

# ---------------------------------------------------------------------------
# 11. A STATE block with nothing checkable in it -> hard error. The enumeration
#     that decides what gets checked is derived from the region, so a region that
#     yields nothing means the derivation broke, not that the doc is healthy
#     (catch 8: discovering nothing must be a hard failure).
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t11")
if [ -z "$REPO" ]; then
  fail "nothing checkable in STATE -> hard error" "fixture build failed"
else
  write_state "$REPO" 'Prose with no issue numbers, no ADRs and no commits in it.'
  GH_STUB_CLOSED="" out=$(run_checker "$REPO"); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi 'no checkable assertion'; then
    pass "nothing checkable in STATE -> hard error"
  else
    fail "nothing checkable in STATE -> hard error" "rc=$rc, output:
$out"
  fi
fi

# ---------------------------------------------------------------------------
# 12. Missing memory file -> hard error. The whole point of the checker is that
#     "I found no drift" and "I could not look" must never look the same.
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t12")
if [ -z "$REPO" ]; then
  fail "missing memory file -> hard error" "fixture build failed"
else
  GH_STUB_CLOSED="" out=$(run_checker "$REPO"); rc=$?
  # Matches the SPECIFIC diagnosis, not the "NO drift check ran" banner every
  # error path prints — asserting on the banner would stay green no matter which
  # guard actually fired.
  if [ "$rc" -ne 0 ] \
     && printf '%s' "$out" | grep -q 'does not exist' \
     && printf '%s' "$out" | grep -q 'NO drift check ran'; then
    pass "missing memory file -> hard error"
  else
    fail "missing memory file -> hard error" "rc=$rc, output:
$out"
  fi
fi

# ---------------------------------------------------------------------------
# 13. No `## Log` heading -> hard error. Without the STATE/LOG boundary the
#     checker cannot tell current assertions from superseded history, and
#     guessing would police the entire file.
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t13")
if [ -z "$REPO" ]; then
  fail "no STATE/LOG boundary -> hard error" "fixture build failed"
else
  write_state "$REPO" '### NEXT — #18

Cites ADR-0002.'
  ( cd "$REPO" || exit 1
    grep -v '^## Log' .claude/memory/current-state.md > tmp.md
    mv tmp.md .claude/memory/current-state.md
    git add -A >/dev/null 2>&1; git commit -q -m "drop boundary" )
  GH_STUB_CLOSED="" out=$(run_checker "$REPO"); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "'## Log'"; then
    pass "no STATE/LOG boundary -> hard error"
  else
    fail "no STATE/LOG boundary -> hard error" "rc=$rc, output:
$out"
  fi
fi

# ---------------------------------------------------------------------------
# 14. The degraded environment, which is where this class of bug actually lives:
#     `gh` absent from PATH entirely. Four hooks in this repo's history exited 127
#     on a missing binary and were treated as non-blocking, so they failed OPEN for
#     months. A checker that skips its issue half when gh is gone reports "clean"
#     having checked a fraction of what it claims.
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t14")
if [ -z "$REPO" ]; then
  fail "gh absent -> hard error" "fixture build failed"
else
  write_state "$REPO" '### NEXT — #18

Cites ADR-0002.'
  # Point GH_BIN at a name that cannot exist rather than carving gh out of PATH.
  # The earlier version removed every PATH entry containing gh, which on a Linux
  # runner also removes bash and coreutils — the case could not be built, and the
  # test failed loudly rather than claiming a pass it had not exercised. GH_BIN
  # defaults to `gh`, so this still drives the production lookup.
  ABSENT_GH="gh-absent-fixture-$$"
  if command -v "$ABSENT_GH" >/dev/null 2>&1; then
    fail "gh absent -> hard error" "the stand-in name $ABSENT_GH unexpectedly exists; the case was not exercised"
  else
    out=$( ( cd "$REPO" || exit 1; GH_BIN="$ABSENT_GH" ./scripts/check-memory-drift.sh ) 2>&1 ); rc=$?
    if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'is not on PATH'; then
      pass "gh absent -> hard error"
    else
      fail "gh absent -> hard error" "rc=$rc, output:
$out"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 15. `gh` present but failing (unauthenticated / offline) -> hard error, not a
#     silently skipped issue check.
# ---------------------------------------------------------------------------
REPO=$(make_repo "$TESTDIR/t15")
if [ -z "$REPO" ]; then
  fail "gh failing -> hard error" "fixture build failed"
else
  write_state "$REPO" '### NEXT — #18

Cites ADR-0002.'
  GH_STUB_FAIL=1 out=$(run_checker "$REPO"); rc=$?
  GH_STUB_FAIL=""   # must not leak into case 16, which needs a healthy stub
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'could not read issue #18'; then
    pass "gh failing -> hard error"
  else
    fail "gh failing -> hard error" "rc=$rc, output:
$out"
  fi
fi

# ---------------------------------------------------------------------------
# 16. THE ONE THAT MATTERS (spec D1 / AC4): the real, current
#     .claude/memory/current-state.md must produce ZERO findings. If a future edit
#     to the checker makes it noisy, this goes red before anyone has learned to
#     ignore the output. It is also the only case whose fixture is the production
#     path shape — a UNC-rooted repo — rather than a mktemp one (catch 5a).
#
#     Issue state is answered by the stub (everything OPEN) rather than the real
#     `gh`: this suite runs in CI, where gh exists but is unauthenticated, and a
#     test that needs network auth would be red for reasons that are not about the
#     code. The stub still proves the thing this case exists to prove — that the
#     checker does not flag correct content — because a false positive on an OPEN
#     issue would show up here. It does NOT prove the live board agrees with the
#     doc; that is what running the checker by hand does.
#
#     Read-only against the real repo: the checker only ever runs `git log`,
#     `git cat-file` and `gh`, and never writes (catch 6).
#
#     ONE CARVE-OUT, and it is a real weakening rather than a technicality: a
#     finding about `Last updated:` is tolerated here. The live file's marker says
#     2026-08-23 while the newest commit touching it is 2026-09-05 — that is
#     genuine drift, correctly reported, and the fix is to re-date the file, which
#     this suite must not do for itself. Everything else must be silent, so a
#     future edit that makes the checker noisy about the PROSE still turns this
#     red. When the marker is re-dated the assertion holds unchanged (an empty set
#     satisfies it), so this does not need revisiting afterwards.
# ---------------------------------------------------------------------------
GH_STUB_CLOSED="" out=$( PATH="$STUBBIN:$PATH" bash "$REAL_REPO/scripts/check-memory-drift.sh" 2>&1 )
rc=$?
printf '%s\n' "$out" > "$TESTDIR/real.out"
offenders=$(grep '^  line ' "$TESTDIR/real.out" | grep -v 'Last updated:')
if [ "$rc" -eq 0 ] && [ -z "$offenders" ]; then
  pass "the real current-state.md produces no false positives"
else
  fail "the real current-state.md produces no false positives" "rc=$rc, unexpected finding(s):
$offenders
full output:
$out"
fi

echo ""
if [ "$FAILED" -eq 0 ]; then echo "ALL GREEN"; else echo "SOME RED"; fi
exit "$FAILED"
