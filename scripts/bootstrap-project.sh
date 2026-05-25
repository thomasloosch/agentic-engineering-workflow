#!/usr/bin/env bash

# bootstrap-project.sh
# Sets up a new project to use the agentic-engineering-workflow.
#
# Usage:
#   ./scripts/bootstrap-project.sh /path/to/project "Project Name"
#
# What it does:
#   - Creates .claude/ subdirectory structure in the target project
#   - Symlinks agents, skills, and commands from the workflow repo
#   - Creates a CLAUDE.md from template if one doesn't exist
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

echo "[1/6] Creating .claude/ directory structure..."
mkdir -p "$PROJECT_PATH/.claude/"{agents,skills,commands,memory,logs}
echo "      Done."

# ─── Step 2: Symlink agents ────────────────────────────────────────────────────

echo "[2/6] Symlinking agents..."
for agent in "$WORKFLOW_DIR/.claude/agents/"*.md; do
  target="$PROJECT_PATH/.claude/agents/$(basename "$agent")"
  ln -sf "$agent" "$target"
done
agent_count=$(ls "$PROJECT_PATH/.claude/agents/" | wc -l)
echo "      Symlinked $agent_count agents."

# ─── Step 3: Symlink skills ────────────────────────────────────────────────────

echo "[3/6] Symlinking skills..."
for skill_dir in "$WORKFLOW_DIR/.claude/skills/"/*/; do
  target="$PROJECT_PATH/.claude/skills/$(basename "$skill_dir")"
  ln -sf "$skill_dir" "$target"
done
skill_count=$(ls "$PROJECT_PATH/.claude/skills/" | wc -l)
echo "      Symlinked $skill_count skills."

# ─── Step 4: Symlink commands ─────────────────────────────────────────────────

echo "[4/6] Symlinking commands..."
for cmd in "$WORKFLOW_DIR/.claude/commands/"*.md; do
  target="$PROJECT_PATH/.claude/commands/$(basename "$cmd")"
  ln -sf "$cmd" "$target"
done
cmd_count=$(ls "$PROJECT_PATH/.claude/commands/" | wc -l)
echo "      Symlinked $cmd_count commands."

# ─── Step 5: Create CLAUDE.md from template ───────────────────────────────────

echo "[5/6] Checking CLAUDE.md..."
if [[ ! -f "$PROJECT_PATH/CLAUDE.md" ]]; then
  cp "$WORKFLOW_DIR/templates/CLAUDE.md.template" "$PROJECT_PATH/CLAUDE.md"
  sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$PROJECT_PATH/CLAUDE.md"
  echo "      Created CLAUDE.md from template. Customise it for your project."
else
  echo "      CLAUDE.md already exists — skipping (not overwriting)."
fi

# ─── Step 6: Initialise current-state.md ─────────────────────────────────────

echo "[6/6] Checking current-state.md..."
if [[ ! -f "$PROJECT_PATH/.claude/memory/current-state.md" ]]; then
  cat > "$PROJECT_PATH/.claude/memory/current-state.md" << STATEOF
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
STATEOF
  echo "      Created current-state.md."
else
  echo "      current-state.md already exists — skipping (not overwriting)."
fi

# ─── Step 7: PR template ──────────────────────────────────────────────────────

if [[ ! -f "$PROJECT_PATH/.github/pull_request_template.md" ]]; then
  mkdir -p "$PROJECT_PATH/.github"
  cp "$WORKFLOW_DIR/.github/pull_request_template.md" \
     "$PROJECT_PATH/.github/pull_request_template.md" 2>/dev/null || true
fi

# ─── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo "Bootstrap complete for: $PROJECT_NAME"
echo ""
echo "Next steps:"
echo "  1. Customise $PROJECT_PATH/CLAUDE.md for this project"
echo "  2. cd $PROJECT_PATH && claude"
echo "  3. Type /start-session"

