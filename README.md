# Agentic Engineering Workflow

Multi-agent engineering workflow templates for Claude Code. Generic and project-agnostic.

**Status:** Under construction. Full setup guide coming after v1 stabilises.

## Setup

After cloning, activate the local secret-scan pre-commit guard — one command, run once:

```sh
./scripts/setup-hooks.sh
```

This is required because the guard is wired via `core.hooksPath` in your local
(uncommitted) `.git/config`, so a fresh clone starts with it **inactive**. CI
secret-scanning (gitleaks) runs on every push/PR regardless and is the enforcing
authority; the local guard is fast, fail-closed feedback before you commit.

Then install dev dependencies (the linter):

```sh
npm ci
```

## How this reaches a project — two mechanisms, on purpose

The harness splits by what has to read the file (ADR-0007):

| half | what | mechanism | currency |
|---|---|---|---|
| **portable / learning** | skills, `verification.md`, `code-review.md` | **marketplace plugin** | **next session** |
| **mechanical wiring** | CI workflows, git hooks, lint config, test entrypoint, `package.json` scripts | `bootstrap-project.sh` + the emitted `setup-project.sh` | when you run it |
| **project-owned data** | the catch-log's rows, `current-state.md` | created once, never distributed | n/a |

The line is drawn mechanically, not by taste: **does something outside Claude Code
have to read it?** GitHub Actions must find a workflow at `.github/workflows/`, git
must find a hook where `core.hooksPath` points, npm must find scripts in
`package.json` — so those are real files in the consuming repo. Everything only
Claude Code reads can be a plugin, and a plugin has no second copy to drift.

**One exception, and it is deliberate:** `engineering-standards.md` stays
copy-propagated. It is hard-`@`-imported by path from each project's `CLAUDE.md`,
and plugin delivery was tested and rejected — the version-independent placeholder
does not resolve in memory imports, and the form that *does* work embeds the
plugin version, so it would break on every release in every project.

### Plugin updates apply on the NEXT session, never the current one

Plugins load at session start, before any update can be applied — `claude plugin
update` says "restart required to apply" in its own help. So a change pushed here
reaches a project on its **next** session.

This is better than the previous state, where a change arrived only when someone
remembered to re-run a script. It is **not** live, and nothing in this repo should
imply that it is.

Auto-update is available but off by default here: `DISABLE_AUTOUPDATER` gates both
the CLI self-updater and plugin auto-update through one switch. `FORCE_AUTOUPDATE_PLUGINS=1`
re-enables plugin auto-update alone. When enabled, the refresh runs once per session
start, in the background, after a 0–10 minute jitter, and **only in interactive
sessions** — `-p` runs never auto-update.

### Releasing a plugin change

A change to shipped plugin content **with an unchanged version is a silent no-op**:
consumers keep the cached copy and never receive it. Nothing errors and nothing
warns. CI fails on this (`scripts/check-plugin-version.sh`), so bump `version` in
`.claude-plugin/plugin.json` whenever you touch `.claude/skills/` or
`docs/checklists/`.

## Testing and linting this repo

This repo distributes the TDD gate and the guards, so it holds itself to the
standards it publishes (issue #13 — it previously did not).

```sh
npm test
```

Runs **every** suite — the TDD gate's own tests, the import guard's, and the
shell guard suites — and prints each one it discovered.

```sh
npm run lint
```

**Do not use a bare `node --test`.** Node's test runner skips dot-prefixed
directories, so `.claude/tdd/` is invisible to it: a bare run finds 1 test
instead of 31 and reports success. `node --test .claude/tdd/` fails outright with
`MODULE_NOT_FOUND` (it tries to `require()` the directory). `npm test` goes
through `scripts/run-tests.mjs`, which discovers suites explicitly and fails loudly
if discovery returns nothing.

Sub-targets: `npm run test:node`, `npm run test:sh`.

## Run-level observability

```sh
npm run observe                      # this project
npm run observe -- --all             # every project, split per project
npm run observe -- --json            # machine-readable
npm run observe -- --since=<sha|date> # before/after split with tier shares
```

`--since` takes a commit-ish (resolved against this repo) or `YYYY-MM-DD`, and
reports frontier / Sonnet / Haiku turn counts and shares on each side of the cutoff.
Without it the report is a cumulative total, which cannot answer "did this change
anything" — every turn ever recorded lands in one bucket.

Summarises what agent runs actually did — tool distribution, per-turn token usage,
model mix, API errors — by reading the traces Claude Code already writes to
`~/.claude/projects/<slug>/*.jsonl`. Read-only; it instruments nothing.

Reports **tokens, not cost** (a price table drifts silently — multiply externally)
and **no latency** (per-request duration isn't recorded; wall-clock gaps include
think time). Emits **metrics only, never conversation content** — asserted in
`scripts/observe.test.mjs`.

The gate deliberately does **not** record its own TDD cycles — see
[ADR-0005](docs/adr/0005-tdd-gate-does-not-self-record.md).
