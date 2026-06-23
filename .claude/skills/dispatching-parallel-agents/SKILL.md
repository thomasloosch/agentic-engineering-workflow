---
name: dispatching-parallel-agents
description: Use when facing 2+ independent tasks that can be worked on without shared state or sequential dependencies. Dispatch one agent per problem domain to parallelize investigation or implementation.
---

# Dispatching Parallel Agents

You delegate tasks to specialized agents with isolated context. By precisely crafting their instructions and context, you ensure they stay focused and succeed at their task. They should never inherit your session's context or history — you construct exactly what they need. This also preserves your own context for coordination work.

When you have multiple unrelated failures (different test files, different subsystems, different bugs), investigating them sequentially wastes time. Each investigation is independent and can happen in parallel.

**Core principle:** Dispatch one agent per independent problem domain. Let them work concurrently.

## When to use this pattern

Use when:
- 3+ test files failing with different root causes
- Multiple subsystems broken independently
- Each problem can be understood without context from others
- No shared state between investigations
- A spec touches 4+ files across distinct concerns (backend route + DB migration + frontend component + i18n keys)

Don't use when:
- Failures are related — fixing one might fix others
- You need to understand full system state first
- Agents would interfere (editing same files, using same resources)
- The task is exploratory and you don't yet know what's broken

## The pattern

### 1. Identify independent domains

Group work by what's distinct:
- Domain A: backend API + tests
- Domain B: DB migration + seed data
- Domain C: frontend component + storybook
- Domain D: i18n keys in both locales

Each domain is independent — fixing one doesn't affect another.

### 2. Construct focused agent prompts

Each agent gets:
- **Specific scope** — one domain, one set of files
- **Clear goal** — measurable success criterion
- **Constraints** — what NOT to change
- **Expected output** — structured summary of findings/changes

Good prompts are:
1. **Focused** — one clear problem domain
2. **Self-contained** — all context needed, no assumed shared state
3. **Specific about output** — exactly what the agent should return

### 3. Dispatch in parallel

Launch all agents concurrently. They work in isolation, no inter-agent communication during execution.

### 4. Review and integrate

When agents return:
- Read each summary carefully
- Verify fixes don't conflict (check if any agents edited overlapping files)
- Run the full test suite — fixes must work together, not just individually
- Spot-check the changes — agents can make systematic errors

## Failure modes

**Too broad scope.** "Fix all the tests" — agent gets lost in too much state. Better: "Fix the 3 failing tests in src/agents/agent-tool-abort.test.ts."

**No context provided.** "Fix the race condition" — agent doesn't know where to look. Better: paste the error messages, test names, relevant file paths.

**No constraints.** Agent refactors unrelated code. Better: "Do NOT change production code. Fix tests only." or "Touch only files matching pattern X."

**Vague output expectation.** "Fix it." — you don't know what changed. Better: "Return: (1) root cause identified, (2) files modified, (3) test results after fix."

**Overlapping file edits.** Two agents both edit `src/utils/helpers.ts`. The second one's changes overwrite the first. Better: explicit file ownership per agent, no overlap allowed.

## Verification after agents return

1. Review each agent's summary for completeness
2. Check no two agents edited the same file
3. Run full test suite — fixes must compose
4. Spot-check at least one fix manually
5. If anything looks wrong, dispatch a single follow-up agent for the conflict rather than re-dispatching the parallel set

## When this skill triggers

- A task spans 4+ independent files across distinct concerns
- A review surfaces 3+ unrelated issues in different subsystems
- Multiple test files failing with distinct root causes
- User explicitly says "do these in parallel"

Reach for this skill when the work splits into independent domains that can run concurrently.
