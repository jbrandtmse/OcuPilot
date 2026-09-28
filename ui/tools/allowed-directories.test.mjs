import { test } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Pins `ui/src/app/core/allowed-directories.ts` (Story 18.1, AD-21, AD-36): the store issues the
// Allowed directories screen's own declared read, once, at the resolver's ceiling of 1,000; keeps
// the roots in read order and the read's truncation; carries a refusal's own sentence; and lets
// only the newest load settle. The api is a fake answering `requestJson`, so no test waits on a
// network or a clock.
//
// Mutation (Rule 19): point `ALLOWED_DIRECTORIES_ROUTE` at another screen's route -> the path
// assertion goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { ALLOWED_DIRECTORIES_LOADING, ALLOWED_DIRECTORIES_MAX_ROWS, ALLOWED_DIRECTORIES_ROUTE, AllowedDirectoriesStore } = await import(
  join(uiRoot, 'src', 'app', 'core', 'allowed-directories.ts')
);

const READ_PATH = '/api/ocupilot/screens/security.alloweddirectories/read?maxRows=1000';

/** A fake api answering every request with `answer`, recording each path it was asked for. */
function fakeApi(answer) {
  const paths = [];
  return {
    paths,
    requestJson: async (path) => {
      paths.push(path);
      return typeof answer === 'function' ? answer(path) : answer;
    },
  };
}

function ok(rows, truncated = false) {
  return { kind: 'ok', status: 200, body: { fields: ['Directory', 'Restricted'], rows, truncated, banner: '' } };
}

test('the store issues the Allowed directories read once, at the resolver ceiling, and keeps the roots in read order', async () => {
  assert.equal(ALLOWED_DIRECTORIES_ROUTE, 'security/allowed-directories');
  assert.equal(ALLOWED_DIRECTORIES_MAX_ROWS, 1000);
  const store = new AllowedDirectoriesStore();
  assert.deepEqual(store.state(), ALLOWED_DIRECTORIES_LOADING, 'a store no load has settled reads loading');
  const api = fakeApi(
    ok([
      { Directory: '/usr/irissys/', Restricted: true },
      { Directory: '/tmp/', Restricted: true },
    ])
  );
  await store.load(api);
  assert.deepEqual(api.paths, [READ_PATH], 'one request, to the screen read route, at maxRows 1000');
  assert.deepEqual(store.state(), { status: 'ready', roots: ['/usr/irissys/', '/tmp/'], truncated: false, reason: '' }, 'in the order read, never re-sorted');
});

test('an unrestricted instance answers its one root, and a restricted one with no root answers none', async () => {
  const store = new AllowedDirectoriesStore();
  await store.load(fakeApi(ok([{ Directory: '/durable/iris/mgr/', Restricted: false }])));
  assert.deepEqual(store.state().roots, ['/durable/iris/mgr/']);
  await store.load(fakeApi(ok([])));
  assert.deepEqual(store.state(), { status: 'ready', roots: [], truncated: false, reason: '' }, 'ready and empty is not a refusal');
});

test('a read cut at the cap is reported truncated, and a row with no directory is not a root', async () => {
  const store = new AllowedDirectoriesStore();
  await store.load(fakeApi(ok([{ Directory: '/tmp/' }, { Directory: '' }, { Restricted: true }, null, { Directory: 7 }], true)));
  assert.deepEqual(store.state(), { status: 'ready', roots: ['/tmp/'], truncated: true, reason: '' });
});

test("a refused read carries the envelope's own sentence and no roots; a transport failure carries none", async () => {
  const store = new AllowedDirectoriesStore();
  const refusal = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'This account does not hold the privilege this request requires.', detail: { failedPair: '%Admin_FileSystemAccess:USE' } };
  await store.load(fakeApi(refusal));
  assert.deepEqual(store.state(), { status: 'refused', roots: [], truncated: false, reason: refusal.reason });

  await store.load(fakeApi({ kind: 'error', status: 0, code: null, reason: null, detail: null }));
  assert.deepEqual(store.state(), { status: 'refused', roots: [], truncated: false, reason: '' });

  await store.load(fakeApi({ kind: 'ok', status: 200, body: { unexpected: true } }));
  assert.equal(store.state().status, 'refused', 'an answer that is not the read shape is not a list of roots');
});

test('subscribers hear loading and then the answer; an unsubscribed one hears nothing more', async () => {
  const store = new AllowedDirectoriesStore();
  const heard = [];
  const stop = store.subscribe(() => heard.push(store.state().status));
  await store.load(fakeApi(ok([{ Directory: '/tmp/' }])));
  assert.deepEqual(heard, ['loading', 'ready']);
  stop();
  await store.load(fakeApi(ok([])));
  assert.deepEqual(heard, ['loading', 'ready'], 'nothing after unsubscribing');
});

test('only the newest load settles: an older answer arriving last does not overwrite it', async () => {
  const store = new AllowedDirectoriesStore();
  let releaseFirst;
  const first = store.load({
    requestJson: () =>
      new Promise((resolve) => {
        releaseFirst = () => resolve(ok([{ Directory: '/old/' }]));
      }),
  });
  await store.load(fakeApi(ok([{ Directory: '/new/' }])));
  releaseFirst();
  await first;
  assert.deepEqual(store.state().roots, ['/new/']);
});
