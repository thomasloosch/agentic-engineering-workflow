# Current State — agentic-engineering-workflow

Status snapshot for session orientation. Updated at the close of each work batch.
Last updated: 2026-06-06

## What this repo is
Meta-tooling for a solo agentic engineering workflow: shared skills, agents,
commands, hooks, and a bootstrap script that stamps the full hierarchy into
individual project repos. Separate from product work (Sovary); used to build it.

## What's built and current
- Global CLAUDE.md tracked at docs/global-CLAUDE.md
- Engineering pipeline is now user-invoked skills (grilling -> to-prd -> to-issues
  -> tdd; plus setup-engineering-skills, domain-modeling, codebase-design, triage,
  improve-codebase-architecture). spec-writer + implementation-engineer agents
  retired (this commit); coordinator HELD pending the Part-4 session-ritual
  decision (it still backs /start-session + /defer).
- Remaining sub-agents (.claude/agents/): coordinator (held), code-review,
  security-audit, i18n-auditor, brand-guardian, performance-auditor, qa-testing,
  git-operator, researcher, session-close — disposition pending (mp-skills
  design §5 Parts 2-4)
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
