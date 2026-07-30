# Spec — #5 Run-level observability

**Issue:** #5 · **Status:** Gate 1 approved (the four decisions below) · **Date:** 2026-07-30

---

## 1. Purpose

`docs/metrics/v1-success-metrics.md` covers *outcome* observability — time-to-merge,
override rate, friction. What is missing is *run-level*: what the agent actually did,
how much it cost in tokens, and whether that is drifting. Without it there is no way
to tell a healthy run from one quietly degrading.

The interview changed the shape of this work. Claude Code **already writes complete
per-session traces** to `~/.claude/projects/<slug>/*.jsonl` — tool calls in order,
per-turn token usage, model, timestamps, API errors, hook firings. The issue asks for
"a log/trace file + small summarizer"; the trace file exists. Only the summarizer is
missing. So this slice adds **one read-only script over artifacts that already exist**,
and instruments nothing.

## 2. Acceptance criteria

1. `npm run observe` summarises the current project's runs: session count and date
   range, token totals (input / output / cache-create / cache-read), model mix, tool
   distribution, and API-error count.
2. `--all` reports **per project, split, never merged into one aggregate** — four
   projects exist today (51 sessions, ~108 MB) and their health is separate.
3. `--json` emits the same data machine-readably.
4. **Metrics only — never conversation content.** A test asserts no message text,
   file content, or tool arguments appear in any output.
5. Reports **tokens, not cost.** No price table.
6. Degrades honestly: a missing projects directory, an unreadable session, or a
   malformed line is reported and skipped, never a crash and never a silent zero.
7. States plainly that wall-clock gaps are **not** model latency (they include human
   think time), rather than presenting a number that looks like latency and isn't.

## 3. Out of scope

- **Drift detection.** "Run-over-run divergence on a fixed task" is the one bullet
  that cannot be derived from existing transcripts — every session is a different
  task, so it needs a fixture, a runner, and a comparison method. Different kind of
  work; bundling it makes the cheap 80% wait on the expensive 20%. Its own issue.
- **Cost in currency** — see AC-5. Tokens are the honest primitive; a price table
  drifts silently and would be wrong-but-confident.
- **True per-request latency** — not recorded in the transcripts. Only wall-clock
  gaps exist, and they conflate model time with human think time.
- **The `$CLAUDE_LOGS_DIR` / `$CLAUDE_MEMORY_DIR` fix** in the issue's third bullet.
  Already resolved (`18d884c`, `b06bf5d`, `b43b1b7` per `docs/metrics/stage-2-patterns.md`);
  zero live references remain repo-wide. Nothing to do.
- **Any instrumentation, hook, or wrapper.** The data already exists.
- **Writing into `docs/metrics/v1-success-metrics.md`.** That file's weekly log is
  hand-curated outcome evidence; machine-appending run metrics would mix two kinds
  of evidence in one place.
- **A dashboard, service, or database.** Solo scale: one script, printed output.
