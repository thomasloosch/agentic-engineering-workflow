# Current State — agentic-engineering-workflow

The hand-maintained orientation / handoff doc for this repo — read it at session
start to orient. There is no /start-session ritual anymore; THIS file is the
orientation. Updated by hand as work lands.
Last updated: 2026-08-13

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
- ISSUE #4, CLOSED — eval harness: deterministic, labelled, local-first
  (jobs-radar scorer as the first target). ADR-0004. Food-engineering domain
  first, ~30 Thomas-validated labels; `labelled_by: thomas` enforced in the
  harness, `cc|claude|agent|auto` rejected (exit 2) so an agent can never
  self-label its own eval set. Subsumed the STEP-0 corpus's label role (the
  corpus keeps its posting-text role; `step0-corpus.test.js` now asserts
  labels are absent from it). Standards gained an "evals-before-code" line —
  What's-NOT-a-rule, conditional-firm (bar applies where correctness is a
  judgment call; absent for deterministic logic) — with the caveat that
  eval-green is regression protection on labelled cases, not proof of
  generalisation. Single-profile limit is documented in the jobs-radar eval
  README: all cases are `thomas/food-engineer`, so the eval suite is blind to
  ai/geo changes — do not treat it as a general arbiter for those.
- ISSUE #5, CLOSED — observability: `npm run observe` (scripts/observe.mjs)
  reads `~/.claude/projects/*/*.jsonl` for per-model turn counts, with
  `--since=<sha|date>` slicing so a routing delta is actually readable (a plain
  cumulative total can't show a share *change*). Cost (needs a price table) and
  latency (would misrepresent human think-time) were declined with reasons, not
  silently dropped; drift tracking carved out into #14.
- ISSUE #8, CLOSED (rescoped) — model routing. Per-subagent-overrides was
  mis-scoped and retired via ADR-0003. What shipped: Lever A — default model
  flipped to Sonnet in the user-level `settings.json`, verified via
  `observe --since` (frontier share 96.1% -> 67.4%). Lever B — rule-driven
  delegation to cheap general-purpose subagents, codified in
  engineering-standards as the falsifier discriminator ("delegate only work
  with a cheap mechanical falsifier; parallelism != mechanicalness; delegate
  the check with the generation") plus a size floor. AC2 (Haiku turn count
  rising) was amended as unsatisfiable: subagent turns are never recorded
  (`isSidechain` is 0 across every transcript), so delegation count is the
  honest proxy, not model-turn share.
- ISSUE #10, CLOSED (struck) — `/goal` struck rather than built (ADR-0006).
  Per-issue acceptance verification stays human + engineering-standards
  Rule 2; the revisit trigger is "verification gets routed to a cheaper model,
  or run without a human in the loop." The catch-list + two-layer methodology
  it would have enforced now lives in docs/checklists/verification.md (7
  catches, see below) instead of a command.
- Day-1 paper adoption arc (Google "New SDLC / Vibe Coding") CLOSED this
  session: issues #4-#11 and #14 filed against it and worked; #4/#5/#6/#7/#8/
  #10 closed, #9/#11/#14 deliberately parked (YAGNI-gated, each with a named
  revisit trigger — see In flight / next). Board is at rest.

## Projects built on this workflow
- jobs-radar (v1.5): D6a descriptions, D6b scorer, D7 heartbeat — all shipped,
  deployed to Hetzner (/opt/jobs-radar on sovary-app), verified live. First
  production exercise of the agent system; surfaced workflow findings W1-W5.

## In flight / next
- NEXT: **The harness program — #16 → #19 → #17 → #18 → #24.** Gate-1 specs for
  #17/#18/#19 APPROVED 2026-08-13. Build in that order; the specs are in
  docs/specs/ and carry their gate decisions at the top.
  - **#16 — CLOSED 2026-08-13 (48a381d), CI green.** Provenance now comes from the
    manifest, not from presence on disk; the manifest is rebuilt from the union of
    repo assets and prior entries, and an override keeps its ORIGINAL recorded hash.
    Sync gained fail-closed-on-empty, an UNVERIFIED class for the new `unknown`
    provenance sentinel, and the ADD class (#25's down half).
    `scripts/lib/asset-list.sh` is now the single shared definition of what gets
    propagated — installer and detector read the same list. jobs-radar is
    deliberately NOT repaired yet; that is #17 slice 4. Dry run against it now names
    the stale standards doc as UNTRACKED and both missing guards as ADD.
    Was: a second `bootstrap-project.sh` run empties the asset
    manifest (37 entries -> 0, reproduced on a mktemp fixture) and
    `sync-project-assets.sh` then reports a clean bill of health while tracking
    nothing. Fail-open. This is why jobs-radar's `.claude/engineering-standards.md`
    is stale and NOT in its manifest (missing #8's model-routing section, ADR-0001's
    Rule-10 reframe, Rule 2's verification.md link), and why the import guard and
    git secret guard never reached it at all. Lands standalone and verified, before
    #17 — do not build more propagation through a broken propagation mechanism.
  - **#19 catch-log** — per-project defect log (what / who-caught / error-class),
    3-value closed who-caught set, rule-of-three promotion. Precedes #17 because
    #17 slice 2 propagates it.
  - **#17 full-harness bootstrap** — propagate the whole reference control set AND
    the learning artifacts; emitted owner-run `setup-project.sh` does the wiring so
    bootstrap never edits package.json.
  - **#18 semver acceptance harness** — the end-to-end test. Fresh repo, bootstrapped,
    taken PRD -> spec -> gate 1 -> build -> gate 2, validated against a public
    conformance corpus split visible/held-out.
  - **#24** — instrument judgment-class verification, gated on #18's measured tally.
- **STAGE 3 IS RETIRED.** The Sovary calendar strip-down (`familienkalender`) is NOT
  the acceptance test — its parity oracle contained the scope judgment it was meant to
  falsify, and parity cannot measure generalisation. `HANDOFF-stage-3.md` is marked
  superseded; `~/familienkalender` is released. What carried into #18: the pre-declared
  metrics, the **"Thomas does not pre-empt"** rule (log who-caught-what as it happens or
  the measurement is contaminated), the two-halves delegation watch, and the #7 session's
  six-for-six all-human catch rate as the benchmark. Friction still logs to
  docs/metrics/v1-success-metrics.md, whose framing predates the Part-4 reorg — only its
  friction-log table and weekly-log mechanics are usable as-is.
- Also filed, not yet built: #20 (regression-case-before-fix, proposed standards
  addition), #21 (gate-rejection logging), #22 (memory reconcile — build-ready after
  the program above; this very section is its evidence), #23 (PRD/spec front-end —
  PARKED, revisit when the catch-log records premise-drift or unobservable-AC at
  gate 1 twice; W1 landed in to-issues as f7bcf03), #25 (cross-project sync +
  up-promotion — down-direction gate OPEN and folded into #16/#17, up-direction
  parked).
- Parked (all low priority, YAGNI-gated — do not build speculatively; each has
  a named revisit trigger):
  - #9 Examples as an explicit context type — distillation turned out to be
    synthesis (frontier main-thread work), not falsifiable delegation; cheap-
    model drafts came back silently wrong. `ready-for-human`.
  - #11 Import guard gap — misses a fabricated package that is ALSO declared
    in package.json (needs a network registry-existence check). Revisit only
    if it actually happens.
  - #14 Drift signal (run-over-run divergence on a fixed task) — revisit
    trigger is "delegated/routed volume exceeds manual-review capacity," not
    a model-version bump per se: a tier drop (#8, Sonnet default) IS the
    divergence risk, not just a cost/latency concern.
- Three original build tasks from before the Day-1 arc, reconciled:
  1. PRD process (repeatable co-think + completeness checklist) — exercised
     via the #4 PRD, not codified as reusable. Only worth building if
     repeatability across future PRDs is wanted; otherwise the pattern stands
     as demonstrated.
  2. Spec generation from PRD (spec-writer W1/W2 fixes: resolve-from-code-
     before-asking / re-anchor-on-revision) — specs were written through the
     flow (#4, #8) but these two specific fixes were never built. Still open
     if wanted.
  3. Deterministic Stop hook as a trust gate — subsumed into the #10 strike +
     ADR-0006's revisit trigger (see #10 above). Not reopened separately.
- Open: sovary-app pending OS updates + restart.

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
- ENFORCEMENT IS DEFERRED, NOT BUILT. One incident -> record the convention in
  docs/checklists/verification.md (item 6), referenced from Standard 2. (Was "the
  /goal checklist (#10)"; /goal was struck — ADR-0006 — and the catch-list rehomed
  there.) Do NOT build tooling (e.g. a linter for tests touching .git) unless it
  recurs. YAGNI.
