# Spec — #18 Semver acceptance harness (the workflow's end-to-end test)

**Issue:** #18 · **Status:** **Gate 1 APPROVED 2026-08-13** · **Drafted:** 2026-08-12
**Blocked by:** #17 (the harness under test), #19 (the measuring instrument)
**Replaces:** `HANDOFF-stage-3.md` — the Sovary calendar strip-down (retired, not run alongside)
**Build order:** #16 → #19 → #17 → **#18** → #24

## Gate 1 decisions (2026-08-13)

1. **Stage-3 replacement holds.** Sovary parity's oracle contains the scope judgment it was meant
   to falsify, so it is partly authored by the thing under test; a public corpus is not. Sovary is
   retired, **not** run alongside.
2. **Corpus: node-semver's fixtures, accepted with caveats. Do NOT precondition on a
   language-agnostic official corpus** — an official machine-readable semver conformance suite
   almost certainly does not exist, and preconditioning on one would stall this test on
   unavailability, which is the exact Stage-3 failure mode being escaped. The property that makes
   validation real is that the fixtures are **independent of the build** — nobody here wrote them.
   Two caveats recorded in §4a.
3. **Build from the semver.org spec text, not node-semver's source.** Reading the reference
   implementation is coding to the oracle and destroys the measurement.
4. **Thomas-side split — accepted.** He fetches, splits by hash-mod-2, commits only the visible
   half. The manual step *is* the integrity guarantee.
5. **Scope — accepted as specified.**
6. **Stage-3 documents corrected now.** Approving this issue decides the retirement, so marking
   `HANDOFF-stage-3.md` superseded and repointing `current-state.md`'s NEXT is executing the
   decision, not presuming it. The general reconcile mechanism remains #22.

---

## 0. Premise-check

**Stage 3's oracle was weaker than it looked.** The handoff calls parity with Sovary-1 "mechanical,
not a judgment," and then, two paragraphs later, correctly identifies that "deciding what is the
calendar (essential vs incidental) is synthesis, must stay main-thread frontier." Both cannot be
true of the same falsifier. Scope judgment sits *inside* the parity oracle, so the oracle is
partly authored by the thing being tested. A public conformance suite is authored by nobody here
and tunable by nobody here.

**Parity cannot measure generalisation.** ADR-0004 already records the limit: eval-green is
regression protection on the cases you labelled, never proof a change generalises. Parity against
one reference implementation is that same limit wearing different clothes. A visible/held-out split
is the only construction in this program that can distinguish *generalised* from *memorised*.

**What carries forward unchanged:** metrics declared before building; the "Thomas does not
pre-empt" rule; the two-halves delegation watch; the six-for-six all-human baseline as the
benchmark.

**Released:** `~/familienkalender` (a bare repo with a README) stops being the vehicle for this
measurement. `HANDOFF-stage-3.md` becomes a superseded document — it should be removed or marked
superseded as part of this work, because a live carrier doc for a retired plan at repo root is the
exact failure #22 exists to catch.

## 1. Purpose

Answer one question with a number: **did the harness pay off?** Operationally — of the defects
found while building a small real thing through the full workflow, what share was caught by the
scaffolding (agent self-check or an automatic gate) versus by Thomas in review? Baseline to beat:
**six catches, six human, zero agent-self** (#7 session).

A second, independent question the same run answers: does the built thing **generalise**, or did
it fit the cases it could see?

## 2. Why semver

- **A real oracle exists.** The spec is public, precise, and not written by anyone here.
- **Genuinely fiddly where it counts.** Prerelease precedence (`1.0.0-alpha.1 < 1.0.0-alpha.beta`),
  build metadata being ignored in precedence but not in equality, `^0.x` behaving unlike `^1.x`,
  `~` vs `^` on partial versions, `x`/`*` wildcards, hyphen and space ranges. These are the places
  implementations actually get wrong — so the held-out set has real discriminating power rather
  than being a formality.
- **Deterministic.** No eval needed; tests answer the question. Per the standards' "What's NOT a
  rule," an eval here would be built to look rigorous.
- **Small enough to finish** without dragging in auth, i18n, DB, or deployment — the confounds
  that would have made Stage 3's measurement hard to read.

## 3. Phases

### Setup

1. `git init` a fresh empty repo (`semver-probe`), outside `agentic-engineering-workflow`.
2. Bootstrap it with the #17 harness; run the emitted `setup-project.sh`.
3. Confirm `npm run lint`, `npm test`, and the CI workflows run green on an empty project.
   **If the harness cannot produce a working project here, that is finding one** — logged in the
   catch-log with who-caught, not quietly fixed as setup friction.

### Flow

PRD -> spec -> **Gate 1** -> build (`/tdd`) -> **Gate 2** (v0.5 review). No step skipped because
the subject is small. A gate that was never a real decision point is itself a finding, and #21
(gate-rejection logging) records why anything was rejected.

Scope of the library: `parse`, `compare`, `satisfies(version, range)`. Ranges limited to exact,
comparators (`<`,`<=`,`>`,`>=`,`=`), `^`, `~`, `x`/`*` wildcards, hyphen ranges, and `||` unions.
No coercion, no `sort`, no CLI — those add surface without adding oracle.

### Verification (internal — what the project checks about itself)

- The project's own tests, written test-first through the TDD gate.
- The propagated guards: lint, import guard, secret scan, exec-bit assertion.
- The `verification.md` checklist, **applied by the building agent to its own work** and reported
  item by item. This is the specific behaviour the harness is supposed to have bought: the
  provenance note on that list says all seven items came from human review. Whether the agent
  now self-applies them is a headline result.

### Validation (external — the held-out oracle)

Split a public conformance corpus into **visible** and **held-out**, 50/50 by a deterministic
rule. Green on held-out = it generalised. Green on visible while red on held-out = it fit the
cases it could see, which is **the single most valuable result this test can produce** and must
not be treated as a failure of the run.

## 4. How the held-out set is kept genuinely held out

Honour-system exclusion is not a mechanism. The construction:

1. **Thomas** (not the build agent) fetches the upstream corpus, applies the split rule, and
   commits **only the visible half** into the probe repo, plus the split rule itself in plain text.
2. The held-out half is **never written to disk in the probe repo** during the build. It is
   regenerated at validation time from the same upstream source by the same recorded rule.
3. Falsifier that the exclusion held, checkable after the fact rather than asserted:
   - the held-out file appears in no commit in the probe repo's history before the validation
     commit (`git log --diff-filter=A`);
   - the build made no network fetch of the upstream corpus (transcript + no lockfile/dep entry
     for it);
   - the split rule is deterministic, so the validation-time regeneration is reproducible.
4. Split rule: stable hash of the normalised case string, `mod 2`. Not "first half of the file" —
   conformance corpora are grouped by feature, so a positional split would hand the agent every
   prerelease case and no range case, or the reverse, and the held-out set would measure coverage
   rather than generalisation.

## 4a. The corpus, and the two caveats on what held-out green means

**Decided at Gate 1: node-semver's own test fixtures** (`npm/node-semver`, ISC-licensed,
machine-readable `[range, version, expected]` tuples covering exactly the fiddly cases in §2).
Licence-checked and provenance recorded in the probe repo before the build starts. The property
that earns it the job is independence: nobody in this program wrote it.

**Caveat 1 — implementation, not specification.** It encodes node-semver's interpretation,
including places where that extends or deviates from semver.org. A held-out failure therefore has
two possible readings — the build is wrong, or the build is right and node-semver is opinionated —
and each held-out failure must be adjudicated against the spec text before being logged as a
defect. Adjudication is a `human` judgment; log it as such.

**Caveat 2 — the corpus may be memorised, and this softens the generalisation number.**
node-semver is one of the most widely deployed packages in existence, so its behaviour is very
likely present in training data. A build agent can therefore pass held-out cases by **recall**
rather than by deriving them from the spec. This is not a reason to abandon the split, but it
means the two results have different strengths:

- **Self-catch ratio (primary) — robust to this.** A defect is caught by whoever caught it,
  regardless of where the knowledge that surfaced it came from. Memorisation does not corrupt the
  who-caught column.
- **Generalisation (secondary) — weakened.** Held-out green is consistent with "generalised" *and*
  with "recalled," and this test cannot separate them. Report it with the caveat attached rather
  than as a clean generalisation claim.

**Not blocking, and not fixed by trying harder here.** If the generalisation number ever becomes
the number that matters, the clean answer is a second probe over a **less-memorised
specification** — an obscure or recent format with a public conformance corpus and little training
presence. Recorded as the follow-on, not built now.

**Reading node-semver's source is out of bounds during the build** (Gate-1 decision 3). Build from
the semver.org spec text. The fixtures are consumed as opaque `[input, expected]` tuples; the
implementation that produced them is not read. Coding to the oracle would collapse both results at
once.

## 5. The measurement — the actual deliverable

**Every defect is logged in the catch-log (#19): what, who-caught, error-class.**

- `agent-self` — the building agent found it in its own work, before any gate fired.
- `automatic-gate` — lint, CI, a hook, a test, the import guard, the secret scan.
- `human` — Thomas, in review at either gate or in passing.

**Thomas does not pre-empt.** Seeing a defect and letting it reach the gate is the discipline. If
Thomas fixes something before the harness has had its chance, the number measured is "Thomas +
harness," and the whole run is worth less. This is uncomfortable by design; the handoff says so
and it remains the sharpest rule in this spec.

**Delegation routing is recorded too.** Which work went to a cheap subagent, and — the live test
of the falsifier discriminator — whether anything lacking a mechanical falsifier was delegated.
Note the known instrument limitation (verification.md catch 7, second bullet): subagent turns are
not recorded anywhere, so the honest metric is the **parent-side delegation count**, not model
turn share. Do not restate the unsatisfiable version of this criterion.

## 6. Acceptance criteria

| # | Criterion | Instrument |
|---|---|---|
| 1 | Probe repo reaches green internal tests + guards + lint through the documented flow, both gates exercised as real decision points | CI run on the probe repo; gate decisions recorded by hand until #21 exists |
| 2 | Corpus provenance + licence + split rule committed **before** the build | file present in the probe repo at the pre-build commit |
| 3 | Held-out exclusion verifiably held | `git log --diff-filter=A` on the held-out path + no upstream fetch in the build |
| 3a | node-semver's **source** was not read during the build | no fetch/read of the package source in the transcript; the fixtures are consumed as opaque tuples |
| 4 | Held-out pass rate reported — measured and explained, not required to be 100% — **with both §4a caveats attached**, and each held-out failure adjudicated against the spec text before being logged as a defect | the validation test run + the adjudication record |
| 5 | Catch-log has every defect with who-caught + error-class; agent-self share reported against six-for-six | the catch-log file, countable as-is |
| 6 | The building agent's `verification.md` self-application is reported item by item | the build's own review output |
| 7 | Delegation count + any falsifier-less delegation reported | parent-side count; `npm run observe --since=<pre-build sha>` for the model-share context |
| 8 | Friction logged | `docs/metrics/v1-success-metrics.md` friction table |

**AC1 wording note (catch 7 applied to this spec).** "Both gates exercised as real decision
points" is not observable by any tool — it is a judgment. It is stated here as a *reported
observation with its evidence*, not as a pass/fail criterion, precisely so it does not become a
fourth unsatisfiable AC.

## 7. Out of scope

- **Publishing the semver library.** It is a probe, not a product. It is not deployed and not
  consumed by anything.
- **Beating node-semver.** Held-out pass rate is a measurement of this workflow, not a competitive
  claim about the library.
- **Any Sovary or familienkalender work.** Explicitly released by this spec.
- **Instrumenting the classes the run surfaces.** That is #24, deliberately gated on this run's
  output so the instrumented set is measured rather than guessed.

## 8. Risks

- **~~No suitable external corpus exists.~~** Resolved at Gate 1 — node-semver's fixtures, with the
  §4a caveats. Superseded by the risk below.
- **Held-out green is recall, not generalisation** (§4a caveat 2). Unfixable within this probe. The
  primary measurement (self-catch ratio) is robust to it; the secondary one is reported with the
  caveat attached. A less-memorised specification is the clean follow-on if that number ever
  becomes the one that matters.
- **A held-out failure is node-semver being opinionated, not a defect** (§4a caveat 1). Mitigation:
  adjudicate against the spec text before logging, and log the adjudication as a `human` catch.
- **The result is uncomfortable.** A low agent-self share means the harness has not paid off yet.
  That is a valid, useful result and reporting it honestly is the point. The failure mode to guard
  against is quietly reclassifying human catches as gate catches.
- **Semver is too easy and nothing is caught.** A run with zero defects measures nothing. If the
  catch-log ends near-empty, the honest read is "the sample was too small," and the response is a
  second, harder probe — not a claim of success.
- **Thomas pre-empts by reflex.** Mitigation: the log records the moment of the catch, so a
  pre-empt is visible as a `human` row on something that never reached a gate.

---

## Gate 1 — APPROVED 2026-08-13

All four questions answered in §"Gate 1 decisions" at the top. Proceed after **#16 → #19 → #17**
have landed: setup, then the flow, then validation, then the report.

**First action when this issue starts, and it is Thomas's:** fetch the corpus, apply the
hash-mod-2 split, commit the visible half plus the split rule and provenance. The build does not
begin until that commit exists — it is the pre-build boundary AC2 and AC3 are measured against.
