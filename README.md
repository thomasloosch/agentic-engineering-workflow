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

The gate deliberately does **not** record its own TDD cycles — see
[ADR-0005](docs/adr/0005-tdd-gate-does-not-self-record.md).
