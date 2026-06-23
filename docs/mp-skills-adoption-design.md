# mp-skills Adoption — Reconciliation Design

**Date:** 2026-06-21
**Status:** **Adopted** — all 8 skills placed and pushed to `main` (2026-06-21 → 06-23); per-skill commits in §7. Two reconciliations remain open (§5 bullets 2–3): the `spec-discipline` → `to-prd` merge and the agent-dispatch retirement. Now a record of the decisions, not a forward plan.
**Source screened:** `mattpocock/skills` @ `6eeb81b` (2026-06-18), local mirror at `~/scratch/mp-skills` fast-forwarded to match.
**Validation target:** Stage 2.5 — the jobs-radar dashboard — is the end-to-end test of the adopted suite.

This is the **design** doc for adopting Matt Pocock's engineering-skills suite into this workflow — *what* we adopted, *why that exact set*, *how it reconciles with how this workflow already works*, and *in what order*. The adoption it specifies has since been executed; it now doubles as the record (per-skill commits in §7). `tdd` was already adopted (the thin fork at [.claude/skills/tdd/](../.claude/skills/tdd/SKILL.md)); everything here builds the closure around it.

---

## 1. Adoption set — the no-dangling-edges closure

**Adopt eight skills** (plus the already-adopted `tdd`):

| Skill | Role in the closure |
|---|---|
| `setup` (`setup-matt-pocock-skills`) | **Config writer.** Sole producer of `docs/agents/{issue-tracker,triage-labels,domain}.md` + the `## Agent skills` pointer block. |
| `domain-modeling` | **Glossary/ADR writer.** The *only* active writer of `CONTEXT.md` and `docs/adr/`. Reached via grilling, improve-arch, triage, or direct. |
| `grilling` | **Interview engine.** The relentless one-question-at-a-time stress test that every "sharpen a plan" wrapper routes to. |
| `codebase-design` | **Architecture vocabulary.** The deep-module lexicon (module / interface / depth / seam / adapter / leverage / locality) that improve-arch and (optionally) tdd consume. |
| `to-prd` | Conversation → PRD → issue tracker. |
| `to-issues` | PRD/plan → independently-grabbable vertical-slice issues. |
| `triage` | Moves issues + external PRs through the five-role state machine; writes agent-ready briefs. **Completes the issue lifecycle.** |
| `improve-codebase-architecture` | Scan → HTML report → grill the pick. The **parallel architecture entry point** (not part of the PRD chain; feeds the same substrate). |

### Why this is the closed set

The screening established the full dependency graph. This set is chosen because it has **no dangling edges** — every read has a writer, every wrapper has its engine:

- **`setup` closes the config edge.** `to-prd`, `to-issues`, and `triage` are *hard*-dependent on per-repo config (which tracker, which label strings). Without `setup`'s output their behaviour is wrong, not just fuzzy. Including `setup` resolves that edge for all three.
- **`domain-modeling` closes the glossary/ADR write-edge.** Six skills *read* `CONTEXT.md`/ADRs (`to-prd`, `to-issues`, `tdd`, `improve-arch`, `triage`, `codebase-design`). Exactly one skill *writes* them — `domain-modeling`. Adopting the readers without it leaves the substrate permanently empty and the "use the project's vocabulary" promise hollow. It is the keystone.
- **`grilling` closes the interview-engine edge.** `improve-arch` and `triage` both invoke `/grilling`. It is also our front-of-pipeline co-think step (see §4). Adopting either wrapper without `grilling` ships a wrapper that calls nothing.
- **`codebase-design` closes the architecture-vocabulary edge.** `improve-arch` invokes `/codebase-design` for its lexicon and its design-it-twice pattern. (Our `tdd` fork currently inlines this vocabulary instead — see §6, deferred.)
- **`triage` completes the issue lifecycle.** `to-prd`→`to-issues` produces agent-ready issues; `triage` is what handles everything those two *didn't* create — raw bug reports, incoming requests, external PRs — moving them into the same `ready-for-agent` queue. Without it the lifecycle has a producer but no intake path for unsolicited work.
- **`improve-arch` is the parallel entry point.** It does not sit in the PRD chain; it's the "spare-moment, keep-the-codebase-good-for-agents" loop. It depends only on `codebase-design` + `grilling` + `domain-modeling`, all of which are already in the set — so including it adds an entry point at **zero** new dependency cost.

Everything *outside* this set either (a) dangles on one of these engines, (b) duplicates an asset we already own (see §5), or (c) is deferred pending Stage 2.5 (see §6). The transitive closure is self-contained.

---

## 2. Execution model & automation

**This is the load-bearing decision.** The slash-skill pipeline **replaces** the agent-dispatch model. The coordinator / spec-writer / implementation-engineer orchestration is **retired** (cleanup in §5). The pipeline is:

```
grilling → to-prd → to-issues → triage(as needed) → implement-per-issue
                 ↑ improve-arch feeds the same CONTEXT.md/ADR substrate
```

The critical clarification, because it looks like a downgrade and is not: **automation is not lost.** Three layers exist; we keep the two that work and drop the one that never did.

### What we keep

**(a) Autonomous-within-a-step.** Once a phase is triggered, Claude Code executes the *whole* unit without further human turns. `/to-issues` breaks an entire PRD into slices in one go. A single `/implement` against one issue builds the complete vertical slice — schema, logic, UI, tests — and the in-prompt verification loop closes itself (write test → run → read failure → fix → re-run) without a human in the loop. The autonomy is *inside the step*, which is exactly where it's reliable.

**(b) Deterministic hooks.** The TDD gate ([.claude/tdd/](../.claude/tdd/)) and git-discipline hooks fire **every time, with no trigger and no judgment** — they are not part of the skill pipeline and are unaffected by retiring the coordinator. A hook cannot forget to run. This is the strongest automation layer and it stays. (Caveat already on record: hooks are *dormant in the MINGW desktop runtime* and advisory there — see [stage-2-retro Finding 4](metrics/stage-2-retro.md). That's a runtime gap to close, not a reason to weaken the layer.)

### What we drop — and why it's correct to drop it

**Orchestration-automation** — a coordinator auto-*deciding* and auto-*dispatching* the next phase. This is the only thing removed, and it is removed because **it never worked.** The W4 coordinator-wiring gate ([patterns.md, `W4-HOLED-GATE`](../.claude/memory/patterns.md)) shipped non-functional: the gate's reader and the code-review writer pointed at different log paths, so it would have falsely reported "review didn't run." The first live agent run ([stage-2-retro Finding 7](metrics/stage-2-retro.md)) routed correctly *once* but only after manual dispatch-prompt injection, and a dispatched sub-agent still violated a documented runtime constraint. The orchestration layer was the most fragile, least-tested part of the system and delivered negative value.

### Phase transitions are human-triggered **by design**

Each transition — grill→PRD, PRD→issues, issue→implement — is a **judgment gate**, not a missing automation. The human deciding "this PRD is right, break it into issues now" *is the review step*. Auto-advancing past these gates is precisely what removed the human's leverage over correctness in the agent-dispatch era. Per [ask-matt](https://github.com/mattpocock/skills/blob/main/skills/engineering/ask-matt/SKILL.md), grill→to-prd→to-issues is meant to run in **one unbroken context window** (the "smart zone," ~120k tokens) so the thinking compounds; `/implement` then starts fresh **per issue** because the issues are independent. The human triggers each boundary deliberately. That's the design, not a gap.

### Future automation-growth path

More **deterministic hooks**, not a resurrected coordinator. The growth direction is to push more guarantees down into the no-judgment-required layer — e.g. the deferred Stop-hook trust-gate (verify the agent's claimed state at end-of-turn before accepting it). New automation earns its place by being a hook that fires every time, not an orchestrator that decides when to fire. **Do not rebuild the coordinator.**

---

## 3. Tracker decision — GitHub Issues

The issue tracker is **GitHub Issues**, configured once by `setup` into `docs/agents/issue-tracker.md`, and read by every chain skill (`to-prd`, `to-issues`, `triage`). One shared config, one source of truth for "where issues live."

Rationale: the projects this workflow stamps (jobs-radar, and ahead Sovary/familienkalender) already live on GitHub; the `gh` CLI is present and authenticated; and the local-`.scratch/` markdown alternative buys nothing here while losing the real issue surface that `triage` and external-PR intake assume. PRs-as-a-request-surface stays **off** by default (solo repos; revisit per-project if a repo starts receiving external PRs).

---

## 4. The four seam reconciliations

These are the points where the suite's assumptions meet how this workflow already operates. Each is resolved, not papered over.

### 4.1 Interview posture — co-think at the front, synthesis after

`grilling` is the **co-think front**: the relentless interview that sharpens a fuzzy intent into a concrete, decided plan. `to-prd` then **synthesizes from that conversation — it does not re-interview** ("no interview, just synthesis of what you've already discussed"). This is the same authority-swap already encoded in the [tdd §1 edit](../.claude/skills/tdd/SKILL.md): downstream steps take authority from the *artifact the upstream gate produced*, not from a fresh round of questions. Grilling does the asking; to-prd trusts the answers. No double-interview, no posture clash.

### 4.2 Gate authority — closes at issue-approval

The human gate **closes when the issues are approved.** `to-issues` quizzes the user on the slice breakdown and iterates *until approved*; at that moment the published, `ready-for-agent` issue becomes the authoritative spec. Downstream — `/implement` and `tdd` — **trusts the approved issue** and does not reopen the negotiation. This matches the tdd fork's "authority comes from the approved spec, not a live human." The gate sits at issue-approval; everything after executes against it.

### 4.3 Config home — `setup` owns `docs/agents/`

Per-repo config lives in `docs/agents/{issue-tracker,triage-labels,domain}.md`, written and owned by `setup`, indexed by an `## Agent skills` block in the project's `CLAUDE.md`. This is additive to our existing CLAUDE.md structure (gates, Standing Rules) and does not collide with the `.claude/rules/` path-scoped convention — `docs/agents/` is skill-config, `.claude/rules/` is code-rule. `setup` edits the existing `CLAUDE.md` in place; it never creates a competing `AGENTS.md`.

### 4.4 Glossary/ADR write-seam — `domain-modeling` is the writer

`domain-modeling` is the **sole writer** of the domain substrate, landing terms in `CONTEXT.md` and decisions in `docs/adr/` — the same `docs/adr/` convention this repo already uses ([stage-2-retro](metrics/stage-2-retro.md) references ADR-style decision records). Creation is lazy (the file appears when the first term/decision crystallizes). Every other skill only *reads* this substrate. This closes the dangling-writer problem the screening flagged: with `domain-modeling` in the set, the readers finally have a producer.

---

## 5. De-duplication resolutions

Three places where the suite overlaps assets we already have. Each needs a pick, not coexistence.

- **`grilling` vs `brainstorming`** (existing skill) — **resolved.** `grilling` adopted (`071d19d`); `brainstorming` retired (`4a3efd5`), no alias. They occupied the same niche (turn fuzzy intent into a sharp plan through dialogue), and `grilling` is the engine the rest of the suite routes to — keeping both would have meant two model-invoked interview skills with overlapping triggers (auto-fire nondeterminism). `brainstorming`'s one unique asset (its structured problem/scope summary) is now served by `to-prd`; its spec-writer coupling pointed at a retiring agent.
- **`to-prd` vs `spec-discipline` / `spec-writer`** (existing skill + agent). **Reconcile toward `to-prd`.** `to-prd` is the un-gated, synthesize-from-conversation PRD writer; `spec-writer` was the gated-agent equivalent. With the agent layer retiring (below), `to-prd` + the §4.2 issue-approval gate is the replacement. The `spec-discipline` 10-section rigor worth keeping should migrate into the PRD template, not survive as a parallel path.
- **Agent-dispatch retired.** The slash pipeline replaces the orchestration trio. **Cleanup (flagged, executed next session):**
  - Update [current-state.md](../.claude/memory/current-state.md) to record the model switch (currently it still describes "11 sub-agents" and "coordinator wiring (W4)" as live).
  - Mark for removal/archive the **coordinator-era** agent defs whose role the pipeline now owns: [coordinator.md](../.claude/agents/coordinator.md), [spec-writer.md](../.claude/agents/spec-writer.md), [implementation-engineer.md](../.claude/agents/implementation-engineer.md).
  - **Separate triage pass (not decided here):** the remaining nine agents (code-review, security-audit, i18n-auditor, brand-guardian, performance-auditor, qa-testing, git-operator, researcher) encode review/audit logic that doesn't map 1:1 to an adopted skill. Their inter-agent "ask the Coordinator to dispatch…" references break once the coordinator is gone, but several could become hooks or model-invoked skills. Decide their fate in a dedicated cleanup, not as a side effect of this adoption.

---

## 6. Deferred items

- **tdd-vocabulary decision.** Our `tdd` fork inlines the deep-module vocabulary (`deep-modules.md`) rather than calling `/codebase-design` like upstream does. Whether to **re-externalize tdd onto `codebase-design`** (one vocabulary source, DRY) or **keep it inlined** (self-contained, no cross-skill edge) is deferred until **Stage 2.5 exercises both** and shows whether the duplication actually drifts.
- **`prototype` / `handoff` / `implement`.** Not in the initial set. Adopt **if Stage 2.5 pulls them** — `prototype` when a state/UI question needs a runnable answer, `handoff` when a planning thread overruns the smart zone, `implement` if the per-issue execution wants a named skill rather than a bare CC turn. Adopt on demand, not speculatively.

---

## 7. Adoption order

Dependencies first, so each skill's edges resolved as it landed. **All steps below are done** — each annotated with its commit. (`tdd` previously adopted, `4a25429`.)

1. **`setup`** — bootstrap the config substrate (GitHub Issues tracker, label vocabulary, single-context domain layout). *De-brand:* renamed the skill itself (dropped `-matt-pocock-skills`); stripped the `# Setup Matt Pocock's Skills` heading; renamed the `triage-labels.md` table column header `Label in mattpocock/skills` → `Canonical role`. **Adopted `68ec242`.**
2. **`domain-modeling`** — the glossary/ADR writer. *De-brand:* none in body; kept `CONTEXT-FORMAT.md` + `ADR-FORMAT.md` companions. **Adopted `261a020`.**
3. **`codebase-design`** — the architecture vocabulary. *De-brand:* none (brand-clean). **Adopted `208561d`.**
4. **`grilling`** — the interview engine; the `brainstorming` de-dup was resolved here (retired in `4a3efd5`). *De-brand:* none (brand-clean). **Adopted `071d19d`.**
5. **`to-prd`** — conversation → PRD. *De-brand:* updated the `run /setup-…` pointer string to `/setup-engineering-skills`. **Adopted `952c836`.** (The `spec-writer` / `spec-discipline` reconciliation flagged here is still open — §5 bullet 2.)
6. **`to-issues`** — PRD → slices. *De-brand:* same setup-pointer string. **Adopted `37b14b2`.**
7. **`triage`** — issue/PR lifecycle. *De-brand:* same setup-pointer string; kept the `AGENT-BRIEF.md` **and `OUT-OF-SCOPE.md`** companions. **Adopted `af68d05`.**
8. **`improve-codebase-architecture`** — the parallel architecture entry point. *De-brand:* none in body (references `/codebase-design`, `/grilling`, `/domain-modeling` by slash-name); kept the `HTML-REPORT.md` companion. **Adopted `628c133`.**

**De-brand summary:** the suite is **mostly brand-clean inside skill bodies.** The branding to remove is concentrated in (a) the `setup` skill's name and heading, and (b) the `run /setup-matt-pocock-skills` **pointer strings** in `to-prd` / `to-issues` / `triage`. That's the whole surface.

---

## 8. Validation

**Stage 2.5 — the jobs-radar dashboard — is the end-to-end test of this adopted suite.** A real feature, taken from fuzzy intent through `grilling` → `to-prd` → `to-issues` → per-issue `implement`+`tdd`, with `improve-arch` available as the architecture loop, proves the pipeline holds together with no dangling edges and no resurrected coordinator. The deferred decisions in §6 resolve against what Stage 2.5 actually exercises.

---

## 9. Setup placement & run notes

`setup` is **placed** (de-branded) at [.claude/skills/setup-engineering-skills/](../.claude/skills/setup-engineering-skills/) so the bootstrap step-3 glob propagates it into target repos. Placement ≠ running — `setup` runs **per-target-repo** (jobs-radar first, for Stage 2.5). Two things to remember at run time:

- **Run-time prerequisite — create the GitHub labels.** After running `setup` in a target repo, create the five triage labels via `gh label create` (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). `setup` writes the role→label *mapping* (`docs/agents/triage-labels.md`) but **does not create the labels themselves**; the chain skills apply them with `gh issue edit --add-label`, which **errors on a missing label**. The mapping without the labels is a silent trap.
- **Lockstep rename.** The placed skill is `setup-engineering-skills`. The pointer strings inside `to-prd`, `to-issues`, and `triage` still say `run /setup-matt-pocock-skills` — when those three are adopted, their pointers must be updated to `run /setup-engineering-skills` in the same step. They were intentionally left untouched here because those skills aren't adopted yet (see §7).
