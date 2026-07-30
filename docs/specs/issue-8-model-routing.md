# Spec — #8 Model routing (rescoped)

**Issue:** #8 · **Status:** Gate 1 — awaiting approval · **Date:** 2026-07-30

---

## 0. Rescope note

The issue's *"per-subagent model overrides"* bullet was **mis-scoped at filing**: it assumed a
named custom-agent layer this repo retired in **ADR-0003**. `.claude/agents/` is absent, and
nothing here defines agents to hang `model:` frontmatter on.

Rescoped to **session + workflow routing + rule-driven delegation**. Lever B uses the
Agent/Task tool's `model` parameter on the *general-purpose* subagent — it does **not**
revive the named custom-agent layer, so ADR-0003 stands unamended.

## 1. Purpose

Two drivers from the issue: the economics lever (reserve frontier for high-complexity work)
and concrete pain (hitting usage limits at high load). The measured baseline says the lever
is entirely unexercised — `npm run observe` across both projects:

| project | opus-4-8 | opus-5 | fable-5 | sonnet-4-6 | haiku |
|---|---|---|---|---|---|
| workflow | 2341 | 552 | 148 | 98 | **0** |
| jobs-radar | 6518 | 1516 | 69 | — | **0** |

Everything defaults to Opus and never gets downshifted. Current rates: Opus 5 **$5/$25** per
MTok · Sonnet 5 **$3/$15** ($2/$10 intro to 2026-08-31) · Haiku 4.5 **$1/$5** · Fable 5 **$10/$50**.

The fix is to invert the default rather than rely on discipline, and to make delegation of
mechanical work a standing rule rather than a case-by-case judgment.

## 2. Acceptance criteria

**Measured, not theorized.** Apply A+B, then re-run `npm run observe` and show:

1. **Frontier turn count drops** as a share of new turns after the change.
2. **Haiku stops being zero** — a non-zero Haiku/Sonnet turn count appears from delegated
   subagent work.
3. **`"model"` default is set and verified against the committed artifact** (or, if it lands
   in unversioned global settings, the *policy* is versioned in the standards doc and the
   setting's location is recorded).
4. **The delegation rule is in the standards doc**, `@`-imported, with the task-class split
   and the size floor stated.
5. **Verification is explicitly fenced out** of the routed classes, in the rule text.
6. **SSOT guard stays green** (still exactly 12 rules — this is guidance, not a rule 13).

## 3. Out of scope

- **Verification / acceptance checking.** The highest-risk target, and routing it is
  ADR-0006's revisit trigger — a separate decision, not this slice. The governing principle
  here is **delegate the generation, keep the verification on main.**
- **Reviving the named custom-agent layer.** A `.claude/agents/` layer with pinned models
  would enable richer routing but re-opens ADR-0003. Recorded as a **revisit item**, its own
  ADR if ever wanted — not built.
- **Enterprise keys** (`availableModels`, `enforceAvailableModels`, `modelOverrides`) — admin
  surface, not solo-relevant.
- **`fallbackModel` / `effortLevel`** — real keys, adjacent, but not this issue's problem.
- **Automatic classification of task complexity.** The rule is a documented task-class list a
  reader applies, not a classifier.

---

## The three levers

**A · Default-model flip.** `"model": "sonnet"` in settings. Frontier becomes opt-*in* via
`/model opus`, reserved for design, architecture, ADRs, and judgment calls. Verified settable:
the key is `model`, a string taking a family alias or full ID; precedence user → project →
local. **Placement decision needed** — see below.

**B · Rule-driven delegation** to a cheap general-purpose subagent, as a standing rule:

| delegate to cheap subagent | keep on main frontier thread |
|---|---|
| test generation | spec / architecture / ADRs |
| mechanical refactors (tests as the check) | judgment calls |
| codebase grep-and-summarize | **verification / acceptance** (fenced, ADR-0006) |
| boilerplate scaffolding | |
| fixture assembly | |
| commit-message drafting | |
| doc formatting | |
| test-run summarizing | |

**Size floor:** delegate bounded chunks only. A two-line edit costs more to hand off than to
do inline — the handoff has to carry context the main thread already holds.

**C · `opts.model` in fan-out workflow scripts** — cheap tier per deterministic stage.

## Open decision for Gate 1

**Where does the `"model"` default live?** Three options, and it changes what "verify against
the committed artifact" can mean:

- **`~/.claude/settings.json` (global)** — matches the actual problem (*every* project
  defaults to Opus), but is unversioned and unreviewable. The policy would be versioned in the
  standards doc while the setting isn't.
- **`.claude/settings.json` (project, committed)** — versioned and verifiable, but this repo
  has no committed settings.json today, and it would impose Sonnet on any clone.
- **`.claude/settings.local.json` (project, gitignored)** — per-machine, matches your guess,
  but scopes the fix to one repo when the burn spans both.

**Recommendation: global**, because the burn is cross-project, with the *policy* recorded in
the versioned standards doc so the reasoning survives even though the setting doesn't.

---

**Gate 1.** Does the rescope and the acceptance shape hold — and which placement for A?
On approval: apply A+B, use #30's stemming-vs-per-variant spike as lever B's proving ground
(each prototype in its own cheap subagent, both compared against the eval on the main thread),
then re-run `observe` and report the delta.
