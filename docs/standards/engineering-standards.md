# Engineering Standards — v1

The 12 rules every project in this workflow inherits by default. Each rule has a one-line statement and a "why" paragraph. Projects can override any rule in their own `CLAUDE.md`.

---

## Correctness

### 1. Lint clean before commit
`npm run lint` (or project equivalent) must pass with zero errors before any commit. No exceptions. If a rule is too strict, change the rule — don't bypass it.

### 2. Verify before declaring done
Don't say "should work" — say "ran it, output was X, matched expectation Y." Verification is the final step of every task, not an optional polish.

### 3. Plan before non-trivial code
Anything touching ≥3 files gets a written plan first. The spec-writer agent owns this. Plans surface ambiguity cheaply; code surfaces it expensively.

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
Format: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`. Automated changelogs depend on this. Bonus: signals professionalism in any code review.

### 10. No direct commits to main
Even solo. Every change goes via feature branch + PR. The PR is mostly for the pause between writing and shipping; the discipline catches mistakes.

### 11. Bilingual is project-conditional
If the project ships in two languages, every user-facing string exists in both at commit time. If the project is single-language, this rule is off.

## Quality

### 12. Comments explain why, not what
If the code needs a comment to say what it does, rewrite the code. Comments explain the reason for a choice, not the choice itself.

---

## What's NOT a rule

These are common standards I've deliberately excluded from v1:

- **DRY** — already implicit in #5 and #7; treated as absolute it produces worse code
- **100% test coverage** — coverage is a measurement, not a standard
- **TDD** — useful sometimes, dogma other times
  - Test-first isn't mandated — but the TDD gate (`.claude/tdd/`) verifies test-first discipline when used, and is the default for feature/logic builds.
- **Maximum line length** — handled by your linter
- **Specific design patterns** (Singleton, Factory, etc.) — pattern-cargo-culting is a sin

## How to override per project

A project's `CLAUDE.md` can override any rule with explicit justification:

```markdown
## Engineering standards overrides

- Rule 11 (Bilingual): OFF — this project is English-only.
- Rule 10 (No direct commits to main): OFF for the first 4 commits while bootstrapping.
```

Overrides must include a reason. "Because I felt like it" is not a reason.

## Related runbooks
Procedures (not rules) that live outside this doc:
- Deploying a Node cron service to Hetzner: see the deployment runbook at
  https://github.com/thomasloosch/agentic-engineering-workflow/blob/main/docs/deployment.md
  (covers NodeSource install, repo-scoped deploy key, absolute cron paths, and the
  user-crontab footgun). Absolute URL because this file is copied into projects where
  a relative docs/ path would not resolve.
