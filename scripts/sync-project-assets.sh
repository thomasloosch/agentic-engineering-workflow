#!/usr/bin/env bash
#
# sync-project-assets.sh — refresh a project's workflow-sourced .claude/ assets
# from the canonical agentic-engineering-workflow repo, WITHOUT silently
# clobbering local edits.
#
# Direction: repo (source of truth) -> project (sync target).
# Authority on what is re-syncable: the project's .claude/.asset-manifest.
#   Listed   = workflow-sourced, re-syncable.
#   Not listed = project override or non-workflow file -> NEVER touched.
#
# Three-hash comparison per manifest entry:
#   a = hash recorded in manifest (state at last bootstrap/sync)
#   b = hash of project's current copy
#   c = hash of repo's current source
#     b==a, c==a  -> SKIP   (nothing changed)
#     b==a, c!=a  -> UPDATE (repo moved, project untouched -> safe to refresh)
#     b!=a, c==a  -> KEEP   (local override -> leave it, report)
#     b!=a, c!=a  -> CONFLICT (both moved -> REFUSE, report, touch nothing)
#   source missing -> report, never delete project copy
#   project copy missing -> report as MISSING (re-add candidate)
#
# Default: DRY RUN (reports, changes nothing).
# --apply: performs UPDATEs and re-adds MISSING files; refreshes their manifest
#          hashes. CONFLICTs are NEVER auto-resolved, even with --apply.
#
# Run from WSL2 (real Linux shell). Usage:
#   scripts/sync-project-assets.sh <project-path> [--apply]
#   scripts/sync-project-assets.sh <project-path> --repo <repo-path> [--apply]

set -euo pipefail

# ─── Args ─────────────────────────────────────────────────────────────────────
PROJECT_PATH=""
REPO_PATH=""
APPLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --repo)  REPO_PATH="${2:-}"; shift 2 ;;
    -*)      echo "Unknown flag: $1" >&2; exit 2 ;;
    *)       if [ -z "$PROJECT_PATH" ]; then PROJECT_PATH="$1"; else echo "Unexpected arg: $1" >&2; exit 2; fi; shift ;;
  esac
done

if [ -z "$PROJECT_PATH" ]; then
  echo "Usage: $0 <project-path> [--repo <repo-path>] [--apply]" >&2
  exit 2
fi

# Default repo path = the repo this script lives in (resolve via script dir).
if [ -z "$REPO_PATH" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

MANIFEST="$PROJECT_PATH/.claude/.asset-manifest"
PROJECT_CLAUDE="$PROJECT_PATH/.claude"
REPO_CLAUDE="$REPO_PATH/.claude"

# ─── Preconditions ────────────────────────────────────────────────────────────
[ -d "$PROJECT_CLAUDE" ] || { echo "ERROR: no .claude/ in project: $PROJECT_CLAUDE" >&2; exit 1; }
[ -d "$REPO_CLAUDE" ]    || { echo "ERROR: no .claude/ in repo: $REPO_CLAUDE" >&2; exit 1; }
[ -f "$MANIFEST" ]       || { echo "ERROR: no manifest: $MANIFEST" >&2; exit 1; }

hash_of() { sha256sum "$1" | cut -d' ' -f1; }

# Resolve a manifest dest-path to its REPO source path.
# Mirrors bootstrap-project.sh's copy logic: most assets map straight into
# .claude/<path>, but engineering-standards.md is sourced from docs/standards/.
# NOTE: this duplicates bootstrap's mapping. The correct long-term fix is to
# record source paths in the manifest (a 3rd column) so this special-case dies.
# Until then, an unmapped non-.claude source surfaces as SRC-GONE (fails safe).
repo_source_for() {
  case "$1" in
    engineering-standards.md) echo "$REPO_PATH/docs/standards/engineering-standards.md" ;;
    *)                        echo "$REPO_CLAUDE/$1" ;;
  esac
}

# ─── Mode banner ──────────────────────────────────────────────────────────────
if [ "$APPLY" -eq 1 ]; then
  echo "=== sync-project-assets: APPLY mode (will write safe updates) ==="
else
  echo "=== sync-project-assets: DRY RUN (no changes; pass --apply to write) ==="
fi
echo "  repo:    $REPO_PATH"
echo "  project: $PROJECT_PATH"
echo

# ─── Parse manifest, dedupe (tolerate bootstrap double-write; last wins) ──────
# Read path<TAB>hash, skip comments/blanks. Last occurrence of a path wins.
declare -A RECORDED
ORDER=()
while IFS=$'\t' read -r path hash; do
  [ -z "${path:-}" ] && continue
  case "$path" in \#*) continue ;; esac
  [ -z "${hash:-}" ] && continue
  if [ -z "${RECORDED[$path]+x}" ]; then ORDER+=("$path"); fi
  RECORDED["$path"]="$hash"
done < "$MANIFEST"

# ─── Classify ─────────────────────────────────────────────────────────────────
TO_UPDATE=()
TO_READD=()
n_skip=0 n_keep=0 n_conflict=0 n_update=0 n_missing_src=0 n_readd=0

for path in "${ORDER[@]}"; do
  a="${RECORDED[$path]}"
  proj_file="$PROJECT_CLAUDE/$path"
  repo_file="$(repo_source_for "$path")"

  if [ ! -f "$repo_file" ]; then
    echo "  SRC-GONE  $path  (source removed from repo; project copy left untouched)"
    n_missing_src=$((n_missing_src+1))
    continue
  fi
  c="$(hash_of "$repo_file")"

  if [ ! -f "$proj_file" ]; then
    echo "  MISSING   $path  (in manifest, absent in project -> re-add candidate)"
    TO_READD+=("$path")
    n_readd=$((n_readd+1))
    continue
  fi
  b="$(hash_of "$proj_file")"

  if [ "$b" = "$a" ] && [ "$c" = "$a" ]; then
    n_skip=$((n_skip+1))
  elif [ "$b" = "$a" ] && [ "$c" != "$a" ]; then
    echo "  UPDATE    $path  (repo moved, project untouched)"
    TO_UPDATE+=("$path")
    n_update=$((n_update+1))
  elif [ "$b" != "$a" ] && [ "$c" = "$a" ]; then
    echo "  KEEP      $path  (local override; repo unchanged -> left as-is)"
    n_keep=$((n_keep+1))
  else
    echo "  CONFLICT  $path  (BOTH project and repo changed -> REFUSED, untouched)"
    n_conflict=$((n_conflict+1))
  fi
done

echo
echo "  summary: $n_update update, $n_readd re-add, $n_keep override, $n_conflict conflict, $n_skip unchanged, $n_missing_src source-gone"

# ─── Apply (safe operations only) ─────────────────────────────────────────────
if [ "$APPLY" -eq 1 ] && { [ "${#TO_UPDATE[@]}" -gt 0 ] || [ "${#TO_READD[@]}" -gt 0 ]; }; then
  echo
  echo "  applying ${#TO_UPDATE[@]} update(s) + ${#TO_READD[@]} re-add(s)..."
  for path in "${TO_UPDATE[@]}" "${TO_READD[@]}"; do
    mkdir -p "$(dirname "$PROJECT_CLAUDE/$path")"
    cp "$(repo_source_for "$path")" "$PROJECT_CLAUDE/$path"
    RECORDED["$path"]="$(hash_of "$PROJECT_CLAUDE/$path")"
    echo "    wrote $path"
  done

  # Rewrite manifest: preserve comment header, emit deduped path<TAB>hash.
  tmp="$(mktemp)"
  grep '^#' "$MANIFEST" > "$tmp" || true
  echo "# Re-synced: $(date +%Y-%m-%d) from $REPO_PATH" >> "$tmp"
  for path in "${ORDER[@]}"; do
    printf '%s\t%s\n' "$path" "${RECORDED[$path]}" >> "$tmp"
  done
  mv "$tmp" "$MANIFEST"
  echo "  manifest refreshed (deduped; updated hashes for synced files)."
fi

if [ "$n_conflict" -gt 0 ]; then
  echo
  echo "  NOTE: $n_conflict conflict(s) were REFUSED. Resolve by hand: diff the repo"
  echo "        and project versions, decide which wins, then re-run."
fi
