# Verification checklist

Concrete checks derived from real misses, supporting **Engineering Standard 2 —
"Verify before declaring done."** Rule 2 is the principle; this is the accumulated
evidence of what that principle actually requires in practice.

**Provenance.** Every item below was surfaced by human or end-to-end review — **none
by an agent's self-check**. That is the central fact about this list, and the reason
it exists as a versioned doc rather than as tribal knowledge or a closed issue's
comment thread. It accreted on issue #10 while `/goal` was a planned command;
[ADR-0006](../adr/0006-per-issue-acceptance-verification-stays-human.md) records why
that command was struck and this list rehomed here.

---

## The two layers

**The list is two-layer — principle → its concrete derived checks — and both levels
are load-bearing.** An automated gate can only assert mechanical facts ("is this
`.sh` `100755`"); a principle like "test through the real invocation path" is a
design heuristic no script can check. Principles guide review and *generate* new
mechanical checks; the checks are what a gate actually runs. Collapse to
principles-only and there is nothing executable; stay at symptoms-only and it is
brittle — every fresh symptom of a known cause is a guaranteed future miss.

**Maintenance rule.** When a new catch arrives, first ask: *is this a special case of
a principle already on the list?*

- **Yes** → file it under that parent, and if the parent had no mechanical check
  covering this case, add one.
- **No** → it's a genuinely new cause; it becomes a new parent.

This actively drives the list toward causes instead of accumulating flat siblings.

**Worked example.** Catch 5 ("real invocation path") is the *parent* of catch 4
("exec bit on `*.sh`"). Catch 4 was recorded at symptom level while its cause went
unnamed — which is exactly why the same cause was free to resurface later as a new
symptom.

---

## The checks

1. **Verify the committed artifact, not the working tree** — the secret guard was
   e2e-"verified" while executable locally but committed `100644`, so git silently
   ignored it. Green in the working state ≠ shipped correctly.
2. **Confirm the guard actually fired** — absence of the "hook was ignored" hint is
   the proof-in-place, not the test passing.
3. **Mutation-test any load-bearing guard** — stub it to always-pass; if the negative
   cases don't then fail, the tests are vacuous.
4. **Exec bit on new `*.sh`** — the agent file-creation path lands scripts `100644`;
   git ignores non-executable hooks. *(Mechanical check: now asserted in CI —
   `guards.yml`, "Executable-bit assertion", keyed on the shebang rather than the
   `.sh` suffix so extensionless git hooks are covered.)*
5. **Real invocation path** — a guard's tests must invoke it the way git/production
   does (direct execution honouring file mode), not via a proxy like `bash <script>`
   that cannot observe a mode problem. This is the general form of catch 4: the
   exec-bit bug survived *every* unit test precisely because the tests used `bash`,
   which never sees the mode. Green through the wrong invocation path is worse than
   red — it buys false confidence.

   **5a. The fixture is part of the invocation path.** *(Added 2026-08-17 on the
   third instance of this parent — promoted from the catch-log per its rule-of-three.)*
   A test whose fixture never resembles the real target verifies a path production
   never takes, even when the invocation *method* is correct. `bootstrap-project.sh`
   passed its entire suite while being unable to bootstrap any real project: every
   fixture came from `mktemp -d`, which returns an MSYS path (`/tmp/...`), and
   `mkdir -p` works there. Every actual project lives on a UNC path
   (`//wsl.localhost/...`), where `mkdir -p` fails outright — even on a directory
   that already exists. 100% green, 0% functional.

   *Mechanical check:* at least one fixture must exercise the **path shape
   production uses**. For this repo that means a UNC-rooted fixture, not only a
   `mktemp -d` one. More generally: if the environment has a characteristic that
   the code must handle (path form, filesystem semantics, line endings, locale),
   one fixture has to carry it, or that characteristic is untested by construction.
6. **Test isolation** — test/eval scripts must operate on `mktemp -d` fixtures, never
   the live repo / index / data store. Guard `cd` with `|| exit`; do not lean on
   `set -e` (it does not reliably abort a bare `cd`, and a silently-failed `cd`
   leaves the script running in the previous directory). Enforcement is deliberately
   **deferred, not built** — one incident means record the convention, not build a
   linter for tests touching `.git`. Build only if it recurs (YAGNI).
7. **Validate acceptance criteria against the measuring instrument, at spec time** —
   an AC the certifying tool cannot observe is **unsatisfiable**, not merely unmet, and
   no amount of good execution will close it. Before accepting a criterion, ask: what
   reads this, and can it actually see the thing? Three instances in one slice (#8),
   all authored by the same hand that then tried to satisfy them:
   - *"frontier share drops"* — measured by a tool that emitted only cumulative totals,
     so a share **change** was unreadable by construction (fixed: `observe --since`).
   - *"Haiku stops being zero"* — subagent turns are recorded nowhere (`isSidechain` is
     0 across every project), so a delegated cheap-model run contributes zero model
     turns. Unsatisfiable however well the routing worked; the honest proxy is the
     parent-side delegation count.
   - *"the setting is applied"* — verified as *present in the file*, which is not the
     same claim as *in effect*. This is catch 1 wearing different clothes: the
     committed artifact was right and the running reality was not.

   This is a **new parent, not a special case of catch 1**. Catch 1 is about checking
   the right artifact *after* the work; this is about whether the criterion is
   observable *at all*, decided before the work starts. The failure mode is upstream
   and cheaper to fix there — a spec review that asks "which tool reads this?" catches
   all three for free.

---

## Maturity signal

The list stops growing when review stops surprising us: when a few builds pass and
human review catches nothing the agent's self-check hadn't already flagged. A
sharper form of the same signal: **new catches stop being special cases of
principles already on the list.**

Adopt as a **direction, not a provable gate** — you cannot prove a catch isn't a
special case of a principle you haven't articulated yet; you can only notice when it
is one. It signals the list is still maturing, not a checkbox to tick.

As of the last update this signal is **not** met: the list is still producing new
items, and every one of the six arrived from human/e2e review rather than agent
self-check.
