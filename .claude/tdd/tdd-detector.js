'use strict';

// Fields are TAB-delimited: <iso>\t<file::testname>\t<outcome>. Splitting on TAB
// (not whitespace) lets test names contain spaces — real node:test names do,
// e.g. "hannover hybrid job passes" — without the outcome column drifting onto a
// word of the name. Must match the recorder's writer exactly.
function parseLine(line) {
  const [timestamp, testname, outcome] = line.split('\t');
  return { timestamp, testname, outcome };
}

// `opts.baseline` is the set of `file::testname` keys that already existed when the
// slice began (#12 part 2). Those tests are recorded pass-first whenever a run
// touches their file — node runs the whole file — which is not evidence of
// test-after. Defaulting to empty preserves the previous behaviour exactly, so a
// caller that cannot resolve a baseline degrades to noisy-but-safe rather than
// silently exempting tests it should be judging.
function classify(logText, opts = {}) {
  const baseline = new Set(opts.baseline || []);
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

  // Findings are COLLECTED, never returned early (#12). Returning on the first
  // violation let the noisiest check suppress the quieter ones: TEST-AFTER fires
  // spuriously whenever a recorded run includes a test that predates the slice (a
  // pre-existing test in an edited file is recorded pass-first), and while it was
  // returning early it took any REGRESSION or HORIZONTAL BATCHING in the same log
  // down with it. The checks are independent, so the report is too.
  const findings = [];

  // A test whose first appearance is a pass was written after its code — unless it
  // predates the slice, in which case its pass is an artifact of node running the
  // whole file, not a discipline violation.
  const testAfter = [...firstSeen.entries()]
    .filter(([name, o]) => o === 'pass' && !baseline.has(name))
    .map(([name]) => name);
  if (testAfter.length > 0) {
    findings.push(`TEST-AFTER detected: ${testAfter.join(', ')} — first appearance was a pass. In genuine TDD every test must fail before it passes.`);
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
    findings.push(`REGRESSION detected: ${regressions.join(', ')} — passed then failed again. A previously-passing test has broken; likely a bad implementation change or test-order dependency.`);
  }

  // Horizontal batching: >= 2 tests where every fail precedes every pass (written
  // upfront, made green in one shot). A SINGLE test's red->green is normal TDD,
  // not batching — so require at least two distinct tests here.
  //
  // Judged over SLICE tests only. This check compares row POSITIONS, so a baseline
  // test passing early drags firstPassIdx to the front and the condition can never
  // hold — the batching stays invisible however the findings are reported. Dropping
  // baseline rows is what lets the check see the slice's own sequence.
  const sliceEntries = entries.filter((e) => !baseline.has(e.testname));
  const sliceTestCount = new Set(sliceEntries.map((e) => e.testname)).size;
  const lastFailIdx  = sliceEntries.reduce((acc, e, i) => (e.outcome === 'fail' ? i : acc), -1);
  const firstPassIdx = sliceEntries.findIndex((e) => e.outcome === 'pass');
  if (sliceTestCount >= 2 && lastFailIdx !== -1 && firstPassIdx > lastFailIdx) {
    findings.push(`HORIZONTAL BATCHING: all ${sliceTestCount} tests failed before any passed. Tests appear to have been written upfront and made to pass in one batch, not one-at-a-time TDD.`);
  }

  // Every finding, most-specific first, so a spurious TEST-AFTER can no longer hide
  // a real one. HEALTHY remains mutually exclusive with any finding — it is only
  // reached when nothing at all was found.
  if (findings.length > 0) {
    return findings.join('\n');
  }

  // Passes present, every test red-first, not batched: healthy one-at-a-time TDD
  // (covers a single test's red->green and genuine multi-test interleaving).
  //
  // Counts the SLICE's tests, not the exempted baseline: the sentence claims each
  // test first appeared failing, which is untrue of baseline tests — they first
  // appeared passing, which is why they were exempted. A verdict must not assert
  // something false about the tests it names.
  const baselineNote = baseline.size > 0 ? ` (${baseline.size} pre-existing test(s) excluded)` : '';
  return `HEALTHY: ${sliceTestCount} test(s), each first appeared failing and then passed${baselineNote}. Consistent with one-test-at-a-time TDD.`;
}

module.exports = { classify };
