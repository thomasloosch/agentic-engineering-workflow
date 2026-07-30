# ADR-0005: The TDD gate does not record its own development; CI carries that weight

**Status:** Accepted
**Date:** 2026-07-30
**Context source:** Issue #13, suggested-scope item 3 — "decide whether the gate should record its own cycles. This is the interesting one and is **not** obviously yes."

## Context

The TDD gate (`.claude/tdd/`) certifies test-first discipline in every project that
bootstraps it. Every other component built under this workflow is developed through
the gate. The gate itself never has been: there is no `scripts/tdd.js` equivalent
here, so changes to `tdd-detector.js` / `tdd-recorder.js` / `tdd-baseline.js`
produce no gate verdict.

Issue #12 is the live cost of that asymmetry: a real defect in `classify()` sat in
canon and propagated to consuming projects.

The reflex fix is to make the gate record itself. #13 flagged that as non-obvious,
and it is. #12 has since closed, so the stated blocker ("wait until #12 part 2
lands, it changes what a valid baseline is") is resolved and the decision is live.

## Decision

**The gate does not record its own TDD cycles. Its discipline is enforced by
non-bypassable CI plus review, not by self-application.**

The reason is not the awkwardness of self-reference — the mechanics are fine, the
recorder writes a log and the detector reads it. The reason is *when* it breaks:

> A gate with a bug in it could misjudge the development of the fix for that bug.

Self-recording is least trustworthy in precisely the case you need it — a detector
whose `classify()` is wrong (exactly #12) would render a verdict on the commit
fixing `classify()`. A green verdict there is indistinguishable from a green verdict
from a correct detector, so the signal carries no information in the failure mode
it exists to catch. Adding it would buy the *appearance* of self-application while
leaving the real risk untouched.

What actually protects downstream projects is that the gate's tests run somewhere
non-bypassable. Before #13 they ran in **no** CI workflow at all — 30 tests, on the
one component every project trusts, executed only when a human remembered the
command locally. That, not the missing self-recording, was the real gap.

So #13 ships:

- `npm test` as a single entry point (`scripts/run-tests.mjs`), discovering suites
  dynamically and failing loudly on empty discovery. Node's runner skips
  dot-prefixed directories, so `.claude/tdd/` is invisible to a bare `node --test`
  — which found 1 test instead of 31 and called it a pass. The prior documented
  invocation hardcoded two files and had already gone stale, silently skipping the
  third suite #12 added.
- `npm run lint` with eslint, mirroring the rules this repo distributes. It found a
  real `prefer-const` violation in the import guard on its first run.
- Both wired into `guards.yml`, so every push and PR runs them.

## Consequences

- The gate's tests are now non-bypassable. A `classify()` regression fails CI on the
  push that introduces it, which is strictly stronger than a self-verdict.
- The gate remains the one component not developed through itself. That asymmetry is
  now deliberate and recorded, not an oversight — if someone proposes self-recording
  again, the burden is to explain how a buggy gate judging its own fix carries
  information.
- This repo gains its first dependency (eslint, dev-only) and therefore a
  `package-lock.json` and an `npm ci` step in CI. Accepted: publishing Standard 1
  ("lint clean before commit") with nothing to run was the sharper inconsistency.
- Reviewers of gate changes should read the tests as the evidence of test-first
  discipline, since no recorder verdict will exist for them.
