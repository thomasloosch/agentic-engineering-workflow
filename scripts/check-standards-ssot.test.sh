#!/usr/bin/env bash
#
# Tests for check-standards-ssot.sh. Each test builds a fixture pair (a doc + a
# SKILL) with known content and asserts the guard's EXIT CODE — not merely that
# it ran. Fixtures are self-contained temp files, so these tests never depend on
# the repo's real standards files.
#
# Contract under test: after the SSOT dedup (issue #6), the engineering-standards
# rule text lives in exactly ONE place — the doc. The guard must:
#   (a) PASS when the doc defines all 12 rules and the SKILL is a thin reference
#       that points at the doc and does NOT re-inline the numbered rules; and
#   (b) FAIL on any regression toward duplication — a rule dropped/added in the
#       doc, the SKILL re-inlining rule text, or the SKILL losing its pointer.
set -uo pipefail

GUARD="$(dirname "$0")/check-standards-ssot.sh"
FAILED=0

pass() { echo "  ✔ $1"; }
fail() { echo "  ✖ $1"; echo "      $2"; FAILED=1; }

# Emit a doc with N rules (### 1. … ### N.) plus the surrounding scaffold.
write_doc() {  # write_doc <path> <n_rules>
  local path="$1" n="$2" i
  : > "$path"
  printf '# Engineering Standards — v1\n\n' >> "$path"
  for ((i = 1; i <= n; i++)); do
    printf '### %d. Rule number %d\nWhy paragraph for rule %d.\n\n' "$i" "$i" "$i" >> "$path"
  done
}

# Thin SKILL: frontmatter + pointer at the doc + a plain numbered how-to list
# (plain "1. Read" items must NOT trip the re-inline check — only bolded
# "1. **Title**" rule lines should).
write_thin_skill() {  # write_thin_skill <path>
  local path="$1"
  cat > "$path" <<'EOF'
---
name: engineering-standards
description: thin reference
---
# Engineering Standards Skill

The 12 rules are canonical in the engineering-standards doc. Read it before
applying: `docs/standards/engineering-standards.md` in this workflow repo, or
`.claude/engineering-standards.md` in a bootstrapped project.

## How to invoke
1. Read the canonical doc named above.
2. Check the project's CLAUDE.md for overrides.
3. Apply the rules to the task at hand.
EOF
}

# Fat SKILL: re-inlines the numbered rules in the old "N. **Title** — …" form.
write_fat_skill() {  # write_fat_skill <path>
  local path="$1"
  cat > "$path" <<'EOF'
---
name: engineering-standards
description: fat copy
---
# Engineering Standards Skill

Points at `docs/standards/engineering-standards.md` but ALSO re-inlines:

1. **Lint clean before commit** — npm run lint must pass.
2. **Verify before declaring done** — ran it, output was X.
EOF
}

run_guard() {  # run_guard <skill> <doc> ; echoes exit code
  bash "$GUARD" "$1" "$2" >/dev/null 2>&1
  echo $?
}

echo "▶ check-standards-ssot"

TESTDIR=$(mktemp -d)
DOC="$TESTDIR/doc.md"
SKILL="$TESTDIR/skill.md"

# 1. Happy path: 12 rules in the doc, thin SKILL → PASS (exit 0).
write_doc "$DOC" 12
write_thin_skill "$SKILL"
rc=$(run_guard "$SKILL" "$DOC")
[ "$rc" = "0" ] && pass "12 rules + thin skill → exit 0" \
  || fail "12 rules + thin skill → exit 0" "got exit $rc"

# 2. SKILL re-inlines rule text → FAIL (exit 1).
write_doc "$DOC" 12
write_fat_skill "$SKILL"
rc=$(run_guard "$SKILL" "$DOC")
[ "$rc" = "1" ] && pass "skill re-inlines rules → exit 1" \
  || fail "skill re-inlines rules → exit 1" "got exit $rc"

# 3. Doc drops a rule (11) → FAIL (exit 1).
write_doc "$DOC" 11
write_thin_skill "$SKILL"
rc=$(run_guard "$SKILL" "$DOC")
[ "$rc" = "1" ] && pass "doc has 11 rules → exit 1" \
  || fail "doc has 11 rules → exit 1" "got exit $rc"

# 4. SKILL missing the canonical pointer → FAIL (exit 1).
write_doc "$DOC" 12
printf -- '---\nname: engineering-standards\n---\n# no pointer here\n' > "$SKILL"
rc=$(run_guard "$SKILL" "$DOC")
[ "$rc" = "1" ] && pass "skill missing pointer → exit 1" \
  || fail "skill missing pointer → exit 1" "got exit $rc"

# 5. A missing file → FAIL (exit 1), never a false green.
rc=$(run_guard "$SKILL" "$TESTDIR/nope.md")
[ "$rc" = "1" ] && pass "missing doc → exit 1" \
  || fail "missing doc → exit 1" "got exit $rc"

rm -rf "$TESTDIR"

echo ""
if [ "$FAILED" -eq 0 ]; then echo "ALL GREEN"; else echo "SOME RED"; fi
exit "$FAILED"
