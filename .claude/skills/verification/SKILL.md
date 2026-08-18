---
name: verification
description: The accumulated verification checklist — concrete checks derived from real misses, plus the AI-failure-mode code review checklist. Use before declaring work done, when reviewing a diff, when writing acceptance criteria, or whenever asking "how would I know this actually works rather than merely looks right".
---

# Verification

Two checklists, both distilled from defects that actually happened in this
workflow rather than from general good practice.

**Read the canonical files — do not work from this summary.** This skill is a
pointer, deliberately thin. Re-inlining the checks here would create a second copy
that drifts, which is the exact failure class the checklists themselves keep
recording.

## The checklists

- **`docs/checklists/verification.md`** — the two-layer catch list: principles and
  the concrete mechanical checks derived from them. Every entry exists because
  something shipped broken in a way that looked fine.
- **`docs/checklists/code-review.md`** — the three AI failure modes to review a
  diff against.

Both resolve inside this plugin's root when it is installed, and at
`https://github.com/thomasloosch/agentic-engineering-workflow/blob/main/docs/checklists/`
otherwise.

## When this matters most

The checklist's recurring theme is **present ≠ working**:

- a guard that exists but never fires
- a test that passes through a path production never takes
- a config that is committed but not in effect
- an acceptance criterion no instrument can actually read

If you are about to report something as done, the question the list keeps asking
is not *"did I do it"* but *"what did I observe that would be different if I
hadn't"*.

## The one rule that governs the rest

**Verification is not validation.** A green suite says the checks you wrote pass.
It does not say the thing is correct against anything outside your own authorship.
When correctness matters, name the independent oracle — and if there isn't one,
say so plainly rather than letting a passing suite imply one.
