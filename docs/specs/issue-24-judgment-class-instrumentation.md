# Spec — #24 Judgment-class verification instrumentation

**Issue:** #24 · **Status:** Gate 1 — draft, recommends **HOLD** (do not build; re-gate on #34) ·
**Date:** 2026-09-07 · **Depends on:** #18 (CLOSED, tally read below), #34 (OPEN, the actual gate)
**Continues:** ADR-0006 · **Adjacent to:** #25 (up-promotion), #32 (verification/validation split)

---

## 0. Premise-check

**#24's own gate is a decision rule, not a scheduling flag:** *"Build only after #18 reports its
self-catch tally. Then instrument the measured dominant classes... record honestly which classes
remain irreducibly human."* That rule needs a distribution of **human** catches to point at. #18's
tally is **9 defects: 5 `agent-self`, 4 `automatic-gate`, 0 `human`.** Applying #24's own rule to
its own input finds no dominant human class, because there are none. Four findings say the gate did
not open — it moved.

1. **The needed measurement does not exist yet.** `0 human` is absence-of-opportunity — nobody was
   reviewing during the build (#18 Gate 2 report, restated by #34). Instrumenting "where human
   catches cluster" from zero human catches is the same guess Stage 3 made, wearing a real number.
2. **The dominant `agent-self` contributor is not a new class.** 3 of 5 came from one instrument,
   the mutation step, already codified as `verification.md` catch 3/3b — "stub it, watch RED, read
   the failure message." #18 is evidence existing advisory guidance pays off when actually run, not
   evidence of anything new to build. Generalizing semver's one-project stubs into a reusable CI
   instrument now would itself be guessed.
3. **The bespoke guards' silence is the same problem, applied inconsistently if ignored.** Import
   guard, secret guard, catch-log staleness check caught nothing inside the probe, only in the
   workflow repo. An untriggered check in a 9-defect sample is not evidence the check is unneeded,
   for the same reason 0 human is not evidence the harness won. Treating one zero as signal and the
   other as noise, to assemble a target list, is not principled.
4. **ADR-0006 stands unamended, and #18 does not trip its revisit trigger** (model routing to a
   cheaper model, or verification run without a human in the loop — neither live). #18's gates were
   still human-reviewed; only within-slice review was absent, and that was already the norm. #24
   doesn't need this trigger to fire, but #18 adds no force to it either.
5. **#34 is filed, scoped, and cheap, for exactly this gap** — same harness, the missing comparison:
   both parties reviewing the same build, catches attributed to whoever is first.

**Conclusion: closing #18 does not satisfy #24's stated gate.** #24 stays gated — moved from #18 to
#34, not opened by #18.

## 1. Purpose

Once a real human-catch distribution exists, replacing guessed judgment-class targets with measured
ones is the whole point of #24 — that reasoning is sound and unchanged. This spec's narrower job
today is to correct #24's gate before it is misread as open, and to preserve the instrumentation
design so #34's output can be spent immediately when it lands, rather than re-derived.

## 2. The decision

**Do not build CI instrumentation from #18's tally now.** Re-gate #24 on #34 producing at least one
genuine human-caught defect, in a build where the harness ran unmodified and both parties had a
chance.

**Rejected: build against the present tally, treating mutation-share as the dominant class.**
Already covered by catch 3/3b (finding 2); nothing to instrument that isn't already advisory
guidance, and generalizing single-project stubs now would repeat the guessed-set failure #24 exists
to avoid.

**Rejected: read `0 human` as "no judgment classes exist," close #24 wontfix.** `0 human` is
absence-of-opportunity, not absence-of-class (finding 1); `verification.md`'s own maturity signal is
unmet — still producing new items, all from human/e2e review. Judgment classes plainly still exist;
we lack their measured distribution, not their existence.

## 3. Design for later (not slices to build now)

Marked explicitly speculative, per the #25 precedent of recording a gated design so it need not be
re-derived. Once #34 reports a per-class human-catch tally, each class with real recurrence becomes
a candidate slice, one behavior per slice, each its own PR:

- a mechanizable class → a CI step, scoped to that class only (ADR-0006 ground 2);
- a class that resists mechanization even after a real attempt → recorded honestly in
  `verification.md` as irreducibly human — as valuable a result as an automated check (#24's own
  framing).

Re-validate this sketch against #34's actual output before any slice starts — a design written
before the data exists is a hypothesis, not a backlog.

## 4. Validation strategy

**No code ships from this spec** — its only claim is the premise-check in §0, so validation here
means: is that claim re-derivable by another reader, not just restated by this one?

**Oracle.** None independent — this is a human judgment about a measurement, read against #24's own
gate text. The strongest available check: another reader can reproduce §0's four findings from
`docs/gate-2-issue-18.md` and `gh issue view 24` alone, no new data collection.

**Verification vs validation (#32).** Verification: does §0 apply #24's own stated rule correctly
to #18's actual numbers — checkable by any reader against the two source documents. Validation:
none — no independent party or held-out corpus judges a re-gating argument. Said plainly, not
disguised as verification.

**Mutation check.** Not applicable to code. The discriminating-power analogue: would a *different*
tally satisfy #24's gate — e.g. 3 human catches across two classes? Yes. The claim in §0 fails on
the actual `0`, not on the general shape of any tally, so it is not vacuous.

## 5. Acceptance criteria

| # | Criterion | Instrument |
|---|---|---|
| 1 | The four premise-check findings in §0 are read and either agreed or rebutted before this spec is treated as closing #24's re-gate | human, Gate 1 reviewer — **reported, not gated** |
| 2 | #24's issue text is updated to name #34, not #18, as the blocking dependency | `gh issue view 24`, diffed against this spec's §0 conclusion |
| 3 | No code, CI config, or `verification.md` content ships from this spec | `git diff` shows only the new spec file |
| 4 | The §3 forward design is preserved verbatim as the starting point when #34 closes, not re-derived from scratch | human, at that future Gate 1 — **reported, not gated** |

## 6. Out of scope

1. Building any CI instrument now — the whole point of §2's decision.
2. Editing #24 or #34's issue text directly from this spec — the Coordinator/human acts on the
   recommendation; this spec only makes it.
3. Respeccing #34 — this spec confirms #34 is the correct gate, it does not alter #34's scope or
   acceptance criteria.
4. Reopening ADR-0006's `/goal` question — its trigger is unchanged and not tripped by #18 (§0.4);
   noted, not reargued.
5. Retroactively adding a human-review arm to #18 — not possible on a closed run, which is
   precisely why #34 exists as a new one rather than a reopening of #18.

## 7. Risks

- **Honest one: this may not be worth building at all, even after #34.** The catch-log's up-
  promotion path (#25) is already delivering judgment-class-adjacent coverage incrementally through
  ordinary builds — two promotions (catches 3b, 8) since #18 alone. If that organic path keeps
  working, a dedicated #24 build could be redundant. Worth checking when #34 closes, not assumed now.
- **Re-gating twice.** #34 is one probe, one project; it could land with a low human count too.
  Mitigation: #34's own AC4 (pre-registered falsifier) should also pre-register what count counts
  as "enough to instrument," so a second re-gate is decided in advance, not discovered again.
- **Parking indefinitely reads as no progress.** It isn't — #25's up-promotion path keeps running
  meanwhile. Named so a future reader doesn't mistake a held #24 for a stalled program.

---

## Gate 1 questions

1. **Re-gate #24 from #18 to #34 — agree?** Recommend yes; §0 shows #18's tally cannot satisfy
   #24's own decision rule, and #34 was filed for exactly this gap.
2. **Edit #24's issue text now, or leave it until #34 closes?** Recommend edit now — #18 closed
   reads as a green light by default, and leaving that unedited invites the guessed-set build #24
   exists to prevent, by anyone reading the issue at face value.
3. **Keep the §3 forward design, or delete it until #34 closes?** Recommend keep, marked
   non-committed — #25 set this precedent and it worked; the alternative is re-deriving the same
   sketch later for no gain.
4. **Does #25's up-promotion path plausibly already cover #24's ground, making a dedicated build
   unnecessary regardless of #34's outcome?** No recommendation — genuine open question, flagged in
   §7, worth deciding once #34's data exists rather than on priors now.
