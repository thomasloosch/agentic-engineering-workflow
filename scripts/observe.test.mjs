import { describe, test } from 'node:test';
import assert from 'node:assert/strict';

import { aggregate, projectPathFrom, formatReport } from './observe.mjs';

// Line shapes copied from real transcripts (~/.claude/projects/<slug>/*.jsonl), so
// the parser is pinned against what Claude Code actually writes rather than an
// invented schema.
const assistant = (model, usage, tools = [], ts = '2026-07-30T10:00:00.000Z') => JSON.stringify({
  type: 'assistant',
  timestamp: ts,
  message: {
    model,
    role: 'assistant',
    usage,
    content: [
      { type: 'text', text: 'SECRET-PROSE-SHOULD-NEVER-APPEAR' },
      ...tools.map((name) => ({ type: 'tool_use', name, input: { cmd: 'SECRET-ARG' } })),
    ],
  },
});

const usage = (i, o, cc = 0, cr = 0) => ({
  input_tokens: i, output_tokens: o, cache_creation_input_tokens: cc, cache_read_input_tokens: cr,
});

const userLine = (ts = '2026-07-30T09:59:00.000Z') => JSON.stringify({
  type: 'user', timestamp: ts, message: { role: 'user', content: 'SECRET-USER-PROSE' },
});

describe('#5 — aggregate over transcript lines', () => {
  test('sums tokens across turns, by category', () => {
    const a = aggregate([assistant('opus-5', usage(10, 5, 3, 100)), assistant('opus-5', usage(1, 2, 0, 7))]);
    assert.deepEqual(a.tokens, { input: 11, output: 7, cacheCreate: 3, cacheRead: 107 });
  });

  test('counts model mix and tool distribution', () => {
    const a = aggregate([
      assistant('opus-5', usage(1, 1), ['Bash', 'Read']),
      assistant('fable-5', usage(1, 1), ['Bash']),
    ]);
    assert.deepEqual(a.models, { 'opus-5': 1, 'fable-5': 1 });
    assert.deepEqual(a.tools, { Bash: 2, Read: 1 });
  });

  test('counts API errors', () => {
    const a = aggregate([JSON.stringify({ type: 'assistant', isApiErrorMessage: true, apiErrorStatus: 529 })]);
    assert.equal(a.apiErrors, 1);
  });

  test('attributes subagent (sidechain) turns separately', () => {
    const main = JSON.parse(assistant('opus-5', usage(1, 1)));
    const sub = { ...JSON.parse(assistant('opus-5', usage(2, 2))), isSidechain: true };
    const a = aggregate([JSON.stringify(main), JSON.stringify(sub)]);
    assert.equal(a.sidechainTurns, 1);
  });

  test('reports a date range from timestamps', () => {
    const a = aggregate([
      userLine('2026-07-01T00:00:00.000Z'),
      assistant('opus-5', usage(1, 1), [], '2026-07-05T00:00:00.000Z'),
    ]);
    assert.equal(a.firstSeen, '2026-07-01T00:00:00.000Z');
    assert.equal(a.lastSeen, '2026-07-05T00:00:00.000Z');
  });

  test('a malformed line is counted and skipped, never fatal', () => {
    const a = aggregate(['{not json', assistant('opus-5', usage(4, 4))]);
    assert.equal(a.unparsableLines, 1);
    assert.equal(a.tokens.input, 4);
  });

  test('an empty input yields zeros, not a crash', () => {
    const a = aggregate([]);
    assert.equal(a.tokens.input, 0);
    assert.equal(a.assistantTurns, 0);
  });
});

describe('#8 — a cutoff splits turns into before/after so a delta is readable', () => {
  // Criterion 1 of #8 is "frontier share drops", which a cumulative total cannot
  // answer: every turn ever recorded is in one bucket. Shipping that criterion
  // against a tool that only emits totals made it unverifiable by construction.
  const early = assistant('opus-5', usage(10, 1), ['Bash'], '2026-07-01T00:00:00.000Z');
  const late = assistant('sonnet-5', usage(20, 2), ['Read'], '2026-07-31T00:00:00.000Z');
  const CUT = Date.parse('2026-07-15T00:00:00.000Z');

  test('since keeps only turns at or after the cutoff', () => {
    const a = aggregate([early, late], undefined, { since: CUT });
    assert.deepEqual(a.models, { 'sonnet-5': 1 });
    assert.equal(a.tokens.input, 20);
  });

  test('until keeps only turns before the cutoff', () => {
    const a = aggregate([early, late], undefined, { until: CUT });
    assert.deepEqual(a.models, { 'opus-5': 1 });
    assert.equal(a.tokens.input, 10);
  });

  test('the two halves partition the whole — nothing double-counted or dropped', () => {
    const whole = aggregate([early, late]);
    const before = aggregate([early, late], undefined, { until: CUT });
    const after = aggregate([early, late], undefined, { since: CUT });
    assert.equal(before.assistantTurns + after.assistantTurns, whole.assistantTurns);
    assert.equal(before.tokens.input + after.tokens.input, whole.tokens.input);
  });

  test('a turn with no timestamp is excluded from both halves, and counted', () => {
    // Excluding it silently would make the halves quietly not sum to the whole.
    const undated = JSON.stringify({
      type: 'assistant', message: { model: 'opus-5', usage: usage(5, 5), content: [] },
    });
    const a = aggregate([undated], undefined, { since: CUT });
    assert.equal(a.assistantTurns, 0);
    assert.equal(a.undatedTurns, 1);
  });

  test('no cutoff means no filtering — the default stays a plain total', () => {
    const a = aggregate([early, late]);
    assert.equal(a.assistantTurns, 2);
    assert.equal(a.undatedTurns, 0);
  });
});

describe('#5 — output carries metrics only, never content', () => {
  // The transcripts hold full conversation text. A summariser that prints any of it
  // is a leak waiting to be pasted somewhere, so this is asserted, not assumed.
  const lines = [userLine(), assistant('opus-5', usage(9, 9), ['Bash'])];

  test('aggregate output contains no prose, tool arguments, or raw lines', () => {
    const blob = JSON.stringify(aggregate(lines));
    assert.ok(!blob.includes('SECRET'), 'no conversation text or tool arguments in the aggregate');
  });

  test('the rendered report contains no prose either', () => {
    const text = formatReport([{ project: 'p', path: 'p', ...aggregate(lines) }]);
    assert.ok(!text.includes('SECRET'), 'no conversation text in the rendered report');
  });
});

describe('#5 — the project path comes from the recorded cwd, not a decoded slug', () => {
  // The directory slug flattens '/', '.' and literal '-' all to '-', so it cannot be
  // inverted: "--wsl-localhost-...-jobs-radar" reads equally as
  // ".../wsl.localhost/.../jobs-radar" or ".../wsl/localhost/.../jobs/radar". Every
  // transcript records the real cwd, so use the fact rather than guessing.
  test('reads cwd from the first line that carries one', () => {
    const lines = [
      JSON.stringify({ type: 'user' }),
      JSON.stringify({ type: 'assistant', cwd: '\\\\wsl.localhost\\ubuntu\\home\\thomas\\projects\\jobs-radar' }),
    ];
    assert.equal(projectPathFrom(lines), '\\\\wsl.localhost\\ubuntu\\home\\thomas\\projects\\jobs-radar');
  });

  test('a windows drive path survives verbatim', () => {
    assert.equal(projectPathFrom([JSON.stringify({ cwd: 'E:\\Claude\\Projects\\Sovary' })]), 'E:\\Claude\\Projects\\Sovary');
  });

  test('returns null when nothing records a cwd, so the caller can label the fallback', () => {
    assert.equal(projectPathFrom([JSON.stringify({ type: 'user' }), 'not json']), null);
  });
});

describe('#5 — the report splits per project rather than merging', () => {
  test('each project appears as its own section with its own totals', () => {
    const text = formatReport([
      { project: 'a', path: 'a', ...aggregate([assistant('opus-5', usage(100, 1))]) },
      { project: 'b', path: 'b', ...aggregate([assistant('opus-5', usage(200, 2))]) },
    ]);
    assert.match(text, /\ba\b/);
    assert.match(text, /\bb\b/);
    // Distinct totals present — not silently summed into one figure.
    assert.ok(text.includes('100') && text.includes('200'), 'per-project totals are reported separately');
  });
});
