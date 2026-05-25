# v1 Success Metrics

Tracked weekly during Stage 2 (job matcher) and Stage 3 (calendar).
Retro reads from this file after the calendar ships.

---

## The 5 metrics

### 1. Time-to-merge
From "task brief given to spec-writer" to "PR merged to main."
Target: should decline over time as workflow matures.
How to measure: note start time when dispatching spec-writer, note merge time from git log.

### 2. Agent override rate
Percentage of agent findings I override (mark as false positive or ignore).
Target: below 20%. Higher means agents are too noisy.
How to measure: count agent findings per week, count how many I acted on vs dismissed.

### 3. Stale TODO count
Items in current-state.md open more than 7 days.
Target: fewer than 5 at any time.
How to measure: run /health-check weekly, read the ORANGE/RED escalation count.

### 4. Brief-to-action lag
For job matcher: days between "agent sends a brief" and "I act on the output."
Target: under 2 days. Higher means the briefs are not useful enough.
How to measure: note date brief arrived, note date I applied/dismissed the match.
Note: this metric only becomes meaningful from Stage 2 week 1 onwards.

### 5. Friction moments
Things I had to manually intervene in that should have been automatic.
Target: trend downward. Each friction moment is a v2 candidate fix.
How to measure: log them in the friction log below as they happen.

---

## Weekly log

| Week | Time-to-merge avg | Override rate | Stale TODOs | Brief-to-action lag | Friction count |
|------|-------------------|---------------|-------------|---------------------|----------------|
| W1   |                   |               |             | n/a (Stage 2 not started) |           |
| W2   |                   |               |             |                     |                |
| W3   |                   |               |             |                     |                |
| W4   |                   |               |             |                     |                |
| W5   |                   |               |             |                     |                |
| W6   |                   |               |             |                     |                |
| W7   |                   |               |             |                     |                |
| W8   |                   |               |             |                     |                |

Add rows as needed. Fill in during /health-check each Sunday.

---

## Friction log

Log friction moments here as they happen. Don't wait for the weekly review.

| Date | What happened | Expected behaviour | Suggested v2 fix |
|------|--------------|-------------------|-----------------|
|      |              |                   |                 |

---

## v4 guide findings log

Track issues found during infrastructure setup execution — feeds into v4 of the setup guide.

| # | Finding | Impact | v4 fix |
|---|---------|--------|--------|
| 1 | First gh install fails silently | Lost time debugging | Fail-loud verification after install |
| 2 | WSL2 path translation not explained | Confusing cd errors | Add WSL2 path primer before Part 1.4 |
| 3 | Code-block comments pasted as commands | Minor confusion | Clearer visual distinction |
| 4 | WSL2 cannot write git config on /mnt/ | Part 1.4 impossible | Remove Part 1.4 entirely |
| 5 | Repo name case sensitivity (Sovary vs sovary) | Remote URL mismatch | Verify exact casing on GitHub first |
| 6 | HTTPS-to-SSH conversion not anticipated | Extra steps required | Detect protocol and adjust set-url command |
| 7 | Run-this vs example-only code blocks unclear | Commands pasted incorrectly | Visual markers on every code block |
| 8 | Cloudflare registrar not mentioned | Minor — had to ask | Add Cloudflare as first option |
| 9 | master vs main branch after gh repo create | Branch protection failed | Add git branch -M main after clone |
| 10 | Git config not persisting from section 1.3 | Commit failed | Add explicit verification step |
| 11 | SSH passphrase caching missing | Repeated passphrase prompts | Add ssh-agent setup to section 1.3 |
| 12 | GitHub host-key prompt not anticipated | Unexpected interactive prompt | Document it as expected |
| 13 | Empty directories invisible to git status | Minor confusion | Add note in section 3.1 |
| 14 | PR template orphaned between 2.4 and 3.1 | Template missed first time | Fix sequencing |
| 15 | No head -1 check after agent file creation | Frontmatter eaten silently | Verify first line = --- after each file |
| 16 | Sed path globalization leaves backslashes | Runtime path failures | Use Python script instead of sed chain |
| 17 | wslu not in standard Ubuntu repos | Browser opener failed | Use explorer.exe alias instead |
| 18 | PowerShell vs WSL2 confusion | Commands ran in wrong shell | Add persistent WSL2 reminder to each part |
| 19 | GitHub Actions cron runs in UTC | Wrong time for German users | Add UTC conversion note for Berlin users |

---

## Retro questions (fill in after calendar ships)

1. Did the agents actually reduce your cognitive load, or did they add overhead?
2. Which agent fired most often? Which fired least? Was the frequency right?
3. Did the escalation ladder (14-day RED refusal) help or frustrate?
4. Did the self-learning loop (lessons.md, patterns.md) stay manageable?
5. What would you add to v2 that v1 is missing?
6. What would you remove from v2 that v1 has unnecessarily?
