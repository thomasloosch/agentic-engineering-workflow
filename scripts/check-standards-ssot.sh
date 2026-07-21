#!/usr/bin/env bash
#
# check-standards-ssot.sh — enforce the engineering-standards single-source-of-truth.
#
# After issue #6, the rule text lives in exactly ONE place: the doc
# (docs/standards/engineering-standards.md), which bootstrap propagates into
# every project. The SKILL is a thin reference that POINTS at the doc and must
# never re-inline the rules — a re-inlined copy is drift-able duplication, the
# exact thing this guard exists to prevent.
#
# This replaces the old "rule-title parity" check in weekly-health.yml: with one
# copy of the rules there is nothing left to keep in parity — the invariant is
# now "doc is complete, SKILL stays thin."
#
# Usage: check-standards-ssot.sh [SKILL_PATH] [DOC_PATH]
#   Args default to the workflow-repo locations, resolved relative to this
#   script, so CI can call it with no arguments. Tests pass fixture paths.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="${1:-$REPO_ROOT/.claude/skills/engineering-standards/SKILL.md}"
DOC="${2:-$REPO_ROOT/docs/standards/engineering-standards.md}"

EXPECTED_RULES=12
POINTER='docs/standards/engineering-standards.md'   # canonical path the thin SKILL must cite

fail() { echo "ERROR: $1"; exit 1; }

echo "=== engineering-standards SSOT check ==="
echo "  SKILL: $SKILL"
echo "  doc:   $DOC"

[ -f "$SKILL" ] || fail "SKILL not found: $SKILL"
[ -f "$DOC" ]   || fail "doc not found: $DOC"

# 1. The doc must define exactly the 12 rules (### N. Title). A rule dropped,
#    added, or renumbered here is a real change to the standard set.
rule_count=$(grep -cE '^### [0-9]+\. ' "$DOC")
[ "$rule_count" -eq "$EXPECTED_RULES" ] \
  || fail "doc defines $rule_count rules (### N.), expected $EXPECTED_RULES"

# 2. The SKILL must cite the canonical doc — that pointer IS its runtime load path.
grep -qF "$POINTER" "$SKILL" \
  || fail "SKILL does not point at the canonical doc ($POINTER)"

# 3. The SKILL must NOT re-inline numbered rule text ("N. **Title** — …").
#    Plain numbered lists ("1. Read the doc") are fine; only bolded rule
#    headings signal a re-introduced duplicate copy.
inlined=$(grep -cE '^[0-9]+\. \*\*' "$SKILL")
[ "$inlined" -eq 0 ] \
  || fail "SKILL re-inlines $inlined numbered rule line(s) — rule text belongs only in the doc"

echo "OK: doc holds all $EXPECTED_RULES rules; SKILL is a thin reference with no duplicated rule text"
