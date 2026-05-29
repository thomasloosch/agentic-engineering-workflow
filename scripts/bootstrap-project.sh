#!/usr/bin/env bash

# bootstrap-project.sh
# Sets up a new project to use the agentic-engineering-workflow.
#
# Usage:
#   ./scripts/bootstrap-project.sh /path/to/project "Project Name"
#
# What it does:
#   - Creates .claude/ subdirectory structure in the target project
#   - Symlinks agents, skills, commands, and engineering-standards from the workflow repo
#     (preserves project-local overrides if a non-symlink file already exists at the target)
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

# ─── Step 1: Create .claude/ structure ────────────────────────────────────────

echo "[1/12] Creating .claude/ directory structure..."
mkdir -p "$PROJECT_PATH/.claude/"{agents,skills,commands,memory,logs,rules}
echo "       Done."

# ─── Step 2: Symlink agents ────────────────────────────────────────────────────

echo "[2/12] Symlinking agents..."
agent_linked=0
agent_overridden=0
for agent in "$WORKFLOW_DIR/.claude/agents/"*.md; do
  [[ -e "$agent" ]] || continue
  target="$PROJECT_PATH/.claude/agents/$(basename "$agent")"
  if [[ -e "$target" && ! -L "$target" ]]; then
    echo "       Preserving local override: $(basename "$agent")"
    agent_overridden=$((agent_overridden + 1))
  else
    ln -sfn "$agent" "$target"
    agent_linked=$((agent_linked + 1))
  fi
done
echo "       Symlinked $agent_linked agents (${agent_overridden} local overrides preserved)."

# ─── Step 3: Symlink skills ────────────────────────────────────────────────────

echo "[3/12] Symlinking skills..."
skill_linked=0
skill_overridden=0
for skill_dir in "$WORKFLOW_DIR/.claude/skills/"*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name="$(basename "${skill_dir%/}")"
  target="$PROJECT_PATH/.claude/skills/$skill_name"
  if [[ -e "$target" && ! -L "$target" ]]; then
    echo "       Preserving local override: $skill_name"
    skill_overridden=$((skill_overridden + 1))
  else
    ln -sfn "${skill_dir%/}" "$target"
    skill_linked=$((skill_linked + 1))
  fi
done
echo "       Symlinked $skill_linked skills (${skill_overridden} local overrides preserved)."

# ─── Step 4: Symlink commands ─────────────────────────────────────────────────

echo "[4/12] Symlinking commands..."
cmd_linked=0
cmd_overridden=0
for cmd in "$WORKFLOW_DIR/.claude/commands/"*.md; do
  [[ -e "$cmd" ]] || continue
  target="$PROJECT_PATH/.claude/commands/$(basename "$cmd")"
  if [[ -e "$target" && ! -L "$target" ]]; then
    echo "       Preserving local override: $(basename "$cmd")"
    cmd_overridden=$((cmd_overridden + 1))
  else
    ln -sfn "$cmd" "$target"
    cmd_linked=$((cmd_linked + 1))
  fi
done
echo "       Symlinked $cmd_linked commands (${cmd_overridden} local overrides preserved)."

# ─── Step 5: Symlink engineering-standards.md ─────────────────────────────────

echo "[5/12] Symlinking engineering-standards.md..."
SOURCE_STANDARDS="$WORKFLOW_DIR/docs/standards/engineering-standards.md"
TARGET_STANDARDS="$PROJECT_PATH/.claude/engineering-standards.md"
if [[ ! -f "$SOURCE_STANDARDS" ]]; then
  echo "       WARN: source not found at $SOURCE_STANDARDS — skipping."
elif [[ -e "$TARGET_STANDARDS" && ! -L "$TARGET_STANDARDS" ]]; then
  echo "       Preserving local override: engineering-standards.md"
else
  ln -sfn "$SOURCE_STANDARDS" "$TARGET_STANDARDS"
  if [[ -L "$TARGET_STANDARDS" && -e "$TARGET_STANDARDS" ]]; then
    echo "       Symlinked engineering-standards.md."
  else
    echo "       ERROR: symlink not created or doesn't resolve."
    exit 1
  fi
fi

# ─── Step 6: Scaffold .claude/rules/ ──────────────────────────────────────────

echo "[6/12] Scaffolding .claude/rules/..."
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

# ─── Step 7: Create CLAUDE.md from template ───────────────────────────────────

echo "[7/12] Checking CLAUDE.md..."
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

# ─── Step 8: Create CLAUDE.local.md ───────────────────────────────────────────

echo "[8/12] Checking CLAUDE.local.md..."
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

# ─── Step 9: Handle .gitignore ────────────────────────────────────────────────

echo "[9/12] Checking .gitignore..."
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

# ─── Step 10: Ensure .claude/logs/.gitkeep ────────────────────────────────────

echo "[10/12] Ensuring .claude/logs/.gitkeep..."
if [[ ! -f "$PROJECT_PATH/.claude/logs/.gitkeep" ]]; then
  touch "$PROJECT_PATH/.claude/logs/.gitkeep"
  echo "        Created .claude/logs/.gitkeep (preserves directory across clones)."
else
  echo "        .claude/logs/.gitkeep already exists — skipping."
fi

# ─── Step 11: Initialise current-state.md ─────────────────────────────────────

echo "[11/12] Checking current-state.md..."
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

# ─── Step 12: PR template ─────────────────────────────────────────────────────

echo "[12/12] Checking PR template..."
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
echo ""
echo "Next steps:"
echo "  1. Customise $PROJECT_PATH/CLAUDE.md for this project"
echo "  2. Edit CLAUDE.local.md with any sprint-specific notes (gitignored)"
echo "  3. cd $PROJECT_PATH && claude"
echo "  4. Type /start-session"
