import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins Database details' own state (`areas/os-management/database-details.store.ts`, Story 6.11):
// the one meter it draws for AvailableSpace, and which declared columns render as ordinary
// properties.
//
// Mutations (Rule 19):
// - change DATABASE_METER_CONFIG's field to 'Size' -> the meter-value assertion goes red, reading
//   the wrong figure.
// - drop the AvailableSpace exclusion from isPropertyField -> the property-field assertion for it
//   goes red, since the meter's own field would then also render as a plain property.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const store = await import(join(uiRoot, 'src', 'app', 'areas', 'os-management', 'database-details.store.ts'));
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

test('DATABASE_METER_CONFIG: one value meter, AvailableSpace, no percentage and no state', () => {
  assert.equal(store.DATABASE_METER_CONFIG.kind, 'value');
  assert.equal(store.DATABASE_METER_CONFIG.field, 'AvailableSpace');
  assert.equal(store.DATABASE_METER_CONFIG.label, STRINGS.databaseColumnAvailable);
  assert.equal(store.DATABASE_METER_CONFIG.denominatorField, undefined, 'a value meter declares no denominator');
});

test('availableSpaceMeterView: a value meter carries no percent, state or word, whatever the row holds', () => {
  const view = store.availableSpaceMeterView({ AvailableSpace: 3.1, Size: 70 }, null);
  assert.equal(view.value, 3.1);
  assert.equal(view.percent, null);
  assert.equal(view.state, null);
  assert.equal(view.word, null);
  assert.equal(view.error, null);
});

test('availableSpaceMeterView: a fault after a success keeps the last value and carries the fault text', () => {
  const loaded = { AvailableSpace: 3.1 };
  const view = store.availableSpaceMeterView(loaded, 'The instance is unreachable.');
  assert.equal(view.value, 3.1, 'the last-good row is still what the meter reads, per ScreenStore.applyTick');
  assert.equal(view.error, 'The instance is unreachable.');
});

test('availableSpaceMeterView: no row yet answers a null value, never zero', () => {
  const view = store.availableSpaceMeterView(undefined, null);
  assert.equal(view.value, null);
});

test('isPropertyField: every declared column but AvailableSpace, the meter\u2019s own field', () => {
  assert.equal(store.isPropertyField('AvailableSpace'), false);
  for (const field of [
    'Directory',
    'MaxSize',
    'ExpansionSize',
    'NewVolumeThreshold',
    'NewVolumeDirectory',
    'ResourceName',
    'NewGlobalIsKeep',
    'NewGlobalCollation',
    'ClusterMountMode',
    'ReadOnly',
    'GlobalJournalState',
    'Size',
    'DiskFree',
    'Mounted',
  ]) {
    assert.equal(store.isPropertyField(field), true, `${field} renders as an ordinary property`);
  }
});
