import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { readdirSync, readFileSync, statSync } from 'node:fs';

// Pins the client half of the minted proposal (Story 5.1): what the turn store reads off the
// progress payload, the two lifecycle events it publishes onto the one bus (AD-43), the expiry
// constant held equal to the instance's own, and the rule that nothing in the client authors a
// proposal.
//
// **No test here waits on a clock.** The poll is driven by hand through the injected `schedule`
// seam, the way `turn.test.mjs` and `refresh.test.mjs` drive theirs.
//
// Mutations (Rule 19):
// - publish `proposal-open` without the `proposalId` -> the bus refuses it, and the
//   `RefreshService` integration test goes red on `paused()`.
// - re-publish `proposal-open` for an id already open -> "an id already open is not opened
//   again" goes red, and one close would no longer lift the pause.
// - close every proposal when the turn ends -> "a turn ending closes nothing" goes red.
// - return the wrong scope from the mint's `EntityRef.Key` (here: publish a scope the bound
//   screen does not carry) -> the `RefreshService` integration test goes red, because the event
//   no longer matches the bound screen's scope.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = join(uiRoot, '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { screenDeclaration } = await import(
  join(uiRoot, 'src', 'app', 'testing', 'screen-declaration.ts')
);
const {
  TurnStore,
  TURN_PATH,
  CONVERSATION_STORAGE_KEY,
  conversationReadPath,
  turnProgressPath,
  parseProposals,
  PROPOSAL_EXPIRED_STATE,
  PROPOSAL_LIVE_STATE,
} = await import(corePath('turn.ts'));
const { ChangeBus, PROPOSAL_EXPIRY_MS } = await import(corePath('change-bus.ts'));
const { RefreshService } = await import(corePath('refresh.ts'));
const { ScreenStores } = await import(corePath('screen-store.ts'));
const { stubAccountPreferences } = await import(
  new URL('../src/app/testing/account-preferences.ts', import.meta.url).href
);

const LIMITS_PATH = join(repoRoot, 'src', 'OcuPilot', 'Kernel', 'Agent', 'Limits.cls');
const APP_DIR = join(uiRoot, 'src', 'app');
const EXAMPLE_PROPOSAL = join(APP_DIR, 'shell', 'example-proposal.ts');

const settle = () => new Promise((resolve) => setImmediate(resolve));

/** The one moment every test here reads. Injected into both the bus and the refresh service, so
 * no assertion depends on the wall clock and the bus's own ten-minute clamp is deterministic. */
const NOW_MS = Date.parse('2026-09-19T09:50:00Z');
const EXPIRES_AT = new Date(NOW_MS + 300_000).toISOString();

function memoryStorage() {
  const map = new Map();
  return {
    getItem: (key) => (map.has(key) ? map.get(key) : null),
    setItem: (key, value) => map.set(key, value),
    removeItem: (key) => map.delete(key),
    map,
  };
}

/** The whole-number value of `Parameter <name> As %Integer = <n>;` in `text`. */
function parameterNumber(text, name) {
  const match = new RegExp(`Parameter ${name}\\s+As %Integer\\s*=\\s*(\\d+)\\s*;`).exec(text);
  if (match === null) throw new Error(`${LIMITS_PATH}: no whole-number Parameter ${name} found`);
  return Number(match[1]);
}

/** A progress body carrying `proposals`, in the shape `OcuPilot.Api.Turn.HandleProgress` answers. */
function progress(proposals, state = 'running') {
  return {
    kind: 'ok',
    status: 200,
    body: {
      turnId: 'turn-1',
      state,
      startedAt: null,
      endedAt: null,
      iterations: 0,
      tokens: { input: 0, output: 0 },
      limit: null,
      steps: [],
      stepsDropped: 0,
      reply: state === 'completed' ? 'done' : null,
      error: null,
      proposals,
    },
  };
}

function proposal(overrides = {}) {
  return {
    proposalId: 'p1',
    target: { type: 'web-application', scope: 'instance', id: '/csp/myapp' },
    expiresAt: EXPIRES_AT,
    tool: 'webapp.list.update',
    changed: [{ field: 'Enabled', before: 'false', after: 'true' }],
    unchangedCount: 38,
    rationale: 'because',
    expectedImpact: 'it serves',
    reverse: 'set it back',
    state: PROPOSAL_LIVE_STATE,
    ...overrides,
  };
}

/**
 * A turn store already running a turn, with the poll in the test's hands: `polls` is the queue of
 * progress answers, one per tick, and `tick()` runs the next scheduled pass.
 */
async function running(polls, bus) {
  const scheduled = [];
  const api = {
    requestJson: async (path) => {
      if (path === TURN_PATH) return { kind: 'ok', status: 202, body: { turnId: 'turn-1' } };
      if (path === turnProgressPath('turn-1')) return polls.shift() ?? progress([]);
      return { kind: 'ok', status: 200, body: {} };
    },
  };
  const turn = new TurnStore({
    api,
    storage: memoryStorage(),
    navigationType: () => 'navigate',
    schedule: (run) => scheduled.push(run),
    // The same fixed clock the bus reads. The store closes a proposal whose own `expiresAt` has
    // passed (DW-1209), so a wall clock here would read every fixture proposal as already expired.
    now: () => NOW_MS,
    bus,
  });
  await turn.send('do it');
  await settle();
  const tick = async () => {
    const run = scheduled.shift();
    if (run === undefined) throw new Error('nothing was scheduled');
    run();
    await settle();
  };
  return { turn, tick, scheduled };
}

/** Every event a bus publishes, in order, over the one injected clock. */
function recordingBus() {
  const bus = new ChangeBus({ now: () => new Date(NOW_MS) });
  const events = [];
  bus.subscribe((event) => events.push(event));
  return { bus, events };
}

// --- The expiry constant -----------------------------------------------------------------------

test('PROPOSAL_EXPIRY_MS is the instance\'s own PROPOSALEXPIRYSECONDS', () => {
  const seconds = parameterNumber(readFileSync(LIMITS_PATH, 'utf8'), 'PROPOSALEXPIRYSECONDS');
  assert.equal(
    PROPOSAL_EXPIRY_MS,
    seconds * 1000,
    'the bus clamps a proposal to AD-6\'s window, so it and the server-side constant are one value'
  );
});

test('the turn record outlives a proposal, so a claim reads a turn that is still there', () => {
  const text = readFileSync(LIMITS_PATH, 'utf8');
  assert.ok(
    parameterNumber(text, 'RETENTIONSECONDS') >= parameterNumber(text, 'PROPOSALEXPIRYSECONDS'),
    'retention below expiry would make a claim answer PROPOSAL.TURNENDED for a turn that merely aged out'
  );
});

// --- Parsing ------------------------------------------------------------------------------------

test('a proposal with no id, or with an incomplete target, is dropped rather than published', () => {
  assert.deepEqual(parseProposals([proposal({ proposalId: '' })]), []);
  assert.deepEqual(parseProposals([proposal({ target: { type: 'web-application', scope: '', id: 'x' } })]), []);
  assert.deepEqual(parseProposals([proposal({ target: { type: '', scope: 'instance', id: 'x' } })]), []);
  assert.deepEqual(parseProposals('not an array'), []);
});

test('a proposal is read whole, with its expiry as epoch milliseconds', () => {
  const [read] = parseProposals([proposal()]);
  assert.equal(read.proposalId, 'p1');
  assert.equal(read.tool, 'webapp.list.update');
  assert.equal(read.unchangedCount, 38);
  assert.equal(read.expiresAt, Date.parse(EXPIRES_AT));
  assert.deepEqual(read.changed, [{ field: 'Enabled', before: 'false', after: 'true', removed: false }]);
  assert.equal(read.rationale, 'because');
  assert.equal(read.expectedImpact, 'it serves');
  assert.equal(read.reverse, 'set it back');
});

test('an unreadable expiry is 0, which the bus replaces with AD-6\'s own window', () => {
  const [read] = parseProposals([proposal({ expiresAt: 'not a moment' })]);
  assert.equal(read.expiresAt, 0);
});

// --- The publisher ------------------------------------------------------------------------------

test('the first poll carrying a live proposal publishes proposal-open once', async () => {
  const { bus, events } = recordingBus();
  const { tick } = await running([progress([proposal()]), progress([proposal()])], bus);
  await tick();
  await tick();
  const opens = events.filter((event) => event.kind === 'proposal-open');
  assert.equal(opens.length, 1, 'an id already open is not opened again');
  assert.equal(opens[0].proposalId, 'p1');
  assert.equal(opens[0].type, 'web-application');
  assert.equal(opens[0].scope, 'instance');
  assert.equal(opens[0].id, '/csp/myapp');
  assert.equal(opens[0].expiresAt, Date.parse(EXPIRES_AT));
});

test('an id that leaves a poll is closed', async () => {
  const { bus, events } = recordingBus();
  const { tick } = await running([progress([proposal()]), progress([])], bus);
  await tick();
  await tick();
  assert.deepEqual(
    events.map((event) => event.kind),
    ['proposal-open', 'proposal-closed']
  );
  assert.equal(events[1].proposalId, 'p1');
});

test('a proposal whose state turns terminal is closed', async () => {
  const { bus, events } = recordingBus();
  const { tick } = await running(
    [progress([proposal()]), progress([proposal({ state: 'confirmed' })])],
    bus
  );
  await tick();
  await tick();
  assert.deepEqual(
    events.map((event) => event.kind),
    ['proposal-open', 'proposal-closed']
  );
});

test('a turn ending closes nothing: a proposal outlives its turn', async () => {
  const { bus, events } = recordingBus();
  const { tick, turn } = await running([progress([proposal()], 'completed')], bus);
  await tick();
  assert.deepEqual(
    events.map((event) => event.kind),
    ['proposal-open']
  );
  assert.equal(turn.busy(), false);
  assert.equal(turn.entries().at(-1).proposals.length, 1);
});

test('sign-out closes every proposal this store opened', async () => {
  const { bus, events } = recordingBus();
  const { tick, turn } = await running([progress([proposal()])], bus);
  await tick();
  turn.endSession();
  assert.deepEqual(
    events.map((event) => event.kind),
    ['proposal-open', 'proposal-closed']
  );
});

// --- Integration with the shipped RefreshService (Rule 1) ---------------------------------------

/** The refresh framework wired the way `src/main.ts` wires it, over `bus`. */
function boundRefresh(bus) {
  const scheduled = [];
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const refresh = new RefreshService({
    stores,
    connectivity: { park: () => () => {}, isOnline: () => true },
    bus,
    namespace: () => 'HSCUSTOM',
    schedule: (run, delayMs) => scheduled.push({ run, delayMs }),
    now: () => new Date(NOW_MS),
  });
  refresh.bind(
    screenDeclaration({
      descriptor: 'OcuPilot.Screen.Descriptor.WebAppList',
      route: 'web-applications/list',
      area: 'web-applications',
      labelKey: 'webAppListLabel',
      refreshes: true,
      refreshRates: [10],
      entityType: 'web-application',
      scope: 'instance',
    }),
    async () => ({ kind: 'ok', rows: [], truncated: false })
  );
  // The chip's own setting: without a rate the timer is off, and "off wins over paused" is a
  // published state of its own (`chipLabel`). The pause is only observable on a screen the user
  // has actually switched on.
  refresh.setRate(10);
  return { refresh, scheduled };
}

test('a proposal the turn store publishes pauses the bound screen, and its close resumes it', async () => {
  const bus = new ChangeBus({ now: () => new Date(NOW_MS) });
  const { refresh } = boundRefresh(bus);
  const { tick } = await running([progress([proposal()]), progress([])], bus);

  assert.equal(refresh.paused(), false);
  await tick();
  assert.equal(refresh.paused(), true, 'a live proposal against the bound entity holds the timer');
  assert.equal(refresh.armedFor(), 'expiry', 'a paused screen arms its pause deadline, never a tick');

  await tick();
  assert.equal(refresh.paused(), false, 'the close lifts the pause');
  assert.equal(refresh.armedFor(), 'tick');
});

test('a proposal against another scope leaves the bound screen running', async () => {
  const bus = new ChangeBus({ now: () => new Date(NOW_MS) });
  const { refresh } = boundRefresh(bus);
  const { tick } = await running(
    [progress([proposal({ target: { type: 'web-application', scope: 'USER', id: '/csp/myapp' } })])],
    bus
  );
  await tick();
  assert.equal(refresh.paused(), false);
});

// --- The restore path (Story 5.2, DW-1213) -----------------------------------------------------

/** A turn store that has restored `convo-1`, whose one turn carries `proposals` on the wire. */
async function restored(proposals) {
  const storage = memoryStorage();
  storage.setItem(CONVERSATION_STORAGE_KEY, 'convo-1');
  const api = {
    requestJson: async (path) => {
      if (path !== conversationReadPath('convo-1')) return { kind: 'ok', status: 200, body: {} };
      return {
        kind: 'ok',
        status: 200,
        body: {
          conversationId: 'convo-1',
          turns: [
            {
              seq: 1,
              message: 'enable the demo application',
              state: 'completed',
              reply: 'I have prepared the change.',
              error: null,
              steps: [],
              stepsDropped: 0,
              proposals,
            },
          ],
        },
      };
    },
  };
  const bus = new ChangeBus({ now: () => new Date(NOW_MS) });
  const events = [];
  bus.subscribe((event) => events.push(event));
  const turn = new TurnStore({ api, storage, navigationType: () => 'reload', bus });
  return { turn, bus, events };
}

test('a restored turn carries its proposals, recorded terminal whatever the wire said (DW-1213)', async () => {
  // Mutation (Rule 19): hard-code `proposals: []` in `parseRestoredEntry` again -> this goes red
  // on the entry carrying none, and a reload would lose the card with no other route to it.
  const { turn } = await restored([proposal()]);
  await turn.restore();
  const entry = turn.entries().at(-1);
  assert.equal(entry.proposals.length, 1, "the restored turn carries the turn's own proposal");
  assert.equal(entry.proposals[0].proposalId, 'p1');
  assert.equal(
    entry.proposals[0].state,
    PROPOSAL_EXPIRED_STATE,
    'and it is terminal on arrival: a restored card is shown expired, with Re-propose'
  );
  assert.equal(entry.live, false);
});

test('Integration AC: a reload arms no pause, so the shipped RefreshService reports paused() false and arms a tick', async () => {
  // The proposal is unburned and unexpired on the instance -- `state` is `live` on the wire, and
  // its expiry is five minutes ahead -- which is exactly the case DW-1213 is about.
  //
  // Mutation (Rule 19): publish the restored set with the wire state, rather than the terminal
  // state `restoredProposals` records -> this goes red, `paused()` reads true after a reload, and
  // nothing lifts it: this tab makes no poll for a turn that has already ended.
  const { turn, bus, events } = await restored([proposal()]);
  const { refresh } = boundRefresh(bus);
  assert.equal(refresh.paused(), false);

  await turn.restore();

  assert.deepEqual(events, [], 'the restore path publishes nothing at all');
  assert.equal(refresh.paused(), false, 'so the bound screen is not paused by a reload');
  assert.equal(refresh.armedFor(), 'tick', 'and it arms a tick rather than a pause deadline');
  // And the card is nonetheless on screen: the entry carries it, terminal.
  assert.equal(turn.entries().at(-1).proposals.length, 1);
});

// --- The client authors no proposal --------------------------------------------------------------

/** Every `.ts` under `ui/src/app`, recursively. */
function clientSources(dir = APP_DIR, found = []) {
  for (const entry of readdirSync(dir).sort()) {
    const path = join(dir, entry);
    if (statSync(path).isDirectory()) {
      clientSources(path, found);
    } else if (entry.endsWith('.ts')) {
      found.push(path);
    }
  }
  return found;
}

test('nothing shipped in the client authors a proposal value, and nothing posts one', () => {
  // AD-6: the instance mints. A shipped client module may read a proposal off the wire and render
  // it; what it may not do is write one of its values down. So the scan is for a *literal* -- a
  // string, a number or a template -- assigned to any field a proposal carries, which is what
  // `shell/example-proposal.ts` alone does and is why it is exempt. Specs and the harness under
  // `testing/` build fixtures by construction and are outside the rule.
  // `auditWarning` joined the wire in Story 5.2 and drives a warning the user reads before
  // confirming a write, so a shipped literal there would suppress a safety sentence rather than
  // merely stale a value -- and because it is a boolean, the literal alternation has to admit
  // `true` and `false` as well as a quoted, numeric or template value.
  // `unchanged` joined the wire in Story 5.8 -- the disclosure's own rows, projected and masked on
  // the instance (DW-1223). A shipped literal there would put a value the classification never
  // admitted under the caption, so it belongs in the alternation like every other proposal field.
  // `destructive` joined the wire in Story 5.10, declared by the write tool's own `DESTRUCTIVE`
  // parameter. A shipped literal there would draw the destructive treatment -- or withhold it --
  // from the client rather than from the tool, which is the safety signal the declaration exists
  // to keep on the instance, so it is in the alternation with `auditWarning` and admits the two
  // boolean spellings for the same reason.
  // `consequence` is the kernel's code for what a write does beyond its diff, and the card states
  // its sentence as a warning -- a shipped literal there would author or suppress that warning.
  const authoring =
    /\b(before|after|unchanged|unchangedCount|rationale|expectedImpact|reverse|fingerprint|auditWarning|destructive|consequence)\s*:\s*('|"|\d|`|true\b|false\b)/;
  // Since Story 5.3 the client does POST to a proposal route -- the id in the path and, in the
  // body, only the fields the target screen declares secret-typed. What it still may not do is
  // post a proposal's own content, so the scan is for a request body that names one.
  // `closedReason` and `confirmedAt` are deliberately absent from the list: the client READS both
  // off the answer to that same POST, within the scan's own window, so naming them here would
  // flag the reader rather than an author.
  const posting =
    /method:\s*'(POST|PUT)'[\s\S]{0,200}\b(payload|fingerprint|changed|diff|unchanged|unchangedCount|targetRef|rationale|expectedImpact|reverse|auditWarning|destructive)\b/i;
  const offenders = [];
  for (const path of clientSources()) {
    if (path === EXAMPLE_PROPOSAL || path.endsWith('.spec.ts') || path.includes(`${join('app', 'testing')}`)) {
      continue;
    }
    const source = readFileSync(path, 'utf8')
      .replace(/\/\*[\s\S]*?\*\//g, '')
      .replace(/^\s*\/\/.*$/gm, '');
    if (authoring.test(source) || posting.test(source)) offenders.push(path.slice(repoRoot.length + 1));
  }
  assert.deepEqual(
    offenders,
    [],
    'a proposal, its diff and its payload come from the instance; only shell/example-proposal.ts holds a literal one'
  );
});
