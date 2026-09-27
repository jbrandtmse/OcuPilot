// Pins the turns-an-hour refusal on the client (Story 14.6, AD-41): the banner renders the
// instance's `retryAt` as a zero-padded 24-hour `hh:mm` in the browser's own time zone, the
// transcript line carries the limit, the store turns a `403 TURN.LIMITHOUR` into its own banner
// state and a local refused entry rather than a send error, and the server's sentence is the
// published banner byte for byte.
//
// **The time zone is fixed before any Date exists.** `Asia/Kolkata` is UTC+05:30, so a UTC
// rendering can never pass for a local one: the minutes differ as well as the hours.
//
// Mutations (Rule 19):
// - render with `getUTCHours`/`getUTCMinutes` in `turnLimitBanner` -> the banner tests go red.
// - drop the `TURN.LIMITHOUR` arm from `TurnStore.send` -> the store test goes red.
// - reword `REASONTURNLIMITHOUR` in `Error.cls` -> the pin goes red naming both.

process.env.TZ = 'Asia/Kolkata';

const { test } = await import('node:test');
const assert = (await import('node:assert/strict')).default;
const { readFileSync } = await import('node:fs');
const { fileURLToPath } = await import('node:url');
const { dirname, join } = await import('node:path');

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = join(uiRoot, '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { TURN_LIMIT_CODE, turnLimitBanner, turnLimitLine, turnLimitOf } = await import(corePath('turn-limit.ts'));
const { TurnStore, CONVERSATION_PATH, TURN_PATH, turnErrorBanner } = await import(corePath('turn.ts'));
const { STRINGS } = await import(corePath('strings.ts'));

function ok(body, status = 200) {
  return { kind: 'ok', status, body };
}

function err(status, code, reason = 'refused', detail = null) {
  return { kind: 'error', status, code, reason, detail };
}

/** Per-path response queues, and every call recorded. */
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

function memoryStorage() {
  const map = new Map();
  return {
    getItem: (key) => (map.has(key) ? map.get(key) : null),
    setItem: (key, value) => map.set(key, value),
    removeItem: (key) => map.delete(key),
  };
}

const freshTab = () => () => 'navigate';

/** The server's sentence for 3 at 14:05 UTC, as `Api/Turn.RenderHourLimit` fills it. */
const SERVER_REASON = "You have reached this instance's limit of 3 agent turns an hour. You can send again at 14:05 UTC.";

const REFUSAL = err(403, 'TURN.LIMITHOUR', SERVER_REASON, { limit: 3, retryAt: '2026-09-27T14:05:00Z' });

test('the time zone this suite pins is really in force', () => {
  assert.equal(new Date('2026-09-27T14:05:00Z').getTimezoneOffset(), -330, 'Asia/Kolkata is UTC+05:30');
});

test('the banner renders retryAt as local hh:mm, zero-padded, with the limit filled', () => {
  assert.equal(
    turnLimitBanner(3, '2026-09-27T14:05:00Z'),
    "You have reached this instance's limit of 3 agent turns an hour. You can send again at 19:35."
  );
  assert.equal(
    turnLimitBanner(12, '2026-09-27T18:31:00Z'),
    "You have reached this instance's limit of 12 agent turns an hour. You can send again at 00:01.",
    'past local midnight the hour is 00, not 24, and both halves keep two digits'
  );
});

test('the transcript line carries the limit', () => {
  assert.equal(turnLimitLine(3), 'This turn was not started: you have used your 3 turns for this hour.');
});

test('turnLimitOf accepts only a whole limit of at least 1 and a retryAt that is a date', () => {
  assert.deepEqual(turnLimitOf({ limit: 3, retryAt: '2026-09-27T14:05:00Z' }), { limit: 3, retryAt: '2026-09-27T14:05:00Z' });
  assert.equal(turnLimitOf(null), null);
  assert.equal(turnLimitOf({ limit: 0, retryAt: '2026-09-27T14:05:00Z' }), null);
  assert.equal(turnLimitOf({ limit: 1.5, retryAt: '2026-09-27T14:05:00Z' }), null);
  assert.equal(turnLimitOf({ limit: '3', retryAt: '2026-09-27T14:05:00Z' }), null);
  assert.equal(turnLimitOf({ limit: 3, retryAt: 'soon' }), null);
  assert.equal(turnLimitOf({ limit: 3 }), null);
});

test('a start refused TURN.LIMITHOUR raises the limit state and a local refused entry, never a send error', async () => {
  const api = fakeApi({
    [CONVERSATION_PATH]: [ok({ conversationId: 'convo-1' }, 201)],
    [TURN_PATH]: [REFUSAL, ok({ turnId: 'turn-1' }, 202)],
  });
  const turn = new TurnStore({ api, storage: memoryStorage(), navigationType: freshTab(), schedule: () => {} });

  assert.equal(await turn.send('list namespaces'), 'error', 'the send is refused');
  assert.deepEqual(turn.turnLimit(), { limit: 3, retryAt: '2026-09-27T14:05:00Z' }, 'the limit state is the refusal detail');
  assert.equal(turn.sendError(), null, 'and is not a send error');
  assert.equal(turn.locked(), false, 'nor the lock banner');
  assert.equal(turn.busy(), false, 'and the store is idle again');
  const entries = turn.entries();
  assert.equal(entries.length, 1, 'the refused turn is one entry');
  const [entry] = entries;
  assert.equal(entry.seq, -1, 'with no server position');
  assert.equal(entry.message, 'list namespaces', 'carrying the message');
  assert.equal(entry.state, 'failed');
  assert.equal(entry.live, false);
  assert.deepEqual(entry.error, { seq: 0, code: TURN_LIMIT_CODE, reason: turnLimitLine(3) });
  assert.equal(
    turnErrorBanner(entry, STRINGS.agentTurnStoppedBanner, STRINGS.agentTurnStoppedNoStepBanner),
    'This turn was not started: you have used your 3 turns for this hour.',
    'and the transcript renders the published line verbatim, not wrapped in the stopped template'
  );

  assert.equal(await turn.send('again'), 'sent', 'the next send is accepted');
  assert.equal(turn.turnLimit(), null, 'and clears the limit state');
  assert.equal(turn.entries()[0].error?.code, TURN_LIMIT_CODE, 'the refused line stays in this tab');
});

test('a new conversation and a sign-out each clear the limit state', async () => {
  for (const clear of ['newConversation', 'endSession']) {
    const api = fakeApi({
      [CONVERSATION_PATH]: [ok({ conversationId: 'convo-1' }, 201), ok({ conversationId: 'convo-2' }, 201)],
      [TURN_PATH]: [REFUSAL],
    });
    const turn = new TurnStore({ api, storage: memoryStorage(), navigationType: freshTab(), schedule: () => {} });
    await turn.send('hello');
    assert.notEqual(turn.turnLimit(), null, `${clear}: the limit is raised`);
    if (clear === 'newConversation') {
      assert.equal(await turn.newConversation(), true, 'a new conversation is minted');
    } else {
      turn.endSession();
    }
    assert.equal(turn.turnLimit(), null, `${clear}: clears it`);
    assert.equal(turn.entries().length, 0, `${clear}: and the refused line with the transcript`);
  }
});

test('a TURN.LIMITHOUR whose detail is not a limit falls back to the server sentence as a send error', async () => {
  const api = fakeApi({
    [CONVERSATION_PATH]: [ok({ conversationId: 'convo-1' }, 201)],
    [TURN_PATH]: [err(403, 'TURN.LIMITHOUR', SERVER_REASON, null)],
  });
  const turn = new TurnStore({ api, storage: memoryStorage(), navigationType: freshTab(), schedule: () => {} });
  assert.equal(await turn.send('hello'), 'error');
  assert.equal(turn.turnLimit(), null);
  assert.deepEqual(turn.sendError(), { status: 403, code: 'TURN.LIMITHOUR', reason: SERVER_REASON });
  assert.equal(turn.entries().length, 0);
});

test("Error.cls's REASONTURNLIMITHOUR is the published banner, byte for byte", () => {
  const source = readFileSync(join(repoRoot, 'src', 'OcuPilot', 'Api', 'Error.cls'), 'utf8');
  const match = /^Parameter REASONTURNLIMITHOUR = "([^"]*)";$/m.exec(source);
  assert.notEqual(match, null, 'Error.cls declares REASONTURNLIMITHOUR');
  assert.equal(match[1], STRINGS.agentTurnLimitBanner, 'REASONTURNLIMITHOUR and agentTurnLimitBanner are one sentence');
});
