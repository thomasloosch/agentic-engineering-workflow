# Spec — #26 Plugin distribution for the portable/learning half

**Issue:** #26 · **Status:** Gate 1 — awaiting approval · **Date:** 2026-08-14
**ADR:** [ADR-0007](../adr/0007-plugin-distribution-for-the-portable-half.md) (PROPOSED — approve both together or neither)
**Reshapes:** #17 slice 2 · **Supersedes (partly):** #25 down-direction · **Feeds:** #22

---

## 0. Premise-check

Verified against the installed CLI (2.1.169) and against `coleam00/skills` (MIT), not assumed.

**Confirmed.**

- `claude plugin marketplace add|update|list|remove` and `claude plugin install|update|list` exist and run non-interactively.
- **Currency is next-session.** `claude plugin update --help` self-documents: *"(restart required to apply)"*.
- `DISABLE_AUTOUPDATER` **is** set in this runtime — verified in `env`. This is the obstacle the primary auto-update path has to clear, not a hypothetical.
- This repo has **no** `.claude-plugin/` directory and is registered in no marketplace (`claude plugin marketplace list` shows only `claude-plugins-official`).
- `coleam00/skills` is a working two-file reference: `.claude-plugin/marketplace.json` (owner, `plugins[]`, each with `source`, `skills`, metadata) + `.claude-plugin/plugin.json` (`name`, `version`, `skills`), both `$schema`-annotated.

**Found, not in the brief, and both change the plan.**

- **`claude plugin tag` already validates manifest agreement** — "creates a `{name}--v{version}` git tag, validating that plugin.json and any enclosing marketplace entry agree", and it has `--dry-run`. The proposed CI guard should **invoke this**, not reimplement it.
- **`claude plugin marketplace add --sparse <paths...>`** limits the checkout by git sparse-checkout. Lets a consumer fetch only `.claude-plugin` + the skills tree instead of this whole repo (which contains CI, hooks, scripts, docs a consumer does not need).

**Corrected.** The brief states `CLAUDE_CODE_PLUGIN_PREFER_HTTPS` "does not exist in 2.1.169 — use `CLAUDE_CODE_REMOTE`". Both exist and are equivalent; the binary contains
`function xWH(){return q8(process.env.CLAUDE_CODE_REMOTE)||q8(process.env.CLAUDE_CODE_PLUGIN_PREFER_HTTPS)}`.
Moot here (public repo — HTTPS and SSH both work), recorded so a future private-marketplace decision starts from fact.

## 1. Purpose

Kill the drift class for read-only reference material instead of tracking it better.

#16 was one instance: copy-propagation plus a manifest, where a re-run emptied the manifest and the detector then called the project healthy. That is fixed, but the *class* survives — every propagated file is a copy that can diverge. jobs-radar still carries a stale `@`-imported standards doc.

A plugin has no second copy, so it cannot drift. That is the whole argument.

## 2. The split, and why it isn't arbitrary

| half | artifacts | mechanism | why |
|---|---|---|---|
| **portable / learning** | skills, `verification.md`, `code-review.md`, catch-log **schema** | marketplace plugin | read-only reference; a project has no business editing it, so there is no reason to copy it |
| **mechanical wiring** | CI workflows, git hooks, lint config, test entrypoint, `package.json` scripts, `core.hooksPath` | bootstrap + `setup-project.sh` | **must** be files in the consuming repo — CI cannot run a workflow inside a plugin, git cannot execute a hook it cannot see |
| **project-owned data** | catch-log **rows**, `current-state.md` | neither — created once, never distributed | accumulating locally is the entire point (#17 D2a already settled this) |

The line is drawn by a mechanical test, not by taste: **does something outside Claude Code have to read the file?** If yes (git, GitHub Actions, npm), it must be a real file in the repo. If only Claude Code reads it, it can be a plugin.

## 3. Slices

**Slice 1 — the manifests.** `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`, modelled on Cole's, pointing at `./.claude/skills`. Verify `claude plugin marketplace add <repo>` then `claude plugin install` works non-interactively, from a clean state.

**Slice 2 — the version guard.** CI step failing when `.claude-plugin/**` or any shipped skill changes without a `plugin.json` version bump. Implemented by invoking `claude plugin tag --dry-run` where possible, falling back to a git-diff comparison of the version field. Includes its mutation check (AC5).

**Slice 3 — move the checklists into the plugin.** `verification.md`, `code-review.md` become plugin-delivered. Removes the need for #17's D2a mirror banner *for these two files*.

**Slice 4 — auto-update path.** Investigate lifting `DISABLE_AUTOUPDATER` and using per-marketplace `autoUpdate`. If blocked, wire the fallback into #22's drift-check with a "what changed / next session gets vX" report. **A SessionStart update hook is out of scope and rejected in the ADR** — 5–6 s/session for zero freshness gain, because the update cannot apply until the next session regardless.

**Slice 5 — docs.** State the next-session currency plainly wherever propagation is described.

## 4. Acceptance criteria

Each names the instrument that reads it (catch 7).

| # | Criterion | Instrument |
|---|---|---|
| 1 | Both manifests exist and validate against their `$schema`s | a JSON-schema check in CI |
| 2 | `claude plugin marketplace add <this repo>` then `claude plugin install` succeeds **non-interactively** from a clean marketplace state | scripted run in a fixture `HOME`, asserted exit 0 |
| 3 | A consumer session loads the skills **from the plugin**, with no copied duplicates in its `.claude/skills/` | `claude plugin list` + absence of the paths in the project tree |
| 4 | CI **fails** when shipped plugin content changes with an unchanged `plugin.json` version | deliberate un-bumped change on a branch; assert the job goes red |
| 5 | **Mutation check:** stub the version guard to always-pass and confirm AC4 goes red | catch 3 — a guard that stays green with itself removed is vacuous |
| 6 | The mechanical half still installs via bootstrap and is unaffected | `scripts/bootstrap-project.test.sh` still green; manifest still lists the mechanical assets |
| 7 | No doc claims live updates; next-session currency stated where propagation is described | grep for the claim; read the propagation docs |
| 8 | jobs-radar's stale standards doc is resolved by whichever mechanism wins for it (see Q2) | `sha256sum` against canonical, or its `@`-import verified working |

**AC4 is the load-bearing one.** An un-versioned plugin change is a **silent** no-op — the same fail-open shape as #16 and the dead hooks, which is now this program's most frequent defect class (`fail-open-guard`, 2 of 3 toward promotion). A guard against it is not optional polish.

## 5. Out of scope

- **A SessionStart plugin-update hook.** Rejected on measurement; see ADR.
- **Moving CI/hooks/lint into the plugin.** Mechanically impossible.
- **Automated up-promotion** (#25's up half) — unchanged by this, stays parked.
- **Making this repo a private marketplace.** Public today; the SSH/credential-helper note is recorded for if that ever changes.
- **Adopting Cole's skills themselves.** Separate issues; this is the distribution channel, not the payload.

## 6. Risks

- **Ordering waste against #17** (Q1). Real, and the reason this is drafted now.
- **The `@`-import breaks** (Q2). Projects `@`-import `.claude/engineering-standards.md`. A plugin does not provide that path. If the standards doc moves and the import isn't reconciled, every project's `CLAUDE.md` silently stops importing its standards — a fail-open of the highest-value artifact. **This is the single most dangerous change in the spec** and is why Q2 is a gate question rather than an implementation detail.
- **`DISABLE_AUTOUPDATER` cannot be lifted**, making slice 4 fall back to the #22 trigger. Acceptable; the fallback is genuinely useful and cheap.
- **Losing per-project override of checklists.** Mostly a gain (local edits to shared learning are the drift source), but a real loss of flexibility — should be conscious.

---

## Gate 1 questions

1. **Ordering vs #17.** Approve this before #17 builds slice 2's mirror machinery (avoiding build-then-delete), or let #17 ship mirrors and migrate after? Building first wastes work; deciding first delays #17. **Recommendation: decide this first** — slice 2 is a small part of #17 and the waste is larger than the delay.
2. **Does the engineering-standards doc move to the plugin?** It is `@`-imported at `.claude/engineering-standards.md` by every project's `CLAUDE.md`, a path a plugin does not supply. Options: (a) keep it copied by bootstrap, plugin ships only the checklists — safest, keeps one copied file; (b) move it and change the `@`-import in the CLAUDE.md template — cleaner, but silently breaks any existing project until re-bootstrapped. **Recommendation: (a) for now** — the risk in (b) is a silent loss of the standards, and the copied standards doc is the one file whose drift the #16 fix now actually detects.
3. **Auto-update priority.** Is investigating the `DISABLE_AUTOUPDATER` lift worth it before building the #22 fallback, given it is set by the runtime and may not be ours to change?
4. **Does the plugin ship the catch-log schema as a skill, or as a template file?** A skill can carry the rules and be read on demand; a file has to be placed. Leaning skill-plus-placement: the *rules* travel as reference, the empty table gets placed once by bootstrap.
