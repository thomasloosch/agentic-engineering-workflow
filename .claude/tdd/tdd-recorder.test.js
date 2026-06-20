'use strict';

const { describe, test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const reporter = require('./tdd-recorder');
const { createRecorder, appendSafe } = reporter;

// ---------------------------------------------------------------------------
// Fabricated node --test reporter events (shapes confirmed empirically):
// real test → details.type "test"; suite aggregate → details.type "suite";
// skip/todo → test:pass with data.skip / data.todo set.
// ---------------------------------------------------------------------------

const NOW = '2026-06-14T00:00:00.000Z';
const CWD = '/proj';

function passEvent({ name, file }) {
  return { type: 'test:pass', data: { name, file, nesting: 1, details: { type: 'test' } } };
}

function failEvent({ name, file, causeCode }) {
  return {
    type: 'test:fail',
    data: {
      name, file, nesting: 1,
      details: {
        type: 'test',
        error: { failureType: 'testCodeFailure', code: 'ERR_TEST_FAILURE',
                 cause: causeCode ? { code: causeCode } : 'serialized error string' },
      },
    },
  };
}

// Drive the reporter (an async generator that yields nothing) to completion.
async function drainReporter(events) {
  async function* src() { for (const e of events) yield e; }
  const gen = reporter(src());
  for (;;) {
    const { done } = await gen.next();
    if (done) break;
  }
}

function suiteEvent({ name, file, status }) {
  return {
    type: status === 'pass' ? 'test:pass' : 'test:fail',
    data: { name, file, nesting: 0, details: { type: 'suite' } },
  };
}

describe('tdd-recorder', () => {
  // The old module-load filter dropped any test whose name basename matched the
  // file basename — a false positive. node never sends a pass/fail event for a
  // real module-load failure (verified), so the filter is gone: a real test
  // named like its file must now log.
  test('real test named like its file basename → logs (no false drop)', () => {
    const { handle } = createRecorder({ cwd: CWD });
    const lines = handle(
      { type: 'test:pass', data: { name: 'x.test.js', file: '/proj/src/x.test.js', details: { type: 'test' } } },
      NOW,
    );
    assert.deepEqual(lines, ['2026-06-14T00:00:00.000Z\tsrc/x.test.js::x.test.js\tpass']);
  });

  test('assertion-fail event (name≠file, ERR_ASSERTION) → fail line', () => {
    const { handle } = createRecorder({ cwd: CWD });
    const lines = handle(
      failEvent({ name: 'rejects bad input', file: '/proj/src/x.test.js', causeCode: 'ERR_ASSERTION' }),
      NOW,
    );
    assert.deepEqual(lines, ['2026-06-14T00:00:00.000Z\tsrc/x.test.js::rejects bad input\tfail']);
  });

  test('pass event (name≠file) → pass line', () => {
    const { handle } = createRecorder({ cwd: CWD });
    const lines = handle(
      passEvent({ name: 'accepts good input', file: '/proj/src/x.test.js' }),
      NOW,
    );
    assert.deepEqual(lines, ['2026-06-14T00:00:00.000Z\tsrc/x.test.js::accepts good input\tpass']);
  });

  test('suite aggregate (details.type==="suite") → no line', () => {
    const { handle } = createRecorder({ cwd: CWD });
    const lines = handle(
      suiteEvent({ name: 'my describe block', file: '/proj/src/x.test.js', status: 'pass' }),
      NOW,
    );
    assert.deepEqual(lines, []);
  });

  // Leaf-name-only resolution can collide (two tests with the same name in
  // different describe blocks). Flag it; full describe-ancestry is deferred.
  test('two distinct tests resolving to same file::name → collision-warning line', () => {
    const { handle } = createRecorder({ cwd: CWD });
    handle(passEvent({ name: 'dup', file: '/proj/src/x.test.js' }), NOW);
    const lines = handle(passEvent({ name: 'dup', file: '/proj/src/x.test.js' }), NOW);
    assert.ok(
      lines.some((l) => /collision/i.test(l)),
      `expected a collision-warning line, got ${JSON.stringify(lines)}`,
    );
  });

  // Skipped / todo tests report as test:pass with data.skip / data.todo set —
  // they are not real green outcomes and must not be logged as pass.
  test('skipped test (data.skip) → no line', () => {
    const { handle } = createRecorder({ cwd: CWD });
    const lines = handle(
      { type: 'test:pass', data: { name: 'skips', file: '/proj/src/x.test.js', skip: true, details: { type: 'test' } } },
      NOW,
    );
    assert.deepEqual(lines, []);
  });

  test('todo test (data.todo) → no line', () => {
    const { handle } = createRecorder({ cwd: CWD });
    const lines = handle(
      { type: 'test:pass', data: { name: 'todos', file: '/proj/src/x.test.js', todo: true, details: { type: 'test' } } },
      NOW,
    );
    assert.deepEqual(lines, []);
  });

  // A logging failure must never break the caller's `npm test`: warn, don't throw.
  test('appendSafe: write failure warns to stderr without throwing', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'tddrec-'));
    const orig = process.stderr.write;
    let captured = '';
    process.stderr.write = (s) => { captured += s; return true; };
    let threw = false;
    try {
      appendSafe(dir, 'data\n'); // dir is a directory -> appendFileSync throws EISDIR
    } catch {
      threw = true;
    } finally {
      process.stderr.write = orig;
    }
    fs.rmSync(dir, { recursive: true, force: true });
    assert.equal(threw, false);
    assert.match(captured, /tdd-recorder|log write failed/i);
  });

  test('appendSafe: success writes the text and returns true', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'tddrec-'));
    const p = path.join(dir, 'sub', 'ok.log');
    const ok = appendSafe(p, 'hello\n');
    const got = fs.readFileSync(p, 'utf8');
    fs.rmSync(dir, { recursive: true, force: true });
    assert.equal(ok, true);
    assert.equal(got, 'hello\n');
  });

  // TDD_RECORD gate: routine `npm test` (flag unset) must not touch the log;
  // only `npm run tdd` (flag set) records.
  const EV = [{ type: 'test:pass', data: { name: 'a', file: '/p/x.test.js', details: { type: 'test' } } }];
  const withEnv = async (rec, log, fn) => {
    const saved = { rec: process.env.TDD_RECORD, log: process.env.TDD_LOG };
    if (rec === undefined) delete process.env.TDD_RECORD; else process.env.TDD_RECORD = rec;
    process.env.TDD_LOG = log;
    try { await fn(); } finally {
      if (saved.rec === undefined) delete process.env.TDD_RECORD; else process.env.TDD_RECORD = saved.rec;
      if (saved.log === undefined) delete process.env.TDD_LOG; else process.env.TDD_LOG = saved.log;
    }
  };

  test('reporter: no-op without TDD_RECORD (npm test stays clean)', async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'tddrec-'));
    const log = path.join(dir, 'tdd-session.log');
    await withEnv(undefined, log, () => drainReporter(EV));
    const existed = fs.existsSync(log);
    fs.rmSync(dir, { recursive: true, force: true });
    assert.equal(existed, false);
  });

  test('reporter: records when TDD_RECORD is set', async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'tddrec-'));
    const log = path.join(dir, 'tdd-session.log');
    await withEnv('1', log, () => drainReporter(EV));
    const body = fs.existsSync(log) ? fs.readFileSync(log, 'utf8') : '';
    fs.rmSync(dir, { recursive: true, force: true });
    assert.match(body, /::a\tpass/);
  });
});
