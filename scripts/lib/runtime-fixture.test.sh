#!/usr/bin/env bash
#
# Tests for runtime-fixture.sh — the runtime-faithful fixture tier (#33, catch 5a).
#
# The contract these pin is unusual and worth stating: a fixture helper is only
# useful if the fixture actually REPRODUCES the production hazard. A helper that
# claims to build a UNC-rooted fixture but quietly hands back a /tmp path would be
# worse than no helper, because every suite using it would report green while
# testing the same runtime it always did. So these tests assert the hazard is
# present, not merely that a directory was created.
set -uo pipefail

LIB="$(cd "$(dirname "$0")" && pwd)/runtime-fixture.sh"
FAILED=0

pass() { echo "  ✔ $1"; }
fail() { echo "  ✖ $1"; echo "      $2"; FAILED=1; }

# shellcheck source=runtime-fixture.sh
source "$LIB"

echo "▶ runtime-fixture"

# 1. The fixture root is the production path shape, not /tmp.
#    This is the whole point: /tmp is MSYS, production is UNC, and `mkdir -p`
#    behaves differently on the two.
root="$(runtime_fixture_root)"
case "$root" in
  //*) pass "fixture root is UNC-rooted (production path shape)" ;;
  *)   fail "fixture root is UNC-rooted (production path shape)" \
            "got '$root' — a non-UNC root means every suite using this helper tests the wrong runtime" ;;
esac

# 2. runtime_mktemp_d creates a usable directory under that root.
d="$(runtime_mktemp_d)"
if [ -n "$d" ] && [ -d "$d" ]; then
  case "$d" in
    //*) pass "runtime_mktemp_d creates a UNC-rooted directory" ;;
    *)   fail "runtime_mktemp_d creates a UNC-rooted directory" "got '$d'" ;;
  esac
else
  fail "runtime_mktemp_d creates a UNC-rooted directory" "no directory created (got '$d')"
fi

# 3. THE FIXTURE REPRODUCES THE HAZARD. `mkdir -p` on an absolute UNC path fails
#    here — that is the defect that made bootstrap unable to touch any real
#    project while passing its whole suite. If this assertion ever goes green-side
#    (i.e. mkdir starts succeeding), the environment changed and #33's premise
#    needs re-checking; that is informative, not brittle.
if [ -n "${d:-}" ] && [ -d "$d" ]; then
  if mkdir -p "$d/hazard-probe" 2>/dev/null; then
    fail "fixture reproduces the UNC mkdir hazard" \
         "mkdir -p on an absolute UNC path SUCCEEDED — the fixture no longer reproduces the production condition, so it is not runtime-faithful. Re-check #33's premise."
  else
    pass "fixture reproduces the UNC mkdir hazard"
  fi
fi

# 4. ensure_dir (the portable helper) works where raw mkdir -p does not. Together
#    with 3, this proves the fixture is faithful AND that the fix is real.
# shellcheck source=portable-fs.sh
source "$(cd "$(dirname "$0")" && pwd)/portable-fs.sh"
if [ -n "${d:-}" ] && [ -d "$d" ]; then
  if ensure_dir "$d" "a/b/c" && [ -d "$d/a/b/c" ]; then
    pass "ensure_dir succeeds on the same path mkdir -p rejects"
  else
    fail "ensure_dir succeeds on the same path mkdir -p rejects" "ensure_dir failed under $d"
  fi
fi

# 5. CRLF fixtures. The catch-log generator shipped the wrong content because it
#    searched for an LF-delimited marker in a CRLF file. A helper that writes CRLF
#    on demand is what lets a text-processing test exercise that condition.
if [ -n "${d:-}" ] && [ -d "$d" ]; then
  runtime_write_crlf "$d/crlf.txt" "alpha" "---" "beta"
  # Checked with `od`, NOT `grep`. MSYS grep strips CR before matching, so
  # `grep -q $'\r'` returns false on a file that demonstrably contains CR — the
  # first version of this assertion did exactly that and reported the helper
  # broken when the bytes were correct. An assertion that cannot observe the
  # property it tests is `overbroad-assertion`, and using a CR-stripping tool to
  # look for CR is that failure in its purest form.
  crs=$(od -c "$d/crlf.txt" 2>/dev/null | grep -c '\\r' || true)
  if [ -f "$d/crlf.txt" ] && [ "${crs:-0}" -gt 0 ]; then
    pass "runtime_write_crlf produces real CRLF line endings"
  else
    fail "runtime_write_crlf produces real CRLF line endings" \
         "no CR bytes found via od — a test relying on this would silently exercise LF"
  fi
fi

# 6. Cleanup actually removes the fixture. A helper that leaks directories into the
#    WSL home on every run is its own problem.
if [ -n "${d:-}" ]; then
  runtime_fixture_cleanup "$d"
  if [ -d "$d" ]; then
    fail "runtime_fixture_cleanup removes the fixture" "$d still exists"
  else
    pass "runtime_fixture_cleanup removes the fixture"
  fi
fi

echo ""
if [ "$FAILED" -eq 0 ]; then echo "ALL GREEN"; else echo "SOME RED"; fi
exit "$FAILED"
