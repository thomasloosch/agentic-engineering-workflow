---
description: Route a research question to the right depth — quick factual lookups via inline web search, substantial/high-cost questions via /deep-research. Use when you need current information, library comparisons, CVE checks, framework docs, or external knowledge before a decision.
---

# /research

Decide *how* to research by how much a wrong answer costs. This is a router, not an agent — it points you at the right tool for the depth.

## Usage

```
/research [topic]
/research [topic] depth=quick
/research [topic] depth=deep
```

Examples:
```
/research "latest CVEs for express-rate-limit"
/research "RSS feed parsing libraries Node.js 2026" depth=quick
/research "German job posting salary transparency law 2026" depth=deep
```

## Route by depth

| Depth | Scope | Use when | How to run it |
|-------|-------|----------|---------------|
| `quick` | 1–5 sources, ~5 min | Factual questions with clear answers — version numbers, deprecation status, CVE checks, quick API lookups | Use `WebSearch` / `WebFetch` directly, inline. No harness needed. |
| `standard` | 5–15 sources, ~15 min | Comparative questions, design tradeoffs, "how do people handle X" (default if not specified) | Inline `WebSearch`/`WebFetch` across a few query phrasings — or `/deep-research` if the answer is load-bearing. |
| `deep` | 15+ sources, ~45 min | Substantial design decisions, legal/regulatory questions, anything where a wrong answer has high cost | Run `/deep-research` — it fans out searches, fetches sources, adversarially verifies claims, and synthesizes a cited report. |

**Graceful degradation:** `/deep-research` is a plugin skill, so it travels with the plugin, not the project bootstrap. If it isn't loaded here, inline `WebSearch`/`WebFetch` still cover quick and standard. For a deep question without it, do the fan-out by hand — several query phrasings, fetch and cross-check the top sources, then write up the findings with citations and a confidence note.

## When to research at all

- Before picking a library or tool ("which RSS parsing library is actively maintained in 2026?")
- Before a legal or compliance decision ("does GDPR Art. 17 apply to our audit logs?")
- Before assuming a dependency is safe ("any known CVEs for this package?")
- When planning needs external knowledge you don't already have
- Any time you're about to make a decision based on something you're not certain about

## When NOT to

- To look up your own codebase — use Grep or Read directly
- To generate opinions about your architecture — that's a design decision, not a research lookup
- To replace reading official documentation you can access yourself in 2 minutes
- For tasks already well-covered by training (basic syntax, well-established patterns)

Research is for external, current, or uncertain knowledge — not for things already in the model's training data.
