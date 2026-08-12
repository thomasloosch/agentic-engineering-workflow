# Spec — #19 The catch-log

**Issue:** #19 · **Status:** Gate 1 — awaiting approval · **Date:** 2026-08-12
**Blocks:** #18 (its measuring instrument) · **Propagated by:** #17 · **Feeds:** #20, #21, #24, #25

---

## 0. Premise-check

Grepped every candidate home before proposing a new file. Nothing covers this:

| existing artifact | what it is | why it isn't this |
|---|---|---|
| `docs/checklists/verification.md` | 7 distilled parent principles | the *destination* of promotion, not a running record; explicitly not per-incident |
| `.claude/memory/lessons.md` | cross-project prose principles | its own header says "curated, not append-only" — wrong shape for a tally |
| `docs/metrics/v1-success-metrics.md` | friction log | friction = "I had to intervene manually"; different axis from "who caught this" |
| `docs/metrics/stage-2-patterns.md` | archived snapshot | not live |
| `patterns.md`, `agent-compliance.log` | retired self-learning loop | retired in Part 4 for bloat — the thing this must not become |

**The retirement is the most important premise here.** The old self-learning loop was removed
because it accumulated and nobody read it. Four properties keep this different, and each is a
design constraint, not a hope: a **fixed narrow schema** (no free-text growth), **append-only with
a cap** (excess archived), a **closed who-caught vocabulary** (the column has to be countable or
the whole artifact is pointless), and **existence in service of one specific decision** — promotion
— rather than in service of "learning."

**Ordering.** verification.md catch 7: an acceptance criterion the certifying tool cannot observe
is *unsatisfiable*, not merely unmet. #18's headline criterion is a self-catch ratio. So this ships
before #18, or #18's main AC is unsatisfiable by construction — the exact mistake catch 7 records
three instances of.

## 1. Purpose

Two jobs, deliberately one artifact:

1. **Measuring instrument** for #18's self-catch ratio, and for #24's decision about *which*
   judgment classes are worth instrumenting.
2. **Loop improvement** — the **up** direction of inheritance. A project's recurring error class
   becomes a candidate for promotion to central standards or `verification.md`. Today inheritance
   is one-directional: the centre pushes down and nothing comes back except by someone remembering.

## 2. The artifact

`.claude/memory/catch-log.md` — a legend, a table, an archive pointer.

```
| date | what | who-caught | error-class | outcome |
```

- **date** — ISO, absolute. No relative dates.
- **what** — one line. The defect, not the fix.
- **who-caught** — closed set of three: `agent-self` / `automatic-gate` / `human`.
- **error-class** — controlled but growable vocabulary (§3).
- **outcome** — `fixed` / `fixed+regression-case` / `accepted` / `promoted -> <target>`.

### who-caught: exactly three values, and the boundaries stated

- `agent-self` — the building agent found it **in its own work, before any gate fired**. If a test
  it just wrote went red, that is `automatic-gate`, not `agent-self`. The distinction is the entire
  point of the column: `agent-self` measures whether the propagated learning changed the agent's
  behaviour; `automatic-gate` measures whether the propagated guards work. Blurring them makes the
  #18 number uninterpretable.
- `automatic-gate` — fires without a human present: lint, CI, a hook, a test, an eval, a guard.
- `human` — Thomas. Including "noticed in passing," which is the case most likely to go unlogged
  and the case that most inflates the agent-self share if it does.

### error-class: seeded from evidence, not invented

Each seed class below is drawn from a catch this repo has actually recorded, so the vocabulary
starts grounded:

| class | origin |
|---|---|
| `fail-open-guard` | #16 — bootstrap re-run empties the manifest; sync reports clean |
| `wrong-invocation-path` | verification.md catch 5 — `bash pre-commit` cannot see file mode |
| `vacuous-test` | catch 3 — tests that pass with the guard stubbed out |
| `unobservable-AC` | catch 7 — three instances in #8 |
| `premise-drift` | #8's §0 rescope; "3 of 5 issues" in the Stage-3 handoff |
| `stale-propagated-asset` | jobs-radar's standards doc, stale and untracked |
| `silent-truncation` | #13 — a hardcoded two-file test command silently stopped running a third |
| `artifact-vs-effect` | catch 1 / catch 7 third bullet — "present in the file" ≠ "in effect" |

New classes are added deliberately, one legend line each, with the incident that produced them.
Growth in this column is expected; growth in the *schema* is not.

## 3. The promotion rule

**Threshold: three rows of one class in a project's log, or two rows across two projects.**

Deliberately Standard 7's rule-of-three rather than a fresh number invented here — the standard
already argues that two instances do not establish a shape and the third is where you learn what
the abstraction should be. Same logic applies to a lesson as to an extracted function.

On reaching threshold, the class becomes a **promotion candidate**, and the promotion is a human
judgment, routed by what the class actually names:

- names a **principle** ("test through the real invocation path") -> a `verification.md` entry,
  filed under an existing parent if it is a special case of one, per that doc's maintenance rule;
- names a **rule** ("a defect isn't fixed until its failing case is permanent") -> a standards
  change, which means an SSOT-guard decision (`EXPECTED_RULES=12`) — see #20, which is this
  mechanism's first customer;
- names a **mechanical check** -> a CI step, per ADR-0006 ground 2 ("mechanizable checks migrate to
  CI, where they cannot be bypassed").

**Promotion is not automated, and that is a decision, not a gap.** Deciding whether a recurring
class generalises is a judgment call: it fails the falsifier-discriminator membership test in the
standards, so there is nothing to delegate and nothing to gate. #25 records the automated path as
designed-but-gated with its own revisit trigger.

## 4. Hygiene — the anti-bloat constraints

- **Promoted rows collapse.** Once promoted, the contributing rows are struck through and replaced
  by a single line: `class -> promoted to <target>, N rows, <date>`. The detail lives in git history.
- **Cap: 50 live rows.** Excess archived to `docs/metrics/catch-log-archive-<YYYY-MM>.md`, oldest
  first. A number, not a vibe — `patterns.md` had no cap and that is how it died.
- **No commentary column.** Reasoning goes in the promotion target or the commit message. A log
  with a discussion column becomes a discussion.
- **Append in the turn the catch happens.** A log written at session close is a log written from
  memory, and memory rounds toward the flattering number.

## 5. Capture is manual — and why

No automated detection. There is no reliable signal for "a defect was caught": a test going red is
sometimes a catch and sometimes the normal red phase of TDD; a human comment is sometimes a catch
and sometimes a question. A heuristic detector would produce rows nobody trusts, and an
untrustworthy measuring instrument is worse than a manual one because it hides its own error rate.

If manual capture proves too weak — rows demonstrably missing after a run — that is a finding with
a real incident behind it, and it becomes the argument for a narrower automated hook. Not guessed
now. (This is ADR-0006's third ground applied to the instrument rather than to the gate.)

## 6. Seeding — the log ships with real rows

An empty instrument cannot be shown to work. Three seeding steps, all of which are also the
demonstration required by AC4:

1. **#16's manifest defect** — `agent-self`, `fail-open-guard`. The first row, and honestly
   classified: it was found by a mechanical probe run by the agent, before any human saw it.
2. **Backfill the six historical catches** from the #7 session as `human`. The six-for-six baseline
   currently exists only as a sentence in `verification.md`'s provenance note and in ADR-0006. Put
   it in the instrument, so #18's comparison is log-against-log rather than log-against-prose.
3. **Run one promotion end to end** on the seeded rows and record it. A promotion rule that has
   never fired is a vacuous rule — catch 3, one level out.

## 7. Acceptance criteria

| # | Criterion | Instrument |
|---|---|---|
| 1 | `catch-log.md` exists with the schema, the closed who-caught set, and the seeded legend | the file |
| 2 | Propagated by bootstrap into a fresh project (skeleton + legend, no rows) and manifest-recorded | #17's fixture; grep the manifest |
| 3 | Promotion rule + threshold + cap + archival rule written in the file itself | the file — the rule travels with the log or it doesn't travel |
| 4 | Seeded: #16's row, the six backfilled `human` rows, and one worked promotion | the file + the promotion target's diff |
| 5 | The self-catch ratio is computable **from the file alone**, by counting | count the who-caught column; no external context needed |
| 6 | #18's run populates it live and its ratio is reported against the seeded baseline | #18's report |

**AC5 is the one that matters.** If computing the ratio requires knowing context that isn't in the
file, the instrument has failed at the one job that makes #18's headline AC satisfiable.

## 8. Out of scope

- **Automated capture** (§5).
- **Automated up-promotion** — #25, gated.
- **A defect tracker.** GitHub issues track work; this tracks who *found* it, and only for defects
  found during a build.
- **Cross-project aggregation tooling.** Two projects; counting by hand is correct. Revisit at the
  third, with #25.

## 9. Risks

- **It becomes `patterns.md` again.** Mitigated by §4's four hard constraints, each with a number
  or a closed set. This is the main risk and it has a track record.
- **`agent-self` gets over-claimed.** The agent classifying its own catches has an obvious
  incentive. Mitigation: the boundary in §2 is stated tightly (a red test is `automatic-gate`), and
  Thomas can re-classify any row at review — with the re-classification itself visible in git
  history.
- **Rows go unlogged in the moment.** The failure mode that most inflates the agent-self share,
  because unlogged catches are disproportionately Thomas's passing remarks. No mechanical fix;
  named here so it is watched during #18 rather than discovered afterwards.

---

## Gate 1 questions

1. **The three-value who-caught set**, with a red test counted as `automatic-gate` rather than
   `agent-self`. That boundary determines what #18's headline number means — agree with where it
   is drawn?
2. **Threshold of three** (borrowed from Standard 7), or do you want two given how few builds there
   are to accumulate rows?
3. **One file or two.** #21 (gate-rejection logging) proposes reusing this schema with `gate-1` /
   `gate-2` as who-caught values rather than a second log. Fold it in from the start, or keep this
   scoped to build defects and decide later?
4. **The 50-row cap** — right order of magnitude for a solo two-project system?

On approval: build the file + legend + rule, seed it per §6, wire it into #17's propagation, then
#18 can start.
