#!/usr/bin/env bash

# bootstrap-project.sh
# Sets up a new project to use the agentic-engineering-workflow.
#
# Usage:
#   ./scripts/bootstrap-project.sh /path/to/project "Project Name"
#
# What it does:
#   - Creates .claude/ subdirectory structure in the target project
#   - Copies agents, skills, commands, and engineering-standards from the workflow repo
#     (preserves project-local overrides if a non-symlink file already exists at the target)
#   - Copies the TDD gate runtime (tdd-recorder.js, tdd-detector.js) into .claude/tdd/
#     and the rotator hook into .claude/hooks/ (test files stay in the workflow repo)
#   - Records a content-hash manifest (.claude/.asset-manifest) of every copied file,
#     so staleness against the workflow repo is always detectable (see Piece 2 re-sync)
#   - Scaffolds .claude/rules/ for path-scoped rules
#   - Creates CLAUDE.md from template if one doesn't exist
#   - Creates CLAUDE.local.md template (ephemeral, gitignored)
#   - Creates or appends to .gitignore for bootstrap-required entries
#   - Adds .claude/logs/.gitkeep so the directory survives a fresh clone
#   - Initialises .claude/memory/current-state.md if it doesn't exist
#   - Copies the PR template to .github/ if it doesn't exist

set -euo pipefail

# ─── Arguments ────────────────────────────────────────────────────────────────

PROJECT_PATH="${1:-}"
PROJECT_NAME="${2:-}"

if [[ -z "$PROJECT_PATH" || -z "$PROJECT_NAME" ]]; then
  echo "Usage: $0 /path/to/project 'Project Name'"
  echo ""
  echo "Example:"
  echo "  $0 ~/projects/jobs-radar 'Jobs Radar'"
  exit 1
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Error: Project directory does not exist: $PROJECT_PATH"
  echo "Create the directory first, then run this script."
  exit 1
fi

WORKFLOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The shared definition of what gets propagated (see the file's header for why it
# is extracted rather than duplicated into this script and the sync script).
# shellcheck source=lib/asset-list.sh
source "$WORKFLOW_DIR/scripts/lib/asset-list.sh"
echo "Workflow repo: $WORKFLOW_DIR"
echo "Target project: $PROJECT_PATH"
echo "Project name: $PROJECT_NAME"
echo ""

# ─── Asset manifest setup ─────────────────────────────────────────────────────
# Records every workflow-sourced file copied into the project, with the SHA256 it
# had at copy time. A file listed here is workflow-sourced and re-syncable; a file
# NOT listed is a project-local override and must never be auto-overwritten.
# Staleness = workflow repo's CURRENT sha256 for a path != the hash recorded here.

MANIFEST="$PROJECT_PATH/.claude/.asset-manifest"
SOURCE_COMMIT="$(git -C "$WORKFLOW_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"

# Sentinel for column 2 when this script CANNOT know an asset's provenance: the
# file is on disk, differs from the repo's copy, and no prior manifest entry says
# where it came from. "The owner edited it" and "an old copy from a pre-manifest
# bootstrap" are indistinguishable from here, so we record the uncertainty rather
# than guessing. sync must refuse to auto-resolve these (issue #16).
UNKNOWN_HASH='unknown'

hash_of() { sha256sum "$1" | awk '{print $1}'; }

# ── Provenance model (issue #16) ──────────────────────────────────────────────
# The MANIFEST — not the file's presence on disk — decides whether an asset is
# workflow-sourced. The old code asked `[[ -e target && ! -L target ]]` as though
# it meant "the owner edited this", when it actually means "this exists", which is
# true of everything the PREVIOUS run copied. Combined with truncate-at-start,
# a second bootstrap recorded nothing and the manifest came back EMPTY — silently
# reclassifying every workflow asset as a local override and making the project
# invisible to sync-project-assets.sh, which then reported it perfectly in sync.
#
# Per asset:  a = hash in the prior manifest · b = project's current file · c = repo source
#
#   unlisted, absent          -> copy, record c                (new asset / ADD)
#   unlisted, present, b == c -> leave, record c                (identical; safe to adopt)
#   unlisted, present, b != c -> LEAVE, record UNKNOWN_HASH     (provenance unknowable)
#   listed,   b == a          -> refresh from repo, record new  (untouched since copy)
#   listed,   b != a          -> LEAVE, record **a**            (real override — see below)
#   listed,   absent          -> re-copy, record new
#   listed,   source gone     -> leave, carry the entry forward
#
# The override row is the one that matters. Re-recording it at the CURRENT hash
# would be worse than dropping it: sync's three-hash logic would then read
# b == a && c != a as "repo moved, project untouched -> safe to refresh" and
# overwrite the owner's edit on the next run. Preserving the ORIGINAL recorded
# hash is what keeps that classification honest.
#
# The manifest is regenerated from the UNION of (repo assets) and (prior entries),
# never from "whatever this run happened to copy".

declare -A PRIOR_HASH PRIOR_SRC NEW_HASH NEW_SRC
PRIOR_ORDER=()
NEW_ORDER=()
n_placed=0; n_refreshed=0; n_override=0; n_adopted=0; n_unknown=0; n_carried=0

load_prior_manifest() {
  [[ -f "$MANIFEST" ]] || return 0
  local path hash src
  while IFS=$'\t' read -r path hash src; do
    [[ -z "${path:-}" ]] && continue
    case "$path" in \#*) continue ;; esac
    [[ -z "${hash:-}" ]] && continue
    # A pre-v2 (2-column) row carries no source path. Ignore it rather than
    # misreading column 2 as a source: the asset will be re-derived below.
    [[ -z "${src:-}" ]] && continue
    if [[ -z "${PRIOR_HASH[$path]+x}" ]]; then PRIOR_ORDER+=("$path"); fi
    PRIOR_HASH["$path"]="$hash"
    PRIOR_SRC["$path"]="$src"
  done < "$MANIFEST"
}

record_entry() {  # record_entry <rel-path> <hash> <repo-relative-source>
  if [[ -z "${NEW_HASH[$1]+x}" ]]; then NEW_ORDER+=("$1"); fi
  NEW_HASH["$1"]="$2"
  NEW_SRC["$1"]="$3"
}

place_asset() {
  # place_asset <absolute-source-in-workflow-repo> <path-relative-to-.claude/> [exec]
  local src="$1" rel="$2" want_exec="${3:-}"
  local target="$PROJECT_PATH/.claude/$rel"
  local srcrel="${src#"$WORKFLOW_DIR"/}"
  local a b c

  if [[ ! -f "$src" ]]; then
    echo "       WARN: source not found — skipping: $srcrel"
    return 0
  fi
  c="$(hash_of "$src")"
  mkdir -p "$(dirname "$target")"

  install_it() {
    cp "$src" "$target"
    [[ -n "$want_exec" ]] && chmod +x "$target"
    return 0
  }

  # A leftover symlink from the symlink-era bootstraps carries no provenance and
  # cannot be hashed meaningfully — replace it and treat the result as fresh.
  if [[ -L "$target" || ! -e "$target" ]]; then
    rm -f "$target"
    install_it
    record_entry "$rel" "$c" "$srcrel"
    n_placed=$((n_placed + 1))
    return 0
  fi

  b="$(hash_of "$target")"

  if [[ -n "${PRIOR_HASH[$rel]+x}" ]]; then
    a="${PRIOR_HASH[$rel]}"
    if [[ "$b" == "$a" ]]; then
      install_it
      record_entry "$rel" "$c" "$srcrel"
      n_refreshed=$((n_refreshed + 1))
    else
      record_entry "$rel" "$a" "$srcrel"   # ORIGINAL hash — see the note above
      n_override=$((n_override + 1))
      echo "       Preserving local override: $rel"
    fi
  elif [[ "$b" == "$c" ]]; then
    record_entry "$rel" "$c" "$srcrel"
    n_adopted=$((n_adopted + 1))
  else
    record_entry "$rel" "$UNKNOWN_HASH" "$srcrel"
    n_unknown=$((n_unknown + 1))
    echo "       UNKNOWN PROVENANCE — left untouched, sync will refuse it: $rel"
  fi
}

write_manifest() {
  # Written ONCE, at the end, from the union of what we placed and what the prior
  # manifest knew. Never truncated up front — that is what made a re-run lossy.
  local path
  for path in "${PRIOR_ORDER[@]:-}"; do
    [[ -z "$path" ]] && continue
    [[ -n "${NEW_HASH[$path]+x}" ]] && continue
    record_entry "$path" "${PRIOR_HASH[$path]}" "${PRIOR_SRC[$path]}"
    n_carried=$((n_carried + 1))
  done

  {
    echo "# Asset manifest — agentic-engineering-workflow"
    echo "# Workflow-sourced files copied at bootstrap, with content hashes."
    echo "# Listed = workflow-sourced/re-syncable. Not listed = project override."
    echo "# Stale if workflow repo's current sha256 for a path != the hash here."
    echo "# Format: v2, 3 tab-separated columns (col 3 = repo-root-relative source path)."
    echo "# A hash of '$UNKNOWN_HASH' means provenance could not be determined —"
    echo "# resolve by hand; sync will not auto-update those entries."
    echo "# Generated: $(date -I)"
    echo "# Source: agentic-engineering-workflow @ $SOURCE_COMMIT"
    echo "#"
    printf '# <path-relative-to-.claude/>\t<sha256-at-copy-time>\t<source-path-relative-to-repo-root>\n'
    for path in "${NEW_ORDER[@]:-}"; do
      [[ -z "$path" ]] && continue
      printf '%s\t%s\t%s\n' "$path" "${NEW_HASH[$path]}" "${NEW_SRC[$path]}"
    done
  } > "$MANIFEST"
}

# ─── Step 1: Create .claude/ structure ────────────────────────────────────────

echo "[1/13] Creating .claude/ directory structure..."
mkdir -p "$PROJECT_PATH/.claude/"{agents,skills,commands,memory,logs,rules,tdd,hooks}
load_prior_manifest   # read BEFORE anything is written; manifest is rewritten at the end
echo "       Done."

# ─── Steps 2-6: Place every workflow asset ────────────────────────────────────
# One table-driven loop over scripts/lib/asset-list.sh, which is the single
# definition of what gets propagated and is shared with sync-project-assets.sh so
# the installer and the drift detector cannot disagree about the asset set.
# Adding a propagated asset means adding a row there, not editing this loop.
#
# What the assets are: the skills/commands/agents context layer; the @-imported
# engineering-standards doc; the TDD gate RUNTIME (its own tests stay in the
# workflow repo); the SessionStart rotator hook (a no-op except on an explicit
# --new-slice run, so resuming mid-slice never wipes records); the git-native
# secret-scan pre-commit guard, which genuinely BLOCKS unlike the advisory Claude
# Code lifecycle hooks in the MINGW desktop runtime (ADR-0002) — CI gitleaks
# remains the non-bypassable authority; and the hallucinated-dependency import
# guard, which detects its ecosystem at runtime and skips LOUDLY when it has no
# adapter so a propagated guard never becomes a silent pass.

echo "[2-6/13] Placing workflow assets..."
while IFS=$'\t' read -r rel src want_exec; do
  [[ -z "${rel:-}" ]] && continue
  place_asset "$src" "$rel" "${want_exec:-}"
done < <(enumerate_workflow_assets "$WORKFLOW_DIR")
echo "       Done."

# The guard FILE is placed by the loop above; what remains here is the WIRING,
# which is not a file copy and so has no manifest entry. Without core.hooksPath
# the guard sits on disk and never runs — present but inert, the ADR-0002
# false-confidence trap.
if [[ -f "$PROJECT_PATH/.claude/git-hooks/pre-commit" ]]; then
  # Wire core.hooksPath, but never clobber a project's existing custom value.
  if git -C "$PROJECT_PATH" rev-parse --git-dir >/dev/null 2>&1; then
    existing="$(git -C "$PROJECT_PATH" config --local --get core.hooksPath 2>/dev/null || true)"
    if [[ -z "$existing" || "$existing" == ".claude/git-hooks" ]]; then
      git -C "$PROJECT_PATH" config --local core.hooksPath .claude/git-hooks
      echo "       Wired secret-scan guard (core.hooksPath=.claude/git-hooks)."
    else
      echo "       NOTE: core.hooksPath already set to '$existing' — left as-is."
      echo "             Install the guard there manually, or unset to use .claude/git-hooks."
    fi
  else
    echo "       NOTE: project is not a git repo — guard copied but not wired."
    echo "             Run: git -C '$PROJECT_PATH' config core.hooksPath .claude/git-hooks"
  fi
fi

# ─── Step 7: Scaffold .claude/rules/ ──────────────────────────────────────────

echo "[7/13] Scaffolding .claude/rules/..."
if [[ ! -f "$PROJECT_PATH/.claude/rules/README.md" ]]; then
  cat > "$PROJECT_PATH/.claude/rules/README.md" << 'RULESEOF'
# Path-scoped rules

Rules that apply only to files matching specific paths. Claude Code loads
these automatically when the working file matches a rule's `paths:` glob.

This is the official Anthropic mechanism for scoping rules narrower than
project-wide `CLAUDE.md`. Use it for things like backend-only conventions,
frontend-only patterns, or migration-file standards — rules that would
mis-apply if put in the top-level `CLAUDE.md`.

## When to add a new rule file

- The rule genuinely applies to a subset of files (matched by glob)
- A project-wide rule in `CLAUDE.md` would be too broad
- The rule is stable enough to commit (otherwise use `CLAUDE.local.md`)

**Do not pre-create empty rule files.** Add them when you have a real rule.

## Working syntax

```markdown
---
paths:
  - "src/api/**"
  - "src/routes/**"
---

# API rules

- All responses use the `{success, data, error}` envelope.
- Errors include a stable `code` string field.
```

Globs must be quoted strings. YAML list form is what works reliably.

## Known upstream issues (as of 2026-01)

- Glob patterns starting with `{` or `*` need quoting (anthropics/claude-code#13905)
- `paths:` may load globally instead of being scoped on macOS (#16299)
- User-level `~/.claude/rules/` may ignore `paths:` on Windows (#21858)

If a rule isn't loading or is loading when it shouldn't: run `/memory` in
a Claude Code session to see what was actually loaded.

Authoritative docs: https://code.claude.com/docs/en/memory
RULESEOF
  echo "       Created .claude/rules/README.md."
else
  echo "       .claude/rules/README.md already exists — skipping."
fi

# ─── Step 8: Create CLAUDE.md from template ───────────────────────────────────

echo "[8/13] Checking CLAUDE.md..."
if [[ ! -f "$PROJECT_PATH/CLAUDE.md" ]]; then
  if [[ ! -f "$WORKFLOW_DIR/templates/CLAUDE.md.template" ]]; then
    echo "       WARN: template not found at $WORKFLOW_DIR/templates/CLAUDE.md.template — skipping."
  else
    cp "$WORKFLOW_DIR/templates/CLAUDE.md.template" "$PROJECT_PATH/CLAUDE.md"
    sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$PROJECT_PATH/CLAUDE.md"
    echo "       Created CLAUDE.md from template. Customise it for your project."
  fi
else
  echo "       CLAUDE.md already exists — skipping (not overwriting)."
fi

# ─── Step 9: Create CLAUDE.local.md ───────────────────────────────────────────

echo "[9/13] Checking CLAUDE.local.md..."
if [[ ! -f "$PROJECT_PATH/CLAUDE.local.md" ]]; then
  cat > "$PROJECT_PATH/CLAUDE.local.md" << LOCALEOF
# Personal Notes — $PROJECT_NAME

Ephemeral, gitignored. Never committed. Delete items as they stop being relevant.

## Currently avoiding

- (e.g. "no refactors this week, shipping pre-beta")

## Local quirks

- (e.g. "my dev DB is paused — don't suggest migrations")

## Reminders to self

-
LOCALEOF
  echo "       Created CLAUDE.local.md."
else
  echo "       CLAUDE.local.md already exists — skipping (not overwriting)."
fi

# ─── Step 10: Handle .gitignore ────────────────────────────────────────────────

echo "[10/13] Checking .gitignore..."
REQUIRED_IGNORES=(
  "CLAUDE.local.md"
  ".claude/logs/*"
  "!.claude/logs/.gitkeep"
)

if [[ ! -f "$PROJECT_PATH/.gitignore" ]]; then
  cat > "$PROJECT_PATH/.gitignore" << 'GITEOF'
# Claude
CLAUDE.local.md
.claude/logs/*
!.claude/logs/.gitkeep

# Node
node_modules/

# Env
.env
.env.local

# OS
.DS_Store
GITEOF
  echo "       Created .gitignore."
else
  appended_any=false
  for ignore in "${REQUIRED_IGNORES[@]}"; do
    if ! grep -qxF "$ignore" "$PROJECT_PATH/.gitignore"; then
      if ! $appended_any; then
        printf '\n# Added by agentic-engineering-workflow bootstrap\n' >> "$PROJECT_PATH/.gitignore"
        appended_any=true
      fi
      echo "$ignore" >> "$PROJECT_PATH/.gitignore"
    fi
  done
  if $appended_any; then
    echo "       Appended bootstrap-required entries to existing .gitignore."
  else
    echo "       .gitignore already has required entries — skipping."
  fi
fi

# ─── Step 11: Ensure .claude/logs/.gitkeep ────────────────────────────────────

echo "[11/13] Ensuring .claude/logs/.gitkeep..."
if [[ ! -f "$PROJECT_PATH/.claude/logs/.gitkeep" ]]; then
  touch "$PROJECT_PATH/.claude/logs/.gitkeep"
  echo "        Created .claude/logs/.gitkeep (preserves directory across clones)."
else
  echo "        .claude/logs/.gitkeep already exists — skipping."
fi

# ─── Step 12: Initialise current-state.md ─────────────────────────────────────

echo "[12/13] Checking current-state.md..."
if [[ ! -f "$PROJECT_PATH/.claude/memory/current-state.md" ]]; then
  cat > "$PROJECT_PATH/.claude/memory/current-state.md" << STATEEOF
# Current State — $PROJECT_NAME

_Last updated: $(date -I) — bootstrapped_

## Open work

Nothing yet — first task incoming.

## Open TODOs

Nothing yet.

## Recent decisions

Nothing yet.

## RED-severity blockers

None.
STATEEOF
  echo "        Created current-state.md."
else
  echo "        current-state.md already exists — skipping (not overwriting)."
fi

# ─── Step 13: PR template ─────────────────────────────────────────────────────

echo "[13/13] Checking PR template..."
PR_TEMPLATE_SRC="$WORKFLOW_DIR/.github/pull_request_template.md"
PR_TEMPLATE_DST="$PROJECT_PATH/.github/pull_request_template.md"
if [[ -f "$PR_TEMPLATE_DST" ]]; then
  echo "        .github/pull_request_template.md already exists — skipping."
elif [[ ! -f "$PR_TEMPLATE_SRC" ]]; then
  echo "        WARN: PR template not found at $PR_TEMPLATE_SRC — skipping."
else
  mkdir -p "$PROJECT_PATH/.github"
  cp "$PR_TEMPLATE_SRC" "$PR_TEMPLATE_DST"
  echo "        Copied PR template."
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

write_manifest

echo ""
echo "Bootstrap complete for: $PROJECT_NAME"
echo "  manifest: $((${#NEW_ORDER[@]})) entries — ${n_placed} placed, ${n_refreshed} refreshed," \
     "${n_override} local override(s) kept, ${n_adopted} adopted, ${n_unknown} unknown-provenance," \
     "${n_carried} carried forward"
if [[ "$n_unknown" -gt 0 ]]; then
  echo ""
  echo "  ⚠ $n_unknown file(s) have UNKNOWN provenance: present, differing from the repo,"
  echo "    and absent from any prior manifest. They were left untouched and recorded as"
  echo "    '$UNKNOWN_HASH'. sync-project-assets.sh will refuse to auto-update them until a"
  echo "    human decides whether each is a deliberate override or a stale pre-manifest copy."
fi

# ─── Manual wiring (Option C: print, don't edit) ──────────────────────────────
# The gate files are now in place, but two files this script must NOT rewrite
# (package.json, .claude/settings.json) need the project owner to wire them up.
# We print the exact snippets rather than editing, so existing scripts/hooks are
# never clobbered. Paths assume the bootstrapped location (.claude/tdd/).

echo ""
echo "─────────────────────────────────────────────────────────────────────────────"
echo " TDD GATE — MANUAL WIRING REQUIRED (two snippets to add by hand)"
echo "─────────────────────────────────────────────────────────────────────────────"
echo ""
echo " 1) package.json — register the recorder as a --test-reporter on BOTH scripts."
echo "    Only 'tdd' records (cross-env sets TDD_RECORD=1); plain 'test' stays quiet:"
echo ""
cat << 'WIRINGEOF'
      "scripts": {
        "test": "node --test --test-reporter=spec --test-reporter-destination=stdout --test-reporter=./.claude/tdd/tdd-recorder.js --test-reporter-destination=stdout",
        "tdd": "cross-env TDD_RECORD=1 node --test --test-reporter=spec --test-reporter-destination=stdout --test-reporter=./.claude/tdd/tdd-recorder.js --test-reporter-destination=stdout"
      }
WIRINGEOF
echo ""
echo "    cross-env is required (Windows-safe env var):  npm install --save-dev cross-env"
echo ""
echo " 2) .claude/settings.json — register the rotator on SessionStart (merge if the"
echo "    file already exists). On SessionStart the hook is a no-op; it rotates"
echo "    .claude/logs/tdd-session.log only when the /tdd executor runs it explicitly"
echo "    as 'rotate-tdd-session-log.sh --new-slice' at slice start:"
echo ""
cat << 'WIRINGEOF'
      {
        "hooks": {
          "SessionStart": [
            {
              "hooks": [
                {
                  "type": "command",
                  "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/rotate-tdd-session-log.sh"
                }
              ]
            }
          ]
        }
      }
WIRINGEOF
echo "─────────────────────────────────────────────────────────────────────────────"

echo ""
echo "Next steps:"
echo "  1. Customise $PROJECT_PATH/CLAUDE.md for this project"
echo "  2. Edit CLAUDE.local.md with any sprint-specific notes (gitignored)"
echo "  3. cd $PROJECT_PATH && claude"
echo "  4. Read .claude/memory/current-state.md to orient"
