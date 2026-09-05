# Spec — #N <title>

**Issue:** #N · **Status:** Gate 1 — awaiting approval · **Date:** YYYY-MM-DD

> Copy this file to `docs/specs/issue-N-<slug>.md`. The italic lines are prompts —
> delete each one as you replace it with your answer; the **bold** lines are the
> claims you are answering and stay. Sections 0–7 are the shape the specs in this
> repo already have; adapt or drop what does not apply.
>
> **§4 is the exception: it is required, and an empty §4 is a gate-1 rejection.**
> There is deliberately no CI check for it — a guard could only confirm the heading
> exists, and a heading with nothing real under it is exactly the spec this section
> exists to prevent.

---

## 0. Premise-check

*Check the claim the issue rests on against the repo as it is now, not as the issue
described it. Where the two disagree, record the disagreement — a premise that does
not survive contact is a gate-1 finding, not an edit to make quietly.*

## 1. Purpose

*One paragraph. What does shipping this let someone do, or what question does it
answer?*

## 2. The decision

*The seam, the interface, or the option taken, and what was rejected to get there. A
spec with no rejected option did not make a decision, it recorded an intention.*

## 3. Slices

*Vertical, one behaviour each, each red-to-green on its own. A table of `# | slice |
what it covers` is usually enough.*

## 4. Validation strategy

**Mandatory.** Four claims to make. Half a page total — if this runs longer than §5,
you are writing the test plan rather than the strategy.

**Every acceptance criterion names its instrument.**

*Point at §5. Before writing a criterion, ask what tool or person reads it and whether
that thing can actually see the property claimed: an AC nothing can observe is
**unsatisfiable**, not merely unmet (verification checklist, catch 7). Where the
honest answer is "a person judges it", the criterion is **reported with evidence, not
gated** — say so in the row rather than implying a tool that does not exist.*

**What the oracle can and cannot prove.**

*Name the oracle — the thing you check answers against. Then state both halves, the
second in as much detail as the first: what a green result would **not** establish,
and which of your claims that weakens. If there is no independent oracle, say so
plainly here. A passing suite must never be left to imply one.*

**Verification and validation, kept apart.**

*Label every check as one or the other. This is a standing constraint (#32), not a
formatting preference.*

- *Verification — the project's own tests, lint, guards, and self-applied checklists.
  All authored by whoever built the thing, so none of it is independent. "The suite is
  green" is verification, always.*
- *Validation — evidence from something the author did not write: a held-out set, a
  public corpus, a reference implementation, a second party running the gate.*

*If the validation side is empty, write that sentence out loud. It is a legitimate
answer for some work and a serious one; disguising it as verification is not. And when
you do claim a source is independent, give the check that shows the independence
actually held, runnable afterwards by someone else — `git log --diff-filter=A` on the
held-out file, no upstream fetch in the build. A promise is not a mechanism.*

**The mutation check.**

*Name it: the specific thing you will break, and which suite must go red when you do
(catch 3 and 3b). "Break something and check" is not a mutation check; "stub
`satisfies` to `return true` and `range-exclude` must redden" is. An assertion never
observed to fail is not yet evidence.*

## 5. Acceptance criteria

| # | Criterion | Instrument |
|---|---|---|
| 1 | *…* | *what reads it* |

*Every row carries an instrument. A row whose only honest instrument is a human
judgment is marked reported-not-gated, per §4.*

## 6. Out of scope

*Including anything deliberately not built — record the reason, so a later session
does not "fix" the omission.*

## 7. Risks

*What would make this land and still be wrong.*

---

## Gate 1 questions

*The decisions you want made before any code is written. If you have none, you have
not found the ambiguity yet — look again at §2 and §4.*
