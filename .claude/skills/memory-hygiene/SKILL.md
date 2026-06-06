---
name: memory-hygiene
description: Rules for curating lessons.md, patterns.md, and CLAUDE.md to prevent the bloat that plagued v0 of this system. Loaded by session-close and the weekly health-check. Enforces file size caps, archival rules, promotion rules, and the per-project Standing Rules limit.
---

# Memory Hygiene Skill

Self-learning systems compound. Without curation, they drown in their own output. This skill defines the rules that keep the memory files useful instead of overwhelming.

## File size targets

| File | Target | Hard cap | Action at cap |
|------|--------|----------|---------------|
| CLAUDE.md (per project) | <300 lines | 500 | Demote oldest Standing Rule |
| lessons.md | <400 lines | 800 | Run archival pass |
| patterns.md | <500 lines | 1000 | Run archival pass |
| current-state.md (per project) | <100 lines | 150 | Force user review |

When a hard cap is exceeded, the next /health-check refuses to mark health GREEN until the file is brought back under cap.

## Archival rules (run weekly via cron or /health-check)

**For lessons.md:**
- Lesson with `last_triggered` > 60 days AND `frequency` = 1 → move to `## Archive` section at bottom
- Lesson with status PROMOTED → remove from active list, leave a single-line reference noting where it was promoted to
- Active lessons stay in the main list regardless of frequency

**For patterns.md:**
- Findings older than 90 days → move to `patterns-archive.md` (separate file)
- Standing patterns (promoted from lessons) stay regardless of age

**For CLAUDE.md Standing Rules section:**
- Maximum 15 promoted rules in any project's CLAUDE.md
- If 16+: oldest by promotion date gets demoted back to `patterns.md` Standing Patterns and removed from CLAUDE.md
- This prevents the runaway-promotion pattern observed in v0 (CLAUDE.md hit 11 promoted rules; trending toward 30+)

## Promotion rules

A lesson graduates through three tiers:

1. **lessons.md** (active learnings) — entry created on first correction
2. **patterns.md Standing Patterns** (recurring patterns) — promote when `frequency >= 3` within 30 days
3. **CLAUDE.md Standing Rules** (project conventions) — promote when standing-pattern persists 2+ sprints

Manual control:
- User types `PROMOTE [lesson title]` → moves up one tier
- User types `REJECT [lesson title]` → stays active, threshold raised by 2 for this lesson
- User types `DEFER [lesson title]` → resurface candidate next week

## Weekly health indicator (one-line output)

[YYYY-MM-DD] | health: GREEN|YELLOW|RED | lessons: N | patterns: N | open TODOs: N | RED escalations: N

- **GREEN** = all targets met, no hard caps exceeded
- **YELLOW** = one cap exceeded but archival caught it this cycle
- **RED** = multiple caps exceeded OR a RED-severity TODO escalation present

The weekly indicator is appended to `$HOME/.claude/health-log.md` (or equivalent; `$CLAUDE_HOME` is unset in the MINGW desktop runtime, `$HOME/.claude` resolves to `/c/Users/Admin/.claude`, Windows-side only). One line per week.

## When this skill triggers

- session-close agent at end of every session (light pass — count entries, flag if cap nearing)
- /health-check command (full pass — apply archival, demote, prune)
- Manual invocation when files feel bloated and the user asks "why is this so slow"
