#!/usr/bin/env bash
#
# Tests for sync-project-assets.sh. Each test builds a throwaway project/repo
# pair in a mktemp -d working area and asserts the script's EXIT CODE — not
# merely that it ran. Fixtures are hand-built (bootstrap is never invoked), so
# these tests never touch the repo's own .git, index, or any live data.
#
# Contract under test: the sync must FAIL CLOSED when the manifest says the
# project has no workflow-sourced assets while the project's .claude/ tree is
# demonstrably non-empty. That combination is not "fully in sync" — it is the
# signature of a manifest that lost its entries (issue #16), which silently
# reclassifies every workflow asset as a project-local override and makes the
# project un-re-syncable forever after. A zero-everything summary followed by
# exit 0 is indistinguishable from a healthy run, so the defect hides. The
# only safe report is a loud non-zero exit.
set -uo pipefail

SYNC="$(cd "$(dirname "$0")" || exit 1; pwd)/sync-project-assets.sh"
FAILED=0

pass() { echo "  ✔ $1"; }
fail() { echo "  ✖ $1"; echo "      $2"; FAILED=1; }

# A manifest header with no data rows: exactly the comment block bootstrap
# writes (init_manifest in bootstrap-project.sh), and nothing else. The final
# line uses printf so the column legend carries real tabs, like the real file.
write_header_only_manifest() {  # write_header_only_manifest <path>
  local path="$1"
  {
    echo "# Asset manifest — agentic-engineering-workflow"
    echo "# Workflow-sourced files copied at bootstrap, with content hashes."
    echo "# Listed = workflow-sourced/re-syncable. Not listed = project override."
    echo "# Stale if workflow repo's current sha256 for a path != the hash here."
    echo "# Format: v2, 3 tab-separated columns (col 3 = repo-root-relative source path)."
    echo "# Generated: 2026-01-01"
    echo "# Source: agentic-engineering-workflow @ deadbee"
    echo "#"
    printf '# <path-relative-to-.claude/>\t<sha256-at-copy-time>\t<source-path-relative-to-repo-root>\n'
  } > "$path"
}

# Fake project: a non-empty .claude/ tree. The file inside is what makes the
# empty manifest a contradiction rather than a legitimately empty project.
make_project() {  # make_project <root> ; echoes <projectdir>
  local proj="$1/project"
  mkdir -p "$proj/.claude/skills/example" || return 1
  printf -- '---\nname: example\n---\n# Example skill\n' \
    > "$proj/.claude/skills/example/SKILL.md" || return 1
  echo "$proj"
}

# Fake repo: the script only requires <repo>/.claude to exist, so a stub with
# one file is enough to get past the preconditions.
make_repo() {  # make_repo <root> ; echoes <repodir>
  local repo="$1/repo"
  mkdir -p "$repo/.claude/skills/example" || return 1
  printf -- '---\nname: example\n---\n# Example skill\n' \
    > "$repo/.claude/skills/example/SKILL.md" || return 1
  echo "$repo"
}

# Dry run (no --apply): reports only, writes nothing. stdout+stderr are merged
# because the failure message needs whatever the script said before it stopped.
run_sync() {  # run_sync <projectdir> <repodir> ; echoes output, returns its rc
  bash "$SYNC" "$1" --repo "$2" 2>&1
}

echo "▶ sync-project-assets"

TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

# 1. Entry-less manifest beside a non-empty .claude/ -> must exit non-zero.
PROJECT=$(make_project "$TESTDIR")
REPO=$(make_repo "$TESTDIR")
if [ -z "$PROJECT" ] || [ -z "$REPO" ]; then
  fail "empty manifest + non-empty .claude/ → non-zero exit" \
       "could not build the fixture under $TESTDIR"
else
  write_header_only_manifest "$PROJECT/.claude/.asset-manifest"
  out=$(run_sync "$PROJECT" "$REPO")
  rc=$?
  [ "$rc" -ne 0 ] && pass "empty manifest + non-empty .claude/ → non-zero exit" \
    || fail "empty manifest + non-empty .claude/ → non-zero exit" \
            "got exit $rc (expected non-zero); output was:
$out"
fi

# 2. An 'unknown'-provenance entry must never be auto-updated, even with --apply.
#    bootstrap records that sentinel when a file is present, differs from the repo,
#    and has no prior manifest entry — "the owner edited it" and "stale copy from a
#    pre-manifest bootstrap" are indistinguishable at that point. Auto-refreshing
#    would silently destroy a real override, so the only safe action is to report
#    and touch nothing (issue #16).
TESTDIR=$(mktemp -d)
PROJECT=$(make_project "$TESTDIR")
REPO=$(make_repo "$TESTDIR")
if [ -z "$PROJECT" ] || [ -z "$REPO" ]; then
  fail "unknown-provenance entry is never auto-updated" \
       "could not build the fixture under $TESTDIR"
else
  # Project copy differs from the repo copy, and is recorded as 'unknown'.
  printf -- 'LOCAL CONTENT THAT MUST SURVIVE\n' \
    > "$PROJECT/.claude/skills/example/SKILL.md"
  before=$(cat "$PROJECT/.claude/skills/example/SKILL.md")
  write_header_only_manifest "$PROJECT/.claude/.asset-manifest"
  printf 'skills/example/SKILL.md\tunknown\t.claude/skills/example/SKILL.md\n' \
    >> "$PROJECT/.claude/.asset-manifest"

  out=$(bash "$SYNC" "$PROJECT" --repo "$REPO" --apply 2>&1)
  after=$(cat "$PROJECT/.claude/skills/example/SKILL.md")

  if [ "$before" != "$after" ]; then
    fail "unknown-provenance entry is never auto-updated" \
         "--apply overwrote the file; output was:
$out"
  elif ! printf '%s' "$out" | grep -qi 'unknown'; then
    fail "unknown-provenance entry is never auto-updated" \
         "file survived but the report never mentions unknown provenance; output was:
$out"
  else
    pass "unknown-provenance entry is never auto-updated"
  fi
fi

# 3. A repo asset the project has never tracked must be reported as ADD, and
#    installed on --apply. Without this the sync only ever looks at the project's
#    own manifest, so an asset added to the workflow AFTER a project was
#    bootstrapped is invisible — reported as neither missing nor stale. That is
#    how jobs-radar ended up with no import guard and no git secret guard while
#    the sync called it healthy (issue #16).
TESTDIR=$(mktemp -d)
PROJECT=$(make_project "$TESTDIR")
REPO=$(make_repo "$TESTDIR")
if [ -z "$PROJECT" ] || [ -z "$REPO" ]; then
  fail "untracked repo asset is reported as ADD and installed on --apply" \
       "could not build the fixture under $TESTDIR"
else
  # The repo gains a command the project has never seen. The skill exists in both
  # and is tracked, so the manifest is legitimately non-empty.
  mkdir -p "$REPO/.claude/commands" "$PROJECT/.claude/commands"
  printf -- '# Research command\n' > "$REPO/.claude/commands/research.md"

  skill_hash=$(sha256sum "$PROJECT/.claude/skills/example/SKILL.md" | cut -d' ' -f1)
  write_header_only_manifest "$PROJECT/.claude/.asset-manifest"
  printf 'skills/example/SKILL.md\t%s\t.claude/skills/example/SKILL.md\n' "$skill_hash" \
    >> "$PROJECT/.claude/.asset-manifest"

  dry=$(bash "$SYNC" "$PROJECT" --repo "$REPO" 2>&1)
  if ! printf '%s' "$dry" | grep -q 'commands/research.md'; then
    fail "untracked repo asset is reported as ADD and installed on --apply" \
         "dry run never mentioned the untracked asset; output was:
$dry"
  elif [ -e "$PROJECT/.claude/commands/research.md" ]; then
    fail "untracked repo asset is reported as ADD and installed on --apply" \
         "dry run WROTE the file — a dry run must change nothing"
  else
    bash "$SYNC" "$PROJECT" --repo "$REPO" --apply >/dev/null 2>&1
    if [ -f "$PROJECT/.claude/commands/research.md" ] &&
       grep -q 'commands/research.md' "$PROJECT/.claude/.asset-manifest"; then
      pass "untracked repo asset is reported as ADD and installed on --apply"
    else
      fail "untracked repo asset is reported as ADD and installed on --apply" \
           "--apply did not install the file and record it in the manifest"
    fi
  fi
fi

rm -rf "$TESTDIR"

echo ""
if [ "$FAILED" -eq 0 ]; then echo "ALL GREEN"; else echo "SOME RED"; fi
exit "$FAILED"
