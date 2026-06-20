'use strict';

const { describe, test } = require('node:test');
const assert = require('node:assert/strict');
const { classify } = require('./tdd-detector');

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

// Healthy: every test fails first; fails interleave with passes (test-C fails
// at index 3, after test-A passes at index 2 — real one-test-at-a-time TDD).
const FIXTURE_HEALTHY = `
2026-06-14T08:00:00Z\tsuite.test.js::test-A\tfail
2026-06-14T08:00:01Z\tsuite.test.js::test-B\tfail
2026-06-14T08:00:02Z\tsuite.test.js::test-A\tpass
2026-06-14T08:00:03Z\tsuite.test.js::test-C\tfail
2026-06-14T08:00:04Z\tsuite.test.js::test-B\tpass
2026-06-14T08:00:05Z\tsuite.test.js::test-C\tpass
`.trim();

// Test-after: every test first appears as pass — tests were written after code.
const FIXTURE_TEST_AFTER = `
2026-06-14T08:00:00Z\tsuite.test.js::test-A\tpass
2026-06-14T08:00:01Z\tsuite.test.js::test-B\tpass
2026-06-14T08:00:02Z\tsuite.test.js::test-C\tpass
`.trim();

// Horizontal batching: all fails precede all passes — tests written upfront
// then all made to pass in one shot, not one-at-a-time.
const FIXTURE_HORIZONTAL = `
2026-06-14T08:00:00Z\tsuite.test.js::test-A\tfail
2026-06-14T08:00:01Z\tsuite.test.js::test-B\tfail
2026-06-14T08:00:02Z\tsuite.test.js::test-C\tfail
2026-06-14T08:00:03Z\tsuite.test.js::test-A\tpass
2026-06-14T08:00:04Z\tsuite.test.js::test-B\tpass
2026-06-14T08:00:05Z\tsuite.test.js::test-C\tpass
`.trim();

// Regression: test-A passed at index 1, then failed again at index 4.
const FIXTURE_REGRESSION = `
2026-06-14T08:00:00Z\tsuite.test.js::test-A\tfail
2026-06-14T08:00:01Z\tsuite.test.js::test-A\tpass
2026-06-14T08:00:02Z\tsuite.test.js::test-B\tfail
2026-06-14T08:00:03Z\tsuite.test.js::test-B\tpass
2026-06-14T08:00:04Z\tsuite.test.js::test-A\tfail
`.trim();

// TAB-delimited (the format under test). The test name CONTAINS SPACES — a real
// node:test name — and is a first-seen pass, so correct parsing must classify it
// as test-after. A whitespace-splitting parser misreads the outcome column
// (lands on a word of the name) and misclassifies it as healthy.
const FIXTURE_SPACED_NAME =
  '2026-06-14T08:00:00Z\tsuite.test.js::locationBonus hannover returns one\tpass';

// TAB-delimited data lines preceded by the rotator's "# SESSION" comment header.
// The header is not a test record; the parser must skip it so the test count
// reflects only real tests (3 here, not 4).
const FIXTURE_HEADERED_HEALTHY = [
  '# SESSION 2026-06-14T07:59:59Z startup',
  '2026-06-14T08:00:00Z\tsuite.test.js::test-A\tfail',
  '2026-06-14T08:00:01Z\tsuite.test.js::test-B\tfail',
  '2026-06-14T08:00:02Z\tsuite.test.js::test-A\tpass',
  '2026-06-14T08:00:03Z\tsuite.test.js::test-C\tfail',
  '2026-06-14T08:00:04Z\tsuite.test.js::test-B\tpass',
  '2026-06-14T08:00:05Z\tsuite.test.js::test-C\tpass',
].join('\n');

// ---------------------------------------------------------------------------
// Cycle 1: test-after
// ---------------------------------------------------------------------------

describe('tdd-detector', () => {
  test('all-test-after: report mentions test-after', () => {
    const report = classify(FIXTURE_TEST_AFTER);
    assert.ok(report.toLowerCase().includes('test-after'),
      `Expected report to mention "test-after", got: ${report}`);
  });

  test('healthy-interleaved: report mentions healthy', () => {
    const report = classify(FIXTURE_HEALTHY);
    assert.ok(report.toLowerCase().includes('healthy'),
      `Expected report to mention "healthy", got: ${report}`);
  });

  test('horizontal-batching: report mentions horizontal or batching', () => {
    const report = classify(FIXTURE_HORIZONTAL);
    assert.ok(
      report.toLowerCase().includes('horizontal') || report.toLowerCase().includes('batching'),
      `Expected report to mention "horizontal" or "batching", got: ${report}`
    );
  });

  test('regression: report mentions regression or regress', () => {
    const report = classify(FIXTURE_REGRESSION);
    assert.ok(
      report.toLowerCase().includes('regression') || report.toLowerCase().includes('regress'),
      `Expected report to mention "regression" or "regress", got: ${report}`
    );
  });

  // Bug under fix: a SPACED test name must not corrupt the outcome column.
  test('spaced test name: first-seen pass is detected as test-after', () => {
    const report = classify(FIXTURE_SPACED_NAME);
    assert.ok(
      report.toLowerCase().includes('test-after'),
      `Expected "test-after" for a spaced-name first-seen-pass, got: ${report}`
    );
  });

  // The "# SESSION" header is not a test record; it must be ignored, not counted.
  test('session header line is ignored; count reflects only real tests', () => {
    const report = classify(FIXTURE_HEADERED_HEALTHY);
    assert.ok(
      report.toLowerCase().includes('healthy'),
      `Expected "healthy", got: ${report}`
    );
    assert.ok(
      report.includes('3 test'),
      `Expected exactly 3 tests counted (header excluded), got: ${report}`
    );
  });

  // --- Fail-closed (lead): a record-less or red-only log must NEVER say HEALTHY.
  test('empty log -> NO-DATA, never HEALTHY', () => {
    const r = classify('');
    assert.ok(/cannot assess|no-data/i.test(r), `expected NO-DATA, got: ${r}`);
    assert.ok(!/healthy/i.test(r), `must not say HEALTHY on no data, got: ${r}`);
  });

  test('header-only log (no records) -> NO-DATA', () => {
    const r = classify('# SESSION 2026-06-14T07:59:59Z startup');
    assert.ok(/cannot assess|no-data/i.test(r), `expected NO-DATA, got: ${r}`);
  });

  test('reds-only (no passes yet) -> IN-PROGRESS, never HEALTHY', () => {
    const r = classify(['t\tf::A\tfail', 't\tf::B\tfail'].join('\n'));
    assert.ok(/in-progress|not a verdict/i.test(r), `expected IN-PROGRESS, got: ${r}`);
    assert.ok(!/healthy/i.test(r), `must not say HEALTHY with no passes, got: ${r}`);
  });

  // --- Single test's red->green is healthy TDD, not horizontal batching.
  test('single test red->green -> HEALTHY (not HORIZONTAL)', () => {
    const r = classify(['t\tf::A\tfail', 't\tf::A\tpass'].join('\n'));
    assert.ok(/healthy/i.test(r), `expected HEALTHY, got: ${r}`);
    assert.ok(!/horizontal|batching/i.test(r), `must not say HORIZONTAL, got: ${r}`);
  });
});
