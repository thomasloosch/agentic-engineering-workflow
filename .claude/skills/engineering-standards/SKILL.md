---
name: engineering-standards
description: The 12 engineering rules every project inherits by default. Loaded automatically when an agent is reviewing or writing code, to ensure compliance with KISS, YAGNI, fail-closed, conventional commits, and the rest. Use whenever code is being written, reviewed, or audited.
---

# Engineering Standards Skill

The 12 rules this skill enforces are **single-sourced in the engineering-standards
doc** — this file is a thin reference, not a second copy. They apply unless the
project's CLAUDE.md explicitly overrides one with written justification.

## Load the rules (do this first)

Read the canonical doc before applying anything. It holds the 12 rules, the
"what's NOT a rule" exclusions, the writing-discipline rule, the override
protocol, and the related-runbooks pointer:

- In this workflow repo: `docs/standards/engineering-standards.md`
- In a bootstrapped project: `.claude/engineering-standards.md`

Read whichever path is present. That doc is authoritative — if this file and the
doc ever disagree, the doc wins.

## How to invoke

1. Read the canonical doc (paths above).
2. Check the project's CLAUDE.md for explicit overrides — valid only with a written reason.
3. Apply the rules to the review or generation task at hand.
4. When flagging a violation, cite the rule number (e.g., "Violation of Rule 4 — fail-loud principle").
