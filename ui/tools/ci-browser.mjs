#!/usr/bin/env node
/**
 * One leg of CI's `browser shard k/3` (Story 13.5): this shard's share of `browser/*.browser-spec.mjs`,
 * in sorted order, one `node --test --test-concurrency=1` process per file, so one file at a time
 * against the throwaway `OCUPILOT_BROWSER_ORIGIN` and `OCUPILOT_BROWSER_CONTAINER` name.
 * `npm run test:browser` is unchanged and still runs the whole suite; this runs as
 * `npm run test:browser:shard -- --shard k/n`.
 *
 * The share is the one `ci-shards.mjs` assigns from `--timings` (default `ui/tools/ci-timings.json`).
 * Each file's TAP goes to stdout as it runs and to a second reporter's file, from which its pass,
 * fail and skip counts are read. A file fails when its process exits non-zero, when it reports a
 * failed or cancelled test, or when its counts cannot be read. The shard fails when any file does,
 * or when it executed no test at all (pass plus fail is 0), which a shard whose every test skipped
 * would otherwise pass. The record `ci-shards.mjs check` reads is written whenever the share was
 * computed, failed or not.
 *
 * Usage (from `ui/`):
 *   npm run test:browser:shard -- --shard k/n [--record PATH] [--timings PATH] [--dir DIR]
 *
 * `--dir` (default `ui/browser/`) is where the spec files are read from. Exit 0 when the shard passed,
 * 1 when it did not, 2 on a usage error.
 */

import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

import { assignShards, browserSpecsOnDisk, DEFAULT_BROWSER_DIR, parseShard, readTimings, writeRecord } from './ci-shards.mjs';

/** The options, or a thrown usage error. `--shard` is required. */
export function parseArgs(argv) {
  const options = { shard: null, record: '', timings: '', dir: DEFAULT_BROWSER_DIR };
  for (let i = 0; i < argv.length; i += 2) {
    const flag = argv[i];
    const value = argv[i + 1];
    if (!['--shard', '--record', '--timings', '--dir'].includes(flag)) throw new Error(`ci-browser: unknown argument ${flag}`);
    if (value === undefined) throw new Error(`ci-browser: ${flag} needs a value`);
    if (flag === '--shard') {
      try {
        options.shard = parseShard(value);
      } catch (error) {
        throw new Error(`ci-browser: ${error.message}`);
      }
    }
    if (flag === '--record') options.record = value;
    if (flag === '--timings') options.timings = value;
    if (flag === '--dir') options.dir = resolve(value);
  }
  if (options.shard === null) throw new Error('ci-browser: --shard k/n is required; `npm run test:browser` runs the whole suite');
  return options;
}

/**
 * A TAP stream's closing counts, `{pass, fail, skipped, todo, cancelled}`, or `null` when it carries
 * no `# pass` or no `# fail` line. The last of each wins: the summary closes the stream.
 */
export function tapCounts(text) {
  const read = (name) => {
    const all = [...String(text).matchAll(new RegExp(`^# ${name} (\\d+)$`, 'gm'))];
    return all.length === 0 ? null : Number(all[all.length - 1][1]);
  };
  const pass = read('pass');
  const fail = read('fail');
  if (pass === null || fail === null) return null;
  return { pass, fail, skipped: read('skipped') ?? 0, todo: read('todo') ?? 0, cancelled: read('cancelled') ?? 0 };
}

function main() {
  let options;
  try {
    options = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 2;
    return;
  }
  const { index, count } = options.shard;
  const label = `shard ${index}/${count}`;

  let offered;
  let share;
  try {
    const timings = readTimings(options.timings === '' ? undefined : options.timings);
    offered = browserSpecsOnDisk(options.dir);
    share = assignShards(offered, timings.browser, count).shares[index - 1].items;
  } catch (error) {
    console.error(`ci-browser: ${label} -- ${error.message}`);
    process.exitCode = 1;
    return;
  }
  console.log(`ci-browser: ${label} -- running ${share.length} of ${offered.length} spec file(s), one at a time`);

  // Removed from the child's environment: a runner started under `node --test` inherits the
  // variable, and a child that sees it reports to a parent that is not listening.
  const env = { ...process.env };
  delete env.NODE_TEST_CONTEXT;

  const ran = [];
  const problems = [];
  let skipped = 0;
  const scratch = mkdtempSync(join(tmpdir(), 'ocupilot-ci-browser-'));
  try {
    share.forEach((name, position) => {
      const tap = join(scratch, `${position}.tap`);
      const startedAt = Date.now();
      const result = spawnSync(
        process.execPath,
        [
          '--test',
          '--test-concurrency=1',
          '--test-reporter=tap',
          '--test-reporter-destination=stdout',
          '--test-reporter=tap',
          `--test-reporter-destination=${tap}`,
          join(options.dir, name),
        ],
        { stdio: ['ignore', 'inherit', 'inherit'], env }
      );
      const seconds = (Date.now() - startedAt) / 1000;
      let counts = null;
      try {
        counts = tapCounts(readFileSync(tap, 'utf8'));
      } catch {
        counts = null;
      }
      const exit = result.error ? result.error.message : `exit ${result.status}`;
      let outcome = 'passed';
      if (counts === null) {
        outcome = 'unreadable';
        problems.push(`${name}: its test counts could not be read (${exit}) -- which is a failure, never a pass`);
      } else if (counts.fail > 0) {
        outcome = 'failed';
        problems.push(`${name}: ${counts.fail} of ${counts.pass + counts.fail} test(s) failed`);
      } else if (counts.cancelled > 0) {
        outcome = 'failed';
        problems.push(`${name}: ${counts.cancelled} test(s) were cancelled`);
      } else if (result.status !== 0) {
        outcome = 'failed';
        problems.push(`${name}: its node --test process ended with ${exit} although no test failed`);
      }
      const tests = counts === null ? 0 : counts.pass + counts.fail;
      skipped += counts === null ? 0 : counts.skipped;
      ran.push({ name, seconds, tests, failed: counts === null ? 0 : counts.fail, outcome });
      const tag = outcome === 'passed' ? 'ok' : outcome.toUpperCase();
      const detail = counts === null ? exit : `${counts.pass} passed, ${counts.fail} failed, ${counts.skipped} skipped`;
      console.log(`  ${tag.padEnd(11)}${name} -- ${detail}, ${seconds.toFixed(1)} s`);
    });
  } finally {
    rmSync(scratch, { recursive: true, force: true });
  }

  const tests = ran.reduce((sum, item) => sum + item.tests, 0);
  const failed = ran.reduce((sum, item) => sum + item.failed, 0);
  if (tests === 0) {
    problems.push(
      share.length === 0
        ? `was assigned none of the ${offered.length} spec file(s), so it executed 0 tests -- which is a failure, never a pass`
        : `its ${share.length} spec file(s) executed 0 tests (${skipped} skipped) -- which is a failure, never a pass`
    );
  }
  console.log(`ci-browser: ${label} -- ${ran.length} spec file(s), ${tests} test(s) executed, ${failed} failed, ${skipped} skipped`);
  if (options.record !== '') {
    try {
      writeRecord(options.record, { suite: 'browser', shard: index, shards: count, offered, assigned: share, ran });
    } catch (error) {
      problems.push(`could not write the record ${options.record}: ${error.message}`);
    }
  }
  if (problems.length > 0) {
    for (const problem of problems) console.error(`ci-browser: ${label} -- ${problem}`);
    process.exitCode = 1;
    return;
  }
  console.log(`ci-browser: ${label} -- green.`);
}

if (process.argv[1] && process.argv[1].endsWith('ci-browser.mjs')) {
  main();
}
