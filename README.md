# Agentic Engineering Workflow

Multi-agent engineering workflow templates for Claude Code. Generic and project-agnostic.

**Status:** Under construction. Full setup guide coming after v1 stabilises.

## Setup

After cloning, activate the local secret-scan pre-commit guard — one command, run once:

```sh
./scripts/setup-hooks.sh
```

This is required because the guard is wired via `core.hooksPath` in your local
(uncommitted) `.git/config`, so a fresh clone starts with it **inactive**. CI
secret-scanning (gitleaks) runs on every push/PR regardless and is the enforcing
authority; the local guard is fast, fail-closed feedback before you commit.
