#!/usr/bin/env bash
#
# Tests for the git-native pre-commit secret guard. Each test builds a throwaway
# git repo, stages known content, runs the hook from the repo root, and asserts
# the resulting COMMIT DECISION (exit code) and the class of message emitted
# (SECRET DETECTED vs HOOK ERROR) — not merely that the script ran.
#
# Contract under test (slice-1, issue #7):
#   - A staged secret (key format or secret file) is BLOCKED, fail-closed.
#   - A clean diff PASSES.
#   - Allowlisted example/sample/template files are exempt from BOTH the
#     filename rule AND the content scan (placeholder keys must not block).
#   - Token patterns are BOUNDED — short lookalikes do not false-positive.
#   - An internal failure BLOCKS with a HOOK ERROR message distinct from a
#     secret hit, so a hook bug does not train reflexive `--no-verify`.
set -uo pipefail

# Absolute path — tests cd into throwaway repos, so a relative path would break.
HOOK="$(cd "$(dirname "$0")" && pwd)/pre-commit"
FAILED=0

# Fixtures are ASSEMBLED FROM FRAGMENTS at runtime (adjacent-string concatenation)
# so no contiguous secret token ever appears in this committed file — otherwise
# the very guard under test, and CI gitleaks, would flag this test. The throwaway
# repos below still receive the full, contiguous secret.
AWS_KEY='AKIA''IOSFODNN7EXAMPLE'                          # canonical AWS example key
OAI_KEY='sk-''abcdefghijklmnopqrstuvwxyz0123456789'       # OpenAI-format, length-valid
OAI_PROJ='sk-proj-''abcdefghijklmnopqrstuvwxyz012345'     # placeholder for the .env.example case
PRIV_BEGIN='-----BEGIN RSA ''PRIVATE KEY-----'

pass() { echo "  ✔ $1"; }
fail() { echo "  ✖ $1"; echo "      $2"; FAILED=1; }

setup() {
  TESTDIR=$(mktemp -d)
  git -C "$TESTDIR" init -q
  git -C "$TESTDIR" config user.email t@t.co
  git -C "$TESTDIR" config user.name t
  ERR="$TESTDIR/.err"
}
teardown() { rm -rf "$TESTDIR"; }

# stage <relpath> ; content comes from stdin
stage() {
  local rel="$1"; shift
  local abs="$TESTDIR/$rel"
  mkdir -p "$(dirname "$abs")"
  cat > "$abs"
  git -C "$TESTDIR" add "$rel"
}

# run the hook from inside the repo; sets global RC and writes stderr to $ERR
run_hook() { ( cd "$TESTDIR" && bash "$HOOK" ) >/dev/null 2>"$ERR"; RC=$?; }

assert_pass() {  # assert_pass <label>
  if [ "$RC" -eq 0 ]; then pass "$1"
  else fail "$1" "expected PASS (rc 0); got rc=$RC, stderr: [$(cat "$ERR")]"; fi
}
assert_block() {  # assert_block <label> <expected-substring-in-stderr>
  if [ "$RC" -ne 0 ] && grep -qF "$2" "$ERR"; then pass "$1"
  else fail "$1" "expected BLOCK (rc!=0) with '[$2]'; got rc=$RC, stderr: [$(cat "$ERR")]"; fi
}

echo "▶ pre-commit secret guard"

# 1. Planted AWS key in an ordinary file → BLOCKED as a secret.
setup
printf 'const k = "%s"\n' "$AWS_KEY" | stage app.js
run_hook
assert_block "planted AWS key → blocked (SECRET DETECTED)" "SECRET DETECTED"
teardown

# 2. Clean diff → PASSES.
setup
printf 'export const greeting = "hello world"\n' | stage app.js
run_hook
assert_pass "clean diff → passes"
teardown

# 3. Staged .env file → BLOCKED (filename rule).
setup
printf 'API_KEY=whatever\n' | stage .env
run_hook
assert_block ".env staged → blocked (SECRET DETECTED)" "SECRET DETECTED"
teardown

# 4. REFINEMENT 1: placeholder key inside .env.example → PASSES (content scan
#    must skip allowlisted example files, not just the filename rule).
setup
printf 'AWS_KEY=%s\nOPENAI=%s\n' "$AWS_KEY" "$OAI_PROJ" | stage .env.example
run_hook
assert_pass ".env.example with placeholder keys → passes (content exempt)"
teardown

# 5. REFINEMENT 2: short 'sk-' lookalike → PASSES (bounded pattern, no FP).
setup
printf 'const task = "sk-short"\nname = "sk-abc"\n' | stage app.js
run_hook
assert_pass "short sk- lookalike → passes (bounded, no false positive)"
teardown

# 6. Real OpenAI-format key (bounded length met) → BLOCKED.
setup
printf 'const key = "%s"\n' "$OAI_KEY" | stage app.js
run_hook
assert_block "long sk- key → blocked (SECRET DETECTED)" "SECRET DETECTED"
teardown

# 7. Private key block → BLOCKED.
setup
printf -- '%s\nMIIabc\n-----END RSA PRIVATE KEY-----\n' "$PRIV_BEGIN" | stage id_rsa.txt
run_hook
assert_block "PRIVATE KEY block → blocked (SECRET DETECTED)" "SECRET DETECTED"
teardown

# 8. A secret introduced via a rename+modify must still be caught. With git's
#    default rename detection the file reports as 'R' (outside --diff-filter=ACM)
#    and would escape the scan — the guard must disable rename detection.
setup
# Large body so that adding one secret line keeps rename similarity HIGH — git's
# default detection then reports 'R' (which --diff-filter=ACM excludes). This is
# the case that escapes unless the guard disables rename detection.
for i in $(seq 1 40); do echo "export const v$i = $i"; done | stage old.js
git -C "$TESTDIR" commit -q -m init
git -C "$TESTDIR" mv old.js new.js
printf 'const AWS = "%s"\n' "$AWS_KEY" >> "$TESTDIR/new.js"
git -C "$TESTDIR" add new.js
run_hook
assert_block "secret in renamed+modified file → blocked (no-renames)" "SECRET DETECTED"
teardown

# 9. NIT: internal failure (run outside a git repo) → BLOCKED with HOOK ERROR,
#    a message class distinct from a secret hit.
NONREPO=$(mktemp -d)
( cd "$NONREPO" && bash "$HOOK" ) >/dev/null 2>"$NONREPO/.err"; RC=$?
if [ "$RC" -ne 0 ] && grep -qF "HOOK ERROR" "$NONREPO/.err" && ! grep -qF "SECRET DETECTED" "$NONREPO/.err"; then
  pass "internal failure → blocked with HOOK ERROR (not SECRET DETECTED)"
else
  fail "internal failure → blocked with HOOK ERROR (not SECRET DETECTED)" "got rc=$RC, stderr: [$(cat "$NONREPO/.err")]"
fi
rm -rf "$NONREPO"

# 10. Exec-bit assertion: a shebang file staged 100644 is BLOCKED.
#     This is the mechanization of artifact-vs-effect — a class that recurred three
#     times as a principle-in-a-checklist before becoming a gate. The same check
#     runs in CI, but CI fires after the bad mode is already committed.
setup
printf '#!/usr/bin/env bash\necho hi\n' > "$TESTDIR/tool.sh"
git -C "$TESTDIR" add tool.sh
git -C "$TESTDIR" update-index --chmod=-x tool.sh 2>/dev/null || true
run_hook
assert_block "shebang file staged 100644 → blocked" "NOT EXECUTABLE"
teardown

# 11. The same file staged 100755 → allowed. Without this, a guard that blocked
#     every script would pass test 10 and be useless.
setup
printf '#!/usr/bin/env bash\necho hi\n' > "$TESTDIR/tool.sh"
git -C "$TESTDIR" add tool.sh
git -C "$TESTDIR" update-index --chmod=+x tool.sh
run_hook
assert_pass "shebang file staged 100755 → allowed"
teardown

# 12. A NON-shebang file staged 100644 → allowed. The rule keys on shebang ∪ *.sh,
#     not on "every staged file", or ordinary source would be unable to commit.
setup
printf 'plain text, no shebang\n' > "$TESTDIR/notes.md"
git -C "$TESTDIR" add notes.md
run_hook
assert_pass "non-shebang file staged 100644 → allowed"
teardown

# 13. A *.mjs file staged 100644 → allowed. node-invoked, correctly non-executable;
#     the CI rule excludes it and this must match or the two gates disagree.
setup
printf '#!/usr/bin/env node\nconsole.log(1)\n' > "$TESTDIR/cli.mjs"
git -C "$TESTDIR" add cli.mjs
git -C "$TESTDIR" update-index --chmod=-x cli.mjs 2>/dev/null || true
run_hook
assert_pass "*.mjs staged 100644 → allowed (node-invoked)"
teardown

echo ""
if [ "$FAILED" -eq 0 ]; then echo "ALL GREEN"; else echo "SOME RED"; fi
exit "$FAILED"
