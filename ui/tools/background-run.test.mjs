import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the client half of an owner-scoped background run (Story 19.15, Story 20.33): the start and what it
// came to, the busy owner's attach, the poll and the cancel, the run a poll no longer finds, the transient
// failure polled again, and the answer of an older poll dropped.
//
// Nothing here touches a clock or a network: the API is a stub that answers per method and path, and the
// poll schedule is a list the test sends from by hand.
//
// Mutations (Rule 19):
// - drop the 404 branch of `BackgroundRun.read` -> "a run its poll no longer finds leaves the screen" goes
//   red (the run still reads running), and `sql-query.page.spec.ts`'s swept-run case with it.
// - drop the transient branch of `read` -> "a transient failure polls again" goes red with no poll scheduled.
// - drop the generation comparison in `poll` -> "an answer of an older poll is dropped" goes red.
// - attach before `settle` is called in `start` -> "settle runs before the run is attached" goes red.

const corePath = (name) => join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'app', 'core', name);

const { BACKGROUND_POLL_MS, BackgroundRun, backgroundViewOf, runPath } = await import(corePath('background-run.ts'));
const { STRINGS } = await import(corePath('strings.ts'));

const PATH = '/api/ocupilot/test/background';
const BUSY = 'TEST.BUSY';
const ID = '0123456789abcdef0123456789abcdef';

const ok = (body) => ({ kind: 'ok', status: 200, body });
const refused = (status, code, reason, detail = null) => ({ kind: 'error', status, code, reason, detail });

/** The answer a poll or a cancel reads. */
const view = (status, extra = {}) => ok({ id: ID, status, startedAt: 'a', endedAt: status === 'running' ? null : 'b', cancelRequested: false, ...extra });

/** One run over a stub API: `answer(method, path, ...results)` queues what that route answers, first queued first. */
function fixture() {
  const calls = [];
  const routes = new Map();
  const scheduled = [];
  const delays = [];
  let changes = 0;
  const deps = {
    api: {
      requestJson: async (path, init = {}) => {
        const method = init.method ?? 'GET';
        calls.push({ method, path, body: init.body, scope: init.scope, headers: init.headers });
        const next = routes.get(`${method} ${path}`)?.shift();
        assert.notEqual(next, undefined, `an answer is queued for ${method} ${path}`);
        return typeof next === 'function' ? next() : next;
      },
    },
    scope: () => 'USER',
    schedule: (run, delay) => {
      scheduled.push(run);
      delays.push(delay);
    },
  };
  const run = new BackgroundRun(
    {
      path: PATH,
      busyCode: BUSY,
      answerOf: (result) => (result !== null && typeof result === 'object' && result.outcome === 'rows' ? { rows: result.rows } : null),
      refusalText: (code, reason) => (code === 'TEST.KNOWN' ? 'the known sentence' : (reason ?? '')),
    },
    () => {
      changes += 1;
    }
  );
  return {
    run,
    deps,
    calls,
    scheduled,
    delays,
    changes: () => changes,
    answer: (method, path, ...results) => routes.set(`${method} ${path}`, [...(routes.get(`${method} ${path}`) ?? []), ...results]),
    /** Send the polls the run scheduled, and let their answers land. */
    flush: async () => {
      for (const send of scheduled.splice(0)) send();
      await new Promise((resolve) => setImmediate(resolve));
    },
  };
}

const settled = () => new Promise((resolve) => setImmediate(resolve));

test('runPath names the poll route and the cancel route under the start route, the id encoded', () => {
  assert.equal(runPath(PATH, ID), `${PATH}/${ID}`);
  assert.equal(runPath(PATH, ID, true), `${PATH}/${ID}/cancel`);
  assert.equal(runPath(PATH, 'a/b c'), `${PATH}/a%2Fb%20c`);
});

test('a start posts its body in scope, and a run id attaches the run and polls it at once', async () => {
  const f = fixture();
  f.answer('POST', PATH, ok({ id: ID, status: 'running' }));
  f.answer('GET', runPath(PATH, ID), view('running'));
  const started = await f.run.start(f.deps, '{"statement":"x"}');
  await settled();
  assert.deepEqual(started, { kind: 'attached', id: ID });
  assert.deepEqual(f.calls[0], { method: 'POST', path: PATH, body: '{"statement":"x"}', scope: 'USER', headers: { 'Content-Type': 'application/json' } });
  assert.equal(f.calls[1].path, runPath(PATH, ID), 'the first poll follows the attach');
  assert.equal(f.run.id(), ID);
  assert.equal(f.run.status(), 'running');
  assert.equal(f.run.busy(), true);
  assert.equal(f.scheduled.length, 1, 'a run that still runs is polled again');
  assert.deepEqual(f.delays, [BACKGROUND_POLL_MS]);
});

test("a 200 answer with no run id is handed back untouched, and attaches nothing", async () => {
  const f = fixture();
  const body = { outcome: 'confirm', constructs: ['%SEARCH'] };
  f.answer('POST', PATH, ok(body));
  const started = await f.run.start(f.deps, '{}');
  assert.deepEqual(started, { kind: 'answered', body });
  assert.equal(f.run.id(), null);
  assert.equal(f.run.status(), null);
  assert.equal(f.run.busy(), false, 'the start is over and no run is live');
  assert.equal(f.calls.length, 1, 'nothing is polled');
});

test('a start while a run is live or starting sends nothing and answers null', async () => {
  const f = fixture();
  let release = () => {};
  f.answer('POST', PATH, () => new Promise((resolve) => (release = () => resolve(ok({ outcome: 'error', message: 'm' })))));
  const first = f.run.start(f.deps, '{}');
  assert.equal(f.run.busy(), true, 'a start on its way is busy');
  assert.equal(await f.run.start(f.deps, '{}'), null);
  release();
  assert.equal((await first).kind, 'answered');
  assert.equal(f.calls.length, 1);
  f.answer('POST', PATH, ok({ id: ID, status: 'running' }));
  f.answer('GET', runPath(PATH, ID), view('running'));
  await f.run.start(f.deps, '{}');
  await settled();
  assert.equal(await f.run.start(f.deps, '{}'), null, 'a running run blocks a second start');
});

test("a busy owner's refusal attaches the run it names, and any other refusal attaches nothing", async () => {
  const f = fixture();
  f.answer('POST', PATH, refused(409, BUSY, 'busy sentence', { runId: ID }));
  f.answer('GET', runPath(PATH, ID), view('running'));
  const busy = await f.run.start(f.deps, '{}');
  await settled();
  assert.deepEqual(busy, { kind: 'refused', refusal: 'busy sentence', attached: true });
  assert.equal(f.run.id(), ID);
  assert.equal(f.run.status(), 'running');

  const g = fixture();
  g.answer('POST', PATH, refused(422, 'TEST.KNOWN', 'ignored'));
  assert.deepEqual(await g.run.start(g.deps, '{}'), { kind: 'refused', refusal: 'the known sentence', attached: false });
  assert.equal(g.run.id(), null);
  g.answer('POST', PATH, { kind: 'error', status: 0, code: null, reason: null, detail: null });
  assert.deepEqual(await g.run.start(g.deps, '{}'), { kind: 'refused', refusal: STRINGS.connectivityRequestRefused, attached: false }, 'no sentence reads "request refused"');
});

test('settle runs before the run is attached or polled, with what the start came to', async () => {
  const f = fixture();
  const events = [];
  f.answer('POST', PATH, ok({ id: ID, status: 'running' }));
  f.answer('GET', runPath(PATH, ID), () => {
    events.push('polled');
    return view('running');
  });
  await f.run.start(f.deps, '{}', (outcome) => events.push(`settle:${outcome.kind}:${f.run.id()}`));
  await settled();
  assert.deepEqual(events, ['settle:attached:null', 'polled'], 'the run was not yet on screen when settle ran');
});

test('a poll reads the view: status, answer and refusal, and a running run is polled again after a second', async () => {
  const f = fixture();
  f.answer('POST', PATH, ok({ id: ID, status: 'running' }));
  f.answer('GET', runPath(PATH, ID), view('running'));
  await f.run.start(f.deps, '{}');
  await settled();
  f.answer('GET', runPath(PATH, ID), view('ended', { result: { outcome: 'rows', rows: [['1']] } }));
  await f.flush();
  assert.equal(f.run.status(), 'ended');
  assert.deepEqual(f.run.answer(), { rows: [['1']] });
  assert.equal(f.run.busy(), false);
  assert.equal(f.scheduled.length, 0, 'an ended run is not polled again');

  const g = fixture();
  g.answer('POST', PATH, ok({ id: ID, status: 'running' }));
  g.answer('GET', runPath(PATH, ID), view('failed', { refusal: { code: 'TEST.KNOWN', reason: 'r' } }));
  await g.run.start(g.deps, '{}');
  await settled();
  assert.equal(g.run.status(), 'failed');
  assert.equal(g.run.refusal(), 'the known sentence');
  assert.equal(g.run.answer(), null);
});

test('cancel posts the cancel route while the run runs, reads its answer as a poll, and goes on polling until it ends', async () => {
  const f = fixture();
  f.answer('POST', PATH, ok({ id: ID, status: 'running' }));
  f.answer('GET', runPath(PATH, ID), view('running'));
  await f.run.start(f.deps, '{}');
  await settled();
  f.answer('POST', runPath(PATH, ID, true), view('running', { cancelRequested: true }));
  await f.run.cancel(f.deps);
  assert.deepEqual(f.calls.at(-1), { method: 'POST', path: runPath(PATH, ID, true), body: undefined, scope: 'USER', headers: undefined });
  assert.equal(f.run.status(), 'running');
  f.answer('GET', runPath(PATH, ID), view('canceled', { cancelRequested: true }));
  await f.flush();
  assert.equal(f.run.status(), 'canceled');
  const sent = f.calls.length;
  await f.run.cancel(f.deps);
  assert.equal(f.calls.length, sent, 'a run that is no longer running is not canceled');
});

test('a run its poll no longer finds leaves the screen (a swept run, or one that was never the caller\'s)', async () => {
  // Mutation (Rule 19): drop the 404 branch of `read` -> the run still reads running and this goes red.
  const f = fixture();
  f.answer('POST', PATH, ok({ id: ID, status: 'running' }));
  f.answer('GET', runPath(PATH, ID), view('running'));
  await f.run.start(f.deps, '{}');
  await settled();
  f.answer('GET', runPath(PATH, ID), refused(404, 'TEST.NOTFOUND', 'No run of yours has this id.'));
  await f.flush();
  assert.equal(f.run.id(), null);
  assert.equal(f.run.status(), null);
  assert.equal(f.run.answer(), null);
  assert.equal(f.run.refusal(), '');
  assert.equal(f.run.busy(), false);
  assert.equal(f.scheduled.length, 0, 'nothing is polled for a run that is gone');
});

test('a transient poll failure polls again and changes nothing the screen shows', async () => {
  // Mutation (Rule 19): drop the transient branch of `read` -> the 503 reads as a refusal and no poll is scheduled.
  const f = fixture();
  f.answer('POST', PATH, ok({ id: ID, status: 'running' }));
  f.answer('GET', runPath(PATH, ID), view('running'));
  await f.run.start(f.deps, '{}');
  await settled();
  for (const transient of [
    { kind: 'installing', status: 503, code: 'INSTALL.PENDING' },
    { kind: 'error', status: 0, code: null, reason: null, detail: null },
    refused(503, 'API.UNAVAILABLE', 'unavailable'),
  ]) {
    f.answer('GET', runPath(PATH, ID), transient);
    await f.flush();
    assert.equal(f.run.status(), 'running', `a ${transient.kind} ${transient.status} leaves the run running`);
    assert.equal(f.run.refusal(), '');
    assert.equal(f.scheduled.length, 1, 'and the next poll is scheduled');
  }
});

test("any other poll refusal ends the polling, with its sentence, and the run no longer reads running", async () => {
  const f = fixture();
  f.answer('POST', PATH, ok({ id: ID, status: 'running' }));
  f.answer('GET', runPath(PATH, ID), refused(403, 'AUTH.NOPRIVILEGE', 'denied'));
  await f.run.start(f.deps, '{}');
  await settled();
  assert.equal(f.run.status(), 'failed');
  assert.equal(f.run.refusal(), 'denied');
  assert.equal(f.run.busy(), false);
  assert.equal(f.scheduled.length, 0);
  f.answer('POST', PATH, ok({ id: ID, status: 'running' }));
  f.answer('GET', runPath(PATH, ID), ok({ unexpected: true }));
  await f.run.start(f.deps, '{}');
  await settled();
  assert.equal(f.run.refusal(), STRINGS.connectivityRequestRefused, 'a body that is no view with no sentence reads "request refused"');
});

test('an answer of an older poll, and a tick scheduled before stop, are dropped', async () => {
  // Mutation (Rule 19): drop the generation comparison in `poll` -> the older answer lands and this goes red.
  const f = fixture();
  f.answer('POST', PATH, ok({ id: ID, status: 'running' }));
  f.answer('GET', runPath(PATH, ID), view('running'));
  await f.run.start(f.deps, '{}');
  await settled();
  let late = () => {};
  f.answer('GET', runPath(PATH, ID), () => new Promise((resolve) => (late = () => resolve(view('ended', { result: { outcome: 'rows', rows: [['old']] } })))));
  const tick = f.scheduled.splice(0)[0];
  tick();
  f.run.stop();
  late();
  await settled();
  assert.equal(f.run.status(), 'running', 'the answer of a poll that stop() outdated is dropped');
  assert.equal(f.run.answer(), null);

  const sent = f.calls.length;
  f.run.stop();
  tick();
  await settled();
  assert.equal(f.calls.length, sent, 'a tick scheduled before stop sends nothing');
});

test('a run whose start answered after polling stopped is attached unpolled', async () => {
  const f = fixture();
  let release = () => {};
  f.answer('POST', PATH, () => new Promise((resolve) => (release = () => resolve(ok({ id: ID, status: 'running' })))));
  const started = f.run.start(f.deps, '{}');
  f.run.stop();
  release();
  assert.deepEqual(await started, { kind: 'attached', id: ID });
  await settled();
  assert.equal(f.run.status(), 'running');
  assert.equal(f.calls.length, 1, 'no poll was sent for it');
  f.answer('GET', runPath(PATH, ID), view('ended', { result: { outcome: 'rows', rows: [] } }));
  await f.run.poll(f.deps);
  assert.equal(f.run.status(), 'ended', 'the page that returns follows it');
});

test('backgroundViewOf reads a view and answers null for any other shape', () => {
  const answerOf = (result) => result ?? null;
  const refusalText = (code, reason, detail) => `${code}|${reason}|${detail?.x}`;
  assert.deepEqual(backgroundViewOf({ id: ID, status: 'ended', result: 7, refusal: { code: 'C', reason: 'R', detail: { x: 1 } } }, answerOf, refusalText), {
    id: ID,
    status: 'ended',
    answer: 7,
    refusal: 'C|R|1',
  });
  assert.equal(backgroundViewOf({ id: ID, status: 'unheard-of' }, answerOf, refusalText), null);
  assert.equal(backgroundViewOf({ status: 'ended' }, answerOf, refusalText), null);
  assert.equal(backgroundViewOf(null, answerOf, refusalText), null);
  assert.equal(backgroundViewOf('text', answerOf, refusalText), null);
});
