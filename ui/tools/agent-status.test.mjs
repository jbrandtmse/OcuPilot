import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the one fact the first-login gate, the panel's two empty states and the rail's attention
// dot all turn on: does this instance hold an enabled agent definition (FR-28)?
//
// Mutations (Rule 19):
// - read `enabled` as truthy rather than `=== true` -> the all-disabled test goes red, because a
//   row that carries the key at all would count as configured.
// - drop the generation check in `load()` -> the late-answer test goes red, and a read a departed
//   principal issued would settle the answer for the one who replaced them.
// - settle `answered()` on a failed read -> the failed-read test goes red, and the panel would
//   pick an audience from an answer nobody gave.
// - subscribe to every bus event rather than to `changed` on this type -> the bus test's request
//   count goes red.
// - drop the `request` sequence check in `load()` -> the out-of-order test goes red, and the
//   answer an Enable just corrected is overwritten by the one it replaced.
// - drop the `connectivity.retryWhenReachable` park -> the parked-read test goes red, and one
//   transport fault removes the panel, the dot and the gate for the life of the tab.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { AgentStatus, AGENT_DEFINITIONS_PATH, AGENT_DEFINITION_ENTITY, AGENT_DEFINITION_SCOPE } =
  await import(corePath('agent-status.ts'));
const { ChangeBus } = await import(corePath('change-bus.ts'));

const SETTLE = () => new Promise((resolve) => setImmediate(resolve));

function ok(body) {
  return { kind: 'ok', status: 200, body };
}

const REFUSED = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'no', detail: null };

/**
 * The smallest thing `AgentStatus` needs: something that answers `requestJson`. Answers are taken
 * in order and the last one repeats, so a test states only the answers it cares about.
 */
function stubApi(answers) {
  const calls = [];
  return {
    calls,
    requestJson: async (path) => {
      calls.push(path);
      return answers[Math.min(calls.length - 1, answers.length - 1)];
    },
  };
}

function rows(...enabled) {
  return { definitions: enabled.map((flag, index) => ({ id: String(index), name: 'a', enabled: flag })) };
}

test('nothing is answered before the first read, and nothing is configured either', () => {
  const status = new AgentStatus({ api: stubApi([ok(rows())]) });
  assert.equal(status.answered(), false);
  assert.equal(status.configured(), false);
});

test('an empty list answers unconfigured', async () => {
  const api = stubApi([ok({ definitions: [] })]);
  const status = new AgentStatus({ api });
  await status.load();
  assert.deepEqual(api.calls, [AGENT_DEFINITIONS_PATH], 'the read is the ungated selection list');
  assert.equal(status.answered(), true);
  assert.equal(status.configured(), false);
});

test('rows that are all disabled answer unconfigured -- the question is enabled, not present', async () => {
  const status = new AgentStatus({ api: stubApi([ok(rows(false, false, false))]) });
  await status.load();
  assert.equal(status.answered(), true);
  assert.equal(status.configured(), false);
});

test('one enabled row among disabled ones answers configured', async () => {
  const status = new AgentStatus({ api: stubApi([ok(rows(false, true, false))]) });
  await status.load();
  assert.equal(status.configured(), true);
});

test('a row whose `enabled` is not the boolean true does not count', async () => {
  // The projection ships a JSON boolean; anything else is a shape this client did not ask for,
  // and reading it as truthy would call an instance configured on the string "false".
  const status = new AgentStatus({
    api: stubApi([ok({ definitions: [{ id: '1', enabled: 'true' }, { id: '2', enabled: 1 }] })]),
  });
  await status.load();
  assert.equal(status.answered(), true);
  assert.equal(status.configured(), false);
});

test('a body that is not the shape this read expects answers unconfigured rather than throwing', async () => {
  for (const body of [null, {}, { definitions: 'no' }, 7]) {
    const status = new AgentStatus({ api: stubApi([ok(body)]) });
    await status.load();
    assert.equal(status.answered(), true, `body ${JSON.stringify(body)} still settles`);
    assert.equal(status.configured(), false);
  }
});

test('a failed read settles nothing and leaves the previous answer standing', async () => {
  const api = stubApi([ok(rows(true)), REFUSED]);
  const status = new AgentStatus({ api });
  await status.load();
  assert.equal(status.configured(), true);

  await status.load();
  assert.equal(status.answered(), true, 'the earlier answer is still the answer');
  assert.equal(status.configured(), true, 'and a refusal never means "unconfigured"');
});

test('a first read that fails leaves `answered()` false, so no consumer picks an audience', async () => {
  const status = new AgentStatus({ api: stubApi([REFUSED]) });
  await status.load();
  assert.equal(status.answered(), false);
  assert.equal(status.configured(), false);
});

test('a late answer to a read a departed principal issued is dropped', async () => {
  let release = null;
  const api = {
    requestJson: () => new Promise((resolve) => {
      release = resolve;
    }),
  };
  const status = new AgentStatus({ api });
  const inFlight = status.load();
  status.reset();
  release(ok(rows(true)));
  await inFlight;
  assert.equal(status.answered(), false, 'the answer belonged to whoever asked, not to the tab');
  assert.equal(status.configured(), false);
});

test('of two reads in flight, the one that asked LAST settles the answer', async () => {
  // Reachable without a `reset()`: `App` loads on every signed-in pass and the bus loads on every
  // definition change, so an Enable's read can overtake one already in flight. The answer the
  // stale one carries is the pre-Enable one, which would re-light the dot and the banner.
  const release = [];
  const api = {
    requestJson: () => new Promise((resolve) => release.push(resolve)),
  };
  const status = new AgentStatus({ api });

  const first = status.load();
  const second = status.load();
  assert.equal(release.length, 2, 'both reads are in flight');

  // The newer read answers first -- an Enable landed -- and then the older one arrives.
  release[1](ok(rows(true)));
  await second;
  assert.equal(status.configured(), true);

  release[0](ok({ definitions: [] }));
  await first;
  assert.equal(status.configured(), true, 'the overtaken read does not get to answer');
  assert.equal(status.answered(), true);
});

test('a failed read is parked with the connectivity service, so it re-runs when the instance answers', async () => {
  // The bus cannot be the only retry: on an unconfigured instance no definition will change, and
  // the surfaces that would prompt one are all withheld while `answered()` is false.
  const parked = [];
  const connectivity = {
    retryWhenReachable: (key, run) => parked.push({ key, run }),
  };
  const api = stubApi([REFUSED, ok(rows(true))]);
  const status = new AgentStatus({ api, connectivity });

  await status.load();
  assert.equal(status.answered(), false, 'nothing is answered yet');
  assert.deepEqual(parked.map((entry) => entry.key), [AGENT_DEFINITIONS_PATH]);

  // The instance answers again and the park drains.
  parked[0].run();
  await SETTLE();
  assert.equal(status.answered(), true, 'the read ran again on its own');
  assert.equal(status.configured(), true);
});

test('a successful read parks nothing', async () => {
  const parked = [];
  const status = new AgentStatus({
    api: stubApi([ok(rows(true))]),
    connectivity: { retryWhenReachable: (key, run) => parked.push({ key, run }) },
  });
  await status.load();
  assert.deepEqual(parked, []);
});

test('`reset()` forgets the answer and notifies', async () => {
  const status = new AgentStatus({ api: stubApi([ok(rows(true))]) });
  await status.load();
  let notifications = 0;
  status.subscribe(() => {
    notifications += 1;
  });
  status.reset();
  assert.equal(status.answered(), false);
  assert.equal(status.configured(), false);
  assert.equal(notifications, 1);
});

test('subscribers hear an answer that moved, and are left alone by one that did not', async () => {
  const api = stubApi([ok({ definitions: [] }), ok({ definitions: [] }), ok(rows(true))]);
  const status = new AgentStatus({ api });
  let notifications = 0;
  status.subscribe(() => {
    notifications += 1;
  });

  await status.load();
  assert.equal(notifications, 1, 'the first answer is always news: it is what makes it answered');

  await status.load();
  assert.equal(notifications, 1, 'a re-read that confirms what is on screen re-renders nothing');

  await status.load();
  assert.equal(notifications, 2, 'and an answer that moved is');
  assert.equal(status.configured(), true);
});

test("AD-14: a definition's `changed` event re-reads, and nothing else on the bus does", async () => {
  const api = stubApi([ok({ definitions: [] }), ok(rows(true))]);
  const bus = new ChangeBus();
  const status = new AgentStatus({ api, bus });
  await status.load();
  assert.equal(status.configured(), false);
  assert.equal(api.calls.length, 1);

  // Another entity type's change says nothing about the agent.
  bus.publish({ kind: 'changed', type: 'web-application', scope: 'HSCUSTOM', id: '/csp/myapp' });
  // A proposal against a definition says a proposal is live, not that the instance moved.
  bus.publish({
    kind: 'proposal-open',
    type: AGENT_DEFINITION_ENTITY,
    scope: AGENT_DEFINITION_SCOPE,
    id: '1',
    proposalId: 'p1',
  });
  await SETTLE();
  assert.equal(api.calls.length, 1, `neither is a re-read: ${JSON.stringify(api.calls)}`);

  bus.publish({
    kind: 'changed',
    type: AGENT_DEFINITION_ENTITY,
    scope: AGENT_DEFINITION_SCOPE,
    id: '1',
  });
  await SETTLE();
  await SETTLE();
  assert.equal(api.calls.length, 2, 'an Enable is');
  assert.equal(status.configured(), true, 'and the answer moved with it');
});
