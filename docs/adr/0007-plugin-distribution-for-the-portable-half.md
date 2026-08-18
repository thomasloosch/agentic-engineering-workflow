# ADR-0007: Distribute the portable half as a marketplace plugin; keep mechanical wiring in bootstrap

**Status:** **ACCEPTED 2026-08-17.** Both gate questions resolved; the split below is the decision.
**Date drafted:** 2026-08-14 · **Accepted:** 2026-08-17
**Context source:** the harness-hardening program, item 2. Supersedes part of #25 and reshapes part of #17 — see Consequences.

## Gate decisions (2026-08-17)

**Q1 — ordering: decide the split now, do not build the checklist copies.** The
reasoning that settles it: none of the plugin-delivered artifacts is hard-`@`-imported.
Rule 2 links `verification.md` by **URL**, not by path, so nothing breaks when the
file is not on disk. And the plugin cache *is* the offline mirror — plugin delivery
keeps offline access while removing the second copy that could drift. So the mirror
copies were never load-bearing, and building them would have been throwaway work.

Consequence for #17 slice 2: **it drops the mirror-bannered checklist copies and
D2a's banner for them.** Mechanical propagation is unaffected and proceeds.

**Accepted interim gap:** until the plugin ships, a newly bootstrapped project has
no local checklist copy. It is covered by the URL reference in Rule 2, so the gap is
brief and non-breaking — not worth building throwaway copies to close.

**Q2 — the standards doc stays COPY-propagated. VERIFIED BY TEST 2026-08-18, no
longer provisional.**

Q2 was originally decided on the reasoning that plugin-delivering the doc would
break the hard `@.claude/engineering-standards.md` import. That reasoning rested on
a durability assumption which #17 slice 4 disproved (the copy is per-checkout
ephemeral — jobs-radar gitignores it *and* the manifest). So the answer was
re-opened and settled empirically instead:

| variant | result |
|---|---|
| **A** — `@${CLAUDE_PLUGIN_ROOT}/docs/standards/engineering-standards.md` | **FAILED to resolve** |
| **B** — `@~/.claude/plugins/cache/<mkt>/<plugin>/0.1.0/docs/standards/…` | **RESOLVED** — returned the two sentinel facts (the 2026-08-17 hook-retirement date and "Rule of three before extracting"), neither guessable from a bare project |

**What this establishes, precisely.** Plugin-delivered files *are* importable — B
proves the memory-import loader resolves into the plugin cache. What fails is the
**version-independent placeholder**. And the cache path is version-namespaced
(`.../<plugin>/0.1.0/...`, with no `latest` alias — the cache directory contained
only the version), so variant B embeds the version and would break on **every
release, in every project**.

A propagation mechanism that requires editing every consumer's `CLAUDE.md` on each
version bump is strictly worse than the copy it would replace. **So the copy stands
as verified fact rather than as an interim default**, and the standards doc is the
sole learning artifact that remains copy-propagated.

> **Revisit trigger — narrow and specific.** If Claude Code gains a
> version-independent way to reference a plugin file from a `CLAUDE.md` import —
> `${CLAUDE_PLUGIN_ROOT}` working in memory imports, or a `latest`/unversioned
> alias in the cache path — plugin delivery for the standards doc reopens
> immediately, because B already proves the import itself resolves. Nothing else
> about this decision needs revisiting; only that one capability.

This does **not** affect the checklists. `verification.md` and `code-review.md` are
referenced by URL (Rule 2), not by `@`-import path, so they carry no such
dependency and remain plugin-delivered.

**Mechanism finds adopted rather than rebuilt:** the CI version guard invokes
`claude plugin tag --dry-run` (it already validates plugin.json ↔ marketplace
agreement); consumers use `marketplace add --sparse` to avoid fetching this whole
repo.

---

## Context

Two facts force this decision.

**The copy-propagation model has a structural failure mode, now demonstrated
twice.** #16 was exactly this: bootstrap copies workflow assets into a project,
records hashes in `.claude/.asset-manifest`, and `sync-project-assets.sh` diffs
three hashes to detect drift. That machinery works, but its correctness rests on
a manifest that a second bootstrap run silently emptied — and the drift detector
then reported the project healthy while tracking nothing. The fix landed, but the
*class* remains: every propagated file is a copy that can diverge, and every copy
needs provenance tracking to notice. jobs-radar still carries a stale
`@`-imported standards doc for this reason.

**Claude Code has a first-class distribution mechanism we are not using.**
Plugins load skills, and marketplaces distribute plugins from a git repo. Verified
against the installed CLI (2.1.169), not assumed:

- `claude plugin marketplace add|update|list|remove` and `claude plugin
  install|update|list` all exist and run non-interactively.
- `claude plugin update` self-documents the currency model: *"(restart required to
  apply)"*.
- `claude plugin marketplace add --sparse <paths...>` limits the checkout via git
  sparse-checkout — so a marketplace repo need not ship its whole tree.
- `claude plugin tag` creates a `{name}--v{version}` tag "validating that
  plugin.json and any enclosing marketplace entry agree" — a manifest-agreement
  validator already exists and does not need writing.
- `coleam00/skills` (MIT) is a working reference: `.claude-plugin/marketplace.json`
  plus `.claude-plugin/plugin.json`, both with `$schema` refs, the plugin pointing
  at `./.claude/skills`.

This repo has **no** `.claude-plugin/` directory and is registered in no
marketplace.

## Decision

**Split distribution by artifact kind.**

**Portable / learning half → a marketplace plugin from this repo.** Skills,
`verification.md`, `code-review.md`, and the catch-log *schema*. These are read-only
reference material: a project consumes them, and a project has no business editing
them. Distributing them as a plugin means there is **no second copy to drift**,
which dissolves the #16 class for this half rather than tracking it more carefully.

**Exception, decided at Gate 1: the engineering-standards doc stays copied** — it
is hard-`@`-imported by path, so plugin-delivering it would silently break every
project's standards import. See Q2 above.

**Mechanical wiring half → stays with bootstrap and `setup-project.sh`.** CI
workflows, git hooks, lint config, the test entrypoint, `package.json` scripts,
`core.hooksPath`. These must be *files in the project's own repo* — CI cannot run a
workflow that lives in a plugin, and git cannot execute a hook it cannot see. This
half is inherently per-project and inherently copied.

**The catch-log itself is neither.** Its schema is portable and ships with the
plugin; its *rows* are project-owned data that must never be centrally distributed.
This matches #17's D2a decision, which already established that the catch-log is
not a mirror.

## Consequences

### For #25 (cross-project sync + up-promotion)

**The down-direction sync is superseded for the portable half.** There is nothing
to sync if there is nothing copied. `sync-project-assets.sh` remains correct and
necessary for the mechanical half, which is not going away. So #25 narrows rather
than closes — and its *up*-direction (promotion from a project's catch-log to the
centre) is untouched by this decision and stays parked.

### For #17 (full-harness bootstrap)

**Slice 2 is reduced, per the Q1 decision.** The mirror-bannered copies of
`verification.md` and `code-review.md` are **not built** — those become
plugin-delivered, and D2a's banner is unnecessary for them because the drift it
warns about cannot occur without a copy. What remains in slice 2: placing the
catch-log skeleton (project-owned data, must be a file) and keeping the standards
doc copy (Q2). Mechanical propagation is unaffected.

Deciding this before #17 built the mirror machinery is the whole reason this ADR was
drafted ahead of schedule, and it avoided the throwaway.

### Currency: next session, never current

Stated plainly because it is a limitation, not a caveat to bury: **plugins load at
session start, before any update can apply.** `claude plugin update`'s own help
says "restart required to apply". So a change pushed to this repo reaches a project
on its *next* session, never the current one. Any design that promises live
propagation is wrong. This is strictly better than the status quo, where a change
reached a project only when someone remembered to re-run a script — but it is not
instant, and the docs must not imply it is.

### Versioning is load-bearing, and un-versioned changes are silent no-ops

A `.claude-plugin/` content change without a `version` bump in `plugin.json` will
not be picked up. That failure is **silent** — the exact `fail-open` shape this
program keeps finding — so a CI guard that fails on changed plugin content with an
unchanged version is not optional. `claude plugin tag` already validates
plugin.json/marketplace agreement and should be reused rather than reimplemented.

### Auth

The workflow repo is **public**, so HTTPS and SSH both work and no credential
helper is needed. Recorded for the future: if a private repo ever becomes a
marketplace, auto-update disables the credential helper and SSH becomes required.

**Premise corrected during this work.** The program brief stated that
`CLAUDE_CODE_PLUGIN_PREFER_HTTPS` "does not exist in 2.1.169 — use
`CLAUDE_CODE_REMOTE` if HTTPS forcing is needed." Both exist and are equivalent.
The binary contains:

```js
function xWH(){return q8(process.env.CLAUDE_CODE_REMOTE)||q8(process.env.CLAUDE_CODE_PLUGIN_PREFER_HTTPS)}
```

Either variable triggers the same path. Neither is needed for a public repo; the
note is kept only so a future private-marketplace decision starts from fact.

### What we give up

- **A project can no longer locally override a propagated checklist.** Today it
  can (bootstrap preserves overrides). Under a plugin it reads what the plugin
  ships. This is mostly a *gain* — local edits to shared learning are the drift
  source D2a's banner exists to discourage — but it is a real loss of flexibility
  and should be a conscious one.
- **Offline/air-gapped use.** A plugin is fetched from git; a copied file is
  already there. Not currently a constraint.
- **A second mechanism to understand.** Two distribution paths instead of one, with
  a rule for which artifact goes where. Justified only because the two halves have
  genuinely different requirements (CI cannot read a plugin).

## Alternatives rejected

**Keep everything in copy-propagation.** Rejected: it means permanently maintaining
provenance tracking for read-only reference material that has no reason to be
copied. #16 is the cost of that model, paid once already.

**Move everything to the plugin.** Rejected: impossible. CI workflows must be files
in the consuming repo, and git hooks must be on disk where git looks.

**A SessionStart hook that runs `claude plugin marketplace update`.** Rejected on
measurement, not taste: it costs 5–6 s per session and buys nothing, because the
update cannot apply until the *next* session anyway. Deliberately recorded as
rejected so it is not proposed again.

## Gate-1 questions — all resolved 2026-08-17

Q1 (ordering) and Q2 (the standards doc) are answered at the top of this file.

Q3 (auto-update mechanism) remains an implementation question inside #26 slice 4
rather than a gate question: investigate lifting `DISABLE_AUTOUPDATER` and using
per-marketplace `autoUpdate` first, and fall back to triggering
`claude plugin marketplace update` from #22's drift-check if the runtime-injected
variable is not ours to change. A SessionStart update hook stays rejected.
