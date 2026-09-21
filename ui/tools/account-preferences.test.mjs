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

// --- Story 15.5: the three value kinds, and the refusal a write leaves behind ------------------
//
// Mutations (Rule 19):
// - drop `views` from `valuesOf`'s call in `settle` -> "the widened read" goes red.
// - drop the fault assignment from `settle`'s non-ok branch -> "a refusal records" goes red, and
//   a refused preference would again be surfaced nowhere at all (DW-1326).
// - make `loaded()` return `answeredValue` -> "a write's answer is not a read's" goes red, and a
//   dismissal the user made before the first read settled would be undone by the next write.

const { VIEW_KIND, REFRESH_KIND, SHELL_KIND, SHELL_SIDE_BAR_OPEN } = await import(
  join(uiRoot, 'src', 'app', 'core', 'account-preferences.ts')
);

/** An answer carrying all five members the widened route publishes. */
function wholeBody(seed = {}) {
  return {
    favorites: (seed.favorites ?? []).map((route) => ({ route })),
    recents: (seed.recents ?? []).map((route) => ({ route })),
    views: Object.entries(seed.views ?? {}).map(([route, value]) => ({ route, value })),
    refreshRates: Object.entries(seed.refreshRates ?? {}).map(([route, value]) => ({ route, value })),
    shell: Object.entries(seed.shell ?? {}).map(([name, value]) => ({ name, value })),
  };
}

test('the widened read exposes the three value kinds, keyed by route and by shell member', async () => {
  const api = stubApi([
    ok(
      wholeBody({
        favorites: ['logs/alerts'],
        views: { 'permissions/users': '{"sort":"Name"}' },
        refreshRates: { 'os-management/processes': '10' },
        shell: { sideBarOpen: '0', panelWidth: '512' },
      })
    ),
  ]);
  const store = new AccountPreferences({ api });
  await store.load();

  assert.deepEqual(store.favorites(), ['logs/alerts']);
  assert.equal(store.views().get('permissions/users'), '{"sort":"Name"}');
  assert.equal(store.refreshRates().get('os-management/processes'), '10');
  assert.equal(store.shell().get(SHELL_SIDE_BAR_OPEN), '0');
  assert.equal(store.shell().get('panelWidth'), '512');
  assert.equal(store.views().get('no-such-screen'), undefined, 'a route nothing was stored for is absent');
});

test('an answer from an instance that predates the value kinds reads as three empty maps', async () => {
  const api = stubApi([ok(body(['logs/alerts'], []))]);
  const store = new AccountPreferences({ api });
  await store.load();
  assert.equal(store.views().size, 0);
  assert.equal(store.refreshRates().size, 0);
  assert.equal(store.shell().size, 0);
});

test('an entry whose key or value is not a non-empty string is dropped, never rendered', async () => {
  const api = stubApi([
    ok({
      favorites: [],
      recents: [],
      views: [{ route: 'a', value: 'kept' }, { route: '', value: 'x' }, { route: 'b' }, { route: 'c', value: 3 }, 'nope'],
      refreshRates: [],
      shell: [],
    }),
  ]);
  const store = new AccountPreferences({ api });
  await store.load();
  assert.deepEqual([...store.views()], [['a', 'kept']]);
});

test('setValue sends the key under the member its kind uses, and an empty one is never sent', async () => {
  const api = stubApi([ok(wholeBody({ shell: { sideBarOpen: '0' } }))]);
  const store = new AccountPreferences({ api });
  await store.load();

  await store.setValue(VIEW_KIND, 'permissions/users', '{"sort":"Name"}');
  assert.deepEqual(JSON.parse(api.calls[1].body), {
    kind: VIEW_KIND,
    action: 'set',
    route: 'permissions/users',
    value: '{"sort":"Name"}',
  });

  await store.setValue(SHELL_KIND, SHELL_SIDE_BAR_OPEN, '1');
  assert.deepEqual(JSON.parse(api.calls[2].body), {
    kind: SHELL_KIND,
    action: 'set',
    name: SHELL_SIDE_BAR_OPEN,
    value: '1',
  });

  const before = api.calls.length;
  await store.setValue(REFRESH_KIND, '', '10');
  await store.setValue(REFRESH_KIND, 'logs/alerts', '');
  assert.equal(api.calls.length, before, 'neither an empty key nor an empty value reaches the instance');
});

test('a refusal records the instance\'s own sentence and leaves the lists standing (DW-1326)', async () => {
  const api = stubApi([
    ok(wholeBody({ favorites: ['logs/alerts'] })),
    { kind: 'error', status: 422, code: 'PREFERENCES.LIMIT', reason: 'This account already holds as many favorites as the instance keeps.', detail: null },
  ]);
  const store = new AccountPreferences({ api });
  await store.load();
  assert.equal(store.fault(), '', 'nothing has been refused yet');

  await store.add(FAVORITE_KIND, 'permissions/users');
  assert.equal(store.fault(), 'This account already holds as many favorites as the instance keeps.');
  assert.deepEqual(store.favorites(), ['logs/alerts'], 'and the list the instance last answered still stands');

  store.clearFault();
  assert.equal(store.fault(), '', 'a surface that has announced it drops it');
});

test('a transport failure records no sentence, because it has none to record', async () => {
  const api = stubApi([
    ok(wholeBody({ favorites: ['logs/alerts'] })),
    { kind: 'error', status: 0, code: null, reason: null, detail: null },
  ]);
  const store = new AccountPreferences({ api });
  await store.load();
  await store.add(FAVORITE_KIND, 'permissions/users');
  assert.equal(store.fault(), '', 'the connectivity banner is already saying this');
  assert.deepEqual(store.favorites(), ['logs/alerts']);
});

test("a write's answer before any read does not settle the read, so `loaded` stays false", async () => {
  const api = stubApi([ok(wholeBody({ shell: { sideBarOpen: '0' } }))]);
  const store = new AccountPreferences({ api });
  assert.equal(store.loaded(), false);
  assert.equal(store.answered(), false);

  await store.setValue(SHELL_KIND, SHELL_SIDE_BAR_OPEN, '1');
  assert.equal(store.answered(), true, 'the instance has answered something');
  assert.equal(store.loaded(), false, 'but nothing has read this account yet');

  await store.load();
  assert.equal(store.loaded(), true);
});

test('a write that overtakes the read still settles it, so the stores are not left on the defaults', async () => {
  // Mutation (Rule 19): key `loadedValue` on the read's own settle rather than on the read having
  // been asked for -> this goes red, and a reloaded tab renders the published defaults with the
  // instance's answer already in hand (`recents-recorder.ts` registers a visit just after the
  // read, and its answer supersedes it).
  const answers = [
    ok(wholeBody({ shell: { sideBarOpen: '0' } })),
    ok(wholeBody({ shell: { sideBarOpen: '0' }, recents: ['permissions/users'] })),
  ];
  const calls = [];
  let resolveRead = null;
  const api = {
    calls,
    requestJson(path, init = {}) {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? null });
      if ((init.method ?? 'GET') === 'GET') {
        return new Promise((resolve) => {
          resolveRead = () => resolve(answers[0]);
        });
      }
      return Promise.resolve(answers[1]);
    },
  };
  const store = new AccountPreferences({ api });
  let notified = 0;
  store.subscribe(() => (notified += 1));

  const read = store.load();
  const write = store.add(RECENT_KIND, 'permissions/users');
  await write;
  assert.equal(store.loaded(), true, "the write's answer settles the read this shell asked for");
  assert.equal(store.shell().get(SHELL_SIDE_BAR_OPEN), '0', 'and carries the same whole body');
  assert.ok(notified > 0, 'and the stores waiting on it are told');

  resolveRead();
  await read;
  assert.equal(store.loaded(), true, 'and the overtaken read changes nothing when it lands');
});

test('reset drops the value maps and the standing refusal as well as the lists', async () => {
  const api = stubApi([
    ok(wholeBody({ favorites: ['logs/alerts'], shell: { sideBarOpen: '0' } })),
    { kind: 'error', status: 422, code: 'PREFERENCES.NAME', reason: 'refused', detail: null },
  ]);
  const store = new AccountPreferences({ api });
  await store.load();
  await store.setValue(SHELL_KIND, 'sideBarOpen', '1');
  assert.equal(store.fault(), 'refused');

  store.reset();
  assert.deepEqual(store.favorites(), []);
  assert.equal(store.shell().size, 0);
  assert.equal(store.views().size, 0);
  assert.equal(store.refreshRates().size, 0);
  assert.equal(store.fault(), '');
  assert.equal(store.loaded(), false);
  assert.equal(store.answered(), false);
});

test('rapid writes to one key are serialized and collapsed to the latest value', async () => {
  // Mutation (Rule 19): send from `setValue` directly instead of through `drain` -> the ordering
  // assertion goes red, and a panel stepped 416, 432, 448 can be left holding 432 because the
  // last request landed first (measured in the browser tier).
  const sent = [];
  let release = null;
  const api = {
    requestJson(path, init = {}) {
      sent.push(JSON.parse(init.body ?? '{}').value ?? 'GET');
      if (release === null) {
        return new Promise((resolve) => {
          release = () => resolve(ok(wholeBody()));
        });
      }
      return Promise.resolve(ok(wholeBody()));
    },
  };
  const store = new AccountPreferences({ api });

  void store.setValue(SHELL_KIND, SHELL_SIDE_BAR_OPEN, '1');
  void store.setValue(SHELL_KIND, SHELL_SIDE_BAR_OPEN, '0');
  const last = store.setValue(SHELL_KIND, SHELL_SIDE_BAR_OPEN, '1');
  assert.deepEqual(sent, ['1'], 'only the first is in flight');

  release();
  await last;
  await new Promise((resolve) => setTimeout(resolve, 0));
  assert.deepEqual(sent, ['1', '1'], 'and the burst collapses to its latest value, sent after it');
});

test('writes to different keys do not queue behind one another', async () => {
  const sent = [];
  const api = {
    requestJson(path, init = {}) {
      const body = JSON.parse(init.body ?? '{}');
      sent.push(`${body.kind}:${body.name ?? body.route}`);
      return new Promise(() => {});
    },
  };
  const store = new AccountPreferences({ api });
  void store.setValue(SHELL_KIND, SHELL_SIDE_BAR_OPEN, '1');
  void store.setValue(SHELL_KIND, 'panelWidth', '512');
  void store.setValue(VIEW_KIND, 'logs/alerts', '{}');
  assert.deepEqual(sent, ['shell:sideBarOpen', 'shell:panelWidth', 'view:logs/alerts']);
});
