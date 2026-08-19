#!/usr/bin/env bash
#
# Tests for bootstrap-project.sh. Each test builds a throwaway project in a
# mktemp -d working area and asserts on the OBSERVABLE artefact the script
# leaves behind — the asset manifest at <project>/.claude/.asset-manifest —
# never on the repo's own .git, index, or any live data.
#
# Contract under test: bootstrap is IDEMPOTENT with respect to the manifest.
# The manifest is the record of which files are workflow-sourced and therefore
# re-syncable; a file absent from it is treated as a project-local override and
# is never auto-overwritten. So a second bootstrap of the same project must not
# shrink that record: whatever the first run listed, the second must still list.
# Re-running is the normal way to pick up workflow updates, and a manifest that
# empties itself on re-run silently reclassifies every workflow asset as a local
# override — the project stops being re-syncable at all (issue #16).
set -uo pipefail

BOOTSTRAP="$(cd "$(dirname "$0")" && pwd)/bootstrap-project.sh"
FAILED=0

pass() { echo "  ✔ $1"; }
fail() { echo "  ✖ $1"; echo "      $2"; FAILED=1; }

# shellcheck source=lib/runtime-fixture.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/runtime-fixture.sh"
# shellcheck source=lib/portable-fs.sh
source "$(cd "$(dirname "$0")" && pwd)/lib/portable-fs.sh"

# Fresh throwaway project: a git repo in its own directory under the temp work
# area. Echoes the project path.
#
# Uses ensure_dir rather than `mkdir -p "$1/$2"`. The original version used the
# latter and worked for every /tmp fixture — then failed the moment a UNC-rooted
# fixture was introduced, because `mkdir -p` on an absolute UNC path cannot run.
# This helper had the same latent defect as the code it tests, hidden by the same
# missing condition, and the runtime-faithful tier surfaced it on its first use.
make_project() {  # make_project <parent> <name> ; echoes <projectdir>
  local proj="$1/$2"
  ensure_dir "$1" "$2" || return 1
  ( cd "$proj" || exit 1; git init -q . ) || return 1
  echo "$proj"
}

# Run the script under test against a project. Its chatty stdout is noise here;
# only the artefacts it writes matter.
run_bootstrap() {  # run_bootstrap <projectdir> <project name>
  bash "$BOOTSTRAP" "$1" "$2" >/dev/null
}

# Manifest entries = lines that are not comments. Comment lines start with '#';
# blank lines start with nothing, so '^[^#]' excludes both. grep exits 1 on zero
# matches, which is a legitimate count of 0, not an error.
count_manifest_entries() {  # count_manifest_entries <projectdir> ; echoes <n>
  local manifest="$1/.claude/.asset-manifest"
  [ -f "$manifest" ] || { echo 0; return 0; }
  grep -c '^[^#]' "$manifest" || true
}

echo "▶ bootstrap-project"

TESTDIR=$(mktemp -d)
trap 'rm -rf "$TESTDIR"' EXIT

# 1. Re-run must not shrink the manifest (issue #16 regression case).
#    Every copy step reads "exists on disk and is not a symlink" as "local
#    override — preserve, do not record", while init_manifest truncates first.
#    Second run therefore records nothing and the manifest comes back empty.
PROJECT=$(make_project "$TESTDIR" "probe-one")
if [ -z "$PROJECT" ]; then
  fail "re-run preserves manifest entries" "could not create the temp project"
else
  run_bootstrap "$PROJECT" "Probe One"
  first=$(count_manifest_entries "$PROJECT")
  run_bootstrap "$PROJECT" "Probe One"
  second=$(count_manifest_entries "$PROJECT")
  [ "$second" -ge "$first" ] && pass "re-run preserves manifest entries" \
    || fail "re-run preserves manifest entries" \
            "manifest shrank on re-run: first=$first second=$second"
fi

# 2. A file the owner edited keeps its ORIGINAL recorded hash across a re-run.
#
#    Added because a mutation check exposed test 1 as weaker than it looked:
#    disabling the prior-manifest load leaves the entry COUNT intact (every file
#    then reads as "untracked but identical to the repo" and is adopted), so test 1
#    stayed green with the load-bearing code removed. The behaviour that genuinely
#    depends on reading the prior manifest is this one.
#
#    Why the original hash and not the current one: sync classifies by comparing
#    the recorded hash against the project's file and the repo's file. Re-recording
#    an override at its CURRENT hash would make the next sync read
#    "project untouched, repo moved -> safe to refresh" and silently overwrite the
#    owner's edit. Preserving the original is what keeps that classification true.
PROJECT=$(make_project "$TESTDIR" "probe-two")
if [ -z "$PROJECT" ]; then
  fail "owner override keeps its original recorded hash" "could not create the temp project"
else
  run_bootstrap "$PROJECT" "Probe Two"
  tracked=".claude/skills/tdd/SKILL.md"   # manifest v3: project-root-relative
  before=$(awk -F'\t' -v p="$tracked" '$1==p{print $2}' "$PROJECT/.claude/.asset-manifest")

  printf -- '\nOWNER EDIT\n' >> "$PROJECT/$tracked"
  run_bootstrap "$PROJECT" "Probe Two"

  after=$(awk -F'\t' -v p="$tracked" '$1==p{print $2}' "$PROJECT/.claude/.asset-manifest")
  edit_survived=$(tail -1 "$PROJECT/$tracked")

  if [ -z "$before" ]; then
    fail "owner override keeps its original recorded hash" \
         "fixture problem: $tracked was not in the manifest after the first run"
  elif [ "$edit_survived" != "OWNER EDIT" ]; then
    fail "owner override keeps its original recorded hash" \
         "the re-run OVERWROTE the owner's edit"
  elif [ "$after" != "$before" ]; then
    fail "owner override keeps its original recorded hash" \
         "recorded hash changed: before=$before after=$after"
  else
    pass "owner override keeps its original recorded hash"
  fi
fi

# 3. Assets OUTSIDE .claude/ are placed and tracked (#17 slice 1).
#
#    The manifest's first column was ".claude/-relative", and both bootstrap and
#    sync resolved it against <project>/.claude. That made the mechanical control
#    set impossible to express: GitHub only reads workflows at
#    .github/workflows/, and eslint only discovers its config at the project
#    root. Neither path can be written as a .claude/-relative string.
#
#    So column 1 is now PROJECT-ROOT-relative (manifest v3). This test pins the
#    property that forced the change: a root-level asset lands at the root and is
#    tracked like any other, so drift in it is detectable.
PROJECT=$(make_project "$TESTDIR" "probe-three")
if [ -z "$PROJECT" ]; then
  fail "assets outside .claude/ are placed and tracked" "could not create the temp project"
else
  run_bootstrap "$PROJECT" "Probe Three"

  missing=""
  [ -f "$PROJECT/eslint.config.js" ] || missing="$missing eslint.config.js"
  [ -f "$PROJECT/.github/workflows/secret-scan.yml" ] || missing="$missing .github/workflows/secret-scan.yml"

  # guards.yml must NOT be propagated: it is the workflow repo's own guard-test
  # suite and references scripts a consumer project does not have, so installing
  # it would create a workflow that fails on its first run.
  [ -f "$PROJECT/.github/workflows/guards.yml" ] && \
    fail "assets outside .claude/ are placed and tracked" \
         "guards.yml was propagated; it is workflow-repo-only and would fail on arrival"

  untracked=""
  for p in "eslint.config.js" ".github/workflows/secret-scan.yml"; do
    grep -q "^$(printf '%s' "$p" | sed 's/[.[\*^$]/\\&/g')	" "$PROJECT/.claude/.asset-manifest" \
      || untracked="$untracked $p"
  done

  if [ -n "$missing" ]; then
    fail "assets outside .claude/ are placed and tracked" "not placed:$missing"
  elif [ -n "$untracked" ]; then
    fail "assets outside .claude/ are placed and tracked" \
         "placed but absent from the manifest (invisible to drift detection):$untracked"
  else
    pass "assets outside .claude/ are placed and tracked"
  fi
fi

# 4. bootstrap EMITS setup-project.sh, and does not itself touch package.json
#    (#17 slice 3, decision D1).
#
#    The split exists so there is exactly one thing that edits owner-owned files,
#    and the owner runs it deliberately. bootstrap copies and records; the emitted
#    script wires. If bootstrap ever edits package.json directly, the no-edit
#    default is gone and nobody notices until it clobbers something.
PROJECT=$(make_project "$TESTDIR" "probe-four")
if [ -z "$PROJECT" ]; then
  fail "bootstrap emits setup-project.sh and never edits package.json" "could not create the temp project"
else
  printf '{\n  "name": "probe-four",\n  "scripts": {\n    "start": "node index.js"\n  }\n}\n' \
    > "$PROJECT/package.json"
  before=$(sha256sum "$PROJECT/package.json" | cut -d' ' -f1)

  run_bootstrap "$PROJECT" "Probe Four"

  after=$(sha256sum "$PROJECT/package.json" | cut -d' ' -f1)
  problems=""
  [ -f "$PROJECT/setup-project.sh" ] || problems="$problems setup-project.sh-not-emitted"
  [ -x "$PROJECT/setup-project.sh" ] || problems="$problems setup-project.sh-not-executable"
  [ "$before" = "$after" ] || problems="$problems package.json-was-modified-by-bootstrap"

  if [ -n "$problems" ]; then
    fail "bootstrap emits setup-project.sh and never edits package.json" "$problems"
  else
    pass "bootstrap emits setup-project.sh and never edits package.json"
  fi
fi

# 5. setup-project.sh wires package.json when the owner runs it, and is idempotent.
#    Idempotence matters because the owner will re-run it after a re-bootstrap; a
#    second run appending a duplicate script block would corrupt the manifest file
#    that npm reads.
if [ -n "${PROJECT:-}" ] && [ -x "$PROJECT/setup-project.sh" ]; then
  ( cd "$PROJECT" || exit 1; ./setup-project.sh --yes ) >/dev/null 2>&1
  rc1=$?
  first=$(sha256sum "$PROJECT/package.json" | cut -d' ' -f1)
  ( cd "$PROJECT" || exit 1; ./setup-project.sh --yes ) >/dev/null 2>&1
  second=$(sha256sum "$PROJECT/package.json" | cut -d' ' -f1)

  # Read package.json through a pipe rather than by path. node here is the Windows
  # build and cannot resolve an MSYS path like /tmp/... — passing the path directly
  # yields a spurious failure that looks like a product bug. cat is MSYS-side, so
  # the path is resolved by the shell that understands it.
  read_script() {  # read_script <script-name> ; echoes its value or ""
    cat "$PROJECT/package.json" | node -e '
      let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
        try{const j=JSON.parse(s);process.stdout.write(((j.scripts||{})[process.argv[1]])||"")}
        catch(e){process.stdout.write("PARSE_ERROR")}
      })' "$1" 2>/dev/null
  }
  test_val=$(read_script test)
  start_val=$(read_script start)
  has_test=n;    [ -n "$test_val" ] && [ "$test_val" != "PARSE_ERROR" ] && has_test=y
  kept_start=n;  [ "$start_val" = "node index.js" ] && kept_start=y

  if [ "$rc1" -ne 0 ]; then
    fail "setup-project.sh wires package.json idempotently" "first run exited $rc1"
  elif [ "$has_test" != "y" ]; then
    fail "setup-project.sh wires package.json idempotently" "no 'test' script was added (got: $has_test)"
  elif [ "$kept_start" != "y" ]; then
    fail "setup-project.sh wires package.json idempotently" "clobbered the owner's existing 'start' script"
  elif [ "$first" != "$second" ]; then
    fail "setup-project.sh wires package.json idempotently" "second run changed the file — not idempotent"
  else
    pass "setup-project.sh wires package.json idempotently"
  fi
else
  fail "setup-project.sh wires package.json idempotently" "no emitted script to run"
fi

# 6. bootstrap.conf gates a component off, loudly, without erroring (#17 D3/D4).
PROJECT=$(make_project "$TESTDIR" "probe-five")
if [ -z "$PROJECT" ]; then
  fail "bootstrap.conf ci=off omits the workflows and exits 0" "could not create the temp project"
else
  ( cd "$PROJECT" || exit 1; mkdir -p .claude )
  printf 'ci=off\n' > "$PROJECT/.claude/bootstrap.conf"
  out=$(bash "$BOOTSTRAP" "$PROJECT" "Probe Five" 2>&1)
  rc=$?
  # `ci` gates the consumer's CI template. It deliberately does NOT gate
  # secret-scan.yml — that has its own switch, because the two have different
  # preconditions (the secret scan is blocking and wants a history baseline first).
  if [ "$rc" -ne 0 ]; then
    fail "bootstrap.conf ci=off omits the CI template and exits 0" "exited $rc"
  elif [ -e "$PROJECT/.claude/ci/ci.yml.template" ]; then
    fail "bootstrap.conf ci=off omits the CI template and exits 0" "the CI template was installed anyway"
  elif [ ! -f "$PROJECT/.github/workflows/secret-scan.yml" ]; then
    fail "bootstrap.conf ci=off omits the CI template and exits 0" \
         "ci=off also disabled the secret scan — those are separate switches"
  elif ! printf '%s' "$out" | grep -qi "ci=off"; then
    fail "bootstrap.conf ci=off omits the CI template and exits 0" \
         "component was skipped SILENTLY — an inapplicable guard must be visible in the log"
  else
    pass "bootstrap.conf ci=off omits the CI template and exits 0"
  fi
fi

# 7. secret_scan=off must stop the secret-scan WORKFLOW, not just the local guard.
#    Regression case for a real defect: gate_for matched `.github/workflows/*` -> ci
#    before the specific rule, so setting secret_scan=off installed the blocking
#    workflow anyway. That was found on the first run against a real repo whose
#    history has never had a gitleaks baseline — the precise hazard the switch was
#    set to avoid. A switch that does not take effect is worse than no switch.
PROJECT=$(make_project "$TESTDIR" "probe-six")
if [ -z "$PROJECT" ]; then
  fail "secret_scan=off stops the secret-scan workflow" "could not create the temp project"
else
  ( cd "$PROJECT" || exit 1; mkdir -p .claude )
  printf 'secret_scan=off\n' > "$PROJECT/.claude/bootstrap.conf"
  out=$(bash "$BOOTSTRAP" "$PROJECT" "Probe Six" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "secret_scan=off stops the secret-scan workflow" "exited $rc"
  elif [ -e "$PROJECT/.github/workflows/secret-scan.yml" ]; then
    fail "secret_scan=off stops the secret-scan workflow" \
         "the BLOCKING workflow was installed despite the switch being off"
  elif [ ! -f "$PROJECT/.claude/ci/check-imports.mjs" ]; then
    fail "secret_scan=off stops the secret-scan workflow" \
         "it also disabled unrelated components — the gate is too broad"
  else
    pass "secret_scan=off stops the secret-scan workflow"
  fi
fi

# 8. The catch-log SKELETON is placed — schema and rules, but NO rows (#17 slice 2).
#
#    This is the one learning artifact that is still a file rather than
#    plugin-delivered, because it is project-OWNED data: its whole purpose is to
#    accumulate locally. So a new project must get the vocabulary (who-caught set,
#    error classes, promotion rule, hygiene) and an empty table — never this repo's
#    rows, which are its own history and do not travel.
#
#    Getting this backwards in either direction is a real failure: ship the rows and
#    every project starts with someone else's defects; ship a bare table and the
#    project has an instrument with no rules for using it.
PROJECT=$(make_project "$TESTDIR" "probe-seven")
if [ -z "$PROJECT" ]; then
  fail "catch-log skeleton is placed with rules but no rows" "could not create the temp project"
else
  run_bootstrap "$PROJECT" "Probe Seven"
  LOG="$PROJECT/.claude/memory/catch-log.md"

  if [ ! -f "$LOG" ]; then
    fail "catch-log skeleton is placed with rules but no rows" "not placed at .claude/memory/catch-log.md"
  else
    missing=""
    grep -q 'agent-self'          "$LOG" || missing="$missing who-caught-set"
    grep -q 'automatic-gate'      "$LOG" || missing="$missing automatic-gate"
    grep -qi 'promotion'          "$LOG" || missing="$missing promotion-rule"
    grep -q 'fail-open-guard'     "$LOG" || missing="$missing error-class-legend"
    # No inherited rows: a data row starts "| 20" (a date). The legend and the
    # header are tables too, so this must key on the date, not on "any table row".
    rows=$(grep -c '^| 20' "$LOG" || true)

    if [ -n "$missing" ]; then
      fail "catch-log skeleton is placed with rules but no rows" "skeleton missing:$missing"
    elif [ "$rows" -ne 0 ]; then
      fail "catch-log skeleton is placed with rules but no rows" \
           "$rows inherited row(s) — a new project must not start with this repo's defects"
    # Deliberately NOT manifest-recorded, which refines #19's AC2. The manifest
    # means "workflow-sourced and re-syncable", and this file is neither: it carries
    # a substituted placeholder (so the project copy never equals the source hash)
    # and the project writes rows to it. Listing it would make sync offer to refresh
    # a project's own defect history. Same treatment as CLAUDE.md.
    elif grep -q '^\.claude/memory/catch-log\.md	' "$PROJECT/.claude/.asset-manifest"; then
      fail "catch-log skeleton is placed with rules but no rows" \
           "it IS manifest-recorded — sync would offer to overwrite the project's own rows"
    elif ! grep -q "Probe Seven" "$LOG"; then
      fail "catch-log skeleton is placed with rules but no rows" \
           "{{PROJECT_NAME}} was not substituted"
    else
      pass "catch-log skeleton is placed with rules but no rows"
    fi
  fi
fi

rm -rf "$TESTDIR"

# 9. RUNTIME-FAITHFUL CASE (#33, catch 5a). Everything above runs under
#    `mktemp -d`, an MSYS path where `mkdir -p` on an absolute path works fine.
#    Production is a UNC path where it does not — which is why bootstrap passed
#    this entire suite while being unable to touch a single real project.
#
#    This case runs bootstrap end-to-end against a UNC-rooted fixture, the path
#    shape every real target has. It is one case rather than a conversion of all
#    thirteen: the tier belongs where the code touches path semantics, and adding
#    it everywhere would be churn without adding coverage.
UNCDIR="$(runtime_mktemp_d bootstrap-test)"
if [ -z "$UNCDIR" ]; then
  fail "bootstrap works against a UNC-rooted project (production path shape)" \
       "could not build the runtime-faithful fixture — refusing to fall back to /tmp, which would test the wrong runtime"
else
  PROJECT=$(make_project "$UNCDIR" "unc-probe")
  if [ -z "$PROJECT" ]; then
    fail "bootstrap works against a UNC-rooted project (production path shape)" \
         "could not create the project under $UNCDIR"
  else
    ( cd "$PROJECT" || exit 1; git init -q . ) >/dev/null 2>&1
    out=$(bash "$BOOTSTRAP" "$PROJECT" "UNC Probe" 2>&1); rc=$?
    entries=$(count_manifest_entries "$PROJECT")
    if [ "$rc" -ne 0 ]; then
      fail "bootstrap works against a UNC-rooted project (production path shape)" \
           "exited $rc. Output:
$(printf '%s' "$out" | tail -5)"
    elif [ "$entries" -eq 0 ]; then
      fail "bootstrap works against a UNC-rooted project (production path shape)" \
           "manifest is empty — bootstrap ran but recorded nothing"
    elif [ ! -f "$PROJECT/setup-project.sh" ]; then
      fail "bootstrap works against a UNC-rooted project (production path shape)" \
           "setup-project.sh was not emitted"
    else
      pass "bootstrap works against a UNC-rooted project (production path shape)"
    fi
  fi
  runtime_fixture_cleanup "$UNCDIR"
fi

echo ""
if [ "$FAILED" -eq 0 ]; then echo "ALL GREEN"; else echo "SOME RED"; fi
exit "$FAILED"
