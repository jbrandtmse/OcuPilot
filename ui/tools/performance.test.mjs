import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins Home's performance row store (Story 16.18): what its refresh read answers the framework
// for a success, a 403 and a fault; the line's points, which are only the answers received and
// never older than ten minutes; the pure drawing and formatting; and the two cross-file names the
// row shares with the instance.
//
// Mutations (Rule 19):
// - append a point on a 403 in `read` -> "a 403 clears the row" and "the line starts empty" go red.
// - keep points older than 600 s in `read` -> "points older than ten minutes are dropped" goes red.
// - let a 403 answer `kind: 'fault'` -> "a 403 clears the row" goes red on the returned kind.
// - drop the `request` guard -> "only the newest answer writes" goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = join(uiRoot, '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const {
  PERFORMANCE_FIELDS,
  PERFORMANCE_PATH,
  PerformanceRow,
  SPARKLINE_WINDOW_MS,
  formatPerformance,
  sparklinePath,
} = await import(core('performance.ts'));
const { HOME_REFRESH_NAME } = await import(core('account-preferences.ts'));

const T0 = 1_700_000_000_000;

const VALUES = {
  cacheEfficiency: 8745.8,
  globalReferencesPerSecond: 47089,
  globalUpdatesPerSecond: 1203,
  diskReadsPerSecond: 12,
  diskWritesPerSecond: 34,
};

/** A row over a transport the test answers, with the clock in the test's hands. */
function harness() {
  const state = { now: T0, answers: [], calls: [] };
  const api = {
    requestJson: async (path, init = {}) => {
      state.calls.push({ path, init });
      const next = state.answers.shift();
      if (next === undefined) return { kind: 'ok', status: 200, body: { ...VALUES } };
      return typeof next === 'function' ? next() : next;
    },
  };
  const row = new PerformanceRow({ api, now: () => state.now });
  return { row, state };
}

const refused = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'x', detail: { failedPair: '%Admin_Operate:USE' } };
const serverFault = { kind: 'error', status: 500, code: 'INTERNAL', reason: 'x', detail: null };

test('a success answers one row of the five numbers, holds them, and plots one point at the client time', async () => {
  const { row, state } = harness();
  const result = await row.read();
  assert.deepEqual(result, { kind: 'ok', rows: [VALUES], truncated: false });
  assert.deepEqual(row.values(), VALUES);
  assert.equal(row.denied(), false);
  assert.deepEqual(row.points(), [{ at: T0, value: 47089 }]);
  assert.equal(state.calls[0].path, PERFORMANCE_PATH);
  assert.equal(state.calls[0].init.scope, null, 'instance metrics carry no namespace');
});

test('a 403 clears the row: an ok answer of no rows, no values, no points, and no fault', async () => {
  const { row, state } = harness();
  await row.read();
  state.now = T0 + 5_000;
  state.answers.push(refused);
  const result = await row.read();
  assert.deepEqual(result, { kind: 'ok', rows: [], truncated: false });
  assert.equal(row.values(), null);
  assert.equal(row.denied(), true);
  assert.deepEqual(row.points(), []);
});

test('the line starts empty: a first answer refused plots nothing, and the next success plots one point', async () => {
  const { row, state } = harness();
  state.answers.push(refused);
  await row.read();
  assert.deepEqual(row.points(), []);
  state.now = T0 + 5_000;
  await row.read();
  assert.deepEqual(row.points(), [{ at: T0 + 5_000, value: 47089 }]);
  assert.equal(row.denied(), false);
});

test('any other failure is a fault for the framework, and the last values and points stand', async () => {
  const { row, state } = harness();
  await row.read();
  for (const failure of [serverFault, { kind: 'error', status: 0, code: null, reason: null, detail: null }]) {
    state.answers.push(failure);
    const result = await row.read();
    assert.equal(result.kind, 'fault');
    assert.equal(result.fault.path, PERFORMANCE_PATH);
    assert.deepEqual(row.values(), VALUES);
    assert.equal(row.points().length, 1);
  }
});

test('before any success a fault leaves the row absent', async () => {
  const { row, state } = harness();
  state.answers.push(serverFault);
  const result = await row.read();
  assert.equal(result.kind, 'fault');
  assert.equal(row.values(), null);
  assert.equal(row.denied(), false);
});

test('an answer missing a member, or carrying one that is not a number, is a server fault, never a partial row', async () => {
  const { row, state } = harness();
  const { diskWritesPerSecond: _dropped, ...missing } = VALUES;
  for (const body of [missing, { ...VALUES, globalUpdatesPerSecond: '1203' }, { ...VALUES, diskReadsPerSecond: null }, []]) {
    state.answers.push({ kind: 'ok', status: 200, body });
    const result = await row.read();
    assert.equal(result.kind, 'fault', JSON.stringify(body));
    assert.equal(result.fault.kind, 'server-fault');
  }
  assert.equal(row.values(), null);
});

test('points older than ten minutes are dropped, so the line never spans more than 600 s', async () => {
  const { row, state } = harness();
  for (let step = 0; step <= 130; step += 1) {
    state.now = T0 + step * 5_000;
    await row.read();
  }
  const points = row.points();
  const last = points[points.length - 1].at;
  assert.ok(points.every((point) => point.at >= last - SPARKLINE_WINDOW_MS), 'no point is older than the window');
  assert.equal(points[0].at, last - SPARKLINE_WINDOW_MS, 'and the oldest is exactly ten minutes back');
  assert.equal(points.length, 121);
});

test('only the newest answer writes, and one that lands after clearHistory or reset writes nothing', async () => {
  const { row, state } = harness();
  let releaseSlow;
  state.answers.push(() => new Promise((resolve) => (releaseSlow = () => resolve({ kind: 'ok', status: 200, body: { ...VALUES, globalReferencesPerSecond: 1 } }))));
  const slow = row.read();
  await row.read();
  releaseSlow();
  await slow;
  assert.deepEqual(row.points().map((point) => point.value), [47089], 'the overtaken answer plotted nothing');

  state.answers.push(() => new Promise((resolve) => (releaseSlow = () => resolve({ kind: 'ok', status: 200, body: { ...VALUES } }))));
  const late = row.read();
  row.clearHistory();
  releaseSlow();
  await late;
  assert.deepEqual(row.points(), [], 'an answer for a Home view that closed does not land on the next');
});

test('clearHistory drops the line and keeps the values; reset forgets both', async () => {
  const { row, state } = harness();
  await row.read();
  state.now += 5_000;
  await row.read();
  let notified = 0;
  row.subscribe(() => (notified += 1));
  row.clearHistory();
  assert.deepEqual(row.points(), []);
  assert.deepEqual(row.values(), VALUES);
  assert.equal(notified, 1);
  state.answers.push(refused);
  await row.read();
  assert.equal(row.denied(), true);
  row.reset();
  assert.equal(row.values(), null);
  assert.equal(row.denied(), false);
});

test('sparklinePath draws nothing for fewer than two points', () => {
  assert.equal(sparklinePath([], T0, 120, 24), '');
  assert.equal(sparklinePath([{ at: T0, value: 5 }], T0, 120, 24), '');
});

test('sparklinePath: zero baseline, the largest value at the top, and x across ten minutes from the first point', () => {
  const points = [
    { at: T0, value: 0 },
    { at: T0 + 300_000, value: 50 },
    { at: T0 + 600_000, value: 100 },
  ];
  assert.equal(sparklinePath(points, T0 + 600_000, 120, 24), 'M0 24 L60 12 L120 0');
  // Two points five seconds apart sit at the left, not stretched across the box.
  assert.equal(sparklinePath(points.slice(0, 2).map((point, index) => ({ ...point, at: T0 + index * 5_000 })), T0 + 5_000, 120, 24), 'M0 24 L1 0');
  // All zero is a flat line on the baseline.
  assert.equal(sparklinePath([{ at: T0, value: 0 }, { at: T0 + 5_000, value: 0 }], T0 + 5_000, 120, 24), 'M0 24 L1 24');
});

test('sparklinePath scrolls once the window has passed, and leaves out a point before it', () => {
  const points = [
    { at: T0, value: 10 },
    { at: T0 + 300_000, value: 20 },
    { at: T0 + 900_000, value: 40 },
  ];
  assert.equal(sparklinePath(points, T0 + 900_000, 120, 24), 'M0 12 L120 0');
});

test('formatPerformance: rates are whole numbers with grouped digits, cache efficiency has one decimal', () => {
  assert.deepEqual(formatPerformance({ ...VALUES, globalReferencesPerSecond: 1234567.6, cacheEfficiency: 12345.67 }), {
    cacheEfficiency: '12,345.7',
    globalReferencesPerSecond: '1,234,568',
    globalUpdatesPerSecond: '1,203',
    diskReadsPerSecond: '12',
    diskWritesPerSecond: '34',
  });
  assert.equal(formatPerformance({ ...VALUES, cacheEfficiency: 0 }).cacheEfficiency, '0.0');
});

test('the five members are the ones OcuPilot.Port.MonitorPort answers, in its order', () => {
  const source = readFileSync(join(repoRoot, 'src', 'OcuPilot', 'Port', 'MonitorPort.cls'), 'utf8');
  const declared = /^Parameter METRICS = "([^"]*)";$/m.exec(source)[1].split(',').map((pair) => pair.split(':')[0]);
  assert.deepEqual([...PERFORMANCE_FIELDS], declared);
});

test("Home's rate name is the one OcuPilot.Kernel.State.Pref accepts for the refresh kind", () => {
  const source = readFileSync(join(repoRoot, 'src', 'OcuPilot', 'Kernel', 'State', 'Pref.cls'), 'utf8');
  assert.equal(/^Parameter HOMEREFRESHNAME As %String = "([^"]*)";$/m.exec(source)[1], HOME_REFRESH_NAME);
});
