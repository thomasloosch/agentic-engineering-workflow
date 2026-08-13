# Spec — #17 Full-harness bootstrap, including the learning artifacts

**Issue:** #17 · **Status:** **Gate 1 APPROVED 2026-08-13** · **Drafted:** 2026-08-12
**Blocked by:** #16 (manifest fail-open, lands standalone first), #19 (the catch-log artifact
slice 3 propagates) · **Blocks:** #18
**Build order:** #16 → #19 → **#17** → #18 → #24

## Gate 1 decisions (2026-08-13)

1. **D1 two-script split — accepted.** It satisfies the no-edit-package.json default: bootstrap
   copies and records, the emitted `setup-project.sh` (owner-run, refuse-on-conflict, prints its
   diff) is the only thing that touches `package.json`.
2. **D2 `.claude/checklists/` — accepted, with one addition.** Every propagated copy carries a
   header marking it a **mirror**, naming the canonical URL. The manifest keeps the mirror honest
   against the repo; the marker keeps a *human* from becoming the drift source by editing a mirror
   they took for the original. Applied to `verification.md` and `code-review.md`; the catch-log is
   **not** a mirror — it is project-owned data with a propagated skeleton, so it gets the schema
   and legend, not a mirror header.
3. **AC9 mutation check — kept, non-negotiable.** A propagation suite that stays green with the
   propagation stubbed out is vacuous. Dropping it would contradict catch 3 in the same document
   that cites it.
4. **Slice ordering — #16 splits out and lands first**, verified on its own, not as slice 1 here.
   It is a bug actively causing damage, it has a clean standalone regression case, and separating
   it lets jobs-radar's re-sync proceed on its own track. Slices renumbered below.

---

## 0. Premise-check

Verified against the repo and against `~/projects/jobs-radar` before writing, per the
premise-drift discipline.

**Confirmed.** `bootstrap-project.sh` propagates skills, commands, the standards doc, the TDD
gate runtime + rotator hook, and copies two guard files. It does **not** propagate the lint
config or a lint script, the test entrypoint, any CI workflow, `observe.mjs`, or any learning
artifact. `ci.yml` exists only as `.template`. Measured end state in jobs-radar: no
`.github/workflows/` directory at all, `core.hooksPath` unset, `.claude/ci/` and
`.claude/git-hooks/` absent, no `verification.md`, no `code-review.md`.

**Corrected.** The item as briefed asks for "a `setup-project.sh` the owner runs once." There is
already a `bootstrap-project.sh`, and a second top-level script in this repo would be two entry
points to one job. The resolution taken here: bootstrap stays the repo-side copier, and it
**emits** `setup-project.sh` *into the target project* as the owner-run wiring step. That is what
makes "preserving the no-edit-package.json default" coherent — bootstrap genuinely never edits
`package.json`; the emitted script does, and only when the owner runs it.

**Newly found, load-bearing.** #16: a second bootstrap run empties the manifest, and
`sync-project-assets.sh` then reports a clean bill of health while tracking nothing. Reproduced
on an isolated fixture (37 entries -> 0). This is why jobs-radar's `engineering-standards.md` is
silently two months stale. **Ordering consequence:** #16's fix is the first slice of this work,
not a parallel ticket — propagating more assets through a propagation mechanism that forgets what
it propagated multiplies the drift surface.

## 1. Purpose

A project bootstrapped by this workflow should, on day one and with no hand-editing beyond one
config file:

- satisfy the workflow's own standards — Rule 1 (lint clean) has something to run, Rule 2
  (verify before done) has the checklist it points at;
- have every mechanical guard this repo has paid for actually *running*, not merely present;
- carry the accumulated learning, so it starts where the last project finished.

The second point is the one that fails today, and the third does not exist today.

**Why the learning half is not optional.** Every guard in this repo exists because a catch was
recorded first: the exec-bit CI assertion exists because catch 4/5 were written down; the
`--since` flag on `observe` exists because catch 7 was written down. Propagating guards without
the catch record ships the conclusions and discards the reasoning — and the next project's novel
defect then has nowhere to accrete, so it is paid for twice.

## 2. Slices

**Precondition, not a slice — #16.** Manifest provenance decided by the manifest, not by presence
on disk; sync fails closed on a zero-entry manifest; ADD class so assets new since the last
bootstrap are visible (#25's open half). Lands and is verified on its own before this issue starts.
Its regression case (bootstrap twice, manifest must not shrink) stays cited here as AC6, because
this issue's propagation is what would silently re-open it.

**Slice 1 — mechanical control set.** Propagate `eslint.config.js`, `run-tests.mjs`,
`guards.yml`, `secret-scan.yml`, `ci.yml` (installed as `.yml`), `observe.mjs`,
`check-imports.mjs`, `hooks/git/pre-commit`. All manifest-recorded.

**Slice 2 — learning artifacts.** Propagate `verification.md` and `code-review.md` into
`.claude/checklists/` with the mirror header (D2), and #19's catch-log skeleton + legend into
`.claude/memory/`. Manifest-recorded, so staleness is detectable — the failure mode this whole
item exists to close. **Requires #19's artifact to exist**, which is why #19 precedes this issue.

**Slice 3 — `setup-project.sh` + `bootstrap.conf`.** The owner-run wiring, and the override.

**Slice 4 — re-bootstrap jobs-radar.** The mechanism's first real customer, and the proof it
works on a project that is not a fresh fixture. Closes the live drift #16 exposed.

## 3. Design decisions (confirmed at Gate 1)

**D1 · Two scripts, clear split.** `bootstrap-project.sh` (repo-side, copies + records, never
edits owner-owned files) emits `setup-project.sh` (project-side, idempotent, wires
`package.json` scripts / `.claude/settings.json` SessionStart / `core.hooksPath`, refuses rather
than clobbers on conflict, prints a diff of what it would change and requires no flags to be
safe). *Alternative rejected:* have bootstrap do the wiring behind a `--wire` flag — collapses
the two trust levels into one script and makes the no-edit default a matter of remembering a flag.

**D2 · Learning artifacts live at `.claude/checklists/`.** Not `docs/`, because `docs/` is the
project's own namespace and a workflow-owned file there will be edited as if it were local. Not
appended into `CLAUDE.md`, because that file is the project's override surface and must stay
hand-owned. *Consequence:* the standards doc's Rule 2 link is an absolute GitHub URL by design
(so it resolves in projects); the propagated copy is the offline mirror, and the two are kept
honest by the manifest rather than by a second URL.

**D2a · Mirror header (added at Gate 1).** Each propagated checklist opens with a fixed banner:

```
> **Mirror — do not edit here.** Canonical: <absolute GitHub URL>
> Local edits are a drift source and will show as CONFLICT on the next sync.
> To change this checklist, change the canonical copy and re-sync.
```

The manifest already detects a divergent mirror mechanically; the banner exists to stop a *human*
becoming the drift source, which no hash can prevent. **The catch-log is not a mirror** — it is
project-owned data whose whole purpose is to accumulate locally. It receives the schema, the
legend, and the promotion rule, and it carries no mirror header. Getting this backwards would tell
a project not to write to the one file it is supposed to write to.

**D3 · `.claude/bootstrap.conf`, committed, key=value.** Components: `lint`, `test`, `ci`,
`secret_scan`, `import_guard`, `tdd_gate`, `observe`, `checklists`, `catch_log`. Defaults all
`on` except where the ecosystem cannot support them. Committed rather than gitignored so the
decision is reviewable and a re-bootstrap or a clone reproduces it.

**D4 · Ecosystem gate is loud, never silent.** A non-Node project gets `lint=off test=off` with a
printed reason. This follows `check-imports.mjs`'s existing loud-skip contract — the property
being preserved is that an inapplicable guard is *visible* in the log, never absent.

**D5 · Node-only in this slice.** `bootstrap.conf` gives the shape for other ecosystems; adapters
for them are YAGNI until a non-Node project exists. Recorded so it is not re-litigated.

**D6 · CI workflows install as real `.yml`.** `ci.yml.template` becomes the source for a
generated `ci.yml`, with the bilingual-locale step and the (now-dead) agent-frontmatter step
emitted conditionally from `bootstrap.conf` rather than shipped as inert always-skipping blocks.
*Note:* the template's `agent-checks` job checks `.claude/agents/` frontmatter — a layer retired
in ADR-0003 and empty in this repo. It should not be propagated at all.

## 4. Acceptance criteria

Each is stated with the instrument that reads it, per verification.md catch 7.

| # | Criterion | Instrument |
|---|---|---|
| 1 | Fresh `git init` + bootstrap + `setup-project.sh` -> `npm run lint`, `npm test` both run and pass; no hand-editing beyond `bootstrap.conf` | scripted e2e fixture under `mktemp -d`, asserted exit 0 |
| 2 | The three CI workflows are installed as `.yml` and are valid | file existence + `gh workflow list` on a throwaway remote, or `actionlint` |
| 3 | `verification.md`, `code-review.md`, catch-log present in the new project **and** manifest-recorded; the two checklists carry the mirror banner, the catch-log does **not** | grep the manifest for all three paths; grep the banner string (present ×2, absent ×1) |
| 4 | The git secret guard **blocks** a planted fake key | `git commit` in the fixture, exit non-zero — real invocation path, not `bash pre-commit` (catch 5) |
| 5 | Import guard runs in the new project's CI and loud-skips rather than silent-passes | assert the skip string is in the log when no adapter matches |
| 6 | Re-running bootstrap does not shrink the manifest | bootstrap twice, compare entry counts (#16's regression case) |
| 7 | `bootstrap.conf` with `ci=off` omits the workflows and exits 0 | fixture with the flag set, assert absence + exit 0 |
| 8 | jobs-radar, re-bootstrapped: standards doc hash matches canonical, both guards live, `core.hooksPath` set | `sha256sum` comparison + `git config --get core.hooksPath` + a planted-key commit attempt |
| 9 | A mutation check: stub the propagation step to a no-op and confirm criteria 1–8 go red | catch 3 — a green suite that would stay green with the feature removed is vacuous |

## 5. Out of scope

- **Non-Node ecosystem adapters** (D5). YAGNI; the conf shape is the forward compatibility.
- **The automated up-promotion path** — #25's closed half. Manual promotion via #19 is correct at
  two projects.
- **Reviving `.claude/agents/`.** ADR-0003 stands; the CI template's agent-frontmatter job is
  dropped, not propagated.
- **Making lifecycle hooks work in the MINGW desktop runtime.** ADR-0002 is accepted; that is why
  the *git-native* guard is the one this spec verifies as blocking.
- **A CLAUDE.md for this repo.** Still the deliberately-deferred repo-architecture question
  recorded in `current-state.md`.

## 6. Risks

- **The fixture passes and reality doesn't.** Mitigation: AC8 makes a real project the criterion,
  not just a `mktemp` fixture. This is catch 5's shape at project scale — a test that only ever
  runs against a synthetic target verifies a path production never takes.
- **`setup-project.sh` clobbers an owner's `package.json`.** Mitigation: refuse-on-conflict, print
  the diff, require the owner to resolve. Never merge silently.
- **Propagating `verification.md` creates a second stale copy.** Mitigation: manifest-recorded (so
  the sync sees it) plus the D2a mirror banner (so a human does not edit it). This is precisely why
  #16 is a precondition rather than a slice — without the manifest fix, adding artifacts makes the
  drift surface larger, not smaller.

---

## Gate 1 — APPROVED 2026-08-13

All four questions answered in §"Gate 1 decisions" at the top. Proceed after **#16** and **#19**
have landed and been verified: slices 1–4 in order, each with its own verification, AC9's mutation
check run against the finished propagation rather than per-slice.
