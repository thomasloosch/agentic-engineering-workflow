#!/usr/bin/env bash
#
# Tests for bootstrap-project.sh. Each test builds a throwaway project in a
# mktemp -d working area and asserts on the OBSERVABLE artefact the script
# leaves behind — the asset manifest at <project>/.claude/.asset-manifest —
# never on the repo's own .git, index, or any live data.
#
# Contract under test: bootstrap is IDEMPOTENT with respect to the manifest.
# The manifest is the record of which files are workflow-sourced and therefore
# re-syncable; a file absent from it is treated as a project-local override and
# is never auto-overwritten. So a second bootstrap of the same project must not
# shrink that record: whatever the first run listed, the second must still list.
# Re-running is the normal way to pick up workflow updates, and a manifest that
# empties itself on re-run silently reclassifies every workflow asset as a local
# override — the project stops being re-syncable at all (issue #16).
set -uo pipefail

BOOTSTRAP="$(cd "$(dirname "$0")" && pwd)/bootstrap-project.sh"
FAILED=0

pass() { echo "  ✔ $1"; }
fail() { echo "  ✖ $1"; echo "      $2"; FAILED=1; }

# Fresh throwaway project: a git repo in its own directory under the temp work
# area. Echoes the project path; the temp work area is removed on exit.
make_project() {  # make_project <parent> <name> ; echoes <projectdir>
  local proj="$1/$2"
  mkdir -p "$proj" || return 1
  ( cd "$proj" || exit 1; git init -q . ) || return 1
  echo "$proj"
}

# Run the script under test against a project. Its chatty stdout is noise here;
# only the artefacts it writes matter.
run_bootstrap() {  # run_bootstrap <projectdir> <project name>
  bash "$BOOTSTRAP" "$1" "$2" >/dev/null
}

# Manifest entries = lines that are not comments. Comment lines start with '#';
# blank lines start with nothing, so '^[^#]' excludes both. grep exits 1 on zero
# matches, which is a legitimate count of 0, not an error.
count_manifest_entries() {  # count_manifest_entries <projectdir> ; echoes <n>
  local manifest="$1/.claude/.asset-manifest"
  [ -f "$manifest" ] || { echo 0; return 0; }
  grep -c '^[^#]' "$manifest" || true
}

echo "▶ bootstrap-project"

TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

# 1. Re-run must not shrink the manifest (issue #16 regression case).
#    Every copy step reads "exists on disk and is not a symlink" as "local
#    override — preserve, do not record", while init_manifest truncates first.
#    Second run therefore records nothing and the manifest comes back empty.
PROJECT=$(make_project "$TESTDIR" "probe-one")
if [ -z "$PROJECT" ]; then
  fail "re-run preserves manifest entries" "could not create the temp project"
else
  run_bootstrap "$PROJECT" "Probe One"
  first=$(count_manifest_entries "$PROJECT")
  run_bootstrap "$PROJECT" "Probe One"
  second=$(count_manifest_entries "$PROJECT")
  [ "$second" -ge "$first" ] && pass "re-run preserves manifest entries" \
    || fail "re-run preserves manifest entries" \
            "manifest shrank on re-run: first=$first second=$second"
fi

# 2. A file the owner edited keeps its ORIGINAL recorded hash across a re-run.
#
#    Added because a mutation check exposed test 1 as weaker than it looked:
#    disabling the prior-manifest load leaves the entry COUNT intact (every file
#    then reads as "untracked but identical to the repo" and is adopted), so test 1
#    stayed green with the load-bearing code removed. The behaviour that genuinely
#    depends on reading the prior manifest is this one.
#
#    Why the original hash and not the current one: sync classifies by comparing
#    the recorded hash against the project's file and the repo's file. Re-recording
#    an override at its CURRENT hash would make the next sync read
#    "project untouched, repo moved -> safe to refresh" and silently overwrite the
#    owner's edit. Preserving the original is what keeps that classification true.
PROJECT=$(make_project "$TESTDIR" "probe-two")
if [ -z "$PROJECT" ]; then
  fail "owner override keeps its original recorded hash" "could not create the temp project"
else
  run_bootstrap "$PROJECT" "Probe Two"
  tracked="skills/tdd/SKILL.md"
  before=$(awk -F'\t' -v p="$tracked" '$1==p{print $2}' "$PROJECT/.claude/.asset-manifest")

  printf -- '\nOWNER EDIT\n' >> "$PROJECT/.claude/$tracked"
  run_bootstrap "$PROJECT" "Probe Two"

  after=$(awk -F'\t' -v p="$tracked" '$1==p{print $2}' "$PROJECT/.claude/.asset-manifest")
  edit_survived=$(tail -1 "$PROJECT/.claude/$tracked")

  if [ -z "$before" ]; then
    fail "owner override keeps its original recorded hash" \
         "fixture problem: $tracked was not in the manifest after the first run"
  elif [ "$edit_survived" != "OWNER EDIT" ]; then
    fail "owner override keeps its original recorded hash" \
         "the re-run OVERWROTE the owner's edit"
  elif [ "$after" != "$before" ]; then
    fail "owner override keeps its original recorded hash" \
         "recorded hash changed: before=$before after=$after"
  else
    pass "owner override keeps its original recorded hash"
  fi
fi

rm -rf "$TESTDIR"

echo ""
if [ "$FAILED" -eq 0 ]; then echo "ALL GREEN"; else echo "SOME RED"; fi
exit "$FAILED"
