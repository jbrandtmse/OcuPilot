import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the screen store's table slots (AD-19): the view choices persisted per descriptor and
// restored when the store is created, the refused max-rows values (DW-17), and the scope switch
// clearing where the user was (DW-18).
//
// Mutations (Rule 19):
// - stop restoring the view map in the `ScreenStore` constructor -> "AC9" goes red.
// - let `setMaxRows` accept 0 -> "DW-17 bad cap" goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { ScreenStores, DEFAULT_MAX_ROWS } = await import(core('screen-store.ts'));
const { PreferenceStore, SCREEN_VIEWS_KEY } = await import(core('preferences.ts'));

function memoryStorage() {
  const map = new Map();
  return {
    getItem: (key) => (map.has(key) ? map.get(key) : null),
    setItem: (key, value) => map.set(key, value),
    removeItem: (key) => map.delete(key),
    map,
  };
}

const ONE = 'OcuPilot.Screen.Descriptor.One';
const TWO = 'OcuPilot.Screen.Descriptor.Two';

test('AC9: sort, direction, filter and max rows set on one store are restored by a new ScreenStores over the same storage', () => {
  const storage = memoryStorage();
  const first = new ScreenStores({ preferences: new PreferenceStore({ storage }) }).for(ONE, []);
  first.setSort('NameSpace');
  first.setDirection('desc');
  first.setFilter('csp');
  assert.equal(first.setMaxRows(5000), true);

  const stores = new ScreenStores({ preferences: new PreferenceStore({ storage }) });
  const restored = stores.for(ONE, []);
  assert.deepEqual(
    { sort: restored.sort(), direction: restored.direction(), filter: restored.filter(), maxRows: restored.maxRows() },
    { sort: 'NameSpace', direction: 'desc', filter: 'csp', maxRows: 5000 }
  );

  const other = stores.for(TWO, []);
  assert.deepEqual(
    { sort: other.sort(), direction: other.direction(), filter: other.filter(), maxRows: other.maxRows() },
    { sort: '', direction: '', filter: '', maxRows: DEFAULT_MAX_ROWS },
    "another descriptor's defaults are untouched"
  );
});

test('DW-17 bad cap: 0, -5, 2.5 and NaN change neither the store nor the preference', () => {
  const storage = memoryStorage();
  const store = new ScreenStores({ preferences: new PreferenceStore({ storage }) }).for(ONE, []);
  let notified = 0;
  store.subscribe(() => (notified += 1));
  for (const cap of [0, -5, 2.5, Number.NaN, Number.MAX_SAFE_INTEGER + 2]) {
    assert.equal(store.setMaxRows(cap), false, `refused: ${cap}`);
  }
  assert.equal(store.maxRows(), DEFAULT_MAX_ROWS);
  assert.equal(storage.map.has(SCREEN_VIEWS_KEY), false, 'nothing was remembered');
  assert.equal(notified, 0, 'and nobody was told of a change that did not happen');
});

test('a stored view of the wrong shape falls back field by field, without throwing', () => {
  const storage = memoryStorage();
  storage.setItem(SCREEN_VIEWS_KEY, JSON.stringify({ [ONE]: { sort: 3, direction: 'sideways', filter: 'x', maxRows: -1 } }));
  const store = new ScreenStores({ preferences: new PreferenceStore({ storage }) }).for(ONE, []);
  assert.deepEqual(
    { sort: store.sort(), direction: store.direction(), filter: store.filter(), maxRows: store.maxRows() },
    { sort: '', direction: '', filter: 'x', maxRows: DEFAULT_MAX_ROWS }
  );
  storage.setItem(SCREEN_VIEWS_KEY, '{not json');
  assert.doesNotThrow(() => new ScreenStores({ preferences: new PreferenceStore({ storage }) }).for(ONE, []));
});

test('DW-18 scope switch: clearAnswers drops rows, selection, active, changed and scroll, and keeps the choices', () => {
  const store = new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) }).for(ONE, []);
  store.applyTick([{ Name: 'A' }], true, new Date(0));
  store.setSelection(['A']);
  store.setActive('A');
  store.markChanged('A');
  store.setScroll(120);
  store.setFilter('a');
  store.setMaxRows(50);

  store.clearAnswers();

  assert.deepEqual(store.data(), []);
  assert.deepEqual(store.selection(), []);
  assert.equal(store.active(), '');
  assert.equal(store.changed().size, 0);
  assert.equal(store.scroll(), 0);
  assert.equal(store.lastUpdate(), null);
  assert.equal(store.filter(), 'a', 'the filter is the user\'s');
  assert.equal(store.maxRows(), 50, 'and so is the cap');
});

test('a changed mark holds until cleared, and marking or clearing twice notifies once', () => {
  const store = new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) }).for(ONE, []);
  let notified = 0;
  store.subscribe(() => (notified += 1));
  store.markChanged('A');
  store.markChanged('A');
  assert.deepEqual([...store.changed()], ['A']);
  store.clearChanged('A');
  store.clearChanged('A');
  assert.equal(store.changed().size, 0);
  assert.equal(notified, 2);
});
