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
#   <path-relative-to-PROJECT-ROOT>  <absolute-source-path>  <exec|"">
#
# Paths are PROJECT-ROOT-relative (manifest v3), not .claude/-relative as in v2.
# The change was forced by the mechanical control set: GitHub only reads workflows
# at .github/workflows/, and eslint only discovers its config at the project root.
# Neither is expressible as a .claude/-relative string, so the whole half of the
# harness that makes a project satisfy its own standards could not be tracked at
# all. Everything under .claude/ simply carries the `.claude/` prefix now.
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
    printf '%s\t%s\t\n' ".claude/agents/$(basename "$f")" "$f"
  done

  # Skills, per FILE. Directory granularity would freeze every file in a skill the
  # moment one of them was overridden.
  for skill_dir in "$repo/.claude/skills/"*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "${skill_dir%/}")"
    while IFS= read -r -d '' f; do
      printf '%s\t%s\t\n' ".claude/skills/$skill_name/${f#"${skill_dir%/}"/}" "$f"
    done < <(find "${skill_dir%/}" -type f -print0 | sort -z)
  done

  for f in "$repo/.claude/commands/"*.md; do
    [[ -f "$f" ]] || continue
    printf '%s\t%s\t\n' ".claude/commands/$(basename "$f")" "$f"
  done

  # The @-imported standards doc — the most load-bearing propagated artifact.
  f="$repo/docs/standards/engineering-standards.md"
  [[ -f "$f" ]] && printf '%s\t%s\t\n' ".claude/engineering-standards.md" "$f"

  # TDD gate RUNTIME only; the gate's own tests stay in the workflow repo.
  for f in "$repo/.claude/tdd/"*.js; do
    [[ -f "$f" ]] || continue
    case "$f" in *.test.js) continue ;; esac
    printf '%s\t%s\t\n' ".claude/tdd/$(basename "$f")" "$f"
  done

  # Executed by Claude Code on SessionStart — must land 100755.
  f="$repo/.claude/hooks/rotate-tdd-session-log.sh"
  [[ -f "$f" ]] && printf '%s\t%s\texec\n' ".claude/hooks/rotate-tdd-session-log.sh" "$f"

  # Executed by git on every commit via core.hooksPath — must land 100755, or git
  # silently ignores it (the inert-guard bug, verification.md catches 4 and 5).
  f="$repo/hooks/git/pre-commit"
  [[ -f "$f" ]] && printf '%s\t%s\texec\n' ".claude/git-hooks/pre-commit" "$f"

  # Hallucinated-dependency guard, invoked by the project's CI. node-invoked, so
  # correctly non-executable.
  f="$repo/scripts/check-imports.mjs"
  [[ -f "$f" ]] && printf '%s\t%s\t\n' ".claude/ci/check-imports.mjs" "$f"

  # ── Mechanical control set (#17 slice 1) ────────────────────────────────────
  # The half that makes a bootstrapped project satisfy its OWN standards on day
  # one. These live OUTSIDE .claude/ because the tools that read them require it:
  # GitHub only looks in .github/workflows/, eslint only discovers its config at
  # the project root. That requirement is what forced manifest v3.
  #
  # Rule 1 says "lint clean before commit"; until now a fresh project had nothing
  # to run. That is the same defect #13 fixed IN this repo, reproduced one level
  # out in every project this repo creates.

  # Lint config + the test entry point. run-tests.mjs is placed under .claude/ci/
  # because nothing outside Claude Code needs to find it by convention — only
  # package.json refers to it, and that wiring is the owner-run setup step.
  f="$repo/eslint.config.js"
  [[ -f "$f" ]] && printf '%s\t%s\t\n' "eslint.config.js" "$f"

  f="$repo/scripts/run-tests.mjs"
  [[ -f "$f" ]] && printf '%s\t%s\t\n' ".claude/ci/run-tests.mjs" "$f"

  # Observability (#5). Reads ~/.claude/projects/*/*.jsonl, so it is per-machine
  # in effect, but the script itself is a propagated asset like any other.
  f="$repo/scripts/observe.mjs"
  [[ -f "$f" ]] && printf '%s\t%s\t\n' ".claude/ci/observe.mjs" "$f"

  # CI workflows. Installed as real .yml, not .template — a template is a file
  # that never runs, and #17's whole point is that the guards actually execute.
  #
  # ONLY secret-scan.yml is propagated. It is genuinely generic: gitleaks over the
  # repo's own history, no repo-specific paths.
  #
  # guards.yml is deliberately NOT propagated, despite being the obvious candidate.
  # It is the workflow repo's own guard TEST suite — it runs
  # check-standards-ssot.sh, pre-commit.test.sh and check-imports.test.mjs, none of
  # which exist in a consumer project. Installing it there produces a workflow that
  # fails on its first run: present, red, and training the owner to ignore CI. Its
  # own header says as much ("downstream projects run the guards, not these tests").
  # The consumer's guard-running workflow is ci.yml, generated from ci.yml.template
  # by setup-project.sh (slice 3), which is why ci.yml is not enumerated here either.
  f="$repo/.github/workflows/secret-scan.yml"
  [[ -f "$f" ]] && printf '%s\t%s\t\n' ".github/workflows/secret-scan.yml" "$f"

  return 0
}
