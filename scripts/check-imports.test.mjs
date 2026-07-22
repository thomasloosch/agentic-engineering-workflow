#!/usr/bin/env node
/*
 * Tests for check-imports.mjs — the hallucinated-dependency / real-import guard
 * (issue #7, slice-2, G2). Language-agnostic core + per-ecosystem adapters; the
 * node adapter is the only one implemented. Each test asserts the guard's
 * VERDICT against fixture source + a package.json manifest.
 *
 * Contract under test:
 *   - An imported package NOT declared in package.json (deps/devDeps/etc.) is
 *     flagged (slopsquatting signal).
 *   - Declared dependency OR devDependency -> passes.
 *   - Node builtins (fs, path) incl. `node:`-prefixed -> ignored.
 *   - Relative ('./', '../') and path-aliased ('@/', '~/', '#') imports -> ignored.
 *   - Scoped packages (@scope/pkg) handled; @scope/pkg subpaths reduce to the pkg.
 *   - Subpath imports (pkg/sub) resolve against the top-level pkg.
 *   - require(), dynamic import(), and `export ... from` forms are all extracted.
 *   - No recognized manifest -> LOUD skip (visible), never a silent pass.
 *   - Fail-closed: a malformed manifest is a CHECKER ERROR (exit 2), distinct
 *     from a hallucinated-import finding (exit 1).
 */
import { mkdtempSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HERE = fileURLToPath(new URL('.', import.meta.url));
const CHECKER = join(HERE, 'check-imports.mjs');
const mod = await import('./check-imports.mjs');
const { nodeAdapter, findUndeclared } = mod;

let failed = 0;
function check(label, cond, detail = '') {
  process.stdout.write((cond ? '  ok  ' : '  XX  ') + label + (cond ? '' : '\n      ' + detail) + '\n');
  if (!cond) failed = 1;
}

function tmp() { return mkdtempSync(join(tmpdir(), 'ci-g2-')); }
function w(root, rel, body) {
  const p = join(root, rel);
  mkdirSync(join(p, '..'), { recursive: true });
  writeFileSync(p, body);
  return p;
}

process.stdout.write('[check-imports] node adapter\n');

// ── Unit: extractImports finds every import form with line numbers ──
{
  const src = [
    "import a from 'react'",                 // 1
    "import { b } from 'lodash'",            // 2
    "export { c } from 'undeclared-x'",      // 3
    "const d = require('express')",          // 4
    "const e = await import('dynamic-pkg')", // 5
    "import './local.js'",                   // 6 (relative, side-effect)
  ].join('\n');
  const specs = nodeAdapter.extractImports(src).map((i) => i.spec);
  check('extract: import/from', specs.includes('react') && specs.includes('lodash'), specs.join(','));
  check('extract: export-from', specs.includes('undeclared-x'), specs.join(','));
  check('extract: require()', specs.includes('express'), specs.join(','));
  check('extract: dynamic import()', specs.includes('dynamic-pkg'), specs.join(','));
}

// ── Unit: comments must not yield imports (the checker self-flagged on its own
//    source comments before this was fixed), and comment-stripping must be
//    string-aware so a '//' inside a string literal does not eat real code. ──
{
  const src = [
    "// import fake from 'commented-out-pkg'",
    "/* import blocked from 'block-comment-pkg' */",
    "/*\n * import multi from 'multiline-comment-pkg'\n */",
    "const u = 'http://example.com'; import real from 'real-pkg'",
  ].join('\n');
  const specs = nodeAdapter.extractImports(src).map((i) => i.spec);
  check('comments: line-comment import ignored', !specs.includes('commented-out-pkg'), specs.join(','));
  check('comments: block-comment import ignored', !specs.includes('block-comment-pkg'), specs.join(','));
  check('comments: multiline-comment import ignored', !specs.includes('multiline-comment-pkg'), specs.join(','));
  check('comments: // inside a string does not hide real code', specs.includes('real-pkg'), specs.join(','));
}

// ── Unit: regex literals containing quote chars must not desync the stripper.
//    /['"]/ would otherwise be read as an open string, leaving trailing
//    comments unstripped and leaking phantom imports. ──
{
  const src = [
    "const re = /['\"]/g;",
    "import real from 'realpkg'",
  ].join('\n');
  const specs = nodeAdapter.extractImports(src).map((i) => i.spec);
  check('regex literal with quotes: real import still found', specs.includes('realpkg'), specs.join(','));
  check('regex literal with quotes: no phantom specs', specs.length === 1, specs.join(','));
}
{
  const src = "const re = /['\"]/g; // import fake from 'phantom-pkg'\n";
  const specs = nodeAdapter.extractImports(src).map((i) => i.spec);
  check('regex literal then comment: comment still stripped', !specs.includes('phantom-pkg'), specs.join(','));
}
{
  // Division must not be mistaken for a regex literal.
  const src = "const r = a / b; const s = c / d;\nimport ok from 'divpkg'\n";
  const specs = nodeAdapter.extractImports(src).map((i) => i.spec);
  check('division not treated as regex', specs.includes('divpkg') && specs.length === 1, specs.join(','));
}
{
  // A regex preceded by a KEYWORD (not punctuation): `return /['"]/...`.
  // The punctuation-only heuristic read this as division, so the quotes inside
  // opened a string state and desynced the stripper.
  const src = [
    "function f(s) { return /['\"]/.test(s); }",
    "import real from 'kwpkg'",
  ].join('\n');
  const specs = nodeAdapter.extractImports(src).map((i) => i.spec);
  check('keyword-preceded regex (return): no desync', specs.includes('kwpkg') && specs.length === 1, specs.join(','));
}
{
  const src = "function f(s) { return /['\"]/.test(s); } // import fake from 'phantom-kw'\n";
  const specs = nodeAdapter.extractImports(src).map((i) => i.spec);
  check('keyword-preceded regex: trailing comment still stripped', !specs.includes('phantom-kw'), specs.join(','));
}
{
  // Other regex-preceding keywords must behave the same.
  const src = [
    "const a = typeof /['\"]/;",
    "switch (x) { case /['\"]/.source: break; }",
    "const b = await /['\"]/.exec(s);",
    "import real from 'kwpkg2'",
  ].join('\n');
  const specs = nodeAdapter.extractImports(src).map((i) => i.spec);
  check('keywords typeof/case/await before regex: no desync', specs.includes('kwpkg2') && specs.length === 1, specs.join(','));
}
{
  // An identifier merely ENDING in a keyword is still division, not a regex.
  const src = "const myreturn = a / b; const c = d / e;\nimport ok from 'idpkg'\n";
  const specs = nodeAdapter.extractImports(src).map((i) => i.spec);
  check('identifier ending in keyword -> still division', specs.includes('idpkg') && specs.length === 1, specs.join(','));
}

// ── Unit: line numbers survive comment stripping ──
{
  const src = "// import a from 'x'\n\nimport b from 'realpkg'\n";
  const got = nodeAdapter.extractImports(src).find((i) => i.spec === 'realpkg');
  check('comments: line numbers preserved after stripping', got && got.line === 3, JSON.stringify(got));
}

// ── Unit: packageName / classification helpers ──
check('pkgName: scoped subpath', nodeAdapter.packageName('@scope/pkg/sub') === '@scope/pkg');
check('pkgName: unscoped subpath', nodeAdapter.packageName('lodash/merge') === 'lodash');
check('pkgName: node: prefix stripped', nodeAdapter.packageName('node:fs') === 'fs');
check('builtin: fs', nodeAdapter.isBuiltin('fs'));
check('builtin: node:path', nodeAdapter.isBuiltin('node:path'));
check('builtin: fs/promises subpath', nodeAdapter.isBuiltin('fs/promises'));
check('builtin: real pkg is not builtin', !nodeAdapter.isBuiltin('react'));
check('relative: ./x', nodeAdapter.isRelativeOrAlias('./x'));
check('relative: ../y', nodeAdapter.isRelativeOrAlias('../y'));
check('alias: @/foo', nodeAdapter.isRelativeOrAlias('@/foo'));
check('alias: ~/bar', nodeAdapter.isRelativeOrAlias('~/bar'));
check('alias: #internal subpath', nodeAdapter.isRelativeOrAlias('#internal'));
check('alias: @scope/pkg is NOT an alias', !nodeAdapter.isRelativeOrAlias('@scope/pkg'));

// ── Unit: findUndeclared against a declared set ──
{
  const root = tmp();
  const declared = new Set(['react', 'lodash', '@scope/pkg']); // devDeps folded in by adapter elsewhere
  const f = w(root, 'app.js', [
    "import React from 'react'",             // declared -> ok
    "import merge from 'lodash/merge'",      // subpath of declared -> ok
    "import x from '@scope/pkg/sub'",        // scoped subpath of declared -> ok
    "import fake from 'totally-fake-pkg'",   // undeclared -> FLAG
    "import fs from 'node:fs'",              // builtin -> ok
    "import rel from './rel.js'",            // relative -> ok
    "import al from '@/aliased'",            // alias -> ok
  ].join('\n'));
  const hits = findUndeclared([f], nodeAdapter, declared);
  check('undeclared pkg -> flagged', hits.some((h) => h.name === 'totally-fake-pkg'), hits.map((h) => h.name).join(','));
  check('declared/subpath/scoped/builtin/relative/alias -> not flagged',
    hits.length === 1, 'unexpected: ' + hits.map((h) => h.name).join(','));
  rmSync(root, { recursive: true, force: true });
}

// ── Unit: declaredPackages folds devDependencies in ──
{
  const declared = nodeAdapter.declaredPackages({
    dependencies: { react: '^18' },
    devDependencies: { vitest: '^1' },
    optionalDependencies: { fsevents: '*' },
    peerDependencies: { eslint: '*' },
  });
  check('declared: deps + devDeps + optional + peer', ['react', 'vitest', 'fsevents', 'eslint'].every((n) => declared.has(n)));
}

// ── Integration (CLI): exit codes ──
function cli(root, args) {
  try {
    const out = execFileSync('node', [CHECKER, ...args], { cwd: root, encoding: 'utf8' });
    return { code: 0, out };
  } catch (e) {
    return { code: e.status, out: (e.stdout || '') + (e.stderr || '') };
  }
}

// clean node project -> exit 0
{
  const root = tmp();
  w(root, 'package.json', JSON.stringify({ dependencies: { react: '^18' } }));
  w(root, 'src/app.js', "import React from 'react'\nimport fs from 'node:fs'\n");
  const r = cli(root, ['src']);
  check('CLI: clean node project -> exit 0', r.code === 0, `code=${r.code} out=${r.out}`);
  rmSync(root, { recursive: true, force: true });
}

// fabricated import -> exit 1
{
  const root = tmp();
  w(root, 'package.json', JSON.stringify({ dependencies: { react: '^18' } }));
  w(root, 'src/app.js', "import x from 'slopsquatted-xyz'\n");
  const r = cli(root, ['src']);
  check('CLI: fabricated import -> exit 1', r.code === 1, `code=${r.code} out=${r.out}`);
  check('CLI: names the offending package', /slopsquatted-xyz/.test(r.out), r.out);
  rmSync(root, { recursive: true, force: true });
}

// no manifest -> LOUD skip, exit 0
{
  const root = tmp();
  w(root, 'src/app.js', "import x from 'anything'\n");
  const r = cli(root, ['src']);
  check('CLI: no adapter -> exit 0 (loud skip, not a silent pass)', r.code === 0, `code=${r.code}`);
  check('CLI: skip is visible in output', /SKIP/i.test(r.out) && /no adapter|no .*manifest|ecosystem/i.test(r.out), r.out);
  rmSync(root, { recursive: true, force: true });
}

// zero source files scanned -> LOUD, never a quiet exit 0 that reads as "clean"
{
  const root = tmp();
  w(root, 'package.json', JSON.stringify({ dependencies: {} }));
  const r = cli(root, ['does-not-exist']);
  check('CLI: no files scanned -> says so loudly', /NO SOURCE FILES|no source files/i.test(r.out),
    `code=${r.code} out=${r.out}`);
  rmSync(root, { recursive: true, force: true });
}

// malformed manifest -> CHECKER ERROR exit 2 (distinct from a finding)
{
  const root = tmp();
  w(root, 'package.json', '{ this is not valid json ');
  w(root, 'src/app.js', "import x from 'react'\n");
  const r = cli(root, ['src']);
  check('CLI: malformed manifest -> exit 2 (CHECKER ERROR)', r.code === 2, `code=${r.code} out=${r.out}`);
  check('CLI: error message is distinct from a finding', /CHECKER ERROR/.test(r.out) && !/HALLUCINATED/.test(r.out), r.out);
  rmSync(root, { recursive: true, force: true });
}

process.stdout.write('\n' + (failed ? 'SOME RED' : 'ALL GREEN') + '\n');
process.exit(failed);
