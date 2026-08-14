#!/usr/bin/env bash
#
# probe-hook-firing.sh — evidence-gathering probe for ADR-0002.
#
# PURPOSE
#
# ADR-0002 asserted that Claude Code lifecycle hooks are "advisory-only in the
# Desktop runtime." That claim turned out to rest on an artifact: four of the five
# hooks depended on `jq`, which is absent here, so they exited 127 before doing
# anything — indistinguishable from not firing at all.
#
# With that fixed, PreToolUse was proven to fire AND block (a `git add -A` and a
# force-push-to-main were both genuinely refused). Two questions remain, and
# neither can be answered from inside a running session, because hooks are loaded
# at session start:
#
#   1. Do PostToolUse hooks fire?
#   2. Do SessionStart hooks fire?
#
# The obstacle for PostToolUse specifically is that the real PostToolUse hook
# (auto-update-last-reviewed.sh) only has an observable effect when the global
# CLAUDE.md is edited — and its effect is to stamp "Last reviewed: <today>", which
# would be a FALSE claim if written by a probe rather than by an actual review.
# So this probe exists to produce an observable signal that lies about nothing.
#
# WHAT IT DOES
#
# Appends one line per invocation to ~/.claude/logs/hook-firing-probe.log:
#   <ISO timestamp>  <hook_event_name or "unknown">  <tool_name or "-">
#
# Zero dependencies (no jq — that is the whole point), never blocks, always
# exits 0. Reads stdin only to inspect it, and tolerates any payload shape.
#
# HOW TO READ THE RESULT
#
# After one fresh desktop session in which you edit a file and run a command:
#   cat ~/.claude/logs/hook-firing-probe.log
# A SessionStart line proves SessionStart fires. A PostToolUse line proves
# PostToolUse fires. An empty or absent file means that event did not fire —
# which is itself the answer, and would partially reinstate ADR-0002's original
# claim for those events.
#
# REMOVE WHEN DONE. This is a measuring instrument, not a permanent hook. Delete
# its entries from ~/.claude/settings.json and delete the log once ADR-0002 is
# settled on this evidence.

set -uo pipefail

PAYLOAD="$(cat 2>/dev/null || true)"

LOG_DIR="$HOME/.claude/logs"
LOG="$LOG_DIR/hook-firing-probe.log"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

# Extract two fields without jq. Deliberately crude: this is a probe, and a
# mis-parsed field name is far less interesting than the fact that a line was
# written at all.
event="$(printf '%s' "$PAYLOAD" | sed -n 's/.*"hook_event_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
tool="$(printf '%s' "$PAYLOAD" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"

printf '%s  %s  %s\n' \
  "$(date -Iseconds 2>/dev/null || date)" \
  "${event:-unknown}" \
  "${tool:--}" >> "$LOG" 2>/dev/null || true

exit 0
