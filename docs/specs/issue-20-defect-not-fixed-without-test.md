# Spec — #20 A defect isn't fixed until its failing case is a permanent test/eval entry

**Issue:** #20 · **Status:** Gate 1 — draft, recommends BUILD (small) · **Date:** 2026-09-05
**Depends on:** #19 (catch-log, CLOSED) · **Adjacent to:** verification.md catch 3 / 3b · **No overlap with #30** (in flight — that spec governs what a *spec* must contain; this governs what a *fix* must leave behind)

---

## 0. Premise-check

The issue's own filed premise-check (Standard 2 requires evidence but not *permanence*;
catch 3 is adjacent, not equivalent; the TDD gate doesn't cover post-fix discipline) still
holds — nothing in the repo has since covered this ground. Its one stated weakness — "one
strong incident, not three" — no longer holds, and in the direction that *strengthens* the
case, not weakens it.

`.claude/memory/catch-log.md` now carries 27+ rows recorded since #19 shipped. Reading the
`outcome` column against real code/config defects (excluding process mishaps like a
mis-posted GitHub comment, which no test suite could hold), at least four are `fixed` with
**no** regression case, by the row's own description:

- the manifest hash-substitution defect (2026-08-17): *"Caught by reasoning through the
  hash model before committing, not by a test."*
- the piped exit-status miscount (2026-08-14): ground truth checked manually, no persistent
  assertion added.
- the ADR-0002 runtime-premise error (2026-08-14): a documentation fix with nothing to test
  — a legitimate exception, not a counterexample (see §6).
- the ADR-0007 `node_modules` claim (2026-08-18): explicitly *"recorded as untested rather
  than resolved by argument."*

**A structural finding, not just more evidence:** this pattern will never trip the
catch-log's own rule-of-three promotion, because that rule counts recurrence **by
error-class**, and "no permanent case left behind" is an attribute of the **outcome**
column, cutting across `artifact-vs-effect`, `premise-drift`, and others alike. The
mechanism #20 asks about structurally cannot surface the gap it's being asked to close.
That argues for adding the entry directly, on the accumulated qualitative evidence, rather
than waiting on a threshold that cannot fire.

**Not redundant with catch 3b** (promoted 2026-09-05, same corpus). 3b asks whether an
assertion that *exists* can fail; #20 asks whether one exists *at all* after a defect fix.
3b is the second question; #20 is the first and temporally prior one.

**Recommendation, following the issue's own filed recommendation:** land as a new
verification.md entry now. Not Standard 13 (an unforced change to `EXPECTED_RULES=12` for
one clause-sized rule). Not a Standard 2 clause (that slot is #30's, for a distinct
concern — spec content, not fix discipline; stacking a second unrelated clause into Rule 2
this session dilutes it the same way a 13th standard would, without even the guard cost).

## 1. Purpose

Today a defect can be closed on Rule 2's evidence bar — "ran it, output was X" — without
that evidence surviving the session. The exec-bit bug (verification.md catches 4/5)
recurred as a new symptom for exactly this reason, and the catch-log now shows it is not a
one-off: four more code/config defects since have been fixed by reasoning or manual check
with nothing left in the suite to catch a recurrence.

## 2. The decision

Add one new **top-level** verification.md entry (not nested under catch 3's family — the
maintenance rule's test is "is this a special case of a principle already on the list?",
and the answer is no: 3/3b ask whether an assertion is *good*, this asks whether one
*exists*). State the rule and a mechanical check mirroring 3b's shape but pointed at
existence: *before closing a defect, confirm a test/eval case exists that reproduces it and
fails against the pre-fix code, and that it is committed, not run-and-discarded.*

**Rejected alternative:** add a `missing-regression-case` error-class to the catch-log so
the gap becomes self-surfacing via the existing threshold rule. Tempting, but YAGNI per the
same logic #19 applies to automating its own promotion path — this session's manual read of
the outcome column *was* the detector, and it worked. Build the mechanized version only if
this entry ships and the gap keeps recurring unnoticed.

## 3. Slices

| # | slice | behaviour |
|---|---|---|
| 1 | write the checklist entry + mechanical check | verification.md gains one new parent |
| 2 | demonstrate discriminating power against one real historical row (the manifest hash-substitution catch, §0) — show the rule would have required action there | a human reads the entry against that row and agrees |
| 3 | confirm no other file moves | `scripts/check-standards-ssot.sh` still reports 12 |

Slice 2 is the mutation-equivalent for a documentation change: an entry every existing row
already satisfies has no discriminating power (vacuous, catch 3's own standard applied to
itself).

## 4. Validation strategy

**Every AC names its instrument** (§5).

**Oracle:** none independent. Same as every existing verification.md item — applied by the
building agent to its own work, per the doc's own admitted Maturity signal ("every one of
the [existing] catches arrived from human/e2e review rather than agent self-check"). This
entry does not change that; stated plainly rather than implied otherwise.

**Verification vs validation.** Verification here is: does the entry read as a genuinely
new parent under the maintenance rule's own test (checked by a human, §5 AC1), and does it
have discriminating power against at least one real row (§3 slice 2, checked by re-reading
the catch-log). There is no validation source — no independent party or held-out corpus
judges a checklist-wording change. Said out loud, not disguised as verification.

**Mutation check.** Not literally applicable — no code to break. The analogue used here:
would this entry have been satisfied by everything already being fine? No — the manifest
hash-substitution row (§0) is a real counterexample, so the entry discriminates.

## 5. Acceptance criteria

| # | Criterion | Instrument |
|---|---|---|
| 1 | verification.md gains one new **top-level** entry (not nested under 3/3b), with the maintenance-rule reasoning written inline | the file; the maintenance-rule test applied by the human reviewer at gate 2 |
| 2 | the entry states a mechanical check mirroring 3b's shape, aimed at existence not quality | the file |
| 3 | at least one real catch-log row is shown to fail the new rule, demonstrating discriminating power | the manifest hash-substitution row (§0), read against the entry — **reported, not gated**, a human judgment |
| 4 | `scripts/check-standards-ssot.sh` still reports 12 rules; `docs/standards/engineering-standards.md` untouched | `bash scripts/check-standards-ssot.sh` |
| 5 | catch-log's schema is untouched — no new error-class, outcome value, or who-caught value | diff of `.claude/memory/catch-log.md`'s rule sections before/after |

## 6. Out of scope

- Standard 13, or a Standard 2 clause (§2 — reasons given).
- A new catch-log error-class or any schema change (§2 — YAGNI, rejected alternative).
- CI enforcement that a regression case exists (no test-count-diff gate proposed; that is
  catch 8's territory if it's ever needed, and there's no evidence yet that it is).
- Retroactively adding regression tests for the four historical rows identified in §0 —
  this spec names the pattern, it does not schedule a backfill project.
- Documentation-only defects with nothing testable (the ADR-0002 row, §0) — the rule
  applies to defects a test/eval *could* have caught, not to every catch-log row.

## 7. Risks

- **Advisory-only, same as the rest of verification.md.** Nothing here suggests this entry
  will be self-checked before human review any more reliably than catches 1–8 have been.
  Not a defect unique to this spec — named because the issue asked whether it would be
  "unenforceable in practice." Answer: enforceable to the same degree as the rest of the
  doc, no worse, no better.
- **Self-grading conflict of interest.** The agent that fixed the defect often also judges
  whether the regression case is "permanent enough" — the same risk #19 §9 names for
  `agent-self` over-claiming.
- **Honest "not worth building" case.** If this entry goes as unread as the others, the
  cost is one paragraph for no behaviour change. The mitigating fact: the cost is small
  (no code, no schema), and §0's four corroborating rows show the gap actually recurring —
  positive expected value even under the pessimistic prior.

---

## Gate 1 questions

1. **New top-level entry vs. a lettered child of catch 3.** Recommend new top-level parent
   — it answers "does a case exist," logically prior to 3/3b's "is the case any good."
   Filing it under 3 would make that family answer two different questions. Agree?
2. **Slice 2's demonstration row.** Using the manifest hash-substitution catch as the
   worked example, or a different one from §0's list? Any of the four works; the manifest
   one is the clearest single-cause case.
3. **Backfill.** Given four corroborating rows, is there appetite for a *separate*,
   later ticket to add regression cases for them? Recommend not bundling it here — real
   but distinct work.
