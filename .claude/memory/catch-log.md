# Catch-log — agentic-engineering-workflow

Per-project defect log: what was caught, who caught it, what class of error it
was. Two jobs — the measuring instrument for #18's self-catch ratio, and the
loop's **up**-direction: a recurring class becomes a promotion candidate to the
centre. Spec: #19.

**Status against #19's acceptance criteria.** AC1/AC3/AC4/AC5 satisfied by this
file. **AC2 (propagation) CLOSED 2026-08-17** by #17 slice 2 — with one
refinement: the skeleton is deliberately **not** manifest-recorded, because the
manifest means "workflow-sourced and re-syncable" and this file is neither. It
carries a substituted placeholder and the project writes rows to it, so listing
it would have sync offering to refresh a project's own defect history.
**AC6 (populated live by a real build) is #18's job.**

**Not a mirror, and this file is the SOURCE.** `templates/catch-log.md.template`
is generated from this file by `scripts/make-catch-log-skeleton.mjs`, which strips
every data row and every project-specific section, so a new project inherits the
rules and an empty table and never this repo's rows. A CI check asserts the
committed skeleton is current — without it, the rules here could change (they
changed four times in two sessions) while new projects kept inheriting the old
vocabulary and threshold, silently. **Edit the rules here, then regenerate.**

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
| `wrong-invocation-path` | a test observes the artifact through a path production doesn't use — wrong invocation METHOD, or a fixture whose SHAPE production never has — and misses what the real path would catch | verification.md catch 5 + 5a (catch 4 is a documented special case) |
| `vacuous-test` | a test/guard stays green even with the thing it protects stubbed out or broken | verification.md catch 3 |
| `unobservable-AC` | an acceptance criterion names no instrument that can actually read it | verification.md catch 7 (origin: #8) |
| `premise-drift` | an issue or plan is built against a premise that moved since it was written | #8 §0 rescope; Stage-3 handoff, "3 of 5 issues" |
| `stale-propagated-asset` | a mirrored/propagated file has silently diverged from its canonical source | jobs-radar's standards doc (#16) |
| `silent-truncation` | a hardcoded or incomplete enumeration silently drops entries instead of failing loud | #13 |
| `artifact-vs-effect` | the committed/reported state looks right; the running/actual effect is not what it claims | verification.md catch 1; catch 7's third bullet |
| `unsafe-test-isolation` | a test operates on live/shared state instead of an isolated fixture, risking corruption on failure | verification.md catch 6 — **added here**, no seed-table entry existed for it |
| `overbroad-assertion` | an assertion fails on correct code — a false RED. The mirror of `vacuous-test`, kept **separate on purpose**: both are "the assertion doesn't measure the claim", but one hides defects and the other manufactures them, and lumping them would let three unrelated mistakes trip a promotion that describes neither | added 2026-08-14 (the jq-in-comments assertion) |

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

**Once promoted, a class stops counting toward promotion.** New instances are
still logged — they are evidence the promoted principle is being learned but not
yet absorbed — but they do not re-trigger the threshold. Without this the rule
would re-promote `artifact-vs-effect` on every third recurrence forever.
(Added 2026-08-14, when that class recurred immediately after its promotion.)

**Do not merge classes to reach the threshold.** Three superficially similar
mistakes are not three instances of one cause, and a promotion built on a merged
count describes something that never happened. When two classes look adjacent,
the test is whether the same fix addresses both — see `vacuous-test` vs
`overbroad-assertion`, split on exactly this basis.

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
- **No `|` characters in cell text**, not even Markdown-escaped as `\|`. It
  renders correctly but breaks any column-wise count of the table, which is the
  one property AC5 depends on. Rephrase instead.
- **Append in the turn the catch happens.** A log written at session close is
  written from memory, and memory rounds toward the flattering number.

---

## Log

| date | what | who-caught | error-class | outcome |
|---|---|---|---|---|
| 2026-07-22 | The guard's own tests still passed with the guard stubbed to always-pass — the negative cases were vacuous. | human | vacuous-test | fixed |
| 2026-07-17 | A negative test mutated the live git index when a `cd` failed silently under `set -e` (test ran against live state, not an isolated `mktemp -d` fixture). | human | unsafe-test-isolation | fixed |
| 2026-08-13 | #16's own re-run regression test stayed green when the prior-manifest-load code was disabled — every file fell back to "untracked but identical to the repo" and got adopted, so the entry *count* survived by a different path. The test proved less than it looked like it did. | agent-self | vacuous-test | fixed+regression-case |
| 2026-08-13 | — | — | `artifact-vs-effect` | promoted -> verification.md catch 1, 3 rows (2 human, 1 agent-self), 2026-08-13 |
| 2026-08-14 | ADR-0002 attributed the dead hooks to the MINGW runtime (`$HOME` path assumptions). Live probes showed hooks fire and block fine here — the runtime premise was wrong, and the real cause was the missing `jq`. A documented decision resting on an unverified mechanism. | human | premise-drift | fixed |
| 2026-08-14 | `SH_DIRS` in run-tests.mjs listed `.claude/hooks` and `hooks/git` but not `hooks` itself, so a test file placed there was never discovered and the four lifecycle hooks had no suite at all. | agent-self | silent-truncation | fixed+regression-case |
| 2026-08-14 | First attempt at stripping heredoc bodies used `sed`, which applies its script per line, so `.*$` stopped at the first newline and left the entire heredoc body — the thing it existed to remove — intact. Silently did nothing for its only use case; caught by the test that had just been written for it. | automatic-gate | artifact-vs-effect | fixed |
| 2026-08-17 | — | — | `wrong-invocation-path` | promoted -> verification.md catch **5a**, 3 rows (2 human, 1 agent-self), 2026-08-17 |
| 2026-08-18 | — | — | `fail-open-guard` | promoted -> verification.md catch **2a**, 3 rows (0 human, 3 agent-self), 2026-08-18 |
| 2026-08-19 | — | — | `overbroad-assertion` | promoted -> verification.md catch **3a**, 3 rows (0 human, 2 automatic-gate, 1 agent-self), 2026-08-19 |
| 2026-08-19 | `check-imports.mjs` read the dependency manifest from `process.cwd()` while taking scan paths from argv, with nothing asserting the two agreed. Pointed at a project from outside it, the guard judged that project's imports against a DIFFERENT project's manifest — silently passing when they happened to overlap, and both loud-skip branches bypassed because files and an adapter were found, just the wrong adapter. Found by auditing the guards against a real UNC target instead of the usual fixture, where cwd and target always coincide. | agent-self | fail-open-guard | fixed+regression-case |
| 2026-08-19 | The fix for the above over-corrected twice before landing: resolving the manifest only from the scan directory made `check-imports src` loud-skip a project that HAS one a level up, and then an unbounded upward walk escaped the project entirely and picked up a stray manifest in the Windows home. Both caught by the existing suite within seconds. Re-classified 2026-08-19 from `overbroad-assertion`: the first half is a guard declining to check what it should, which is this class, not an assertion failing on correct input. | automatic-gate | fail-open-guard | fixed |
| 2026-08-19 | `make_project` in the bootstrap suite used `mkdir -p` on an absolute path — the same UNC defect as the code it tests, hidden by the same missing condition. Surfaced the moment a UNC-rooted fixture was introduced, on its first use. | automatic-gate | wrong-invocation-path | fixed |
| 2026-08-18 | Asserted that a GitHub-sourced plugin install would exclude `node_modules` because it is gitignored, correcting an earlier finding on reasoning alone. Re-tested from outside the repo: still ships 15M including `node_modules`. The correction was wrong and the original finding stood. Retracted in the spec; the residual uncertainty (does a machine with no local checkout get the clean version?) is recorded as untested rather than resolved by argument. | agent-self | premise-drift | fixed |
| 2026-08-17 | The catch-log skeleton generator searched for a literal newline-delimited marker to strip the source's header. This checkout is CRLF, so the match never fired and the generated skeleton silently kept the workflow repo's own framing, including text about issue numbers meaningless in a consuming project. Failed silently and looked plausible. An assertion on the OUTPUT now refuses to write a skeleton containing workflow-repo text. | agent-self | wrong-invocation-path | fixed+regression-case |
| 2026-08-17 | Added `{{PROJECT_NAME}}` substitution inside the generic asset installer, which breaks the manifest's core invariant: the project copy no longer equals the source hash, so sync reads `b == a && c != a` as "safe to refresh" and would overwrite a project's own catch-log rows. Caught by reasoning through the hash model before committing, not by a test. Substituted project-owned files now use CLAUDE.md's place-once pattern instead. | agent-self | artifact-vs-effect | fixed |
| 2026-08-17 | Set `secret_scan=off` in jobs-radar's bootstrap.conf to avoid installing a blocking gitleaks workflow on a repo whose history has never been scanned — and the workflow installed anyway, because `gate_for` matched the generic `.github/workflows/*` -> `ci` rule before the specific one. A switch set, believed effective, and silently inert. Split into separate `secret_scan` and `git_guard` keys; regression case added. | agent-self | artifact-vs-effect | fixed+regression-case |
| 2026-08-14 | `guards.yml` was about to be propagated to consumer projects as part of the mechanical control set. It is the workflow repo's own guard-TEST suite and runs three scripts no consumer has, so it would have installed CI that fails on first run — present, red, and training the owner to ignore CI. Caught by reading the file's own header before shipping it. | agent-self | artifact-vs-effect | fixed+regression-case |
| 2026-08-14 | Reported a planted-secret probe's exit status from a piped command, so the printed code belonged to the last process in the pipe rather than to git. Ground truth (no commit created) was checked separately and did confirm the block, but the stated evidence measured the wrong process. | agent-self | artifact-vs-effect | fixed |

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
git-history lookup.

**Current corpus (updated 2026-08-19, after the overbroad-assertion promotion).**
15 individually visible rows (agent-self: 8, human: 4, automatic-gate: 3) **plus**
four collapsed promotion lines (2h+1a, 2h+1a, 0h+3a, 0h+1a+2g) =
**agent-self: 14, human: 8, automatic-gate: 5** across 27 catches.

Read that number carefully, because it is not the #18 measurement and must not
be quoted as one. It mixes three unlike things: a retrospective backfill of six
historical `human` catches, and two builds (#16 and the hook revival) done by an
agent that *knew it was being measured on self-catch rate* — which is precisely
the incentive problem §9 names. It is a baseline for comparison, not a result.

Two honest readings of it:

**The expensive defects were invisible to every gate.** #16's manifest and the
dead hooks were both `fail-open-guard`s, and a gate that fails open cannot catch
anything, including itself. Both needed a human or a deliberate probe. That is a
finding about the harness, not about the log.

**`automatic-gate` went 1 → 3 within a single build, and all three came from
tests written minutes earlier.** The heredoc false positive, the `sed`-does-
nothing bug, and the jq-in-comments false RED were each caught by a fresh
assertion rather than by a human. That is the first evidence in this corpus of
gates catching things — and it is worth being precise about what it does and
doesn't show: these gates caught defects in *the thing being built in that same
turn*, which is TDD working, not the standing harness working. The standing
harness still has a 0-for-2 record on the defects that actually cost weeks.

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

## Class standings (recount after the 2026-08-14 hook-revival build)

Counted per the rules above — promoted classes excluded, adjacent classes not merged.

| class | rows | toward promotion |
|---|---|---|
| `artifact-vs-effect` | 3 collapsed + 4 new | **promoted** — no longer counts. Three fresh instances across two builds says the principle is documented but not yet absorbed. It is by far the most frequent class here, and every instance is the same shape: something *present* mistaken for something *working*. |
| `fail-open-guard` | 3 collapsed | **promoted 2026-08-18** -> catch 2a. All three were agent-self catches, and none was found by a test — each needed someone to ask whether the guard had actually run. Two builds, two instances, both invisible until something probed for *effect* rather than *presence*. The likeliest next promotion. |
| `overbroad-assertion` | 3 collapsed | **promoted 2026-08-19** -> catch 3a, the mirror of catch 3. A fourth row was re-classified out rather than counted: it was a guard declining to check, not an assertion failing on correct input. Promoting on a padded count would have described something that never happened. |
| `vacuous-test` | 2 | 1 away |
| `wrong-invocation-path` | 2 collapsed + 2 new | **promoted 2026-08-17** -> catch 5a. Third instance was a fixture-shape problem, not an invocation-method one — a genuinely new special case under the same parent, which is why the promotion had content rather than pointing at an existing line. |
| `premise-drift` | 2 | 1 away |
| `silent-truncation` | 1 | 2 away |
| `unsafe-test-isolation` | 1 | 2 away |

`fail-open-guard` at 2-of-3 is the one to watch: if it lands a third time, the
promotion target is a principle roughly of the form *"a guard must be verified to
produce its EFFECT, not merely to be present and exit non-zero"* — which
`verification.md` catch 2 gestures at ("confirm the guard actually fired") but
does not state as a general requirement about guards that die before their own
logic.

*Archive: none yet — 15 individual rows + 4 collapsed promotion lines = 27 catches
accounted for, cap is 50 live rows.*
