# Current State — agentic-engineering-workflow

The hand-maintained orientation / handoff doc for this repo — read it at session
start to orient. There is no /start-session ritual anymore; THIS file is the
orientation. Updated by hand as work lands.
Last updated: 2026-06-24

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
  /security-review (mp-skills design §5 Part 2). FOLLOW-UP (not lost):
  /security-review covers pending-change review but NOT full-history secret
  scanning or npm audit. Home for those is a push/PR-triggered gitleaks CI
  workflow (runtime-independent) — NOT a local pre-push hook (dormant in the
  MINGW desktop runtime, Finding 4 — false confidence). npm audit is largely
  covered by dependabot where configured (this repo has it). jobs-radar has no
  CI yet; the secret-scan folds into its CI setup.
- git-operator agent retired; git ops are inline now — conventions live in
  engineering-standards Rule 9 (conventional commits) + global CLAUDE (explicit
  staging), force-push guarded by the block-force-push-to-main hook. Its
  merge-gating (no-direct-to-main) was contrary to locked-decision #7 and is
  intentionally gone (mp-skills design §5 Part 2-adjacent).
- Rule-10/#7 conflict RESOLVED (this commit): decision #7 recorded as
  docs/adr/0001-solo-direct-to-main.md; Rule 10 reframed project-conditional in
  BOTH copies (skill + doc), override-example dropped, warn-direct-commit hook
  message updated. FOLLOW-UPS (not done here): (a) the broader SKILL-vs-doc
  engineering-standards drift beyond Rule 10 (Rule 3, Rule 9, Writing-discipline
  section) — a single-source-of-truth task; (b) the GitHub PR-ruleset on this
  repo (Thomas UI action — see Open items below).
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
- FOLLOW-UP: .github/workflows/weekly-health.yml loops `for f in .claude/agents/*.md`
  (frontmatter + scope-boundary checks) — now an empty dir, so they fail CI; make
  them empty-safe (nullglob/guard) next.
- 6 enforcement hooks (dormant in MINGW desktop, active in terminal claude CLI)
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

## Projects built on this workflow
- jobs-radar (v1.5): D6a descriptions, D6b scorer, D7 heartbeat — all shipped,
  deployed to Hetzner (/opt/jobs-radar on sovary-app), verified live. First
  production exercise of the agent system; surfaced workflow findings W1-W5.

## In flight / next
- Batch 3 (workflow-repo half), remaining: deploy-facts discoverability — D2/D4/D5
  already in docs/deployment.md; added "Related runbooks" pointer in
  engineering-standards.md (GitHub URL, reaches all projects via @-import; not
  duplicated — finding-G). Retro open items #2/#4/#5/#8.
- Batch 4: spec-writer revision (W1/W2/W3), behavioral-validation rule (W5),
  spec-reconciliation loop-close + living-
  versioned-spec convention codified, .gitattributes for CRLF churn, deferred
  review findings, retro as final act + lessons distillation.
- Stage 2.5 (not started, needs spec) — then Stage 3 (Sovary calendar strip-down).
- Open: remove unintended branch-protection ruleset on this repo (blocks locked
  decision #7 solo direct-to-main); sovary-app pending OS updates + restart.

## Known characteristics to respect
- Runtime: desktop app = MINGW on Windows over \\wsl.localhost UNC; build/test in WSL2.
- Never commit via the GitHub web UI (commits direct to main without local
  sync — the two-write-path hazard, finding G). Commit runtime (MINGW desktop
  vs WSL2) is incidental to integrity; build/test belongs in WSL2 (above).
- Hooks dormant in desktop app — git discipline is manual there.
