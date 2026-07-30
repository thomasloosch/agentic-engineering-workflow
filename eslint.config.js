'use strict';

// Flat config for the workflow repo's own JS (issue #13 — the repo that publishes
// Engineering Standard 1, "lint clean before commit," had nothing to run).
//
// Two source types live here and must not be linted under one set of assumptions:
//   - .claude/tdd/*.js       CommonJS (the gate, bootstrapped into projects that
//                            require() it — its module form is not a free choice)
//   - scripts/*.mjs          ESM (import.meta.url, top-level await)
//
// Rules mirror the ones this repo distributes to projects (see jobs-radar's
// eslint.config.js) so the standard we publish is the standard we hold ourselves to.

const sharedRules = {
  'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
  'no-console': 'off', // these are CLI tools; console IS the output surface
  semi: ['error', 'always'],
  'no-var': 'error',
  'prefer-const': 'error',
};

const nodeGlobals = {
  process: 'readonly',
  console: 'readonly',
  Buffer: 'readonly',
  URL: 'readonly',
  TextEncoder: 'readonly',
  TextDecoder: 'readonly',
  setTimeout: 'readonly',
  clearTimeout: 'readonly',
  globalThis: 'readonly',
};

module.exports = [
  {
    // Never lint dependencies or the transient agent worktrees.
    ignores: ['node_modules/**', '.claude/worktrees/**'],
  },
  {
    files: ['**/*.js'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'commonjs',
      globals: {
        ...nodeGlobals,
        require: 'readonly',
        module: 'writable',
        exports: 'writable',
        __dirname: 'readonly',
        __filename: 'readonly',
      },
    },
    rules: sharedRules,
  },
  {
    files: ['**/*.mjs'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: nodeGlobals,
    },
    rules: sharedRules,
  },
];
