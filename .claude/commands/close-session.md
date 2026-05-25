---
description: End a work session cleanly. Updates state files, logs learnings if corrections happened, generates weekly report on Friday/Saturday/Sunday. Run before stepping away from a project.
---

# /close-session

When this command runs, dispatch the **session-close** agent with the following instruction:
TASK: Session close — session N (auto-increment from last session number in compliance log)
PROJECT: [current project root + path to its CLAUDE.md]
SCOPE: Run the full session-close procedure. Batch-read all state. Update PM files. Log learnings if corrections > 0. Generate weekly report if today is Friday/Saturday/Sunday.
Input the session summary:

What happened this session: [user provides this in their next message, OR session-close reads from session-checkpoint.md if user just types /close-session]
Corrections received: [number, default 0 if not provided]

Begin.

## Expected session-close behaviour

The session-close agent should:

1. **Read everything in one parallel burst** (Step 1 of its procedure) — current-state, lessons, patterns, compliance log, sprint files
2. **Write everything in one parallel burst** (Step 2) — up to 9 files updated together
3. **Self-learning sweep** (Step 3, conditional on corrections > 0) — capture new lessons, increment frequencies
4. **Weekly report** (Step 4, conditional on day-of-week) — generate the weekly health report
5. **Output**: structured session-close report with files-updated checklist

## When to use this command

- At the natural end of every working session (before stepping away)
- Before switching projects
- Before a long break (overnight, weekend)
- After completing a feature or major task

Do NOT run /close-session multiple times in the same session — it'll create duplicate session entries. If you need to capture more work after running it, just keep working; the next /close-session catches everything since the last one.

## What if you forget

If you forget to run /close-session and start a new session anyway, the /start-session coordinator will detect the gap (no fresh close entry in the compliance log) and prompt: "Last session didn't close cleanly. Run /close-session to capture state, or type 'skip' to proceed without."

Skipping is fine occasionally but compounds badly. The system's reliability depends on regular closes.

