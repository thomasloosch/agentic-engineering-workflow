#!/usr/bin/env node
//
// observe.mjs — run-level observability (issue #5).
//
// Claude Code already writes a complete trace of every session to
// ~/.claude/projects/<slug>/*.jsonl: tool calls in order, per-turn token usage,
// model, timestamps, API errors. #5 asked for "a log/trace file + small
// summarizer" — the trace file exists, so this is only the summarizer. It
// instruments nothing and writes nothing.
//
//   npm run observe             this project
//   npm run observe -- --all    every project, SPLIT per project
//   npm run observe -- --json   machine-readable
//
// Two deliberate limits, both stated in output rather than papered over:
//   - TOKENS, NOT COST. Cost needs a per-model price table, which drifts silently
//     and would be wrong-but-confident. Multiply externally.
//   - NO LATENCY. Per-request duration is not recorded. Only wall-clock gaps
//     exist, and they include human think time, so calling them latency would be
//     a number that looks meaningful and isn't.
//
// PRIVACY: transcripts hold full conversation text. This reads it and emits
// METRICS ONLY — never prose, tool arguments, or file contents. Asserted in
// observe.test.mjs, not merely intended.

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const PROJECTS_DIR = path.join(os.homedir(), '.claude', 'projects');

// The directory name is a slug of the project path with every separator and dot
// flattened to '-', which is NOT invertible: '-' may have been '/', '.', or a
// literal '-'. ("--wsl-localhost-...-jobs-radar" decodes equally well to
// "wsl.localhost/.../jobs-radar" and "wsl/localhost/.../jobs/radar".) So do not
// decode it — every transcript records the real `cwd`, which is authoritative.
// Returns null when no line carries one, and the caller falls back to the slug.
export function projectPathFrom(lines) {
  for (const line of lines) {
    if (!line) continue;
    try {
      const o = JSON.parse(line);
      if (o.cwd) return o.cwd;
    } catch { /* skip: the aggregate pass counts unparsable lines */ }
  }
  return null;
}

const emptyTotals = () => ({
  sessions: 0,
  assistantTurns: 0,
  sidechainTurns: 0,
  apiErrors: 0,
  unparsableLines: 0,
  undatedTurns: 0,
  tokens: { input: 0, output: 0, cacheCreate: 0, cacheRead: 0 },
  models: {},
  tools: {},
  firstSeen: null,
  lastSeen: null,
});

/**
 * Fold raw JSONL lines into metrics. Pure — no IO, so it is directly testable.
 *
 * opts.since / opts.until (epoch ms) bound which turns count, so a before/after
 * delta is readable. #8's first acceptance criterion is "frontier share drops",
 * which a cumulative total cannot answer — every turn ever recorded lands in one
 * bucket. Shipping that criterion against a totals-only tool made it unverifiable
 * by construction; this is the fix.
 */
export function aggregate(lines, acc = emptyTotals(), opts = {}) {
  const bounded = typeof opts.since === 'number' || typeof opts.until === 'number';

  for (const line of lines) {
    if (!line) continue;
    let o;
    try {
      o = JSON.parse(line);
    } catch {
      // Fail loud-but-continue: a truncated trailing line (the session still being
      // written) must not take the whole report down, but a silently dropped line
      // would make the totals quietly wrong. Counted and surfaced.
      acc.unparsableLines++;
      continue;
    }

    if (o.timestamp) {
      if (!acc.firstSeen || o.timestamp < acc.firstSeen) acc.firstSeen = o.timestamp;
      if (!acc.lastSeen || o.timestamp > acc.lastSeen) acc.lastSeen = o.timestamp;
    }

    // Window filter. An undated turn cannot be placed on either side of a cutoff,
    // so it is excluded from BOTH halves — and counted, because dropping it
    // silently would make the halves quietly fail to sum to the whole.
    if (bounded) {
      const t = o.timestamp ? Date.parse(o.timestamp) : NaN;
      if (Number.isNaN(t)) {
        if (o.type === 'assistant' && o.message) acc.undatedTurns++;
        continue;
      }
      if (typeof opts.since === 'number' && t < opts.since) continue;
      if (typeof opts.until === 'number' && t >= opts.until) continue;
    }

    if (o.isApiErrorMessage) acc.apiErrors++;
    if (o.type !== 'assistant' || !o.message) continue;

    acc.assistantTurns++;
    if (o.isSidechain) acc.sidechainTurns++;
    if (o.message.model) acc.models[o.message.model] = (acc.models[o.message.model] || 0) + 1;

    const u = o.message.usage;
    if (u) {
      acc.tokens.input += u.input_tokens || 0;
      acc.tokens.output += u.output_tokens || 0;
      acc.tokens.cacheCreate += u.cache_creation_input_tokens || 0;
      acc.tokens.cacheRead += u.cache_read_input_tokens || 0;
    }
    // Tool NAMES only. `input` is deliberately never read — it carries command
    // strings, file paths and payloads, which is exactly what must not leak.
    if (Array.isArray(o.message.content)) {
      for (const c of o.message.content) {
        if (c.type === 'tool_use' && c.name) acc.tools[c.name] = (acc.tools[c.name] || 0) + 1;
      }
    }
  }
  return acc;
}

function readProject(dir, opts = {}) {
  const acc = emptyTotals();
  let cwd = null;
  let files = [];
  try {
    files = fs.readdirSync(dir).filter((f) => f.endsWith('.jsonl'));
  } catch {
    return { ...acc, unreadable: true };
  }
  for (const f of files) {
    let raw;
    try {
      raw = fs.readFileSync(path.join(dir, f), 'utf8');
    } catch {
      acc.unparsableLines++; // unreadable session: surfaced, never a silent zero
      continue;
    }
    acc.sessions++;
    const lines = raw.split('\n');
    if (!cwd) cwd = projectPathFrom(lines);
    aggregate(lines, acc, opts);
  }
  return { ...acc, cwd };
}

// Tier split for the routing question (#8): which turns ran on the expensive tier.
// Matched on the model id rather than a hardcoded list, so a new Opus/Sonnet/Haiku
// release is classified correctly without editing this file.
const TIERS = [
  ['frontier', /opus|fable|mythos/i],
  ['sonnet', /sonnet/i],
  ['haiku', /haiku/i],
];

/**
 * Delegation count, from the PARENT transcript's tool calls.
 *
 * Subagent turns are not recorded anywhere: `isSidechain` is 0 across every
 * project, and no transcript exists outside ~/.claude/projects. So a delegated
 * Haiku run contributes zero model turns and is invisible to a tier count —
 * which made "Haiku stops being zero" unsatisfiable as written, not merely unmet.
 * The Agent/Task tool call in the parent IS recorded, so it is the honest proxy
 * for "delegation happened".
 */
export function delegationCount(tools) {
  return (tools.Agent || 0) + (tools.Task || 0);
}

export function tierCounts(models) {
  const out = { frontier: 0, sonnet: 0, haiku: 0, other: 0 };
  for (const [id, n] of Object.entries(models)) {
    const hit = TIERS.find(([, re]) => re.test(id));
    out[hit ? hit[0] : 'other'] += n;
  }
  return out;
}

const share = (part, total) => (total ? `${((part / total) * 100).toFixed(1)}%` : '—');

/** Before/after rendering for a cutoff run — the shape #8's criterion 1 needs. */
export function formatDelta(rows, label) {
  const out = [`Routing delta — cutoff ${label}`, ''];
  for (const r of rows) {
    const b = tierCounts(r.before.models);
    const a = tierCounts(r.after.models);
    const bt = b.frontier + b.sonnet + b.haiku + b.other;
    const at = a.frontier + a.sonnet + a.haiku + a.other;
    out.push(`── ${r.path}`);
    out.push(`   ${'turns'.padEnd(10)} before ${String(bt).padStart(6)}      after ${String(at).padStart(6)}`);
    out.push(`   ${'frontier'.padEnd(10)} ${String(b.frontier).padStart(6)} ${share(b.frontier, bt).padStart(7)}  ${String(a.frontier).padStart(6)} ${share(a.frontier, at).padStart(7)}`);
    out.push(`   ${'sonnet'.padEnd(10)} ${String(b.sonnet).padStart(6)} ${share(b.sonnet, bt).padStart(7)}  ${String(a.sonnet).padStart(6)} ${share(a.sonnet, at).padStart(7)}`);
    out.push(`   ${'haiku'.padEnd(10)} ${String(b.haiku).padStart(6)} ${share(b.haiku, bt).padStart(7)}  ${String(a.haiku).padStart(6)} ${share(a.haiku, at).padStart(7)}`);
    out.push(`   ${'delegations'.padEnd(10)} ${String(delegationCount(r.before.tools)).padStart(6)}          ${String(delegationCount(r.after.tools)).padStart(6)}`);
    const undated = r.before.undatedTurns + r.after.undatedTurns;
    if (undated) out.push(`   NOTE       ${undated} undated turn(s) in neither half`);
    out.push('');
  }
  out.push('Subagent turns are NOT recorded — a delegated Haiku run contributes zero');
  out.push('model turns, so the tier rows measure MAIN-THREAD routing only. The');
  out.push('delegations row (parent-side Agent/Task calls) is what shows lever B.');
  out.push('');
  out.push('And a cutoff only splits recorded turns — it cannot show whether delegated');
  out.push('output held up under review. Judge that separately.');
  return out.join('\n');
}

// Accept a date or a git commit-ish. A sha is resolved against THIS repo, which is
// the common case (comparing against the commit that changed the config).
function resolveCutoff(value) {
  if (/^\d{4}-\d{2}-\d{2}/.test(value)) {
    const t = Date.parse(value.length === 10 ? `${value}T00:00:00Z` : value);
    if (!Number.isNaN(t)) return { ms: t, label: value };
  }
  try {
    const iso = execFileSync('git', ['show', '-s', '--format=%cI', value], {
      cwd: path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..'),
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    const t = Date.parse(iso);
    if (!Number.isNaN(t)) return { ms: t, label: `${value} (${iso})` };
  } catch { /* fall through to the error below */ }
  return null;
}

const n = (x) => x.toLocaleString('en-US');
const day = (ts) => (ts ? ts.slice(0, 10) : '—');

const top = (obj, limit = 8) => Object.entries(obj)
  .sort((a, b) => b[1] - a[1]).slice(0, limit)
  .map(([k, v]) => `${k}:${v}`).join('  ') || '—';

/** Render per-project sections. Never merged into a single total — each project's
 *  health is its own question (#5 D3). */
export function formatReport(projects) {
  const out = [];
  for (const p of projects) {
    out.push(`── ${p.project}`);
    out.push(`   ${p.path}`);
    if (p.unreadable) {
      out.push('   UNREADABLE — directory could not be listed', '');
      continue;
    }
    out.push(`   sessions ${p.sessions}   ${day(p.firstSeen)} → ${day(p.lastSeen)}`);
    out.push(`   turns    ${n(p.assistantTurns)} assistant`
      + (p.sidechainTurns ? `  (${n(p.sidechainTurns)} subagent)` : '')
      + (p.apiErrors ? `   api-errors ${p.apiErrors}` : ''));
    out.push(`   tokens   in ${n(p.tokens.input)}   out ${n(p.tokens.output)}`);
    out.push(`            cache-create ${n(p.tokens.cacheCreate)}   cache-read ${n(p.tokens.cacheRead)}`);
    out.push(`   models   ${top(p.models)}`);
    out.push(`   tools    ${top(p.tools)}`);
    if (p.unparsableLines) out.push(`   NOTE     ${p.unparsableLines} unparsable line(s) skipped`);
    out.push('');
  }
  out.push('tokens only — no cost (a price table drifts silently; multiply externally).');
  out.push('no latency — per-request duration is not recorded; wall-clock gaps include think time.');
  return out.join('\n');
}

// Identify this project by comparing the RECORDED cwd of each transcript set against
// the real cwd — not by re-deriving the slug, which cannot be done reliably in either
// direction. Comparison is case- and separator-insensitive because the same project is
// reached as both `\\wsl.localhost\...` and `//wsl.localhost/...` in this runtime.
const canon = (p) => p.replace(/\\/g, '/').replace(/\/+$/, '').toLowerCase();

function currentSlug() {
  const here = canon(process.cwd());
  for (const d of fs.readdirSync(PROJECTS_DIR)) {
    const dir = path.join(PROJECTS_DIR, d);
    if (!fs.statSync(dir).isDirectory()) continue;
    const f = fs.readdirSync(dir).find((x) => x.endsWith('.jsonl'));
    if (!f) continue;
    let recorded = null;
    try {
      recorded = projectPathFrom(fs.readFileSync(path.join(dir, f), 'utf8').split('\n'));
    } catch { continue; }
    if (recorded && canon(recorded) === here) return d;
  }
  return null;
}

function main(argv) {
  if (!fs.existsSync(PROJECTS_DIR)) {
    console.error(`no transcripts directory at ${PROJECTS_DIR} — nothing to observe`);
    return 1;
  }
  const all = argv.includes('--all');
  const asJson = argv.includes('--json');
  const sinceArg = (argv.find((a) => a.startsWith('--since=')) || '').slice(8);

  let cutoff = null;
  if (sinceArg) {
    cutoff = resolveCutoff(sinceArg);
    if (!cutoff) {
      console.error(`--since=${sinceArg} is neither a date (YYYY-MM-DD) nor a commit in this repo`);
      return 1;
    }
  }

  let slugs;
  if (all) {
    slugs = fs.readdirSync(PROJECTS_DIR)
      .filter((d) => fs.statSync(path.join(PROJECTS_DIR, d)).isDirectory());
  } else {
    const slug = currentSlug();
    if (!slug) {
      console.error(`no transcripts found for ${process.cwd()} — try --all`);
      return 1;
    }
    slugs = [slug];
  }

  if (cutoff) {
    const rows = slugs
      .map((s) => {
        const dir = path.join(PROJECTS_DIR, s);
        const before = readProject(dir, { until: cutoff.ms });
        const after = readProject(dir, { since: cutoff.ms });
        return { project: s, path: before.cwd || after.cwd || s, before, after };
      })
      .filter((r) => r.before.assistantTurns > 0 || r.after.assistantTurns > 0)
      .sort((a, b) => b.after.assistantTurns - a.after.assistantTurns);

    if (rows.length === 0) { console.error('no sessions found'); return 1; }
    console.log(asJson ? JSON.stringify(rows, null, 2) : formatDelta(rows, cutoff.label));
    return 0;
  }

  const projects = slugs
    .map((s) => {
      const r = readProject(path.join(PROJECTS_DIR, s));
      // Fall back to the slug only when no transcript recorded a cwd — labelled, so
      // an approximate identity is never mistaken for the real path.
      return { project: s, path: r.cwd || `${s} (slug — no cwd recorded)`, ...r };
    })
    .filter((p) => p.sessions > 0 || p.unreadable)
    .sort((a, b) => b.tokens.output - a.tokens.output);

  if (projects.length === 0) {
    console.error('no sessions found');
    return 1;
  }

  console.log(asJson ? JSON.stringify(projects, null, 2) : formatReport(projects));
  return 0;
}

// Only run when executed directly, so the test can import the pure functions.
if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.endsWith('observe.mjs')) {
  process.exit(main(process.argv.slice(2)));
}
