# ADR-0002: Lifecycle hooks in the Desktop runtime — AMENDED

**Status:** SETTLED 2026-08-17 — amendment complete, all gaps closed on measured
evidence, probe removed. The original claim was **wrong in its central assertion
and right in its practical conclusion**, for a different reason than it gave.
**Supersedes:** the original text, preserved verbatim at the bottom.
**Evidence source:** the hook-revival build (see `hooks/hooks.test.sh`,
`hooks/lib/json-extract.sh`, and the live probes recorded below).

---

## What the original ADR claimed

That the `PreToolUse` hooks "fire correctly only in the terminal CLI" because they
assume Linux `$HOME/.claude/…` paths that don't hold in MINGW — so git discipline
is **advisory-only (manual)** in the Desktop runtime.

## What is actually true

**Lifecycle hooks DO fire in the Desktop/MINGW runtime, and blocking hooks DO
block.** Verified live, through the real invocation path — not inferred:

| probe | result |
|---|---|
| `git add -A --dry-run` | **BLOCKED.** `PreToolUse:Bash hook error: [block-git-add-all.sh]` — the tool call was refused. |
| `git push --force --dry-run origin main` | **BLOCKED.** `PreToolUse:Bash hook error: [block-force-push-to-main.sh]` — refused. |

Both commands were chosen to match the guard pattern while being harmless if the
hook did *not* fire, so the probe could not cause damage in the case it was
designed to detect.

**The real cause of the apparent deadness was `jq`.** Four of the five hooks ran
`VAR=$(echo "$PAYLOAD" | jq -r ...)` under `set -euo pipefail`. `jq` is not
installed in this runtime, so each hook exited **127 at its first extraction
line**, before reaching any of its own logic. Claude Code treats exit **2** as
"block" and every other non-zero as a *non-blocking* error — so those four hooks
did not merely fail, they **failed OPEN**: the dangerous command proceeded and
nothing surfaced the problem. `check-claude-md-staleness.sh`, the one hook that
never used `jq`, was unaffected the whole time.

The `$HOME` reasoning in the original ADR was not the operative mechanism. `$HOME`
resolves fine here (`/c/Users/Admin`), and the hooks are registered with
`$HOME/.claude/hooks/...` paths that Claude Code expands correctly.

## The genuine limitation — narrower, and inverted

What *is* true, and is the useful half of the original conclusion:

**Non-blocking hook output is invisible in this runtime.** A hook that exits 0
and writes to stderr produces nothing the user sees. Evidence:
`warn-direct-commit-to-main.sh` sits in the *same* `PreToolUse` matcher block as
the two hooks proven above to fire and surface their messages. A `git commit` on
`main` therefore certainly invoked it — and no warning appeared, twice.

So the correct statement is the inverse of the original:

> Hooks are **enforcing**, not advisory. What is advisory — a warn-only hook that
> exits 0 — is effectively **mute**, and cannot be relied on to inform anyone.

## All three lifecycle events fire — measured, 2026-08-17

The two gaps this ADR left open are now closed by direct measurement rather than
by inference. `hooks/probe-hook-firing.sh` ran across **three days and 18 sessions**
and logged 300 invocations to `~/.claude/logs/hook-firing-probe.log`:

| event | invocations |
|---|---|
| `PreToolUse` | 142 |
| `PostToolUse` | 140 |
| `SessionStart` | 18 |

`PostToolUse` fired for `Bash` (82), `Edit` (47), `Write` (6), `Read`, `Agent` and
`ToolSearch` — so it is not limited to a narrow matcher set. `SessionStart` fired
once per session, 18 times.

**Conclusion: every lifecycle event this repo uses fires in the Desktop/MINGW
runtime.** Nothing about the runtime prevents hook enforcement. The original ADR's
central assertion is false in full, not merely in part.

The probe has been removed from `~/.claude/settings.json` and from the repo. It
was a measuring instrument with a defined end condition, and leaving it installed
would have been a permanent 300-writes-and-counting side effect for a question
already answered.

**Why this needed measuring at all**, given it was reasonable to expect: expectation
is exactly what the original ADR ran on. It asserted a mechanism nobody had probed,
and that assertion then justified four weeks of architectural workarounds. The cost
of measuring was one probe script; the cost of not measuring was a false premise
underneath several decisions.

## Consequences

**Reviving these hooks changed live behaviour, deliberately.** Four guards that
were silently passing everything now block. Specifically: `git add .` / `-A` /
`--all` is refused, and force-push to `main`/`master` is refused. This is the
intended effect and the reason it is recorded here rather than left as a quiet
bug fix — anyone who found those commands working is going to find them stopping.

**What carries forward unchanged from the original:** deterministic
history-scanning checks still belong in CI, and the git-native `pre-commit` guard
(`core.hooksPath`) remains the right mechanism for commit-time secret scanning —
verified again during this work: a planted `AKIA…` key was genuinely refused, with
no commit created. That conclusion was correct; only its stated reason changes.

**What does NOT carry forward:** "hooks are advisory-only in the Desktop runtime"
must not be cited as a reason to avoid building a hook, or as a reason to assume a
hook isn't running. The opposite is now evidenced. A *warn-only* hook, however, is
close to pointless here — if it matters, make it block.

**An option reopened, deliberately not chased.** Several git-native workarounds in
this repo exist *because* lifecycle hooks were believed to be advisory here — the
git-native `pre-commit` guard being the main one. That premise was wrong, so
lifecycle hooks are now available for real enforcement. **This is recorded as an
available option, not a refactor to perform.** The git-native guard still has an
independent justification (git runs it on any operation, including ones issued
outside Claude Code entirely), so there is nothing broken to fix. Simplifying on
the strength of a newly-corrected premise, immediately, is how you trade one
unverified assumption for another.

**`warn-direct-commit-to-main` is retired** — decided on this evidence rather than
left ambiguous. It exited 0 and wrote to stderr, which never surfaces, so it warned
no one for its entire life. Worse, its presence read as coverage. The two options
were to make it block or to drop it, and blocking would contradict **ADR-0001**:
direct-to-main is the *expected and approved* path for a solo repo, so a blocking
guard would fire on correct behaviour. A warning with no audience, on a path that
is not a mistake, has no remaining purpose.

> **Revisit trigger:** a project on this machine gains collaborators, at which point
> Standard 10 becomes active for it and a **blocking** version is the right build.
> Not a warning — this ADR is the evidence that warnings do not reach anyone.

**Standing lesson.** A guard that dies before its own logic is worse than no
guard, because its presence reads as coverage. The class is `fail-open-guard`
(catch-log), and this is its second instance in two builds — after #16's manifest
defect. Both were invisible until something deliberately probed for effect rather
than presence.

---

## Original text (2026-07-17), preserved

> # Enforcement hooks are advisory-only in the Desktop runtime
>
> The enforcement hooks are bash `PreToolUse` scripts that assume Linux
> `$HOME/.claude/…` paths; in the Claude Code Desktop app's MINGW runtime `$HOME`
> is the Windows user home and those assumptions don't hold, so the hooks fire
> correctly only in the terminal CLI. Git-discipline and enforcement are therefore
> **advisory-only (manual)** in the Desktop runtime — the layer where work actually
> happens. Downstream consequence: this is why the `warn-direct-commit` hook is
> advisory, and why deterministic checks (e.g. a git-history secret-scan) belong in
> CI, not local pre-push hooks (a local hook would be dormant here — false
> confidence).
