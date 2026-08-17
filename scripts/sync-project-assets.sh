#!/usr/bin/env bash
#
# sync-project-assets.sh — refresh a project's workflow-sourced assets from the
# canonical agentic-engineering-workflow repo, WITHOUT silently clobbering local
# edits. Assets are not confined to .claude/: the mechanical control set lives at
# .github/workflows/ and the project root, because GitHub and eslint require
# those exact locations (manifest v3).
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

# Manifest v3 records column 1 relative to the PROJECT ROOT, not to .claude/,
# because the mechanical control set lives outside it (.github/workflows/,
# eslint.config.js) and v2 had no way to name those files.
PROJECT_ROOT="$PROJECT_PATH"

# ─── Preconditions ────────────────────────────────────────────────────────────
[ -d "$PROJECT_CLAUDE" ] || { echo "ERROR: no .claude/ in project: $PROJECT_CLAUDE" >&2; exit 1; }
[ -d "$REPO_CLAUDE" ]    || { echo "ERROR: no .claude/ in repo: $REPO_CLAUDE" >&2; exit 1; }
[ -f "$MANIFEST" ]       || { echo "ERROR: no manifest: $MANIFEST" >&2; exit 1; }

hash_of() { sha256sum "$1" | cut -d' ' -f1; }

# The shared definition of what the workflow propagates — the same one bootstrap
# installs from, so this tool cannot go blind to assets the installer knows about.
# shellcheck source=lib/asset-list.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/asset-list.sh"

# Resolve a manifest path to its repo source, read from the manifest's 3rd
# column (recorded at copy time by bootstrap). No hardcoded special-cases:
# an asset sourced outside .claude/ carries its own source path. If the
# source no longer exists in the repo, the caller's -f check reports SRC-GONE.
repo_source_for() {
  echo "$REPO_PATH/${SRC[$1]}"
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

# ─── Parse manifest (v2: path<TAB>hash<TAB>source), dedupe; last wins ─────────
# Guard: a pre-v2 2-column manifest must REFUSE, not be misread (its column 2
# hash would be mistaken for a source path). Old artifact + new reader -> stop.
declare -A RECORDED
declare -A SRC
ORDER=()

# v2 recorded column 1 relative to .claude/; v3 records it relative to the project
# root. Migrate v2 on read by prefixing `.claude/`, so an existing project keeps
# its provenance and its local overrides rather than having every entry silently
# resolve to a missing path — which would report the whole project as MISSING and
# re-add over the top of real overrides.
IS_V2=0
grep -q '^# Format: v2' "$MANIFEST" && IS_V2=1

while IFS=$'\t' read -r path hash src; do
  [ -z "${path:-}" ] && continue
  case "$path" in \#*) continue ;; esac
  [ -z "${hash:-}" ] && continue
  if [ -z "${src:-}" ]; then
    echo "ERROR: $MANIFEST is the old 2-column format (no source-path column)." >&2
    echo "       line '$path' has no 3rd column. This sync version requires v2." >&2
    echo "       Regenerate the manifest (3-column) before using this version." >&2
    exit 1
  fi
  [ "$IS_V2" -eq 1 ] && path=".claude/$path"
  if [ -z "${RECORDED[$path]+x}" ]; then ORDER+=("$path"); fi
  RECORDED["$path"]="$hash"
  SRC["$path"]="$src"
done < "$MANIFEST"

[ "$IS_V2" -eq 1 ] && echo "  NOTE: manifest is v2; paths migrated to project-root-relative for this run."

# ─── Fail closed on an entry-less manifest (issue #16) ────────────────────────
# A manifest with no data rows next to a NON-EMPTY .claude/ tree is not "nothing
# to sync" — it is the signature of a manifest that lost its entries. Every
# workflow asset then reads as an untracked project override, and the classify
# loop below (which iterates the manifest) prints a zero-everything summary that
# is indistinguishable from a healthy run. Exiting 0 there is a fail-OPEN drift
# detector: it reports a clean bill of health on a project it has stopped
# tracking. Standard 4 — fail closed.
if [ "${#ORDER[@]}" -eq 0 ]; then
  # Anything under .claude/ other than the manifest itself counts as content.
  claude_files="$(find "$PROJECT_CLAUDE" -type f ! -name '.asset-manifest' -print -quit 2>/dev/null || true)"
  if [ -n "$claude_files" ]; then
    echo "ERROR: $MANIFEST has no entries, but $PROJECT_CLAUDE is not empty." >&2
    echo "       Every workflow asset in this project is therefore untracked, and this" >&2
    echo "       tool cannot tell a real override from a lost entry. Refusing to report" >&2
    echo "       'in sync' on a project it is not tracking." >&2
    echo "       Fix: re-run bootstrap-project.sh against this project to rebuild the" >&2
    echo "       manifest from the union of repo assets and any surviving entries." >&2
    exit 1
  fi
  echo "  manifest has no entries and .claude/ is empty — nothing to sync."
fi

# ─── Classify ─────────────────────────────────────────────────────────────────
TO_UPDATE=()
TO_READD=()
n_skip=0 n_keep=0 n_conflict=0 n_update=0 n_missing_src=0 n_readd=0 n_unverified=0

# Sentinel written by bootstrap when an asset's provenance could not be determined
# (present, differing from the repo, absent from any prior manifest). Must match
# UNKNOWN_HASH in bootstrap-project.sh.
UNKNOWN_HASH='unknown'

for path in "${ORDER[@]}"; do
  a="${RECORDED[$path]}"
  proj_file="$PROJECT_ROOT/$path"
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

  # Unknown provenance is checked FIRST. An 'unknown' hash matches neither b nor c,
  # so it would otherwise fall through to CONFLICT — which is safe (nothing is
  # written) but states something we do not know: "BOTH project and repo changed."
  # We have no idea whether the project's copy was edited; that is the whole point
  # of the sentinel. Reporting a fabricated reason for a correct refusal is its own
  # defect, so it gets its own class and an honest message.
  if [ "$a" = "$UNKNOWN_HASH" ]; then
    echo "  UNVERIFIED $path  (provenance unknown -> REFUSED, untouched)"
    n_unverified=$((n_unverified+1))
    continue
  fi

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

# ─── ADD: repo assets this project has never tracked (issue #16) ──────────────
# The loop above iterates the MANIFEST, so it can only ever see assets the project
# already knows about. An asset added to the workflow after this project was
# bootstrapped is in neither the manifest nor the project, and was therefore
# reported as nothing at all — the reason jobs-radar silently has no import guard
# and no git secret guard while this tool called it healthy.
#
# The asset set comes from scripts/lib/asset-list.sh, the same definition bootstrap
# installs from, so the installer and the detector cannot disagree about what
# exists. A file already present on disk is NOT an ADD — it is untracked content of
# unknown provenance, which only bootstrap is allowed to adopt.
TO_ADD=()
n_add=0
while IFS=$'\t' read -r rel src _want_exec; do
  [[ -z "${rel:-}" ]] && continue
  [ -n "${RECORDED[$rel]+x}" ] && continue
  if [ -e "$PROJECT_ROOT/$rel" ]; then
    echo "  UNTRACKED $rel  (present but in no manifest -> re-run bootstrap to adopt it)"
    continue
  fi
  echo "  ADD       $rel  (in the workflow, never tracked here)"
  TO_ADD+=("$rel")
  SRC["$rel"]="${src#"$REPO_PATH"/}"
  n_add=$((n_add+1))
done < <(enumerate_workflow_assets "$REPO_PATH")

echo
echo "  summary: $n_update update, $n_add add, $n_readd re-add, $n_keep override, $n_conflict conflict, $n_unverified unverified, $n_skip unchanged, $n_missing_src source-gone"

# ─── Apply (safe operations only) ─────────────────────────────────────────────
if [ "$APPLY" -eq 1 ] && { [ "${#TO_UPDATE[@]}" -gt 0 ] || [ "${#TO_READD[@]}" -gt 0 ] || [ "${#TO_ADD[@]}" -gt 0 ]; }; then
  echo
  echo "  applying ${#TO_UPDATE[@]} update(s) + ${#TO_READD[@]} re-add(s) + ${#TO_ADD[@]} add(s)..."
  for path in "${TO_UPDATE[@]:-}" "${TO_READD[@]:-}" "${TO_ADD[@]:-}"; do
    [ -z "$path" ] && continue
    mkdir -p "$(dirname "$PROJECT_ROOT/$path")"
    cp "$(repo_source_for "$path")" "$PROJECT_ROOT/$path"
    # An added asset is new to the manifest, so it needs an ORDER slot as well as
    # a hash — without this it is written to disk and immediately forgotten again.
    if [ -z "${RECORDED[$path]+x}" ]; then ORDER+=("$path"); fi
    RECORDED["$path"]="$(hash_of "$PROJECT_ROOT/$path")"
    echo "    wrote $path"
  done

  # Rewrite manifest with a CANONICAL v3 header (no comment accretion):
  #   - carry forward the immutable "# Generated:" (project birth) if present
  #   - refresh "# Source:" to the repo's CURRENT commit (not the frozen one)
  #   - emit a single "# Re-synced:" line (replaces any prior; never accretes)
  #   - drop one-time/stale comments (migration provenance, old Source/Re-synced)
  gen_line="$(grep -m1 '^# Generated:' "$MANIFEST" || true)"
  repo_commit="$(git -C "$REPO_PATH" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  tmp="$(mktemp)"
  {
    echo "# Asset manifest — agentic-engineering-workflow"
    echo "# Workflow-sourced files copied at bootstrap, with content hashes."
    echo "# Listed = workflow-sourced/re-syncable. Not listed = project override."
    echo "# Stale if workflow repo's current sha256 for a path != the hash here."
    echo "# Format: v3, 3 tab-separated columns (col 1 = PROJECT-ROOT-relative,"
    echo "#          col 3 = repo-root-relative source path)."
    if [ -n "$gen_line" ]; then echo "$gen_line"; fi
    echo "# Source: agentic-engineering-workflow @ $repo_commit"
    echo "# Re-synced: $(date +%Y-%m-%d) from $REPO_PATH"
    echo "#"
    printf '# <path-relative-to-project-root>\t<sha256-at-copy-time>\t<source-path-relative-to-repo-root>\n'
    for path in "${ORDER[@]}"; do
      printf '%s\t%s\t%s\n' "$path" "${RECORDED[$path]}" "${SRC[$path]}"
    done
  } > "$tmp"
  mv "$tmp" "$MANIFEST"
  echo "  manifest refreshed (canonical v2 header; source @ $repo_commit; hashes updated)."
fi

if [ "$n_unverified" -gt 0 ]; then
  echo
  echo "  NOTE: $n_unverified entr(ies) have UNKNOWN provenance and were REFUSED. Each is a"
  echo "        file that predates manifest tracking: it may be a deliberate override or a"
  echo "        stale copy. Diff it against the repo, decide, then record the real hash (or"
  echo "        delete the file and re-run bootstrap to take the workflow's version)."
fi

if [ "$n_conflict" -gt 0 ]; then
  echo
  echo "  NOTE: $n_conflict conflict(s) were REFUSED. Resolve by hand: diff the repo"
  echo "        and project versions, decide which wins, then re-run."
fi
