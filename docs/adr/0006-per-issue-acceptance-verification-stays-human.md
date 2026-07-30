# ADR-0006: Per-issue acceptance verification stays with Rule 2 + human review; `/goal` struck

**Status:** Accepted — reverses the earlier "build `/goal` as a skill" decision recorded on issue #10
**Date:** 2026-07-30
**Context source:** Issue #10 (`/goal` referenced by the build flow but not installed).

## Context

Issue #10 was filed because the recorded build flow — *"CC builds (in-prompt
self-verify + `/code-review` + `/goal`)"* — asserted a step with no implementation.
Its acceptance criterion offered two branches: build `/goal`, **or** correct the
record so the flow no longer references it.

The issue's own earlier decision took the first branch: build `/goal` as a skill,
gated behind #4 and #5, with a catch-list accreting as its spec. That decision is
reversed here.

## Decision

**Strike `/goal`. Per-issue acceptance verification is Rule 2 plus human review.**

Three grounds, in order of weight:

**1. The live drift is already gone.** The build-flow text that named `/goal` has
since been removed or rewritten. Every surviving reference is either a description
of issue #10 itself or a future-tense forward link. Nothing instructs an agent to
run a command that does not exist — which is #10's acceptance criterion, second
branch, satisfied by correcting the record rather than by anyone building.

**2. The mechanizable checks are migrating to CI, where they cannot be bypassed.**
Catch 4 (exec bit) is now the "Executable-bit assertion" step in `guards.yml`; the
standards SSOT invariant is a CI step; the import guard and secret-scan guards run
there too. A `/goal` command run at the agent's discretion is a weaker enforcement
point than a required check — CI is the better home for anything mechanical, and the
catch-list's mechanical items are going there as they mature.

**3. YAGNI — the conditions that would make it necessary are not live.** `/goal`'s
justification was safety under model routing (#8) and walk-away autonomy. Neither is
in use. Building a formalized gate now would encode an admittedly incomplete
checklist against a need that does not yet exist.

**Explicitly NOT a ground: "the manual check works."** It does, but that is a
human-in-the-loop result, not evidence a gate is redundant. The catch-list is six
items, **all** surfaced by human or e2e review and **none** by agent self-check. The
manual check working is exactly what a human in the loop buys you; it says nothing
about what happens when that human is removed. Conflating the two is how the gap
would get lost.

## What carries forward

The catch-list and its two-layer (principle → derived mechanical checks) methodology
were the real artifact of the `/goal` design work, and they do not die with the
closed issue. They are rehomed to
[`docs/checklists/verification.md`](../checklists/verification.md), referenced from
Rule 2 in the standards doc — a versioned artifact that reaches every project via
the `@`-imported standards, rather than a comment thread on a closed issue. (Same
move as sending the registry limitation to #11 rather than leaving it in closed #7.)

## Revisit trigger

Neither Rule 2 (a principle) nor CI (generic invariants — secrets, exec bits,
imports) covers **per-issue acceptance verification**: "did this build satisfy issue
X's stated criteria." Today that is answered by human review of the
acceptance-criteria table, and this ADR accepts that.

> **Revisit formalizing a `/goal`-equivalent if and when verification is routed to a
> cheaper model (#8), or run without a human in the loop. Not before.**

Either condition removes the reviewer this decision leans on, at which point an
unformalized judgment-heavy verification step becomes the unsafe thing #10
originally worried about. Until then, formalizing it buys process for a risk that
is not present.

## Consequences

- #10 closes as *record corrected*, not as *built* or *wontfix*.
- The catch-list keeps accreting in its new home; its maturity signal ("new catches
  stop being special cases of principles already on the list") is not yet met.
- Eval `--json` output (#4) is consumed by whoever is verifying — human or CI — not
  by a planned command. ADR-0004's forward link is reworded accordingly.
- If #8 lands, this ADR is the first thing to re-read.
