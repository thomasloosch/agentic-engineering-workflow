# Current State — agentic-engineering-workflow

Read at session start to orient. There is no `/start-session` ritual; THIS file is
the orientation.

**This file has two halves, and the split is the point (#22).** The block below is
**STATE**: one current value per fact, and it is *replaced* when it changes. The Log
beneath it is **EVENTS**: timestamped, *appended*, never edited.

Appending a state creates two answers to one question with nothing marking which is
current — and the stale copy usually sits higher in the file, so it gets read first.
That is exactly how this doc came to lead with "NEXT: strip Sovary to calendar-only"
after that plan was retired. Structure carries this rule, not an instruction.

**If you change what is true, edit the block below. If you record what happened,
append to the Log.**

Last updated: 2026-09-07

---

## Current State

**What this repo is.** Meta-tooling for a solo agentic engineering workflow: shared
skills, standards, guards, hooks, and a bootstrap that stamps the harness into
project repos. Separate from product work; used to build it.

### NEXT — four human decisions, no build in progress

Nothing is half-finished and nothing is blocked on a fix. Both repos are clean, the
workflow repo is pushed, CI is green. What is outstanding is judgment:

1. **#21's revisit trigger is undecidable as written** — "#18's first real gate
   rejection" names no closed vocabulary, unlike #23's, which counts catch-log
   error-classes and therefore can be evaluated from the file.

### #18 — CLOSED 2026-09-07, Gate 2 accepted

The measurement the program exists to produce. Baseline to beat: **six catches, six
human, zero agent-self** (#7 session).

- **Build:** all 164 in-scope visible cases pass. 206 tests, 7 suites, lint green.
- **Held-out validation: 155/160 (96.9%)** on cases the build never saw. Thomas
  generated the split; same upstream commit as the visible half. Recorded in
  `~/projects/semver-probe/docs/VALIDATION-RESULT.md` **before** any fix, and
  `corpus/held-out.json` appears in no earlier commit (AC6, checkable by
  `git log --diff-filter=A`).
- **Catches: 9 — 5 `agent-self`, 4 `automatic-gate`, 0 `human`.** Full report:
  `docs/gate-2-issue-18.md`. **The ratio is not the conclusion** — see the closing
  comment on #18. What the run demonstrated is narrower: mutation testing and
  held-out validation each found defects nothing else did, and the bespoke guards
  found nothing at all inside the probe.
- **Read the number with its caveats.** Zero human catches reflects zero
  opportunity, not harness superiority — nobody was reviewing. Three of the five
  `agent-self` catches came from ONE instrument, the mutation step, and each was a
  branch the corpus provably cannot reach. The workflow's bespoke guards caught
  little inside the probe: the `automatic-gate` catches were eslint twice and the
  held-out validation twice. And 96.9% cannot separate generalisation from recall,
  since node-semver is almost certainly in training data.
- **The held-out half is spent.** Both defects it found are now permanent
  regression tests, because that half cannot serve as an independent check again.
  Any later score against it is fitting, not generalisation.

### Gate 1 outcomes, 2026-09-07

- **#20 BUILT** — `verification.md` entry **9**: a defect is not fixed until its
  failing case is a permanent test/eval entry. Plugin bumped to 0.6.0.
- **#21 RESCOPED** — no schema; the inline dated "Gate 1 decisions" heading (as in
  #17/#18/#19/#26) is named as the standing interim convention.
- **#24 HELD** — re-gated on #34, and its issue text now carries a correction
  notice so a closed #18 does not read as a green light.
- **#25 PARKED** — one README section naming the sync's scope and manual cadence.
- **#23 STAYS PARKED** — one trigger instance recorded, two required.

### Recently completed

- **#22 memory reconcile** — both halves. The checker is
  `scripts/check-memory-drift.sh`. **It is structural, not semantic**: it verifies
  issue states, ADR existence, commit SHAs and the freshness marker, and does not
  read the block for truth. A clean run is narrower than it looks.
- **#30 validation-strategy section** — `docs/specs/TEMPLATE.md` plus a clause under
  Standard 2. No CI guard, deliberately: a guard can only assert a heading exists.

### Parked, with triggers

- **#23 PRD/spec front-end** — W1 landed; see decision 3 above for its trigger.
- **#24 judgment-class instrumentation** and **#25 up-promotion** — no longer
  parked. The tally they waited for exists, and gate-1 specs were drafted
  2026-09-07. Note the tally is weaker than either issue assumed: see below.
- **#34 human-review-arm probe** — new, filed 2026-09-07. The comparison #18 could
  not make, because nobody was reviewing during that run.
- **#35 jobs-radar catch-log** — CLOSED 2026-09-07. Its `.claude/memory/`
  still carries the pre-catch-log `lessons.md`/`patterns.md` scheme, so the
  cross-project half of the learning loop has exactly one project in it.
- **#9 / #11 / #14** (YAGNI, each with its own trigger).

### Projects on this workflow

- **jobs-radar** — harness installed; its new files are deliberately **left
  untracked**, and it keeps its own `test`/`tdd`/`lint` scripts. `setup-project.sh`
  correctly refused to overwrite them. **One exception, 2026-09-07 (#35):
  `.claude/memory/catch-log.md` IS tracked** — everything else in that group is
  regenerable from this repo and the catch-log is not. Its log starts empty; the
  old `lessons.md`/`patterns.md` were not back-filled.
- **semver-probe** (`~/projects/semver-probe`) — #18's probe, complete and now
  pushed to a **private** repo (`thomasloosch/semver-probe`). Private on purpose:
  `corpus/held-out.json` is committed there, and publishing it would spoil
  node-semver as a held-out oracle for any future run. Its history was rewritten
  once, before the first push, to replace a private commit email with the noreply
  address — content identical (HEAD tree hash unchanged), all SHAs moved.
  **`gh` cannot see this repo**: the fine-grained PAT is scoped to selected
  repositories and this one is not among them. Git over SSH is unaffected.

### Runtime facts that bite (verify against these before debugging)

- **UNC and WSL2 disagree about file modes.** `chmod +x` from MINGW does not reach
  the real ext4 file, and `ls -l` over UNC then reports the mode you asked for. The
  **git index** mode is trustworthy from either side; the **working-tree** mode must
  be set and read from WSL2 (`wsl.exe -e bash -c ...`).
- `mkdir -p` on an absolute UNC path fails, even when the directory exists. Use
  `ensure_dir` (`scripts/lib/portable-fs.sh`).
- **Lifecycle hooks DO fire and block** here — ADR-0002 amended on measured evidence.
  But a warn-only hook (exit 0 + stderr) is **mute**: its output never surfaces. If it
  matters, make it block.
- `node` is not on `PATH` in a non-interactive `wsl.exe bash -c`; use `bash -lc`.
  WSL has no native node here at all — `npm` resolves through Windows interop, so a
  path printed from "inside WSL" can come back as a `\\wsl.localhost\...` UNC path.
- **Exit codes from `wsl.exe ... bash -lc '...; echo $?'` are not trustworthy** —
  the status reported belongs to the wrong process. Write a script file and run
  `wsl.exe -- bash /path/to/it` when the exit code matters.
- **The GitHub SSH key is Windows-side only.** `git push` from WSL fails
  `Permission denied (publickey)`; push from Git Bash. Same repo, same remote.
- **Python's default text-mode write emits CRLF on Windows.** Edits made that way
  ship CRLF into a repo whose scripts run under WSL bash, which then dies on a bare
  CR before reaching its own logic. The index stays LF, so `git status` shows
  nothing. Pass an explicit LF newline when writing files.
- Plugin is at **0.6.0**. A shipped change without a version bump is a silent no-op;
  CI fails on it. `SHIPPED_PATHS` is `.claude-plugin`, `.claude/skills`,
  `docs/checklists` — `docs/standards` and `docs/specs` are outside it and do NOT
  trip the guard, though the standards doc still reaches projects by bootstrap copy.

### Instruments

- **Catch-log** (`.claude/memory/catch-log.md`) — 37 rows: 31 individual plus 6
  collapsed promotion summaries. Across the 31: **17 `agent-self`, 11
  `automatic-gate`, 3 `human`.** Structurally favours `agent-self`, because the
  agent writing the code is also the one reading the output.
- **Six promotions fired**: `artifact-vs-effect` -> catch 1, `wrong-invocation-path`
  -> 5a, `fail-open-guard` -> 2a, `overbroad-assertion` -> 3a, `vacuous-test` -> 3b,
  `silent-truncation` -> 8. The catch-log's RULES are the source for the propagated
  skeleton; edit there, then regenerate with
  `node scripts/make-catch-log-skeleton.mjs`.
- **Probe catch-log** (`~/projects/semver-probe/.claude/memory/catch-log.md`) — 9
  rows, 5 `agent-self` / 4 `automatic-gate`. This is #18's measurement and is kept
  separate from this repo's log on purpose.
- **verification.md** — 8 top-level checks plus 2a, 3a, 3b, 5a. Reached by URL from
  Rule 2.
- **Drift checker** — `scripts/check-memory-drift.sh`, structural only (see above).

---

## Log — historical, append-only

> **Everything below is history, not current state.** It records what happened and
> why, and individual entries may have been superseded. Where the Log and the block
> above disagree, **the block above wins**. Do not edit entries here to make them
> current; add a new one, or fix the state block.

### 2026-09-05 — the propagated test entrypoint had never run anywhere but here

Starting #18 slice 1 meant running `npm test` in the probe, which discovered zero
suites. Three defects in `run-tests.mjs`, all the same shape: it was written and
tested only in the layout it was authored in. It resolved its project root as
"my directory, then up one" (right at `scripts/`, wrong at `.claude/ci/`), searched
only this repo's directory list, and hard-failed unless BOTH categories found
suites — which no JS-only consumer can satisfy.

The fourth was worse and had nothing to do with layout: `node --test` silently skips
every file and exits 0 when `NODE_TEST_CONTEXT` is in its environment. The variable
is inherited, so running the runner from inside any node:test process printed
"OK: all N suite(s) passed" having executed nothing.

Nine catches logged. Two classes crossed the rule-of-three in one session and both
are left as candidates, because the rule says a human decides: `vacuous-test` and
`silent-truncation`. The `vacuous-test` third instance is the sharp one — a
regression test whose sed backreferences were mangled into a literal control
character, so both sides of its comparison were identical and it could never fail.
It passed with the defect reintroduced. **Only the mutation step found it**, which is
true of all three rows in that class: none was caught by a gate.

The catch-log itself needed repair. The row describing the 2026-08-19 raw-NUL defect
contained a raw NUL, so git had classified the whole file as binary and every diff of
the #18 measuring instrument was invisible.

Slice 1 then went in as five red-green cycles: all 12 `valid-versions` cases green,
mutation-checked. Slice 2 is blocked on a scope decision about `loose`.

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
- **ADR-0002 SETTLED 2026-08-17.** Probe ran 3 days / 18 sessions, 300 invocations:
  PreToolUse 142, PostToolUse 140, SessionStart 18. ALL three lifecycle events fire
  in the Desktop/MINGW runtime; probe removed. Two consequences: (a) lifecycle hooks
  are available for real enforcement — several git-native workarounds exist because
  we believed otherwise; recorded as an option, NOT a refactor to chase, since the
  git-native guard has its own justification (git runs it regardless of caller);
  (b) `warn-direct-commit-to-main` RETIRED — exit-0 stderr never surfaces, so it
  warned no one while reading as coverage, and blocking would contradict ADR-0001.
  Revisit as a BLOCKING hook only if a project gains collaborators. Rule 10's
  why-paragraph in the standards doc was corrected (it cited that hook).
- Enforcement hooks: **ADR-0002 AMENDED 2026-08-14 — they were never dormant
  because of the runtime.** Four of five exited 127 on a missing `jq` (under
  `set -euo pipefail`, at their first extraction line), which Claude Code treats
  as a non-blocking error — so they failed OPEN for months. Now jq-free
  (`hooks/lib/json-extract.sh`), fail-CLOSED on unparseable+dangerous payloads,
  and covered by 18 tests via the real invocation path. Verified LIVE: `git add
  -A` and force-push-to-main are both genuinely refused. The surviving real
  limitation is inverted from the old claim — hooks ENFORCE fine; a *warn-only*
  hook that exits 0 is mute here (its stderr never surfaces), so if it matters,
  make it block. `PostToolUse`/`SessionStart` firing still unverified —
  `hooks/probe-hook-firing.sh` is installed and registered; read
  `~/.claude/logs/hook-firing-probe.log` after one fresh desktop session, finish
  the ADR, then remove the probe.
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
- **DONE 2026-08-19: #16, #17, #26. The harness-hardening program's build half is
  complete.** #26 (plugin distribution) closed — all 5 slices; ADR-0007 ACCEPTED.
  The delivery model is settled BY TEST: `@${CLAUDE_PLUGIN_ROOT}` does NOT resolve
  in memory imports, the absolute form does but embeds the plugin version, so the
  standards doc stays copy-propagated. Everything else portable is plugin-delivered.
  Plugin is at 0.4.0; a CI guard fails the build on shipped changes without a bump
  (it has caught two real omissions). Auto-update: `FORCE_AUTOUPDATE_PLUGINS=1`
  enables the plugin half alone — evidence-backed but NOT behaviour-observed, so
  unconfirmed until a session refreshes with it set.
  #33's runtime-faithful fixture tier landed (`scripts/lib/runtime-fixture.sh`);
  its UNC audit found and fixed a fail-open in `check-imports.mjs`.
  **NEXT: #18 (semver acceptance harness)** — the measurement the whole program
  exists to produce. Everything it depends on (#16, #17, #19) is done.
- Superseded plan (kept for the ordering rationale): **#16 → #19 → #17 → #18 → #24.** Gate-1 specs for
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
  - **#19 catch-log — BUILT, v0.5 posted for review 2026-08-13** (`6ef5161` seed,
    `8533c93` first promotion), CI green. `.claude/memory/catch-log.md`: 3-value
    who-caught set, rule-of-three promotion, seeded with #16's row + the six
    backfilled `#7`-session catches + one real worked promotion
    (`artifact-vs-effect` -> already-existing verification.md catch 1).
    Running the promotion for real (not describing it) exposed a real gap in the
    hygiene rule as first drafted — collapsing rows without their who-caught
    breakdown would have silently broken AC5 on every future promotion; fixed in
    the same build. AC2 (propagation) and AC6 (populated by a real build)
    deliberately NOT closed — those complete with #17 and #18 respectively, so
    #19 stays open on the board.
  - **#17 full-harness bootstrap — SLICE 1 DONE 2026-08-14 (`1975c26`), CI green.**
    Mechanical control set now propagates: eslint.config.js, run-tests.mjs,
    observe.mjs, secret-scan.yml. **Manifest v2 -> v3** — column 1 is now
    PROJECT-ROOT-relative, forced because GitHub requires .github/workflows/ and
    eslint requires a root config, neither expressible in v2. v2 manifests migrate
    on read (load-bearing: without it, 33 jobs-radar entries flip to "re-add" and
    --apply would overwrite every override; a test now kills that mutation).
    `guards.yml` deliberately NOT propagated — it is this repo's own guard-TEST
    suite and would fail on first run in any consumer; a test asserts its absence.
    **SLICE 3 DONE (`b6db347`)** — bootstrap emits an owner-run `setup-project.sh`
    (the only thing that edits package.json / settings.json; refuses on conflict,
    idempotent) and `.claude/bootstrap.conf` gates components per project with LOUD
    skips. **SLICE 4 DONE (`7dbd3e9`)** — jobs-radar re-bootstrapped, its
    two-month-stale standards doc repaired, local secret guard verified blocking
    there. Two defects found only by running against a real target: bootstrap could
    not bootstrap ANY real project (`mkdir -p` fails on absolute UNC paths, even for
    existing dirs — every fixture was a `/tmp` MSYS path, so 100% green and 0%
    functional; fixed via `scripts/lib/portable-fs.sh`, promoted to verification.md
    catch **5a**), and `secret_scan=off` did not take effect because `gate_for`
    matched the generic workflows rule first (now split `secret_scan` /
    `git_guard`).
    **SLICE 2 is now nearly empty** — ADR-0007 (ACCEPTED) drops the checklist copies
    entirely; only the catch-log skeleton placement remains, and it needs #19's
    artifact added to the asset list.
    NOTE: jobs-radar's `.gitignore` already excludes the propagated portable assets,
    so its harness is per-checkout and the standards drift never existed in its git
    history. That is ADR-0007's split arrived at independently.
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
- Claude Code LIFECYCLE hooks (PreToolUse etc., hooks/*.sh) **DO fire and DO
  block in the desktop app** — ADR-0002 amended 2026-08-14 on live evidence; the
  old "dormant/manual" claim was a `jq` artifact, not a runtime property. Git
  discipline is now genuinely enforced there. GIT-NATIVE hooks (hooks/git/, wired
  via core.hooksPath) remain a DISTINCT mechanism — git runs those itself, so they
  block on any git operation including ones issued outside Claude Code. Still do
  not collapse the two mechanisms together; the distinction is real, just no
  longer a difference in *whether* each enforces.
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

