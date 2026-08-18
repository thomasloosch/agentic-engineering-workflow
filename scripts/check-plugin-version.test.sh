#!/usr/bin/env bash
#
# Tests for check-plugin-version.sh.
#
# Contract: shipped plugin content changing without a version bump must FAIL, and
# nothing else may. The guard exists because an unbumped plugin change is a silent
# no-op for every consumer — so a vacuous version of this guard (one that passes
# regardless) would be worse than not having it.
#
# Every case builds a throwaway git repo under mktemp -d and never touches this
# repo's own .git (verification.md catch 6). Directory changes are guarded
# explicitly rather than relying on set -e.
set -uo pipefail

GUARD="$(cd "$(dirname "$0")" && pwd)/check-plugin-version.sh"
FAILED=0

pass() { echo "  ✔ $1"; }
fail() { echo "  ✖ $1"; echo "      $2"; FAILED=1; }

# A throwaway repo with the guard copied in, one commit of baseline content.
make_repo() {  # make_repo <root> <version> ; echoes repo path
  local repo="$1/r"
  mkdir -p "$repo/scripts" "$repo/.claude-plugin" "$repo/.claude/skills/demo" || return 1
  cp "$GUARD" "$repo/scripts/check-plugin-version.sh" || return 1
  chmod +x "$repo/scripts/check-plugin-version.sh"
  printf '{\n  "name": "demo",\n  "version": "%s"\n}\n' "$2" > "$repo/.claude-plugin/plugin.json"
  printf -- '---\nname: demo\n---\n# Demo\n' > "$repo/.claude/skills/demo/SKILL.md"
  ( cd "$repo" || exit 1
    git init -q .
    git config user.email t@e; git config user.name t
    git add -A >/dev/null 2>&1
    git commit -q -m baseline ) || return 1
  echo "$repo"
}

run_guard() {  # run_guard <repo> ; echoes output, returns rc
  ( cd "$1" || exit 1; bash scripts/check-plugin-version.sh ) 2>&1
}

echo "▶ check-plugin-version"

TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

# 1. Shipped content changed, version unchanged -> FAIL. The whole point.
REPO=$(make_repo "$TESTDIR/a" "1.0.0")
if [ -z "$REPO" ]; then
  fail "content changed + version unchanged -> fail" "fixture build failed"
else
  ( cd "$REPO" || exit 1
    printf -- '---\nname: demo\n---\n# Demo CHANGED\n' > .claude/skills/demo/SKILL.md
    git add -A >/dev/null 2>&1; git commit -q -m "change skill, no bump" )
  out=$(run_guard "$REPO"); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'version did not'; then
    pass "content changed + version unchanged -> fail"
  else
    fail "content changed + version unchanged -> fail" "rc=$rc, output:
$out"
  fi
fi

# 2. Shipped content changed WITH a version bump -> pass. Without this, a guard
#    that always failed would satisfy test 1 and block every release.
REPO=$(make_repo "$TESTDIR/b" "1.0.0")
if [ -z "$REPO" ]; then
  fail "content changed + version bumped -> pass" "fixture build failed"
else
  ( cd "$REPO" || exit 1
    printf -- '---\nname: demo\n---\n# Demo CHANGED\n' > .claude/skills/demo/SKILL.md
    printf '{\n  "name": "demo",\n  "version": "1.1.0"\n}\n' > .claude-plugin/plugin.json
    git add -A >/dev/null 2>&1; git commit -q -m "change skill + bump" )
  out=$(run_guard "$REPO"); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '1.0.0 -> 1.1.0'; then
    pass "content changed + version bumped -> pass"
  else
    fail "content changed + version bumped -> pass" "rc=$rc, output:
$out"
  fi
fi

# 3. Only NON-shipped content changed -> pass, version untouched. The guard must
#    not force a plugin release for every docs or script edit in the repo.
REPO=$(make_repo "$TESTDIR/c" "1.0.0")
if [ -z "$REPO" ]; then
  fail "unshipped content changed -> pass" "fixture build failed"
else
  ( cd "$REPO" || exit 1
    mkdir -p docs/metrics && printf 'notes\n' > docs/metrics/whatever.md
    git add -A >/dev/null 2>&1; git commit -q -m "unrelated docs" )
  out=$(run_guard "$REPO"); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'no shipped plugin content changed'; then
    pass "unshipped content changed -> pass"
  else
    fail "unshipped content changed -> pass" "rc=$rc, output:
$out"
  fi
fi

# 4. A missing base ref must SKIP LOUDLY, never pass quietly. A guard that cannot
#    run and says nothing is indistinguishable from one that ran and approved.
REPO=$(make_repo "$TESTDIR/d" "1.0.0")
if [ -z "$REPO" ]; then
  fail "missing base ref -> loud skip" "fixture build failed"
else
  out=$( ( cd "$REPO" || exit 1; bash scripts/check-plugin-version.sh no-such-ref ) 2>&1 ); rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'LOUD skip'; then
    pass "missing base ref -> loud skip"
  else
    fail "missing base ref -> loud skip" "rc=$rc, output:
$out"
  fi
fi

echo ""
if [ "$FAILED" -eq 0 ]; then echo "ALL GREEN"; else echo "SOME RED"; fi
exit "$FAILED"
