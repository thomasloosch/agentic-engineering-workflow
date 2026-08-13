#!/usr/bin/env bash
#
# asset-list.sh — the single definition of WHAT the workflow propagates.
#
# Sourced by both bootstrap-project.sh (which places these assets) and
# sync-project-assets.sh (which reports repo assets a project is not tracking —
# the ADD class). Those two must agree on the asset set or the drift detector
# goes blind to exactly the files the installer added, which is the failure this
# whole issue (#16) is about: jobs-radar never received the import guard or the
# git secret guard, and sync could not say so because it only ever looked at the
# project's own manifest.
#
# Rule 7 says do not extract for two call sites. This is a deliberate exception
# and the reason is not brevity: it is single-source-of-truth for a definition
# whose two copies would silently diverge. Duplicating it here would reproduce
# the #6 drift problem inside the fix for #16.
#
# Adding a propagated asset means adding a row to enumerate_workflow_assets and
# nothing else — both consumers pick it up. (#17 extends this list.)

# enumerate_workflow_assets <repo-root>
#
# Emits one tab-separated row per asset:
#   <path-relative-to-project-.claude/>  <absolute-source-path>  <exec|"">
#
# Emits nothing for a source that does not exist, so an asset removed from the
# repo simply stops being offered; the consumers decide what that means (bootstrap
# carries the old manifest entry forward, sync reports SRC-GONE).
enumerate_workflow_assets() {
  local repo="$1"
  local f skill_dir skill_name base

  # Agent definitions. The layer is retired (ADR-0003) and the directory is
  # currently absent; the loop is kept so a project that still carries one is
  # tracked rather than silently untracked.
  for f in "$repo/.claude/agents/"*.md; do
    [[ -f "$f" ]] || continue
    printf '%s\t%s\t\n' "agents/$(basename "$f")" "$f"
  done

  # Skills, per FILE. Directory granularity would freeze every file in a skill the
  # moment one of them was overridden.
  for skill_dir in "$repo/.claude/skills/"*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "${skill_dir%/}")"
    while IFS= read -r -d '' f; do
      printf '%s\t%s\t\n' "skills/$skill_name/${f#"${skill_dir%/}"/}" "$f"
    done < <(find "${skill_dir%/}" -type f -print0 | sort -z)
  done

  for f in "$repo/.claude/commands/"*.md; do
    [[ -f "$f" ]] || continue
    printf '%s\t%s\t\n' "commands/$(basename "$f")" "$f"
  done

  # The @-imported standards doc — the most load-bearing propagated artifact.
  f="$repo/docs/standards/engineering-standards.md"
  [[ -f "$f" ]] && printf '%s\t%s\t\n' "engineering-standards.md" "$f"

  # TDD gate RUNTIME only; the gate's own tests stay in the workflow repo.
  for f in "$repo/.claude/tdd/"*.js; do
    [[ -f "$f" ]] || continue
    case "$f" in *.test.js) continue ;; esac
    printf '%s\t%s\t\n' "tdd/$(basename "$f")" "$f"
  done

  # Executed by Claude Code on SessionStart — must land 100755.
  f="$repo/.claude/hooks/rotate-tdd-session-log.sh"
  [[ -f "$f" ]] && printf '%s\t%s\texec\n' "hooks/rotate-tdd-session-log.sh" "$f"

  # Executed by git on every commit via core.hooksPath — must land 100755, or git
  # silently ignores it (the inert-guard bug, verification.md catches 4 and 5).
  f="$repo/hooks/git/pre-commit"
  [[ -f "$f" ]] && printf '%s\t%s\texec\n' "git-hooks/pre-commit" "$f"

  # Hallucinated-dependency guard, invoked by the project's CI. node-invoked, so
  # correctly non-executable.
  f="$repo/scripts/check-imports.mjs"
  [[ -f "$f" ]] && printf '%s\t%s\t\n' "ci/check-imports.mjs" "$f"

  return 0
}
