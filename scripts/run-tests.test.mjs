#!/usr/bin/env node
//
// Tests for run-tests.mjs — specifically that it works AS PROPAGATED.
//
// This script is the test entrypoint bootstrap installs into every project, at
// `.claude/ci/run-tests.mjs`. In THIS repo it lives at `scripts/run-tests.mjs`, and
// it resolved its project root as "my directory, then up one" — correct here, and
// wrong everywhere it is propagated to, where up-one lands on `.claude/` instead of
// the project root. It also searched only this repo's own directory layout, so a
// consumer's `test/` was never scanned.
//
// The result: `npm test` in a freshly bootstrapped project discovered zero suites.
// It failed loudly rather than reporting a false pass — that part of the design
// worked — but the propagated entrypoint did not run anything.
//
// These tests use the CONSUMER layout, because that is the one that was broken and
// the one no existing test exercised.

import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync, copyFileSync, rmSync, mkdtempSync } from 'node:fs';
import path from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const RUNNER = path.join(HERE, 'run-tests.mjs');
let failed = 0;

function check(label, cond, detail = '') {
  if (cond) console.log(`  ok  ${label}`);
  else { console.log(`  XX  ${label}`); if (detail) console.log(`      ${detail}`); failed = 1; }
}

function w(root, rel, body) {
  const p = path.join(root, rel);
  mkdirSync(path.dirname(p), { recursive: true });
  writeFileSync(p, body);
}

function run(cwd, script, extraEnv = {}) {
  const env = { ...process.env, ...extraEnv };
  try {
    return { code: 0, out: execFileSync('node', [script], { cwd, encoding: 'utf8', env }) };
  } catch (e) {
    return { code: e.status, out: (e.stdout || '') + (e.stderr || '') };
  }
}

console.log('[run-tests] propagated layout');

// 1. CONSUMER LAYOUT: runner at .claude/ci/, tests in test/. This is what bootstrap
//    produces, and it discovered nothing.
{
  const root = mkdtempSync(path.join(tmpdir(), 'rt-consumer-'));
  w(root, 'package.json', JSON.stringify({ name: 'probe', private: true }));
  mkdirSync(path.join(root, '.claude/ci'), { recursive: true });
  copyFileSync(RUNNER, path.join(root, '.claude/ci/run-tests.mjs'));
  w(root, 'test/thing.test.mjs', 'process.exit(0);\n');

  const r = run(root, '.claude/ci/run-tests.mjs');
  check('consumer layout: discovers a suite in test/', /thing\.test\.mjs/.test(r.out),
    `code=${r.code} out=${r.out.slice(0, 400)}`);
  check('consumer layout: exits 0 when that suite passes', r.code === 0,
    `code=${r.code} out=${r.out.slice(0, 400)}`);
  rmSync(root, { recursive: true, force: true });
}

// 2. A FAILING suite must still fail. Without this, a runner that discovered
//    nothing and exited 0 would satisfy test 1's spirit while being useless.
{
  const root = mkdtempSync(path.join(tmpdir(), 'rt-fail-'));
  w(root, 'package.json', JSON.stringify({ name: 'probe', private: true }));
  mkdirSync(path.join(root, '.claude/ci'), { recursive: true });
  copyFileSync(RUNNER, path.join(root, '.claude/ci/run-tests.mjs'));
  w(root, 'test/bad.test.mjs', 'process.exit(1);\n');

  const r = run(root, '.claude/ci/run-tests.mjs');
  check('consumer layout: a failing suite fails the run', r.code !== 0,
    `code=${r.code} out=${r.out.slice(0, 300)}`);
  rmSync(root, { recursive: true, force: true });
}

// 3. Zero suites must still be a LOUD failure, not a quiet pass. This property
//    already worked and must survive the fix — it is the reason the defect was
//    visible at all instead of reporting green on an empty run.
{
  const root = mkdtempSync(path.join(tmpdir(), 'rt-empty-'));
  w(root, 'package.json', JSON.stringify({ name: 'probe', private: true }));
  mkdirSync(path.join(root, '.claude/ci'), { recursive: true });
  copyFileSync(RUNNER, path.join(root, '.claude/ci/run-tests.mjs'));

  const r = run(root, '.claude/ci/run-tests.mjs');
  check('consumer layout: zero suites fails loudly', r.code !== 0 && /discovery is broken/i.test(r.out),
    `code=${r.code} out=${r.out.slice(0, 300)}`);
  rmSync(root, { recursive: true, force: true });
}

// 4. NODE_TEST_CONTEXT in the environment must not turn a failing suite green.
//    `node --test` treats that variable as "I am already inside a test run" and
//    skips every file while exiting 0. The variable is inherited, so running this
//    runner from inside any node:test process silently executed nothing and
//    reported a pass. This is the runner's own failure mode, not the fixture's:
//    the assertion is that a suite which exits 1 still fails the run.
{
  const root = mkdtempSync(path.join(tmpdir(), 'rt-ctx-'));
  w(root, 'package.json', JSON.stringify({ name: 'probe', private: true }));
  mkdirSync(path.join(root, '.claude/ci'), { recursive: true });
  copyFileSync(RUNNER, path.join(root, '.claude/ci/run-tests.mjs'));
  w(root, 'test/bad.test.mjs', 'process.exit(1);\n');

  const r = run(root, '.claude/ci/run-tests.mjs', { NODE_TEST_CONTEXT: 'child' });
  check('inherited NODE_TEST_CONTEXT does not turn a failing suite green', r.code !== 0,
    `code=${r.code} out=${r.out.slice(0, 400)}`);
  rmSync(root, { recursive: true, force: true });
}

console.log('\n' + (failed ? 'SOME RED' : 'ALL GREEN') + '\n');
process.exit(failed);
