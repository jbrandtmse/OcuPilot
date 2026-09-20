// Pins the framework-free half of Story 15.4: the System Information store's late-answer guard,
// its hold on a transport failure, the scope it lets `ApiService` attach, and a member the
// instance did not report surfacing as an empty string rather than as an absent key. All four are
// decided in `core/`, which is where `node --test` can execute them -- jsdom computes no layout
// and the browser tier has no way to make a read fail on demand.
//
// Mutations (Rule 19):
// - drop the `if (request !== this.request) return;` guard in `SystemInfo.load` -> the "a late
//   answer does not overwrite a newer one" row goes red.
// - drop the `if (result.kind !== 'ok')` park in `SystemInfo.load` -> the "a failed read leaves
//   the previous answer standing" row goes red, and an offline panel would blank its seven rows.
// - pass `{ scope: null }` to `requestJson` in `SystemInfo.load` -> the "the read carries the
//   shell's own namespace" row goes red, and the production member would answer for the install
//   namespace whatever namespace the user is looking at.
// - drop the `generation !== this.generation` guard -> the "an answer for a departed principal
//   does not land on the next" row goes red.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { SystemInfo, SYSTEM_INFO_PATH, SYSTEM_INFO_FIELDS } = await import(core('system-info.ts'));

/** An answer in the shape `GET /ui/system` publishes. */
function systemBody(overrides = {}) {
  const body = {};
  for (const field of SYSTEM_INFO_FIELDS) body[field] = `${field}-value`;
  return { ...body, ...overrides };
}

function ok(value) {
  return { kind: 'ok', status: 200, body: value };
}

function transportError() {
  return { kind: 'error', status: 0, code: null, reason: null, detail: null };
}

/** A stub API whose every call resolves from a queue, recording what was asked. */
function stubApi(answers) {
  const calls = [];
  const queue = [...answers];
  return {
    calls,
    requestJson(path, init = {}) {
      calls.push({ path, init, method: init.method ?? 'GET' });
      const next = queue.length > 1 ? queue.shift() : queue[0];
      return Promise.resolve(next);
    },
  };
}

/** A stub API each of whose calls is settled by hand, so two can be in flight at once. */
function deferredApi() {
  const pending = [];
  return {
    pending,
    requestJson(path) {
      let settle;
      const promise = new Promise((resolve) => {
        settle = resolve;
      });
      pending.push({ path, settle });
      return promise;
    },
  };
}

test('a read settles all seven members and notifies once', async () => {
  const api = stubApi([ok(systemBody())]);
  const store = new SystemInfo({ api });
  let notified = 0;
  store.subscribe(() => (notified += 1));

  assert.equal(store.answered(), false);
  await store.load();

  assert.equal(store.answered(), true);
  assert.equal(store.failed(), false);
  assert.equal(notified, 1);
  assert.equal(api.calls[0].path, SYSTEM_INFO_PATH);
  assert.equal(api.calls[0].method, 'GET');
  for (const field of SYSTEM_INFO_FIELDS) assert.equal(store.fields()[field], `${field}-value`);
});

test('the seven members are the ones the panel renders, in the order the read carries them', () => {
  assert.deepEqual(
    [...SYSTEM_INFO_FIELDS],
    ['uptime', 'mirror', 'databaseSpace', 'journalSpace', 'lockTable', 'writeDaemon', 'production'],
    'the wire contract, spelled here rather than derived from the module under test'
  );
});

test("the read carries the shell's own namespace, because production status is per namespace", async () => {
  const api = stubApi([ok(systemBody())]);
  const store = new SystemInfo({ api });
  await store.load();

  // `ApiService.scopedPath` attaches `?ns=` from the service's own scope source unless the caller
  // names one, and `null` is the opt-out that makes a call carry none. This read wants the shell's
  // namespace -- the router resolves and validates it and stashes it as the request's scope, which
  // is what the production member is read against -- so its contract is to name neither, which is
  // what this asserts. The path itself carries no query of its own, so nothing here could shadow
  // the attached parameter.
  assert.equal('scope' in api.calls[0].init, false, 'no per-call scope override is passed');
  assert.equal(SYSTEM_INFO_PATH.includes('?'), false, 'and the path carries no query of its own');
});

test('a member the instance could not report reads as the empty string, never as absent', async () => {
  const api = stubApi([ok(systemBody({ production: '', mirror: '' }))]);
  const store = new SystemInfo({ api });
  await store.load();
  assert.equal(store.fields().production, '');
  assert.equal(store.fields().mirror, '');
  assert.equal(store.fields().uptime, 'uptime-value');
  assert.ok('production' in store.fields(), 'the member is still a key the panel renders a row for');
});

test('a member the answer omits, or shapes as something other than a string, reads empty', async () => {
  const body = systemBody();
  delete body.lockTable;
  const api = stubApi([ok({ ...body, writeDaemon: 0 })]);
  const store = new SystemInfo({ api });
  await store.load();
  assert.equal(store.fields().lockTable, '');
  assert.equal(store.fields().writeDaemon, '');
  assert.equal(store.answered(), true, 'and the read still settled');
});

test('a body that is not an object at all leaves every member empty rather than throwing', async () => {
  const api = stubApi([ok('not an object')]);
  const store = new SystemInfo({ api });
  await store.load();
  for (const field of SYSTEM_INFO_FIELDS) assert.equal(store.fields()[field], '');
});

test('a failed read leaves the previous answer standing and says the read failed', async () => {
  const api = stubApi([ok(systemBody()), transportError()]);
  const store = new SystemInfo({ api });
  await store.load();
  await store.load();

  assert.equal(store.answered(), true, 'the answer it had is still an answer');
  assert.equal(store.failed(), true, 'and the failure is reported');
  assert.equal(store.fields().uptime, 'uptime-value', 'with the previous values still held');
});

test('a failed read with nothing held is what the panel renders its not-reported rows from', async () => {
  const api = stubApi([transportError()]);
  const store = new SystemInfo({ api });
  let notified = 0;
  store.subscribe(() => (notified += 1));
  await store.load();

  assert.equal(store.answered(), false, 'nothing has ever been answered');
  assert.equal(store.failed(), true);
  assert.equal(notified, 1, 'and the panel was told once');
  for (const field of SYSTEM_INFO_FIELDS) assert.equal(store.fields()[field], '');
});

test('a second failed read notifies nothing: the parked state has not changed', async () => {
  const api = stubApi([transportError()]);
  const store = new SystemInfo({ api });
  await store.load();
  let notified = 0;
  store.subscribe(() => (notified += 1));
  await store.load();
  assert.equal(notified, 0);
});

test('a read that answers clears a previous failure', async () => {
  const api = stubApi([transportError(), ok(systemBody())]);
  const store = new SystemInfo({ api });
  await store.load();
  assert.equal(store.failed(), true);
  await store.load();
  assert.equal(store.failed(), false);
  assert.equal(store.answered(), true);
});

test('a late answer does not overwrite a newer one', async () => {
  const api = deferredApi();
  const store = new SystemInfo({ api });
  const first = store.load();
  const second = store.load();
  assert.equal(api.pending.length, 2);

  // The newer request settles first, then the older one answers with stale values.
  api.pending[1].settle(ok(systemBody({ uptime: 'newer' })));
  await second;
  api.pending[0].settle(ok(systemBody({ uptime: 'older' })));
  await first;

  assert.equal(store.fields().uptime, 'newer', 'the overtaken read settles nothing');
});

test('an answer for a departed principal does not land on the next one', async () => {
  const api = deferredApi();
  const store = new SystemInfo({ api });
  const inFlight = store.load();
  store.reset();
  api.pending[0].settle(ok(systemBody({ uptime: 'the previous principal' })));
  await inFlight;

  assert.equal(store.answered(), false, 'the reset is what the next sign-in reads from');
  assert.equal(store.fields().uptime, '');
});

test('reset clears the values, the answered flag and the failure, and notifies', async () => {
  const api = stubApi([ok(systemBody())]);
  const store = new SystemInfo({ api });
  await store.load();
  let notified = 0;
  store.subscribe(() => (notified += 1));

  store.reset();
  assert.equal(notified, 1);
  assert.equal(store.answered(), false);
  assert.equal(store.failed(), false);
  for (const field of SYSTEM_INFO_FIELDS) assert.equal(store.fields()[field], '');
});

test('unsubscribing stops the notifications', async () => {
  const api = stubApi([ok(systemBody())]);
  const store = new SystemInfo({ api });
  let notified = 0;
  const stop = store.subscribe(() => (notified += 1));
  stop();
  await store.load();
  assert.equal(notified, 0);
});
