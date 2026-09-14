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

// Story 2.8: the banner is the fourth slot a tick owns. It is what the instance answered, so a
// tick that answers none clears the one before it -- which is what makes "gone the moment it
// clears" (EXPERIENCE.md `:351`) a property of `applyTick` rather than of a caller.
//
// Mutation (Rule 19): leave `bannerKey` alone in `applyTick` -> the clearing assertion goes red.
test('a tick writes the banner the instance answered, and the next one clears it', () => {
  const store = new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) }).for(ONE, []);
  assert.equal(store.banner(), '', 'a store that has never read raises no strip');

  store.applyTick([{ Name: 'A' }], false, 'taskManagerSuspendedBanner', new Date(0));
  assert.equal(store.banner(), 'taskManagerSuspendedBanner');

  store.applyTick([{ Name: 'A' }], false, '', new Date(1));
  assert.equal(store.banner(), '', 'the condition cleared, so the strip goes with the next read');
});

// Story 2.8 QA follow-up, widened by Story 2.9. `refresh.test.mjs`'s tick test moves sort, filter,
// selection, scroll and max rows off default; `direction` is the one slot it does not carry, and
// all five are set away from default here so the whole set is pinned in one place. `applyTick`'s
// own signature (`rows, truncated, banner, at`) is why none of them can change, which is what the
// class doc comment above `applyTick` claims.
//
// **`setSort` and `setDirection` are the command bar's sort control's two writes** (Story 2.9), so
// what this test drives is now the state a user can actually put the screen into rather than a
// state only a test could reach -- which is what makes the browser tier's own "the sort survived
// the tick" leg falsifiable at all. The persisted half is the test below.
//
// Mutation (Rule 19): add `this.sortBy = '';` to `applyTick` -> this assertion goes red on `sort`,
// and so does `refresh.test.mjs`'s "a tick replaces data, truncated, banner and lastUpdate and
// nothing else"; `this.sortDirection` instead reddens this one alone.
test('a tick leaves sort, direction, filter, selection and scroll alone even when each is off its default', () => {
  const storage = memoryStorage();
  const store = new ScreenStores({ preferences: new PreferenceStore({ storage }) }).for(ONE, []);
  store.setSort('NameSpace');
  store.setDirection('desc');
  store.setFilter('csp');
  store.setSelection(['A']);
  store.setScroll(120);

  store.applyTick([{ Name: 'B' }], false, '', new Date(5));

  assert.deepEqual(
    {
      sort: store.sort(),
      direction: store.direction(),
      filter: store.filter(),
      selection: store.selection(),
      scroll: store.scroll(),
    },
    { sort: 'NameSpace', direction: 'desc', filter: 'csp', selection: ['A'], scroll: 120 }
  );

  // The remembered copy is untouched too: a tick writes no view preference, so leaving and
  // re-entering the screen after one still restores what the user chose.
  assert.deepEqual(JSON.parse(storage.map.get(SCREEN_VIEWS_KEY))[ONE], {
    sort: 'NameSpace',
    direction: 'desc',
    filter: 'csp',
    maxRows: DEFAULT_MAX_ROWS,
  });
});

// Story 2.9, AC2's persistence half: a sort chosen through the command bar's sort control is
// remembered per screen and is in force again when the screen is re-entered.
//
// Each slot is set ON ITS OWN, over its own storage, which is what the AC9 test above cannot do:
// it sets four in a row, so a later call re-persists whatever an earlier one failed to write and
// a `rememberView()` missing from `setSort` alone would leave it green.
//
// Mutation (Rule 19): remove the `rememberView()` call from `ScreenStore.setSort` -> the first
// half goes red and nothing else in the suite moves; remove it from `setDirection` -> the second.
test('a sort set on its own, and a direction set on its own, each survive a store rebuild', () => {
  const sortStorage = memoryStorage();
  new ScreenStores({ preferences: new PreferenceStore({ storage: sortStorage }) }).for(ONE, []).setSort('Commands');
  const afterSort = new ScreenStores({ preferences: new PreferenceStore({ storage: sortStorage }) }).for(ONE, []);
  assert.equal(afterSort.sort(), 'Commands', 'the chosen field is in force on the way back');
  assert.equal(afterSort.direction(), '', 'and the direction is still the declared default');

  const directionStorage = memoryStorage();
  new ScreenStores({ preferences: new PreferenceStore({ storage: directionStorage }) }).for(ONE, []).setDirection('desc');
  const afterDirection = new ScreenStores({ preferences: new PreferenceStore({ storage: directionStorage }) }).for(ONE, []);
  assert.equal(afterDirection.direction(), 'desc', 'and so is the chosen direction');
  assert.equal(afterDirection.sort(), '', 'while the field is still the declared default');
});

test('DW-18 scope switch: clearAnswers drops rows, selection, active, changed and scroll, and keeps the choices', () => {
  const store = new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) }).for(ONE, []);
  store.applyTick([{ Name: 'A' }], true, 'taskManagerSuspendedBanner', new Date(0));
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
  assert.equal(store.banner(), '', 'and the strip, which belonged to the namespace the shell has left');
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
