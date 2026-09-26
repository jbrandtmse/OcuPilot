import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins Task history's own state (`areas/tasks/history.store.ts`): the default read sends nothing,
// the form as shown sends every field (an emptied one as an unset bound), an arrival sends exactly
// its criteria, the answer's applied criteria fill the fields a request left absent, Search is a
// one-way latch this tab's lifetime, and `readFor` memoizes by reference so a re-bind after the
// detail dialog closes is a no-op.
//
// Mutations (Rule 19):
// - `criteria` sends `userOnly: '1'` whatever the checkbox -> "the checkbox translates" goes red.
// - `applyEcho` fills every field, sent or not -> "the echo fills only what the request left absent" goes red.
// - `applyEcho` ignores the edited set -> "the echo leaves a field the person typed into" goes red.
// - `readFor` calls `create` every time -> "readFor memoizes the first read it is given" goes red.
// - `isCurrentGeneration` always answers true -> "generations tell a stale instance from the current one" goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const store = await import(join(uiRoot, 'src', 'app', 'areas', 'tasks', 'history.store.ts'));

test('the store opens unsearched on the default read, which sends no criteria at all', () => {
  const search = new store.TaskHistorySearch();
  assert.equal(search.searched(), false);
  assert.equal(search.search(), '');
  assert.equal(search.userOnly(), false);
  assert.equal(search.since(), '');
  assert.deepEqual(search.criteria(), {}, 'nothing is sent, so the instance applies since\'s default');
});

test('the form as shown sends every field, notifying as each is set', () => {
  const search = new store.TaskHistorySearch();
  let notified = 0;
  search.subscribe(() => (notified += 1));
  search.setSearch('OcuPilotDemo');
  search.setSince('2026-09-20 00:00:00');
  search.useForm();
  assert.deepEqual(search.criteria(), { search: 'OcuPilotDemo', userOnly: '', since: '2026-09-20 00:00:00' });
  assert.equal(notified, 3);
  search.setSince('');
  assert.deepEqual(search.criteria(), { search: 'OcuPilotDemo', userOnly: '', since: '' }, 'an emptied since is sent empty: the whole history');
});

test('the checkbox translates to "1" when checked and to an empty value when not', () => {
  const search = new store.TaskHistorySearch();
  search.useForm();
  search.setUserOnly(true);
  assert.equal(search.criteria().userOnly, '1');
  search.setUserOnly(false);
  assert.equal(search.criteria().userOnly, '', 'unchecked is an unset criterion, never "0"');
});

test('an arrival sends exactly its criteria and shows them in the form', () => {
  const search = new store.TaskHistorySearch();
  search.useArrival({ route: 'tasks/history', criterion: '', criteria: { search: 'OcuPilotProbeRunTask', since: '', nosuch: 'x' } });
  assert.deepEqual(search.criteria(), { search: 'OcuPilotProbeRunTask', since: '' }, 'no userOnly, and nothing undeclared');
  assert.equal(search.search(), 'OcuPilotProbeRunTask');
  assert.equal(search.since(), '');
});

test('the echo fills only what the request left absent, and ignores an answer to a replaced request', () => {
  const search = new store.TaskHistorySearch();
  search.applyEcho({ search: '', userOnly: '', since: '2026-09-19 12:00:00' }, {});
  assert.equal(search.since(), '2026-09-19 12:00:00', 'the default read shows the since the instance applied');

  search.useArrival({ route: 'tasks/history', criterion: '', criteria: { search: 'probe' } });
  search.applyEcho({ search: 'other', userOnly: '1', since: '2026-09-19 13:00:00' }, { search: 'probe' });
  assert.equal(search.search(), 'probe', 'a field the request carried keeps it');
  assert.equal(search.userOnly(), true);
  assert.equal(search.since(), '2026-09-19 13:00:00');

  search.applyEcho({ since: '1999-01-01 00:00:00' }, {});
  assert.equal(search.since(), '2026-09-19 13:00:00', 'an answer to the default read the arrival replaced changes nothing');
});

test('the echo leaves a field the person typed into while the read was out, and fills the rest', () => {
  const search = new store.TaskHistorySearch();
  search.useDefault();
  search.setSearch('typed');
  search.applyEcho({ search: '', userOnly: '', since: '2026-09-19 12:00:00' }, {});
  assert.equal(search.search(), 'typed', 'what the person typed is theirs until the next Search');
  assert.equal(search.since(), '2026-09-19 12:00:00', 'an untouched field still shows the applied value');
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
