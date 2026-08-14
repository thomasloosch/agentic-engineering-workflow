# Catch-log — agentic-engineering-workflow

Per-project defect log: what was caught, who caught it, what class of error it
was. Two jobs — the measuring instrument for #18's self-catch ratio, and the
loop's **up**-direction: a recurring class becomes a promotion candidate to the
centre. Spec: #19.

**Status against #19's acceptance criteria.** AC1/AC3/AC4/AC5 satisfied by this
file. **AC2 (propagation into a fresh project) closes with #17**, not here —
this file has no manifest entry of its own yet because bootstrap hasn't been
taught to place it. **AC6 (populated live by a real build) is #18's job.**

**Not a mirror.** Per #17's Gate-1 decision D2a, `verification.md` and
`code-review.md` are propagated mirrors and carry a banner saying so. This file
is the opposite kind of artifact — project-owned data whose entire purpose is
to accumulate locally — and carries no such banner. Bootstrap will propagate
its schema/legend as a skeleton with zero rows; the rows below are this
project's own history and do not travel.

---

## who-caught (closed set — exactly these three)

- **`agent-self`** — the building agent found it in its own work, **before any
  gate fired**. A red test the agent just wrote is *not* this — that's
  `automatic-gate`. This column exists to measure whether propagated learning
  changed behaviour; blurring the boundary makes it unmeasurable.
- **`automatic-gate`** — fires without a human present: lint, CI, a hook, a
  test, an eval, a guard.
- **`human`** — Thomas, including "noticed in passing." The case most likely
  to go unlogged, and the one that most inflates the agent-self share if it
  does.

## error-class (controlled, growable — add a legend line when you add a class)

| class | meaning | origin |
|---|---|---|
| `fail-open-guard` | a guard/detector reports "clean" while not actually tracking or checking what it claims to | #16 |
| `wrong-invocation-path` | a test observes the artifact through a path production doesn't use, and misses what that real path would catch | verification.md catch 5 (catch 4 is its documented special case) |
| `vacuous-test` | a test/guard stays green even with the thing it protects stubbed out or broken | verification.md catch 3 |
| `unobservable-AC` | an acceptance criterion names no instrument that can actually read it | verification.md catch 7 (origin: #8) |
| `premise-drift` | an issue or plan is built against a premise that moved since it was written | #8 §0 rescope; Stage-3 handoff, "3 of 5 issues" |
| `stale-propagated-asset` | a mirrored/propagated file has silently diverged from its canonical source | jobs-radar's standards doc (#16) |
| `silent-truncation` | a hardcoded or incomplete enumeration silently drops entries instead of failing loud | #13 |
| `artifact-vs-effect` | the committed/reported state looks right; the running/actual effect is not what it claims | verification.md catch 1; catch 7's third bullet |
| `unsafe-test-isolation` | a test operates on live/shared state instead of an isolated fixture, risking corruption on failure | verification.md catch 6 — **added here**, no seed-table entry existed for it |

## Promotion rule

**Threshold: 3 rows of one class in this project's log, or 2 rows across 2
projects.** Standard 7's rule-of-three, not a fresh number invented here — two
instances can be coincidence; the third is where the shape becomes legible.

On threshold, the class becomes a **promotion candidate**. A human decides
where it goes, routed by what the class names:

- names a **principle** → a `docs/checklists/verification.md` entry, filed
  under an existing parent if it's a special case of one (that doc's own
  maintenance rule)
- names a **rule** → a standards change (SSOT-guard implication — see #20)
- names a **mechanical check** → a CI step (ADR-0006 ground 2)

**Not automated, and that's a decision, not a gap.** Deciding whether a
recurring class generalises is judgment; it fails the falsifier-discriminator
membership test, so there is nothing here to delegate or gate. #25 records the
automated up-path as designed-but-gated.

## Hygiene

- **Promoted rows collapse.** Once a class is promoted, its contributing rows
  are removed and replaced by one line:
  `class -> promoted to <target>, N rows (X human, Y agent-self, Z
  automatic-gate), <date>`. Full narrative detail stays in git history at the
  commit that recorded them — never reconstructed here — but the who-caught
  breakdown travels with the collapsed line itself. Without it, AC5
  ("computable from the file alone") degrades on every promotion: the count
  would be right until the first collapse, then quietly wrong forever after,
  which is worse than not promoting at all. Discovered doing the first
  promotion below, not designed in up front — recorded here so the next one
  doesn't rediscover it.
- **Cap: 50 live rows.** Excess archives to
  `docs/metrics/catch-log-archive-<YYYY-MM>.md`, oldest first.
- **No commentary column.** Reasoning belongs in the promotion target or the
  commit message.
- **Append in the turn the catch happens.** A log written at session close is
  written from memory, and memory rounds toward the flattering number.

---

## Log

| date | what | who-caught | error-class | outcome |
|---|---|---|---|---|
| 2026-08-13 | Bootstrap re-run emptied the asset manifest (37 → 0); sync then reported a clean bill of health. Root cause: a file's mere presence on disk was read as "local override," and the manifest was truncated before re-derivation, so preserved-and-unrecorded meant permanently dropped. | agent-self | fail-open-guard | fixed+regression-case |
| 2026-07-22 | The guard's own tests still passed with the guard stubbed to always-pass — the negative cases were vacuous. | human | vacuous-test | fixed |
| 2026-07-22 | New `*.sh` scripts land at file mode 100644 from the agent's file-creation path; exec bit is never set by that path. | human | wrong-invocation-path | fixed |
| 2026-07-22 | Guard tests invoked it via `bash <script>`, which cannot observe file mode — tests stayed green while the real, git-invoked hook was inert. | human | wrong-invocation-path | fixed |
| 2026-07-17 | A negative test mutated the live git index when a `cd` failed silently under `set -e` (test ran against live state, not an isolated `mktemp -d` fixture). | human | unsafe-test-isolation | fixed |
| 2026-08-13 | #16's own re-run regression test stayed green when the prior-manifest-load code was disabled — every file fell back to "untracked but identical to the repo" and got adopted, so the entry *count* survived by a different path. The test proved less than it looked like it did. | agent-self | vacuous-test | fixed+regression-case |
| 2026-08-13 | — | — | `artifact-vs-effect` | promoted -> verification.md catch 1, 3 rows (2 human, 1 agent-self), 2026-08-13 |

**Provenance note on the six 2026-07-22 / 2026-07-17 catches.** Backfilled from
the `#7` session (issue created 2026-07-17, closed 2026-07-22; verification
lessons committed `aa22072`, 2026-07-22) to put the six-for-six all-human
baseline (cited in `verification.md`'s provenance note and ADR-0006) into this
instrument rather than leaving it as a sentence in prose. All six were seeded
as `human`, and were kept at the original six-item granularity rather than
pre-collapsing catch 4 into catch 5 at seed time (even though `verification.md`
documents one as the other's special case), so the historical count stayed
traceable to its source before any promotion touched it. Two of the six (the
committed-artifact and confirm-fired catches) are now the human half of the
collapsed row below — see the note on AC5 immediately after.

**AC5 after a collapse.** Counting the `who-caught` column directly now
undercounts: the promotion below removed three individual rows (2 human, 1
agent-self) from the table, and their breakdown lives only in the collapsed
row's `outcome` cell, not in three separate `who-caught` cells. This is a real
cost of the collapse rule, not an oversight — keeping N rows alive forever so a
retrospective count stays a single column-scan would defeat the cap that keeps
this file from becoming `patterns.md` again. The rule going forward: **when a
promotion fires, fold its rows' who-caught breakdown into the collapsed row's
outcome text** (done above), so a full-corpus count is still "from the file
alone, no external context" — it costs one extra line to read, not a
git-history lookup. As seeded here: 6 individually visible rows
(agent-self: 2, human: 4) **plus** the collapsed row's breakdown
(agent-self: 1, human: 2) = **agent-self: 3, human: 6, automatic-gate: 0**
across the full 9-catch corpus — a retrospective backfill plus today's `#16`
build, not `#18`'s measurement. `#18` measures the *next* run against this
baseline; this count is not that number.

---

## Promotions fired

**2026-08-13 — `artifact-vs-effect` reached 3 rows** in this project's log: the
two 2026-07-22 catches (secret guard committed 100644; confirming it fired
means more than a green test) plus the 2026-08-13 UNC exec-bit staging catch.
Per the promotion rule this is a candidate. **Resolution: already promoted** —
this class *is* `verification.md` catch 1 (and the third bullet of catch 7);
the first two catches are that catch's own origin, so there is no new
standards artifact to create.

What this demonstrates is narrower than "a new rule got written," and that is
the point: (a) threshold-detection fires correctly against real rows, not a
staged example; (b) the maintenance rule's *"filed under an existing parent"*
branch, which a synthetic demo would likely have skipped in favour of the more
dramatic "new entry" branch; and (c) one data point toward
`verification.md`'s own maturity signal — the 2026-08-13 recurrence landed as a
special case of an *already-named* principle rather than requiring a new one.
One instance is not that signal being met (`verification.md` is explicit that
it isn't, and stays that way here too), but it is the shape of instance that
would eventually add up to it.

The three contributing rows are collapsed in a follow-up commit, per the
hygiene rule; their full text is recoverable at the commit that first recorded
them.

---

*Archive: none yet — 6 individual rows + 1 collapsed promotion line = 9 catches
accounted for, cap is 50 live rows.*
