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
  tokens: { input: 0, output: 0, cacheCreate: 0, cacheRead: 0 },
  models: {},
  tools: {},
  firstSeen: null,
  lastSeen: null,
});

/** Fold raw JSONL lines into metrics. Pure — no IO, so it is directly testable. */
export function aggregate(lines, acc = emptyTotals()) {
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

function readProject(dir) {
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
    aggregate(lines, acc);
  }
  return { ...acc, cwd };
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
