'use strict';

// Fields are TAB-delimited: <iso>\t<file::testname>\t<outcome>. Splitting on TAB
// (not whitespace) lets test names contain spaces — real node:test names do,
// e.g. "hannover hybrid job passes" — without the outcome column drifting onto a
// word of the name. Must match the recorder's writer exactly.
function parseLine(line) {
  const [timestamp, testname, outcome] = line.split('\t');
  return { timestamp, testname, outcome };
}

function classify(logText) {
  // Split on \r?\n so a Windows-written log (CRLF) doesn't leave a stray \r on
  // the outcome field. Keep only real test records: the "# SESSION" header and
  // "COLLISION" diagnostic lines have no pass/fail outcome and are dropped here.
  const entries = logText
    .split(/\r?\n/)
    .map(parseLine)
    .filter((e) => e.outcome === 'pass' || e.outcome === 'fail');

  // Fail-closed: with no records we cannot judge anything. Never fall through to
  // a HEALTHY verdict on an empty / headers-only / all-dropped log.
  if (entries.length === 0) {
    return 'NO-DATA: cannot assess — the log holds no test records (pass/fail lines).';
  }

  const firstSeen = new Map(); // testname → first-seen 'pass' | 'fail'
  for (const { testname, outcome } of entries) {
    if (!firstSeen.has(testname)) firstSeen.set(testname, outcome);
  }

  // Reds only, no greens yet: the red phase is unfinished. Not a verdict, and
  // explicitly NOT healthy — a passing green must exist before we call it good.
  if (!entries.some((e) => e.outcome === 'pass')) {
    return `IN-PROGRESS: ${firstSeen.size} test(s) failing, no passes yet — not a verdict (red phase incomplete).`;
  }

  // A test whose first appearance is a pass was written after its code.
  const testAfter = [...firstSeen.entries()]
    .filter(([, o]) => o === 'pass')
    .map(([name]) => name);
  if (testAfter.length > 0) {
    return `TEST-AFTER detected: ${testAfter.join(', ')} — first appearance was a pass. In genuine TDD every test must fail before it passes.`;
  }

  // A test that passed and then failed again has regressed.
  const hasPassed = new Set();
  const regressions = [];
  for (const { testname, outcome } of entries) {
    if (outcome === 'pass') {
      hasPassed.add(testname);
    } else if (outcome === 'fail' && hasPassed.has(testname) && !regressions.includes(testname)) {
      regressions.push(testname);
    }
  }
  if (regressions.length > 0) {
    return `REGRESSION detected: ${regressions.join(', ')} — passed then failed again. A previously-passing test has broken; likely a bad implementation change or test-order dependency.`;
  }

  // Horizontal batching: >= 2 tests where every fail precedes every pass (written
  // upfront, made green in one shot). A SINGLE test's red->green is normal TDD,
  // not batching — so require at least two distinct tests here.
  const lastFailIdx  = entries.reduce((acc, e, i) => (e.outcome === 'fail' ? i : acc), -1);
  const firstPassIdx = entries.findIndex((e) => e.outcome === 'pass');
  if (firstSeen.size >= 2 && lastFailIdx !== -1 && firstPassIdx > lastFailIdx) {
    return `HORIZONTAL BATCHING: all ${firstSeen.size} tests failed before any passed. Tests appear to have been written upfront and made to pass in one batch, not one-at-a-time TDD.`;
  }

  // Passes present, every test red-first, not batched: healthy one-at-a-time TDD
  // (covers a single test's red->green and genuine multi-test interleaving).
  return `HEALTHY: ${firstSeen.size} test(s), each first appeared failing and then passed. Consistent with one-test-at-a-time TDD.`;
}

module.exports = { classify };
