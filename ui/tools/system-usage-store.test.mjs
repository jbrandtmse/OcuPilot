import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins System usage's own state (`areas/os-management/system-usage.store.ts`, Story 6.9): the
// percent computation, each meter kind's resolved view, and the two load-bearing behaviors the
// spec's "Meter fault" row names -- a fault keeps the last good value and dashes nothing at this
// layer (only `meter.ts` dashes the display), and a screen that has never loaded reads every
// track meter as pending (no value, no word, no error).
//
// Mutations (Rule 19):
// - divide by zero instead of guarding `denominator === 0` in `percentFromFields` -> the "zero
//   allocation reads pending, not a percentage" case below goes red with `Infinity` or `NaN`.
// - drop the `PENDING_STATE` fallback from `meterViewFor`'s 'status'/'percent' branches, reading
//   `state: null` before load -> the "before any success" case goes red, since `meter.ts` would
//   then misread the meter as a value meter (see that file's own header).
// - stop passing `error` through on a loaded meter -> the "fault after a success keeps the value
//   and carries the fault text" case goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const store = await import(join(uiRoot, 'src', 'app', 'areas', 'os-management', 'system-usage.store.ts'));

const LOADED_ROW = {
  'Usage.AllGlobalReferences': 12345,
  'Usage.LastUpdate': '2026-09-17 10:30:00',
  'SharedMemory.SMHAllocated': 1000,
  'SharedMemory.SMHUsed': 900,
  'Dashboard.Performance.GlobalRefsPerSecond': 42.5,
  'Dashboard.SystemUsage.DatabaseSpace': 'Normal',
  'Dashboard.SystemUsage.WriteDaemon': 'Troubled',
};

test('numberField and stringField read a flat dotted key, or null when it is absent or the wrong type', () => {
  assert.equal(store.numberField(LOADED_ROW, 'Usage.AllGlobalReferences'), 12345);
  assert.equal(store.numberField(LOADED_ROW, 'Usage.LastUpdate'), null, 'a string field is not a number');
  assert.equal(store.numberField(undefined, 'Usage.AllGlobalReferences'), null);
  assert.equal(store.stringField(LOADED_ROW, 'Dashboard.SystemUsage.DatabaseSpace'), 'Normal');
  assert.equal(store.stringField(LOADED_ROW, 'Usage.AllGlobalReferences'), null, 'a number field is not a string');
});

test('isCounterField: every Usage.* field, and no other', () => {
  assert.equal(store.isCounterField('Usage.AllGlobalReferences'), true);
  assert.equal(store.isCounterField('Usage.LastUpdate'), true);
  assert.equal(store.isCounterField('SharedMemory.SMHUsed'), false);
  assert.equal(store.isCounterField('Dashboard.Performance.GlobalRefsPerSecond'), false);
});

test('sharedMemoryPercent: used over allocated as a percentage, null when either is missing or allocated is zero', () => {
  assert.equal(store.sharedMemoryPercent(LOADED_ROW), 90);
  assert.equal(store.sharedMemoryPercent(undefined), null, 'nothing has loaded yet');
  assert.equal(
    store.sharedMemoryPercent({ 'SharedMemory.SMHUsed': 5, 'SharedMemory.SMHAllocated': 0 }),
    null,
    'a zero allocation is read as pending, never as a division'
  );
});

test('meterViewFor: a value meter carries no percent, state or word, whatever the row holds', () => {
  const config = { kind: 'value', label: 'Global references per second', field: 'Dashboard.Performance.GlobalRefsPerSecond' };
  assert.deepEqual(store.meterViewFor(config, LOADED_ROW, null), {
    label: 'Global references per second',
    unit: '',
    error: null,
    value: 42.5,
    percent: null,
    state: null,
    word: null,
  });
  assert.equal(store.meterViewFor(config, undefined, null).value, null, 'pending before load');
});

test('meterViewFor: a percent meter (Shared memory) computes state and word from the percentage once loaded', () => {
  const config = { kind: 'percent', label: 'Shared memory', field: 'SharedMemory.SMHUsed', denominatorField: 'SharedMemory.SMHAllocated' };
  const view = store.meterViewFor(config, LOADED_ROW, null);
  assert.equal(view.value, 90, 'the readout is the percentage, not the used figure');
  assert.equal(view.unit, '%');
  assert.equal(view.percent, 90);
  assert.equal(view.state, 'warning', '90 is at or above the 85 cut-off');
  assert.equal(view.word, 'Warning');
});

test('meterViewFor: a status meter (Database space, Write daemon) reads the vendor word', () => {
  const database = store.meterViewFor(
    { kind: 'status', label: 'Database space', field: 'Dashboard.SystemUsage.DatabaseSpace' },
    LOADED_ROW,
    null
  );
  assert.equal(database.value, null, 'a status meter carries no numeric value');
  assert.equal(database.state, 'normal');
  assert.equal(database.word, 'Normal');

  const daemon = store.meterViewFor(
    { kind: 'status', label: 'Write daemon', field: 'Dashboard.SystemUsage.WriteDaemon' },
    LOADED_ROW,
    null
  );
  assert.equal(daemon.state, 'error');
  assert.equal(daemon.word, 'Troubled');
});

test('meterViewFor: before any success, a track meter (percent or status) carries a non-null placeholder state, no word, no value, no error', () => {
  for (const config of [
    { kind: 'percent', label: 'Shared memory', field: 'SharedMemory.SMHUsed', denominatorField: 'SharedMemory.SMHAllocated' },
    { kind: 'status', label: 'Database space', field: 'Dashboard.SystemUsage.DatabaseSpace' },
  ]) {
    const view = store.meterViewFor(config, undefined, null);
    assert.equal(view.value, null, `${config.label}: no value yet`);
    assert.equal(view.word, null, `${config.label}: no word yet`);
    assert.equal(view.state, 'normal', `${config.label}: state is the non-null placeholder for a track meter (meter.ts reads null as "value meter")`);
    assert.equal(view.error, null, `${config.label}: no fault yet either`);
  }
});

test('meterViewFor: a fault after a success keeps the last value and word, and carries the fault text', () => {
  const config = { kind: 'status', label: 'Write daemon', field: 'Dashboard.SystemUsage.WriteDaemon' };
  const beforeFault = store.meterViewFor(config, LOADED_ROW, null);
  const duringFault = store.meterViewFor(config, LOADED_ROW, 'request refused');
  assert.equal(duringFault.word, beforeFault.word, 'the last word is kept');
  assert.equal(duringFault.state, beforeFault.state, 'and the last state');
  assert.equal(duringFault.error, 'request refused');
});

test('METER_CONFIGS declares the seven meters, Shared memory first and the two value meters last', () => {
  assert.equal(store.METER_CONFIGS.length, 7);
  assert.equal(store.METER_CONFIGS[0].kind, 'percent');
  assert.deepEqual(
    store.METER_CONFIGS.slice(1, 5).map((config) => config.kind),
    ['status', 'status', 'status', 'status']
  );
  assert.deepEqual(
    store.METER_CONFIGS.slice(5).map((config) => config.kind),
    ['value', 'value']
  );
});
