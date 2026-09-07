# Spec — #21 Gate-rejection logging

**Issue:** #21 · **Status:** **Gate 1 APPROVED 2026-09-07 — RESCOPE** · **Drafted:** 2026-09-05
**Depends on:** #19 (catch-log, CLOSED — but see §0), #18 (semver acceptance harness, **CLOSED 2026-09-07** — see decision 4)
**Composes with:** #30 (**CLOSED 2026-09-07**; `docs/specs/TEMPLATE.md` shipped in `53c3bfd`)

## Gate 1 decisions (2026-09-07)

1. **Rescope, agreed.** Do not extend catch-log's `who-caught` set and do not open a second
   file now. #19's own Gate 1 decision 3 set the precondition (wait for #18 to run) and it is
   honored as written.
2. **Interim convention named as standing practice.** Recording rejection/amendment reasoning
   inline, under a dated "Gate 1 decisions" heading at the top of the spec — exactly this
   section, in this file — is the convention until the trigger below fires. No new file, no
   new schema.
3. **Revisit trigger, unchanged from §2:** build the structured instrument when #18 produces
   its first real gate rejection, or when three gate-1/gate-2 rejections have been recorded via
   this interim convention — whichever comes first.
4. **Flag, not acted on:** #18 closed today (2026-09-07), after this spec was drafted. Its
   Gate 2 report (`docs/gate-2-issue-18.md`, AC8) records a Gate-1-rejected sub-scope
   (`range-parse`, excluded on principle). Whether that satisfies "#18 produces its first real
   gate rejection" is a judgment call this spec does not make — the trigger names no closed
   vocabulary for what counts as a "real" rejection versus an ordinary Gate 1 scoping decision,
   unlike catch-log's closed three-value `who-caught` set. Check this before assuming the
   trigger is still unfired.

---

## 0. Premise-check

**The precondition #21 needs was already set, deliberately, and is still unmet.** #19's
own Gate 1 decision #3 (2026-08-13) considered exactly #21's shape sketch — extend
catch-log's `who-caught` with `gate-1`/`gate-2` values — and declined for now:

> "a gate-1 rejection is really a `human` catch with a location — folding it in now risks
> countability for no proven gain. Revisit after #18 has run and the fit can be judged
> against real rows."

`gh issue view 18` returns **OPEN**. #18 has not run. The condition #19 itself set for
revisiting this design question has not been met. Building #21 as sketched now means
deciding — blind — the exact question #19 asked to defer until real data exists to decide
it against.

**A factual claim in #21 does not hold.** The issue states `docs/metrics/v1-success-metrics.md`
"already names 'gate-1 rejections' as a friction metric." `grep -ri "gate-1\|gate 1"
docs/metrics/*.md` returns nothing. That file's "Friction moments" and "Agent override
rate" rows are the nearest analogues, and neither mentions gates. The file itself is a
legacy v1/Stage-2 artifact — it references `/health-check` and the "self-learning loop
(lessons.md, patterns.md)," both retired per current standards. This half of #21's
justification should be struck, not built around.

**What's newly true since filing, and cuts the other way.** #30 is landing right now
(`docs/specs/TEMPLATE.md`, uncommitted in this tree) and already encodes the first concrete,
structured gate-1 rejection reason this repo has written as a rule: *"§4 is the exception:
it is required, and an empty §4 is a gate-1 rejection."* That is a real rejection-reason
class arriving independent of #21, before any log exists to catch it — direct evidence the
underlying need is live, even while the specific mechanism stays premature.

**Net read.** The problem is real (a rejected spec is revised in place and the reason
evaporates) and the historical evidence for it is genuine (verification.md catch 7's three
#8 instances; #8's own §0 rescope; the Stage-3 handoff's "3 of 5 issues" drift). The
mechanism sketch is not yet buildable on its own terms.

## 1. Purpose

A spec or v0.5 rejected at gate 1 or gate 2 is revised in place today, and the reason for
rejection leaves no durable, countable trace — only prose in whichever spec happened to
record it. Recurring reasons (unobservable AC, premise drift, scope too large) can't be
seen as a pattern because no row exists per rejection.

## 2. The decision

**Rescope. Do not extend catch-log's `who-caught` set now** (respects #19 decision #3,
unmet precondition). **Do not open a second file now** (same reason — fold-vs-separate is
exactly the question being avoided blind).

**Do name, explicitly, the interim practice already in use.** #19, #22, and #30's own specs
each record amendment/rejection reasoning inline under a dated "Gate 1 decisions" heading.
That costs nothing new — it is already house style. This spec's contribution is to name it
as the standing convention until the trigger below fires, and to strike the broken
metrics-file claim rather than build around it.

**Revisit trigger (decidable, not open-ended):** build the structured instrument when #18
produces its first real gate rejection, **or** when three gate-1/gate-2 rejections have
been recorded via the interim convention — whichever comes first. Three, by analogy to the
catch-log's own rule-of-three (Standard 7's logic: two instances may be coincidence, the
third is where the shape becomes legible). At that point fold-vs-separate is decidable
against real rows, exactly the bar #19 set.

**Rejected alternative:** build the structured log now, seeded only from the three
historical incidents #21 cites (catch 7's #8 instances, #8's rescope, Stage-3's drift) —
mirroring #19 §6's "an empty instrument cannot be shown to work" seeding move. Rejected
because those three are already fully recorded prose (verification.md catch 7, #8's own
§0, the Stage-3 handoff); turning them into log rows adds a thinner second copy without new
information — the exact duplication #19's own out-of-scope list warns against ("GitHub
issues track work; this tracks who found it").

## 3. Slices

| # | slice | behaviour |
|---|---|---|
| 1 | name the interim convention explicitly and correct the stale metrics-file claim | this spec |
| 2 (deferred) | build the structured instrument once the trigger fires | a future issue, re-spec'd against real #18 rows |

There is only one buildable slice today; slice 2 is explicitly not this issue's work.

## 4. Validation strategy

**Every AC names its instrument** (§5).

**Oracle:** none independent — this is a scope decision, not a code change. Verification is
"did this spec correctly represent #19's decision, #18's state, and the metrics file's
contents," checked by re-reading those three artifacts directly (§0, all reproducible via
`gh` and `grep`).

**Verification vs validation.** Verification = the premise-check itself: `gh issue view 18
--json state`, and `grep` against `docs/metrics/*.md`, both shown in §0 and rerunnable by
anyone. Validation = none available — whether "wait for #18" was the right call can only be
judged once #18 runs, which is the entire reason for waiting rather than guessing.

**Mutation check.** Not applicable to a scope decision (no code to break). Nearest
analogue: would this premise-check read differently if #18 had already shipped? Yes — the
fold-vs-separate question would become decidable — which shows the recommendation is
conditioned on real, checkable state, not a boilerplate "not yet."

## 5. Acceptance criteria

| # | Criterion | Instrument |
|---|---|---|
| 1 | this spec accurately states #19's decision #3 and #18's current state | `gh issue view 18 --json state` (OPEN); `docs/specs/issue-19-catch-log.md` decision #3, quoted verbatim above |
| 2 | the v1-success-metrics.md claim is checked and shown false | `grep -ri "gate-1\|gate 1" docs/metrics/*.md` — no matches |
| 3 | the interim convention (rejection reasoning inline under "Gate 1 decisions") is named as standing practice until the trigger fires | **reported, not gated** — a human habit; checked at the next spec carrying a real gate-1 amendment or rejection |
| 4 | the revisit trigger is a decidable condition, not an open-ended "later" | this file, §2 — read the trigger sentence |

## 6. Out of scope

- Building the structured log, file, or schema change now (§2).
- Repointing or fixing `v1-success-metrics.md`'s broader staleness — flagged, not fixed.
  That file's other legacy references (`/health-check`, the retired self-learning loop) are
  a separate cleanup, plausibly its own #22-shaped ticket, not this one.
- Deciding fold-vs-separate-file — explicitly deferred to the trigger in §2, not decided
  provisionally here.

## 7. Risks

- **Honest "not worth building yet" case, stated directly.** Everything #21 wants is
  either (a) already happening informally in each spec's "Gate 1 decisions" section, or (b)
  blocked on data that doesn't exist. Formalizing now means designing a schema against zero
  or three thin historical rows — the exact under-seeded instrument #19 §6 refused to ship.
- **The interim convention has no forcing function.** "Keep doing what we're doing" means
  some specs may carry a "Gate 1 decisions" section and others may not, with no compliance
  check. Mitigation: naming it here is a smaller but real improvement over the current
  unstated default.
- **Waiting has a cost too.** If #18 stalls indefinitely, the eventual instrument has fewer
  real rows to seed from. Mitigation: the interim convention itself accumulates seedable
  rows in the meantime — nothing is lost by waiting, only deferred.

---

## Gate 1 questions

1. **Rescope, agreed?** Wait for #18 to ship, or for three inline-recorded rejections,
   before building a structured gate-rejection log. Recommend yes — this directly honors
   #19's own Gate 1 decision, which set this exact precondition and has not yet been met.
2. **The stale metrics-file claim.** Correct it only here, or also edit the GitHub issue
   text on #21 itself? Recommend leaving the issue text as the historical record and
   letting this spec supersede the claim — editing others' issue text isn't this spec's job.
3. **The interim convention.** Is "record rejection reasoning inline under a dated Gate-1-
   decisions heading" an acceptable placeholder while waiting, or do you want something
   lighter or heavier in the meantime?
