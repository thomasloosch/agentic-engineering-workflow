# Current State — agentic-engineering-workflow

The hand-maintained orientation / handoff doc for this repo — read it at session
start to orient. There is no /start-session ritual anymore; THIS file is the
orientation. Updated by hand as work lands.
Last updated: 2026-07-22

## What this repo is
Meta-tooling for a solo agentic engineering workflow: shared skills, agents,
commands, hooks, and a bootstrap script that stamps the full hierarchy into
individual project repos. Separate from product work (Sovary); used to build it.

## What's built and current
- Global CLAUDE.md tracked at docs/global-CLAUDE.md
- Engineering pipeline is now user-invoked skills (grilling -> to-prd -> to-issues
  -> tdd; plus setup-engineering-skills, domain-modeling, codebase-design, triage,
  improve-codebase-architecture). spec-writer + implementation-engineer agents
  retired (Part 1, 6f6fa67); coordinator retired in Part 4 (this commit).
- researcher agent retired (this commit); /research is now a thin router to
  /deep-research + inline web tools (mp-skills design §5 Part 2).
- code-review agent retired; pre-merge review now via /code-review (always) +
  /security-review (security-touching diffs) built-in skills (mp-skills design
  §5 Part 2).
- security-audit agent retired; strategic per-branch security review now via
  /security-review (mp-skills design §5 Part 2). Its full-history secret-scan
  (which /security-review does NOT cover — that's pending-change only) now lives
  in CI: .github/workflows/secret-scan.yml (gitleaks, push + PR + workflow_dispatch,
  fetch-depth 0). COMPLETE: full-history baseline ran clean (no secrets in history),
  so the gate is now BLOCKING (continue-on-error removed) and the .gitleaks.toml
  allowlist stays empty. Secret-scan ONLY: no npm audit here (no package.json;
  dependabot covers only the Actions versions). jobs-radar's secret-scan still
  pending — it has no CI yet; folds into its CI setup (the
  .github/workflows/ci.yml.template).
- git-operator agent retired; git ops are inline now — conventions live in
  engineering-standards Rule 9 (conventional commits) + global CLAUDE (explicit
  staging), force-push guarded by the block-force-push-to-main hook. Its
  merge-gating (no-direct-to-main) was contrary to locked-decision #7 and is
  intentionally gone (mp-skills design §5 Part 2-adjacent).
- Rule-10/#7 conflict RESOLVED (this commit): decision #7 recorded as
  docs/adr/0001-solo-direct-to-main.md; Rule 10 reframed project-conditional in
  BOTH copies (skill + doc), override-example dropped, warn-direct-commit hook
  message updated. FOLLOW-UPS: (a) SKILL-vs-doc engineering-standards drift —
  DONE this session (Rule 3 /to-prd + Writing-discipline synced, Rule 9 trimmed,
  What's-NOT-a-rule added to the SKILL; title-drift guard added to weekly-health
  CI so it can't silently recur). (b) the GitHub PR-ruleset — DONE this session
  (PR requirement removed server-side; force-push/deletion guards kept).
- AGENT LAYER FULLY RETIRED (Part 4, this commit): coordinator + session-close
  retired, and the 4 web-app auditors (i18n-auditor, brand-guardian,
  performance-auditor, qa-testing) folded in. .claude/agents/ is now EMPTY. The
  engineering pipeline is the slash-skills above; orientation is reading this
  file by hand.
- Session ritual + self-learning RETIRED (Part 4): the /start-session, /defer,
  /close-session, /health-check commands + memory-hygiene skill + agent-compliance.log
  (the W4 self-grading orphan) removed. lessons.md KEPT as reference knowledge;
  patterns.md archived to docs/metrics/stage-2-patterns.md. The one forward-looking
  loss is the escalation-ladder / RED-refusal TODO-nagging (never fired) — the
  Open-items list is now purely manual.
- Retired-auditor reusable ideas (flagged, not lost): i18n-auditor's deterministic
  translation-key consistency check (keys-in-code exist in every locale) is a strong
  pre-commit/CI HOOK candidate — rebuild if a bilingual web project
  (Sovary/familienkalender) needs it. brand-guardian / performance-auditor /
  qa-testing (visual-brand, bundle/Lighthouse, Playwright live-testing) are web-app
  gates, N/A to CLI/cron — revisit as skills-or-hooks when web work needs them.
- 6 enforcement hooks (dormant in MINGW desktop, active in terminal claude CLI) —
  recorded as ADR-0002 (hooks advisory-only in the Desktop runtime; the constraint
  the warn-direct-commit hook + secret-scan-belongs-in-CI decisions lean on).
- FLAGGED DECISION (not taken here): the workflow repo has no root CLAUDE.md, and
  we're keeping it that way for now. The no-root decision was about not placing the
  GLOBAL CLAUDE.md at root; a dedicated PROJECT CLAUDE.md is a separate question. A
  root CLAUDE.md would enable Option B (thin engineering-standards SKILL via
  @-import of the doc — true SSOT) AND fix the Rule-10-override-home gap — its own
  repo-architecture decision, deliberately deferred.
- Bootstrap: copy-based with content-hash manifest (.asset-manifest)
- Path variables reconciled this session:
  - MEMORY_DIR -> project-relative .claude/memory/ (32 sites + session-close:396
    ABSOLUTE->project-relative prose fix). Commit 1aad210.
  - CLAUDE_HOME -> $HOME/.claude/ (5 sites). Commit d4e0106.
  - Runtime-assumption notes across all CLAUDE_HOME + LOGS_DIR sites: these resolve
    under the MINGW desktop app where agents execute; an agent run from WSL2 would
    resolve to a missing/divergent dir. Documented-known, not active failure
    (orchestration stays in desktop app). Commit 627a632.
- Memory files (this file + lessons.md): tracked in workflow repo as canonical
  knowledge; bootstrapped projects reference these rather than copying.
- SECURITY GUARDS — ISSUE #7, CLOSED (note: distinct from "locked-decision #7"
  above, which is the direct-to-main decision; unrelated numbering collision):
  (a) git-native pre-commit SECRET guard, hooks/git/pre-commit, wired by
  core.hooksPath, fail-closed, high-signal key formats + secret filenames. It
  genuinely blocks in MINGW (git runs it) — see the lifecycle-vs-git-native
  distinction under Known characteristics. A strict SUBSET of CI gitleaks (the
  authority), so the two cannot drift.
  (b) hallucinated-dependency IMPORT guard, scripts/check-imports.mjs —
  language-agnostic core + per-ecosystem adapters, ecosystem detected
  per-project at RUNTIME, node adapter only; loud-skips when it has no adapter
  or scans zero files (never a silent pass). Model is manifest-DECLARATION, not
  registry-existence — see #11 for that gap.
  (c) docs/checklists/code-review.md — the three AI failure modes.
  CI: .github/workflows/guards.yml runs both guards' suites, asserts exec bits
  (shebang ∪ *.sh), and runs the #6 SSOT guard on every push/PR.
  FRESH CLONES MUST RUN scripts/setup-hooks.sh — core.hooksPath lives in
  uncommitted .git/config, so the local guard starts inactive otherwise.

## Projects built on this workflow
- jobs-radar (v1.5): D6a descriptions, D6b scorer, D7 heartbeat — all shipped,
  deployed to Hetzner (/opt/jobs-radar on sovary-app), verified live. First
  production exercise of the agent system; surfaced workflow findings W1-W5.

## In flight / next
- NEXT: #4 eval harness with rubrics (scorer first). jobs-radar#48 folds INTO
  that session — create jobs-radar CONTEXT.md + fix its stale CLAUDE.md "State
  files" line (still lists seen.json/profile.yaml/applied.json). Deliberately
  not built standalone: the scorer is #4's first eval target, so CONTEXT.md
  supports that work instead of being unrelated cleanup.
- Backlog, do not build speculatively: #11 (import guard misses a fabricated
  package that is ALSO declared in package.json; needs a network registry-
  existence check — build only if it actually happens). #10 (/goal is referenced
  by the build flow but is not installed in this environment).
- Batch 3 (workflow-repo half), remaining: deploy-facts discoverability — D2/D4/D5
  already in docs/deployment.md; added "Related runbooks" pointer in
  engineering-standards.md (GitHub URL, reaches all projects via @-import; not
  duplicated — finding-G). Retro open items #2/#4/#5/#8.
- Batch 4: spec-writer revision (W1/W2/W3), behavioral-validation rule (W5),
  spec-reconciliation loop-close + living-
  versioned-spec convention codified, .gitattributes for CRLF churn, deferred
  review findings, retro as final act + lessons distillation.
- Stage 2.5 (not started, needs spec) — then Stage 3 (Sovary calendar strip-down).
- Open: sovary-app pending OS updates + restart. (The unintended branch-protection
  PR-ruleset that blocked decision #7 is RESOLVED — removed server-side this session.)

## Known characteristics to respect
- Runtime: desktop app = MINGW on Windows over \\wsl.localhost UNC; build/test in WSL2.
- Never commit via the GitHub web UI (commits direct to main without local
  sync — the two-write-path hazard, finding G). Commit runtime (MINGW desktop
  vs WSL2) is incidental to integrity; build/test belongs in WSL2 (above).
- Claude Code LIFECYCLE hooks (PreToolUse etc., hooks/*.sh) are dormant in the
  desktop app — that git discipline is manual there (ADR-0002). This does NOT
  apply to GIT-NATIVE hooks (hooks/git/, wired via core.hooksPath): git runs
  those itself, so they genuinely block in MINGW. Verified in #7 slice-1 — do
  not collapse the two mechanisms back together.
- Exec-bit CI assertion keys on shebang ∪ *.sh — extensionless scripts
  (hooks/git/pre-commit) exist; a *.sh-only rule would miss the file that caused
  the original bug (it shipped 100644, so git silently ignored it). Do not
  "tidy" this back to *.sh-only: that silently re-opens the hole.

### Verification lessons (2026-07-17 session)
- TEST THROUGH THE REAL INVOCATION PATH, not a convenient proxy. The secret
  guard shipped INERT because every test invoked it as `bash pre-commit`, and
  `bash <file>` can never observe a file-MODE problem — git runs a hook by mode,
  so a 100644 hook is silently skipped while every bash-invoked test still
  passes. A guard's tests must exercise it the way git/production actually
  invokes it (direct execution honouring the mode), or the test validates a path
  that never runs in reality. This is the sharp form of "green != verified":
  green through the WRONG invocation path is worse than red, because it buys
  false confidence.
- TEST/EVAL SCRIPTS RUN ON ISOLATED FIXTURES, NEVER LIVE STATE. Convention:
  create the working area with `mktemp -d`; never operate on the repo's own
  .git, index, or any live data store. Guard every directory change explicitly —
  `cd "$tmp" || exit 1` — do NOT rely on `set -e` to abort a bare `cd` (it does
  not do so reliably; a silently-failed `cd` leaves the script running in the
  PREVIOUS directory). Origin: a negative test mutated the live git index when a
  `cd` failed silently under `set -e` (caught and restored in-turn, nothing
  pushed). LOAD-BEARING FOR #4: eval scripts run adjacent to jobs-radar's live
  production store — a silent `cd` failure there corrupts real data, not a
  throwaway fixture.
- ENFORCEMENT IS DEFERRED, NOT BUILT. One incident -> record the convention and
  add it to the /goal checklist (#10). Do NOT build tooling (e.g. a linter for
  tests touching .git) unless it recurs. YAGNI.
