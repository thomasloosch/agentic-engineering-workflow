# ADR-0004: Output evals — deterministic exact-match over human-labelled cases, local-first

**Status:** Accepted
**Date:** 2026-07-29
**Context source:** Issue #4 (eval harness), first applied to the jobs-radar scorer. PRD: `jobs-radar/docs/PRD-issue-4-eval-harness.md`; spec: `jobs-radar/docs/specs/issue-4-eval-harness.md`.

## Context

The workflow verifies the deterministic half of correctness well (TDD gate = tests;
the TDD-detector is a narrow trajectory eval). The missing half is output/quality
evals for components whose *behaviour in the field* is the risk surface, not their
unit-level logic. The jobs-radar scorer was the proving case: three recurring
failure classes (morphological-variant misses, a false-positive class) were each
caught per-incident in production because nothing pinned the scorer against
validated ground truth.

This ADR records the eval methodology so a second project needing evals starts from
a decision, not a rediscovery. The harness itself deliberately lives in the target
repo (jobs-radar), not here.

## Decision

Four settled choices, in force for any eval built under this workflow:

**1. Eval unit = per-(input, config) → discrete expected outputs.**
For the scorer: per-(posting, profile) → {verdict, decision tier}. Assert both the
outcome and *why* (which gate / which signal level). Checks at a different
granularity (e.g. config-level source binding) are separate checks, never folded
into the per-case unit.

**2. Deterministic exact-match assertions, not LM-judge.**
When expected outputs are discrete values, the eval is run-then-compare. LM-judge
is reserved for non-deterministic prose output — nothing in scope yet. Corollary
proven in the first application: *determinism must be pinned, not assumed* — the
scorer was LLM-free but still wall-clock-dependent (a recency bonus read
`Date.now()`), enough to flip a verdict across the threshold. Evals freeze every
ambient input (clock, environment) to values recorded in the dataset.

**3. Labels are the human's, never the agent's.**
The agent builds the runner and assembles candidates; the human supplies every
verdict. Candidates are presented *with the system's current output* so labelling
is confirm-or-correct against something concrete. Each label records who and when
(`labelled_by`, `labelled_at`); the runner refuses to run on unlabelled or
unattributed cases. Weighting is toward known failure classes, not representative
sampling. Labelled sets must be built from **full production-fidelity inputs** —
the first application found compressed summaries score differently from the real
postings they summarise, which would have manufactured phantom failure classes.

**4. Local-first in the target repo; methodology recorded here.**
The runner + dataset live in the project (`jobs-radar/eval/`, `npm run eval`);
this ADR records the pattern. Extraction into a reusable workflow-level harness is
YAGNI-gated on a second project needing evals. CI-gating is deferred until the
label set has earned trust — the same "don't guard unproven code" discipline as the
project's test suite. One eval mechanism per project: the harness subsumed the
prior ad-hoc labelled fixture rather than standing beside it.

Supporting mechanics from the first build, adopted as part of the pattern:

- **Real entrypoint only.** The eval calls the exact function production calls; a
  batch-vs-singleton equivalence test guards the shortcut of evaluating one case at
  a time. A guard/eval running through a proxy invocation path validates something
  that never runs in reality.
- **Reasons are read, not recomputed.** Where the system explains its own decision
  (log line, explanation export), the eval derives the expected axis from that —
  recomputing the decision in the runner is a reimplementation that can silently
  drift. Parse failures throw; they never guess.
- **Regression gate via a blessed baseline.** `pass→fail` against the committed
  baseline exits non-zero; an already-failing case is a *known gap* — reported,
  named, exit 0. Re-blessing is an explicit flag, never a side effect.
- **Per-failure-class reporting.** The aggregate hides the class the eval exists
  to catch; every report names failing cases per class.
- **Isolated fixtures, fail-closed.** Eval I/O happens in fresh temp directories
  with the production data path asserted as out-of-bounds before any write.

## Consequences

- Scorer regressions in the named classes are now caught locally before deploy,
  not per-incident in production; vocabulary/threshold tuning gets a fixed target.
- The human labelling pass is the critical path — the harness is idle until labels
  land, by design. The runner's refusal on unlabelled cases makes that visible
  rather than silently running on placeholder truth.
- A second project wanting evals copies the four decisions and the mechanics list;
  if that copy step recurs, extraction to a shared harness becomes a live issue.
- Forward links: eval results are a signal #5 (observability) should trace. The
  `--json` output is a verification input for **whoever is verifying — human review
  or CI**, not for a planned command: #10's `/goal` was struck (ADR-0006), which
  also carries the revisit trigger should verification ever run without a human in
  the loop.
