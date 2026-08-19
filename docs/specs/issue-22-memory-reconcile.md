# Spec — #22 Memory reconcile

**Issue:** #22 · **Status:** Gate 1 — awaiting approval · **Date:** 2026-08-19
**Unblocked by:** #16, #17, #19, #26 (all closed) · **Reference shape:** `second-brain-audit` (MIT), via #29

---

## 0. Premise-check

**The drift is not hypothetical and it is frequent.** `current-state.md` has been
hand-corrected **7 times since 2026-08-12** — roughly once per working session. Every
correction was reactive: someone noticed the doc was wrong *after* reading it.

Two corrections were not cosmetic:

- it led with **"NEXT: Stage 3 — strip Sovary to calendar-only"** after that plan was
  retired, so the orientation doc's first instruction was the wrong next action;
- it named a five-issue chain as upcoming when four fifths of it had shipped.

That is the specific failure mode: a file read at session start *because it is
trusted*, asserting work that is finished or plans that are dead.

**What is mechanically checkable, verified by running the checks by hand first:**

| assertion type | count in the file today | check |
|---|---|---|
| issue references (`#N`) | 21 distinct | `gh issue view N --json state` |
| ADR references (`ADR-NNNN`) | 6 distinct | file exists in `docs/adr/` |
| commit SHAs | 11 distinct | `git cat-file -e <sha>^{commit}` |

All 11 SHAs currently resolve; several referenced issues are closed. **That last fact
is the whole design problem** — see below.

**Not the retired session ritual.** `/start-session`, `/close-session` and
`/health-check` were retired in Part 4 for firing regardless of whether they had
anything to say. This reports only mismatches: zero mismatches means zero output, so
it cannot become nagging. ADR-0002's amendment also matters here — lifecycle hooks
*do* fire and block now, so a hook is a real option, but this stays a script the
closing turn or CI invokes (see D2).

## 1. The central design constraint

**Referencing a closed issue is not drift.** Most of the file's `#N` mentions are
history — "#16, CLOSED, here is what it fixed" — and flagging those would produce a
report that is wrong far more often than right.

A checker that cries wolf trains you to ignore it, which converts it into a guard
that protects nothing. That is `overbroad-assertion` (verification.md catch 3a,
promoted 2026-08-19 on three instances), and this tool is unusually exposed to it
because the prose is written by hand and varies.

**So the rule is: flag only assertions about the FUTURE that are contradicted by the
present.** Concretely, drift is:

| pattern | why it is drift |
|---|---|
| `NEXT:` … `#N` where N is **closed** | the orientation doc's primary instruction is dead work |
| `parked` / `pending` / `blocked on` / `awaiting` … `#N` where N is **closed** | a stated blocker that no longer exists |
| `ADR-NNNN` with no matching file in `docs/adr/` | a decision cited that cannot be read |
| a 7–40 hex SHA that is not a commit | a claim of evidence that cannot be checked |
| `Last updated: <date>` older than the newest commit **to this file** | the freshness marker itself is stale |

Everything else is left alone, including every past-tense reference to closed work.

## 2. Design decisions to confirm

**D1 · Narrow by default, and prove the narrowness.** The tool ships with a
false-positive test: run it against the *current, correct* `current-state.md` and
assert it reports **zero** drift. If a future edit makes it noisy, that test goes red
before anyone learns to ignore the output. This is catch 3a's mechanical check
applied to the tool itself.

**D2 · A script, not a hook — and not CI-blocking.** `scripts/check-memory-drift.sh`,
run on demand and at session close. Deliberately **not** a blocking CI gate: the doc
being briefly out of date is not a reason to fail a build, and a gate people bypass
is worse than a report they read. It exits 0 with findings printed, and non-zero only
on a checker error (fail-closed on its own malfunction, per catch 2a).

**D3 · State vs event, adopted from `second-brain-audit` (#29).** The deeper fix is
structural, not a checker: `current-state.md` mixes **state** (one current value,
must be *replaced*) with **events** (timestamped, *appended*). Appending a state
creates two answers with nothing marking which is current — which is exactly how
"NEXT" ended up pointing at retired work while the real next action sat lower down.

Proposed: a `## Current State` block at the top holding only replaceable facts (what
is NEXT, what is blocked, what is in flight), and the historical narrative below it
as an append-only log. The checker then only has to police a small, well-defined
region rather than the whole prose file.

**This is the higher-value half and it is also the more invasive one** — it
restructures the orientation doc. Flagged as a gate question rather than assumed.

**D4 · No auto-fix.** The tool reports; a human edits. Auto-editing an orientation
doc from a heuristic is how you get a confidently wrong orientation doc.

## 3. Acceptance criteria

| # | Criterion | Instrument |
|---|---|---|
| 1 | Detects a `NEXT:` pointing at a closed issue | fixture with a closed-issue NEXT line |
| 2 | Detects a nonexistent ADR reference and an unresolvable SHA | fixture with both |
| 3 | Detects a `Last updated` older than the file's newest commit | fixture + `git log -1 -- <file>` |
| 4 | **Reports ZERO drift on the real, current file** | run it against `current-state.md` in CI-less local run |
| 5 | **Mutation check:** stub the drift detection to always-clean and confirm 1–3 go red | catch 3 |
| 6 | A checker error (unreachable `gh`, unreadable file) exits **non-zero and says so**, never silently clean | fixture with `gh` unavailable |
| 7 | Zero findings produces zero output | run against a clean fixture |

**AC4 and AC6 are the two that matter.** AC4 is what keeps it from becoming noise;
AC6 is catch 2a — this program has now logged four guards that reported clean while
not actually running.

## 4. Out of scope

- **Auto-fixing** (D4).
- **Policing prose accuracy in general.** Only the five mechanical patterns in §1. "Is
  this paragraph still true?" is judgment and stays human.
- **Other memory files.** `lessons.md` is curated prose with no future-tense
  assertions; the catch-log has its own integrity rules.
- **A blocking CI gate** (D2).

## 5. Risks

- **Noise → ignored → useless.** The dominant risk, mitigated by D1's zero-false-
  positive test and by the deliberately narrow pattern list.
- **The structural change (D3) is invasive.** It rewrites the doc most likely to be
  read cold by a future session. If it goes wrong, orientation gets worse, not better.
- **`gh` dependency.** Issue-state checks need network and auth. Per AC6 that must be
  a loud failure, not a silent skip — the same trap the four dead hooks fell into.

---

## Gate 1 questions

1. **D3 — restructure `current-state.md` into `## Current State` + append-only log?**
   It is the higher-value half (it prevents the drift rather than detecting it) and
   the more invasive. Do it in this issue, or ship the checker first and restructure
   separately once the checker shows which regions actually drift?
2. **D2 — on-demand + session-close, not CI.** Agreed, or do you want it in CI as a
   non-blocking report?
3. **Scope of the pattern list (§1).** Five patterns, chosen to be near-zero false
   positive. Anything you have seen drift that they would miss?
