# Spec — #30 Mandatory "Validation strategy" section

**Issue:** #30 · **Status:** Gate 1 — awaiting approval · **Date:** 2026-08-19
**Enforces:** #32 (standing constraint) · **Composes with:** #21 (gate-rejection logging)

---

## 0. Premise-check

**The habit already exists, unevenly, and nothing requires it.** Every spec written
in this program carries an acceptance-criteria table with an explicit **Instrument**
column, and #18 goes furthest with a §4a stating what its oracle can and cannot
prove. So the practice is real — but it is a convention I have been following, not a
requirement, and there is no spec template in this repo at all. `docs/specs/` holds a
shape, not a rule.

**The failure it prevents is documented three times over.** verification.md catch 7
records three unsatisfiable acceptance criteria in #8, all authored by the same hand
that then tried to satisfy them. A spec review asking *"which tool reads this?"*
catches all three for free.

**And it recurred during this program**, which is the stronger evidence: #18's
headline AC (a self-catch ratio) was unsatisfiable until #19 built the instrument to
measure it. That was caught at spec time precisely *because* the instrument column
forced the question — the practice working, informally, once.

**Not a duplicate of #21.** #21 records *why a spec was rejected*, after the fact.
This changes *what a spec must contain*, so fewer are rejectable for this reason.
They compose: recurring `unobservable-AC` rejections in #21's log would be evidence
this section is being skipped or done badly.

## 1. What the section must contain

Four items, each drawn from something the good specs here already do:

1. **Every AC names the instrument that reads it.** An AC no tool can observe is
   *unsatisfiable*, not merely unmet.
2. **What the oracle can and cannot prove.** #18's §4a is the model: it states plainly
   that held-out green may be recall rather than generalisation, and which of its two
   results that weakens. A spec with no independent oracle must say so rather than let
   a passing suite imply one.
3. **The mutation check.** How you would know the verification is not vacuous — stub
   the thing and confirm the suite goes red (catch 3).
4. **Verification vs validation, kept distinct.** Internal suite green ≠ correct
   against an independent oracle. This is where #32's standing constraint becomes
   reviewable per spec instead of a slogan in an issue.

## 2. Where it lands — the decision

Three options, and the recommendation is deliberately *not* the most enforceable one:

| option | cost | why / why not |
|---|---|---|
| **(a) `docs/specs/TEMPLATE.md`** + a line in the standards | cheap | discoverable, unenforced. The template makes the section the default rather than a thing to remember |
| **(b) a clause under Standard 2** | no SSOT-guard change (`EXPECTED_RULES=12` stays) | Rule 2 is the natural parent — "verification is the final step". Costs citeability: it becomes a sentence, not a rule |
| **(c) a CI guard** that fails a spec lacking the heading | mechanical | **rejected** |

**Recommendation: (a) + (b). Explicitly NOT (c).**

A guard can only check that a heading *exists*, never that the content under it is any
good — and a spec with an empty "Validation strategy" heading would pass it while
being exactly the spec the requirement exists to prevent. That is presence-vs-effect,
the class this program has logged **six** times and promoted to verification.md catch
1. Adding a guard that certifies a heading would be committing that error knowingly,
in the mechanism meant to prevent it.

The quality of this section is a gate-1 judgment. It should stay one.

## 3. Acceptance criteria

| # | Criterion | Instrument |
|---|---|---|
| 1 | `docs/specs/TEMPLATE.md` exists with the four items as prompts, not prose to fill in blindly | the file |
| 2 | Standard 2 gains a clause requiring the section, without changing the rule count | `scripts/check-standards-ssot.sh` still green (12 rules) |
| 3 | The clause reaches projects | it is in the `@`-imported standards doc, which bootstrap propagates |
| 4 | Applying the template to an existing spec produces no contradiction — i.e. #18 and #26 already satisfy it | read both against the template; note any gap as a finding |
| 5 | **No CI guard is added** for this | absence, deliberate — recorded here so a future session does not "fix" the omission |

**AC4 is the real test.** If the template cannot be satisfied by the two best specs
already written, the template is wrong, not the specs.

## 4. Out of scope

- **A CI heading-check** (§2, rejected with reason).
- **Retrofitting every existing spec.** New specs use it; old ones stay as they are
  unless touched.
- **Enforcing it on PRDs or issues.** Specs only — an issue is allowed to be a sketch.

## 5. Risks

- **It becomes a box to tick.** A section written to satisfy a template, saying "tests
  will pass", is worse than nothing because it looks like rigour. Mitigation: the
  template asks *questions* (what reads this AC? what can your oracle not prove?)
  rather than offering headings to fill.
- **Standards doc edits are `@`-imported**, so this reaches every project. That is the
  point, and it means the wording gets one careful pass rather than an iterative one.

---

## Gate 1 questions

1. **(a) + (b), and explicitly not (c)** — agreed? The argument against the CI guard is
   that it can only certify a heading exists, which is the presence-vs-effect class
   this program keeps logging.
2. **Standard 2 clause wording** — it edits the `@`-imported standards doc, so it
   propagates to every project. Want to see the exact sentence before it lands?
3. **AC4** — if #18 or #26 turns out *not* to satisfy the template, do I fix the
   template or note the gap and leave the specs alone?
