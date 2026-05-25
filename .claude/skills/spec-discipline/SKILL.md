---
name: spec-discipline
description: Gate-based spec writing with explicit checkpoints. Use whenever writing a feature spec, design doc, or technical proposal. Enforces structured output with 10 mandatory sections and pause-for-approval gates. Prevents the "write the whole spec then discover it's wrong at the end" pattern.
---

# Spec Discipline Skill

A spec written without gates is a spec discovered to be wrong only after it's complete. This skill enforces gate-based authoring: produce part, pause, get approval, produce next part.

## The 10-section template

Every spec produced under this skill has these sections in order. Empty sections are deleted (never "N/A — to be filled" or "TBD").

1. **Purpose** — what problem this solves (one paragraph)
2. **Acceptance criteria** — specific, verifiable conditions (numbered list)
3. **Out of scope** — what this spec deliberately does NOT cover (most important section, prevents creep)
4. **Architecture** — shape of the solution (prose + diagram if helpful)
5. **Data model** — tables, columns, indices, migrations
6. **API surface** — routes, methods, request/response shapes (if applicable)
7. **UI/UX** — screen flows, components, copy (bilingual if project policy requires)
8. **Failure modes** — table of failure × detection × response
9. **Verification plan** — specific tests, not "test thoroughly"
10. **Rollout** — feature flag? migration order? backfill? (if applicable)

## The 3 gates

**Gate 1 — Problem framing.** Produce only sections 1, 2, 3. Stop. Ask the user: "Does this correctly capture the problem and bounded scope? If yes, I'll continue with architecture."

**Gate 2 — Architecture.** Produce sections 4–7. Stop. Ask: "Does this architecture make sense? Push back on anything unclear or wrong before I write the failure-mode and verification sections."

**Gate 3 — Failure handling and verification.** Produce sections 8–10. Stop. Spec is complete.

After Gate 3, the Spec Writer hands off to the Coordinator for Implementation Engineer dispatch.

## Hard rules

- Never produce a spec longer than 1500 words. If you're approaching that, decompose into multiple specs instead.
- Never use vague terms: "seamlessly integrates", "robustly handles", "intuitive UX". Surface them as open questions instead.
- Never bury assumptions. Surface them at Gate 1 as explicit questions, not buried in section 4.
- Never write actual production code. Pseudocode in architecture is OK; production code is the Implementation Engineer's job.
- Never skip Gate 1, even for "small" tasks. Small tasks get 1-paragraph sections, not zero sections.

## When this skill triggers

- User asks for a "spec", "design doc", "proposal", "technical plan"
- The Coordinator dispatches the Spec Writer agent
- Any agent realizes the task at hand needs a spec before code (per Engineering Standard #3: plan before non-trivial code)
