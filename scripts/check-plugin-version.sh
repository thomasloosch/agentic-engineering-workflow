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

# No base to compare against (shallow clone, first commit) -> say so rather than
# passing silently. A guard that cannot run must not report success.
if ! git rev-parse --verify --quiet "$BASE" >/dev/null; then
  echo "check-plugin-version: SKIPPED — base ref '$BASE' not available."
  echo "check-plugin-version: this is a LOUD skip: no version check ran."
  exit 0
fi

read_version() {  # read_version <ref|WORKTREE>
  if [ "$1" = "WORKTREE" ]; then
    node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(JSON.parse(s).version||"")}catch(e){process.stdout.write("PARSE_ERROR")}})' < "$MANIFEST"
  else
    git show "$1:$MANIFEST" 2>/dev/null | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{try{process.stdout.write(JSON.parse(s).version||"")}catch(e){process.stdout.write("")}})'
  fi
}

changed="$(git diff --name-only "$BASE" HEAD -- "${SHIPPED_PATHS[@]}" 2>/dev/null || true)"

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
