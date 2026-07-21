#!/usr/bin/env bash
#
# One-time local setup: activate the git-native secret-scan pre-commit guard.
#
# core.hooksPath lives in .git/config, which is NOT committed — so every fresh
# clone starts with the guard SILENTLY INACTIVE. That is exactly the ADR-0002
# false-confidence trap (a guard you believe is running but isn't), so a fresh
# clone must run this once. CI gitleaks (.github/workflows/secret-scan.yml) is
# the committed, non-bypassable authority regardless of local setup.
#
# Idempotent: safe to re-run.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ ! -f hooks/git/pre-commit ]]; then
  echo "✖ hooks/git/pre-commit not found — are you in the workflow repo?" >&2
  exit 1
fi

chmod +x hooks/git/pre-commit
git config core.hooksPath hooks/git

echo "✔ Secret-scan pre-commit guard active (core.hooksPath=$(git config --get core.hooksPath))."
echo "  It blocks commits that introduce hard-coded secrets, fail-closed."
echo "  Bypass with 'git commit --no-verify'; CI gitleaks still catches it."
