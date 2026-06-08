# Workflow Lessons

Distilled, durable principles for building with this workflow. Cross-project —
project-specific lessons live in each project's .claude/memory/lessons.md.
Each lesson is the principle; the incident that produced it lives in the stage
retros (docs/metrics/). Curated, not append-only — prune and reorganize as
patterns clarify.

## Verification
- **Prose-verified != behavior-verified.** A workflow/agent change that reads
  correct in the diff can still fail in practice. Validate by routing a real
  task through and observing, not by reading the edited file. This is
  HUMAN-enforced, not tooling-enforced: the agents cannot reliably self-apply
  it (W4 — the coordinator's own auto-fire instruction did not execute on its
  own). Do not assume a change is validated because a rule says to validate it;
  the human routes the validation task and reads the result. (Stage-2 W5)
- **A green self-report is not verification.** Agents grading their own output
  is the recurring trap. Confirm by reading the actual artifact/diff, not the
  summary of it.
- **Read evidence before asserting.** cat/grep/probe actual file content and
  runtime state before claiming anything about them.

## Scoring & tuning
- **Lead-signal anchor over threshold-fitting.** Build scoring around genuine
  signal structure; a threshold placed in a 1-point gap between fixtures is
  overfitting, not calibration. (Stage-2 D6b)
- **Anti-fixture-fitting must be universal across all tunable parameters.**
  Lock one knob against fixture-fitting and the model fits via whichever knob
  you didn't lock. (Stage-2 D6b threshold)
- **Fixtures are necessary, not sufficient.** Passing known cases proves the
  logic isn't broken; the live run is the real validation.

## Design
- **Build for discovery, not hardcoded lists.** Anything that will go stale
  (agent lists, paths, inventories) should self-discover. Ask "will this go
  stale?" before designing it.
- **First principles before pattern-matching.** Strip assumptions; ask what the
  actual constraint is before reaching for the familiar solution.
- **A constraint that lives only where the agent doesn't read it is not a
  constraint.** (Stage-2 runtime-constraint finding)

## Process discipline
- **Spec reconciliation is load-bearing.** As-built divergence from spec goes
  undetected until it causes confusion downstream. Reconcile spec to reality
  after implementation diverges. Specs are living single files, versioned in-file
  with a changelog; git history is the verbatim archive, not parallel version-files.
- **Two write-paths to one artifact is dangerous.** Single source of truth;
  git history is the archive, not parallel files on disk. (finding G)
- **Separate commits by intent; explicit path staging, never git add .**
- **Start CC in the repo it's working on.** Cross-repo work from the wrong
  working dir causes path confusion and stray writes. (Stage-2 operational)

## Failure modes to watch
- **NaN/corrupt-reads-as-healthy.** A guard that passes silently on corrupt
  input is the opposite of a guard. Probe for it explicitly. (D7)
- **Split-brain is worse than missing.** A path resolving to a different real
  file per runtime reads healthy in both contexts while silently diverging —
  worse than resolving to a missing dir, which errors loudly. Annotate
  runtime-dependent paths explicitly. (path-variable audit)
- **Failure-mode tables miss partial failures** (succeed-then-fail-midway is a
  distinct mode from fail-at-start).
- **Orchestration biases toward shipping fast** — gates and re-review-after-change
  must be explicit and enforced, not assumed.
