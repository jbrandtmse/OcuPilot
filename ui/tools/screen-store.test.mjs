import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the screen store's table slots (AD-19): the view choices remembered per screen on the
// instance and adopted on its first answered read (Story 15.5, AD-50), the refused max-rows values
// (DW-17), and the scope switch clearing where the user was (DW-18).
//
// **The two descriptors are read from the mirror rather than invented.** A remembered view is
// keyed by the screen's route, so a descriptor the mirror does not carry has no route and
// remembers nothing -- which is the right behaviour and would make an invented name silently pin
// nothing at all.
//
// Mutations (Rule 19):
// - stop adopting the remembered view in `adoptRemembered` -> "AC9" goes red.
// - let `setMaxRows` accept 0 -> "DW-17 bad cap" goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { ScreenStores, DEFAULT_MAX_ROWS } = await import(core('screen-store.ts'));
const { SCREENS } = await import(core('screens.generated.ts'));
const { stubAccountPreferences, settledAccountPreferences } = await import(
  new URL('../src/app/testing/account-preferences.ts', import.meta.url).href
);

const BUILT = SCREENS.filter((screen) => screen.built && screen.route !== '');
const ONE = BUILT[0].descriptor;
const ONE_ROUTE = BUILT[0].route;
const TWO = BUILT[1].descriptor;

/** An account store nothing has been remembered in yet, already answered. */
function account(seed = {}) {
  return settledAccountPreferences({ views: seed });
}

/** Let the writes a store issued settle, so a second `ScreenStores` over it adopts them. */
async function flush() {
  await new Promise((resolve) => setTimeout(resolve, 0));
}

test('AC9: sort, direction, filter and max rows set on one store are restored by a new ScreenStores over the same account', async () => {
  const held = await account();
  const first = new ScreenStores({ account: held }).for(ONE, []);
  first.setSort('NameSpace');
  first.setDirection('desc');
  first.setFilter('csp');
  assert.equal(first.setMaxRows(5000), true);

  await flush();
  const stores = new ScreenStores({ account: held });
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

test('DW-17 bad cap: 0, -5, 2.5 and NaN change neither the store nor the preference', async () => {
  const held = await account();
  const store = new ScreenStores({ account: held }).for(ONE, []);
  let notified = 0;
  store.subscribe(() => (notified += 1));
  for (const cap of [0, -5, 2.5, Number.NaN, Number.MAX_SAFE_INTEGER + 2]) {
    assert.equal(store.setMaxRows(cap), false, `refused: ${cap}`);
  }
  assert.equal(store.maxRows(), DEFAULT_MAX_ROWS);
  assert.equal(held.calls.length, 1, 'nothing was remembered beyond the read that settled the store');
  assert.equal(notified, 0, 'and nobody was told of a change that did not happen');
});

test('a remembered view of the wrong shape falls back field by field, without throwing', async () => {
  const shaped = await account({
    [ONE_ROUTE]: JSON.stringify({ sort: 3, direction: 'sideways', filter: 'x', maxRows: -1 }),
  });
  const store = new ScreenStores({ account: shaped }).for(ONE, []);
  assert.deepEqual(
    { sort: store.sort(), direction: store.direction(), filter: store.filter(), maxRows: store.maxRows() },
    { sort: '', direction: '', filter: 'x', maxRows: DEFAULT_MAX_ROWS }
  );

  const unparsable = await account({ [ONE_ROUTE]: '{not json' });
  assert.doesNotThrow(() => new ScreenStores({ account: unparsable }).for(ONE, []));
});

// Story 2.8: the banner is the fourth slot a tick owns. It is what the instance answered, so a
// tick that answers none clears the one before it -- which is what makes "gone the moment it
// clears" (EXPERIENCE.md "panel (top), form-pages, Task") a property of `applyTick` rather than of a caller.
//
// Mutation (Rule 19): leave `bannerKey` alone in `applyTick` -> the clearing assertion goes red.
test('a tick writes the banner the instance answered, and the next one clears it', () => {
  const store = new ScreenStores({ account: stubAccountPreferences() }).for(ONE, []);
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
test('a tick leaves sort, direction, filter, selection and scroll alone even when each is off its default', async () => {
  const held = await account();
  const store = new ScreenStores({ account: held }).for(ONE, []);
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
  await flush();
  assert.deepEqual(JSON.parse(held.views().get(ONE_ROUTE)), {
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
test('a sort set on its own, and a direction set on its own, each survive a store rebuild', async () => {
  const sortAccount = await account();
  new ScreenStores({ account: sortAccount }).for(ONE, []).setSort('Commands');
  await flush();
  const afterSort = new ScreenStores({ account: sortAccount }).for(ONE, []);
  assert.equal(afterSort.sort(), 'Commands', 'the chosen field is in force on the way back');
  assert.equal(afterSort.direction(), '', 'and the direction is still the declared default');

  const directionAccount = await account();
  new ScreenStores({ account: directionAccount }).for(ONE, []).setDirection('desc');
  await flush();
  const afterDirection = new ScreenStores({ account: directionAccount }).for(ONE, []);
  assert.equal(afterDirection.direction(), 'desc', 'and so is the chosen direction');
  assert.equal(afterDirection.sort(), '', 'while the field is still the declared default');
});

test('DW-18 scope switch: clearAnswers drops rows, selection, active, changed and scroll, and keeps the choices', () => {
  const store = new ScreenStores({ account: stubAccountPreferences() }).for(ONE, []);
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
  const store = new ScreenStores({ account: stubAccountPreferences() }).for(ONE, []);
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

// Story 15.5: what a store remembers under, and the one view it declines to send.
//
// Mutations (Rule 19):
// - drop the `this.route === ''` guard from `rememberView` -> "a store with no route" goes red,
//   and Home would write a preference keyed by the empty string, which the instance refuses.
// - drop the `PREFERENCE_VALUE_MAX` guard -> "a view too long" goes red, and a long filter would
//   be refused by the instance and surfaced as an alert the user cannot act on.

test('a store is remembered under its screen\'s route, resolved from the mirror', async () => {
  const held = await account();
  const store = new ScreenStores({ account: held }).for(ONE, []);
  store.setFilter('csp');
  await flush();
  assert.deepEqual([...held.views().keys()], [ONE_ROUTE], 'the row is keyed by the route, not by the descriptor');
});

test('a store with no route remembers nothing, and asks the instance for nothing', async () => {
  const held = await account();
  const before = held.calls.length;
  const store = new ScreenStores({ account: held }).for('OcuPilot.Screen.Descriptor.NotInTheMirror', []);
  store.setFilter('csp');
  assert.equal(store.setMaxRows(50), true, 'the store still works in this tab');
  assert.equal(held.calls.length, before, 'but nothing is written for a screen with no route');
});

test('a view longer than the instance keeps is not sent, and the screen keeps it anyway', async () => {
  const { PREFERENCE_VALUE_MAX } = await import(core('screen-store.ts'));
  const held = await account();
  const before = held.calls.length;
  const store = new ScreenStores({ account: held }).for(ONE, []);
  store.setFilter('x'.repeat(PREFERENCE_VALUE_MAX));
  assert.equal(store.filter(), 'x'.repeat(PREFERENCE_VALUE_MAX), 'the filter is in force on screen');
  assert.equal(held.calls.length, before, 'and nothing the instance would refuse was sent');
});

test('a route the caller names is what the store is keyed by, whatever the mirror says', async () => {
  const held = await account();
  const store = new ScreenStores({ account: held }).for('OcuPilot.Screen.Descriptor.NotInTheMirror', [], 'probe/route');
  store.setFilter('csp');
  await flush();
  assert.deepEqual([...held.views().keys()], ['probe/route']);
});

test('reset releases each store\'s account subscription, so a dropped store stops listening', async () => {
  // Mutation (Rule 19): drop the `release()` loop from `ScreenStores.reset` -> this goes red, and
  // every screen a departed principal opened would stay subscribed for the life of the tab and
  // adopt the next principal's answer into a store nothing renders.
  //
  // The store is built BEFORE the read settles, so `adopted` is still false: a store that stayed
  // subscribed would adopt on the read below and notify, which is what makes this falsifiable.
  const held = stubAccountPreferences({ views: { [ONE_ROUTE]: '{"sort":"Name"}' } });
  const stores = new ScreenStores({ account: held });
  const store = stores.for(ONE, []);
  let notified = 0;
  store.subscribe(() => (notified += 1));

  stores.reset();
  await held.load();
  assert.equal(notified, 0, 'the dropped store neither adopts nor redraws');
  assert.equal(store.sort(), '', 'and its slots are still the published defaults');
});
