# Spec — #25 Cross-project sync + up-promotion: the inheritance mechanism at scale

**Issue:** #25 · **Status:** Gate 1 — awaiting approval · **Date:** 2026-09-07
**Unblocked by:** #18 (CLOSED, Gate 2 accepted) · **Reshaped by:** ADR-0007 (ACCEPTED), #16 (CLOSED), #17 (CLOSED), #19 (CLOSED)

---

## 0. Premise-check

**#18's tally is real but weaker than either issue assumed.** Gate 2 report posted
2026-09-05, #18 CLOSED 2026-09-07: 9 defects, 5 `agent-self`, 4 `automatic-gate`, 0 `human`, against a
`6/6/0`-human baseline. Zero human means zero opportunity (nobody reviewed), three of
five `agent-self` catches came from one instrument (mutation), and the bespoke guards
caught nothing inside the probe (`docs/gate-2-issue-18.md`). This unblocks #25. It
proves nothing beyond that (sample of 9, one project, one author).

**Down-direction: most of what #25 asked for is already built by other issues, and
one claim in #25's own comment thread is false.**

- Gate-2's "Correction 1" (no `ADD` class, fails open on an empty manifest)
  describes a state `scripts/sync-project-assets.sh` no longer has: an `ADD` class
  exists (lines 221-249, sourced from the same `scripts/lib/asset-list.sh` enumeration
  bootstrap uses), and an empty manifest over a non-empty `.claude/` now `exit 1`s
  with a named remediation. Both landed via #16/#17, closed before #18 ran.
- **ADR-0007 (ACCEPTED) narrows the remaining scope.** Skills, `verification.md`,
  `code-review.md`, and the catch-log schema now ship as a plugin — nothing to sync
  because nothing is copied. `sync-project-assets.sh` stays necessary only for the
  mechanical half (CI, git hooks, lint config, test entrypoint, `package.json`
  scripts) plus one exception, `engineering-standards.md`, which stays
  copy-propagated because it is hard-`@`-imported and the plugin-path form does not
  resolve (tested, ADR-0007 Q2). `scripts/check-plugin-version.sh`'s `SHIPPED_PATHS`
  is `.claude-plugin`, `.claude/skills`, `docs/checklists` — `docs/standards` is
  outside it, so the standards-doc copy can drift with no version-guard tripwire,
  only `sync-project-assets.sh`'s own report.
- **The cadence claim does not hold.** #25's second comment says "cadence is settled
  by #17's re-bootstrap of jobs-radar" — one run, one project, one date. Nothing in
  this repo invokes `sync-project-assets.sh` on any schedule: no hook, no CI step, no
  cron reference, and `README.md` never mentions the script. A single historical run
  is not a cadence.

**Up-direction: #25's "up-promotion" is the catch-log's existing rule-of-three
promotion, at wider scope — a superset, not a different thing.** `catch-log.md`
already does the up-direction job within one repo: same `who-caught`/`error-class`
vocabulary, same 3-in-one-project (or 2-across-2) threshold, same
human-decides-edits-the-centre flow. Six promotions have fired. What #25 adds is not
a new rule — it extends the *read side* of that rule to a catch-log in a different
project's repo, which nothing currently does.

**Checked, not assumed: that extension's revisit trigger has not fired.** Trigger:
"a third project, or a promotion candidate that recurs in two projects' catch-logs
and gets missed." No third project exists. `~/projects/semver-probe`'s catch-log has
9 rows, including `vacuous-test` x3 and `silent-truncation` x1; this repo's own log
independently crossed 3 on both classes the same day (2026-09-05) and promoted them
via the existing per-repo rule — neither was *missed*, each was caught inside its own
project's log. `~/projects/jobs-radar/.claude/memory/` holds only the pre-catch-log
scheme (`current-state.md`, `lessons.md`, `patterns.md`) — **it has no
`catch-log.md`**, so the "two projects" precondition doesn't currently hold; there is
one project-level catch-log outside this repo, not two.

**N=2, weighed honestly.** `semver-probe` is finished, no git remote, evidence on one
machine. `jobs-radar` keeps its harness untracked and lacks the up-direction's data
structure. Cross-project automation now would compare a side that doesn't exist.

## 1. Purpose

#25's two halves have each been substantially resolved by other issues since filing,
but that resolution is scattered across an ADR, a checklist's own rules, two lines in
`current-state.md`, and a comment thread containing a claim ("cadence is settled")
that does not survive checking. This spec consolidates the record in one citable
place and corrects the false claim.

## 2. The decision

**Do not build automation for either direction now.**

- **A scheduler/hook/CI trigger for `sync-project-assets.sh`** — rejected: no drift
  evidence #16/#17 left uncaught, and at N=2 with irregular touch points a documented
  manual step is cheaper and equally effective.
- **A cross-project catch-log reader for up-promotion** — rejected: the revisit
  trigger is unmet, and one of the two projects has no catch-log to read.

**Taken instead:** this spec as the consolidated record, plus one docs-only addition
(§3) — nowhere currently says when to run the mechanical-half sync.

## 3. Slices

No code slices. One documentation change, if approved:

| # | change | covers |
|---|---|---|
| D1 | Add a paragraph to `README.md`'s "How this reaches a project" section naming `sync-project-assets.sh`, its post-ADR-0007 mechanical-only scope, and a manual cadence ("run after any change to `bootstrap-project.sh` or `asset-list.sh`, and periodically otherwise") | the cadence gap in §0 |

**Not a slice here:** giving jobs-radar a `catch-log.md` — a bootstrap/provenance
gap, not a sync-or-promotion gap. See Gate 1 question 3.

## 4. Validation strategy

**Every acceptance criterion names its instrument** — §5's table; none is gated by a
tool that cannot see the claimed property.

**What the oracle can and cannot prove.** The oracle for §0/AC1-2 is direct
inspection of this repo and the two project checkouts — search commands, `gh issue
view`, reading the named files, all reproducible. Green proves the claims matched the
repo *at the time checked*; it proves nothing about next session, and it cannot prove
a cross-project recurrence never happened — only that none is recorded in the two
catch-logs that exist today.

**Verification and validation, kept apart.** Everything here is **verification**: my
own re-run of the commands cited in §0, authored by me, checking my own claims. There
is **no validation** — no independent oracle for "was YAGNI right here," only a human
judgment call. Stated plainly rather than dressed up as more.

**Mutation check.** For AC1: before D1 lands, searching `README.md` for
`sync-project-assets.sh` returns nothing — the defect D1 exists to fix. If D1 lands,
reverting it and re-running the same search must return to zero hits, proving the
addition (not something else) closes the gap.

## 5. Acceptance criteria

| # | Criterion | Instrument |
|---|---|---|
| 1 | Every factual claim in §0 is reproducible from the command/file cited beside it | the cited search/`gh`/file-read commands, re-run by anyone |
| 2 | The up-direction revisit trigger (third project, or a missed cross-project recurrence) is confirmed unmet as of this spec's date | direct read of `~/projects/jobs-radar/.claude/memory/` and `~/projects/semver-probe/.claude/memory/catch-log.md` — **reported, not gated**: "missed" needs a human judgment, no tool does this |
| 3 | (if D1 approved) `README.md` documents the sync script's post-ADR-0007 scope and a manual cadence | occurrence count of `sync-project-assets.sh` in `README.md`: 0 -> >=1 |
| 4 | (if D1 approved) The addition does not imply automation that does not exist | human read of the paragraph against the real mechanism — same reason as AC2, no automated instrument distinguishes honest from overstated |

## 6. Out of scope

1. **Automated cadence** for the mechanical-half sync. Revisit trigger: three drift
   incidents in a row caught only by an unprompted manual run, or a third project.
2. **Automated cross-project up-promotion.** Stays parked per `catch-log.md`'s rule
   and ADR-0007; trigger unmet per §0.
3. **Giving jobs-radar a `catch-log.md`.** Real gap, wrong issue — see Gate 1 Q3.
4. **Any change to the sync script's classification logic** (`ADD`, `UPDATE`,
   `KEEP`, `CONFLICT`, `MISSING`, `SRC-GONE`, `UNVERIFIED`). Already built and tested
   under #16/#17/#18.
5. **Reopening ADR-0007's split.** Accepted; not re-litigated here.

## 7. Risks

- **Near-zero build can look like busywork.** Mitigated: the issue thread itself
  contains a now-corrected false claim ("cadence is settled"); fixing that in one
  citable place has value independent of code.
- **The "no build" call ages the moment a third project appears.** Trigger is
  explicit and unchanged, so reopening is cheap — a new gate-1 pass, not a redesign.
- **D1 itself can go stale** if a future ADR reshapes the sync/plugin split — the
  same `stale-propagated-asset` shape this issue is about, which is why D1 cites
  ADR-0007 by number rather than restating its content.
- **Not worth revisiting at all if:** the mechanical half shrinks to nothing
  (everything becomes plugin-deliverable) — the down-direction question dissolves on
  its own.

---

## Gate 1 questions

1. **Approve the no-build disposition for both directions?** Recommendation: yes —
   the down-direction's stated gaps are already closed, and the up-direction's
   revisit trigger is checked (§0), not assumed, and is unmet.
2. **Approve the one docs-only addition (D1)?** Recommendation: yes — near-zero
   cost, closes a real and currently undocumented gap, no overlap with #26.
3. **File jobs-radar's missing `catch-log.md` as its own small issue, separate from
   #25?** Recommendation: yes — it's a bootstrap gap (jobs-radar was never given the
   file `component_on catch_log` would install), not a sync-or-promotion gap;
   bundling it here would blur which issue fixed what.
4. **`current-state.md` currently states "#24 and #25 — gate 1. Specs drafted
   2026-09-07"**, written before this document existed. Flagged, not edited —
   `.claude/memory/` is out of this task's scope. Recommendation: whoever accepts
   this spec should also correct that line so the orientation doc doesn't assert a
   spec that, until now, didn't exist.
