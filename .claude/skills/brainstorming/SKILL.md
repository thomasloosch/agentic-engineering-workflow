---
name: brainstorming
description: Use before creating a feature or spec when the idea is still fuzzy. Turns a vague intent into a concrete proposal through dialogue. The upstream step that the spec-writer expects to have already happened.
---

# Brainstorming

A brainstorming session turns "I have an idea about X" into "here's what we're building, here's why, here's what's out of scope" — concrete enough to hand to the spec-writer.

This is dialogue, not a worksheet. Ask one question at a time. Build understanding incrementally.

## When to use

- The user has an idea but the shape isn't clear yet
- A spec attempt is bouncing back with "we don't even know what we want"
- The feature could go several reasonable directions and a choice needs to be made
- Stage 1 (problem framing) of the spec-writer is producing unstable answers

## When NOT to use

- The problem is already well-defined — go straight to spec-writer
- The user is asking for code, not a feature — go straight to implementation-engineer
- The work is genuinely trivial — answer directly

## The pattern

### 1. Ground the conversation

Before asking anything new, establish:
- What does the user already have? (existing project, prior context, related features)
- What concrete moment prompted this idea? (a real frustration, a missed use case, a competitive observation)
- Who is this actually for? (themselves, a specific user segment, a hypothetical persona)

Do not skip this step even when the user seems ready to dive in. Skipping produces specs that solve the wrong problem.

### 2. One question at a time

Ask one focused question. Wait for the answer. Let the answer reshape your next question.

Avoid:
- Question batches ("What about A, B, and C, and have you considered D?")
- Leading questions that contain the answer you expect
- Questions that re-ask what was already answered

### 3. Surface tensions explicitly

When two requirements pull in different directions, name the tension and ask which side matters more. Example: "You want it fast AND comprehensive — those usually trade off. Which dimension would you sacrifice first?"

### 4. Capture the shape, not the details

Before ending: write a 3-5 sentence summary of what you understood. Read it back. Get explicit confirmation. This summary becomes the input to spec-writer's Gate 1.

The summary should answer:
- What problem this solves (one sentence)
- For whom (one sentence)
- The 2-3 acceptance criteria that matter most
- What is explicitly out of scope

### 5. Hand off cleanly

When the user confirms the summary, say: "Ready to dispatch spec-writer with this brief?" Don't write the spec yourself — that's the spec-writer's job.

## Anti-patterns

- **Over-asking.** If 5+ questions in, you still don't have a concrete shape, the idea may genuinely not be ready — say so and suggest the user think more before continuing.
- **Under-asking.** Jumping to "great, I'll spec this" after 1-2 surface questions skips the actual brainstorming work.
- **Solution-shopping.** Suggesting implementations ("you could use library X, or framework Y") during brainstorming — that's the spec-writer's Gate 2 territory.
- **Validating prematurely.** "That's a great idea!" — flattery, not analysis. Brainstorming should occasionally surface that an idea isn't worth building.

## Output format

End every brainstorming session with this structure, even if the dialogue was short:

**Problem:** [one sentence]
**For whom:** [one sentence]
**Acceptance criteria (top 3):**
1. [verifiable condition]
2. [verifiable condition]
3. [verifiable condition]
**Out of scope:**
- [what this deliberately won't cover]
- [what this deliberately won't cover]

Ready to dispatch spec-writer?
