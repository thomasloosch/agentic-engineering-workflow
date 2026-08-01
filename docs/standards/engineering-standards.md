# Engineering Standards — v1

The 12 rules every project in this workflow inherits by default. Each rule has a one-line statement and a "why" paragraph. Projects can override any rule in their own `CLAUDE.md`.

---

## Correctness

### 1. Lint clean before commit
`npm run lint` (or project equivalent) must pass with zero errors before any commit. No exceptions. If a rule is too strict, change the rule — don't bypass it.

### 2. Verify before declaring done
Don't say "should work" — say "ran it, output was X, matched expectation Y." Verification is the final step of every task, not an optional polish.

What that requires in practice is accumulated in the verification checklist —
concrete checks derived from real misses, every one surfaced by human or e2e review
rather than agent self-check:
https://github.com/thomasloosch/agentic-engineering-workflow/blob/main/docs/checklists/verification.md
(Absolute URL because this file is copied into projects where a relative `docs/` path
would not resolve.) **Per-issue acceptance verification** — "did this build satisfy
issue X's stated criteria" — is covered by this rule plus human review, deliberately
not by tooling; see ADR-0006 for the revisit trigger.

### 3. Plan before non-trivial code
Anything touching ≥3 files gets a written plan first — the `/to-prd` skill produces it (grilling → PRD → issues). Plans surface ambiguity cheaply; code surfaces it expensively.

### 4. Fail closed in production, fail loud in dev
Production paths in plan-gating, authorisation, and any privilege check return 503 (or equivalent) on any error. Development paths throw and crash — silent failure is worse than visible failure.

## Design

### 5. KISS — simplest thing that works
If a junior engineer can't read it, it's too clever. Cleverness is rarely a virtue in production code.

### 6. YAGNI — don't build for hypothetical futures
Build for the current spec, not anticipated needs. Anticipated needs change; current specs are real.

### 7. Rule of three before extracting
Don't DRY two call sites. Wait for the third. Premature abstraction is worse than duplication — it locks in the wrong shape before you understand the right one.

### 8. Single responsibility
One function/module/component does one thing. "And" in the name is a signal to split: `validateAndSave`, `parseAndStore`.

## Workflow

### 9. Conventional Commits
Format: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`. Automated changelogs depend on this.

### 10. No direct commits to main (project-conditional)
For projects with collaborators, every change goes via feature branch + PR: the PR is the pause and the second reader. Solo projects may commit directly to main (ADR-0001) — there's no second reviewer to gate on; the pause comes from self-review and the warn-direct-commit hook.

### 11. Bilingual is project-conditional
If the project ships in two languages, every user-facing string exists in both at commit time. If the project is single-language, this rule is off.

## Quality

### 12. Comments explain why, not what
If the code needs a comment to say what it does, rewrite the code. Comments explain the reason for a choice, not the choice itself.

---

## Writing discipline (prose artifacts)

Beyond the 12 code rules, one discipline governs the prose artifacts the workflow produces — PRDs (`to-prd`), issues (`to-issues`), and agent briefs (`triage`):

- **No vague terms.** Banned: "seamlessly integrates," "robustly handles," "intuitive UX," and their kin — they read as finished but specify nothing. Replace each with a concrete, testable statement: what the thing actually does, in language an acceptance criterion could check. If you can't make it concrete, that's an unresolved question to surface, not a phrase to ship.

## Model routing (cost discipline)

Beyond the 12 code rules: which model does the work. Frontier capability is the expensive
default, and the failure mode is not choosing badly — it is never choosing at all.

**The default is Sonnet, and it is set in the global user settings — not in this repo.**
`"model": "sonnet"` lives in `~/.claude/settings.json` on the machine you work from (on this
setup: `C:\Users\Admin\.claude\settings.json`, the Windows desktop-app home, which is where
**all** sessions actually run — the WSL2 `~/.claude/settings.json` is a vestige of an
abandoned test install with zero recorded sessions and is deliberately left alone). It is
recorded here because a global setting is invisible to the repo: without this line a future
session, or a second machine, has no way to know the default was ever meant to be anything
but Opus. If sessions are defaulting to Opus, that knob was never set there — set it.

This is a deliberate split. The **setting** is a personal, per-machine cost preference tied to
your usage limits; nobody clones the repo to inherit it, so it does not belong in project
settings. The **policy below** is the shareable reasoning, so it is versioned here.

**Escalate deliberately.** `/model opus` for design, architecture, ADRs, and judgment calls —
work where being wrong is expensive and being slow is not. Everything else stays on the default.

**Delegate the generation, keep the verification on main.** Hand bounded, mechanical work to a
cheap general-purpose subagent (the Agent tool's `model` parameter — this does *not* require a
named custom-agent layer; ADR-0003 stands):

| delegate to a cheap subagent | keep on the main frontier thread |
|---|---|
| test generation | spec, architecture, ADRs |
| mechanical refactors (tests as the check) | judgment calls |
| codebase grep-and-summarize | **verification and acceptance checking** |
| boilerplate scaffolding | |
| fixture assembly | |
| commit-message drafting | |
| doc formatting | |
| test-run summarizing | |

**Verification is deliberately not routed.** It is the highest-risk target, and moving it to a
cheaper model is the explicit revisit trigger in ADR-0006 — a separate decision, not a
side effect of cost tuning.

**The membership test — delegate work that has a mechanical falsifier.** The table above lists
classes; this is what decides whether something belongs in the left column. If the only way to
find out the output is wrong is to read it carefully, you have not delegated the work — you
have moved it from your hands to your eyes and added a briefing cost on top.

Run a candidate through it: test generation and mechanical refactors are checked by the suite;
fixture assembly by shape assertions; doc formatting and commit messages are mechanical or
trivially cheap to eyeball. Grep-and-summarize qualifies **only for specific claims** ("these
seven files export X"), not general ones ("these files are identical") — a generalisation has
no falsifier and is where this failed in practice. Distilling a canonical pattern, writing an
ADR, and deciding what is essential all fail the test: the question *is* the judgment.

Beware tasks that fan out cleanly — parallelism is not mechanicalness, and a job that splits
into three tidy chunks can still be three judgment calls.

**Delegate the check with the generation.** Brief for "write X **and run it**, report the
output," never bare "write X". A delegated code sample that was never executed returns looking
correct and fails on first use — a silent error on your side of the line instead of a loud one
on the subagent's, where it would have been cheap.

**Size floor: delegate bounded chunks only.** A two-line edit costs more to hand off than to do
inline, because the handoff must carry context the main thread already holds. If briefing the
subagent takes longer than doing the work, do the work.

In fan-out workflow scripts, set `opts.model` per stage — deterministic stages do not need the
frontier tier.

**Cheap is not free.** A too-cheap model on a subtly-wrong subtask moves cost from tokens to
your review time, and the token metrics will not show it. Judge a routing change by whether the
delegated output held up under review, not by the token delta alone.

## What's NOT a rule

These are common standards I've deliberately excluded from v1 — don't flag them as violations:

- **DRY** — already implicit in #5 and #7; treated as absolute it produces worse code
- **100% test coverage** — coverage is a measurement, not a standard
- **TDD** — useful sometimes, dogma other times
  - Test-first isn't mandated — but the TDD gate (`.claude/tdd/`) verifies test-first discipline when used, and is the default for feature/logic builds.
- **Evals** — the bar where correctness is a judgment call, absent where it isn't
  - For logic whose correctness is a *judgment* — a scorer, classifier, ranker, or anything where "is this output right?" needs a human to answer — a labelled eval is the only real check, and it comes before the tuning it guards. Set the bar at the eval, not a demo.
  - For deterministic logic, tests already answer the question and an eval adds nothing. Don't build one to look rigorous.
  - **Eval-green is not verified.** It is regression protection on the cases you labelled — it does not prove the change generalises to live input. The eval equivalent of Rule 2: a passing eval says "these cases still hold," never "this works." Growing the labelled set is how that gap closes; a fresh capture is how you check it.
  - Methodology (labels human-owned with provenance, deterministic exact-match, ambient inputs frozen, local-first): ADR-0004.
- **Maximum line length** — handled by your linter
- **Specific design patterns** (Singleton, Factory, etc.) — pattern-cargo-culting is a sin

## How to override per project

A project's `CLAUDE.md` can override any rule with explicit justification:

```markdown
## Engineering standards overrides

- Rule 11 (Bilingual): OFF — this project is English-only.
```

Overrides must include a reason. "Because I felt like it" is not a reason.

## Related runbooks
Procedures (not rules) that live outside this doc:
- Deploying a Node cron service to Hetzner: see the deployment runbook at
  https://github.com/thomasloosch/agentic-engineering-workflow/blob/main/docs/deployment.md
  (covers NodeSource install, repo-scoped deploy key, absolute cron paths, and the
  user-crontab footgun). Absolute URL because this file is copied into projects where
  a relative docs/ path would not resolve.
