---
description: Defer an open TODO to a future date with a written reason. Removes the item from the escalation ladder until the new date. Prevents false RED-severity blocks on legitimate long-running items.
---

# /defer

## Usage
/defer [item description or ID] [YYYY-MM-DD] [reason]

Example:
/defer "OpenPanel upgrade" 2026-06-15 because waiting for Hetzner scheduled maintenance window

## What happens when this command runs

1. The Coordinator finds the matching item in `.claude/memory/current-state.md`
2. Updates the item with:
   - `deferred_to: YYYY-MM-DD`
   - `defer_reason: [reason]`
   - `defer_count: +1`
3. Logs the deferral to `$HOME/.claude/logs/agent-compliance.log` (`$CLAUDE_LOGS_DIR` is unset in the MINGW desktop runtime; `$HOME` resolves to `/c/Users/Admin/.claude/logs/agent-compliance.log`):
[ISO timestamp] | coordinator | defer | [item] deferred to [date] — reason: [reason]
4. The item no longer triggers the escalation ladder until `deferred_to` date is reached

## Hard rules

- **Deferral requires a date AND a reason.** `/defer "X" 2026-06-15` with no reason is rejected.
- **Maximum 3 deferrals per item.** On the 4th deferral attempt, the Coordinator refuses: "This item has been deferred 3 times. Either act on it now or explicitly drop it from the list."
- **Dropping an item** (not deferring): use `/defer [item] drop because [reason]`. This removes it from current-state entirely and logs the drop. Useful for things that no longer matter.

## Why this exists

The 14-day RED-severity refusal is non-negotiable — it's what prevents reminders from becoming wallpaper. But some long-running items are genuinely waiting on external factors (a vendor, a scheduled event, a decision that needs more time). Deferral is the legitimate escape valve for those cases.

Deferral is not for avoiding hard tasks. The defer_count field exists to surface patterns — if you've deferred the same item 3 times, the system forces a decision.
