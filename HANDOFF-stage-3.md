# HANDOFF — Stage 3: Sovary calendar strip-down as the workflow acceptance test

Paste this into a fresh conversation to start Stage 3. The Day-1 paper-adoption
arc is complete (workflow board at rest); Stage 3 is the end-to-end test of
whether the harness we built actually pays off. This chat is the
planning/review/alignment surface; CC (Claude Code, Windows-side) is the
implementation agent.

## READ FIRST — behavioral discipline (non-negotiable)

- First principles before pattern-matching. Read evidence (`cat`/`grep`/probe)
  before asserting about files or runtime.
- Premise-check before scoping. Last session, 3 of 5 issues had premises that
  had moved since filing. Grep the premise against current code before doing
  the work.
- Green != verified. Presence != effect. A passing report / a config in a
  file is not proof; confirm the load-bearing claim against the committed
  artifact and real behaviour.
- Push back with evidence, not deference. Honest disagreement is wanted.
- No end-of-response affirmations. Log catches briefly. Flag-don't-absorb on
  scope.
- Calibrate gates to real failure modes; don't make Thomas blind-paste
  obvious checks.

## The test — what Stage 3 is actually measuring

Strip Sovary down to a calendar-only app (`familienkalender`), built through
the workflow, to answer: did the scaffolding (standards, verification.md,
hooks, evals, routing rule, gates) pay off?

**The oracle.** Keep Sovary-1 (as-is) untouched as ground truth. The
falsifier for the stripped version is behavioural parity with Sovary-1's
calendar — mechanical, not a judgment. Clone Sovary fresh into `~/projects/`;
do NOT touch the Windows-side `E:\Claude\Projects\Sovary`.

**Metrics — declare BEFORE building** (verification.md catch 7):

1. **Parity** — stripped calendar behaves identically to Sovary-1's
   calendar. The falsifier.
2. **Self-catch ratio** — of defects found during the build, how many did
   the scaffolding catch (CI, hooks, evals, CC applying the falsifier rule
   in its own review) vs how many did Thomas catch in review? Benchmark
   against last session: six catches, all human, zero agent-self-check.
   This ratio is the answer to "did it pay off."
3. **Friction** — reuse `docs/metrics/v1-success-metrics.md`: time-to-merge,
   gate-1 rejections, premise-drifts, override rate.

**The measurement corrupts if Thomas intervenes.** To measure the
scaffolding's autonomy, Thomas must NOT pre-empt errors — log
who-caught-what and let the scaffolding fail visibly. Otherwise the number
is "Thomas + scaffolding," not the scaffolding.

**Watch the two halves** (live test of the falsifier discriminator). The
strip has a judgment half — deciding what is the calendar (essential vs
incidental) is synthesis, must stay main-thread frontier — and a mechanical
half — executing the removal with parity tests green, which is delegatable.
If the workflow routes those correctly on its own, the falsifier rule took.
If it sends the scope judgment to a cheap subagent, it didn't.

## Sequence

1. **Spec the test first** (its own gate-1). Before any build: define the
   calendar-scope boundary (what's in/out), the parity harness against
   Sovary-1, and the self-catch instrumentation (how who-caught-what is
   logged). Thomas approves this test-spec.
2. Then run the strip through the normal flow: clone Sovary -> bootstrap
   `familienkalender` -> PRD (scope) -> spec -> gate-1 -> build -> verify
   against Sovary-1 parity -> v0.5 review.
3. Report parity + self-catch ratio + friction against the pre-declared
   metrics.

## Environment mechanics (carry these — they cost time last session)

- One runtime: all Claude Code is Windows-side (`C:\Users\Admin\.claude`).
  WSL2 has no Claude Code — it's the shell for `git`/`npm`/`deploy.sh` only.
- Model default = Sonnet (`C:\Users\Admin\.claude\settings.json`); takes
  effect on a fresh session. `/model opus` at the start of judgment-heavy
  sessions (like the scope decision and every review) — the default won't
  do it for you, and Stage 3's scope call is exactly the work that needs
  frontier.
- Push: this repo's origin is an SSH remote
  (`git@github.com:thomasloosch/agentic-engineering-workflow.git`) and it
  works from this environment — verified live via `ssh -T git@github.com`
  and `git push --dry-run` in the 2026-08-05 session (corrects a claim in
  the prior handoff draft that origin SSH fails publickey from MINGW and
  falls back to HTTPS; that was checked and found wrong for this shell). If
  a future session hits a publickey failure, treat it as a fresh
  environment-specific issue to diagnose, not an assumed HTTPS-only path.
  PAT has Workflows: Read+write. `git pull --rebase` before committing (two
  writers on `main`).
- ADRs: `NNNN-kebab-title.md`, no prefix; `ls docs/adr/` before adding
  (collision happened last session). familienkalender starts its own ADR
  sequence.
- Delegation: subagent turns are unrecorded — you can't measure delegation
  savings, only review cost. Delegate only work with a cheap mechanical
  falsifier ("write X and run Y, show it fails when wrong"); keep
  scope/judgment/verification on main.

## Where the pieces live

- Workflow repo `agentic-engineering-workflow`: standards
  (`docs/standards/engineering-standards.md`),
  `docs/checklists/verification.md` (7 catches + falsifier discriminator),
  `docs/checklists/code-review.md`, the guards/hooks, `scripts/observe.mjs`.
  Bootstrap propagates these into new projects — so `familienkalender`
  inherits the harness on bootstrap.
- Sovary: GitHub `thomasloosch/Sovary` (clone fresh to `~/projects/`).
- `docs/metrics/v1-success-metrics.md` — the friction metrics.

## First move in the new conversation

`/model opus`, then: read this handoff + `.claude/memory/current-state.md`,
confirm the discipline and the environment model, then work with Thomas to
spec the test (scope boundary + parity harness + self-catch instrumentation)
— do not start the strip build until that test-spec is approved at gate-1.
