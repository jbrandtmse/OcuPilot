import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { testClassesOnDisk } from './ci-runner.mjs';
import { assignShards, browserSpecsOnDisk, checkRecords, parseShard, readTimings, refreshTimings } from './ci-shards.mjs';
import { stubEnv, writeStub } from './stub-bin.mjs';

/**
 * The shard split and its roll-up (Story 13.5): `ci-shards.mjs`'s assignment, check and refresh,
 * `ci-runner.mjs --shard` and `ci-browser.mjs`, one test per row of the story's I/O matrix.
 *
 * The runners are executed, not read. `ci-runner.mjs` runs from a copy of itself, `ci-shards.mjs`
 * and `scripts/ci-unit-test.sh` in a temporary tree whose `src/OcuPilot/Test/` holds seven fixture
 * classes, with a stub `docker` on PATH answering the list session with those classes and each class
 * session with a landed run. `ci-browser.mjs` runs over fixture spec files, and `refresh` through a
 * stub `gh`. Nothing here needs an instance, a browser or the network.
 */

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(here, '..', '..');
const SHARDS_CLI = join(here, 'ci-shards.mjs');
const BROWSER_CLI = join(here, 'ci-browser.mjs');

// --- Assignment ------------------------------------------------------------------------------

test('--shard takes k/n with 1 <= k <= n, and anything else is refused naming the flag', () => {
  assert.deepEqual(parseShard('2/3'), { index: 2, count: 3 });
  assert.deepEqual(parseShard('40/40'), { index: 40, count: 40 });
  for (const bad of ['0/3', '4/3', 'x', '1/0', '/3', '1/', '1.5/3', '01/3', ' 1/3', '', undefined]) {
    assert.throws(() => parseShard(bad), /^Error: --shard takes k\/n/, `${JSON.stringify(bad)} is refused`);
  }
});

// Mutation (Rule 19): sort ascending in assignShards -> this goes red.
test('assignment is longest first, each item to the least-loaded shard', () => {
  const { shares } = assignShards(['a', 'b', 'c', 'd'], { a: 10, b: 9, c: 8, d: 1 }, 2);
  assert.deepEqual(
    shares.map((share) => share.items),
    [['a', 'd'], ['b', 'c']],
    'a (10) and b (9) open the two shards, c (8) joins the lighter, d (1) the lighter again'
  );
  assert.deepEqual(shares.map((share) => share.seconds), [11, 17]);
});

test('equal weights go by name in code-unit order, to the lowest shard index on a tie', () => {
  // `localeCompare` would put `a` before `B`; a code-unit comparison puts `B` (66) before `a` (97),
  // and every leg must make the same choice whatever its locale.
  const { shares } = assignShards(['a', 'B'], { a: 5, B: 5 }, 2);
  assert.deepEqual(shares.map((share) => share.items), [['B'], ['a']]);
  const tied = assignShards(['x', 'y', 'z'], { x: 1, y: 1, z: 1 }, 3);
  assert.deepEqual(tied.shares.map((share) => share.items), [['x'], ['y'], ['z']], 'each tie opens the lowest empty shard');
});

// Mutation (Rule 19): drop the by-name tie-break from assignShards' sort -> this goes red.
test('a share keeps the order its items were offered in, and the split does not depend on that order', () => {
  // The three ties straddle both shards (x 10; then w, y, z at 5, the last tie to the lower index),
  // so an order-dependent tie-break moves an item between shards.
  const timings = { w: 5, x: 10, y: 5, z: 5 };
  const { shares } = assignShards(['z', 'y', 'x', 'w'], timings, 2);
  assert.deepEqual(shares.map((share) => share.items), [['z', 'x'], ['y', 'w']], 'offered order, not weight or name order');
  const reordered = assignShards(['w', 'x', 'y', 'z'], timings, 2);
  assert.deepEqual(
    reordered.shares.map((share) => [...share.items].sort()),
    shares.map((share) => [...share.items].sort()),
    'the same items land in the same shards whatever order they were offered in'
  );
});

// Mutation (Rule 19): skip untimed items in assignShards -> this goes red.
test('an item with no recorded time is still assigned, at the median, and a timing for a removed item is ignored', () => {
  const { shares, weights, untimed } = assignShards(['a', 'b', 'c', 'new'], { a: 10, b: 2, c: 4, removed: 1000 }, 2);
  assert.deepEqual(untimed, ['new']);
  assert.equal(weights.new, 4, 'the median of the offered items recorded times: 2, 4 and 10');
  assert.deepEqual(shares.flatMap((share) => share.items).sort(), ['a', 'b', 'c', 'new'], 'every offered item is in a shard');
  assert.ok(!shares.some((share) => share.items.includes('removed')), 'and the removed one is in none');
  assert.equal(shares.reduce((sum, share) => sum + share.seconds, 0), 20, 'nor does its timing weigh anything');
  assert.equal(assignShards(['a', 'b', 'c', 'd', 'new'], { a: 2, b: 4, c: 10, d: 12 }, 1).weights.new, 7, 'an even count takes the mean of the middle two');
  assert.deepEqual(assignShards(['x', 'y'], {}, 2).weights, { x: 1, y: 1 }, 'and with nothing recorded every item weighs 1');
});

test('more shards than items leaves the later shards empty', () => {
  assert.deepEqual(assignShards(['a'], {}, 3).shares.map((share) => share.items), [['a'], [], []]);
});

test("the checkout's classes split four ways and its spec files three, each once, within one largest item of each other", () => {
  const timings = readTimings();
  for (const [suite, items, legs] of [
    ['objectscript', testClassesOnDisk(), 4],
    ['browser', browserSpecsOnDisk(), 3],
  ]) {
    assert.ok(items.length > 20, `the checkout carries ${items.length} ${suite} item(s)`);
    const { shares, weights } = assignShards(items, timings[suite], legs);
    assert.deepEqual(shares.flatMap((share) => share.items).sort(), [...items].sort(), `every ${suite} item is in exactly one shard`);
    const totals = shares.map((share) => share.seconds);
    const largest = Math.max(...items.map((name) => weights[name]));
    assert.ok(Math.max(...totals) - Math.min(...totals) <= largest, `${suite} shard totals ${totals.join(', ')} differ by more than the largest item, ${largest}`);
  }
});

test('the timings file is sorted, holds seconds, and says where each half came from', () => {
  const raw = JSON.parse(readFileSync(join(here, 'ci-timings.json'), 'utf8'));
  assert.deepEqual(Object.keys(raw), ['source', 'objectscript', 'browser']);
  for (const suite of ['objectscript', 'browser']) {
    const keys = Object.keys(raw[suite]);
    assert.ok(keys.length > 20, `${suite} carries ${keys.length} timing(s)`);
    assert.deepEqual(keys, [...keys].sort(), `${suite} keys are in code-unit order, so a refresh diff is readable`);
    assert.ok(Object.values(raw[suite]).every((seconds) => typeof seconds === 'number' && seconds >= 0));
  }
  assert.match(raw.source.objectscript, /run \d+/, 'the ObjectScript half names its run');
  assert.match(raw.source.browser, /run \d+/, 'the browser half names its run, estimated or recorded');
});

test('the browser spec files are the *.browser-spec.mjs files, in code-unit order', () => {
  const specs = browserSpecsOnDisk();
  assert.equal(specs[0], 'a11y-structural-invariants.browser-spec.mjs', 'the structural gate sorts first, as its header requires');
  assert.ok(specs.every((name) => name.endsWith('.browser-spec.mjs')));
  assert.ok(!specs.includes('list-spec.mjs') && !specs.includes('iris-session.mjs'), 'a helper module is not a spec file');
  assert.deepEqual(specs, [...specs].sort((a, b) => (a < b ? -1 : a > b ? 1 : 0)));
});

// Mutation (Rule 19): make browserSpecsOnDisk skip any file whose name starts with `users` -> this
// goes red. The legs and the `browser` roll-up both read that one function, so only an independent
// definition of a spec file can see it narrow.
test("the browser spec list is every browser/ module that registers tests, DW-159's definition of a spec", () => {
  const dir = join(here, '..', 'browser');
  const registers = readdirSync(dir)
    .filter((name) => name.endsWith('.mjs') && /\bfrom\s+['"]node:test['"]/.test(readFileSync(join(dir, name), 'utf8')))
    .sort((a, b) => (a < b ? -1 : a > b ? 1 : 0));
  assert.ok(registers.length > 20, `browser/ holds ${registers.length} module(s) that register tests`);
  assert.deepEqual(browserSpecsOnDisk(), registers);
});

// --- The roll-up check, over records built here ------------------------------------------------

const OFFERED = ['A', 'B', 'C', 'D'];

function recordEntry(shard, names, overrides = {}) {
  const ran = names.map((name) => ({ name, seconds: 60, tests: 2, failed: 0, outcome: 'passed' }));
  return {
    path: `records/objectscript-shard-${shard}.json`,
    record: { suite: 'objectscript', shard, shards: 3, offered: OFFERED, assigned: names, ran, ...overrides },
  };
}

const completeRecords = () => [recordEntry(1, ['A', 'D']), recordEntry(2, ['B']), recordEntry(3, ['C'])];

const check = (records, overrides = {}) =>
  checkRecords({ suite: 'objectscript', shards: 3, result: 'success', records, ...overrides });

test('a complete run passes the check and reports items, tests and minutes per shard', () => {
  const { problems, lines, items } = check(completeRecords());
  assert.deepEqual(problems, []);
  assert.equal(items, 4);
  assert.deepEqual(lines, [
    'shard 1/3 -- 2 class(es), 4 test(s), 2.0 min',
    'shard 2/3 -- 1 class(es), 2 test(s), 1.0 min',
    'shard 3/3 -- 1 class(es), 2 test(s), 1.0 min',
  ]);
});

test('the check names a dropped item, a duplicate with both shards, a missing record and an unoffered item', () => {
  const dropped = completeRecords();
  dropped[0] = recordEntry(1, ['A']);
  assert.deepEqual(check(dropped).problems, ['1 of 4 class(es) ran in no shard: D']);

  const twice = completeRecords();
  twice[1] = recordEntry(2, ['B', 'D']);
  assert.deepEqual(check(twice).problems, ['D ran in more than one shard: shard 1/3 and shard 2/3']);

  const missing = completeRecords().slice(0, 2);
  assert.deepEqual(check(missing).problems, [
    'shard 3/3 left no record: it refused before running its share, did not finish, or did not upload its record -- its own log says which',
    '1 of 4 class(es) ran in no shard: C',
  ]);

  const extra = completeRecords();
  extra[2] = recordEntry(3, ['C', 'E']);
  assert.deepEqual(check(extra).problems, ['E ran in shard 3/3 but was not offered']);
});

test('the check names differing offered lists, a shard with no test, a failed item and the result', () => {
  const differs = completeRecords();
  differs[1] = recordEntry(2, ['B'], { offered: ['A', 'B', 'C'] });
  assert.match(check(differs).problems.join('\n'), /shard 2\/3 was offered a different list of class\(es\) from shard 1\/3/);

  const empty = completeRecords();
  empty[2].record.ran[0].tests = 0;
  assert.deepEqual(check(empty).problems, ['shard 3/3 executed 0 tests; a shard that tested nothing is a failure, never a pass']);

  const failing = completeRecords();
  failing[0].record.ran[0].outcome = 'failed';
  assert.deepEqual(check(failing, { result: 'failure' }).problems, [
    'the objectscript shard jobs\' result is "failure", not "success"',
    'shard 1/3: A failed',
  ]);
  assert.deepEqual(check(completeRecords(), { result: 'skipped' }).problems, ['the objectscript shard jobs\' result is "skipped", not "success"']);
});

test('the check names an unreadable record, a malformed one, a second record for a shard and a wrong split', () => {
  const records = [
    ...completeRecords(),
    { path: 'records/broken.json', error: 'is not readable JSON (Unexpected end of JSON input)' },
    { path: 'records/odd.json', record: { suite: 'objectscript', shard: 2, shards: 3, offered: OFFERED, assigned: [], ran: [{ name: 'B' }] } },
    recordEntry(2, ['B']),
    { path: 'records/four.json', record: { ...recordEntry(4, []).record, shards: 4 } },
    { path: 'records/browser.json', record: { ...recordEntry(1, []).record, suite: 'browser' } },
  ];
  const problems = check(records).problems.join('\n');
  assert.match(problems, /records\/broken\.json is not readable JSON/);
  assert.match(problems, /records\/odd\.json carries a ran entry that is not \{name, seconds, tests, failed, outcome\}/);
  assert.match(problems, /shard 2\/3 left two records/);
  assert.match(problems, /records\/four\.json is shard 4\/4, a split into 4 rather than 3/);
  assert.doesNotMatch(problems, /browser\.json/, "another suite's record is not this check's business");
});

test('for the browser suite the check holds the offered list to the spec files the checkout carries', () => {
  const records = completeRecords().map(({ path, record }) => ({ path, record: { ...record, suite: 'browser' } }));
  const result = checkRecords({ suite: 'browser', shards: 3, result: 'success', records, expected: [...OFFERED, 'E'] });
  assert.deepEqual(result.problems, [
    'the shards were offered 4 spec file(s) and the checkout carries 5; only in the checkout: E',
    '1 of 5 spec file(s) ran in no shard: E',
  ]);
});

// --- Refresh -----------------------------------------------------------------------------------

test('refresh rewrites each suite the records cover, sorted, and keeps the suite they do not', () => {
  const current = {
    source: { objectscript: 'seed', browser: 'seed browser' },
    objectscript: { A: 1, 'Old.Gone': 9 },
    browser: { 'x.browser-spec.mjs': 5 },
  };
  const ranOf = (name, seconds) => [{ name, seconds, tests: 1, failed: 0, outcome: 'passed' }];
  const records = [
    { suite: 'objectscript', shard: 2, shards: 2, offered: ['B', 'A'], assigned: ['A'], ran: ranOf('A', 2.24) },
    { suite: 'objectscript', shard: 1, shards: 2, offered: ['B', 'A'], assigned: ['B'], ran: ranOf('B', 3.14159) },
  ];
  const { timings, problems, rewritten } = refreshTimings(current, records, 'run 42');
  assert.deepEqual(problems, []);
  assert.deepEqual(rewritten, ['objectscript']);
  assert.deepEqual(timings.objectscript, { A: 2.2, B: 3.1 });
  assert.deepEqual(Object.keys(timings.objectscript), ['A', 'B'], 'in code-unit order, and the removed class is gone');
  assert.deepEqual(timings.browser, { 'x.browser-spec.mjs': 5 }, 'a suite with no record is kept');
  assert.equal(timings.source.browser, 'seed browser');
  assert.match(timings.source.objectscript, /^run 42: /);

  const partial = refreshTimings(current, records.slice(0, 1), 'run 42');
  assert.match(partial.problems.join('\n'), /the objectscript records are shard\(s\) 2 of 2, not one record per shard/);
  assert.deepEqual(partial.rewritten, [], 'a run missing a shard would drop that shard\'s classes, so nothing is rewritten');
});

/** A temporary timings file and a directory of records for the refresh CLI. */
function refreshFixture() {
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-refresh-'));
  const timingsPath = join(dir, 'ci-timings.json');
  const original = `${JSON.stringify({ source: { objectscript: 'seed', browser: 'seed browser' }, objectscript: { A: 1, 'Old.Gone': 9 }, browser: { 'x.browser-spec.mjs': 5 } }, null, 2)}\n`;
  writeFileSync(timingsPath, original);
  const records = join(dir, 'records');
  mkdirSync(records);
  for (const [shard, name, seconds] of [[1, 'B', 3.1], [2, 'A', 2.2]]) {
    writeFileSync(
      join(records, `objectscript-shard-${shard}.json`),
      JSON.stringify({ suite: 'objectscript', shard, shards: 2, offered: ['A', 'B'], assigned: [name], ran: [{ name, seconds, tests: 1, failed: 0, outcome: 'passed' }] })
    );
  }
  return { dir, timingsPath, original, records };
}

test('refresh --run downloads the run\'s records with gh and rewrites the timings file from them', () => {
  const { dir, timingsPath, original, records } = refreshFixture();
  try {
    const bin = join(dir, 'bin');
    const calls = join(dir, 'gh-calls');
    // gh run download lays each artifact out in a directory of its own name under --dir.
    writeStub(bin, 'gh', [
      'printf \'%s\\n\' "$*" >> "$OCUPILOT_GH_CALLS"',
      '[ "$OCUPILOT_GH_FAIL" = "1" ] && exit 1',
      'while [ $# -gt 0 ]; do [ "$1" = "--dir" ] && out="$2"; shift; done',
      'for file in "$OCUPILOT_GH_RECORDS"/*.json; do',
      '  name=$(basename "$file" .json)',
      '  mkdir -p "$out/ci-record-$name" && cp "$file" "$out/ci-record-$name/"',
      'done',
    ]);
    const refresh = (extra = {}) =>
      spawnSync(process.execPath, [SHARDS_CLI, 'refresh', '--run', '12345', '--timings', timingsPath], {
        encoding: 'utf8',
        env: stubEnv(bin, { OCUPILOT_GH_CALLS: calls, OCUPILOT_GH_RECORDS: records, OCUPILOT_GH_FAIL: '0', ...extra }),
      });

    const failed = refresh({ OCUPILOT_GH_FAIL: '1' });
    assert.equal(failed.status, 1, `a download that failed is a failure: ${failed.stdout}${failed.stderr}`);
    assert.match(failed.stderr, /gh run download 12345 did not finish/);
    assert.equal(readFileSync(timingsPath, 'utf8'), original, 'and nothing was rewritten');

    writeFileSync(join(records, 'garbage.json'), '{');
    const unreadable = refresh();
    assert.equal(unreadable.status, 1, `an unreadable record is a failure: ${unreadable.stdout}${unreadable.stderr}`);
    assert.match(unreadable.stderr, /ci-record-garbage\/garbage\.json is not readable JSON/, 'naming the file');
    assert.equal(readFileSync(timingsPath, 'utf8'), original, 'and nothing was rewritten');
    rmSync(join(records, 'garbage.json'));

    const run = refresh();
    assert.equal(run.status, 0, `${run.stdout}${run.stderr}`);
    assert.match(readFileSync(calls, 'utf8'), /^run download 12345 --pattern ci-record-\* --dir \S+$/m, "it asks gh for exactly that run's records");
    const rewritten = JSON.parse(readFileSync(timingsPath, 'utf8'));
    assert.deepEqual(rewritten.objectscript, { A: 2.2, B: 3.1 });
    assert.deepEqual(rewritten.browser, { 'x.browser-spec.mjs': 5 });
    assert.match(rewritten.source.objectscript, /^run 12345: /);
    assert.match(run.stdout, /rewritten/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('refresh --records reads a directory, and refuses one that holds no record', () => {
  const { dir, timingsPath, records } = refreshFixture();
  try {
    const run = spawnSync(process.execPath, [SHARDS_CLI, 'refresh', '--records', records, '--timings', timingsPath], { encoding: 'utf8' });
    assert.equal(run.status, 0, `${run.stdout}${run.stderr}`);
    assert.deepEqual(JSON.parse(readFileSync(timingsPath, 'utf8')).objectscript, { A: 2.2, B: 3.1 });
    const empty = join(dir, 'empty');
    mkdirSync(empty);
    const none = spawnSync(process.execPath, [SHARDS_CLI, 'refresh', '--records', empty, '--timings', timingsPath], { encoding: 'utf8' });
    assert.equal(none.status, 1);
    assert.match(none.stderr, /holds no shard record/);
    const both = spawnSync(process.execPath, [SHARDS_CLI, 'refresh', '--run', '1', '--records', empty], { encoding: 'utf8' });
    assert.equal(both.status, 2, 'one source or the other, never both');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

// --- ci-runner.mjs, executed through a stub docker -----------------------------------------------

/** The fixture classes in the order the stub instance offers them: deliberately not name order. */
const CLASSES = ['Golf', 'Alpha', 'Echo', 'Bravo', 'Foxtrot', 'Charlie', 'Delta'].map((name) => `OcuPilot.Test.${name}`);

/** Recorded seconds for all but Golf, which weighs the median of the rest, 25. */
const CLASS_TIMINGS = { Alpha: 50, Bravo: 40, Charlie: 30, Delta: 20, Echo: 10, Foxtrot: 5 };

/** Longest first from CLASS_TIMINGS over three shards, each share in the order the instance offered. */
const CLASS_SHARES = [
  ['Alpha', 'Echo'],
  ['Bravo', 'Delta'],
  ['Golf', 'Foxtrot', 'Charlie'],
].map((share) => share.map((name) => `OcuPilot.Test.${name}`));

/**
 * A temporary checkout holding copies of the runner, the shard module and the session script, the
 * fixture classes on disk, a timings file, and a stub `docker`. The stub answers a list session
 * with CLASSES and a class session with a landed run of `OCUPILOT_STUB_TOTAL` methods (default 3)
 * whose index is the next in its counter file; the class named in `OCUPILOT_STUB_FAIL` fails one.
 */
function runnerTree() {
  const root = mkdtempSync(join(tmpdir(), 'ocupilot-shard-runner-'));
  mkdirSync(join(root, 'ui', 'tools'), { recursive: true });
  mkdirSync(join(root, 'scripts'));
  mkdirSync(join(root, 'src', 'OcuPilot', 'Test'), { recursive: true });
  for (const file of ['ci-runner.mjs', 'ci-shards.mjs']) copyFileSync(join(here, file), join(root, 'ui', 'tools', file));
  copyFileSync(join(REPO_ROOT, 'scripts', 'ci-unit-test.sh'), join(root, 'scripts', 'ci-unit-test.sh'));
  for (const name of CLASSES) {
    writeFileSync(
      join(root, 'src', 'OcuPilot', 'Test', `${name.split('.').pop()}.cls`),
      `Class ${name} Extends %UnitTest.TestCase\n{\n\nMethod TestOne()\n{\n}\n\n}\n`
    );
  }
  const timings = Object.fromEntries(Object.entries(CLASS_TIMINGS).map(([name, seconds]) => [`OcuPilot.Test.${name}`, seconds]));
  writeFileSync(join(root, 'ui', 'tools', 'ci-timings.json'), JSON.stringify({ source: {}, objectscript: timings, browser: {} }));
  const bin = join(root, 'bin');
  writeStub(bin, 'docker', [
    'printf \'%s\\n\' "$*" >> "$OCUPILOT_STUB_CALLS"',
    'input=$(cat)',
    'case "$input" in',
    '  *LIST-START*) printf \'%s\\n\' "OCUPILOT-LIST-START:$OCUPILOT_STUB_CLASSES:OCUPILOT-LIST-END"; exit 0 ;;',
    'esac',
    'n=$(cat "$OCUPILOT_STUB_COUNTER" 2>/dev/null || echo 0)',
    'n=$((n + 1))',
    'printf \'%s\' "$n" > "$OCUPILOT_STUB_COUNTER"',
    'failed=0',
    'fails="[]"',
    'if [ -n "$OCUPILOT_STUB_FAIL" ]; then',
    '  case "$input" in',
    '    *"RunTest(\\":$OCUPILOT_STUB_FAIL\\""*)',
    '      failed=1',
    '      fails="[{\\"class\\":\\"$OCUPILOT_STUB_FAIL\\",\\"method\\":\\"TestOne\\",\\"action\\":\\"\\",\\"error\\":\\"\\",\\"asserts\\":[{\\"action\\":\\"AssertEquals\\",\\"description\\":\\"stub failure\\",\\"location\\":\\"TestOne+1\\"}]}]"',
    '      ;;',
    '  esac',
    'fi',
    'printf \'%s\\n\' "OCUPILOT-PROBEAPPS-BEFORE-START::OCUPILOT-PROBEAPPS-BEFORE-END"',
    'printf \'%s\\n\' "OCUPILOT-RUN-START:$n:${OCUPILOT_STUB_TOTAL:-3}:$failed:1:1:OCUPILOT-RUN-END"',
    'printf \'%s\\n\' "OCUPILOT-FAILS-START:$fails:OCUPILOT-FAILS-END"',
    'printf \'%s\\n\' "OCUPILOT-PROBEAPPS-START::OCUPILOT-PROBEAPPS-END"',
  ]);
  const run = (args, extra = {}) => {
    const result = spawnSync(process.execPath, [join(root, 'ui', 'tools', 'ci-runner.mjs'), '--container', 'stub', ...args], {
      encoding: 'utf8',
      cwd: root,
      env: stubEnv(bin, {
        OCUPILOT_STUB_CALLS: join(root, 'docker-calls'),
        OCUPILOT_STUB_CLASSES: CLASSES.join(','),
        OCUPILOT_STUB_COUNTER: join(root, 'run-counter'),
        OCUPILOT_STUB_FAIL: '',
        ...extra,
      }),
    });
    return { ...result, output: `${result.stdout}${result.stderr}` };
  };
  return { root, run, records: join(root, 'records') };
}

/** The classes a runner's output reports, in the order it ran them. */
const reported = (stdout) => [...stdout.matchAll(/^ {2}\S+\s+(OcuPilot\.Test\.\S+) -- /gm)].map((match) => match[1]);

// Mutation (Rule 19): default an absent --shard to 1/3 -> this goes red.
test('without --shard the runner lists, floor-checks and runs every class with its usual lines, and writes no record', () => {
  const tree = runnerTree();
  try {
    const result = tree.run([]);
    assert.equal(result.status, 0, result.output);
    assert.match(result.stdout, /^ci-runner: the checkout carries 7 test class\(es\); the instance offered 7$/m);
    assert.match(result.stdout, /^ci-runner: running 7 test class\(es\), one at a time \(DW-54\)$/m);
    assert.deepEqual(reported(result.stdout), CLASSES, 'every class, in the order the instance offered them');
    assert.match(result.stdout, /^ci-runner: 7 class\(es\), 21 test\(s\), 0 failed, /m);
    assert.match(result.stdout, /^ci-runner: green\.$/m);
    assert.doesNotMatch(result.output, /shard/, 'and no shard label anywhere');
    const json = readdirSync(tree.root, { recursive: true }).filter((path) => String(path).endsWith('.json'));
    assert.deepEqual(json, [join('ui', 'tools', 'ci-timings.json')], 'no record is written, in the working directory or the tree');
  } finally {
    rmSync(tree.root, { recursive: true, force: true });
  }
});

// Mutation (Rule 19): write the record only when --shard is given -> this goes red.
test('--record without --shard writes every class the whole run ran, as shard 1 of 1, with no shard label', () => {
  const tree = runnerTree();
  try {
    const recordPath = join(tree.records, 'objectscript-whole.json');
    const result = tree.run(['--record', recordPath]);
    assert.equal(result.status, 0, result.output);
    assert.doesNotMatch(result.output, /shard/, 'the output is the unsharded run');
    const record = JSON.parse(readFileSync(recordPath, 'utf8'));
    assert.deepEqual(
      { suite: record.suite, shard: record.shard, shards: record.shards, offered: record.offered, assigned: record.assigned },
      { suite: 'objectscript', shard: 1, shards: 1, offered: CLASSES, assigned: CLASSES }
    );
    assert.deepEqual(record.ran.map((item) => item.name), CLASSES, 'every class, in the order the instance offered them');
  } finally {
    rmSync(tree.root, { recursive: true, force: true });
  }
});

// Mutation (Rule 19): skip the on-disk floor check when --shard is given -> this goes red.
test('a shard still refuses when the instance offers fewer classes than the checkout carries, naming the class', () => {
  // The `instance` roll-up holds the legs only to the list they were offered, so a class that did
  // not compile, and so was never offered, is caught by each leg's floor or by nothing.
  const tree = runnerTree();
  try {
    const offered = CLASSES.filter((name) => name !== 'OcuPilot.Test.Echo');
    const result = tree.run(['--shard', '1/3'], { OCUPILOT_STUB_CLASSES: offered.join(',') });
    assert.equal(result.status, 1, result.output);
    assert.match(result.stdout, /^ci-runner: the checkout carries 7 test class\(es\); the instance offered 6$/m);
    assert.match(result.stderr, /the instance did not offer 1 test class\(es\) the checkout carries -- OcuPilot\.Test\.Echo\. A suite that ran a subset is a failure, never a pass/);
    assert.deepEqual(reported(result.stdout), [], 'and no class ran');
  } finally {
    rmSync(tree.root, { recursive: true, force: true });
  }
});

// Mutations (Rule 19): drop the coverage check, or the zero-tests check, from checkRecords -> this
// goes red.
test('three shards run disjoint shares in the instance order, and their records pass the roll-up until a class goes missing', () => {
  const tree = runnerTree();
  try {
    for (let k = 1; k <= 3; k += 1) {
      const result = tree.run(['--shard', `${k}/3`, '--record', join(tree.records, `objectscript-shard-${k}.json`)]);
      const share = CLASS_SHARES[k - 1];
      assert.equal(result.status, 0, result.output);
      assert.match(result.stdout, new RegExp(`^ci-runner: shard ${k}/3 -- running ${share.length} of 7 test class\\(es\\), one at a time \\(DW-54\\)$`, 'm'));
      assert.deepEqual(reported(result.stdout), share, `shard ${k}/3 runs its share, in the instance's order`);
      assert.match(result.stdout, new RegExp(`^ci-runner: shard ${k}/3 -- green\\.$`, 'm'));
      const record = JSON.parse(readFileSync(join(tree.records, `objectscript-shard-${k}.json`), 'utf8'));
      assert.deepEqual(
        { suite: record.suite, shard: record.shard, shards: record.shards, offered: record.offered, assigned: record.assigned },
        { suite: 'objectscript', shard: k, shards: 3, offered: CLASSES, assigned: share }
      );
      assert.deepEqual(record.ran.map((item) => [item.name, item.tests, item.failed, item.outcome]), share.map((name) => [name, 3, 0, 'passed']));
      assert.ok(record.ran.every((item) => typeof item.seconds === 'number' && item.seconds >= 0), 'each with its seconds');
    }

    const rollUp = () =>
      spawnSync(process.execPath, [SHARDS_CLI, 'check', '--suite', 'objectscript', '--shards', '3', '--records', tree.records, '--result', 'success'], {
        encoding: 'utf8',
      });
    const complete = rollUp();
    assert.equal(complete.status, 0, `${complete.stdout}${complete.stderr}`);
    assert.match(complete.stdout, /every one of 7 class\(es\) ran in exactly one of 3 shard\(s\)/);
    assert.match(complete.stdout, /^ci-shards: objectscript shard 3\/3 -- 3 class\(es\), 9 test\(s\), /m);

    const path = join(tree.records, 'objectscript-shard-1.json');
    const original = readFileSync(path, 'utf8');
    const record = JSON.parse(original);
    writeFileSync(path, JSON.stringify({ ...record, ran: record.ran.filter((item) => item.name !== 'OcuPilot.Test.Echo') }));
    const dropped = rollUp();
    assert.equal(dropped.status, 1, 'a class that ran in no shard fails the roll-up');
    assert.match(dropped.stderr, /1 of 7 class\(es\) ran in no shard: OcuPilot\.Test\.Echo/, 'naming it');

    writeFileSync(path, JSON.stringify({ ...record, ran: record.ran.map((item) => ({ ...item, tests: 0 })) }));
    const empty = rollUp();
    assert.equal(empty.status, 1, 'a shard that executed no test fails the roll-up');
    assert.match(empty.stderr, /shard 1\/3 executed 0 tests/, 'naming the shard');
  } finally {
    rmSync(tree.root, { recursive: true, force: true });
  }
});

// Mutation (Rule 19): drop the shard label from ci-runner's problem lines -> this goes red.
test('a failing class in shard 2 is named with its shard, and the record is still written', () => {
  const tree = runnerTree();
  try {
    const recordPath = join(tree.records, 'objectscript-shard-2.json');
    const result = tree.run(['--shard', '2/3', '--record', recordPath], { OCUPILOT_STUB_FAIL: 'OcuPilot.Test.Delta' });
    assert.equal(result.status, 1, result.output);
    assert.match(result.stdout, /^ {2}FAILED {5}OcuPilot\.Test\.Delta -- 3 test\(s\), 1 failed, /m, 'the usual per-class line');
    assert.match(result.stdout, /^ci-runner: shard 2\/3 -- 2 class\(es\), 6 test\(s\), 1 failed, /m);
    assert.match(result.stderr, /^ci-runner: shard 2\/3 -- found problems --$/m);
    assert.match(result.stderr, /^ {2}shard 2\/3: OcuPilot\.Test\.Delta: 1 of 3 test\(s\) failed/m, 'the problem names the shard and the class');
    const record = JSON.parse(readFileSync(recordPath, 'utf8'));
    assert.deepEqual(record.ran.map((item) => [item.name, item.outcome]), [['OcuPilot.Test.Bravo', 'passed'], ['OcuPilot.Test.Delta', 'failed']]);
  } finally {
    rmSync(tree.root, { recursive: true, force: true });
  }
});

test('a shard whose classes executed no test, or that was assigned none, names itself and fails', () => {
  const tree = runnerTree();
  try {
    const zero = tree.run(['--shard', '1/3'], { OCUPILOT_STUB_TOTAL: '0' });
    assert.equal(zero.status, 1, zero.output);
    assert.match(zero.stderr, /^ {2}shard 1\/3: its 2 test class\(es\) executed 0 tests -- which is a failure, never a pass$/m);

    const recordPath = join(tree.records, 'objectscript-shard-9.json');
    const idle = tree.run(['--shard', '9/9', '--record', recordPath]);
    assert.equal(idle.status, 1, idle.output);
    assert.match(idle.stdout, /^ci-runner: shard 9\/9 -- running 0 of 7 test class\(es\), one at a time \(DW-54\)$/m);
    assert.match(idle.stderr, /^ {2}shard 9\/9: was assigned none of the 7 test class\(es\) the instance offered/m);
    assert.deepEqual(JSON.parse(readFileSync(recordPath, 'utf8')).ran, [], 'and its record says it ran nothing');
  } finally {
    rmSync(tree.root, { recursive: true, force: true });
  }
});

test('a bad --shard, or --shard beside --class, is a usage refusal before any session', () => {
  const tree = runnerTree();
  try {
    for (const args of [['--shard', '0/3'], ['--shard', '4/3'], ['--shard', 'x'], ['--shard', '1/3', '--class', 'OcuPilot.Test.Alpha'], ['--shard']]) {
      const result = tree.run(args);
      assert.equal(result.status, 2, `${args.join(' ')}: ${result.output}`);
      assert.match(result.stderr, /^ci-runner: --shard /m, `${args.join(' ')} is refused naming --shard`);
    }
    assert.ok(!existsSync(join(tree.root, 'docker-calls')), 'and no session was opened');
  } finally {
    rmSync(tree.root, { recursive: true, force: true });
  }
});

// --- ci-browser.mjs, executed over fixture spec files -----------------------------------------

/** A directory of fixture spec files and a timings file, as `{dir, timings}`. */
function specFixture(files, timings) {
  const dir = mkdtempSync(join(tmpdir(), 'ocupilot-shard-specs-'));
  for (const [name, body] of Object.entries(files)) {
    writeFileSync(join(dir, name), `import { test } from 'node:test';\n${body}\n`);
  }
  writeFileSync(join(dir, 'timings.json'), JSON.stringify({ source: {}, objectscript: {}, browser: timings }));
  writeFileSync(join(dir, 'helper-spec.mjs'), "throw new Error('a helper module is never run as a spec file');\n");
  return { dir, timings: join(dir, 'timings.json') };
}

const runBrowserShard = (fixture, args) => {
  const result = spawnSync(process.execPath, [BROWSER_CLI, '--dir', fixture.dir, '--timings', fixture.timings, ...args], { encoding: 'utf8' });
  return { ...result, output: `${result.stdout}${result.stderr}` };
};

const PASSING = "test('passes', () => {});";

test('a browser shard runs its share in sorted order, one file at a time, and records each file', () => {
  // bravo (40) opens shard 1 and delta (30) shard 2, which alpha (5) then joins: shard 2's
  // assignment order is delta, alpha, and it runs alpha first because the share is sorted.
  const fixture = specFixture(
    {
      'alpha.browser-spec.mjs': `${PASSING}\ntest('passes too', () => {});`,
      'bravo.browser-spec.mjs': `${PASSING}\ntest('fails', () => { throw new Error('boom'); });`,
      'delta.browser-spec.mjs': PASSING,
    },
    { 'alpha.browser-spec.mjs': 5, 'bravo.browser-spec.mjs': 40, 'delta.browser-spec.mjs': 30 }
  );
  try {
    const recordPath = join(fixture.dir, 'records', 'browser-shard-2.json');
    const result = runBrowserShard(fixture, ['--shard', '2/2', '--record', recordPath]);
    assert.equal(result.status, 0, result.output);
    assert.match(result.stdout, /^ci-browser: shard 2\/2 -- running 2 of 3 spec file\(s\), one at a time$/m);
    assert.match(result.stdout, /^TAP version 13$/m, "each file's TAP reaches stdout");
    assert.match(result.stdout, /^ci-browser: shard 2\/2 -- 2 spec file\(s\), 3 test\(s\) executed, 0 failed, 0 skipped$/m);
    const record = JSON.parse(readFileSync(recordPath, 'utf8'));
    assert.deepEqual(
      { suite: record.suite, shard: record.shard, shards: record.shards, offered: record.offered, assigned: record.assigned },
      { suite: 'browser', shard: 2, shards: 2, offered: ['alpha.browser-spec.mjs', 'bravo.browser-spec.mjs', 'delta.browser-spec.mjs'], assigned: ['alpha.browser-spec.mjs', 'delta.browser-spec.mjs'] }
    );
    assert.deepEqual(
      record.ran.map((item) => [item.name, item.tests, item.failed, item.outcome]),
      [['alpha.browser-spec.mjs', 2, 0, 'passed'], ['delta.browser-spec.mjs', 1, 0, 'passed']],
      'sorted, with the counts each file reported'
    );
    assert.ok(record.ran.every((item) => item.seconds > 0), 'and the seconds each took');
  } finally {
    rmSync(fixture.dir, { recursive: true, force: true });
  }
});

test('a failing spec file is named with its shard, its record is written, and the roll-up names both', () => {
  const fixture = specFixture(
    {
      'alpha.browser-spec.mjs': PASSING,
      'bravo.browser-spec.mjs': `${PASSING}\ntest('fails', () => { throw new Error('boom'); });`,
    },
    { 'alpha.browser-spec.mjs': 5, 'bravo.browser-spec.mjs': 40 }
  );
  try {
    const records = join(fixture.dir, 'records');
    const failing = runBrowserShard(fixture, ['--shard', '1/2', '--record', join(records, 'browser-shard-1.json')]);
    assert.equal(failing.status, 1, failing.output);
    assert.match(failing.stdout, /^ {2}FAILED {5}bravo\.browser-spec\.mjs -- 1 passed, 1 failed, 0 skipped, /m);
    assert.match(failing.stderr, /^ci-browser: shard 1\/2 -- bravo\.browser-spec\.mjs: 1 of 2 test\(s\) failed$/m);
    const passing = runBrowserShard(fixture, ['--shard', '2/2', '--record', join(records, 'browser-shard-2.json')]);
    assert.equal(passing.status, 0, passing.output);

    const rollUp = spawnSync(
      process.execPath,
      [SHARDS_CLI, 'check', '--suite', 'browser', '--shards', '2', '--records', records, '--result', 'failure', '--dir', fixture.dir],
      { encoding: 'utf8' }
    );
    assert.equal(rollUp.status, 1);
    assert.match(rollUp.stderr, /the browser shard jobs' result is "failure"/);
    assert.match(rollUp.stderr, /shard 1\/2: bravo\.browser-spec\.mjs failed/);
    assert.doesNotMatch(rollUp.stderr, /ran in no shard|more than one shard/, 'the split itself was whole');
  } finally {
    rmSync(fixture.dir, { recursive: true, force: true });
  }
});

test('a browser shard whose every test skipped executed nothing, and fails naming the shard', () => {
  const fixture = specFixture({ 'charlie.browser-spec.mjs': "test('needs an instance', { skip: 'no instance' }, () => {});" }, {});
  try {
    const recordPath = join(fixture.dir, 'records', 'browser-shard-1.json');
    const result = runBrowserShard(fixture, ['--shard', '1/1', '--record', recordPath]);
    assert.equal(result.status, 1, result.output);
    assert.match(result.stderr, /^ci-browser: shard 1\/1 -- its 1 spec file\(s\) executed 0 tests \(1 skipped\) -- which is a failure, never a pass$/m);
    assert.deepEqual(JSON.parse(readFileSync(recordPath, 'utf8')).ran.map((item) => item.tests), [0], 'and the record is written');
  } finally {
    rmSync(fixture.dir, { recursive: true, force: true });
  }
});

// Mutation (Rule 19): collapse ci-browser's share.length === 0 branch into the general zero-tests
// message -> this goes red.
test('a browser shard assigned no spec file names itself distinctly from a skipped-all shard, and its record says it ran nothing', () => {
  const fixture = specFixture({ 'alpha.browser-spec.mjs': PASSING, 'bravo.browser-spec.mjs': PASSING }, {});
  try {
    const recordPath = join(fixture.dir, 'records', 'browser-shard-3.json');
    const result = runBrowserShard(fixture, ['--shard', '3/3', '--record', recordPath]);
    assert.equal(result.status, 1, result.output);
    assert.match(result.stdout, /^ci-browser: shard 3\/3 -- running 0 of 2 spec file\(s\), one at a time$/m);
    assert.match(
      result.stderr,
      /^ci-browser: shard 3\/3 -- was assigned none of the 2 spec file\(s\), so it executed 0 tests -- which is a failure, never a pass$/m
    );
    const record = JSON.parse(readFileSync(recordPath, 'utf8'));
    assert.deepEqual(record.assigned, [], 'the record says the shard was assigned nothing');
    assert.deepEqual(record.ran, [], 'and that it ran nothing');
  } finally {
    rmSync(fixture.dir, { recursive: true, force: true });
  }
});

test('a spec file whose test timed out fails its shard, although no test reported a failure', () => {
  const fixture = specFixture(
    {
      'alpha.browser-spec.mjs': PASSING,
      'hang.browser-spec.mjs': "test('hangs', { timeout: 50 }, async () => { await new Promise((done) => setTimeout(done, 500)); });",
    },
    {}
  );
  try {
    const recordPath = join(fixture.dir, 'records', 'browser-shard-1.json');
    const result = runBrowserShard(fixture, ['--shard', '1/1', '--record', recordPath]);
    assert.equal(result.status, 1, result.output);
    assert.match(result.stderr, /^ci-browser: shard 1\/1 -- hang\.browser-spec\.mjs: /m, 'naming the shard and the file');
    assert.deepEqual(
      JSON.parse(readFileSync(recordPath, 'utf8')).ran.map((item) => [item.name, item.outcome]),
      [['alpha.browser-spec.mjs', 'passed'], ['hang.browser-spec.mjs', 'failed']]
    );
  } finally {
    rmSync(fixture.dir, { recursive: true, force: true });
  }
});

test('the browser roll-up holds the legs to the spec files the checkout carries, not only to what they were offered', () => {
  const fixture = specFixture({ 'alpha.browser-spec.mjs': PASSING, 'bravo.browser-spec.mjs': PASSING }, {});
  try {
    const records = join(fixture.dir, 'records');
    const leg = runBrowserShard(fixture, ['--shard', '1/1', '--record', join(records, 'browser-shard-1.json')]);
    assert.equal(leg.status, 0, leg.output);
    writeFileSync(join(fixture.dir, 'charlie.browser-spec.mjs'), `import { test } from 'node:test';\n${PASSING}\n`);
    const rollUp = spawnSync(
      process.execPath,
      [SHARDS_CLI, 'check', '--suite', 'browser', '--shards', '1', '--records', records, '--result', 'success', '--dir', fixture.dir],
      { encoding: 'utf8' }
    );
    assert.equal(rollUp.status, 1, `${rollUp.stdout}${rollUp.stderr}`);
    assert.match(rollUp.stderr, /only in the checkout: charlie\.browser-spec\.mjs/);
    assert.match(rollUp.stderr, /1 of 3 spec file\(s\) ran in no shard: charlie\.browser-spec\.mjs/);
  } finally {
    rmSync(fixture.dir, { recursive: true, force: true });
  }
});

test('ci-browser refuses to run without --shard, or with a bad one', () => {
  for (const args of [[], ['--shard', '0/3'], ['--shard', '3/2'], ['--bogus', 'x']]) {
    const result = spawnSync(process.execPath, [BROWSER_CLI, ...args], { encoding: 'utf8' });
    assert.equal(result.status, 2, `${JSON.stringify(args)}: ${result.stdout}${result.stderr}`);
    assert.match(result.stderr, /^ci-browser: /m);
  }
});

// --- The npm scripts ---------------------------------------------------------------------------

test('the unsharded browser scripts are unchanged, and the shard build is the same harness build', () => {
  const HARNESS_BUILD = 'ng build --configuration production,harness';
  const { scripts } = JSON.parse(readFileSync(join(here, '..', 'package.json'), 'utf8'));
  assert.equal(scripts['test:browser'], 'node --test --test-concurrency=1 browser/*.browser-spec.mjs');
  assert.equal(scripts['pretest:browser'], HARNESS_BUILD);
  assert.equal(scripts['pretest:browser:shard'], HARNESS_BUILD, 'the data-table specs load the harness, so a shard builds it too');
  assert.equal(scripts['test:browser:shard'], 'node tools/ci-browser.mjs');
  assert.ok(readdirSync(here).includes('ci-browser.mjs'));
});
