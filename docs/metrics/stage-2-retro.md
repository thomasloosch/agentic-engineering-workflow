# Stage 2 Retrospective — Pre-flight Findings

**Session:** 2026-05-29
**Status:** Pre-flight complete. Jobs Radar **not yet bootstrapped** — this session never reached the originally-planned Stage 2 work because verification surfaced two blocking workflow bugs that had to be fixed first.

This is the deliverable the handoff named as non-optional. It captures what broke, what was done, what's fixed, and what the findings mean for Jobs Radar and Stage 3.

---

## Executive summary

The handoff assumed the workflow repo was the source of truth and that bootstrap worked, so Stage 2 would be: verify environment → bootstrap Jobs Radar → exercise the agent system. Verification falsified both assumptions:

1. **The repo was not the source of truth.** Three live artifacts existed only in the deployed Windows config, untracked in git.
2. **Bootstrap's symlink strategy was structurally broken** for the runtime Thomas actually uses (Claude Code desktop app over a `\\wsl.localhost` UNC path).

Both were fixed, committed, and pushed. Had we bootstrapped Jobs Radar on the original assumptions, both bugs would have propagated into Jobs Radar — and later into Sovary and familienkalender. Finding them now is the session's value, and matches the handoff's own prediction that Stage 2 would reveal workflow bugs to fix rather than work around.

---

## Finding 1 — Repo was not the source of truth (RESOLVED)

**Issue.** The handoff listed the global CLAUDE.md, the enforcement hooks, and the coordinator agent as closed v1 deliverables living in the workflow repo. In reality:

- The **global CLAUDE.md** (89 lines / 5703 bytes), loaded by Claude Code from the deployed `~/.claude/CLAUDE.md`, was **untracked** — present nowhere in the repo. `.gitignore` excluded only `settings.local.json`, so this was an accidental sync gap, not a deliberate exclusion.
- All **6 enforcement hooks** existed only in deployed Windows config; the repo had no `hooks/` directory at all. Bootstrap never symlinked hooks.
- The **coordinator agent** in the repo was stale (May 14): it was missing the "Agent discovery" block that the live deployed copy had. That block is load-bearing — it instructs the coordinator to `ls` the agents dirs before claiming an agent doesn't exist, the exact failure Stage 2's routing test depends on avoiding.

There were also two parallel `~/.claude` trees: the real one (Windows side, `/mnt/c/Users/Admin/.claude`) and a stale WSL2-side `~/.claude` (theme-only settings + 7 fossil agents from May 13). The desktop app reads the Windows-side config.

**What was done.** Reconciled all three artifacts into the repo, deployed-Windows → repo, in three separate commits by intent:

- `e59f2dd` — restored the agent-discovery block to the repo coordinator.
- `db75da5` — tracked the 6 hooks under a new top-level `hooks/` (global-only; intentionally NOT added to bootstrap's symlink loop, since hooks guard user-level git behavior globally, not per-project).
- `f5b64cd` — tracked the global CLAUDE.md at `docs/global-CLAUDE.md` (NOT repo root, to avoid Claude Code auto-loading it as the workflow repo's own project memory when the repo is opened in a session — verified against the official memory docs).

All pushed to `origin/main`.

**Status: fixed and pushed.** The repo is now genuinely the source of truth.

---

## Finding 2 — Bootstrap symlink strategy broken in the real runtime (RESOLVED)

**Issue.** Bootstrap symlinked each project's `.claude/{agents,skills,commands}` and `engineering-standards.md` to **WSL2 absolute paths** (`/home/thomas/agentic-engineering-workflow/.claude/...`). Thomas opens projects via the Claude Code **desktop app, folder picker**, which reaches the WSL filesystem over a `\\wsl.localhost` UNC path on the Windows side. A symlink whose target is a Linux absolute path cannot be resolved across that boundary — accessing it throws `Input/output error`. So every bootstrapped project would have had agent/skill/command files that error on read: broken, and silently so.

This matches Anthropic feature request #49933 (open, April 2026): the desktop app runs Windows-side and accesses WSL files over UNC, which breaks symlinks and other POSIX semantics.

**Decision.** Three options were weighed:
- **A — open projects WSL-integrated** in the desktop app. Ruled out: the desktop app does not offer this (it's the subject of the open feature request); and the CLI-in-terminal alternative was rejected because Thomas does not want to work in the terminal.
- **B — bootstrap copies instead of symlinks.** Chosen. Keeps the desktop GUI workflow.
- **C — move everything Windows-side.** Shelved as disproportionate; revisit only if in-place develop proves unreliable (it didn't — see Finding 3).

**Cost of B, accepted.** Copies break single-source-of-truth: a project's copied assets go stale when the workflow repo changes. Mitigation: every copied file is recorded in a per-project **content-hash manifest** (`.claude/.asset-manifest`) with its SHA256 at copy time, so staleness is always *detectable* (workflow's current hash != recorded hash) and curable. Files not in the manifest are project-local overrides, never auto-overwritten. The manifest is content-hash keyed (not timestamp/version) so it cannot lie. The manifest is committed (not gitignored) so it travels with a clone.

**What was done.** Modified `scripts/bootstrap-project.sh` (commit `adc9a3b`): symlink → copy for all four asset types, plus manifest generation. Stale symlinks from older bootstraps are removed before copying (verified it does not write through the symlink to the source repo). Applied via a tested match-or-abort Python editor. Verified end-to-end in a sandbox (happy path, override preservation, symlink-migration, hash integrity) **and** in the real desktop-app runtime (copied files readable over UNC; Windows Node does real file I/O across the share).

**Status: fixed, committed (`adc9a3b`), pushed.**

**Deferred (Piece 2):** a `sync-project-assets` re-sync command that reads the manifest and refreshes stale workflow-sourced files without clobbering overrides. Deferred until first drift is actually felt, to avoid building re-sync machinery before its ergonomics are known. **Note:** in the desktop runtime nothing auto-flags drift (hooks dormant — see Finding 4), so drift detection is pull-based: run the re-sync command at the start of project work or after changing a shared agent.

---

## Finding 3 — The actual runtime model (CHARACTERIZED)

It took three probes and two wrong guesses to model the runtime correctly. The truth:

**The desktop app's Bash tool is Git Bash (MINGW64 / MSYS2) running on Windows, reaching the project over `\\wsl.localhost`.**

Evidence: `uname` reports MINGW64; `node`/`npm` resolve to `/c/Program Files/nodejs/` (Windows binaries); `git` is `/mingw64/bin/git` (Git-for-Windows); `pwd` returns the UNC path; there is no `/home/thomas` mount in this shell. Windows Node does real file I/O across the share, and `process.platform` is `win32`.

This is neither "WSL bash" nor "Windows cmd/PowerShell" — both of which were asserted and falsified mid-session. The corrected model is the constraint set everything downstream inherits.

**Implications now known true:**
- **Path dialect:** relative paths and `//wsl.localhost/ubuntu/home/thomas/...` UNC paths work in agent commands; bare Linux-absolute paths (`/home/thomas/...`) do not.
- **Toolchain split:** agents develop/test with **Windows Node** over UNC; production is **Linux Node** on Hetzner. Plus Thomas's own WSL Node for manual work. Three Node environments.

---

## Finding 4 — Enforcement hooks are structurally dormant in this runtime (CHARACTERIZED)

Locked-decision #9 said "hooks dormant in Desktop, active in terminal." Now explained, not just observed: the hooks are bash scripts wired as Claude Code PreToolUse hooks, referencing Linux `$HOME/.claude/...` paths. In the MINGW runtime, `$HOME` is the Windows user home and the hooks' assumptions don't hold, so they do not fire correctly. This is structural, not a misconfiguration — the enforcement layer was built for a Unix shell the agent runtime isn't.

**Consequence:** for all desktop-app work (which is how Jobs Radar will be built), git-discipline enforcement (`block-git-add-all`, `block-force-push-to-main`, staleness checks) is **advisory only** — it's on the human and on Claude to hold it manually. This held true throughout this session; every git step was verified by hand.

---

## Finding 5 — Dev/prod runtime gap (CONSTRAINT FOR JOBS RADAR SPEC)

Jobs Radar will be **developed** under Git Bash / Windows Node / UNC but **deployed** on Linux / cron / Hetzner CPX22. Code authored/tested where `process.platform === 'win32'` runs in production where it's `'linux'`. The spec must mandate:
- Portable Node only — no Linux-only path assumptions at dev time, no platform-sensitive code (path separators, `os.homedir()`, line endings, shell-outs) that passes in dev and fails on Hetzner.
- **Hetzner is the source of truth for "does it actually run."** Dev-time green is necessary, not sufficient.

---

## Finding 6 — File creation in this runtime: a silent-corruption trap (CONSTRAINT)

`printf` with escape sequences (`\n`) does **not** survive the Git Bash → Windows Node boundary cleanly — observed mid-session producing mangled file content that looked written but wasn't. Quoted-delimiter heredocs (`<< 'EOF'`) work. This is the same family of boundary bug the handoff warns about for WSL2 file creation.

**Rule for agents writing files in this runtime:** use quoted-delimiter heredocs or editor/Write tools — **never `printf`-with-escapes**. This belongs in the Jobs Radar spec and arguably in the global file-creation rules.

---

## Process lessons (about how the work was done)

- **Asserting a model before gathering the full probe set cost three turns.** The runtime was mislabeled twice ("Windows shell," then "WSL bash") before `uname` + `which` + `pwd` together gave the truth. Standing rule going forward: never label the agent runtime without all three in hand.
- **A "successful" commit message is not a clean-tree check.** A commit reported success while leaving an unstaged mode change (README 100644-vs-disk on drvfs). Always read `git status --short` for emptiness after committing.
- **WSL2/drvfs sets a spurious exec bit on every `/mnt/c` file.** Resolved by `git config core.fileMode false` per WSL2 repo, plus explicit `git update-index --chmod` for intentional mode changes. The earlier "normalize modes after each copy" instinct was wrong — it fought the mount and created phantom unstaged deltas.
- **Verification harness bugs can produce false failures.** A hash-integrity check ran under `/bin/sh` instead of bash twice and reported false FAILs. When a check fails, confirm the checker ran correctly before believing the failure.
- **Over-gating cost the human.** Verification gates were placed before nearly every commit; they caught real failures at maybe three moments but otherwise turned the session into blind copy-paste for Thomas. Calibration going forward: gate only steps with a genuine failure mode.

---

## Open items (for post-Stage-2 / Stage 3)

- **#2** — Delete the stale WSL2-side `~/.claude` (theme-only settings + fossil agents). Safe; do during consolidation.
- **#4** — `settings.local.json` (repo, gitignored) vs deployed `settings.json` (live, with hooks + permissions) are different files by purpose, not drifted copies. Document the convention; low priority.
- **#5** — `.backup-*` files in `scripts/` and `templates/`. The `.gitignore` appears to match `*.backup*` (the migration backup didn't show as untracked), so these are likely local-only, not committed cruft. Confirm with `git ls-files | grep backup`; downgrade to optional tidy if untracked.
- **#8 / sync routine** — The `chore: sync` routine that previously copied workflow assets did not verify content (the repo coordinator went stale despite a sync commit existing). Build a sync script that diffs and refuses on conflict rather than overwriting by timestamp.
- **#11 — RESOLVED (this session).** GitHub branch protection required PRs on `main`, contradicting locked-decision #7 (direct-push solo workflow) — an unintended default. Both halves fixed: repo-side, Rule 10 reframed project-conditional + decision #7 recorded as ADR-0001; server-side, the `required_pull_request_reviews` requirement removed (force-push/deletion guards retained). Pushes no longer generate bypass warnings.
- **Piece 2** — `sync-project-assets` re-sync command (see Finding 2), deferred to first felt drift.

---

## What success looks like from here

Pre-flight is done: repo reconciled and pushed, runtime modeled correctly, bootstrap fixed/committed/pushed. **Jobs Radar has not been started.** Next session, in order:

1. Bootstrap Jobs Radar for real: create `~/projects/jobs-radar` (or clone the empty repo), run the now-fixed bootstrap, verify copies + manifest land.
2. Customize Jobs Radar's CLAUDE.md with the handoff's locked constraints (Node.js, daily cron on Hetzner, Migadu SMTP, state files, ~€2/mo target) **plus** the runtime constraints from this session: portable Node (Finding 5), file-creation dialect rule (Finding 6), UNC/relative path discipline (Finding 3).
3. `/start-session` in the desktop app and watch the coordinator route to spec-writer — the first real test of the agent system, which is the actual point of Stage 2.

The whole pre-flight existed to make step 3 a true test of the system rather than a test of a broken setup.

---

## Finding 7 — First live agent run: documented constraint not honored (CAPTURED, iterate next stage)

**What happened.** On the first real `/start-session`, the coordinator routed correctly (coordinator → spec-writer, agent-discovery block fired, no misroute — the core Stage 2 goal met). But of the two dispatched sub-agents, **one failed because it tried to write the spec to a Linux-absolute path**, the exact failure Finding 3 documents. It recovered (spec landed at `.claude/specs/architecture.md`, reachable via UNC), but the failure occurred despite the runtime constraint being known and written into the project CLAUDE.md.

**The finding is the gap, not the failure.** Documenting a constraint in CLAUDE.md is not the same as the agent honoring it at dispatch time. The constraint existed; the agent didn't apply it. Possible causes (to investigate, not assumed): the sub-agent didn't read CLAUDE.md before acting, the constraint wasn't surfaced in the dispatch prompt, or CLAUDE.md isn't reliably loaded for sub-agents in this runtime.

**Interim mitigation (this run).** Runtime constraints were injected directly into the coordinator's dispatch message to the Implementation Engineer, rather than relying on CLAUDE.md being read. This made the constraint travel with the task.

**To iterate next stage.** Decide where runtime constraints must live so agents actually honor them — candidates: (a) dispatch-prompt injection by the coordinator (worked this run, but manual), (b) a `.claude/rules/` path-scoped rule that loads when code files are touched, (c) verifying sub-agents load project CLAUDE.md at all in the desktop/UNC runtime. The principle: a constraint that lives only where the agent doesn't read it is not a constraint. This is the highest-value workflow fix surfaced by the first live run.

**Also noted this run (minor):**
- Folder picker cannot browse the WSL filesystem (Windows-side app); projects must be opened by pasting the `\\wsl.localhost\...` UNC path. Operational, not a bug.
- "Pull request status couldn't be checked" error in the app — same root cause as open item #11 (unintended PR-required ruleset). Benign; did not block the spec run.
- Spec-writer correctly pushed back on a handoff assumption (GitHub Trending is repos, not jobs) and deferred it. Good first-principles behavior by the agent, worth reinforcing.

---

## Deploy-phase findings — Hetzner jobs-radar v1 (2026-05-31)

First live deploy of jobs-radar to Hetzner. Deploy succeeded: daily cron live, first live run sent a real digest (43 jobs scraped, 26 matched, email delivered, `seen.json` written). The findings below are gaps between the Stage-3 handoff's plan and reality on the box.

---

### D1 — "CPX22 already provisioned" was the live product server (CONSTRAINT)

The handoff treated the Hetzner box as a clean deploy target. It is `sovary-app` — the live, Coolify-managed Sovary product server (IPv4 91.98.193.138, Nuremberg). Decision made: co-host jobs-radar on it (near-zero traffic, one small VPS). Consequence: the tooling/product separation the project rules assert is now softer — jobs-radar runs as a host cron job alongside Coolify-managed Sovary containers.

**Implication.** Any work on the Hetzner box touches the live Sovary production environment. Don't treat it as a sandbox. Revisit the co-hosting decision if Sovary traffic grows or the VPS is migrated.

---

### D2 — No Node on the host; Coolify keeps it in containers (INFRA RULE)

Host had no system Node (`which node` empty). Coolify apps carry their own Node inside Docker. Installed Node 22 LTS via NodeSource: apt-managed, lands in system PATH at `/usr/bin/node`, cron-visible. nvm was ruled out — cron runs without shell init and cannot see nvm-managed binaries.

**Rule for future deploys.** Do not assume Node is present on a Coolify host. Bootstrap and deploy docs must include the NodeSource install step explicitly.

---

### D3 — SSH access was a multi-failure maze (highest time cost) (LESSON)

- The Hetzner panel's registered key (`thomas@sovary.app`, MD5 `3c:a5:...`) did **not** match the laptop's local key (`59:e0:...`). Different keys.
- Root password from original provisioning was lost; reset via Hetzner Rescue mode.
- Server's real `authorized_keys` already held two keys (one unlabeled, one `coolify`) — laptop key was appended as a third, non-destructively.

**Hetzner browser console mangles special characters** via keyboard-layout mismatch: `+`→`=`, `_`→`-`, `*`→`8`, `>`→`.`, `%`→`5`, `|`→`\`. This silently corrupted SSH keys and broke every pipe/redirect command. Escape hatches that worked: `nano` (no operators needed), Tab-completion (types `_` correctly), `printf '\053'` to emit `+` without pressing the key.

**Standing rule.** For any future server work: get key-based SSH from WSL2 working first and abandon the Hetzner browser console immediately. Don't hand-paste SSH keys through it. Don't run pipe or redirect commands through it.

---

### D4 — GitHub clone needed a server deploy key (INFRA RULE)

Server had no outbound SSH key. HTTPS clone failed (GitHub killed password auth; a PAT would be required). Generated a passphrase-free ed25519 deploy key on the server, registered as a **read-only deploy key scoped to the jobs-radar repo** (not account-wide) — correct least-privilege for a pull-only box.

**Rule for future deploys.** Deploying any private repo to a fresh box requires a deploy-key step. The handoff's bootstrap docs did not mention this; add it.

---

### D5 — Cron needed absolute node path (INFRA RULE)

The handoff's example cron entry used bare `node`. Cron runs with a stripped `PATH` that did not include the NodeSource install location, so a bare `node` would have produced a silent "command not found" at 07:00. Fixed by using `/usr/bin/node` in the cron entry.

**Rule.** All cron entries generated by bootstrap docs or scripts must use absolute interpreter paths. Never rely on `PATH` in cron.

---

### D6 — filter.js over-excludes adjacent roles (PRODUCT, open)

First live run excluded plausibly-relevant titles as "no role signal": Data Engineer, Senior Backend Engineer, Data Scientist, DevOps/Platform Engineer. The matcher is too title-literal — it matches `"AI engineer"`/`"prompt engineer"` strings but misses roles where AI work appears in the job description rather than the title. This is the filter.js scoring risk flagged as Finding E in the pre-deploy Part-2 review ("most likely to silently do the wrong thing").

Silent false negatives are the worst failure mode for a job digest: the tool appears to work while missing relevant postings.

**Next action.** Tune filter.js via the agent system (coordinator → implementation-engineer → code-review). Do not hand-patch on the server. This is the prime candidate for a real filter.js test suite — scoring changes should not land without it.

---

### D7 — Cron failures are silent (MONITORING gap, deferred)

The mailer fires only on success. A scraper error logs to `/var/log/jobs-radar.log` but sends no notification. A broken scraper could go undetected for weeks.

Not a v1 blocker. Options for v2: a daily "alive" heartbeat email, or alert-on-error in the mailer's `catch` path. Add to the v2 backlog.
