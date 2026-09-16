import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the two facts the first-login gate, the panel's banners and empty states, the panel's footer
// line and the rail's attention dot all turn on: does this instance hold an enabled agent
// definition (FR-28), and does anything restrain the agent for this caller (FR-19, FR-20)?
//
// **One load, two reads.** Both facts settle together, so `answered()` is one gate rather than two
// and no consumer renders a panel that knows about the definition and not about the kill switch.
// That is why `stubApi` answers by path and why the release-based tests below resolve requests in
// pairs.
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
// - make an overtaken read `return` instead of awaiting `newest` -> the overtaken-read test goes
//   red, and the first-login gate awaits a promise that resolves before any answer is in.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const {
  AgentStatus,
  AGENT_DEFINITIONS_PATH,
  AGENT_RESTRAINT_PATH,
  AGENT_DEFINITION_ENTITY,
  AGENT_SWITCH_ENTITY,
  AGENT_DEFINITION_SCOPE,
  FOOTER_KEYS,
  UNRESTRAINED,
  formatKillSwitch,
} = await import(corePath('agent-status.ts'));
const { STRINGS } = await import(corePath('strings.ts'));
const { ChangeBus } = await import(corePath('change-bus.ts'));

const SETTLE = () => new Promise((resolve) => setImmediate(resolve));

function ok(body) {
  return { kind: 'ok', status: 200, body };
}

const REFUSED = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'no', detail: null };

/**
 * The smallest thing `AgentStatus` needs: something that answers `requestJson`.
 *
 * Answers are taken in order **per path** and the last one repeats, so a test states only the
 * answers it cares about and a definitions read is not consumed by the restraint read that travels
 * with it. A test that says nothing about the restraint gets the unrestrained verdict.
 */
function stubApi(answers, restraintAnswers = [ok(UNRESTRAINED)]) {
  const calls = [];
  const perPath = new Map();
  return {
    calls,
    requestJson: async (path) => {
      calls.push(path);
      const list = path === AGENT_RESTRAINT_PATH ? restraintAnswers : answers;
      const seen = (perPath.get(path) ?? 0) + 1;
      perPath.set(path, seen);
      return list[Math.min(seen - 1, list.length - 1)];
    },
  };
}

/**
 * A transport that hands back its resolvers, so a test can settle reads by hand. One `load()`
 * issues two requests, definitions first, so load *n* owns `release[2n]` and `release[2n + 1]`.
 */
function releasableApi(release) {
  return { requestJson: () => new Promise((resolve) => release.push(resolve)) };
}

/** Settle one whole load: its definitions read and the restraint read beside it. */
function settleLoad(release, index, definitionsAnswer, restraintAnswer = ok(UNRESTRAINED)) {
  release[index * 2](definitionsAnswer);
  release[index * 2 + 1](restraintAnswer);
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
  assert.deepEqual(
    api.calls,
    [AGENT_DEFINITIONS_PATH, AGENT_RESTRAINT_PATH],
    'one load is two ungated reads: the selection list and this caller\'s own verdict'
  );
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
  const release = [];
  const status = new AgentStatus({ api: releasableApi(release) });
  const inFlight = status.load();
  status.reset();
  settleLoad(release, 0, ok(rows(true)), ok({ ...UNRESTRAINED, killSwitch: true }));
  await inFlight;
  assert.equal(status.answered(), false, 'the answer belonged to whoever asked, not to the tab');
  assert.equal(status.configured(), false);
  assert.equal(status.restraint().killSwitch, false, 'and neither did the verdict');
});

test('of two reads in flight, the one that asked LAST settles the answer', async () => {
  // Reachable without a `reset()`: `App` loads on every signed-in pass and the bus loads on every
  // definition change, so an Enable's read can overtake one already in flight. The answer the
  // stale one carries is the pre-Enable one, which would re-light the dot and the banner.
  const release = [];
  const status = new AgentStatus({ api: releasableApi(release) });

  const first = status.load();
  const second = status.load();
  assert.equal(release.length, 4, 'both loads are in flight, two reads each');

  // The newer load answers first -- an Enable landed -- and then the older one arrives.
  settleLoad(release, 1, ok(rows(true)));
  await second;
  assert.equal(status.configured(), true);

  settleLoad(release, 0, ok({ definitions: [] }));
  await first;
  assert.equal(status.configured(), true, 'the overtaken read does not get to answer');
  assert.equal(status.answered(), true);
});

test('awaiting a read a later one overtook still gives the caller an answer', async () => {
  // `load()`'s promise means "the answer is in", not "my request came back". The first-login gate
  // awaits the read `App` issued on the pass that saw the sign-in, and a form login issues two
  // passes -- `adopt()` notifies, then `runSubmit()` notifies again -- so the gate's own read is
  // overtaken on every form sign-in. Resolving it unanswered made AC1 turn on whether the
  // navigation map happened to be slower than the second definitions read.
  const release = [];
  const status = new AgentStatus({ api: releasableApi(release) });

  const gate = status.load();
  status.load();
  assert.equal(release.length, 4, 'both loads are in flight, two reads each');

  // The loads answer in the order they were asked, which is the ordinary case: the overtaken one
  // comes back FIRST and carries an answer it is not allowed to settle.
  let resolved = false;
  void gate.then(() => {
    resolved = true;
  });
  settleLoad(release, 0, ok(rows(false)));
  await SETTLE();
  assert.equal(status.answered(), false, 'nothing has settled the answer yet');
  assert.equal(resolved, false, 'and the caller is still waiting rather than holding an empty one');

  settleLoad(release, 1, ok(rows(false)));
  await gate;
  assert.equal(status.answered(), true, 'the overtaken read waited for the one that owns the answer');
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
  assert.equal(api.calls.length, 2, 'one load, two reads');

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
  assert.equal(api.calls.length, 2, `neither is a re-read: ${JSON.stringify(api.calls)}`);

  bus.publish({
    kind: 'changed',
    type: AGENT_DEFINITION_ENTITY,
    scope: AGENT_DEFINITION_SCOPE,
    id: '1',
  });
  await SETTLE();
  await SETTLE();
  assert.equal(api.calls.length, 4, 'an Enable is');
  assert.equal(status.configured(), true, 'and the answer moved with it');
});

// --- Story 3.7: the restraint fact -------------------------------------------------------------
//
// Mutations (Rule 19):
// - read `blocked` as truthy rather than `=== true` -> the narrowing test goes red.
// - accept any `footerKey` the wire carries -> the unknown-key test goes red, and `stringFor`
//   answers '' for it, which reaches the panel as a blank footer line.
// - drop `agent-switch` from `onChange` -> the bus test goes red, and the panel's banners keep
//   standing over a switch that has just been turned off.
// - compare only `configured` in `read()`'s `moved` test -> the notify test goes red, and a kill
//   switch flipped by another administrator never re-renders the panel.

test('a clean instance answers the unrestrained verdict, and the off footer key', async () => {
  const status = new AgentStatus({ api: stubApi([ok(rows(true))]) });
  await status.load();
  assert.equal(status.restrained(), false);
  assert.deepEqual(status.restraint(), UNRESTRAINED);
  assert.equal(status.restraint().footerKey, 'statusReadOnlyOff');
});

test('the verdict is narrowed key by key: a flag that is not the boolean true does not count', async () => {
  const status = new AgentStatus({
    api: stubApi(
      [ok(rows(true))],
      [ok({ blocked: 'true', killSwitch: 1, enforcedReadOnly: null, code: 7, killSwitchReason: {} })]
    ),
  });
  await status.load();
  const verdict = status.restraint();
  assert.equal(verdict.blocked, false);
  assert.equal(verdict.killSwitch, false);
  assert.equal(verdict.enforcedReadOnly, false);
  assert.equal(verdict.code, '', 'a code that is not a string is no code');
  assert.equal(verdict.killSwitchReason, '');
});

test('a footerKey the server may not answer with falls back to the off key', async () => {
  // It reaches `stringFor`, which answers '' for a key the source does not hold -- and a blank
  // footer line says less than the off one.
  for (const footerKey of ['statusNoSuchKey', '', 42, 'constructor']) {
    const status = new AgentStatus({
      api: stubApi([ok(rows(true))], [ok({ ...UNRESTRAINED, footerKey })]),
    });
    await status.load();
    assert.equal(status.restraint().footerKey, 'statusReadOnlyOff', `footerKey ${JSON.stringify(footerKey)}`);
  }
  // And each key the server MAY answer with survives, which is the other half of the roster.
  for (const footerKey of FOOTER_KEYS) {
    const status = new AgentStatus({
      api: stubApi([ok(rows(true))], [ok({ ...UNRESTRAINED, footerKey })]),
    });
    await status.load();
    assert.equal(status.restraint().footerKey, footerKey);
  }
});

test('every footer key the verdict may answer with exists in the string source', () => {
  // The server half is `OcuPilot.Test.Restraint`, which pins the same three literals against
  // `OcuPilot.Kernel.Restraint`'s own parameters -- so a key renamed on either side reddens.
  assert.equal(FOOTER_KEYS.length, 3, 'three now; statusReadOnlyForYou is Story 14.5\'s');
  for (const key of FOOTER_KEYS) {
    assert.ok(Object.hasOwn(STRINGS, key), `${key} is a published string key`);
    assert.ok(STRINGS[key].length > 0, `${key} carries a sentence`);
  }
});

test('the kill switch and enforced read-only are each restraining; the definition alone is not', async () => {
  // `restrained()` is what widens the panel's `shown`, and it is the two sources EXPERIENCE.md
  // gives a banner. A read-only definition restrains writes without one -- the footer line is
  // where that shows.
  const cases = [
    [{ killSwitch: true }, true],
    [{ enforcedReadOnly: true }, true],
    [{ blocked: true, footerKey: 'statusReadOnlyByDefinition' }, false],
    [{}, false],
  ];
  for (const [verdict, expected] of cases) {
    const status = new AgentStatus({
      api: stubApi([ok(rows(true))], [ok({ ...UNRESTRAINED, ...verdict })]),
    });
    await status.load();
    assert.equal(status.restrained(), expected, JSON.stringify(verdict));
  }
});

test('a restraint read that fails settles nothing, so no banner is drawn from an answer nobody gave', async () => {
  const status = new AgentStatus({ api: stubApi([ok(rows(true))], [REFUSED]) });
  await status.load();
  assert.equal(status.answered(), false, 'neither fact settles while either read failed');
  assert.equal(status.configured(), false);
});

test('a failed restraint read is parked under its own path', async () => {
  const parked = [];
  const status = new AgentStatus({
    api: stubApi([ok(rows(true))], [REFUSED, ok({ ...UNRESTRAINED, killSwitch: true })]),
    connectivity: { retryWhenReachable: (key, run) => parked.push({ key, run }) },
  });
  await status.load();
  assert.deepEqual(parked.map((entry) => entry.key), [AGENT_RESTRAINT_PATH]);
  parked[0].run();
  await SETTLE();
  await SETTLE();
  assert.equal(status.answered(), true, 'the read ran again on its own');
  assert.equal(status.restraint().killSwitch, true);
});

test('AD-14: a switch `changed` event re-reads, like a definition\'s', async () => {
  const api = stubApi(
    [ok(rows(true))],
    [ok(UNRESTRAINED), ok({ ...UNRESTRAINED, killSwitch: true, killSwitchReason: 'off' })]
  );
  const bus = new ChangeBus();
  const status = new AgentStatus({ api, bus });
  await status.load();
  assert.equal(status.restraint().killSwitch, false);

  bus.publish({
    kind: 'changed',
    type: AGENT_SWITCH_ENTITY,
    scope: AGENT_DEFINITION_SCOPE,
    id: 'instance',
  });
  await SETTLE();
  await SETTLE();
  assert.equal(status.restraint().killSwitch, true, 'the verdict followed the switch');
  assert.equal(status.restraint().killSwitchReason, 'off');
});

test('a verdict that moved notifies, and one that did not is left alone', async () => {
  const api = stubApi(
    [ok(rows(true))],
    [ok(UNRESTRAINED), ok(UNRESTRAINED), ok({ ...UNRESTRAINED, enforcedReadOnly: true })]
  );
  const status = new AgentStatus({ api });
  let notifications = 0;
  status.subscribe(() => {
    notifications += 1;
  });

  await status.load();
  assert.equal(notifications, 1, 'the first answer is always news');
  await status.load();
  assert.equal(notifications, 1, 'a re-read that confirms the verdict re-renders nothing');
  await status.load();
  assert.equal(notifications, 2, 'and a verdict that moved does');
});

test('`reset()` forgets the verdict as well as the answer', async () => {
  const status = new AgentStatus({
    api: stubApi([ok(rows(true))], [ok({ ...UNRESTRAINED, killSwitch: true })]),
  });
  await status.load();
  assert.equal(status.restrained(), true);
  status.reset();
  assert.deepEqual(status.restraint(), UNRESTRAINED, 'a departed principal\'s verdict is not the next one\'s');
});

test('the published kill-switch banner resolves both slots, and takes its two audience words from the placeholder itself', () => {
  const everyone = formatKillSwitch(STRINGS.agentKillSwitchBanner, 'everyone', 'the freeze');
  const you = formatKillSwitch(STRINGS.agentKillSwitchBanner, 'you', 'the review');
  assert.equal(everyone, 'The agent is switched off for everyone: the freeze.');
  assert.equal(you, 'The agent is switched off for you: the review.');
  // Neither placeholder survives, which is what "the client composes no sentence of its own" means
  // at the surface: the words came out of the published literal.
  for (const rendered of [everyone, you]) {
    assert.ok(!rendered.includes('<'), `no placeholder survives: ${rendered}`);
  }
  // An audience the verdict did not name resolves to the broader word.
  assert.equal(
    formatKillSwitch(STRINGS.agentKillSwitchBanner, '', 'no audience'),
    'The agent is switched off for everyone: no audience.'
  );
});
