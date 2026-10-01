// Pins the data-egress line's client half (Story 16.15, AD-42): `parseEgress` reads the wire
// `egress` member and refuses anything but its exact shape, the progress poll carries it into the
// live entry and the finished one, a restored conversation carries each entry's own, and
// `egressLine` words the three cases from the published strings with `<provider>` and `<host>`
// filled.
//
// Mutations (Rule 19):
// - make `parseEgress` accept a missing `leavesInstance` as false -> "a malformed egress parses to
//   null" goes red.
// - drop `egress` from `pollOnce`'s spread -> "the poll carries egress" goes red.
// - make `egressLine` ignore `contextSent` -> "sharing off reads the no-context sentence" goes red.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { TurnStore, CONVERSATION_PATH, TURN_PATH, CONVERSATION_STORAGE_KEY, conversationReadPath, turnProgressPath, parseEgress } =
  await import(corePath('turn.ts'));
const { egressLine } = await import(corePath('egress-line.ts'));
const { STRINGS } = await import(corePath('strings.ts'));

const LEFT = { provider: 'turnprobe', endpointHost: '192.0.2.10', leavesInstance: true, contextSent: true };
const STAYED = { provider: 'turnprobe', endpointHost: '10.0.0.5', leavesInstance: false, contextSent: true };
const NONE = { provider: 'turnprobe', endpointHost: '192.0.2.10', leavesInstance: true, contextSent: false };

function ok(body, status = 200) {
  return { kind: 'ok', status, body };
}

/** Per-path response queues; the last answer repeats. */
function fakeApi(responses = {}) {
  const seen = new Map();
  return {
    requestJson: async (path) => {
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
  };
}

function fakeSchedule() {
  const scheduled = [];
  return { schedule: (run, delayMs) => scheduled.push({ run, delayMs }), scheduled };
}

const settle = () => new Promise((resolve) => setImmediate(resolve));

test('a well-formed egress parses to exactly its four members', () => {
  assert.deepEqual(parseEgress({ ...LEFT, extra: 1 }), LEFT);
  assert.deepEqual(parseEgress(STAYED), STAYED);
});

test('a missing, null or malformed egress parses to null', () => {
  for (const value of [
    undefined,
    null,
    '',
    'text',
    [],
    [LEFT],
    {},
    { ...LEFT, provider: '' },
    { ...LEFT, provider: 1 },
    { ...LEFT, endpointHost: null },
    { ...LEFT, leavesInstance: 'true' },
    { ...LEFT, contextSent: 1 },
    { provider: 'turnprobe', endpointHost: '192.0.2.10', contextSent: true },
    { provider: 'turnprobe', endpointHost: '192.0.2.10', leavesInstance: true },
  ]) {
    assert.equal(parseEgress(value), null, JSON.stringify(value) ?? 'undefined');
  }
});

test("the poll carries egress into the live entry, and the finished entry keeps it", async () => {
  const { schedule, scheduled } = fakeSchedule();
  const api = fakeApi({
    [CONVERSATION_PATH]: [ok({ conversationId: 'convo-1' }, 201)],
    [TURN_PATH]: [ok({ turnId: 'turn-1' }, 202)],
    [turnProgressPath('turn-1')]: [
      ok({ turnId: 'turn-1', state: 'running', steps: [], stepsDropped: 0, reply: null, error: null, egress: null }),
      ok({ turnId: 'turn-1', state: 'running', steps: [], stepsDropped: 0, reply: null, error: null, egress: LEFT }),
      ok({ turnId: 'turn-1', state: 'completed', steps: [], stepsDropped: 0, reply: 'ok', error: null, egress: LEFT }),
    ],
  });
  const turn = new TurnStore({ api, storage: memoryStorage(), navigationType: () => 'navigate', schedule });
  void turn.send('where did it go');
  await settle();
  await settle();
  await settle();
  assert.equal(turn.entries().at(-1).egress, null, 'the live entry starts with none');
  scheduled.shift().run();
  await settle();
  assert.equal(turn.entries().at(-1).egress, null, 'a poll before any dispatched call carries none');
  scheduled.shift().run();
  await settle();
  assert.deepEqual(turn.entries().at(-1).egress, LEFT, 'the poll carries egress once a call was dispatched');
  scheduled.shift().run();
  await settle();
  const finished = turn.entries().at(-1);
  assert.equal(finished.live, false);
  assert.deepEqual(finished.egress, LEFT, 'and the finished entry keeps it');
});

test('a restored conversation carries each entry its own egress, and an older entry none', async () => {
  const storage = memoryStorage({ [CONVERSATION_STORAGE_KEY]: 'convo-1' });
  const api = fakeApi({
    [conversationReadPath('convo-1')]: [
      ok({
        conversationId: 'convo-1',
        turns: [
          { seq: 1, message: 'old', state: 'completed', reply: 'a', error: null, steps: [], stepsDropped: 0 },
          { seq: 2, message: 'on A', state: 'completed', reply: 'b', error: null, steps: [], stepsDropped: 0, egress: LEFT },
          { seq: 3, message: 'on B', state: 'completed', reply: 'c', error: null, steps: [], stepsDropped: 0, egress: STAYED },
        ],
      }),
    ],
  });
  const turn = new TurnStore({ api, storage, navigationType: () => 'reload' });
  await turn.restore();
  const [older, onA, onB] = turn.entries();
  assert.equal(older.egress, null);
  assert.deepEqual(onA.egress, LEFT);
  assert.deepEqual(onB.egress, STAYED);
});

test("egressLine words the three cases from the published strings, filled", () => {
  const fill = (template, egress) =>
    template.split('<provider>').join(egress.provider).split('<host>').join(egress.endpointHost);
  assert.deepEqual(egressLine(LEFT), { text: fill(STRINGS.egressLineLeft, LEFT), leaves: true });
  assert.deepEqual(egressLine(STAYED), { text: fill(STRINGS.egressLineStayed, STAYED), leaves: false });
  assert.equal(
    egressLine(LEFT).text,
    "This turn's screen context went to turnprobe at 192.0.2.10 and left the instance.",
    'no placeholder survives'
  );
  assert.equal(egressLine(null), null, 'no egress, no line');
});

test('sharing off reads the no-context sentence, naming the provider only, whatever the verdict', () => {
  assert.deepEqual(egressLine(NONE), { text: 'This turn sent no screen context to turnprobe.', leaves: false });
  assert.equal(egressLine(NONE).text, STRINGS.egressLineNone.split('<provider>').join('turnprobe'));
  assert.equal(egressLine({ ...STAYED, contextSent: false }).text, egressLine(NONE).text);
});
