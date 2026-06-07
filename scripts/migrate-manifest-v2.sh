#!/usr/bin/env bash
#
# migrate-manifest-v2.sh — ONE-TIME, DISPOSABLE bridge.
#
# Upgrades a project's .claude/.asset-manifest from the old 2-column format
#   <path-relative-to-.claude/>\t<sha256>
# to v2 3-column (matching fresh-bootstrap output)
#   <path-relative-to-.claude/>\t<sha256>\t<source-path-relative-to-repo-root>
#
# WHY THIS EXISTS / WHY IT'S DISPOSABLE:
#   This script is the ONLY place the old "engineering-standards.md is sourced
#   from docs/standards/" special-case still lives. The live tooling
#   (bootstrap record_asset writes column 3 from each asset's real source;
#   sync repo_source_for reads column 3) has no hardcode. Once every existing
#   project's manifest is migrated, DELETE this script.
#
# IT PRESERVES COLUMN-2 HASHES VERBATIM — it does NOT re-hash. This is a format
# upgrade, not a re-sync. Re-hashing would overwrite the recorded "state at last
# bootstrap/sync" with "state now", silently erasing any drift the next sync is
# supposed to detect. The hashes must carry through untouched.
#
# Default is DRY RUN (prints the would-be manifest, writes nothing).
# Pass --apply to write it in place. Run from WSL2 (real Linux shell).
#
# Usage:
#   scripts/migrate-manifest-v2.sh <project-path> [--apply]

set -euo pipefail

# ─── Args ─────────────────────────────────────────────────────────────────────
PROJECT_PATH=""
APPLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    -*)      echo "Unknown flag: $1" >&2; exit 2 ;;
    *)       if [ -z "$PROJECT_PATH" ]; then PROJECT_PATH="$1"; shift
             else echo "Unexpected extra arg: $1" >&2; exit 2; fi ;;
  esac
done

[ -n "$PROJECT_PATH" ] || { echo "Usage: $0 <project-path> [--apply]" >&2; exit 2; }
MANIFEST="$PROJECT_PATH/.claude/.asset-manifest"
[ -f "$MANIFEST" ] || { echo "ERROR: no manifest at $MANIFEST" >&2; exit 1; }

# Derive column 3 (repo-root-relative source) from column 1. This mapping
# encodes the old special-case and is intentionally hardcoded HERE ONLY.
# It mirrors what fresh bootstrap now records from each asset's real source.
src_for() {
  case "$1" in
    engineering-standards.md) echo "docs/standards/engineering-standards.md" ;;
    *)                        echo ".claude/$1" ;;
  esac
}

# ─── Detect format (refuse already-v2 or mixed) ───────────────────────────────
data_lines=0; twocol=0; threecol=0
while IFS= read -r line; do
  case "$line" in ""|\#*) continue ;; esac
  data_lines=$((data_lines + 1))
  ncol=$(awk -F'\t' '{print NF; exit}' <<<"$line")
  case "$ncol" in
    2) twocol=$((twocol + 1)) ;;
    3) threecol=$((threecol + 1)) ;;
    *) echo "ERROR: $MANIFEST has a line with $ncol columns (expected 2): $line" >&2; exit 1 ;;
  esac
done < "$MANIFEST"

[ "$data_lines" -gt 0 ] || { echo "ERROR: $MANIFEST has no data lines." >&2; exit 1; }
if [ "$threecol" -gt 0 ] && [ "$twocol" -eq 0 ]; then
  echo "Already v2 (3-column): $MANIFEST — nothing to migrate."; exit 0
fi
if [ "$threecol" -gt 0 ] && [ "$twocol" -gt 0 ]; then
  echo "ERROR: $MANIFEST mixes 2- and 3-column data lines — refusing to guess." >&2; exit 1
fi

# ─── Build migrated manifest (v2 header + preserved hashes + derived col 3) ────
tmp="$(mktemp)"
{
  echo "# Asset manifest — agentic-engineering-workflow"
  echo "# Workflow-sourced files copied at bootstrap, with content hashes."
  echo "# Listed = workflow-sourced/re-syncable. Not listed = project override."
  echo "# Stale if workflow repo's current sha256 for a path != the hash here."
  echo "# Format: v2, 3 tab-separated columns (col 3 = repo-root-relative source path)."
  echo "# Migrated 2-col -> 3-col by migrate-manifest-v2.sh on $(date -I) (hashes preserved, not re-hashed)."
  # Carry forward original provenance comments if present.
  grep -E '^# (Generated|Source):' "$MANIFEST" || true
  echo "#"
  printf '# <path-relative-to-.claude/>\t<sha256-at-copy-time>\t<source-path-relative-to-repo-root>\n'
  # Data: preserve path + hash verbatim, append derived source path.
  while IFS=$'\t' read -r path hash; do
    case "$path" in ""|\#*) continue ;; esac
    [ -n "$hash" ] || { echo "ERROR: data line missing hash: $path" >&2; exit 1; }
    printf '%s\t%s\t%s\n' "$path" "$hash" "$(src_for "$path")"
  done < "$MANIFEST"
} > "$tmp"

# ─── Output ───────────────────────────────────────────────────────────────────
if [ "$APPLY" -eq 1 ]; then
  mv "$tmp" "$MANIFEST"
  echo "Migrated in place: $MANIFEST"
  echo "(rollback: the project's own git history holds the previous 2-col manifest)"
else
  echo "=== DRY RUN — would write the following to $MANIFEST ==="
  cat "$tmp"
  rm -f "$tmp"
  echo "=== end DRY RUN. Re-run with --apply to write. ==="
fi
