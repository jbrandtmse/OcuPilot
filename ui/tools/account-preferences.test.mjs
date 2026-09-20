// Pins the per-user preferences store (Story 15.2, AD-50): the two lists as the instance orders
// them, `isFavorite`, the hold on a transport failure, and that a read a later one overtook
// settles nothing. It is framework-free precisely so those rules are decided somewhere
// `node --test` can execute them, rather than emerging from whichever component happened to
// subscribe first.
//
// Mutations (Rule 19):
// - drop the `if (result.kind !== 'ok') return;` park in `settle` -> the "a failed read leaves the
//   previous lists standing" row goes red, and an offline Home would empty both blocks.
// - drop the `if (request !== this.request) return;` guard -> the "a late answer does not
//   overwrite a newer one" row goes red.
// - make `routesOf` return the raw array -> the "an entry the answer does not shape is dropped"
//   row goes red, and a row with no route would render as a button that opens nothing.
// - make `isFavorite` read `recents()` -> the `isFavorite` row goes red.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { AccountPreferences, ACCOUNT_PREFERENCES_PATH, FAVORITE_KIND, RECENT_KIND } = await import(
  join(uiRoot, 'src', 'app', 'core', 'account-preferences.ts')
);

/** An answer in the shape the route publishes. */
function body(favorites, recents) {
  return {
    favorites: favorites.map((route) => ({ route })),
    recents: recents.map((route) => ({ route })),
  };
}

/** A stub API whose every call resolves from a queue, recording what was asked. */
function stubApi(answers) {
  const calls = [];
  const queue = [...answers];
  return {
    calls,
    requestJson(path, init = {}) {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? null });
      const next = queue.length > 1 ? queue.shift() : queue[0];
      return Promise.resolve(next);
    },
  };
}

function ok(value) {
  return { kind: 'ok', status: 200, body: value };
}

test('a read settles both lists in the order the instance answered, and notifies once', async () => {
  const api = stubApi([ok(body(['logs/alerts', 'permissions/users'], ['tasks/schedule']))]);
  const store = new AccountPreferences({ api });
  let notified = 0;
  store.subscribe(() => (notified += 1));

  assert.equal(store.answered(), false);
  await store.load();

  assert.deepEqual(store.favorites(), ['logs/alerts', 'permissions/users']);
  assert.deepEqual(store.recents(), ['tasks/schedule']);
  assert.equal(store.answered(), true);
  assert.equal(notified, 1);
  assert.equal(api.calls[0].path, ACCOUNT_PREFERENCES_PATH);
  assert.equal(api.calls[0].method, 'GET');
});

test('a re-read that confirms the same lists notifies nobody', async () => {
  const api = stubApi([ok(body(['logs/alerts'], []))]);
  const store = new AccountPreferences({ api });
  await store.load();
  let notified = 0;
  store.subscribe(() => (notified += 1));
  await store.load();
  assert.equal(notified, 0);
});

test('isFavorite answers off the favorites list alone', async () => {
  const api = stubApi([ok(body(['logs/alerts'], ['tasks/schedule']))]);
  const store = new AccountPreferences({ api });
  await store.load();
  assert.equal(store.isFavorite('logs/alerts'), true);
  assert.equal(store.isFavorite('tasks/schedule'), false);
  assert.equal(store.isFavorite('never/visited'), false);
});

test('an entry the answer does not shape is dropped rather than rendered as a row that opens nothing', async () => {
  const api = stubApi([
    ok({
      favorites: [{ route: 'logs/alerts' }, { route: 7 }, null, 'logs/messages', {}, { route: '' }],
      recents: 'not an array',
    }),
  ]);
  const store = new AccountPreferences({ api });
  await store.load();
  assert.deepEqual(store.favorites(), ['logs/alerts']);
  assert.deepEqual(store.recents(), []);
});

test('a body carrying neither member reads as two empty lists rather than throwing', async () => {
  const api = stubApi([ok({})]);
  const store = new AccountPreferences({ api });
  await store.load();
  assert.deepEqual(store.favorites(), []);
  assert.deepEqual(store.recents(), []);
  assert.equal(store.answered(), true);
});

test('a write posts the kind, the action and the route, and settles from the answered list', async () => {
  const api = stubApi([ok(body(['logs/alerts'], []))]);
  const store = new AccountPreferences({ api });
  await store.add(FAVORITE_KIND, 'logs/alerts');

  assert.equal(api.calls[0].method, 'POST');
  assert.deepEqual(JSON.parse(api.calls[0].body), {
    kind: FAVORITE_KIND,
    action: 'add',
    route: 'logs/alerts',
  });
  assert.deepEqual(store.favorites(), ['logs/alerts']);
});

test('clear names no route, because the whole list is the subject', async () => {
  const api = stubApi([ok(body([], []))]);
  const store = new AccountPreferences({ api });
  await store.clear(RECENT_KIND);
  const sent = JSON.parse(api.calls[0].body);
  assert.deepEqual(sent, { kind: RECENT_KIND, action: 'clear' });
  assert.equal('route' in sent, false);
});

test('registering a visit is a recent add, and is never awaited by its caller', async () => {
  const api = stubApi([ok(body([], ['logs/alerts']))]);
  const store = new AccountPreferences({ api });
  const returned = store.registerVisit('logs/alerts');
  assert.equal(returned, undefined, 'fire and forget: there is nothing for a navigation to await');
  await new Promise((resolve) => setTimeout(resolve, 0));
  assert.deepEqual(JSON.parse(api.calls[0].body), {
    kind: RECENT_KIND,
    action: 'add',
    route: 'logs/alerts',
  });
  assert.deepEqual(store.recents(), ['logs/alerts']);
});

test('a failed read leaves the previous lists standing rather than emptying the blocks', async () => {
  const api = stubApi([
    ok(body(['logs/alerts'], ['tasks/schedule'])),
    { kind: 'error', status: 0, code: null, reason: null, detail: null },
  ]);
  const store = new AccountPreferences({ api });
  await store.load();
  await store.load();

  assert.deepEqual(store.favorites(), ['logs/alerts'], 'the instance is unreachable, not empty');
  assert.deepEqual(store.recents(), ['tasks/schedule']);
  assert.equal(store.answered(), true);
});

test('a refusal is parked too: a refused favorite never appears on screen', async () => {
  const api = stubApi([
    ok(body([], [])),
    {
      kind: 'error',
      status: 422,
      code: 'PREFERENCES.LIMIT',
      reason: 'refused',
      detail: { violations: [{ field: 'route', code: 'PREFERENCES.LIMIT', reason: 'refused' }] },
    },
  ]);
  const store = new AccountPreferences({ api });
  await store.load();
  await store.add(FAVORITE_KIND, 'logs/alerts');
  assert.deepEqual(store.favorites(), [], 'the client never patches its own copy');
});

test('a late answer does not overwrite a newer one', async () => {
  const resolvers = [];
  const api = {
    requestJson() {
      return new Promise((resolve) => resolvers.push(resolve));
    },
  };
  const store = new AccountPreferences({ api });

  const first = store.load();
  const second = store.load();
  // The newer read answers first, then the older one arrives late.
  resolvers[1](ok(body(['permissions/users'], [])));
  resolvers[0](ok(body(['logs/alerts'], [])));
  await Promise.all([first, second]);

  assert.deepEqual(store.favorites(), ['permissions/users'], 'the newest read owns the answer');
});

test('reset forgets both lists and makes the next read the newest one', async () => {
  const api = stubApi([ok(body(['logs/alerts'], ['tasks/schedule']))]);
  const store = new AccountPreferences({ api });
  await store.load();
  store.reset();
  assert.deepEqual(store.favorites(), []);
  assert.deepEqual(store.recents(), []);
  assert.equal(store.answered(), false);
});

test('an answer for a principal who has since signed out is discarded', async () => {
  const resolvers = [];
  const api = {
    requestJson() {
      return new Promise((resolve) => resolvers.push(resolve));
    },
  };
  const store = new AccountPreferences({ api });
  const pending = store.load();
  store.reset();
  resolvers[0](ok(body(['logs/alerts'], [])));
  await pending;
  assert.deepEqual(store.favorites(), [], 'the departed principal\'s rows never land');
  assert.equal(store.answered(), false);
});

test('unsubscribing stops the notifications', async () => {
  const api = stubApi([ok(body(['logs/alerts'], []))]);
  const store = new AccountPreferences({ api });
  let notified = 0;
  const stop = store.subscribe(() => (notified += 1));
  stop();
  await store.load();
  assert.equal(notified, 0);
});

test('formatNamed resolves the <name> placeholder, and a template without one is unchanged', async () => {
  const { formatNamed, NAME_PLACEHOLDER } = await import(
    join(uiRoot, 'src', 'app', 'core', 'account-preferences.ts')
  );
  assert.equal(NAME_PLACEHOLDER, '<name>');
  assert.equal(formatNamed('Remove <name> from favorites', 'Alerts'), 'Remove Alerts from favorites');
  assert.equal(formatNamed('Clear favorites', 'Alerts'), 'Clear favorites');
});
