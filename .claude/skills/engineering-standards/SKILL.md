---
name: engineering-standards
description: The 12 engineering rules every project inherits by default. Loaded automatically when an agent is reviewing or writing code, to ensure compliance with KISS, YAGNI, fail-closed, conventional commits, and the rest. Use whenever code is being written, reviewed, or audited.
---

# Engineering Standards Skill

When this skill is loaded, the agent enforces these 12 rules. They apply unless the project's CLAUDE.md explicitly overrides one with justification.

## Correctness

1. **Lint clean before commit** — `npm run lint` (or project equivalent) must pass with zero errors before any commit. No exceptions. If a rule is too strict, change the rule — don't bypass it.

2. **Verify before declaring done** — "ran it, output was X, matched expectation Y" — not "should work." Verification is the final step of every task, not optional polish.

3. **Plan before non-trivial code** — anything touching 3 or more files gets a written plan first. Plans surface ambiguity cheaply; code surfaces it expensively.

4. **Fail closed in production, fail loud in dev** — production paths in plan-gating, authorisation, any privilege check return 503 (or equivalent) on error. Development paths throw and crash — silent failure is worse than visible failure.

## Design

5. **KISS — simplest thing that works.** If a junior engineer can't read it, it's too clever. Cleverness is rarely a virtue in production code.

6. **YAGNI — don't build for hypothetical futures.** Build for the current spec, not anticipated needs. Anticipated needs change; current specs are real.

7. **Rule of three before extracting.** Don't DRY two call sites; wait for three. Premature abstraction is worse than duplication — it locks in the wrong shape before you understand the right one.

8. **Single responsibility.** One function/module/component does one thing. "And" in the name is a signal to split: `validateAndSave`, `parseAndStore`.

## Workflow

9. **Conventional Commits** — format: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`. Automated changelogs depend on this.

10. **No direct commits to main** — even solo. Every change goes via feature branch + PR. The PR is mostly for the pause between writing and shipping; the discipline catches mistakes.

11. **Bilingual is project-conditional** — if the project ships in two languages, every user-facing string exists in both at commit time. If the project is single-language, this rule is off.

## Quality

12. **Comments explain why, not what.** If the code needs a comment to say what it does, rewrite the code. Comments explain the reason for a choice, not the choice itself.

## How to invoke

The agent invoking this skill should:

1. Read these 12 rules
2. Check the project's CLAUDE.md for any explicit overrides (only valid with a written reason)
3. Apply the rules to whatever review or generation task is at hand
4. When flagging a violation, cite the rule number (e.g., "Violation of Rule 4 — fail-loud principle")

## Project overrides

A project's CLAUDE.md can override any rule with explicit justification. Example: Engineering standards overrides

Rule 11 (Bilingual): OFF — this project is English-only.
Rule 10 (No direct commits to main): OFF for the first 4 commits while bootstrapping.


Overrides must include a reason. "Because I felt like it" is not a reason.
