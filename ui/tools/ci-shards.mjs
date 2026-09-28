#!/usr/bin/env node
/**
 * How CI splits its two long suites across shard jobs, and how a roll-up proves the split ran whole
 * (Story 13.5).
 *
 * `instance shard k/3` runs its share of the ObjectScript classes through `ci-runner.mjs --shard`,
 * and `browser shard k/3` its share of the spec files through `ci-browser.mjs`. Every leg computes
 * the split itself, from the same offered list and the same `ci-timings.json`, so the legs agree
 * without talking to each other: items sorted by recorded seconds, longest first, then by name in
 * code-unit order, each given to the shard with the smallest running total, the lowest index on a
 * tie. An item with no recorded time weighs the median of the offered items' recorded times, or 1
 * when none has one; a timing for an item nobody offers is ignored.
 *
 * Each leg writes a record, `{suite, shard, shards, offered, assigned, ran: [{name, seconds, tests,
 * failed, outcome}]}`, and the roll-up jobs `instance` and `browser` run `check` over them: it fails
 * unless every item ran in exactly one shard, every shard executed a test, and the shard jobs'
 * result was `success`.
 *
 * Usage (from `ui/`):
 *   node tools/ci-shards.mjs assign --suite objectscript|browser --shards N [--timings PATH]
 *   node tools/ci-shards.mjs check --suite S --shards N --records DIR --result R [--dir DIR]
 *   node tools/ci-shards.mjs refresh (--run ID | --records DIR) [--timings PATH]
 *
 * `assign` splits the checkout's lists. The ObjectScript one is `testClassesOnDisk`'s floor, which
 * misses a class that reaches `TestCase` through a base class, while a CI leg splits the list the
 * instance offers, so the two splits can differ; the share a leg actually ran is its record's
 * `assigned`.
 *
 * `refresh --run ID` downloads that run's `ci-record-*` artifacts with `gh run download` and
 * rewrites `ci-timings.json` from the seconds each shard recorded. Every suite present in the
 * records is replaced whole, keys sorted, so an entry for a removed item goes; a suite absent from
 * them is kept. Run it on a green run once the shard estimates drift, and commit the file.
 *
 * Exit 0 on success, 1 on a failed check or an unreadable input, 2 on a usage error.
 */

import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// ci-runner.mjs imports this module as well, so nothing here may read its bindings at load time.
import { testClassesOnDisk } from './ci-runner.mjs';

const here = dirname(fileURLToPath(import.meta.url));

/** The committed timings every leg assigns from. */
export const DEFAULT_TIMINGS = join(here, 'ci-timings.json');

/** Where the browser spec files live in the checkout. */
export const DEFAULT_BROWSER_DIR = join(here, '..', 'browser');

/** The two suites a record or the timings file can name. */
export const SUITES = ['objectscript', 'browser'];

const NOUNS = { objectscript: 'class(es)', browser: 'spec file(s)' };

/** A caller error: exit 2, as distinct from a failed check or an unreadable input. */
class UsageError extends Error {}

const byCodeUnit = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

const isPlainObject = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);

/** `k/n` as `{index, count}`, or a thrown usage error naming `--shard`. */
export function parseShard(text) {
  const match = /^([1-9]\d*)\/([1-9]\d*)$/.exec(String(text ?? ''));
  if (match === null || Number(match[1]) > Number(match[2])) {
    throw new Error(`--shard takes k/n, two whole numbers with 1 <= k <= n; got ${JSON.stringify(String(text ?? ''))}`);
  }
  return { index: Number(match[1]), count: Number(match[2]) };
}

function median(values) {
  if (values.length === 0) return 1;
  const sorted = [...values].sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

/**
 * The split of `items` over `count` shards: `{shares, weights, untimed}`. `shares[k - 1]` is shard
 * k's `{items, seconds}`, its items in the order `items` gives them; `weights` is each item's
 * seconds as weighed, and `untimed` the items weighed at the median. Pure and deterministic, so
 * every leg that is handed the same list and timings derives the same split.
 */
export function assignShards(items, timings, count) {
  const offered = [...new Set(items)];
  const table = isPlainObject(timings) ? timings : {};
  const recorded = (name) => Object.hasOwn(table, name);
  const fallback = median(offered.filter(recorded).map((name) => table[name]));
  const weights = Object.fromEntries(offered.map((name) => [name, recorded(name) ? table[name] : fallback]));
  const totals = Array(count).fill(0);
  const owner = new Map();
  for (const name of [...offered].sort((a, b) => weights[b] - weights[a] || byCodeUnit(a, b))) {
    let target = 0;
    for (let i = 1; i < count; i += 1) if (totals[i] < totals[target]) target = i;
    totals[target] += weights[name];
    owner.set(name, target);
  }
  return {
    shares: totals.map((seconds, index) => ({ items: offered.filter((name) => owner.get(name) === index), seconds })),
    weights,
    untimed: offered.filter((name) => !recorded(name)),
  };
}

/** The `*.browser-spec.mjs` file names directly under `dir`, in code-unit order. */
export function browserSpecsOnDisk(dir = DEFAULT_BROWSER_DIR) {
  return readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith('.browser-spec.mjs'))
    .map((entry) => entry.name)
    .sort(byCodeUnit);
}

/**
 * The timings file as `{source, objectscript, browser}`, each suite a map of item to seconds. A
 * suite the file leaves out reads as `{}`. Throws naming the file when it cannot be read, or when a
 * value is not a non-negative number of seconds.
 */
export function readTimings(path = DEFAULT_TIMINGS) {
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(path, 'utf8'));
  } catch (error) {
    throw new Error(`cannot read the timings file ${path}: ${error.message}`);
  }
  if (!isPlainObject(parsed)) throw new Error(`the timings file ${path} is not a JSON object`);
  const timings = { source: isPlainObject(parsed.source) ? parsed.source : {} };
  for (const suite of SUITES) {
    const table = parsed[suite] ?? {};
    if (!isPlainObject(table)) throw new Error(`the timings file ${path}: "${suite}" is not an object of seconds`);
    for (const [name, seconds] of Object.entries(table)) {
      if (typeof seconds !== 'number' || !Number.isFinite(seconds) || seconds < 0) {
        throw new Error(`the timings file ${path}: ${suite} "${name}" is ${JSON.stringify(seconds)}, not a number of seconds`);
      }
    }
    timings[suite] = table;
  }
  return timings;
}

/** Write a shard record as JSON, creating its directory. */
export function writeRecord(path, record) {
  mkdirSync(dirname(resolve(path)), { recursive: true });
  writeFileSync(path, `${JSON.stringify(record, null, 2)}\n`);
}

const isCount = (value) => Number.isInteger(value) && value >= 0;
const isNameList = (value) => Array.isArray(value) && value.every((name) => typeof name === 'string');

/** Why `record` is not a shard record, or `null` when it is one. */
export function recordShapeProblem(record) {
  if (!isPlainObject(record)) return 'is not a shard record';
  if (typeof record.suite !== 'string') return 'names no suite';
  if (!Number.isInteger(record.shards) || record.shards < 1) return 'names no shard count';
  if (!Number.isInteger(record.shard) || record.shard < 1 || record.shard > record.shards) {
    return `names shard ${JSON.stringify(record.shard)} of ${record.shards}`;
  }
  if (!isNameList(record.offered)) return 'carries no offered list';
  if (!isNameList(record.assigned)) return 'carries no assigned list';
  if (!Array.isArray(record.ran)) return 'carries no ran list';
  for (const item of record.ran) {
    const ok =
      isPlainObject(item) &&
      typeof item.name === 'string' &&
      typeof item.seconds === 'number' &&
      Number.isFinite(item.seconds) &&
      isCount(item.tests) &&
      isCount(item.failed) &&
      typeof item.outcome === 'string';
    if (!ok) return `carries a ran entry that is not {name, seconds, tests, failed, outcome}: ${JSON.stringify(item)}`;
  }
  return null;
}

/** Every `*.json` file under `dir`, recursively, as `{path, record}` or `{path, error}`. */
export function readRecords(dir) {
  const found = [];
  const walk = (current) => {
    for (const entry of readdirSync(current, { withFileTypes: true }).sort((a, b) => byCodeUnit(a.name, b.name))) {
      const full = join(current, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.name.endsWith('.json')) {
        try {
          found.push({ path: full, record: JSON.parse(readFileSync(full, 'utf8')) });
        } catch (error) {
          found.push({ path: full, error: `is not readable JSON (${error.message})` });
        }
      }
    }
  };
  walk(dir);
  return found;
}

const sameList = (a, b) => a.length === b.length && a.every((name, i) => name === b[i]);

/**
 * The roll-up's verdict over one suite's shard records: `{problems, lines, items}`. `records` is
 * what `readRecords` returns; a record for another suite is not this check's business and is
 * skipped. `expected` is the list every shard must have been offered, or `null` to take the
 * shards' own agreed list. The run is complete only when `problems` is empty: the shard jobs'
 * `result` is `success`, each shard 1..`shards` left exactly one well-formed record, every record
 * was offered the same list, every shard executed at least one test and every item it ran passed,
 * and every expected item ran in exactly one shard and nothing else ran.
 */
export function checkRecords({ suite, shards, result, records, expected = null }) {
  const problems = [];
  const lines = [];
  const noun = NOUNS[suite] ?? 'item(s)';
  const label = (k) => `shard ${k}/${shards}`;
  if (result !== 'success') problems.push(`the ${suite} shard jobs' result is ${JSON.stringify(result)}, not "success"`);

  const byShard = new Map();
  for (const entry of records) {
    if (entry.error !== undefined) {
      problems.push(`${entry.path} ${entry.error}`);
      continue;
    }
    const shape = recordShapeProblem(entry.record);
    if (shape !== null) {
      problems.push(`${entry.path} ${shape}`);
      continue;
    }
    const { record } = entry;
    if (record.suite !== suite) continue;
    if (record.shards !== shards) {
      problems.push(`${entry.path} is shard ${record.shard}/${record.shards}, a split into ${record.shards} rather than ${shards}`);
      continue;
    }
    if (byShard.has(record.shard)) {
      problems.push(`${label(record.shard)} left two records: ${byShard.get(record.shard).path} and ${entry.path}`);
      continue;
    }
    byShard.set(record.shard, entry);
  }
  for (let k = 1; k <= shards; k += 1) {
    if (!byShard.has(k)) problems.push(`${label(k)} left no record: it refused before running its share, did not finish, or did not upload its record -- its own log says which`);
  }

  const present = [...byShard.keys()].sort((a, b) => a - b);
  const agreed = present.length === 0 ? [] : byShard.get(present[0]).record.offered;
  for (const k of present.slice(1)) {
    if (!sameList(byShard.get(k).record.offered, agreed)) {
      problems.push(`${label(k)} was offered a different list of ${noun} from ${label(present[0])}, so the shards cannot have agreed on a split`);
    }
  }
  if (expected !== null && present.length > 0 && !sameList(agreed, expected)) {
    const onlyOffered = agreed.filter((name) => !expected.includes(name));
    const onlyExpected = expected.filter((name) => !agreed.includes(name));
    problems.push(
      `the shards were offered ${agreed.length} ${noun} and the checkout carries ${expected.length}` +
        `${onlyOffered.length > 0 ? `; only offered: ${onlyOffered.join(', ')}` : ''}` +
        `${onlyExpected.length > 0 ? `; only in the checkout: ${onlyExpected.join(', ')}` : ''}`
    );
  }
  const want = expected ?? agreed;

  const ranIn = new Map();
  for (const k of present) {
    const { record } = byShard.get(k);
    const tests = record.ran.reduce((sum, item) => sum + item.tests, 0);
    const seconds = record.ran.reduce((sum, item) => sum + item.seconds, 0);
    lines.push(`${label(k)} -- ${record.ran.length} ${noun}, ${tests} test(s), ${(seconds / 60).toFixed(1)} min`);
    if (tests === 0) problems.push(`${label(k)} executed 0 tests; a shard that tested nothing is a failure, never a pass`);
    for (const item of record.ran) {
      if (!ranIn.has(item.name)) ranIn.set(item.name, []);
      ranIn.get(item.name).push(k);
      if (item.outcome !== 'passed') problems.push(`${label(k)}: ${item.name} ${item.outcome}`);
    }
  }
  const unrun = want.filter((name) => !ranIn.has(name));
  if (unrun.length > 0) problems.push(`${unrun.length} of ${want.length} ${noun} ran in no shard: ${unrun.join(', ')}`);
  for (const name of want) {
    const where = ranIn.get(name) ?? [];
    if (where.length > 1) problems.push(`${name} ran in more than one shard: ${where.map(label).join(' and ')}`);
  }
  const wanted = new Set(want);
  for (const [name, where] of ranIn) {
    if (!wanted.has(name)) problems.push(`${name} ran in ${where.map(label).join(' and ')} but was not offered`);
  }
  return { problems, lines, items: want.length };
}

/**
 * `current` with every suite `records` covers rewritten from the seconds its shards recorded:
 * `{timings, problems, rewritten}`. Each rewritten suite is replaced whole, one decimal, keys in
 * code-unit order, and its `source` names `label`; a suite with no record is kept as it was. A
 * suite whose records are not exactly one per shard 1..n is a problem, and nothing is rewritten
 * while any problem stands.
 */
export function refreshTimings(current, records, label) {
  const bySuite = new Map();
  const problems = [];
  for (const record of records) {
    if (!SUITES.includes(record.suite)) {
      problems.push(`a record names the suite ${JSON.stringify(record.suite)}, which has no timings`);
      continue;
    }
    if (!bySuite.has(record.suite)) bySuite.set(record.suite, []);
    bySuite.get(record.suite).push(record);
  }
  const next = {
    source: { ...(isPlainObject(current.source) ? current.source : {}) },
    objectscript: current.objectscript ?? {},
    browser: current.browser ?? {},
  };
  const rewritten = [];
  for (const suite of SUITES) {
    const list = bySuite.get(suite);
    if (list === undefined) continue;
    const shards = list[0].shards;
    const seen = list.map((record) => record.shard).sort((a, b) => a - b);
    const complete = list.every((record) => record.shards === shards) && sameList(seen, Array.from({ length: shards }, (_, i) => i + 1));
    if (!complete) {
      problems.push(`the ${suite} records are shard(s) ${seen.join(', ')} of ${shards}, not one record per shard, so their times would drop the missing shards' ${NOUNS[suite]}`);
      continue;
    }
    const table = {};
    for (const record of [...list].sort((a, b) => a.shard - b.shard)) {
      for (const item of record.ran) {
        if (!Object.hasOwn(table, item.name)) table[item.name] = Math.round(item.seconds * 10) / 10;
      }
    }
    next[suite] = Object.fromEntries(Object.keys(table).sort(byCodeUnit).map((name) => [name, table[name]]));
    next.source[suite] = `${label}: the seconds each of its ${shards} shard(s) recorded per ${suite === 'objectscript' ? 'class' : 'spec file'}`;
    rewritten.push(suite);
  }
  return { timings: next, problems, rewritten };
}

/** `--flag value` pairs into an object, refusing a flag not in `allowed` or one with no value. */
function parseOptions(argv, allowed) {
  const options = {};
  for (let i = 0; i < argv.length; i += 2) {
    const flag = argv[i];
    const value = argv[i + 1];
    if (!allowed.includes(flag)) throw new UsageError(`unknown argument ${flag}`);
    if (value === undefined) throw new UsageError(`${flag} needs a value`);
    options[flag.slice(2)] = value;
  }
  return options;
}

function parseSuite(value) {
  if (!SUITES.includes(value)) throw new UsageError(`--suite takes ${SUITES.join(' or ')}; got ${JSON.stringify(value ?? '')}`);
  return value;
}

function parseCount(value) {
  if (!/^[1-9]\d*$/.test(String(value ?? ''))) throw new UsageError(`--shards takes a whole number of at least 1; got ${JSON.stringify(value ?? '')}`);
  return Number(value);
}

function assign(argv) {
  const options = parseOptions(argv, ['--suite', '--shards', '--timings']);
  const suite = parseSuite(options.suite);
  const count = parseCount(options.shards);
  const timingsPath = options.timings ?? DEFAULT_TIMINGS;
  const timings = readTimings(timingsPath);
  const items = suite === 'objectscript' ? testClassesOnDisk() : browserSpecsOnDisk();
  const { shares, weights, untimed } = assignShards(items, timings[suite], count);
  const noun = NOUNS[suite];
  console.log(
    `ci-shards: ${suite} -- the checkout's ${items.length} ${noun} over ${count} shard(s), weighed from ${timingsPath}` +
      (untimed.length > 0 ? ` (${untimed.length} untimed, each at the median)` : '')
  );
  shares.forEach((share, index) => {
    console.log(`shard ${index + 1}/${count}: ${share.items.length} ${noun}, est. ${(share.seconds / 60).toFixed(1)} min`);
    for (const name of share.items) {
      console.log(`  ${name}  ${weights[name].toFixed(1)} s${untimed.includes(name) ? ' (untimed: median)' : ''}`);
    }
  });
  const totals = shares.map((share) => share.seconds);
  const largest = items.length === 0 ? 0 : Math.max(...items.map((name) => weights[name]));
  console.log(
    `ci-shards: ${suite} -- estimates ${totals.map((seconds) => (seconds / 60).toFixed(1)).join(' / ')} min; ` +
      `spread ${(Math.max(...totals) - Math.min(...totals)).toFixed(1)} s against a largest item of ${largest.toFixed(1)} s`
  );
  return 0;
}

function check(argv) {
  const options = parseOptions(argv, ['--suite', '--shards', '--records', '--result', '--dir']);
  const suite = parseSuite(options.suite);
  const shards = parseCount(options.shards);
  if (options.records === undefined) throw new UsageError('--records is required');
  if (options.result === undefined) throw new UsageError('--result is required');
  const records = existsSync(options.records) ? readRecords(options.records) : [];
  const expected = suite === 'browser' ? browserSpecsOnDisk(options.dir ?? DEFAULT_BROWSER_DIR) : null;
  const { problems, lines, items } = checkRecords({ suite, shards, result: options.result, records, expected });
  if (!existsSync(options.records)) problems.unshift(`the record directory ${options.records} does not exist`);
  for (const line of lines) console.log(`ci-shards: ${suite} ${line}`);
  if (problems.length > 0) {
    console.error(`ci-shards: ${suite} -- found problems --`);
    for (const problem of problems) console.error(`  ${problem}`);
    return 1;
  }
  console.log(`ci-shards: ${suite} -- every one of ${items} ${NOUNS[suite]} ran in exactly one of ${shards} shard(s), and every shard executed a test.`);
  return 0;
}

function refresh(argv) {
  const options = parseOptions(argv, ['--run', '--records', '--timings']);
  if ((options.run === undefined) === (options.records === undefined)) throw new UsageError('refresh takes exactly one of --run ID and --records DIR');
  if (options.run !== undefined && !/^\d+$/.test(options.run)) throw new UsageError(`--run takes a run id; got ${JSON.stringify(options.run)}`);
  const timingsPath = options.timings ?? DEFAULT_TIMINGS;
  let scratch = null;
  try {
    let dir = options.records;
    let label = `the records in ${options.records}`;
    if (options.run !== undefined) {
      scratch = mkdtempSync(join(tmpdir(), 'ocupilot-ci-records-'));
      const download = spawnSync('gh', ['run', 'download', options.run, '--pattern', 'ci-record-*', '--dir', scratch], {
        stdio: ['ignore', 'inherit', 'inherit'],
      });
      if (download.status !== 0) {
        console.error(`ci-shards: gh run download ${options.run} did not finish (${download.error?.message ?? `exit ${download.status}`}); nothing was rewritten`);
        return 1;
      }
      dir = scratch;
      label = `run ${options.run}`;
    }
    if (!existsSync(dir)) {
      console.error(`ci-shards: the record directory ${dir} does not exist; nothing was rewritten`);
      return 1;
    }
    const entries = readRecords(dir);
    const unreadable = [];
    for (const entry of entries) {
      const problem = entry.error ?? recordShapeProblem(entry.record);
      if (problem !== null) unreadable.push(`${entry.path} ${problem}`);
    }
    if (entries.length === 0) unreadable.push(`${label} holds no shard record`);
    let current;
    try {
      current = readTimings(timingsPath);
    } catch (error) {
      unreadable.push(error.message);
    }
    if (unreadable.length > 0) {
      console.error('ci-shards: nothing was rewritten --');
      for (const problem of unreadable) console.error(`  ${problem}`);
      return 1;
    }
    const { timings, problems, rewritten } = refreshTimings(current, entries.map((entry) => entry.record), label);
    if (problems.length > 0) {
      console.error('ci-shards: nothing was rewritten --');
      for (const problem of problems) console.error(`  ${problem}`);
      return 1;
    }
    const text = `${JSON.stringify(timings, null, 2)}\n`;
    const changed = !existsSync(timingsPath) || readFileSync(timingsPath, 'utf8') !== text;
    writeFileSync(timingsPath, text);
    for (const suite of rewritten) console.log(`ci-shards: ${suite} -- ${Object.keys(timings[suite]).length} timing(s) from ${label}`);
    console.log(`ci-shards: ${timingsPath} ${changed ? 'rewritten' : 'unchanged'}`);
    return 0;
  } finally {
    if (scratch !== null) rmSync(scratch, { recursive: true, force: true });
  }
}

function main() {
  const [command, ...rest] = process.argv.slice(2);
  const commands = { assign, check, refresh };
  if (!Object.hasOwn(commands, command ?? '')) {
    console.error('ci-shards: the first argument is assign, check or refresh');
    process.exitCode = 2;
    return;
  }
  try {
    process.exitCode = commands[command](rest);
  } catch (error) {
    console.error(`ci-shards: ${error.message}`);
    process.exitCode = error instanceof UsageError ? 2 : 1;
  }
}

if (process.argv[1] && process.argv[1].endsWith('ci-shards.mjs')) {
  main();
}
