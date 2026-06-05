---
description: Begin a work session. Reads current-state, applies escalation ladder, surfaces priorities. The first thing the user types every working session.
---

# /start-session

When this command runs, dispatch the **coordinator** agent with the following instruction:
TASK: Session start
PROJECT: [current project root + path to its CLAUDE.md]
SCOPE: Read .claude/memory/current-state.md, check for RED-severity items (14+ days overdue), surface the top 3 priorities. Apply the escalation ladder.
Begin.

## Expected coordinator behaviour

The coordinator should:

1. Read `.claude/memory/current-state.md`
2. Read the last 50 lines of `$HOME/.claude/logs/agent-compliance.log` (recent system activity; `$CLAUDE_LOGS_DIR` is unset in the MINGW desktop runtime, `$HOME` resolves to `/c/Users/Admin/.claude/logs/agent-compliance.log`)
3. For each open TODO, calculate days-open and apply the escalation ladder:
   - 0–2 days: Normal (mention only if relevant)
   - 3–6 days: Yellow (mention at session start)
   - 7–13 days: Orange (recommend acting today)
   - 14+ days: RED (refusal protocol — see below)
4. If any RED items exist: refuse new work, demand action or deferral
5. Otherwise: surface top 3 priorities, ask what user wants to work on today

## Refusal protocol (RED-severity items)

If the coordinator finds a 14+ day overdue item, its output begins with:
Cannot start new work today. RED-severity blocker:
[Item description]
[Days open: N]
Either:
(a) Act on this now (recommended), OR
(b) Defer with format: "defer [item] to [YYYY-MM-DD] because [reason]"
I will not dispatch any other agent until one of these happens.

This is enforced. The /start-session command does not have an override.

## Notes for the user

- If no current-state.md exists yet (fresh project), the coordinator reports "No state file — fresh project. What would you like to start with?"
- If you need to skip the escalation check temporarily (e.g., emergency hotfix), use `/start-session emergency` — but this still logs the skip to the compliance log for accountability

