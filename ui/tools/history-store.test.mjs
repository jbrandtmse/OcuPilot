import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins Task history's own state (`areas/tasks/history.store.ts`): the search text and
// user-defined-only checkbox translate into `criteria()`'s query, Search is a one-way latch this
// tab's lifetime, and `readFor` memoizes by reference so a re-bind after the detail dialog closes
// is a no-op.
//
// Mutations (Rule 19):
// - `criteria` always sends `userOnly` -> "the checkbox translates to '1' only when checked" goes red.
// - `readFor` calls `create` every time -> "readFor memoizes the first read it is given" goes red.
// - `isCurrentGeneration` always answers true -> "generations tell a stale instance from the current one" goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const store = await import(join(uiRoot, 'src', 'app', 'areas', 'tasks', 'history.store.ts'));

test('the store opens unsearched, with an empty search and the checkbox unchecked', () => {
  const search = new store.TaskHistorySearch();
  assert.equal(search.searched(), false);
  assert.equal(search.search(), '');
  assert.equal(search.userOnly(), false);
  assert.deepEqual(search.criteria(), {}, 'an empty form sends no criteria at all');
});

test('setSearch and setUserOnly notify, and criteria sends only what is set', () => {
  const search = new store.TaskHistorySearch();
  let notified = 0;
  search.subscribe(() => (notified += 1));
  search.setSearch('OcuPilotDemo');
  assert.deepEqual(search.criteria(), { search: 'OcuPilotDemo' });
  assert.equal(notified, 1);
  search.setUserOnly(true);
  assert.deepEqual(search.criteria(), { search: 'OcuPilotDemo', userOnly: '1' });
  assert.equal(notified, 2);
});

test('the checkbox translates to "1" only when checked, never to a stray empty value', () => {
  const search = new store.TaskHistorySearch();
  search.setUserOnly(true);
  assert.deepEqual(search.criteria(), { userOnly: '1' });
  search.setUserOnly(false);
  assert.deepEqual(search.criteria(), {}, 'unchecked sends nothing, not userOnly: ""');
});

test('Search is a one-way latch: noteSearched flips it on and it stays on', () => {
  const search = new store.TaskHistorySearch();
  assert.equal(search.searched(), false);
  search.noteSearched();
  assert.equal(search.searched(), true);
  search.setSearch('anything');
  assert.equal(search.searched(), true, 'changing the form afterwards does not un-search it');
});

test('readFor memoizes the first read it is given, and never calls create again', () => {
  const search = new store.TaskHistorySearch();
  let calls = 0;
  const sentinelA = { descriptor: 'a' };
  const first = search.readFor(() => {
    calls += 1;
    return sentinelA;
  });
  assert.equal(first, sentinelA);
  assert.equal(calls, 1);
  const second = search.readFor(() => {
    calls += 1;
    return { descriptor: 'b' };
  });
  assert.equal(second, sentinelA, 'the same object comes back, by reference');
  assert.equal(calls, 1, 'create is never called a second time');
});

test('the grid-focus request is one-shot: taking it clears it', () => {
  const search = new store.TaskHistorySearch();
  assert.equal(search.takeGridFocusRequest(), false, 'nothing requested yet');
  search.requestGridFocus();
  assert.equal(search.takeGridFocusRequest(), true);
  assert.equal(search.takeGridFocusRequest(), false, 'taking it clears it');
});

test('generations tell a stale instance from the current one', () => {
  const search = new store.TaskHistorySearch();
  const first = search.takeGeneration();
  assert.equal(search.isCurrentGeneration(first), true);
  const second = search.takeGeneration();
  assert.equal(search.isCurrentGeneration(first), false, 'the first instance is now stale');
  assert.equal(search.isCurrentGeneration(second), true);
});
