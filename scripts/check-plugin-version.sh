#!/usr/bin/env bash
#
# check-plugin-version.sh — fail when shipped plugin content changed without a
# version bump in .claude-plugin/plugin.json.
#
# WHY THIS IS NOT OPTIONAL
#
# A plugin change with an unchanged version is a SILENT no-op: consumers keep the
# cached copy and never see it. Nothing errors, nothing warns, and the author
# believes the change shipped. That is the fail-open shape this program has now
# logged repeatedly — a guard or a delivery path reporting success while doing
# nothing.
#
# WHAT IT DELEGATES
#
# Manifest agreement (plugin.json's version matching the enclosing marketplace
# entry) is already validated by `claude plugin tag --dry-run`, which also refuses
# on a dirty tree. That is reused rather than reimplemented — it is the tool's own
# validator and cannot drift from the tool. This script adds the one thing that
# validator does not do: compare shipped content against the previous commit and
# require the version to have moved.
#
# Usage:
#   check-plugin-version.sh [BASE_REF]      # default: HEAD~1
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

BASE="${1:-HEAD~1}"
MANIFEST=".claude-plugin/plugin.json"

# Paths whose content is actually delivered to consumers. A change to anything
# here that is invisible to consumers is the failure being guarded.
SHIPPED_PATHS=(
  ".claude-plugin"
  ".claude/skills"
  "docs/checklists"
)

fail() { echo "check-plugin-version: $1" >&2; exit 1; }

[ -f "$MANIFEST" ] || fail "no $MANIFEST — is this the workflow repo?"

# No base to compare against -> say so rather than passing silently. A guard that
# cannot run must not report success.
#
# `cat-file -e <ref>^{commit}` rather than `rev-parse --verify`: in a SHALLOW clone
# rev-parse can resolve a full SHA that is not actually present, so the check would
# pass and the diff below would then fail. That is exactly what happened in CI —
# actions/checkout defaults to depth 1, the base commit was absent, `git diff` wrote
# "fatal: bad object" to stderr, and the old `|| true` turned that into an empty
# result which read as "nothing changed". The guard reported OK on a commit that
# had in fact changed shipped content: a fail-open, in the guard written to prevent
# fail-opens. The workflow now also fetches enough history; this is the second layer.
if ! git cat-file -e "${BASE}^{commit}" 2>/dev/null; then
  echo "check-plugin-version: SKIPPED — base commit '$BASE' is not present in this clone." >&2
  echo "check-plugin-version: this is a LOUD skip: NO version check ran." >&2
  echo "check-plugin-version: if this is CI, deepen the checkout (fetch-depth) so the" >&2
  echo "check-plugin-version: base commit exists — a skipped guard protects nothing." >&2
  exit 0
fi

read_version() {  # read_version <ref|WORKTREE>
  if [ "$1" = "WORKTREE" ]; then
    node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(JSON.parse(s).version||"")}catch(e){process.stdout.write("PARSE_ERROR")}})' < "$MANIFEST"
  else
    git show "$1:$MANIFEST" 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(JSON.parse(s).version||"")}catch(e){process.stdout.write("")}})'
  fi
}

# NOT `|| true`. A failing diff must be fatal, never an empty result: an empty
# result means "nothing changed", and reporting that when the comparison could not
# run is the fail-open this guard exists to prevent.
if ! changed="$(git diff --name-only "$BASE" HEAD -- "${SHIPPED_PATHS[@]}" 2>&1)"; then
  fail "could not diff against '$BASE': $changed"
fi

if [ -z "$changed" ]; then
  echo "check-plugin-version: OK — no shipped plugin content changed since $BASE."
  exit 0
fi

old_version="$(read_version "$BASE")"
new_version="$(read_version HEAD)"

[ "$new_version" = "PARSE_ERROR" ] && fail "$MANIFEST is not valid JSON."
[ -z "$new_version" ] && fail "$MANIFEST has no version field."

# A manifest that did not exist at BASE means the plugin is new — nothing to bump.
if [ -z "$old_version" ]; then
  echo "check-plugin-version: OK — plugin manifest is new at HEAD (version $new_version)."
  exit 0
fi

if [ "$old_version" = "$new_version" ]; then
  echo "check-plugin-version: FAIL — shipped plugin content changed but the version did not." >&2
  echo "" >&2
  echo "  version: $new_version (unchanged since $BASE)" >&2
  echo "  changed files:" >&2
  printf '    %s\n' $changed >&2
  echo "" >&2
  echo "  An unbumped plugin change is a SILENT no-op: consumers keep the cached" >&2
  echo "  copy and never receive it. Nothing would error and nothing would warn." >&2
  echo "" >&2
  echo "  Fix: bump \"version\" in $MANIFEST (and the matching marketplace entry)." >&2
  exit 1
fi

echo "check-plugin-version: OK — content changed and version moved $old_version -> $new_version."
exit 0
