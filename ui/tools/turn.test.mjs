import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the turn store (Story 4.5): send ensures a conversation, polls every 1,000 ms, stops,
// locks on busy or 409, restores with the navigation-kind rule, starts a new conversation, and
// clears itself at sign-out. Every I/O & Edge-Case Matrix row of the spec is a test below.
//
// **No test here waits on a clock.** The 1,000 ms poll is driven by hand through the injected
// `schedule` seam, the same idiom `refresh.test.mjs` uses: a fake schedule records
// `{run, delayMs}` and a test calls `run()` itself.
//
// Mutations (Rule 19):
// - drop the `busyValue` guard at the top of `send()` -> "a second send while busy is refused
//   locally" goes red, and two turns would race the same slot.
// - stop clearing `lockedValue` at the start of a fresh `send()` -> "the lock clears on the next
//   attempt" goes red, and a stale 409 would lock the composer forever.
// - answer the error banner for a `stopped` entry -> "a stop is never an error" goes red.
// - drop the `generation` check in `pollOnce`/`finally` -> "endSession cancels a pending poll"
//   goes red, a stray tick would resurrect a turn after sign-out.
// - read `continuesThisTab` without checking the stored id -> "a fresh tab ignores a stray key"
//   goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const {
  TurnStore,
  CONVERSATION_PATH,
  TURN_PATH,
  CONVERSATION_STORAGE_KEY,
  conversationReadPath,
  turnProgressPath,
  turnStopPath,
  stepLabel,
  turnErrorBanner,
  isTerminalState,
} = await import(corePath('turn.ts'));
const { STRINGS } = await import(corePath('strings.ts'));

function ok(body, status = 200) {
  return { kind: 'ok', status, body };
}

function err(status, code, reason = 'refused') {
  return { kind: 'error', status, code, reason, detail: null };
}

/** Per-path response queues, and every call recorded (path, method, body). */
function fakeApi(responses = {}) {
  const calls = [];
  const seen = new Map();
  return {
    calls,
    requestJson: async (path, init = {}) => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body });
      const list = responses[path] ?? [];
      const index = seen.get(path) ?? 0;
      seen.set(path, index + 1);
      if (list.length === 0) return ok({});
      return list[Math.min(index, list.length - 1)];
    },
  };
}

function memoryStorage(initial = {}) {
  const map = new Map(Object.entries(initial));
  return {
    getItem: (key) => (map.has(key) ? map.get(key) : null),
    setItem: (key, value) => map.set(key, value),
    removeItem: (key) => map.delete(key),
    map,
  };
}

function fakeSchedule() {
  const scheduled = [];
  const schedule = (run, delayMs) => scheduled.push({ run, delayMs });
  return { schedule, scheduled };
}

function freshTab() {
  return () => 'navigate';
}

function reloadedTab() {
  return () => 'reload';
}

const settle = () => new Promise((resolve) => setImmediate(resolve));

function step(overrides = {}) {
  return {
    seq: 1,
    kind: 'tool',
    name: 'shell.namespaces.read',
    status: 'ok',
    summary: '',
    text: '',
    code: '',
    truncated: false,
    target: '',
    arguments: '',
    result: null,
    reason: '',
    failedPair: '',
    ...overrides,
  };
}

// --- Construction / navigation-kind adoption --------------------------------------------------

test('a fresh or duplicated tab starts with no conversation and drops a stray stored id', () => {
  const storage = memoryStorage({ [CONVERSATION_STORAGE_KEY]: 'stale-id' });
  const api = fakeApi();
  const turn = new TurnStore({ api, storage, navigationType: freshTab() });
  assert.equal(turn.conversationId(), null);
  assert.equal(storage.getItem(CONVERSATION_STORAGE_KEY), null);
});

test('a reload adopts a stored conversation id', () => {
  const storage = memoryStorage({ [CONVERSATION_STORAGE_KEY]: 'convo-1' });
  const api = fakeApi();
  const turn = new TurnStore({ api, storage, navigationType: reloadedTab() });
  assert.equal(turn.conversationId(), 'convo-1');
});

// --- restore() ---------------------------------------------------------------------------------

test('restore() with no adopted id settles at once with an empty transcript', async () => {
  const api = fakeApi();
  const turn = new TurnStore({ api, storage: memoryStorage(), navigationType: freshTab() });
  await turn.restore();
  assert.equal(turn.restored(), true);
  assert.deepEqual(turn.entries(), []);
  assert.equal(api.calls.length, 0);
});

test('Reload: restore() replays both a completed and a stopped turn, with no running card', async () => {
  const storage = memoryStorage({ [CONVERSATION_STORAGE_KEY]: 'convo-1' });
  const api = fakeApi({
    [conversationReadPath('convo-1')]: [
      ok({
        conversationId: 'convo-1',
        turns: [
          { seq: 1, message: 'hi', state: 'completed', reply: 'hello', error: null, steps: [step()], stepsDropped: 0 },
          {
            seq: 2,
            message: 'stop me',
            state: 'stopped',
            reply: null,
            error: { seq: 1, code: 'TURN.STOPPED', reason: 'Stopped' },
            steps: [step({ status: 'stopped' })],
            stepsDropped: 0,
          },
        ],
      }),
    ],
  });
  const turn = new TurnStore({ api, storage, navigationType: reloadedTab() });
  await turn.restore();
  const entries = turn.entries();
  assert.equal(entries.length, 2);
  assert.equal(entries[0].reply, 'hello');
  assert.equal(entries[1].state, 'stopped');
  for (const entry of entries) {
    assert.equal(entry.live, false);
    assert.ok(entry.steps.every((s) => s.status !== 'running'), 'no restored step is running');
  }
});

test('restore() drops the id on a 404 -- the conversation is gone', async () => {
  const storage = memoryStorage({ [CONVERSATION_STORAGE_KEY]: 'convo-1' });
  const api = fakeApi({
    [conversationReadPath('convo-1')]: [err(404, 'TURN.CONVERSATION.NOTFOUND')],
  });
  const turn = new TurnStore({ api, storage, navigationType: reloadedTab() });
  await turn.restore();
  assert.equal(turn.conversationId(), null);
  assert.equal(storage.getItem(CONVERSATION_STORAGE_KEY), null);
  assert.deepEqual(turn.entries(), []);
});

test('restore() keeps the id over a transport fault -- only a confirmed 404 drops it', async () => {
  const storage = memoryStorage({ [CONVERSATION_STORAGE_KEY]: 'convo-1' });
  const api = fakeApi({ [conversationReadPath('convo-1')]: [err(0, null)] });
  const turn = new TurnStore({ api, storage, navigationType: reloadedTab() });
  await turn.restore();
  assert.equal(turn.conversationId(), 'convo-1');
});

// --- send(): one read, ensuring a conversation ---------------------------------------------

test('Send, one read: ensures a conversation, posts the turn, polls to a card then a reply', async () => {
  const storage = memoryStorage();
  const { schedule, scheduled } = fakeSchedule();
  const api = fakeApi({
    [CONVERSATION_PATH]: [ok({ conversationId: 'convo-1' }, 201)],
    [TURN_PATH]: [ok({ turnId: 'turn-1' }, 202)],
    [turnProgressPath('turn-1')]: [
      ok({ turnId: 'turn-1', state: 'running', steps: [step({ status: 'running' })], stepsDropped: 0, reply: null, error: null }),
      ok({ turnId: 'turn-1', state: 'completed', steps: [step()], stepsDropped: 0, reply: 'the answer', error: null }),
    ],
  });
  const turn = new TurnStore({ api, storage, navigationType: freshTab(), schedule });

  const sent = turn.send('list namespaces');
  assert.equal(turn.busy(), true, 'busy synchronously, before either network call is even issued');
  await settle();
  await settle();
  await settle();
  assert.equal(turn.conversationId(), 'convo-1');
  assert.equal(storage.getItem(CONVERSATION_STORAGE_KEY), 'convo-1');

  assert.equal(scheduled.length, 1, 'one poll armed at 1,000 ms');
  assert.equal(scheduled[0].delayMs, 1000);
  let live = turn.entries().at(-1);
  assert.equal(live.live, true);
  assert.equal(live.message, 'list namespaces');

  scheduled.shift().run();
  await settle();
  live = turn.entries().at(-1);
  assert.equal(live.steps.length, 1);
  assert.equal(live.steps[0].status, 'running');
  assert.equal(live.state, 'running');
  assert.equal(turn.busy(), true, 'still running after the first card');

  assert.equal(scheduled.length, 1, 'the next poll is armed');
  scheduled.shift().run();
  await settle();

  const outcome = await sent;
  assert.equal(outcome, 'sent');
  assert.equal(turn.busy(), false);
  const finished = turn.entries().at(-1);
  assert.equal(finished.live, false);
  assert.equal(finished.state, 'completed');
  assert.equal(finished.reply, 'the answer');
  assert.equal(turnErrorBanner(finished, STRINGS.agentTurnStoppedBanner), null, 'a completed turn shows no error banner');
});

test("send()'s promise settles as soon as the turn is accepted, not once it ends -- panel.ts clears the draft on this", async () => {
  const { schedule, scheduled } = fakeSchedule();
  const api = fakeApi({
    [CONVERSATION_PATH]: [ok({ conversationId: 'convo-1' }, 201)],
    [TURN_PATH]: [ok({ turnId: 'turn-1' }, 202)],
    [turnProgressPath('turn-1')]: [ok({ turnId: 'turn-1', state: 'running', steps: [], stepsDropped: 0, reply: null, error: null })],
  });
  const turn = new TurnStore({ api, storage: memoryStorage(), navigationType: freshTab(), schedule });

  const outcome = await turn.send('hi');
  assert.equal(outcome, 'sent');
  assert.equal(turn.busy(), true, 'the turn is still running -- send() did not wait for it to end');
  assert.equal(scheduled.length, 1, 'polling continues on its own after send() has already resolved');
});

test('send(): a failed conversation-creation resolves \'error\', clears busy, and never posts a turn', async () => {
  const api = fakeApi({ [CONVERSATION_PATH]: [err(500, 'INTERNAL')] });
  const turn = new TurnStore({ api, storage: memoryStorage(), navigationType: freshTab() });

  const outcome = await turn.send('hi');
  assert.equal(outcome, 'error');
  assert.equal(turn.busy(), false);
  assert.equal(api.calls.some((c) => c.path === TURN_PATH), false, 'no POST /turn when the conversation could not be created');
});

test('createConversation(): endSession() while POST /conversation is in flight leaves the id and storage untouched', async () => {
  const storage = memoryStorage();
  const calls = [];
  const releases = [];
  const api = {
    calls,
    requestJson: async (path, init = {}) => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body });
      if (path === CONVERSATION_PATH) {
        return new Promise((resolve) => releases.push(resolve));
      }
      return ok({});
    },
  };
  const turn = new TurnStore({ api, storage, navigationType: freshTab() });

  const sent = turn.send('hi');
  await settle();
  assert.equal(turn.busy(), true);
  assert.equal(releases.length, 1, 'the POST /conversation call is in flight');

  turn.endSession();
  assert.equal(turn.conversationId(), null);
  assert.equal(storage.getItem(CONVERSATION_STORAGE_KEY), null);

  releases[0](ok({ conversationId: 'convo-1' }, 201));
  await settle();
  await settle();

  assert.equal(turn.conversationId(), null, 'the departed request must not resurrect a conversation id');
  assert.equal(storage.getItem(CONVERSATION_STORAGE_KEY), null, 'nor write it back into storage');
  assert.equal(await sent, 'error');
});

// --- Stop mid-call -------------------------------------------------------------------------

test('Stop mid-call: the tool step the loop was about to run becomes a stopped step, no reply, no error banner', async () => {
  const { schedule, scheduled } = fakeSchedule();
  const api = fakeApi({
    [CONVERSATION_PATH]: [ok({ conversationId: 'convo-1' }, 201)],
    [TURN_PATH]: [ok({ turnId: 'turn-1' }, 202)],
    [turnProgressPath('turn-1')]: [
      ok({
        turnId: 'turn-1',
        state: 'stopped',
        steps: [step({ status: 'stopped', name: 'shell.namespaces.read', target: '' })],
        stepsDropped: 0,
        reply: null,
        error: { seq: 1, code: 'TURN.STOPPED', reason: 'Stopped by the caller' },
      }),
    ],
  });
  const turn = new TurnStore({ api, storage: memoryStorage(), navigationType: freshTab(), schedule });

  const sent = turn.send('do something slow');
  await settle();
  await settle();

  const stopResult = turn.stop();
  scheduled.shift().run();
  await settle();
  assert.equal(await stopResult, false, 'the fake stop endpoint answers the default ok({}) body');

  const outcome = await sent;
  assert.equal(outcome, 'sent');
  const finished = turn.entries().at(-1);
  assert.equal(finished.state, 'stopped');
  assert.equal(finished.reply, null);
  assert.equal(turnErrorBanner(finished, STRINGS.agentTurnStoppedBanner), null, 'a stop is never an error');
  assert.equal(finished.steps[0].status, 'stopped');
  assert.equal(stepLabel(finished.steps[0]), 'shell.namespaces.read');

  const stopCall = api.calls.find((c) => c.path === turnStopPath('turn-1'));
  assert.ok(stopCall, 'POST /turn/:id/stop was called');
  assert.equal(stopCall.method, 'POST');
});

// --- Second send: local busy, and a 409 from another tab -----------------------------------

test('Second send: a second send while this tab is busy is refused locally, no request, lock banner', async () => {
  const { schedule } = fakeSchedule();
  const api = fakeApi({
    [CONVERSATION_PATH]: [ok({ conversationId: 'convo-1' }, 201)],
    [TURN_PATH]: [ok({ turnId: 'turn-1' }, 202)],
    [turnProgressPath('turn-1')]: [ok({ turnId: 'turn-1', state: 'running', steps: [], stepsDropped: 0, reply: null, error: null })],
  });
  const turn = new TurnStore({ api, storage: memoryStorage(), navigationType: freshTab(), schedule });

  void turn.send('first');
  await settle();
  await settle();
  assert.equal(turn.busy(), true);
  const callsBefore = api.calls.length;

  const second = await turn.send('second');
  assert.equal(second, 'locked');
  assert.equal(turn.locked(), true);
  assert.equal(api.calls.length, callsBefore, 'no network call for the locally-refused send');
  assert.equal(turn.entries().length, 1, 'no second message appended');
});

test('Second send: another tab holding the slot answers 409, and this tab shows the same lock banner', async () => {
  const api = fakeApi({
    [CONVERSATION_PATH]: [ok({ conversationId: 'convo-1' }, 201)],
    [TURN_PATH]: [err(409, 'TURN.BUSY', STRINGS.agentTurnLockBanner)],
  });
  const turn = new TurnStore({ api, storage: memoryStorage(), navigationType: freshTab() });

  const outcome = await turn.send('hello');
  assert.equal(outcome, 'locked');
  assert.equal(turn.locked(), true);
  assert.equal(turn.busy(), false, 'busy clears once the refusal is in');
  assert.equal(turn.entries().length, 0, 'nothing rendered for a refused send');
});

test('the lock clears on the next attempt that gets past the local busy check', async () => {
  const api = fakeApi({
    [CONVERSATION_PATH]: [ok({ conversationId: 'convo-1' }, 201)],
    [TURN_PATH]: [err(409, 'TURN.BUSY'), ok({ turnId: 'turn-2' }, 202)],
    [turnProgressPath('turn-2')]: [ok({ turnId: 'turn-2', state: 'completed', steps: [], stepsDropped: 0, reply: 'ok', error: null })],
  });
  const { schedule, scheduled } = fakeSchedule();
  const turn = new TurnStore({ api, storage: memoryStorage(), navigationType: freshTab(), schedule });

  assert.equal(await turn.send('first'), 'locked');
  assert.equal(turn.locked(), true);

  const second = turn.send('second');
  await settle();
  assert.equal(turn.locked(), false, 'cleared as soon as a fresh attempt passes the local check');
  scheduled.shift().run();
  await settle();
  assert.equal(await second, 'sent');
});

test('locked() clears when the turn that was busy finishes, without a second send attempt', async () => {
  const { schedule, scheduled } = fakeSchedule();
  const api = fakeApi({
    [CONVERSATION_PATH]: [ok({ conversationId: 'convo-1' }, 201)],
    [TURN_PATH]: [ok({ turnId: 'turn-1' }, 202)],
    [turnProgressPath('turn-1')]: [ok({ turnId: 'turn-1', state: 'completed', steps: [], stepsDropped: 0, reply: 'ok', error: null })],
  });
  const turn = new TurnStore({ api, storage: memoryStorage(), navigationType: freshTab(), schedule });

  const sent = turn.send('first');
  await settle();
  await settle();
  assert.equal(turn.busy(), true);

  // A same-tab Enter-while-busy attempt raises the lock banner, with no second network call.
  const second = await turn.send('second');
  assert.equal(second, 'locked');
  assert.equal(turn.locked(), true);

  scheduled.shift().run();
  await settle();

  assert.equal(await sent, 'sent');
  assert.equal(turn.busy(), false);
  assert.equal(turn.locked(), false, 'the banner clears when this tab\'s own turn ends');
});

// --- New conversation -----------------------------------------------------------------------

test('newConversation() is refused while busy, and clears the transcript when it is not', async () => {
  const api = fakeApi({ [CONVERSATION_PATH]: [ok({ conversationId: 'convo-1' }, 201), ok({ conversationId: 'convo-2' }, 201)] });
  const turn = new TurnStore({ api, storage: memoryStorage(), navigationType: freshTab() });

  const { schedule } = fakeSchedule();
  const busyApi = fakeApi({
    [CONVERSATION_PATH]: [ok({ conversationId: 'convo-1' }, 201)],
    [TURN_PATH]: [ok({ turnId: 'turn-1' }, 202)],
    [turnProgressPath('turn-1')]: [ok({ turnId: 'turn-1', state: 'running', steps: [], stepsDropped: 0, reply: null, error: null })],
  });
  const busyTurn = new TurnStore({ api: busyApi, storage: memoryStorage(), navigationType: freshTab(), schedule });
  void busyTurn.send('x');
  await settle();
  await settle();
  assert.equal(await busyTurn.newConversation(), false);

  assert.equal(await turn.newConversation(), true);
  assert.equal(turn.conversationId(), 'convo-1');
  assert.deepEqual(turn.entries(), []);
});

// --- endSession ------------------------------------------------------------------------------

test('endSession cancels a pending poll and clears the id, in memory and in storage', async () => {
  const storage = memoryStorage();
  const { schedule, scheduled } = fakeSchedule();
  const api = fakeApi({
    [CONVERSATION_PATH]: [ok({ conversationId: 'convo-1' }, 201)],
    [TURN_PATH]: [ok({ turnId: 'turn-1' }, 202)],
    [turnProgressPath('turn-1')]: [ok({ turnId: 'turn-1', state: 'running', steps: [], stepsDropped: 0, reply: null, error: null })],
  });
  const turn = new TurnStore({ api, storage, navigationType: freshTab(), schedule });

  const sent = turn.send('hi');
  await settle();
  await settle();
  assert.equal(turn.busy(), true);

  turn.endSession();
  assert.equal(turn.busy(), false);
  assert.equal(turn.conversationId(), null);
  assert.equal(storage.getItem(CONVERSATION_STORAGE_KEY), null);
  assert.deepEqual(turn.entries(), []);

  // The poll that was already armed still fires (nothing cancels a timer, per `refresh.ts`'s own
  // idiom), but its generation is stale, so it changes nothing.
  const before = turn.entries();
  scheduled.shift().run();
  await settle();
  assert.deepEqual(turn.entries(), before);
  await sent;
});

// --- Pure projections: stepLabel / turnErrorBanner ------------------------------------------

test('stepLabel is the name alone with no target, and "name target" with one', () => {
  assert.equal(stepLabel({ name: 'provider', target: '' }), 'provider');
  assert.equal(stepLabel({ name: 'shell.webapps.read', target: '/csp/myapp' }), 'shell.webapps.read /csp/myapp');
});

test('turnErrorBanner names the step at error.seq and substitutes both placeholders', () => {
  const entry = {
    state: 'failed',
    error: { seq: 2, code: 'PROVIDER.TIMEOUT', reason: 'The provider timed out.' },
    steps: [step({ seq: 1, name: 'provider', kind: 'model' }), step({ seq: 2, name: 'shell.namespaces.read', status: 'error' })],
  };
  const banner = turnErrorBanner(entry, STRINGS.agentTurnStoppedBanner);
  assert.equal(banner, 'The turn stopped at shell.namespaces.read: The provider timed out.');
});

test('turnErrorBanner is null with no error, and null for completed/stopped even with one', () => {
  assert.equal(turnErrorBanner({ state: 'running', error: null, steps: [] }, STRINGS.agentTurnStoppedBanner), null);
  assert.equal(
    turnErrorBanner(
      { state: 'completed', error: { seq: 1, code: 'X', reason: 'r' }, steps: [] },
      STRINGS.agentTurnStoppedBanner
    ),
    null
  );
  assert.equal(
    turnErrorBanner(
      { state: 'stopped', error: { seq: 1, code: 'TURN.STOPPED', reason: 'r' }, steps: [] },
      STRINGS.agentTurnStoppedBanner
    ),
    null
  );
});

// --- Failed tool -----------------------------------------------------------------------------

test('Failed tool: a failed step carries its reason and failedPair through restore unchanged', async () => {
  const storage = memoryStorage({ [CONVERSATION_STORAGE_KEY]: 'convo-1' });
  const api = fakeApi({
    [conversationReadPath('convo-1')]: [
      ok({
        conversationId: 'convo-1',
        turns: [
          {
            seq: 1,
            message: 'disable it',
            state: 'failed',
            reply: null,
            error: { seq: 1, code: 'AUTH.NOPRIVILEGE', reason: 'no privilege' },
            steps: [
              step({
                status: 'error',
                code: 'AUTH.NOPRIVILEGE',
                reason: 'no privilege',
                failedPair: '%Admin_Secure:USE',
              }),
            ],
            stepsDropped: 0,
          },
        ],
      }),
    ],
  });
  const turn = new TurnStore({ api, storage, navigationType: reloadedTab() });
  await turn.restore();
  const entry = turn.entries()[0];
  assert.equal(entry.steps[0].failedPair, '%Admin_Secure:USE');
  assert.equal(entry.steps[0].reason, 'no privilege');
});

// --- Markup is carried, never interpreted here ----------------------------------------------

test('Markup in a reply or a step is carried as a literal string -- rendering is the template\'s job, not the store\'s', async () => {
  const storage = memoryStorage({ [CONVERSATION_STORAGE_KEY]: 'convo-1' });
  const markup = '<img src="http://203.0.113.9/x">';
  const api = fakeApi({
    [conversationReadPath('convo-1')]: [
      ok({
        conversationId: 'convo-1',
        turns: [{ seq: 1, message: 'hi', state: 'completed', reply: markup, error: null, steps: [], stepsDropped: 0 }],
      }),
    ],
  });
  const turn = new TurnStore({ api, storage, navigationType: reloadedTab() });
  await turn.restore();
  assert.equal(turn.entries()[0].reply, markup);
});

// --- isTerminalState ---------------------------------------------------------------------------

test('isTerminalState is true for the four terminal states and false for queued/running', () => {
  assert.equal(isTerminalState('completed'), true);
  assert.equal(isTerminalState('stopped'), true);
  assert.equal(isTerminalState('abandoned'), true);
  assert.equal(isTerminalState('failed'), true);
  assert.equal(isTerminalState('queued'), false);
  assert.equal(isTerminalState('running'), false);
});
