import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { extractXData } from './screen-mirror.mjs';

// Pins the client half of the one declared read (AD-36): `applyView` over the corpus the server's
// `OcuPilot.Screen.Read.ApplyView` runs, and `createScreenRead` as the read the auto-refresh
// framework calls (AD-43), over the real `ApiService` with an injected `fetch`. No test waits on a
// clock: the tick is the arm handed to the refresh framework's `schedule` seam, fired by hand.
//
// Mutations (Rule 19):
// - lower-case with `toLowerCase()` instead of the ASCII-only replace in `applyView` -> the corpus
//   case "a non-ASCII capital is not lower-cased" goes red.
// - omit `maxRows` from the path in `createScreenRead` -> the tick test's request assertion goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = join(uiRoot, '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);
const { screenDeclaration } = await import(join(uiRoot, 'src', 'app', 'testing', 'screen-declaration.ts'));

const { applyView, createScreenRead, criteriaParams, screenReadPath, textOf, NO_READ_MESSAGE } = await import(corePath('screen-read.ts'));
const { RefreshService } = await import(corePath('refresh.ts'));
const { ChangeBus } = await import(corePath('change-bus.ts'));
const { ScreenStores } = await import(corePath('screen-store.ts'));
const { stubAccountPreferences, settledAccountPreferences, lastRemembered, SHELL_SIDE_BAR_OPEN, SHELL_PANEL_WIDTH } =
  await import(new URL('../src/app/testing/account-preferences.ts', import.meta.url).href);
const { ApiService } = await import(corePath('api.ts'));
const { Session } = await import(corePath('session.ts'));
const { TokenStore } = await import(corePath('token-store.ts'));

const CORPUS_SOURCE = join(repoRoot, 'src', 'OcuPilot', 'Test', 'ReadViewCorpus.cls');
const NOW_MS = 1_700_000_000_000;
const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.Probe';

const READ = {
  source: { port: 'admin', endpoint: 'WebApp.App', type: 'LIST' },
  fields: ['Name', 'NameSpace', 'Enabled'],
  filter: ['Name', 'NameSpace'],
  sort: { fields: ['Name', 'NameSpace'], default: 'Name', direction: 'asc' },
  paging: 'cap',
};

function memoryStorage() {
  const map = new Map();
  return {
    getItem: (key) => (map.has(key) ? map.get(key) : null),
    setItem: (key, value) => map.set(key, value),
    removeItem: (key) => map.delete(key),
  };
}

async function settle() {
  for (let i = 0; i < 8; i++) await new Promise((resolve) => setImmediate(resolve));
}

function screen(extra = {}) {
  return screenDeclaration({
    descriptor: DESCRIPTOR,
    route: 'web-applications/applications',
    area: 'web-applications',
    labelKey: 'navAreaWebApplications',
    // A tool identifier the read grammar admits, as JSON text: `screen-fixture.test.mjs` reads a
    // bare key of that name as a declaration built by hand.
    ...JSON.parse('{"toolIdentifier": "webapp.probe"}'),
    refreshes: true,
    refreshRates: [10],
    entityType: 'web-application',
    scope: 'namespace',
    read: READ,
    ...extra,
  });
}

/**
 * The framework bound to a real `ApiService` over an injected `fetch` that answers `respond(path)`,
 * scoped to `HSCUSTOM` by the service's own source.
 */
function wired(respond) {
  const calls = [];
  const scheduled = [];
  const parks = [];
  const fetchImpl = async (path) => {
    calls.push(path);
    const { status, body } = respond(path);
    return { status, text: async () => JSON.stringify(body) };
  };
  const tokens = new TokenStore({ storage: memoryStorage(), navigationType: () => 'navigate' });
  const session = new Session({ fetch: fetchImpl, tokens, now: () => NOW_MS, schedule: () => {} });
  const api = new ApiService({ fetch: fetchImpl, tokens, session, scope: () => 'HSCUSTOM' });
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const refresh = new RefreshService({
    stores,
    connectivity: {
      retryWhenReachable(key, run) {
        parks.push({ key, run });
      },
    },
    bus: new ChangeBus({ now: () => new Date(NOW_MS) }),
    namespace: () => 'HSCUSTOM',
    schedule: (run, delayMs) => scheduled.push({ run, delayMs }),
    now: () => new Date(NOW_MS),
  });
  return {
    api,
    calls,
    parks,
    refresh,
    store: () => stores.for(DESCRIPTOR, [10]),
    async fire() {
      scheduled[scheduled.length - 1].run();
      await settle();
    },
  };
}

// AC7, the client half: every corpus case, read off disk from the same XData block the server's
// suite reads through the class dictionary.
test('applyView produces every order OcuPilot.Test.ReadViewCorpus declares', () => {
  const body = extractXData(readFileSync(CORPUS_SOURCE, 'utf8'), 'Cases');
  assert.ok(body !== null, 'the corpus block is found');
  const corpus = JSON.parse(body);
  assert.ok(corpus.cases.length >= 10, `the corpus carries its cases (read ${corpus.cases.length})`);
  for (const testCase of corpus.cases) {
    const ids = applyView(testCase.rows ?? corpus.rows, corpus.read, {
      filter: testCase.filter,
      sort: testCase.sort,
      direction: testCase.direction,
    }).map((row) => row.Id);
    assert.deepEqual(ids, testCase.expected, testCase.name);
  }
});

test('textOf gives a number its JSON text, a boolean its word, an array its members joined, and null or an object nothing', () => {
  assert.equal(textOf(0.5), '0.5');
  assert.equal(textOf(-3), '-3');
  assert.equal(textOf(true), 'true');
  assert.equal(textOf(false), 'false');
  assert.equal(textOf(null), '');
  assert.equal(textOf({ a: 1 }), '');
  assert.equal(textOf(['a']), 'a');
  assert.equal(textOf(['%All', 'OcuPilotAdmin']), '%All, OcuPilotAdmin');
  assert.equal(textOf(['x', 1, true, null, { a: 1 }, ['y', 'z']]), 'x, 1, true, , , y, z');
  assert.equal(textOf([]), '');
  assert.equal(textOf('As Is'), 'As Is');
});

test('applyView returns a new array and leaves the rows it was given in their order', () => {
  const rows = [{ Name: 'b' }, { Name: 'a' }];
  const view = applyView(rows, READ);
  assert.deepEqual(view.map((row) => row.Name), ['a', 'b']);
  assert.deepEqual(rows.map((row) => row.Name), ['b', 'a'], 'the input is not reordered');
  assert.equal(view[0], rows[1], 'and the rows are the same objects');
});

// AC2: the auto-refresh framework consumes the screen read. One tick issues exactly one request,
// absolute, carrying the store's own cap and the service's scope, and the store holds its rows and
// its truncation.
test('a tick issues exactly one screen read carrying the store cap and the scope, and the store holds its answer', async () => {
  const rows = [{ Name: '/csp/a', NameSpace: 'USER', Enabled: true }];
  const harness = wired(() => ({ status: 200, body: { fields: READ.fields, rows, truncated: true } }));
  const declaration = screen();
  harness.refresh.bind(declaration, createScreenRead(harness.api, declaration));
  harness.store().setMaxRows(250);
  harness.refresh.setRate(10);

  await harness.fire();

  assert.deepEqual(harness.calls, ['/api/ocupilot/screens/webapp.probe/read?maxRows=250&ns=HSCUSTOM']);
  assert.deepEqual(harness.store().data(), rows, 'the store holds the rows');
  assert.equal(harness.store().truncated(), true, 'and the truncation');
  assert.equal(harness.refresh.armedFor(), 'tick', 'and the cadence continues');
});

test('a tick answering truncated false leaves the store reading false', async () => {
  const answers = [true, false];
  const harness = wired(() => ({ status: 200, body: { fields: READ.fields, rows: [], truncated: answers.shift() } }));
  const declaration = screen();
  harness.refresh.bind(declaration, createScreenRead(harness.api, declaration));
  harness.refresh.setRate(10);

  await harness.fire();
  assert.equal(harness.store().truncated(), true, 'the first tick answered truncated');
  await harness.fire();
  assert.equal(harness.store().truncated(), false, 'and the next, answering false, clears it');
});

// Story 2.8: the screen's own read is where the strip's key arrives. It is additive, so a body
// with no `banner` key -- every screen that declares none -- reads as no strip, and so does one
// whose `banner` is not a string.
//
// Mutation (Rule 19): drop the `banner` key from `createScreenRead`'s ok result -> the first
// assertion goes red and the strip could never reach the store.
test('the screen read carries the banner key the instance answered, and anything but a string reads as none', async () => {
  const bodies = [
    { fields: READ.fields, rows: [], truncated: false, banner: 'taskManagerSuspendedBanner' },
    { fields: READ.fields, rows: [], truncated: false, banner: '' },
    { fields: READ.fields, rows: [], truncated: false },
    { fields: READ.fields, rows: [], truncated: false, banner: 7 },
  ];
  const harness = wired(() => ({ status: 200, body: bodies.shift() }));
  const declaration = screen();
  const read = createScreenRead(harness.api, declaration);

  assert.equal((await read({ maxRows: 5 })).banner, 'taskManagerSuspendedBanner');
  assert.equal((await read({ maxRows: 5 })).banner, '', 'an empty key is no strip');
  assert.equal((await read({ maxRows: 5 })).banner, '', 'and so is an absent one');
  assert.equal((await read({ maxRows: 5 })).banner, '', 'and so is one that is not a string');
});

test('a refused read is a classified fault: the store keeps its rows and the timer parks', async () => {
  const refused = {
    status: 403,
    body: { error: 'forbidden', reason: 'no', code: 'AUTH.NOPRIVILEGE', detail: { failedPair: '%Admin_Secure:USE' } },
  };
  const rows = [{ Name: '/csp/a', NameSpace: 'USER', Enabled: true }];
  let answer = refused;
  const harness = wired(() => answer);
  const declaration = screen();
  const read = createScreenRead(harness.api, declaration);

  const result = await read({ maxRows: 5 });
  assert.equal(result.kind, 'fault');
  assert.equal(result.fault.kind, 'refused');
  assert.equal(result.fault.code, 'AUTH.NOPRIVILEGE');
  assert.equal(result.fault.path, '/api/ocupilot/screens/webapp.probe/read?maxRows=5');

  harness.refresh.bind(declaration, read);
  harness.refresh.setRate(10);
  answer = { status: 200, body: { fields: READ.fields, rows, truncated: false } };
  await harness.fire();
  assert.deepEqual(harness.store().data(), rows, 'a successful tick fills the store');
  answer = refused;
  await harness.fire();
  assert.deepEqual(harness.store().data(), rows, 'and the refused tick leaves those rows in place');
  assert.equal(harness.refresh.armedFor(), 'none', 'the timer is suspended');
  assert.equal(harness.parks.length, 1, 'and one re-arm is parked');
});

test('an answer that is not the read shape is a server fault, never an empty success', async () => {
  const harness = wired(() => ({ status: 200, body: { rows: 'not a list' } }));
  const result = await createScreenRead(harness.api, screen())({ maxRows: 5 });
  assert.equal(result.kind, 'fault');
  assert.equal(result.fault.kind, 'server-fault');
});

test('a screen that declares no read has no screen read', () => {
  const harness = wired(() => ({ status: 200, body: {} }));
  assert.throws(() => createScreenRead(harness.api, screen({ read: null })), (error) => {
    assert.ok(error.message.startsWith(NO_READ_MESSAGE));
    assert.ok(error.message.includes(DESCRIPTOR));
    return true;
  });
});

// --- Story 2.10: the declared server-search criteria (AD-21) -------------------------------------
//
// The client's half of the allow-list `OcuPilot.Screen.Read.CriteriaParams` is on the instance: a
// value travels only where the descriptor names it. An absent criterion is not sent, so the instance
// applies its declared default; an explicit empty one is sent as `p=`, an unset bound (AD-36).
//
// Mutations (Rule 19): drop the `.filter(...)` from `screenReadPath` -> "an absent criterion is not
// sent" goes red; make it filter out `''` as well -> "an explicit empty one is sent" goes red; drop
// the `encodeURIComponent` around the value -> the encoding assertion goes red; return `[]` from
// `criteriaParams` -> every assertion below goes red at once.

/** The criteria block the audit database viewer declares, narrowed to what these tests need. */
const CRITERIA = {
  fields: [
    { param: 'beginDateTime', labelKey: 'auditCriteriaBegin', kind: 'datetime' },
    { param: 'eventSources', labelKey: 'auditColumnEventSource', kind: 'text' },
    { param: 'authentication', labelKey: 'auditCriteriaAuthentication', kind: 'choice', options: ['Password'] },
  ],
  marker: { param: 'eventSources', value: 'OcuPilot', labelKey: 'auditMarkerFilterLabel' },
};

const withCriteria = () => screen({ read: { ...READ, criteria: CRITERIA } });

test('criteriaParams names the declared parameters in declaration order, and nothing for a read with none', () => {
  assert.deepEqual(criteriaParams(withCriteria()), ['beginDateTime', 'eventSources', 'authentication']);
  assert.deepEqual(criteriaParams(screen()), [], 'a read bounded by the cap alone declares none');
  assert.deepEqual(criteriaParams(screen({ read: null })), [], 'and so does a screen with no read');
});

test('screenReadPath appends every non-empty declared criterion, URL-encoded, in declaration order', () => {
  const path = screenReadPath(withCriteria(), 1000, {
    beginDateTime: '2026-09-14 00:00:00',
    eventSources: '%System,OcuPilot',
    authentication: 'Password',
  });
  assert.equal(
    path,
    '/api/ocupilot/screens/webapp.probe/read?maxRows=1000' +
      '&beginDateTime=2026-09-14%2000%3A00%3A00' +
      '&eventSources=%25System%2COcuPilot' +
      '&authentication=Password'
  );
});

test('an absent criterion is not sent, an explicit empty one is, and an undeclared one never travels', () => {
  const path = screenReadPath(withCriteria(), 25, {
    beginDateTime: '',
    eventSources: 'OcuPilot',
    authentication: undefined,
    jsonSearch: 'anything',
  });
  assert.equal(path, '/api/ocupilot/screens/webapp.probe/read?maxRows=25&beginDateTime=&eventSources=OcuPilot');
  assert.equal(
    screenReadPath(withCriteria(), 25, {}),
    '/api/ocupilot/screens/webapp.probe/read?maxRows=25',
    'and a read that names no criterion sends the cap alone, so every default applies'
  );
});

test('createScreenRead hands the answer\'s applied criteria, string members only, to its echo with the request sent', async () => {
  const harness = wired(() => ({
    status: 200,
    body: { fields: READ.fields, rows: [], truncated: false, criteria: { beginDateTime: '2026-09-25 10:00:00', eventSources: '', pids: 5 } },
  }));
  const echoes = [];
  const read = createScreenRead(harness.api, withCriteria(), () => ({ eventSources: '' }), (applied, sent) =>
    echoes.push({ applied, sent })
  );
  await read({ maxRows: 5 });
  assert.deepEqual(echoes, [
    { applied: { beginDateTime: '2026-09-25 10:00:00', eventSources: '' }, sent: { eventSources: '' } },
  ]);
  // An answer with no `criteria` echoes an empty object rather than nothing, so a form still fills
  // the fields its request left absent.
  const bare = wired(() => ({ status: 200, body: { fields: READ.fields, rows: [], truncated: false } }));
  const bareEchoes = [];
  await createScreenRead(bare.api, withCriteria(), () => ({}), (applied) => bareEchoes.push(applied))({ maxRows: 5 });
  assert.deepEqual(bareEchoes, [{}]);
});

test('createScreenRead reads its criteria at call time, not at bind time', async () => {
  const paths = [];
  const harness = wired((path) => {
    paths.push(path);
    return { status: 200, body: { fields: READ.fields, rows: [], truncated: false } };
  });
  let sent = {};
  const read = createScreenRead(harness.api, withCriteria(), () => sent);
  await read({ maxRows: 5 });
  sent = { eventSources: 'OcuPilot' };
  await read({ maxRows: 5 });
  // The `ns` the API service appends (AD-44) rides after the criteria, so the two mechanisms
  // compose rather than one overwriting the other's query string.
  assert.deepEqual(paths, [
    '/api/ocupilot/screens/webapp.probe/read?maxRows=5&ns=HSCUSTOM',
    '/api/ocupilot/screens/webapp.probe/read?maxRows=5&eventSources=OcuPilot&ns=HSCUSTOM',
  ]);
});
