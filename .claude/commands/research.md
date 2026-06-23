---
description: Dispatch the Research agent with a topic. Returns a structured research brief. Use when you need current information, library comparisons, CVE checks, framework docs, or any external knowledge before making a decision.
---

# /research

## Usage
/research [topic]
/research [topic] depth=quick
/research [topic] depth=deep

Examples:
/research "latest CVEs for express-rate-limit"
/research "RSS feed parsing libraries Node.js 2026" depth=quick
/research "German job posting salary transparency law 2026" depth=deep

## Depth options

| Depth | Sources | Use when |
|-------|---------|----------|
| `quick` | 1–5 sources, ~5 min | Factual questions with clear answers — version numbers, deprecation status, quick API lookups |
| `standard` | 5–15 sources, ~15 min | Comparative questions, design tradeoffs, "how do people handle X" (default if not specified) |
| `deep` | 15+ sources, ~45 min | Substantial design decisions, legal/regulatory questions, anything where a wrong answer has high cost |

## What the Research agent returns

A structured brief with:
- Summary (1–3 sentences answering the question)
- Findings (structured by option/aspect)
- Recommendation (specific, or "inconclusive — here's why")
- Sources (numbered, with URLs)
- Confidence: high / medium / low

## When to use /research

- Before picking a library or tool ("which RSS parsing library is actively maintained in 2026?")
- Before a legal or compliance decision ("does GDPR Art. 17 apply to our audit logs?")
- Before assuming a dependency is safe ("any known CVEs for this package?")
- When planning needs external knowledge you don't already have
- Any time you're about to make a decision based on something you're not certain about

## When NOT to use /research

- To look up your own codebase — use Grep or Read directly
- To generate opinions about your architecture — that's a design decision, not a research lookup
- To replace reading official documentation you can access yourself in 2 minutes
- For tasks Claude already knows well from training (basic syntax, well-established patterns)

The Research agent is for external, current, or uncertain knowledge — not for things already in the model's training data.
