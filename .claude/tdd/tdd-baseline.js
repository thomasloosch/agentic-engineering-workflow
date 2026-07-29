'use strict';

// #12 part 2 — the slice baseline. See tdd-baseline.test.js for the rationale.

// Leaf test names only — `describe(...)` names are deliberately NOT collected. The
// recorder keys on leaf names, so a suite name can never be a key; collecting them
// would risk exempting a real test that happens to share a suite's name.
//
// A name this regex cannot read is simply absent from the baseline, so that test is
// judged as if it were new. That is the safe direction: the worst case is the
// false-positive TEST-AFTER we already live with, never a silently-exempted test.
const TEST_NAME = /\btest(?:\.(?:skip|todo|only))?\s*\(\s*(['"`])((?:\\.|(?!\1)[^\\])*)\1/g;

function extractTestNames(source) {
  const names = [];
  for (const m of String(source).matchAll(TEST_NAME)) {
    // Un-escape so the extracted name matches the RUNTIME name the recorder logged:
    // `test('a posting\'s name')` is logged as `a posting's name`.
    names.push(m[2].replace(/\\(.)/g, '$1'));
  }
  return names;
}

// The rotator stamps `# BASE <sha>` at slice start. Absent means "no baseline is
// knowable" — never a guess at HEAD, which would move as the slice progresses and
// would exempt the slice's own tests.
function parseBaseRef(logText) {
  const m = String(logText).match(/^#\s*BASE\s+(\S+)\s*$/m);
  return m ? m[1] : null;
}

// Which files the slice's log mentions. Only these need reading at the base commit —
// a test file the slice never ran cannot contribute a key to judge.
function filesInLog(logText) {
  const files = new Set();
  for (const line of String(logText).split(/\r?\n/)) {
    const [, key, outcome] = line.split('\t');
    if (outcome !== 'pass' && outcome !== 'fail') continue;
    const i = key.indexOf('::');
    if (i > 0) files.add(key.slice(0, i));
  }
  return files;
}

// `readAtBase(ref, file)` returns the file's source AT the base commit, or null if
// it did not exist there (the caller wires this to `git show <ref>:<file>`). It is
// injected so this stays a pure function of its inputs and testable without a repo.
//
// Every uncertainty resolves toward an EMPTY baseline: no base stamp, a file absent
// at base, a name the extractor cannot read. An empty baseline reproduces the
// pre-#12 behaviour — noisy, but it never exempts a test that should be judged.
function resolveBaseline(logText, readAtBase) {
  const baseline = new Set();
  const ref = parseBaseRef(logText);
  if (!ref) return baseline;

  for (const file of filesInLog(logText)) {
    let source;
    try {
      source = readAtBase(ref, file);
    } catch {
      source = null; // unreadable at base == treat every test in it as new
    }
    if (!source) continue;
    for (const name of extractTestNames(source)) {
      baseline.add(`${file}::${name}`);
    }
  }
  return baseline;
}

module.exports = { extractTestNames, parseBaseRef, resolveBaseline };
