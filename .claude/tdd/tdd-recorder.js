'use strict';

// VALIDITY BOUNDARY — node v24, default process isolation.
// This recorder's correctness rests on one observed node behaviour: a real
// module-load failure (`Cannot find module`, a syntax error, any load-time
// throw) aborts the test file BEFORE any test:pass/test:fail event reaches
// this reporter. Verified on node v24 with default process isolation (each
// test file runs in its own child process). Because load failures emit no
// per-test event, the recorder needs no basename-based "module-load-as-fail"
// filter — an earlier such filter was removed; it false-dropped real tests
// named like their file.
//   Build-loop consequence: the implementation stub must EXIST and EXPORT
//   before the first red run, or the red is never recorded and the later
//   green reads as a (false) test-after.
//   Re-verify if a future node changes this — e.g. in-process test execution,
//   or --test-isolation=none becoming the default — since load failures could
//   then surface as events and this assumption would no longer hold.

const fs = require('node:fs');
const path = require('node:path');

function createRecorder(opts = {}) {
  const cwd = (opts.cwd || process.cwd()).replace(/\\/g, '/');
  const seen = new Set(); // keys logged this run — repeat = leaf-name collision

  function rel(file) {
    return path.posix.relative(cwd, String(file).replace(/\\/g, '/'));
  }

  function handle(event, now) {
    const { type, data } = event;
    if (type !== 'test:pass' && type !== 'test:fail') return [];
    if (!data || !data.file || data.name == null) return [];

    // Drop describe/suite aggregates — only leaf tests are per-test results.
    if (!data.details || data.details.type !== 'test') return [];

    // Skipped / todo tests surface as test:pass (node sets data.skip / data.todo)
    // but are not real green outcomes — recording them as pass would pollute the
    // signal (a skipped test reads as a first-seen pass, i.e. a false test-after).
    if (data.skip || data.todo) return [];

    // Note: a real module-load failure never reaches here — node aborts the file
    // at load and emits no per-test pass/fail event (verified on node v24 with
    // default process isolation), so no basename-based drop is needed.

    const status = type === 'test:pass' ? 'pass' : 'fail';
    const key = `${rel(data.file)}::${data.name}`;

    // Fields are TAB-delimited so a test name may contain spaces without the
    // detector's outcome column drifting onto a word of the name. The detector's
    // parser must split on the same TAB. The COLLISION diagnostic keeps the key
    // in the (file::name) column so it has no pass/fail outcome — the detector
    // drops it as a non-record line.
    const out = [];
    if (seen.has(key)) {
      out.push(`${now}\tCOLLISION\t${key}\t(leaf-name collision; describe-ancestry needed to disambiguate)`);
    } else {
      seen.add(key);
    }
    out.push(`${now}\t${key}\t${status}`);
    return out;
  }

  return { handle };
}

// The node --test reporter entry point. Consumes the event stream, runs each
// event through the tested handle(), and appends log lines to the session log.
// It yields nothing (output is the side-effect file), so it can run alongside a
// human-readable reporter on stdout without disturbing it. The log path is the
// project's gitignored .claude/logs/tdd-session.log (override with TDD_LOG).
// Append to the log without ever throwing: a logging failure must not break the
// caller's `npm test`. On failure, warn to stderr and continue (exit stays 0).
function appendSafe(logPath, text) {
  try {
    fs.mkdirSync(path.dirname(logPath), { recursive: true });
    fs.appendFileSync(logPath, text);
    return true;
  } catch (err) {
    process.stderr.write(
      `[tdd-recorder] log write failed (${err.code || err.message}); continuing without TDD logging\n`,
    );
    return false;
  }
}

async function* reporter(source) {
  // Opt-in: only a TDD session records. `npm run tdd` sets TDD_RECORD; routine
  // `npm test` leaves it unset → we drain the stream but write nothing, so an
  // ordinary all-green run never pollutes the log the detector judges.
  const recording = Boolean(process.env.TDD_RECORD);
  const projectDir = process.env.CLAUDE_PROJECT_DIR || process.cwd();
  const logPath = process.env.TDD_LOG
    || path.join(projectDir, '.claude', 'logs', 'tdd-session.log');

  const { handle } = createRecorder({ cwd: projectDir });
  for await (const event of source) {
    if (!recording) continue;
    const lines = handle(event, new Date().toISOString());
    if (lines.length) {
      appendSafe(logPath, lines.map((l) => `${l}\n`).join(''));
    }
  }
}

module.exports = reporter;
module.exports.createRecorder = createRecorder;
module.exports.appendSafe = appendSafe;
