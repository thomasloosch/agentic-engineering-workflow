<!-- Posted to issue #18 on 2026-09-07. Kept here because the issue is the
     conversation and this repo is the record; a decision that lives only in a
     comment thread is one `gh` outage away from being unciteable. -->

# Gate 2 — the semver acceptance harness

The build is complete and validated. This is the report the run existed to produce.

## The measurement

**9 defects, 5 `agent-self`, 4 `automatic-gate`, 0 `human`.**
Baseline to beat: **6 defects, 6 human, 0 agent-self** (#7 session).

Read with the caveats, which matter more than the ratio:

- **0 human means 0 opportunity.** Nobody was reviewing during the build. This is not 5–0, and treating it as one would be the exact self-flattery the catch-log was built to prevent.
- **3 of the 5 `agent-self` catches came from a single instrument** — the mutation step — and each was a branch the corpus *provably cannot reach*. One technique carries most of the result.
- **The workflow's bespoke guards caught almost nothing inside the probe.** The 4 `automatic-gate` catches were eslint twice and the held-out validation twice. The import guard, the secret guard and the catch-log staleness check were silent for the entire build. They did catch things — but in the workflow repo, not here.
- **Sample of 9, one project, one author.** Nothing here supports a general claim about the harness.

## Held-out validation: 155 / 160 (96.9%)

Cases the build never saw. Thomas generated the split; the pin came from the visible half's recorded `upstreamSha`, so both halves are the same upstream commit. Recorded in `docs/VALIDATION-RESULT.md` **before** any fix.

Five failures, two root causes, both adjudicated against semver.org and both judged genuine defects rather than node-semver opinionation:

1. **Strict mode did not trim whitespace.** semver.org admits neither surrounding whitespace nor a `v` prefix; both are node-semver leniencies. The `v` prefix was already accepted in strict because `valid-versions` demanded it, so refusing the trim was inconsistent about the same authority.
2. **Loose mode did not accept a hyphenless prerelease** (`1.2.3pre`). Loose was in scope by gate decision; the implementation covered prefix and whitespace tolerance and stopped.

**Neither was learnable from the visible half, and the second case is the strongest single argument in this run for holding data back.** Every whitespace case in the visible half carries the loose flag — the one strict case landed in the half I could not see. And the visible half *did* contain the hyphenless-prerelease shape, exactly once: `["<1", "1.0.0beta", true]` in `range-exclude`, where the version fails to parse, `satisfies` returns `false`, and `false` is the expected answer. The feature was exercised only in a case where getting it wrong produces the right result. A 100%-green visible suite was compatible with the defect throughout.

That half is now spent. Both defects are permanent regression tests, because it cannot serve as an independent check again, and the post-fix 160/160 is fitting, not generalisation.

## Acceptance criteria

| # | Criterion | Status | Evidence |
|---|---|---|---|
| 1 | All 164 in-scope visible cases pass | **met** | `node scripts/validate.mjs visible` → 164/164; 206 tests, 7 suites |
| 2 | Lint, import guard, secret guard green | **met** | lint 0; import guard 0; secret guard verified live — it blocks a planted AWS key, wired via `core.hooksPath` |
| 3 | Stubbing `satisfies` reddens `range-exclude`; stubbing `compare` reddens `comparisons` | **met** | 0/50 and 0/14 respectively, restored to 164/164 |
| 4 | Held-out regenerated with the same filter, both counts recorded | **met** | filter imported from `test/corpus.mjs`, not restated; 164 of 494 visible, 160 of 488 held-out |
| 5 | Pass rate reported with caveats, every failure adjudicated | **met** | `docs/VALIDATION-RESULT.md` |
| 6 | `held-out.json` in no commit before validation | **met** | `git log --diff-filter=A -- corpus/held-out.json` → first appears at the validation commit |
| 7 | Every defect in the catch-log with who-caught and error-class, countable from the file alone | **met** | 9 rows, counted mechanically |
| 8 | Both gates exercised as real decision points | **reported, not gated** | see below |

**AC8.** Gate 1 produced three answered questions and a rejected sub-scope (`range-parse`, excluded on principle). More tellingly, a gate moment arose *mid-build*: auditing the corpus before slice 2 showed the approved spec's options premise was wrong — `loose` is exercised 33 times in scope, not zero, and `includePrerelease` 18 times, not 24. That went back to you as a decision with three options and changed the scope of four slices. A rubber-stamped gate does not produce that.

## What the run says about the workflow

The probe was the artifact; these are the findings.

- **The harness's own distribution was broken.** `run-tests.mjs`, the test entrypoint bootstrap installs in every project, had never run anywhere but the repo that authored it. Four defects, three of them the same shape — code written and tested only in its authoring layout. The worst: `node --test` silently skips every file and exits 0 when `NODE_TEST_CONTEXT` is inherited, so the runner reported "OK: all N suite(s) passed" having executed nothing.
- **Bootstrap shipped a lint script with no way to run it** — eslint configured and declared nowhere, so a project looked linted and never had been. And `setup-project.sh` printed its check marks and exited 0 on a shell without node, having written nothing.
- **The corpus splitter defaulted to a moving ref** while its comment claimed it was pinned. The handover command would have cut the held-out half from a different upstream and still printed a pass rate. Caught by reading the script, not by any gate — and that half can only be spent once.
- **Two error classes reached the rule of three and were promoted**: `vacuous-test` → verification.md catch **3b**, `silent-truncation` → catch **8**. Notable that none of `vacuous-test`'s three instances was found by a gate; each needed a deliberate mutation step, which is why 3b prescribes reading the failure message rather than just watching it go red.
- **`to-prd` assumes tracker infrastructure a fresh project does not have.** Recorded in the PRD rather than worked around.

## The decision

Accept or reject this run as Gate 2. Closing #18 also unblocks **#24** (judgment-class instrumentation) and **#25** (up-promotion), both of which were gated on this tally.

Three things I would not conclude from it: that the harness is now validated (sample of 9), that 96.9% demonstrates generalisation (node-semver is almost certainly in training data), or that `agent-self` 5 / `human` 0 is a ratio between two parties who both had a chance.
