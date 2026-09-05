#!/usr/bin/env bash
#
# check-memory-drift.sh — report where the STATE block of
# .claude/memory/current-state.md asserts something the issue board, the ADRs or
# this repo no longer agree with. Issue #22.
#
# WHY THIS EXISTS
#
# current-state.md is read cold at session start BECAUSE IT IS TRUSTED. It was
# hand-corrected seven times in eleven days, always reactively — after someone
# read it and noticed it was wrong. Twice the wrongness was the first thing in the
# file: it led with a NEXT pointing at a retired plan, and it named a five-issue
# chain as upcoming when four fifths had shipped.
#
# WHY IT IS THIS NARROW
#
# Referencing a CLOSED issue is not drift. Most of the file's `#N` mentions are
# history ("#16, closed, here is what it fixed"), and flagging those would produce
# a report that is wrong far more often than right — verification.md catch 3a, the
# guard that cries wolf and so protects nothing. So this flags only assertions
# about the FUTURE that the present contradicts, and only inside the STATE block:
#
#   NEXT / parked / pending / blocked on / awaiting ... #N, where N is CLOSED
#   ADR-NNNN with no matching file in docs/adr/
#   a backticked short SHA that is not a commit in this repo
#   Last updated: <date> older than the newest commit to this file
#
# Everything below the `## Log` heading is out of scope by construction: the Log is
# append-only history and its entries are ALLOWED to be superseded.
#
# EXIT CODES (see the spec's D2)
#   0  ran to completion — findings, if any, are printed
#   1  the checker could not do its job, and NO check ran (fail closed, catch 2a)
#
# Findings are deliberately NOT a failure: the doc being briefly out of date is not
# a reason to fail a build, and a gate people bypass is worse than a report they
# read. Only the checker's own malfunction is fatal.
#
# Usage:
#   check-memory-drift.sh [--verbose]
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

FILE=".claude/memory/current-state.md"
VERBOSE=0
[ "${1:-}" = "--verbose" ] && VERBOSE=1

err() { echo "check-memory-drift: ERROR — $1" >&2; echo "check-memory-drift: NO drift check ran. This is not a clean bill of health." >&2; exit 1; }

command -v git >/dev/null 2>&1 || err "git is not on PATH."
# gh is required unconditionally rather than on demand. A checker that quietly
# skips its issue-state half when the tool is missing reports "clean" while having
# checked a fraction of what it claims — the exact fail-open shape of catch 2a.
command -v gh >/dev/null 2>&1 || err "gh is not on PATH — issue state cannot be read."

[ -f "$FILE" ] || err "$FILE does not exist."
grep -q '^## Current State' "$FILE" || err "$FILE has no '## Current State' heading — the STATE block cannot be located."
grep -q '^## Log' "$FILE" || err "$FILE has no '## Log' heading — the STATE/LOG boundary cannot be located."

# The freshness marker is parsed HERE, with the other structural validations,
# rather than at the point of use: if it is unreadable the checker is broken and
# must say so before it has printed any findings, not halfway through.
UPD_RAW="$(awk '/^## Log/{exit} /^Last updated:/{print NR"\t"$0; exit}' "$FILE")"
[ -n "$UPD_RAW" ] || err "$FILE has no 'Last updated:' line above the '## Log' heading — the freshness check cannot run."
UPD_LINE="${UPD_RAW%%$'\t'*}"
UPD_TEXT="${UPD_RAW#*$'\t'}"
UPD_DATE="$(printf '%s' "$UPD_TEXT" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
[ -n "$UPD_DATE" ] || err "the 'Last updated' line carries no YYYY-MM-DD date: $UPD_TEXT"

# `git log -- <file>` is the authority on when the file last changed, not the
# filesystem mtime: an mtime moves on every editor save and on checkout, so it
# would make the marker look fresh whenever anyone merely opened the file.
FILE_COMMIT_DATE="$(git log -1 --format=%ad --date=short -- "$FILE" 2>/dev/null)"
[ -n "$FILE_COMMIT_DATE" ] || err "git reports no commit touching $FILE — the freshness check cannot run."

WORK="$(mktemp -d)" || err "could not create a work directory."
trap 'rm -rf "$WORK"' EXIT

# The policed region: `## Current State` up to (not including) `## Log`. Lines are
# emitted as "<lineno>\t<text>" so findings can cite a line.
awk '/^## Log/{exit} /^## Current State/{f=1} f{print NR"\t"$0}' "$FILE" > "$WORK/region"

FINDINGS="$WORK/findings"
: > "$FINDINGS"
note() { printf '  line %s: %s\n      %s\n' "$1" "$2" "$3" >> "$FINDINGS"; }

# gh_state prints OPEN, CLOSED, or ERR:<message>. It must not call err() itself —
# it runs in a command substitution, where an exit would be swallowed by the
# subshell and the caller would carry on with an empty state.
gh_state() {  # gh_state <issue-number>
  local n="$1" out
  if ! out="$(gh issue view "$n" --json state --jq .state 2>&1)"; then
    printf 'ERR:%s' "$(printf '%s' "$out" | tr '\n' ' ')"
    return 0
  fi
  out="$(printf '%s' "$out" | tr -d '\r\n[:space:]')"
  case "$out" in
    OPEN|CLOSED) printf '%s' "$out" ;;
    *) printf 'ERR:unexpected state %s' "${out:-<empty>}" ;;
  esac
}

CHECKED=0
# Assertions found IN THE REGION (issues, ADRs, SHAs). Kept apart from CHECKED
# because the freshness marker is a file-level constant: counting it would mean
# the "did the enumeration cover anything?" guard below could never fire.
REGION_CHECKED=0

# --- Future-tense assertions pointing at a closed issue ---------------------
#
# The keyword and the `#N` must share a LINE, not a bullet. A bullet is several
# sentences here, and matching across one would let the word "parked" in a
# paragraph's opening claim every issue number mentioned later in it.
while IFS=$'\t' read -r lineno text; do
  case "$text" in
    *NEXT*|*[Pp]arked*|*PARKED*|*[Pp]ending*|*PENDING*|*"blocked on"*|*"Blocked on"*|*"BLOCKED ON"*|*[Aa]waiting*|*AWAITING*) ;;
    *) continue ;;
  esac
  for ref in $(printf '%s' "$text" | grep -oE '#[0-9]+' | sort -u); do
    n="${ref#\#}"
    CHECKED=$((CHECKED + 1))
    REGION_CHECKED=$((REGION_CHECKED + 1))
    st="$(gh_state "$n")"
    case "$st" in
      ERR:*) err "gh could not read issue #$n: ${st#ERR:}" ;;
      CLOSED) note "$lineno" "a future-tense claim points at issue #$n, which is CLOSED" "$text" ;;
    esac
  done
done < "$WORK/region"

# --- ADRs cited with nothing behind them ------------------------------------
#
# Matched anywhere in the STATE block, not only on future-tense lines: an ADR
# reference is an instruction to go read a decision, and it is equally broken in a
# past-tense sentence. Unlike an issue number, "the file is absent" has no
# legitimate reading.
while IFS=$'\t' read -r lineno text; do
  for adr in $(printf '%s' "$text" | grep -oE 'ADR-[0-9]{4}' | sort -u); do
    num="${adr#ADR-}"
    CHECKED=$((CHECKED + 1))
    REGION_CHECKED=$((REGION_CHECKED + 1))
    # A glob that matches nothing expands to itself, so test the expansion.
    found=0
    for f in docs/adr/"$num"-*.md; do
      [ -f "$f" ] && found=1
    done
    [ "$found" -eq 0 ] && note "$lineno" "$adr is cited but docs/adr/$num-*.md does not exist" "$text"
  done
done < "$WORK/region"

# --- Commit SHAs that are not commits ---------------------------------------
#
# Scoped per `### ` subsection. A subsection that DECLARES another repository —
# "Probe repo: `~/projects/semver-probe`" — owns the commits cited inside it, and
# this repo's object store is not the authority for them. Without that scoping the
# live STATE block yields three findings that are wrong on every run forever (two
# probe commits and one npm/node-semver commit), which is precisely how a checker
# becomes noise and stops being read.
#
# The scope is derived from the file rather than configured here, so it cannot
# drift from what the file actually says.
awk -F'\t' 'BEGIN { s = 0; t = 0 }
  FNR == NR {
    if ($2 ~ /^### /) s++
    if ($2 ~ /[Rr]epo:[ \t]*`[^`]+`/) ext[s] = 1
    next
  }
  {
    if ($2 ~ /^### /) t++
    print ((t in ext) ? "EXT" : "LOC") "\t" $0
  }' "$WORK/region" "$WORK/region" > "$WORK/region-scoped"

SUPPRESSED=0
while IFS=$'\t' read -r scope lineno text; do
  for tok in $(printf '%s' "$text" | grep -oE '`[0-9a-f]{7,40}`' | tr -d '`' | sort -u); do
    # At least one a-f, or "1975026" in prose reads as a commit. Narrowing by
    # design: an all-decimal short SHA goes unchecked rather than every seven-digit
    # number being reported.
    case "$tok" in *[a-f]*) ;; *) continue ;; esac
    if [ "$scope" = "EXT" ]; then
      SUPPRESSED=$((SUPPRESSED + 1))
      continue
    fi
    CHECKED=$((CHECKED + 1))
    REGION_CHECKED=$((REGION_CHECKED + 1))
    git cat-file -e "${tok}^{commit}" 2>/dev/null && continue
    note "$lineno" "\`$tok\` is not a commit in this repo" "$text"
  done
done < "$WORK/region-scoped"

# --- The freshness marker itself --------------------------------------------
CHECKED=$((CHECKED + 1))
if [[ "$UPD_DATE" < "$FILE_COMMIT_DATE" ]]; then
  note "$UPD_LINE" "Last updated: $UPD_DATE is older than the newest commit to this file ($FILE_COMMIT_DATE)" "$UPD_TEXT"
fi

if [ $((REGION_CHECKED + SUPPRESSED)) -eq 0 ]; then
  err "the STATE block yielded no checkable assertion — no issue reference, no ADR, no commit. Either the region extraction broke or the block is empty; a checker that scans nothing must never report clean."
fi

suppression_note() {
  [ "$SUPPRESSED" -gt 0 ] && echo "  $SUPPRESSED SHA(s) NOT checked: they sit in a subsection that declares another repo."
  return 0
}

if [ ! -s "$FINDINGS" ]; then
  # Silent on a clean run, by design: zero findings must mean zero output, or this
  # becomes the retired session ritual that fired whether or not it had anything to
  # say. `--verbose` is how you confirm it actually looked at something.
  if [ "$VERBOSE" -eq 1 ]; then
    echo "check-memory-drift: OK — $CHECKED assertion(s) checked in $FILE, no drift."
    suppression_note
  fi
  exit 0
fi

echo "check-memory-drift: DRIFT in $FILE"
echo ""
cat "$FINDINGS"
echo ""
echo "  $(grep -c '^  line ' "$FINDINGS") finding(s) from $CHECKED checked assertion(s)."
suppression_note
echo "  Nothing was changed. Edit the STATE block; do not edit the Log."
exit 0
