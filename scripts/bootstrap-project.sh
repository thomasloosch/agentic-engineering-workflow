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

record_asset() {
  # $1 = absolute path to the copied file in the project (hashed)
  # $2 = path relative to .claude/ in the project   -> manifest column 1
  # $3 = absolute path to the SOURCE file in the workflow repo. Pass the same
  #      variable the cp used; column 3 is that path made repo-root-relative.
  #      Derived per-asset from the real source, so an asset sourced outside
  #      .claude/ (e.g. engineering-standards) is correct with no lookup.
  local h src
  h="$(sha256sum "$1" | awk '{print $1}')"
  src="${3#"$WORKFLOW_DIR"/}"   # repo-root-relative source path -> column 3
  printf '%s\t%s\t%s\n' "$2" "$h" "$src" >> "$MANIFEST"
}

init_manifest() {
  # Truncate-and-regenerate: only workflow-sourced entries live here, and each
  # bootstrap re-derives them, so regenerating from scratch is idempotent.
  {
    echo "# Asset manifest — agentic-engineering-workflow"
    echo "# Workflow-sourced files copied at bootstrap, with content hashes."
    echo "# Listed = workflow-sourced/re-syncable. Not listed = project override."
    echo "# Stale if workflow repo's current sha256 for a path != the hash here."
    echo "# Format: v2, 3 tab-separated columns (col 3 = repo-root-relative source path)."
    echo "# Generated: $(date -I)"
    echo "# Source: agentic-engineering-workflow @ $SOURCE_COMMIT"
    echo "#"
    printf '# <path-relative-to-.claude/>\t<sha256-at-copy-time>\t<source-path-relative-to-repo-root>\n'
  } > "$MANIFEST"
}

# ─── Step 1: Create .claude/ structure ────────────────────────────────────────

echo "[1/13] Creating .claude/ directory structure..."
mkdir -p "$PROJECT_PATH/.claude/"{agents,skills,commands,memory,logs,rules,tdd,hooks}
init_manifest
echo "       Done."

# ─── Step 2: Symlink agents ────────────────────────────────────────────────────

echo "[2/13] Copying agents..."
agent_copied=0
agent_overridden=0
for agent in "$WORKFLOW_DIR/.claude/agents/"*.md; do
  [[ -e "$agent" ]] || continue
  target="$PROJECT_PATH/.claude/agents/$(basename "$agent")"
  if [[ -e "$target" && ! -L "$target" ]]; then
    echo "       Preserving local override: $(basename "$agent")"
    agent_overridden=$((agent_overridden + 1))
  else
    rm -f "$target"   # clear a stale symlink from older (symlink-era) bootstraps
    cp "$agent" "$target"
    record_asset "$target" "agents/$(basename "$agent")" "$agent"
    agent_copied=$((agent_copied + 1))
  fi
done
echo "       Copied $agent_copied agents (${agent_overridden} local overrides preserved)."

# ─── Step 3: Symlink skills ────────────────────────────────────────────────────

echo "[3/13] Copying skills..."
skill_copied=0
skill_overridden=0
for skill_dir in "$WORKFLOW_DIR/.claude/skills/"*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name="$(basename "${skill_dir%/}")"
  target="$PROJECT_PATH/.claude/skills/$skill_name"
  if [[ -e "$target" && ! -L "$target" ]]; then
    echo "       Preserving local override: $skill_name"
    skill_overridden=$((skill_overridden + 1))
  else
    rm -rf "$target"   # clear a stale symlink (or prior copy) before refresh
    cp -r "${skill_dir%/}" "$target"
    while IFS= read -r -d '' f; do
      record_asset "$f" "skills/$skill_name/${f#"$target"/}" "${skill_dir%/}/${f#"$target"/}"
    done < <(find "$target" -type f -print0)
    skill_copied=$((skill_copied + 1))
  fi
done
echo "       Copied $skill_copied skills (${skill_overridden} local overrides preserved)."

# ─── Step 4: Symlink commands ─────────────────────────────────────────────────

echo "[4/13] Copying commands..."
cmd_copied=0
cmd_overridden=0
for cmd in "$WORKFLOW_DIR/.claude/commands/"*.md; do
  [[ -e "$cmd" ]] || continue
  target="$PROJECT_PATH/.claude/commands/$(basename "$cmd")"
  if [[ -e "$target" && ! -L "$target" ]]; then
    echo "       Preserving local override: $(basename "$cmd")"
    cmd_overridden=$((cmd_overridden + 1))
  else
    rm -f "$target"   # clear a stale symlink from older (symlink-era) bootstraps
    cp "$cmd" "$target"
    record_asset "$target" "commands/$(basename "$cmd")" "$cmd"
    cmd_copied=$((cmd_copied + 1))
  fi
done
echo "       Copied $cmd_copied commands (${cmd_overridden} local overrides preserved)."

# ─── Step 5: Symlink engineering-standards.md ─────────────────────────────────

echo "[5/13] Copying engineering-standards.md..."
SOURCE_STANDARDS="$WORKFLOW_DIR/docs/standards/engineering-standards.md"
TARGET_STANDARDS="$PROJECT_PATH/.claude/engineering-standards.md"
if [[ ! -f "$SOURCE_STANDARDS" ]]; then
  echo "       WARN: source not found at $SOURCE_STANDARDS — skipping."
elif [[ -e "$TARGET_STANDARDS" && ! -L "$TARGET_STANDARDS" ]]; then
  echo "       Preserving local override: engineering-standards.md"
else
  rm -f "$TARGET_STANDARDS"   # clear a stale symlink before copying through it
  cp "$SOURCE_STANDARDS" "$TARGET_STANDARDS"
  if [[ -f "$TARGET_STANDARDS" && ! -L "$TARGET_STANDARDS" ]]; then
    record_asset "$TARGET_STANDARDS" "engineering-standards.md" "$SOURCE_STANDARDS"
    echo "       Copied engineering-standards.md."
  else
    echo "       ERROR: copy not created or is unexpectedly a symlink."
    exit 1
  fi
fi

# ─── Step 6: Copy TDD gate (runtime + rotator hook) ───────────────────────────
# The gate RUNTIME (recorder + detector) is the relocatable code copied into each
# project; the gate's TEST files stay in the workflow repo and are NOT copied. The
# rotator hook resets the session log on SessionStart — it must be registered in
# the project's settings.json by hand (see the wiring snippets printed at the end).

echo "[6/13] Copying TDD gate..."
tdd_copied=0
tdd_overridden=0
for tdd_file in "$WORKFLOW_DIR/.claude/tdd/"*.js; do
  [[ -e "$tdd_file" ]] || continue
  case "$tdd_file" in *.test.js) continue ;; esac   # runtime only — tests stay in the repo
  target="$PROJECT_PATH/.claude/tdd/$(basename "$tdd_file")"
  if [[ -e "$target" && ! -L "$target" ]]; then
    echo "       Preserving local override: tdd/$(basename "$tdd_file")"
    tdd_overridden=$((tdd_overridden + 1))
  else
    rm -f "$target"   # clear a stale symlink from older bootstraps
    cp "$tdd_file" "$target"
    record_asset "$target" "tdd/$(basename "$tdd_file")" "$tdd_file"
    tdd_copied=$((tdd_copied + 1))
  fi
done

ROTATOR_SRC="$WORKFLOW_DIR/.claude/hooks/rotate-tdd-session-log.sh"
ROTATOR_DST="$PROJECT_PATH/.claude/hooks/rotate-tdd-session-log.sh"
if [[ ! -f "$ROTATOR_SRC" ]]; then
  echo "       WARN: rotator hook not found at $ROTATOR_SRC — skipping."
elif [[ -e "$ROTATOR_DST" && ! -L "$ROTATOR_DST" ]]; then
  echo "       Preserving local override: hooks/rotate-tdd-session-log.sh"
else
  rm -f "$ROTATOR_DST"   # clear a stale symlink before copying through it
  cp "$ROTATOR_SRC" "$ROTATOR_DST"
  chmod +x "$ROTATOR_DST"   # hook is executed by Claude Code on SessionStart
  record_asset "$ROTATOR_DST" "hooks/rotate-tdd-session-log.sh" "$ROTATOR_SRC"
  tdd_copied=$((tdd_copied + 1))
fi
echo "       Copied $tdd_copied TDD gate file(s) (${tdd_overridden} local overrides preserved)."

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

echo ""
echo "Bootstrap complete for: $PROJECT_NAME"

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
echo "    file already exists; it resets .claude/logs/tdd-session.log each session):"
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
echo "  4. Type /start-session"
