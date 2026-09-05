#!/usr/bin/env node
//
// run-tests.mjs — the repo's single test entry point (`npm test`), issue #13.
//
// WHY THIS EXISTS rather than a bare `node --test`:
//
// Node's test runner SKIPS hidden (dot-prefixed) directories during discovery.
// The TDD gate lives in `.claude/tdd/`, so:
//   - `node --test`                    → finds 1 test (only scripts/), silently missing 30
//   - `node --test .claude/tdd/`       → MODULE_NOT_FOUND: discovery yields nothing, so
//                                        Node falls back to require()-ing the directory
//   - `node --test '.claude/tdd/*.js'` → works, but shell-glob-dependent
//
// So this script DISCOVERS the suites itself and passes an explicit file list to
// `node --test`. Two properties matter:
//
//   1. Discovery is dynamic, so a new test file is picked up automatically. The bug
//      this issue is about was a hardcoded two-file command that silently stopped
//      running a third file (tdd-baseline.test.js, added by #12) — 25 of 30 tests,
//      reported as a pass.
//   2. Discovery is LOUD. Every suite found is printed, and finding zero in any
//      category is a hard failure. A test runner that quietly runs nothing is
//      indistinguishable from one where everything passes.

import { spawnSync } from 'node:child_process';
import { readdirSync, existsSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// The project root, resolved by walking UP to the nearest package.json rather than
// assuming "my directory, then up one".
//
// That assumption held in this repo (scripts/ -> repo root) and broke everywhere
// this file is PROPAGATED: bootstrap installs it at .claude/ci/, where up-one is
// .claude/, so every search path resolved under .claude/ and a freshly bootstrapped
// project discovered zero suites.
function findProjectRoot(startDir) {
  let dir = startDir;
  for (;;) {
    if (existsSync(path.join(dir, 'package.json'))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  // No manifest anywhere above: fall back to the invocation directory, which for
  // `npm test` is the project root.
  return process.cwd();
}

const ROOT = findProjectRoot(path.dirname(fileURLToPath(import.meta.url)));
const shOnly = process.argv.includes('--sh-only');

// Directories searched per category. Adding a suite means dropping a file in one
// of these — no list to update here, which is the point.
// Covers this repo's layout AND a consuming project's. A propagated runner that
// searched only this repo's directories would never find a consumer's own tests —
// the second half of the same defect.
const NODE_DIRS = ['.claude/tdd', 'scripts', 'test', 'tests', 'src', 'lib'];
// `hooks` (the Claude Code LIFECYCLE hooks) was missing here while `hooks/git` and
// `.claude/hooks` were present — so a test file dropped into hooks/ was silently
// never discovered, and the four lifecycle hooks went un-suited entirely. Same
// silent-truncation class as the hardcoded two-file command #13 fixed: discovery
// that quietly covers less than it appears to.
const SH_DIRS = ['.claude/hooks', 'hooks', 'hooks/git', 'scripts', 'scripts/lib', 'test', 'tests'];

const NODE_RE = /\.test\.(js|mjs)$/;
const SH_RE = /\.test\.sh$/;

function discover(dirs, re) {
  const found = [];
  for (const dir of dirs) {
    const abs = path.join(ROOT, dir);
    if (!existsSync(abs)) continue;
    for (const entry of readdirSync(abs).sort()) {
      if (re.test(entry)) found.push(path.join(dir, entry).replace(/\\/g, '/'));
    }
  }
  return found;
}

const nodeSuites = discover(NODE_DIRS, NODE_RE);
const shSuites = discover(SH_DIRS, SH_RE);

console.log('=== discovered suites ===');
if (!shOnly) nodeSuites.forEach((f) => console.log(`  [node] ${f}`));
shSuites.forEach((f) => console.log(`  [sh]   ${f}`));

// Fail closed on empty discovery: silence here would read as success everywhere.
//
// The bar is TOTAL discovery, not per-category. Requiring at least one suite in
// EVERY category was right for this repo, which always has both, and made the
// propagated runner unusable: a project with only JS tests and no shell guards
// could never pass. That is this repo's layout mistaken for a universal rule.
//
// An empty CATEGORY is still called out, because a category that silently
// disappears is the truncation risk the per-category check was reaching for. It is
// a visible note rather than a failure: absence is legitimate elsewhere.
const discoveredTotal = (shOnly ? 0 : nodeSuites.length) + shSuites.length;
if (discoveredTotal === 0) {
  console.error('ERROR: no test suites discovered at all — discovery is broken, not the repo clean.');
  console.error(`       searched under: ${ROOT}`);
  process.exit(1);
}
if (!shOnly && nodeSuites.length === 0) console.log('  NOTE: no node suites found (expected if this project has none).');
if (shSuites.length === 0) console.log('  NOTE: no shell suites found (expected if this project has none).');

// `node --test` SILENTLY SKIPS EVERY FILE and exits 0 when NODE_TEST_CONTEXT is
// present in its environment — it reads that as a recursive run() inside a test
// file and declines to run anything. Node prints a warning; the exit code says
// success. Demonstrated: a file whose only statement is `process.exit(1)` exits 1
// normally and 0 under NODE_TEST_CONTEXT=child.
//
// The variable is inherited, so ANY invocation of this runner from inside a
// node:test process — a meta-test of the runner, a suite that shells out to
// `npm test`, an editor's test integration — reported "OK: all N suite(s) passed"
// having executed nothing. A false green produced by an environment variable is
// the exact failure this runner exists to prevent, so it is scrubbed here rather
// than worked around at each call site.
const CHILD_ENV = { ...process.env };
delete CHILD_ENV.NODE_TEST_CONTEXT;

const failures = [];

if (!shOnly) {
  console.log('\n=== node --test ===');
  // Explicit file list, dynamically built: immune to the dot-directory discovery
  // rule AND to going stale.
  const r = spawnSync(process.execPath, ['--test', ...nodeSuites], { cwd: ROOT, stdio: 'inherit', env: CHILD_ENV });
  if (r.status !== 0) failures.push(`node --test (${nodeSuites.length} suite(s))`);
}

for (const suite of shSuites) {
  console.log(`\n=== bash ${suite} ===`);
  // The shell suites are the guards' own tests; they need bash, which is present
  // on Linux CI and via Git Bash in the dev runtime.
  const r = spawnSync('bash', [suite], { cwd: ROOT, stdio: 'inherit', env: CHILD_ENV });
  if (r.status !== 0) failures.push(`bash ${suite}`);
}

const total = (shOnly ? 0 : nodeSuites.length) + shSuites.length;
console.log(`\n${'='.repeat(60)}`);
if (failures.length > 0) {
  console.error(`FAIL: ${failures.length} of ${total} suite(s) failed:`);
  failures.forEach((f) => console.error(`  - ${f}`));
  process.exit(1);
}
console.log(`OK: all ${total} suite(s) passed.`);
