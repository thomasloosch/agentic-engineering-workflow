'use strict';

// #12 part 2 — resolving the slice baseline: which `file::testname` keys already
// existed when the slice began. Derived from git (the base commit recorded by the
// rotator) rather than from a slice-start test run, because the failure directions
// differ: a missing/unparseable baseline degrades to today's noisy-but-safe
// behaviour, whereas a baseline captured too late would silently exempt the very
// tests it should be judging.
//
// Git access is INJECTED so these run without a repo, and so the pure name/ref
// parsing stays testable on its own.

const { describe, test } = require('node:test');
const assert = require('node:assert/strict');

const { extractTestNames, parseBaseRef, resolveBaseline } = require('./tdd-baseline.js');

describe('tdd-baseline', () => {
  test('extractTestNames: pulls leaf test names, not suite names', () => {
    const src = [
      "describe('a suite name', () => {",
      "  test('first behaviour', () => {});",
      '  test("second behaviour", () => {});',
      '});',
    ].join('\n');
    assert.deepEqual(extractTestNames(src), ['first behaviour', 'second behaviour']);
  });

  // Real case from jobs-radar: test('attaches each posting\'s resolved posture ...').
  // The extracted name must equal the RUNTIME name the recorder logged, or the key
  // will not match and the test will look new.
  //
  // GUARD, not a driver: the escape handling was already written into the regex in
  // the previous cycle, so this passed on its first run. Kept because the case is
  // real and silent when broken, but it did not drive the implementation.
  test('extractTestNames: an escaped quote yields the runtime name', () => {
    const src = String.raw`test('attaches each posting\'s resolved posture', () => {});`;
    assert.deepEqual(extractTestNames(src), ["attaches each posting's resolved posture"]);
  });

  test('parseBaseRef: reads the base commit the rotator stamped, else null', () => {
    const log = [
      '# SLICE 2026-07-24T20:33:47Z new-slice',
      '# BASE 0b6398bfe1c2d3a4',
      't\tf::A\tfail',
    ].join('\n');
    assert.equal(parseBaseRef(log), '0b6398bfe1c2d3a4');
    // No stamp (a log from before this feature, or a slice never rotated) -> null,
    // which callers must treat as "no baseline" rather than guessing a ref.
    assert.equal(parseBaseRef('t\tf::A\tfail'), null);
  });

  test('resolveBaseline: keys the tests that existed at the base commit', () => {
    const log = [
      '# BASE abc123',
      't\told.test.js::kept\tpass',
      't\told.test.js::added-this-slice\tfail',
      't\tbrand-new.test.js::fresh\tfail',
    ].join('\n');
    // old.test.js existed at base and held only `kept`; brand-new.test.js did not
    // exist at base at all (git show fails -> null).
    const readAtBase = (ref, file) => {
      assert.equal(ref, 'abc123');
      return file === 'old.test.js' ? "test('kept', () => {});" : null;
    };

    const baseline = resolveBaseline(log, readAtBase);
    assert.ok(baseline.has('old.test.js::kept'), 'a pre-existing test is baselined');
    assert.ok(!baseline.has('old.test.js::added-this-slice'), 'a test added this slice is NOT baselined');
    assert.ok(!baseline.has('brand-new.test.js::fresh'), 'a file absent at base contributes nothing');
  });

  test('resolveBaseline: no base stamp -> empty baseline, never a guess', () => {
    const log = 't\told.test.js::kept\tpass';
    let called = false;
    const baseline = resolveBaseline(log, () => { called = true; return "test('kept', () => {});"; });
    assert.equal(baseline.size, 0, 'without a base ref nothing may be exempted');
    assert.equal(called, false, 'and git must not be consulted at all');
  });
});
