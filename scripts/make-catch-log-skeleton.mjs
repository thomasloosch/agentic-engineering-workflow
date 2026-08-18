#!/usr/bin/env node
//
// make-catch-log-skeleton.mjs — derive the propagated catch-log skeleton from this
// repo's own catch-log.
//
// WHY GENERATED RATHER THAN HAND-WRITTEN
//
// A new project must inherit the catch-log's RULES — the closed who-caught set, the
// error-class vocabulary, the promotion threshold, the hygiene constraints — and
// none of its ROWS, which are this repo's own defect history and do not travel.
//
// The obvious implementation is a template file containing a copy of those rules.
// That copy would drift: the rules changed three times in a single session (the
// collapse breakdown, the no-pipes constraint, promoted-classes-stop-counting,
// do-not-merge-classes), and every one of those changes would have had to be made
// twice. Two copies of a definition that must not diverge is the #6 drift problem,
// and reproducing it inside the fix for it is the mistake #16's asset-list.sh
// extraction already avoided once.
//
// So the live catch-log is the single source, and the skeleton is derived from it.
// `--check` asserts the committed skeleton matches what the source would produce,
// which is what stops the two silently diverging.
//
// Usage:
//   node scripts/make-catch-log-skeleton.mjs            # write the skeleton
//   node scripts/make-catch-log-skeleton.mjs --check    # exit 1 if stale

import { readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SOURCE = path.join(ROOT, '.claude/memory/catch-log.md');
const TARGET = path.join(ROOT, 'templates/catch-log.md.template');

// Sections that describe THIS repo's history rather than the mechanism. Everything
// from the first of these to the end of the file is dropped.
const PROJECT_SPECIFIC_HEADINGS = [
  '## Class standings',
  '## Promotions fired',
];

function buildSkeleton(rawSrc) {
  // Normalise line endings FIRST. This checkout produces CRLF, and the original
  // version of this function searched for '\n---\n', which never matched — so the
  // header replacement silently did nothing and the generated skeleton carried the
  // source's own header, complete with "#19 acceptance criteria" text meaningless
  // in a consuming project. It failed silently and looked plausible, which is
  // catch 5a (an environment characteristic untested by construction) occurring in
  // the code written to implement catch 5a.
  const src = rawSrc.replace(/\r\n/g, '\n');
  const lines = src.split('\n');
  const out = [];

  let stop = false;
  for (const line of lines) {
    if (PROJECT_SPECIFIC_HEADINGS.some((h) => line.startsWith(h))) {
      stop = true;
    }
    if (stop) continue;

    // Data rows start with a date. The legend and the table header are also table
    // rows, so keying on "any | row" would strip the vocabulary this exists to ship.
    if (/^\| 20\d\d-/.test(line)) continue;

    out.push(line);
  }

  let body = out.join('\n');

  // Drop the paragraphs that only make sense with rows present: the backfill
  // provenance note and the running corpus count.
  body = body.replace(/\*\*Provenance note[\s\S]*?(?=\n---|\n## )/g, '');
  body = body.replace(/\*\*AC5 after a collapse\.\*\*[\s\S]*?(?=\n---|\n## )/g, '');
  body = body.replace(/\*\*Current corpus[\s\S]*?(?=\n---|\n## )/g, '');
  body = body.replace(/\*Archive:[^\n]*\*/g, '');
  body = body.replace(/Two honest readings of it:[\s\S]*?(?=\n---|\n## )/g, '');
  body = body.replace(/Read that number carefully[\s\S]*?(?=\n---|\n## )/g, '');
  body = body.replace(/\n{3,}/g, '\n\n');

  const header = [
    '# Catch-log — {{PROJECT_NAME}}',
    '',
    'Per-project defect log: what was caught, who caught it, what class of error it',
    'was. Two jobs — measuring whether the harness actually catches things (the',
    'self-catch ratio), and the loop\'s **up**-direction: a class that recurs here',
    'becomes a candidate for promotion to the central standards.',
    '',
    '**This file is yours.** It arrived with the rules and an empty table; the rows',
    'are this project\'s own history and are never distributed anywhere. It is',
    'deliberately NOT a mirror of the workflow repo\'s catch-log — that one holds a',
    'different project\'s defects.',
    '',
    '**Generated from the canonical catch-log** by',
    '`scripts/make-catch-log-skeleton.mjs`. The rules below are kept in sync with the',
    'source at the centre; edit them there, not here.',
    '',
    '---',
    '',
  ].join('\n');

  // Replace the source's own header (everything before the first ---) with ours.
  const afterFirstRule = body.indexOf('\n---\n');
  const rulesOnward = afterFirstRule === -1 ? body : body.slice(afterFirstRule + 5);

  return (header + rulesOnward.trimStart()).trimEnd() + '\n';
}

const src = readFileSync(SOURCE, 'utf8');
const skeleton = buildSkeleton(src);

// Guard against the failure that just happened: if the header replacement did not
// take, the skeleton silently ships the source's own framing. Assert the outcome,
// not the attempt.
if (skeleton.includes('#19') || skeleton.includes('agentic-engineering-workflow')) {
  console.error('FAIL: the generated skeleton still contains workflow-repo-specific text.');
  console.error('      The header replacement did not take — refusing to write a skeleton');
  console.error('      that would ship this repo\'s framing into a consuming project.');
  process.exit(1);
}

if (process.argv.includes('--check')) {
  let current = '';
  try {
    current = readFileSync(TARGET, 'utf8');
  } catch {
    console.error('FAIL: templates/catch-log.md.template does not exist.');
    console.error('      Run: node scripts/make-catch-log-skeleton.mjs');
    process.exit(1);
  }
  if (current !== skeleton) {
    console.error('FAIL: templates/catch-log.md.template is STALE.');
    console.error('      The catch-log\'s rules changed and the propagated skeleton did not,');
    console.error('      so new projects would inherit the old vocabulary or promotion rule.');
    console.error('      Run: node scripts/make-catch-log-skeleton.mjs');
    process.exit(1);
  }
  console.log('OK: catch-log skeleton is current.');
  process.exit(0);
}

writeFileSync(TARGET, skeleton);
const rows = (skeleton.match(/^\| 20\d\d-/gm) || []).length;
console.log(`Wrote ${path.relative(ROOT, TARGET)} (${skeleton.split('\n').length} lines, ${rows} data rows)`);
