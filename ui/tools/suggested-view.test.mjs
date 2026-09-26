import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins Home's suggested view (Story 4.10): which lines render and which do not, when Home's prompts
// stand in for them (Story 11.3), and that appending a source appends a line.
//
// `core/suggested-view.ts` is framework-free (AD-19), so this is the one leg that can execute it
// directly -- DOM shape is `panel.spec.ts`'s and geometry is the browser spec's.
//
// Mutations (Rule 19) are named at the tests they redden.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const core = (name) => join(uiRoot, 'src', 'app', 'core', name);

const {
  SuggestedView,
  SOURCES,
  ERROR_LOG_DATES_PATH,
  ERROR_LOG_DESCRIPTOR,
  SWITCHES_DESCRIPTOR,
  formatApplicationErrors,
} = await import(core('suggested-view.ts'));
const { STRINGS } = await import(core('strings.ts'));
const { UNRESTRAINED } = await import(core('agent-status.ts'));
const { HOME_AREA_KEY, screenForDescriptor: screenForDescriptorSync } = await import(core('navigation.ts'));

/** An `AgentStatus`-shaped stub: this store reads only `restraint()`. */
function agentStatusWith(restraint = {}) {
  return { restraint: () => ({ ...UNRESTRAINED, ...restraint }) };
}

/** A `ScopeService`-shaped stub: this store reads only `namespace()`. */
function scopeAt(namespace = 'HSCUSTOM') {
  return { namespace: () => namespace };
}

/**
 * An `ApiService`-shaped stub over one scripted answer, recording every path and init it saw so a
 * test can assert the read was bounded and unscoped (AD-48).
 */
function apiAnswering(answer) {
  const calls = [];
  return {
    calls,
    requestJson: async (path, init) => {
      calls.push({ path, init });
      return typeof answer === 'function' ? answer(path) : answer;
    },
  };
}

const ok = (body) => ({ kind: 'ok', status: 200, body });
const errorAt = (status, code = null) => ({ kind: 'error', status, code, reason: null, detail: null });

function viewOver(options) {
  return new SuggestedView({
    api: options.api,
    agentStatus: options.agentStatus ?? agentStatusWith(),
    scope: options.scope ?? scopeAt(),
    connectivity: options.connectivity,
  });
}

/**
 * A `ConnectivityService`-shaped stub recording every parked re-read, key **and** callback -- the
 * shape `agent-status.test.mjs` and `agent-context.test.mjs` use, so a test can run the parked
 * re-read rather than only assert that something was parked under the right key.
 */
function parkRecorder() {
  const parked = [];
  return { parked, retryWhenReachable: (key, run) => parked.push({ key, run }) };
}

test('before a read the block is not answered, which is the gate the panel renders on', () => {
  const view = viewOver({ api: apiAnswering(ok({ rows: [] })) });
  assert.equal(view.answered(), false, 'a source with its own read has not answered');
  assert.equal(view.showPrompts(), false, 'and never the prompts, which would flash before the read');
  // A projected source is always answered -- it reads a store rather than the instance -- so it
  // is present in `lines()`. `answered()`, not `lines()`, is what withholds the block.
  assert.deepEqual(view.lines().map((line) => line.key), ['agent-status']);
});

test('both lines answer: the agent-status line then the application-errors line, in declared order', async () => {
  const api = apiAnswering(ok({ rows: [{ date: '2026-09-17', count: 3 }, { date: '2026-09-16', count: 1 }] }));
  const view = viewOver({ api });
  await view.load();

  assert.equal(view.answered(), true);
  assert.deepEqual(
    view.lines().map((line) => [line.key, line.counted, line.count, line.descriptor]),
    [
      ['agent-status', false, 0, SWITCHES_DESCRIPTOR],
      ['application-errors', true, 3, ERROR_LOG_DESCRIPTOR],
    ]
  );
  const [status, errors] = view.lines();
  assert.equal(status.text, STRINGS.statusReadOnlyOff, 'the footer line the verdict named');
  assert.equal(
    errors.text,
    formatApplicationErrors(STRINGS.homeSuggestedApplicationErrors, 'HSCUSTOM', 3, '2026-09-17'),
    'the newest date the instance named, in the current namespace scope'
  );
  assert.equal(errors.label + String(errors.count) + errors.tail, errors.text, 'label + count + tail IS the sentence');
  assert.equal(view.showPrompts(), false, 'a non-zero count is not the fallback');

  // Bounded: one call, unscoped, with the namespace on this endpoint's own parameter (AD-48).
  assert.equal(api.calls.length, 1);
  assert.equal(api.calls[0].path, `${ERROR_LOG_DATES_PATH}?namespace=HSCUSTOM`);
  assert.equal(api.calls[0].init.scope, null);
});

test('the kill switch chooses the agent-status line, which is the sentence the banner renders', async () => {
  const view = viewOver({
    api: apiAnswering(ok({ rows: [] })),
    agentStatus: agentStatusWith({
      killSwitch: true,
      killSwitchAudience: 'everyone',
      killSwitchReason: 'Paused during the change freeze',
    }),
  });
  await view.load();
  assert.equal(
    view.lines()[0].text,
    'The agent is switched off for everyone: Paused during the change freeze.'
  );
});

test('the agent-status line is projected live, so it cannot contradict a verdict that answered later', async () => {
  // Mutation (Rule 19): give the agent-status source a `read` that remembers `agentStatusLine()`
  // at `load()` time instead of a `project` resolved on every read -> this goes red.
  //
  // This is the shape the browser suite caught: the panel builds the block and loads it while
  // `AgentStatus` is still in flight, so a remembered projection renders the pre-answer verdict
  // for the life of the visit while the footer two rows below renders the real one.
  let restraint = { ...UNRESTRAINED };
  const view = viewOver({
    api: apiAnswering(ok({ rows: [] })),
    agentStatus: { restraint: () => restraint },
  });
  await view.load();
  assert.equal(view.lines()[0].text, STRINGS.statusReadOnlyOff);

  restraint = { ...UNRESTRAINED, footerKey: 'statusReadOnlyByDefinition' };
  assert.equal(view.lines()[0].text, STRINGS.statusReadOnlyByDefinition, 'the line follows the verdict');
});

/** The application-errors line a refused or faulted read answers (DW-1147). */
function assertUnreadLine(view, namespace, message) {
  const line = view.lines().find((row) => row.key === 'application-errors');
  assert.ok(line, `${message}: the line renders`);
  assert.equal(line.unread, true, `${message}: marked unread`);
  assert.equal(line.counted, true, `${message}: still a counted line`);
  assert.equal(line.count, 0, `${message}: carries no count`);
  assert.equal(line.tail, '', `${message}: and no tail`);
  const sentence = STRINGS.homeSuggestedApplicationErrorsUnread.replace('<NAMESPACE>', namespace);
  assert.equal(line.label, sentence, `${message}: the label is the whole sentence`);
  assert.equal(line.text, sentence, `${message}: and so is the text`);
  assert.equal(view.showPrompts(), false, `${message}: an unread line holds the prompts back`);
}

test('a refused application-errors read renders the unread line, and is never retried (AD-8, DW-1147)', async () => {
  // Mutation (Rule 19): make the non-ok branch answer `null` -> the unread-line assertions go red.
  const connectivity = parkRecorder();
  const view = viewOver({ api: apiAnswering(errorAt(403, 'AUTH.FORBIDDEN')), connectivity });
  await view.load();

  assert.equal(view.answered(), true, 'a refusal settles the source rather than leaving it pending');
  assert.deepEqual(view.lines().map((line) => line.key), ['agent-status', 'application-errors'], 'no zero, no skeleton row');
  assertUnreadLine(view, 'HSCUSTOM', '403');
  assert.deepEqual(connectivity.parked, [], 'a 403 is reported and never retried');
});

test('a faulted or unreachable read renders the unread line and parks exactly one re-read, keyed by the path', async () => {
  // Mutation (Rule 19): make the non-ok branch answer `null` -> the unread-line assertions go red.
  for (const result of [errorAt(500), errorAt(0), { kind: 'installing', status: 503, code: 'INSTALL.RUNNING' }]) {
    const connectivity = parkRecorder();
    const view = viewOver({ api: apiAnswering(result), connectivity });
    await view.load();
    assertUnreadLine(view, 'HSCUSTOM', JSON.stringify(result));
    assert.deepEqual(
      connectivity.parked.map((park) => park.key),
      [`${ERROR_LOG_DATES_PATH}?namespace=HSCUSTOM`]
    );
  }
});

test('the parked re-read is what brings the line back once the instance answers again', async () => {
  // Mutation (Rule 19): replace `() => void this.load()` in `readApplicationErrors` with a
  // callback that reads nothing -> this goes red. The key alone is not the behaviour: Home carries
  // no timer (AD-43) and this store schedules nothing of its own, so the parked re-read is the
  // only path back from a fault for the length of a Home visit.
  const connectivity = parkRecorder();
  const api = { calls: [], requestJson: async (path) => {
    api.calls.push(path);
    return api.calls.length === 1 ? errorAt(0) : ok({ rows: [{ date: '2026-09-17', count: 5 }] });
  } };
  const view = viewOver({ api, connectivity });
  await view.load();
  assertUnreadLine(view, 'HSCUSTOM', 'the faulted read');
  assert.equal(connectivity.parked.length, 1);

  // The store's own notification is the settle point: `run` is `void`-ed, so awaiting it would
  // await `undefined` and assert against the pre-read state. The timer is what makes the mutation
  // above a failure rather than a hang -- a callback that reads nothing notifies nothing, and a
  // bare wait on that notification would never return.
  const settled = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('the parked re-read settled nothing')), 2000);
    const stop = view.subscribe(() => {
      clearTimeout(timer);
      stop();
      resolve();
    });
  });
  connectivity.parked[0].run();
  await settled;

  assert.deepEqual(view.lines().map((line) => line.key), ['agent-status', 'application-errors']);
  assert.equal(view.lines()[1].count, 5, 'the count the recovered read answered');
  assert.equal(view.lines()[1].unread, false, 'which replaces the unread line');
  assert.equal(api.calls.length, 2, 'one re-read, not a loop');
});

test('zero rows is a count of zero, which lets Home\'s prompts stand in', async () => {
  // Mutation (Rule 19): include the agent-status line in the zero test -> the "agent-status stays"
  // assertion goes red.
  const view = viewOver({ api: apiAnswering(ok({ rows: [] })) });
  await view.load();

  assert.equal(view.showPrompts(), true);
  assert.equal(view.lines().find((line) => line.key === 'application-errors').unread, false, 'a real zero is read');
  assert.deepEqual(
    view.lines().map((line) => line.key),
    ['agent-status', 'application-errors'],
    'the uncounted agent-status line stays present under the fallback'
  );
  assert.equal(view.lines().find((line) => line.key === 'agent-status').counted, false);
});

test('a source that settles to no line leaves the zero test to the lines that render', async () => {
  // A source answering `null` renders nothing, so it neither holds the prompts back nor counts.
  const absent = { key: 'absent', read: (_view, state) => { state.answer = null; return Promise.resolve(); } };
  SOURCES.push(absent);
  try {
    const view = viewOver({ api: apiAnswering(ok({ rows: [] })) });
    await view.load();
    assert.equal(view.showPrompts(), true);
  } finally {
    SOURCES.pop();
  }
});

test('DW-1147: a refused, faulted or unreachable counted read never falls through to the prompts', async () => {
  // Mutation (Rule 19): make `showPrompts()` ignore `unread` -> every case here goes red.
  for (const result of [errorAt(403), errorAt(500), errorAt(0), { kind: 'installing', status: 503, code: 'INSTALL.RUNNING' }]) {
    const view = viewOver({ api: apiAnswering(result) });
    await view.load();
    assert.equal(view.showPrompts(), false, JSON.stringify(result));
  }
});

test('AC5: a fourth source appended to the declared array appends a fourth line, in declared order', async () => {
  // Mutation (Rule 19): hard-code the two line keys in the render path (here, `lines()`) instead of
  // iterating the source array -> this goes red.
  //
  // Story 6.13's alerts.log line is exactly this shape: one appended source and one string key.
  const appended = {
    key: 'alerts-log',
    read: (_view, state) => {
      state.answer = {
        key: 'alerts-log',
        counted: true,
        unread: false,
        text: 'appended',
        count: 2,
        label: 'appended ',
        tail: '',
        descriptor: 'OcuPilot.Screen.Descriptor.LogErrorList',
      };
      return Promise.resolve();
    },
  };
  SOURCES.push(appended);
  try {
    const view = viewOver({ api: apiAnswering(ok({ rows: [{ date: '2026-09-17', count: 1 }] })) });
    await view.load();
    assert.deepEqual(view.lines().map((line) => line.key), [
      'agent-status',
      'application-errors',
      'alerts-log',
    ]);
    assert.equal(view.answered(), true);
  } finally {
    SOURCES.pop();
  }
});

test('a namespace switch re-reads for the new namespace, and the line re-resolves', async () => {
  let namespace = 'HSCUSTOM';
  const api = apiAnswering(ok({ rows: [{ date: '2026-09-17', count: 4 }] }));
  const view = viewOver({ api, scope: { namespace: () => namespace } });
  await view.load();
  assert.match(view.lines()[1].text, /HSCUSTOM/);

  namespace = 'USER';
  await view.load();
  assert.equal(api.calls.length, 2, 'one call per line per entry');
  assert.equal(api.calls[1].path, `${ERROR_LOG_DATES_PATH}?namespace=USER`);
  assert.match(view.lines()[1].text, /USER/);
});

test('an unresolved namespace withholds the read rather than issuing it unscoped', async () => {
  // Mutation (Rule 19): drop the `namespace === ''` guard from `readApplicationErrors` -> the
  // "no call" assertion goes red.
  //
  // The shape the browser suite caught: `ScopeService` answers `''` until its list arrives, and
  // `GET /logs/errors/dates?namespace=` is a 404 -- a console error on every Home load.
  let namespace = '';
  const api = apiAnswering(ok({ rows: [{ date: '2026-09-17', count: 2 }] }));
  const view = viewOver({ api, scope: { namespace: () => namespace } });
  await view.load();
  assert.deepEqual(api.calls, [], 'no request at all');
  assert.equal(view.answered(), false, 'and the block renders nothing rather than a partial block');

  namespace = 'HSCUSTOM';
  await view.load();
  assert.equal(api.calls.length, 1);
  assert.equal(view.answered(), true);
});

test('a namespace needing escaping travels encoded', async () => {
  const api = apiAnswering(ok({ rows: [] }));
  const view = viewOver({ api, scope: scopeAt('MY NS/1') });
  await view.load();
  assert.equal(api.calls[0].path, `${ERROR_LOG_DATES_PATH}?namespace=MY%20NS%2F1`);
});

test('reset forgets every answer, so the next visit to Home reads again', async () => {
  const view = viewOver({ api: apiAnswering(ok({ rows: [{ date: '2026-09-17', count: 2 }] })) });
  await view.load();
  assert.equal(view.answered(), true);
  view.reset();
  assert.equal(view.answered(), false);
  assert.deepEqual(view.lines().map((line) => line.key), ['agent-status'], 'the read source is forgotten');
});

test('an answer to a read the tab has left never settles', async () => {
  let release = () => {};
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const api = {
    calls: [],
    requestJson: async (path) => {
      api.calls.push(path);
      await gate;
      return ok({ rows: [{ date: '2026-09-17', count: 9 }] });
    },
  };
  const view = viewOver({ api });
  const running = view.load();
  view.reset();
  release();
  await running;
  assert.equal(view.answered(), false, 'the superseded read settled nothing');
});

test('subscribers are notified once a load has settled, and the listener can be released', async () => {
  const view = viewOver({ api: apiAnswering(ok({ rows: [] })) });
  let notified = 0;
  const stop = view.subscribe(() => {
    notified += 1;
  });
  await view.load();
  assert.equal(notified, 1);
  stop();
  await view.load();
  assert.equal(notified, 1, 'a released listener hears nothing');
});

test('a malformed body is read as no rows rather than as a line about nothing', async () => {
  for (const body of [null, {}, { rows: 'no' }, { rows: [null] }, { rows: [{ date: 7, count: 'many' }] }]) {
    const view = viewOver({ api: apiAnswering(ok(body)) });
    await view.load();
    const line = view.lines().find((row) => row.key === 'application-errors');
    assert.equal(line.count, 0, JSON.stringify(body));
    assert.equal(view.showPrompts(), true);
  }
});

test('the declared sources are the two this story ships, in render order', () => {
  assert.deepEqual(SOURCES.map((source) => source.key), ['agent-status', 'application-errors']);
});

test('every declared line names a descriptor the generated mirror actually carries', () => {
  // Mutation (Rule 19): respell either constant -> this goes red. A line whose descriptor does not
  // resolve renders an Open control with an empty href, which no other assertion observes: every
  // href case in this tree reads the application-errors row.
  for (const descriptor of [SWITCHES_DESCRIPTOR, ERROR_LOG_DESCRIPTOR]) {
    const screen = screenForDescriptorSync(descriptor);
    assert.ok(screen, `${descriptor} resolves in screens.generated.ts`);
    assert.ok(screen.route.length > 0, `${descriptor} declares a route to open`);
  }
});

test("HOME_AREA_KEY is the area the Home descriptor itself declares", () => {
  // Mutation (Rule 19): change `HOME_AREA_KEY` -> this goes red. It is the single switch for both
  // Home's wider panel and the whole block, and every other test supplies 'home' as a literal, so
  // a regenerated mirror with a different key would remove both features with the suite green.
  const home = screenForDescriptorSync('OcuPilot.Screen.Descriptor.Home');
  assert.ok(home, 'the Home descriptor is mirrored');
  assert.equal(home.area, HOME_AREA_KEY);
});
