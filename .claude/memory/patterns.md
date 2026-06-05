# Patterns

## Findings

[2026-06-01] [Code-Review] [CODE-REVIEW] berlinstartup.js: res.text() outside try/catch in fetchDetail — body-read errors bypass prod fail-closed handler | ADVISORY
[2026-06-01] [Code-Review] [CODE-REVIEW] Task D6a — CLEAN PASS (0 blocking, 1 advisory)
[2026-06-05] [Workflow] [DOCS] Box-drawing glyphs (│└┴) don't survive nested heredocs in MINGW→WSL pipe — codepoint drift breaks exact-byte match. Rule: author docs in portable ASCII; reserve Unicode for editor-typed content, never piped. | RESOLVED
[2026-06-05] [Workflow] [VERIFICATION] Shipped sync-project-assets apply path without executing it — set -u + empty array (TO_READD) crashed on first real apply. Failed safe via set -euo pipefail. W5 applied to own code: classifier was behavior-verified, writer path was only prose-verified. Rule: a script's destructive path must be run, not reasoned about, before it's trusted. | RESOLVED
[2026-06-05] [Workflow] [BOOTSTRAP] bootstrap-project.sh double-writes coordinator.md to .asset-manifest (appears twice). sync reader tolerates via dedupe; writer still needs fixing. Bundle with manifest source-path column (engineering-standards special-case). | OPEN
[2026-06-05] [Workflow] [RETRO-ACCURACY] Retro item #2 ("delete stale ~/.claude, safe") was wrong — dir held live memory (19 files incl Sovary project memory), active logs, sessions, backups, a credentials reference. Only agents/commands/skills (May 13) were fossil. Rule: "safe to delete" from a prior session is an assertion, not evidence; ls before rm, always. | RESOLVED
