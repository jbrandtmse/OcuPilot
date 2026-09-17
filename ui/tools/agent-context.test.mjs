import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the one source of the context chip's facts and the caller's sharing choice
// (`GET/PUT /api/ocupilot/agent/context`, Story 4.11): the answered/unanswered gate, the seven
// projected fields, the optimistic `setShare` mirror and its revert on refusal, the
// generation/request/newest stale-answer guard `AgentStatus` also carries, and the `agent-switch`
// re-read.
//
// Mutations (Rule 19):
// - settle `answered()` on a malformed body -> the malformed-body test goes red.
// - drop the generation check from `read()`/`setShare()` -> the departed-principal tests go red.
// - drop the `request` sequence check -> the overtaken-load test goes red.
// - skip the revert on a refused `PUT` -> the refusal test goes red, and the switch would show a
//   choice the instance never stored.
// - subscribe to every bus event rather than `changed` on `agent-switch` -> the bus test's call
//   count goes red.
// - drop the `connectivity.retryWhenReachable` park -> the parked-read test goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { AgentContext, AGENT_CONTEXT_PATH, NO_CONTEXT_INFO } = await import(corePath('agent-context.ts'));
const { AGENT_SWITCH_ENTITY, AGENT_DEFINITION_SCOPE, AGENT_DEFINITION_ENTITY } = await import(
  corePath('agent-status.ts')
);
const { ChangeBus } = await import(corePath('change-bus.ts'));

const SETTLE = () => new Promise((resolve) => setImmediate(resolve));

function ok(body, status = 200) {
  return { kind: 'ok', status, body };
}

const REFUSED = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'no', detail: null };

const FULL_INFO = {
  share: true,
  shareDefault: true,
  userChoice: null,
  contextRowCap: 200,
  provider: 'Anthropic',
  endpointHost: 'api.anthropic.com',
  leavesInstance: true,
};

/** Answers taken in order; the last one repeats, like `agent-status.test.mjs`'s `stubApi`. */
function stubApi(answers) {
  const calls = [];
  return {
    calls,
    requestJson: async (path, init = {}) => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body });
      const index = Math.min(calls.length - 1, answers.length - 1);
      return answers[index];
    },
  };
}

function releasableApi(release) {
  const calls = [];
  return {
    calls,
    requestJson: (path, init = {}) =>
      new Promise((resolve) => release.push({ resolve, path, method: init.method ?? 'GET', body: init.body })),
  };
}

test('nothing is answered before the first read, and every accessor reads the pre-answer default', () => {
  const context = new AgentContext({ api: stubApi([ok(FULL_INFO)]) });
  assert.equal(context.answered(), false);
  assert.equal(context.share(), NO_CONTEXT_INFO.share);
  assert.equal(context.contextRowCap(), NO_CONTEXT_INFO.contextRowCap);
  assert.equal(context.leavesInstance(), null);
});

test('a load settles all seven fields', async () => {
  const context = new AgentContext({ api: stubApi([ok(FULL_INFO)]) });
  await context.load();
  assert.equal(context.answered(), true);
  assert.equal(context.share(), true);
  assert.equal(context.shareDefault(), true);
  assert.equal(context.userChoice(), null);
  assert.equal(context.contextRowCap(), 200);
  assert.equal(context.provider(), 'Anthropic');
  assert.equal(context.endpointHost(), 'api.anthropic.com');
  assert.equal(context.leavesInstance(), true);
});

test('userChoice and leavesInstance carry a stored boolean when the instance has one', async () => {
  const context = new AgentContext({
    api: stubApi([ok({ ...FULL_INFO, userChoice: false, leavesInstance: false })]),
  });
  await context.load();
  assert.equal(context.userChoice(), false);
  assert.equal(context.leavesInstance(), false);
});

test('a body that is not the shape this read expects settles nothing rather than throwing', async () => {
  for (const body of [null, 7, 'no']) {
    const context = new AgentContext({ api: stubApi([ok(body)]) });
    await context.load();
    assert.equal(context.answered(), false, `body ${JSON.stringify(body)} must not settle`);
  }
});

test('a flag that is not the boolean true does not count, and a non-string provider is empty', async () => {
  const context = new AgentContext({
    api: stubApi([ok({ share: 'true', shareDefault: 1, contextRowCap: '200', provider: 7, endpointHost: null })]),
  });
  await context.load();
  assert.equal(context.share(), false);
  assert.equal(context.shareDefault(), false);
  assert.equal(context.contextRowCap(), NO_CONTEXT_INFO.contextRowCap, 'a non-number cap falls back');
  assert.equal(context.provider(), '');
  assert.equal(context.endpointHost(), '');
});

test('a failed read settles nothing and leaves the previous answer standing', async () => {
  const api = stubApi([ok(FULL_INFO), REFUSED]);
  const context = new AgentContext({ api });
  await context.load();
  await context.load();
  assert.equal(context.answered(), true);
  assert.equal(context.provider(), 'Anthropic', 'the refusal never overwrote the standing answer');
});

test('a failed read is parked with the connectivity service', async () => {
  const parked = [];
  const context = new AgentContext({
    api: stubApi([REFUSED, ok(FULL_INFO)]),
    connectivity: { retryWhenReachable: (key, run) => parked.push({ key, run }) },
  });
  await context.load();
  assert.equal(context.answered(), false);
  assert.deepEqual(parked.map((entry) => entry.key), [AGENT_CONTEXT_PATH]);
  parked[0].run();
  await SETTLE();
  assert.equal(context.answered(), true);
});

test('a late answer to a read a departed principal issued is dropped', async () => {
  const release = [];
  const context = new AgentContext({ api: releasableApi(release) });
  const inFlight = context.load();
  context.reset();
  release[0].resolve(ok(FULL_INFO));
  await inFlight;
  assert.equal(context.answered(), false, 'the answer belonged to whoever asked, not to the tab');
});

test('of two reads in flight, the one that asked LAST settles the answer', async () => {
  const release = [];
  const context = new AgentContext({ api: releasableApi(release) });
  const first = context.load();
  const second = context.load();
  assert.equal(release.length, 2);

  release[1].resolve(ok(FULL_INFO));
  await second;
  assert.equal(context.provider(), 'Anthropic');

  release[0].resolve(ok({ ...FULL_INFO, provider: 'stale' }));
  await first;
  assert.equal(context.provider(), 'Anthropic', 'the overtaken read does not get to answer');
});

test('`setShare` mirrors at once, then adopts the PUT\'s 200 body', async () => {
  const api = stubApi([ok(FULL_INFO), ok({ ...FULL_INFO, share: false, userChoice: false })]);
  const context = new AgentContext({ api });
  await context.load();
  assert.equal(context.share(), true);

  const applied = context.setShare(false);
  assert.equal(context.share(), false, 'the mirror is synchronous, before the PUT settles');
  assert.equal(await applied, true);
  assert.equal(context.share(), false);
  assert.equal(context.userChoice(), false, 'the adopted body is the source, not the caller\'s boolean alone');

  const call = api.calls.at(-1);
  assert.equal(call.path, AGENT_CONTEXT_PATH);
  assert.equal(call.method, 'PUT');
  assert.deepEqual(JSON.parse(call.body), { share: false });
});

test('a refused `setShare` reverts the mirror and settles false', async () => {
  const api = stubApi([ok(FULL_INFO), REFUSED]);
  const context = new AgentContext({ api });
  await context.load();

  const applied = await context.setShare(false);
  assert.equal(applied, false);
  assert.equal(context.share(), true, 'the mirror reverted to the server\'s own value');
});

test('a `setShare` whose 200 body is malformed reverts the mirror and settles false', async () => {
  // Mutation (Rule 19): drop the `next === null` revert branch in `setShare` -> this goes red,
  // since the mirror would stand at `false` and the caller would be told the write succeeded.
  const api = stubApi([ok(FULL_INFO), ok(null)]);
  const context = new AgentContext({ api });
  await context.load();
  assert.equal(context.share(), true);

  const applied = await context.setShare(false);
  assert.equal(applied, false, 'a malformed body was never actually adopted, so the write did not land');
  assert.equal(context.share(), true, 'the mirror reverted to the server\'s own value');
});

test('a `setShare` issued after sign-out never lands', async () => {
  const release = [];
  const context = new AgentContext({ api: releasableApi(release) });
  const firstLoad = context.load();
  release[0].resolve(ok(FULL_INFO));
  await firstLoad;

  const applied = context.setShare(false);
  context.reset();
  release[1].resolve(ok({ ...FULL_INFO, share: false }));
  assert.equal(await applied, false);
  assert.equal(context.answered(), false, 'reset already cleared the answer, and the late PUT must not revive it');
});

test('`reset()` forgets the answer and notifies', async () => {
  const context = new AgentContext({ api: stubApi([ok(FULL_INFO)]) });
  await context.load();
  let notifications = 0;
  context.subscribe(() => {
    notifications += 1;
  });
  context.reset();
  assert.equal(context.answered(), false);
  assert.equal(context.provider(), '');
  assert.equal(notifications, 1);
});

test('subscribers hear an answer that moved, and are left alone by one that did not', async () => {
  const api = stubApi([ok(FULL_INFO), ok(FULL_INFO), ok({ ...FULL_INFO, contextRowCap: 50 })]);
  const context = new AgentContext({ api });
  let notifications = 0;
  context.subscribe(() => {
    notifications += 1;
  });
  await context.load();
  assert.equal(notifications, 1, 'the first answer is always news');
  await context.load();
  assert.equal(notifications, 1, 'a re-read that confirms what is on screen re-renders nothing');
  await context.load();
  assert.equal(notifications, 2, 'and one that moved does');
});

test('AD-14: an `agent-switch` `changed` event re-reads; a definition\'s own change does not', async () => {
  const api = stubApi([ok(FULL_INFO), ok({ ...FULL_INFO, contextRowCap: 400 })]);
  const bus = new ChangeBus();
  const context = new AgentContext({ api, bus });
  await context.load();
  assert.equal(api.calls.length, 1);

  bus.publish({ kind: 'changed', type: AGENT_DEFINITION_ENTITY, scope: AGENT_DEFINITION_SCOPE, id: '1' });
  await SETTLE();
  assert.equal(api.calls.length, 1, 'a definition changing is not what this store listens for');

  bus.publish({ kind: 'changed', type: AGENT_SWITCH_ENTITY, scope: AGENT_DEFINITION_SCOPE, id: 'instance' });
  await SETTLE();
  assert.equal(api.calls.length, 2, 'a changed row cap or default is');
  assert.equal(context.contextRowCap(), 400);
});
