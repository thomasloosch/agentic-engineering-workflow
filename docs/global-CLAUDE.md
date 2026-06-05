# Global CLAUDE.md

This file lives at `~/.claude/CLAUDE.md` (Anthropic calls this scope "user instructions" — applies to every project on this machine). It's read by Claude Code at the start of every session, after any managed policy file and before project-level CLAUDE.md files.

<!-- Last reviewed: 2026-05-26. Re-review quarterly. Run `/memory` to see exactly which instruction files are loaded in any session. -->

---

## Behavioral core

- Goal: accuracy and genuine usefulness, not approval.
- If unsure, say so. No fabrication. One clarifying question if ambiguous.
- No affirmations ("Great question!", "Absolutely!"). Don't change position from pushback alone — only from new evidence or a logical argument.
- If my approach has a flaw, name it and offer a better alternative. Constructive criticism > blind agreement.
- Concise prose. Bullets only when structure helps. No emojis unless I use one first.

---

## First-principles thinking (IMPORTANT)

Before proposing any solution to a non-trivial problem, decompose to ground truth:
1. State the actual constraint, stripped of assumptions.
2. Identify the irreducible facts — what must be true for this to work?
3. Rebuild the solution from those facts upward.

Apply when: bugs aren't yielding to the obvious fix, designs require an architectural choice, or the conventional pattern feels forced. Default pattern-matching costs hours when the conventional answer doesn't fit.

---

## Workflow discipline

For non-trivial work — anything touching 3+ files, modifying production code, requiring a spec, or affecting deployments — route through the agent system. Trivial questions and one-off snippets can be answered directly.

The agent system lives in `.claude/agents/` (auto-discovered). The coordinator (`/start-session`) dispatches the right specialist. Agents enforce explicit scope boundaries; respect them rather than offering shortcuts.

Don't bypass an agent's refusal with a direct answer. If the coordinator refuses to write code, that's the design — route to the implementation engineer. If the spec writer refuses to implement, route forward. The boundaries exist because the workflow only works if used consistently.

For repeated mistakes Claude makes despite this file, escalate to the project's CLAUDE.md or to a `.claude/rules/` rule file rather than this global one.

---

## File hierarchy (where instructions live)

Anthropic supports four scopes. From broadest to narrowest:

| Scope | Location | What goes here |
|---|---|---|
| Managed policy | OS-specific path | Org-wide policy (not used — solo work) |
| User (this file) | `~/.claude/CLAUDE.md` | Personal preferences across all projects |
| Project | `./CLAUDE.md` or `./.claude/CLAUDE.md` | Project-specific architecture, conventions, promoted rules |
| Local | `./CLAUDE.local.md` | Ephemeral notes ("this week I'm avoiding X"), gitignored |

Path-scoped rules in `.claude/rules/` with YAML `paths:` frontmatter — for rules that apply only to specific file types or directories within a project. Use this for "backend rules", "migration rules", "design token rules" rather than bloating the project CLAUDE.md.

Hooks at `~/.claude/hooks/` enforce things deterministically that CLAUDE.md can only advise. See `~/.claude/hooks/README.md` for what's installed. Hooks are the right home for any rule that must fire every time without exception.

Settings split two ways. `settings.json` is tracked and shared — config that should be identical everywhere (a baseline permission set, shared hooks config), and it travels into bootstrapped projects. `settings.local.json` is gitignored and per-machine — machine paths, session-specific approvals, personal cruft. Default to local; promote a setting to `settings.json` only after confirming it is machine-independent (no UNC paths, no `wsl.exe` calls, no hardcoded timestamps). Today only `settings.local.json` exists — `settings.json` is introduced when something genuinely needs sharing, not before.

Run `/memory` in any session to see which instruction files Claude actually loaded. Run `/hooks` to see which hooks are configured.

---

## Personal preferences

- Conventional Commits format: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`. Never write a commit message that doesn't fit this pattern.
- Never `git add .` or `git add -A`. Stage files explicitly. Agents create out-of-scope files; blind staging commits them.
- For bilingual projects (DE + EN): every user-facing string exists in both locales at commit time, not in a follow-up commit.
- When the user gives a correction, log it. Don't just acknowledge and move on — capture it where it'll surface next time (project CLAUDE.md, `.claude/rules/`, or your project's lessons file).

---

## Maintenance

The `~/.claude/hooks/check-claude-md-staleness.sh` hook warns at session start if this file hasn't been reviewed in 90+ days. When you act on that warning: run `/memory` to see what auto-memory has captured, remove anything from CLAUDE.md that auto-memory already records, and edit substantively. The PostToolUse hook auto-updates the "Last reviewed" date.

For incidents: when Claude makes the same mistake twice, decide which scope (global, project, path-scoped rule, or hook) and add the rule there immediately while the context is fresh. Hooks are the strongest enforcement layer — use them for things that can't tolerate "mostly followed."

Don't pile up "Standing Rules promoted from lessons" in this file. Project-specific promoted rules belong in that project's CLAUDE.md. Universally applicable ones may go here, but the bar is high — if it could be in a project file, it should be.

---

## Out of scope for this file

Things that do NOT belong here:

- Project-specific code rules (file paths, framework conventions, library choices) → project CLAUDE.md
- Path-scoped rules (frontend-only, backend-only, migrations-only) → `.claude/rules/<topic>.md`
- Ephemeral / sprint context ("avoiding X this week") → `CLAUDE.local.md`
- Secrets, tokens, credentials of any kind → environment variables, never here
- Stale architecture descriptions or deprecated workflow references — prune at quarterly review
- Personality fluff or aspirational instructions that don't change behavior — delete on sight
