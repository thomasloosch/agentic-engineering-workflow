#!/usr/bin/env node
'use strict';

// The gate's entry point: read the slice log, resolve the slice baseline from git,
// print the verdict. Before this existed the detector was a library nothing called,
// so every verdict was a hand-rolled `node -e` — which is part of why the #12 defect
// went unnoticed for so long.
//
// Deliberately THIN. All judgement lives in tdd-detector.js and all baseline logic
// in tdd-baseline.js, both pure and unit-tested; this file is only I/O glue — argv,
// file read, `git show`, exit code — and is verified end-to-end rather than by unit
// test, since mocking its three side effects would test the mock.
//
// Usage:  node .claude/tdd/tdd-verdict.js [logPath]
//         TDD_LOG=... node .claude/tdd/tdd-verdict.js
// Exit:   0 = HEALTHY / NO-DATA / IN-PROGRESS (no violation asserted)
//         1 = at least one finding

const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const { classify } = require('./tdd-detector.js');
const { resolveBaseline } = require('./tdd-baseline.js');

const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const logPath = process.argv[2]
  || process.env.TDD_LOG
  || path.join(projectDir, '.claude', 'logs', 'tdd-session.log');

let logText;
try {
  logText = fs.readFileSync(logPath, 'utf8');
} catch (err) {
  // Fail closed and loud: no log is not a pass.
  process.stderr.write(`[tdd-verdict] cannot read ${logPath}: ${err.message}\n`);
  process.exit(1);
}

// `git show <ref>:<file>` returns the file AS OF the slice's base commit. A file that
// did not exist there exits non-zero; we swallow that and return null, which the
// resolver reads as "every test in this file is new" — the safe direction.
function readAtBase(ref, file) {
  try {
    return execFileSync('git', ['-C', projectDir, 'show', `${ref}:${file}`], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
  } catch {
    return null;
  }
}

const baseline = resolveBaseline(logText, readAtBase);
const verdict = classify(logText, { baseline });

process.stdout.write(`${verdict}\n`);
if (baseline.size === 0 && /^#\s*BASE\s/m.test(logText) === false) {
  // Say so explicitly rather than letting a silent empty baseline look authoritative:
  // an unstamped log is judged exactly as it was before #12, noise included.
  process.stderr.write(
    '[tdd-verdict] no "# BASE" stamp in the log — judged without a slice baseline '
    + '(pre-existing tests may appear as TEST-AFTER). Rotate with --new-slice at slice start.\n',
  );
}

process.exit(/^(HEALTHY|NO-DATA|IN-PROGRESS)/.test(verdict) ? 0 : 1);
