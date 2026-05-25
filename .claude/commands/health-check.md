---
description: Weekly system health check. Counts memory entries, surfaces drift, applies archival rules, reports GREEN/YELLOW/RED health. Run on Sundays or whenever the system feels heavy.
---

# /health-check

When this command runs, do the following inline (no agent dispatch required — this is a direct bash + memory-hygiene skill invocation):

## Step 1 — Count current state

Run the following bash:
echo "=== Memory file sizes ==="
wc -l ~/.claude/memory/*.md 2>/dev/null
echo ""
echo "=== Compliance log entries (last 7 days) ==="
grep "$(date -d '7 days ago' +%Y-%m-%d)" ~/.claude/logs/agent-compliance.log 2>/dev/null | wc -l
echo ""
echo "=== Open TODOs in current project ==="
if [ -f .claude/memory/current-state.md ]; then
grep -c "TODO|Open" .claude/memory/current-state.md || echo "0"
else
echo "No current-state.md in this project"
fi
echo ""
echo "=== Recent agent activity ==="
tail -20 ~/.claude/logs/agent-compliance.log 2>/dev/null || echo "No compliance log yet"

## Step 2 — Apply memory-hygiene skill

Load the memory-hygiene skill. Walk through:

1. **Size targets** — flag any file exceeding its target or hard cap
2. **Archival rules** — identify lessons.md entries with last_triggered > 60 days AND frequency = 1
3. **Standing Rules ceiling** — count promoted rules in CLAUDE.md; flag if approaching 15

For each archival candidate, perform the move (lessons.md → Archive section; patterns.md → patterns-archive.md). For Standing Rules over 15, demote oldest to patterns.md Standing Patterns.

## Step 3 — Apply escalation ladder to all open TODOs

Read every project's `.claude/memory/current-state.md` (or just the current one if scoped). For each open TODO, calculate age and surface:

- 14+ days: RED escalation
- 7–13 days: ORANGE
- 3–6 days: YELLOW

## Step 4 — Output the weekly health line

Append one line to `~/.claude/memory/health-log.md` (create if doesn't exist):
[YYYY-MM-DD] | health: GREEN|YELLOW|RED | lessons: N | patterns: N | open TODOs: N | RED escalations: N

- GREEN = all targets met, no caps exceeded, no RED escalations
- YELLOW = one cap exceeded but archival caught it, OR one ORANGE escalation
- RED = multiple caps exceeded, OR any RED escalation present

## Step 5 — Output to user

Structured report:
Health Check — [date]
Memory files

lessons.md: N lines (target <400, cap 800)
patterns.md: N lines (target <500, cap 1000)
CLAUDE.md Standing Rules: N entries (max 15)

Archival actions taken

Moved N lessons to Archive section
Demoted N standing rules
Or: "No archival needed this week"

Escalations

RED: [list, or "None"]
ORANGE: [list, or "None"]
YELLOW: [list, or "None"]

Overall: GREEN | YELLOW | RED

## When to run

- Every Sunday evening (recommended cadence)
- When boot.md or current-state feels overwhelming to read
- When you suspect the system is drifting
- Before starting a major new feature (clean slate)
