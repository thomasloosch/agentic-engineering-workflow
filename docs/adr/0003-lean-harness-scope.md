# ADR-0003: Lean-harness scope — adopt principles, not the GCP/multi-agent stack

**Status:** Accepted
**Date:** 2026-07-17
**Context source:** Review of Google's "The New SDLC With Vibe Coding" (Day-1, May 2026) against the current `agentic-engineering-workflow`.

## Context

The Day-1 paper's mental models (vibe→agentic spectrum, context engineering, tests+evals, the factory model, harness = model + everything-else, "most agent failures are configuration failures") map well onto this workflow — in several areas the workflow is already ahead of the paper's target reader.

However, the paper's "Where to start" prescriptions tilt toward a Google- and org-scale agenda: Agents CLI / ADK, Agent Runtime deployment, the Agent2Agent (A2A) cross-agent protocol, multi-agent teams and orchestration layers, and hiring / team-structure reframes. This workflow is a solo system, deliberately lean: the coordinator and custom-agent layer were already retired (`.claude/agents/` empty), with mp-skills as the unit of reuse. The paper's own evidence — the large "harness effect" on benchmarks and the finding that most agent failures are configuration failures, not model failures — supports keeping the harness small and well-configured rather than adding agent-orchestration surface area.

A decision is recorded here to prevent re-litigation of "should we adopt ADK / A2A / multi-agent" every time the paper (or a successor) is revisited.

## Decision

**Adopt the paper's principles; do not adopt its GCP/multi-agent tooling.**

Adopted (tracked as issues #4–#9):
- Output/quality evals with rubrics, alongside the existing TDD/test gate (#4)
- Run-level observability — traces, token/cost/latency, drift (#5)
- Single-sourced, versioned context to prevent harness drift (#6)
- Security guardrail hook + AI-failure-mode-tuned code review (#7)
- Intelligent model routing across model tiers (#8)
- Examples as an explicit context type (#9)

Explicitly **not** adopted:
- Agents CLI / ADK and Agent Runtime as the build/deploy substrate
- Agent2Agent (A2A) cross-agent delegation protocol
- Multi-agent teams / orchestration layers (re-introducing a coordinator)
- Org-scale prescriptions: hybrid human-agent team structures, hiring/role reframes

Retained substrate: a single frontier model + mp-skills + deterministic hooks + gates. MCP remains acceptable for tool access; A2A is out of scope until a concrete cross-agent need exists.

## Consequences

Positive:
- Keeps the harness lean, reproducible, and low in configuration-failure surface — the paper's own stated failure mode.
- Preserves the deliberate retirement of the coordinator/custom-agent layer.
- Avoids vendor lock-in and re-platforming; skills stay portable across tools.
- Focuses effort on the genuine deltas (evals, observability) rather than orchestration machinery.

Negative / trade-offs:
- Forgoes multi-agent parallelism and managed agent-runtime conveniences.
- Some paper "where to start" items are intentionally skipped; FOMO risk, mitigated by tracking the adopted subset as issues #4–#9.

Revisit trigger:
- A concrete, demonstrated need for cross-agent delegation or a hosted agent runtime at scale (e.g. a background agent fleet serving real users). At that point this ADR is superseded, not silently overridden.
