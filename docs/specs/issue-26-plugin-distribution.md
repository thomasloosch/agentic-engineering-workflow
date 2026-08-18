# Spec — #26 Plugin distribution for the portable/learning half

**Issue:** #26 · **Status:** **Gate 1 APPROVED 2026-08-17** · **Drafted:** 2026-08-14
**ADR:** [ADR-0007](../adr/0007-plugin-distribution-for-the-portable-half.md) — **ACCEPTED**

## Gate 1 decisions (2026-08-17)

1. **Q1 ordering — decide the split now; do not build the checklist copies.** None of the
   plugin-delivered artifacts is hard-`@`-imported (Rule 2 links `verification.md` by URL, not
   path), and the plugin cache is their offline mirror. So the mirror copies were never
   load-bearing. #17 slice 2 is reduced accordingly; the throwaway is avoided.
2. **Q2 — the standards doc stays COPY-propagated.** Sole learning artifact that remains a copy,
   because it is the one hard-`@`-imported path and #16's fix now detects its drift.
3. **Q3 auto-update** — an implementation question inside slice 4, not a gate question.
4. **Q4 catch-log** — schema ships with the plugin; the empty table is placed once by bootstrap.
5. **Mechanism finds adopted, not rebuilt:** version guard invokes `claude plugin tag --dry-run`;
   consumers use `marketplace add --sparse`.

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
| **the one exception — PROVISIONAL, see slice 0** | `engineering-standards.md` | **bootstrap copy** (Q2), pending the `@`-import test | hard-`@`-imported by path. Q2 kept it copied to avoid breaking that import — but the copy is per-checkout ephemeral in practice (jobs-radar gitignores it *and* the manifest), so this is a leaky answer that slice 0 must either replace or confirm deliberately |
| **mechanical wiring** | CI workflows, git hooks, lint config, test entrypoint, `package.json` scripts, `core.hooksPath` | bootstrap + `setup-project.sh` | **must** be files in the consuming repo — CI cannot run a workflow inside a plugin, git cannot execute a hook it cannot see |
| **project-owned data** | catch-log **rows**, `current-state.md` | neither — created once, never distributed | accumulating locally is the entire point (#17 D2a already settled this) |

The line is drawn by a mechanical test, not by taste: **does something outside Claude Code have to read the file?** If yes (git, GitHub Actions, npm), it must be a real file in the repo. If only Claude Code reads it, it can be a plugin.

## 3. Slices

**Slice 0 — ANSWER THE `@`-IMPORT QUESTION FIRST. This is the load-bearing unknown and it gates the delivery model.**

**Can a plugin-delivered artifact be `@`-imported by its namespaced path?**

Everything about the standards doc hangs on it:

- **If YES** — the standards doc migrates to the plugin, and each project's `CLAUDE.md` changes its `@`-import line **once**. Clean, and the copy problem disappears for every learning artifact without exception.
- **If NO** — we accept the copy-leak and lean on #16's drift detection. The doc stays copied, permanently and for a stated reason rather than as an interim default.

**Q2's "keep it copied" was decided on a durability assumption that #17 slice 4 disproved.** jobs-radar gitignores both the portable assets *and* `.asset-manifest`, so the copied standards doc is **per-checkout ephemeral** and its drift state is **per-clone**. A fresh clone has no standards doc at all until bootstrap runs. So the copy model is leaky for precisely the one file it was retained for — which means this spec has to *solve* standards-doc delivery rather than default to "copy for now."

**Test it, do not reason about it.** Concretely: publish the plugin locally, install it, and try `@`-importing the standards doc from a consuming project's `CLAUDE.md` by whatever namespaced path the plugin exposes — then confirm with `/memory` (or an equivalent observable) that the import **actually resolved**, not merely that the line was accepted. A line that silently fails to import is `artifact-vs-effect` on the highest-value artifact in the system, and this program has logged that class five times.

No other slice commits to a delivery model until this is answered.

### Slice 0 — findings so far (2026-08-17). Partially answered; the live half is blocked.

**Established by observation, not inference:**

1. **The plugin installs and works.** `marketplace add` → `install` → `uninstall` → `marketplace remove` all run **non-interactively** (AC2 satisfied). `claude plugin details` reports 11 skills and ~630 tokens always-on.
2. **The cache path is VERSION-NAMESPACED:**
   `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/…` — e.g. `…/agentic-engineering-workflow/0.1.0/docs/standards/engineering-standards.md`.
   **This is close to decisive against an absolute-path `@`-import.** Even if such an import resolves, the path contains the version, so it would break on **every plugin release**, in **every project**. A propagation mechanism that requires editing every consumer's `CLAUDE.md` on each version bump is worse than the copy it replaces.
3. **The cache carries the WHOLE repo** — `docs/`, `hooks/`, `.github/`, and `node_modules/`. The standards doc *is* present and current there. Shipping `node_modules/` to every consumer is waste; the plugin `source` needs narrowing, or `marketplace add --sparse` used on the consumer side. Folded into slice 1.

**Suggestive, explicitly NOT proven:** `${CLAUDE_PLUGIN_ROOT}` exists in the CLI, but the surrounding text places it in **hook/command exec-form** substitution ("resolved as an executable and spawned directly … no shell. Path placeholders like `${CLAUDE_PLUGIN_ROOT}` are substituted per-element"). Nothing observed ties it to `CLAUDE.md` memory imports. That is a string's context, not a test, and it is recorded as a hint rather than an answer.

**Blocked here:** the live resolution test needs a Claude session in a consuming project, and a nested `claude -p` from inside this session fails with `401 OAuth access token has been revoked`. The test was **not** run, and the question is **not** answered by inference.

**The exact test to run, in a fresh interactive session:**

```
# 1. install
claude plugin marketplace add <path-to-this-repo>
claude plugin install agentic-engineering-workflow@thomasloosch

# 2. in a THROWAWAY project, CLAUDE.md containing ONE of:
#    @${CLAUDE_PLUGIN_ROOT}/docs/standards/engineering-standards.md
#    @~/.claude/plugins/cache/thomasloosch/agentic-engineering-workflow/0.1.0/docs/standards/engineering-standards.md

# 3. confirm it RESOLVED, not that the line was accepted:
/memory
```

`/memory` lists what actually loaded. A line that is accepted but silently fails to import is `artifact-vs-effect` on the highest-value artifact in the system — the class already logged six times here — so "no error appeared" is not evidence.

**Current reading:** finding 2 means even a YES on resolution probably does not rescue plugin delivery for the standards doc, unless a version-independent placeholder works in imports. So the likely outcome is **the copy stands** — but as a *decided* answer with a stated reason, not the interim default Q2 left behind.

**Slice 1 — the manifests.** `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`, modelled on Cole's, pointing at `./.claude/skills`. Verify `claude plugin marketplace add <repo>` then `claude plugin install` works non-interactively, from a clean state.

**Slice 2 — the version guard.** CI step failing when `.claude-plugin/**` or any shipped skill changes without a `plugin.json` version bump. Implemented by invoking `claude plugin tag --dry-run` where possible, falling back to a git-diff comparison of the version field. Includes its mutation check (AC5).

**Slice 3 — move the checklists into the plugin.** `verification.md`, `code-review.md` become plugin-delivered. Removes the need for #17's D2a mirror banner *for these two files*.

**Slice 4 — auto-update path.** Investigate lifting `DISABLE_AUTOUPDATER` and using per-marketplace `autoUpdate`. If blocked, wire the fallback into #22's drift-check with a "what changed / next session gets vX" report. **A SessionStart update hook is out of scope and rejected in the ADR** — 5–6 s/session for zero freshness gain, because the update cannot apply until the next session regardless.

**Slice 5 — docs.** State the next-session currency plainly wherever propagation is described.

## 4. Acceptance criteria

Each names the instrument that reads it (catch 7).

| # | Criterion | Instrument |
|---|---|---|
| 0 | **The `@`-import question is answered by test, not inference** — a plugin-delivered file is `@`-imported from a consuming project and the import is confirmed to RESOLVE (not merely to be accepted). Result recorded either way, and the standards-doc delivery model follows from it | live install + `/memory` or equivalent showing the import loaded |
| 1 | Both manifests exist and validate against their `$schema`s | a JSON-schema check in CI |
| 2 | `claude plugin marketplace add <this repo>` then `claude plugin install` succeeds **non-interactively** from a clean marketplace state | scripted run in a fixture `HOME`, asserted exit 0 |
| 3 | A consumer session loads the skills **from the plugin**, with no copied duplicates in its `.claude/skills/` | `claude plugin list` + absence of the paths in the project tree |
| 4 | CI **fails** when shipped plugin content changes with an unchanged `plugin.json` version | deliberate un-bumped change on a branch; assert the job goes red |
| 5 | **Mutation check:** stub the version guard to always-pass and confirm AC4 goes red | catch 3 — a guard that stays green with itself removed is vacuous |
| 6 | The mechanical half still installs via bootstrap and is unaffected | `scripts/bootstrap-project.test.sh` still green; manifest still lists the mechanical assets |
| 7 | No doc claims live updates; next-session currency stated where propagation is described | grep for the claim; read the propagation docs |
| 8 | ~~jobs-radar's stale standards doc~~ — **moved out of this issue.** Q2 keeps the standards doc copy-propagated, so this is repaired by **#17 slice 4** (re-bootstrap) and does not wait on the plugin | `sha256sum` against canonical, in #17 |

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

## Gate 1 — APPROVED 2026-08-17

All four questions answered in the decisions block at the top. Proceed with slices 1-5.

**One accepted consequence, stated so nobody is surprised:** until the plugin ships, a newly
bootstrapped project has no local copy of `verification.md` or `code-review.md`. Rule 2's URL
reference covers it. The gap is brief and non-breaking, and closing it with throwaway copies was
the waste this decision avoided.
