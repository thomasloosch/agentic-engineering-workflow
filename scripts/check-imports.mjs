#!/usr/bin/env node
/*
 * Hallucinated-dependency / real-import guard (issue #7, slice-2, G2).
 *
 * Flags source that imports a package NOT declared in the project's dependency
 * manifest — the slopsquatting signal: an LLM invents a plausible package name
 * and imports it. Deterministic and offline (no install needed): "declared in
 * the manifest" is the ground truth for "this dependency is real and intended".
 *
 * ARCHITECTURE — language-agnostic core + per-ecosystem ADAPTERS. The core does:
 *   extract imports -> drop builtins + relative/local -> assert each remaining
 *   package is declared in the manifest -> report.
 * Only three things are language-specific and live in an adapter: import syntax,
 * the builtin list, and the manifest location/format. The ECOSYSTEM IS DETECTED
 * PER-PROJECT from which manifest is present, because bootstrap propagates this
 * guard into new projects — a future non-Node project must not inherit a Node
 * checker that silently finds nothing.
 *
 * NO-ADAPTER CASE IS LOUD, never a silent pass: if no recognized manifest is
 * found, the run reports "SKIPPED — no adapter for this ecosystem" as a visible
 * outcome. A propagated guard that silently passes on an unsupported project is
 * the ADR-0002 dormant-hook false-confidence trap.
 *
 * Only the node adapter is implemented. Adding python/go is the seam's job when
 * the first real project in that language appears — not speculatively.
 *
 * Exit codes: 0 clean OR loud-skip · 1 finding(s) · 2 checker error (fail-closed).
 * Usage: node scripts/check-imports.mjs <file-or-dir> [<file-or-dir> ...]
 */
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, extname } from 'node:path';
import { builtinModules } from 'node:module';
import { fileURLToPath } from 'node:url';

const BUILTINS = new Set(builtinModules);

// Never scanned: dependency trees and build output import packages in ways that
// are not the project's own source (a bundle re-imports everything), and
// .claude/ holds this workflow's own tooling — all pure false-positive sources.
const IGNORED_DIRS = new Set([
  'node_modules', '.git', '.claude', 'dist', 'build', 'coverage', '.next', 'out',
]);

// A '/' following one of these (or at start of input) begins a regex literal
// rather than a division — the standard prev-token heuristic.
const REGEX_PREV = new Set([
  '', '(', ',', '=', ':', '[', '!', '&', '|', '?', '{', '}', ';', '+', '-', '*', '%', '~', '^', '<', '>', '\n',
]);

// Keywords that can precede a regex literal: `return /re/`, `typeof /re/`.
// Without these the punctuation-only check reads `return /['"]/` as division,
// desyncing the stripper so a trailing comment survives and leaks phantom
// imports. Matched as whole words, so `myreturn / x` stays division.
const REGEX_PREV_KEYWORDS = new Set([
  'return', 'typeof', 'instanceof', 'in', 'of', 'new', 'delete', 'void',
  'throw', 'case', 'do', 'else', 'yield', 'await',
]);

// ─── Node adapter ─────────────────────────────────────────────────────────────
export const nodeAdapter = {
  name: 'node',
  manifestFile: 'package.json',
  extensions: new Set(['.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs', '.mts', '.cts']),

  // Blank out comments so commented-out imports are not reported (the checker
  // used to flag the import syntax inside its OWN comments). String-aware: a
  // '//' inside a string literal must not start a comment. Newlines are kept so
  // reported line numbers stay accurate.
  // Does the '/' at index i begin a regex literal (vs. division)? Punctuation
  // before it is the common case; a preceding KEYWORD (`return /re/`) is the
  // one the punctuation-only heuristic got wrong. Whole-word match, so an
  // identifier merely ending in a keyword (`myreturn / x`) stays division.
  startsRegexLiteral(src, i, lastSig) {
    if (REGEX_PREV.has(lastSig)) return true;
    let j = i - 1;
    while (j >= 0 && /\s/.test(src[j])) j--;
    const end = j + 1;
    while (j >= 0 && /[A-Za-z_$]/.test(src[j])) j--;
    return REGEX_PREV_KEYWORDS.has(src.slice(j + 1, end));
  },

  stripComments(src) {
    let out = '';
    let state = 'code'; // code | line | block | single | double | template | regex
    let lastSig = '';   // last non-whitespace code char, for regex-vs-division
    let inClass = false;
    for (let i = 0; i < src.length; i++) {
      const c = src[i], n = src[i + 1];
      if (state === 'code') {
        if (c === '/' && n === '/') { state = 'line'; out += '  '; i++; continue; }
        if (c === '/' && n === '*') { state = 'block'; out += '  '; i++; continue; }
        // A '/' after an operator/opening bracket starts a REGEX literal, not
        // division. Quotes inside one (e.g. /['"]/) must not open a string, or
        // the stripper desyncs and later comments survive unstripped.
        if (c === '/' && this.startsRegexLiteral(src, i, lastSig)) { state = 'regex'; inClass = false; out += c; continue; }
        if (c === "'") state = 'single';
        else if (c === '"') state = 'double';
        else if (c === '`') state = 'template';
        out += c;
        if (!/\s/.test(c)) lastSig = c;
        continue;
      }
      if (state === 'regex') {
        out += c;
        if (c === '\\') { if (i + 1 < src.length) { out += src[i + 1]; i++; } continue; }
        if (c === '\n') { state = 'code'; continue; }   // regex cannot span lines
        if (c === '[') inClass = true;
        else if (c === ']') inClass = false;
        else if (c === '/' && !inClass) { state = 'code'; lastSig = '/'; }
        continue;
      }
      if (state === 'line') {
        if (c === '\n') { state = 'code'; out += c; } else out += ' ';
        continue;
      }
      if (state === 'block') {
        if (c === '*' && n === '/') { state = 'code'; out += '  '; i++; }
        else out += c === '\n' ? '\n' : ' ';
        continue;
      }
      // inside a string literal
      out += c;
      if (c === '\\') { if (i + 1 < src.length) { out += src[i + 1]; i++; } continue; }
      if ((state === 'single' && c === "'") || (state === 'double' && c === '"') ||
          (state === 'template' && c === '`')) state = 'code';
    }
    return out;
  },

  // Every specifier-bearing import form, with 1-based line numbers.
  extractImports(rawSource) {
    const source = this.stripComments(rawSource);
    const patterns = [
      /\b(?:import|export)\b[^'"]*?\bfrom\s*['"]([^'"]+)['"]/g, // import/export ... from 'x'
      /\bimport\s*['"]([^'"]+)['"]/g,                          // import 'x' (side-effect)
      /\bimport\s*\(\s*['"]([^'"]+)['"]\s*\)/g,                // dynamic import('x')
      /\brequire\s*\(\s*['"]([^'"]+)['"]\s*\)/g,               // require('x')
    ];
    const seen = new Set();
    const out = [];
    for (const re of patterns) {
      let m;
      while ((m = re.exec(source)) !== null) {
        const spec = m[1];
        const line = source.slice(0, m.index).split('\n').length;
        const key = line + '\0' + spec;
        if (!seen.has(key)) { seen.add(key); out.push({ line, spec }); }
      }
    }
    return out;
  },

  // Relative paths and path-aliases / package-internal subpaths — never a
  // published package. '@/x' and '~/x' are aliases; '@scope/pkg' is NOT.
  isRelativeOrAlias(spec) {
    return (
      spec === '.' || spec === '..' ||
      /^\.\.?\//.test(spec) || spec.startsWith('/') ||
      spec.startsWith('@/') || spec.startsWith('~/') || spec === '~' ||
      spec.startsWith('#')
    );
  },

  isBuiltin(spec) {
    if (spec.startsWith('node:')) return true;
    return BUILTINS.has(this.packageName(spec));
  },

  // Reduce a specifier to its installable package name.
  packageName(spec) {
    let s = spec.startsWith('node:') ? spec.slice(5) : spec;
    if (s.startsWith('@')) {
      const parts = s.split('/');
      return parts.length >= 2 ? parts[0] + '/' + parts[1] : s; // @scope/pkg
    }
    return s.split('/')[0]; // pkg from pkg/sub/path
  },

  // Declared = every dependency field, so a devDependency counts as declared.
  declaredPackages(manifest) {
    const fields = ['dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies'];
    const set = new Set();
    for (const f of fields) {
      if (manifest[f] && typeof manifest[f] === 'object') {
        for (const k of Object.keys(manifest[f])) set.add(k);
      }
    }
    return set;
  },

  loadDeclared(root) {
    const raw = readFileSync(join(root, this.manifestFile), 'utf8');
    return this.declaredPackages(JSON.parse(raw)); // JSON.parse throws -> caught as CHECKER ERROR
  },
};

const ADAPTERS = [nodeAdapter];

// ─── Language-agnostic core ───────────────────────────────────────────────────
export function detectAdapter(root) {
  for (const a of ADAPTERS) {
    if (existsSync(join(root, a.manifestFile))) return a;
  }
  return null;
}

export function collectFiles(paths, extensions) {
  const out = [];
  const walk = (p) => {
    let st;
    try { st = statSync(p); } catch { return; }
    if (st.isDirectory()) {
      for (const e of readdirSync(p)) {
        if (IGNORED_DIRS.has(e)) continue;
        walk(join(p, e));
      }
    } else if (extensions.has(extname(p))) {
      out.push(p);
    }
  };
  for (const p of paths) walk(p);
  return out;
}

export function findUndeclared(files, adapter, declared) {
  const findings = [];
  for (const file of files) {
    let source;
    try {
      source = readFileSync(file, 'utf8');
    } catch (err) {
      findings.push({ file, line: 0, name: file, reason: `cannot read (fail-closed): ${err.message}` });
      continue;
    }
    for (const { line, spec } of adapter.extractImports(source)) {
      if (adapter.isRelativeOrAlias(spec) || adapter.isBuiltin(spec)) continue;
      const name = adapter.packageName(spec);
      if (!declared.has(name)) {
        findings.push({ file, line, name, reason: 'not declared in the dependency manifest' });
      }
    }
  }
  return findings;
}

// ─── CLI ──────────────────────────────────────────────────────────────────────
export function run(argv, cwd) {
  if (!argv.length) {
    process.stderr.write('check-imports: CHECKER ERROR — no paths given\n');
    return 2;
  }
  const adapter = detectAdapter(cwd);
  if (!adapter) {
    // LOUD skip — visible outcome, never a silent pass.
    process.stdout.write(
      'check-imports: SKIPPED — no adapter for this ecosystem (no recognized ' +
      'dependency manifest found in ' + cwd + '). This is NOT a pass: there is ' +
      'no manifest to check imports against.\n');
    return 0;
  }

  let declared;
  try {
    declared = adapter.loadDeclared(cwd);
  } catch (err) {
    process.stderr.write(
      `check-imports: CHECKER ERROR — could not read/parse ${adapter.manifestFile}: ` +
      `${err.message}. This is a tooling failure, not a hallucinated import.\n`);
    return 2;
  }

  const files = collectFiles(argv, adapter.extensions);
  if (!files.length) {
    // Never let "scanned nothing" masquerade as "found nothing wrong".
    process.stdout.write(
      `check-imports: NO SOURCE FILES matched ${JSON.stringify(argv)} [${adapter.name}]. ` +
      'Nothing was checked — verify the paths passed to the guard.\n');
    return 0;
  }

  const findings = findUndeclared(files, adapter, declared);
  if (!findings.length) return 0;

  for (const f of findings) {
    process.stderr.write(
      `check-imports: HALLUCINATED IMPORT — ${f.file}:${f.line}: '${f.name}' ${f.reason}\n`);
  }
  process.stderr.write(
    `check-imports: ${findings.length} finding(s) [${adapter.name}]. If a package ` +
    `is real, declare it in ${adapter.manifestFile} so this passes.\n`);
  return 1;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  process.exit(run(process.argv.slice(2), process.cwd()));
}
