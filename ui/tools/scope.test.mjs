import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the client half of AD-44: which namespace every call is scoped to, which ones the switch
// may offer, what happens to a route namespace the instance refuses, and the channel a scope
// change publishes on.
//
// Mutations (Rule 19):
// - make `namespace()` return the requested value before the list has loaded -> the "nothing is
//   scoped until the list arrives" test goes red, and the shell would spend its first requests
//   on a namespace it has not been told it may enter.
// - drop the `writable` filter from `writableNamespaces` -> the DW-7 filter test goes red, and
//   the switch would offer a namespace the user cannot write in.
// - send the namespaces read with the service's own scope instead of `scope: null` -> the
//   recovery-channel test goes red, and a bad `ns` would close the list that fixes it.
// - notify `onScopeChange` on every notification rather than on a changed resolution -> the
//   "a route event that changes nothing costs no request" test goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { ScopeService, NAMESPACES_PATH, withNamespace, writableNamespaces, onScopeChange } =
  await import(corePath('scope.ts'));

function ok(body) {
  return { kind: 'ok', status: 200, body };
}

function denied(failedPair) {
  return {
    kind: 'error',
    status: 403,
    code: 'NS.DENIED',
    reason: 'This account may not enter that namespace',
    detail: failedPair === null ? null : { failedPair },
  };
}

/** The smallest thing `ScopeService` needs: something that answers `requestJson`. */
function stubApi(answers) {
  const calls = [];
  return {
    calls,
    requestJson: async (path, init = {}) => {
      calls.push({ path, scope: init.scope });
      return answers[Math.min(calls.length - 1, answers.length - 1)];
    },
  };
}

/** A body shaped the way `GET /api/ocupilot/namespaces` shapes one. */
function listBody(scope, namespaces) {
  return { scope, namespaces };
}

const SETTLE = () => new Promise((resolve) => setImmediate(resolve));

// --- withNamespace ------------------------------------------------------------------------

test('withNamespace replaces ns and leaves the path, the fragment and every other parameter', () => {
  assert.equal(withNamespace('/logs?ns=HSCUSTOM', 'USER'), '/logs?ns=USER');
  assert.equal(withNamespace('/logs', 'USER'), '/logs?ns=USER');
  assert.equal(withNamespace('/', 'USER'), '/?ns=USER');
  assert.equal(
    withNamespace('/logs?page=3&ns=HSCUSTOM&sort=time#row-7', 'USER'),
    '/logs?page=3&ns=USER&sort=time#row-7',
    'ns keeps its position and nothing else is touched'
  );
  assert.equal(
    withNamespace('/logs?filter=a%20b', 'USER'),
    '/logs?filter=a%20b&ns=USER',
    "another parameter keeps its own spelling -- nothing is re-encoded on the way through"
  );
  assert.equal(withNamespace('/logs?ns=USER', ''), '/logs', 'an empty namespace drops the parameter');
  assert.equal(
    withNamespace('/logs?ns=%25SYS', '%SYS'),
    '/logs?ns=%25SYS',
    'a namespace whose name carries a percent sign is encoded once'
  );
  assert.equal(withNamespace('/logs#top', 'USER'), '/logs?ns=USER#top');
});

// --- the offered set ------------------------------------------------------------------------

test('DW-7: the switch offers writable namespaces, and the endpoint still reports the others', () => {
  const entries = [
    { name: 'HSCUSTOM', writable: true, failedPair: '' },
    { name: 'USER', writable: false, failedPair: '%DB_USER:WRITE' },
    { name: 'HSLIB', writable: false, failedPair: '' },
  ];
  assert.deepEqual(
    writableNamespaces(entries).map((entry) => entry.name),
    ['HSCUSTOM'],
    'only the writable one is somewhere the switch sends anyone'
  );
  // The other two are still in the list the service holds -- a route already scoped to one of
  // them is honoured, and its verdict is what the reversal in the Design Notes would key off.
  // That is asserted against a real service below ("the requested namespace wins when the list
  // allows it"), not here: an assertion over this literal could not fail.
});

// --- the resolved scope ---------------------------------------------------------------------

test('nothing is scoped until the list arrives', async () => {
  const api = stubApi([ok(listBody('HSCUSTOM', [{ name: 'HSCUSTOM', writable: true }]))]);
  const scope = new ScopeService({ api });
  scope.setRequested('USER');

  assert.equal(scope.loaded(), false);
  assert.equal(scope.namespace(), '', 'no ns is attached to anything before the list has answered');
  assert.equal(scope.requested(), 'USER', 'while the route is still reported verbatim');
  assert.equal(scope.unresolved(), null, 'and nothing is rejected yet');
});

test('the requested namespace wins when the list allows it, and the echo wins when it does not', async () => {
  const api = stubApi([
    ok(
      listBody('HSCUSTOM', [
        { name: 'HSCUSTOM', writable: true },
        { name: 'USER', writable: false, failedPair: '%DB_USER:WRITE' },
      ])
    ),
    denied('%DB_NOPE:READ'),
  ]);
  const scope = new ScopeService({ api });
  scope.setRequested('USER');
  await scope.load();

  // DW-7: readable and not writable, so the switch will not offer it -- and a route already
  // scoped there is honoured all the same.
  assert.equal(scope.namespace(), 'USER');
  assert.equal(scope.unresolved(), null);

  scope.setRequested('NOPE');
  assert.equal(scope.namespace(), 'HSCUSTOM', "a namespace the list does not carry falls back to the instance's own");
  assert.deepEqual(scope.unresolved(), { name: 'NOPE', failedPair: '' }, 'named, with no reason yet');
});

test('the namespaces read is the one call that never carries ns', async () => {
  const api = stubApi([ok(listBody('HSCUSTOM', [{ name: 'HSCUSTOM', writable: true }]))]);
  const scope = new ScopeService({ api });
  scope.setRequested('NOPE');
  await scope.load();
  await scope.load();

  assert.equal(api.calls[0].path, NAMESPACES_PATH, 'through the one absolute API path');
  assert.equal(api.calls[0].scope, null, 'and explicitly unscoped, not merely unscoped by accident');
});

test('DW-8: a requested namespace the list rejects is verified once, and the pair is what it names', async () => {
  const api = stubApi([
    ok(listBody('HSCUSTOM', [{ name: 'HSCUSTOM', writable: true }])),
    denied('%DB_USER:READ'),
  ]);
  const scope = new ScopeService({ api });
  scope.setRequested('USER');
  await scope.load();
  await SETTLE();

  assert.equal(api.calls.length, 2, 'one unscoped read, then one scoped at the namespace in question');
  assert.equal(api.calls[1].scope, 'USER', 'the verification carries the namespace the route asked for');
  assert.deepEqual(scope.unresolved(), { name: 'USER', failedPair: '%DB_USER:READ' });
  assert.equal(scope.namespace(), 'HSCUSTOM', 'while the scope in force is the one the instance resolved');

  // Asked once per name, however many router events repeat it.
  scope.setRequested('HSCUSTOM');
  scope.setRequested('USER');
  await SETTLE();
  assert.equal(api.calls.length, 2, 'and never asked again for the same namespace');
});

test('DW-8: the refusal survives the correction it explains, and a selection answers it', async () => {
  const api = stubApi([
    ok(listBody('HSCUSTOM', [{ name: 'HSCUSTOM', writable: true }])),
    denied('%DB_USER:READ'),
  ]);
  const scope = new ScopeService({ api });
  scope.setRequested('USER');
  await scope.load();

  // What the switch does the moment the list rejects the route's namespace: put the resolved
  // scope in the URL. The refusal has not even arrived yet.
  scope.setRequested('HSCUSTOM');
  assert.equal(scope.unresolved(), null, 'nothing is unresolved once the URL has been corrected');
  await SETTLE();

  assert.deepEqual(
    scope.refusal(),
    { name: 'USER', failedPair: '%DB_USER:READ' },
    'and the reason the scope changed under the user is still there to be said'
  );

  assert.equal(scope.select('HSCUSTOM'), true);
  assert.equal(scope.refusal(), null, 'a namespace the user chose themselves answers it');
});

test('DW-8: a refusal with no pair is recorded as nothing at all', async () => {
  const api = stubApi([
    ok(listBody('HSCUSTOM', [{ name: 'HSCUSTOM', writable: true }])),
    denied(null),
  ]);
  const scope = new ScopeService({ api });
  scope.setRequested('NOPE');
  await scope.load();
  await SETTLE();

  assert.equal(scope.refusal(), null, 'no privilege would have helped, and no sentence is published for it');
});

test("DW-8: a namespace that does not exist is refused with no pair, and the shell says nothing", async () => {
  const api = stubApi([
    ok(listBody('HSCUSTOM', [{ name: 'HSCUSTOM', writable: true }])),
    { kind: 'error', status: 400, code: 'NS.UNKNOWN', reason: 'Unknown namespace', detail: null },
  ]);
  const scope = new ScopeService({ api });
  scope.setRequested('NOPE');
  await scope.load();
  await SETTLE();

  assert.deepEqual(scope.unresolved(), { name: 'NOPE', failedPair: '' });
  assert.equal(scope.namespace(), 'HSCUSTOM');
});

// --- canonicalisation -----------------------------------------------------------------------

test('a route namespace the instance accepts in another case resolves, and costs no request', async () => {
  // `OcuPilot.Api.Router.CanonicalNamespace` uppercases `?ns=user` and answers for `USER`, so a
  // client that compared byte-for-byte against the roster would read a namespace the instance had
  // just accepted as unresolvable and silently replace it. Both sides canonicalise the same way.
  const api = stubApi([
    ok(
      listBody('HSCUSTOM', [
        { name: 'HSCUSTOM', writable: true },
        { name: 'USER', writable: true },
      ])
    ),
  ]);
  const scope = new ScopeService({ api });
  scope.setRequested('user');
  await scope.load();
  await SETTLE();

  assert.equal(scope.requested(), 'USER', 'held in the spelling the instance itself uses');
  assert.equal(scope.namespace(), 'USER', 'so the route is honoured rather than replaced');
  assert.equal(scope.unresolved(), null, 'and nothing is corrected out from under the user');
  assert.equal(api.calls.length, 1, 'the list read alone -- no namespace needed verifying');
});

test('canonicalisation reaches select and leaves an implicit namespace alone', async () => {
  const api = stubApi([
    ok(listBody('HSCUSTOM', [{ name: 'ABC-TEST', writable: true }])),
  ]);
  const scope = new ScopeService({ api });
  await scope.load();

  // A dash and an underscore are as legal in a namespace name as a letter, so the pattern that
  // decides what gets uppercased must admit them on both sides of the wire.
  assert.equal(scope.select('abc-test'), true, 'a legal name spelled in another case is still offered');
  assert.equal(scope.namespace(), 'ABC-TEST');

  scope.setRequested('^^c:\\dir\\');
  assert.equal(
    scope.requested(),
    '^^c:\\dir\\',
    'an implicit namespace is a file-system path: no route is scoped to one and its case is not ours to change'
  );
});

// --- selection ------------------------------------------------------------------------------

test('select takes only a namespace the instance offered for writing', async () => {
  const api = stubApi([
    ok(
      listBody('HSCUSTOM', [
        { name: 'HSCUSTOM', writable: true },
        { name: 'USER', writable: false, failedPair: '%DB_USER:WRITE' },
      ])
    ),
  ]);
  const scope = new ScopeService({ api });
  await scope.load();

  assert.equal(scope.select('NOPE'), false, 'a value the client invented is refused');
  assert.equal(scope.select('USER'), false, 'and so is one the instance reported as read-only');
  assert.equal(scope.namespace(), 'HSCUSTOM', 'neither moved the scope');

  assert.equal(scope.select('HSCUSTOM'), true);
});

// --- the change channel ---------------------------------------------------------------------

test('Integration (Rule 1): the scope change publishes, and its consumer re-reads once per move', async () => {
  const api = stubApi([
    ok(
      listBody('HSCUSTOM', [
        { name: 'HSCUSTOM', writable: true },
        { name: 'USER', writable: true },
      ])
    ),
  ]);
  const scope = new ScopeService({ api });
  const moves = [];
  const stop = onScopeChange(scope, () => moves.push(scope.namespace()));

  await scope.load();
  assert.deepEqual(moves, ['HSCUSTOM'], 'the list arriving is itself the first resolution');

  scope.select('USER');
  assert.deepEqual(moves, ['HSCUSTOM', 'USER'], 'a selection publishes the namespace its consumer must re-read with');

  // A router event repeating the namespace already in force resolves to the same scope, so
  // nothing is published and no consumer re-reads.
  scope.setRequested('USER');
  assert.deepEqual(moves, ['HSCUSTOM', 'USER']);

  stop();
  scope.select('HSCUSTOM');
  assert.deepEqual(moves, ['HSCUSTOM', 'USER'], 'and the subscription can be dropped');
});

test('reset forgets the list, so the next principal in this tab is asked about afresh', async () => {
  const api = stubApi([ok(listBody('HSCUSTOM', [{ name: 'HSCUSTOM', writable: true }]))]);
  const scope = new ScopeService({ api });
  await scope.load();
  assert.equal(scope.loaded(), true);

  scope.reset();
  assert.equal(scope.loaded(), false);
  assert.deepEqual(scope.namespaces(), []);
  assert.equal(scope.refusal(), null, 'including a refusal the previous principal earned');
  assert.equal(scope.namespace(), '', 'and nothing is scoped until the new principal has been answered');
});

/** An API whose answer is released by the returned `release`, so a read can be held across a reset. */
function heldApi(answer) {
  const calls = [];
  let release = () => {};
  const gate = new Promise((resolve) => {
    release = () => resolve(answer);
  });
  return {
    calls,
    release: () => release(),
    requestJson: (path, init = {}) => {
      calls.push({ path, scope: init.scope });
      return gate;
    },
  };
}

test('AD-8: a list answered after a reset settles nothing', async () => {
  // The generation counter, read across `runLoad`'s await. Sign-out clears the tab in place, so a
  // read started by the previous principal can still resume afterwards; installing its answer
  // would scope the next principal's very first requests to a namespace they were never offered.
  const api = heldApi(ok(listBody('HSCUSTOM', [{ name: 'HSCUSTOM', writable: true }])));
  const scope = new ScopeService({ api });
  const pending = scope.load();

  scope.reset();
  api.release();
  await pending;
  await SETTLE();

  assert.equal(scope.loaded(), false, 'the previous principal answer does not mark the list loaded');
  assert.deepEqual(scope.namespaces(), [], 'and installs no namespaces');
  assert.equal(scope.namespace(), '', 'so nothing is scoped on their behalf');
});

test('AD-8: a refusal answered after a reset records nothing', async () => {
  // The same counter, read across `runVerify`'s await -- the second place a previous principal's
  // answer can land, and the one that would otherwise show the next user a privilege refusal
  // earned by somebody else. The list answers at once; the verification it triggers is held.
  const calls = [];
  let release = () => {};
  const held = new Promise((resolve) => {
    release = () => resolve(denied('%DB_USER:READ'));
  });
  const api = {
    calls,
    requestJson: (path, init = {}) => {
      calls.push({ path, scope: init.scope });
      if (calls.length === 1) {
        return Promise.resolve(ok(listBody('HSCUSTOM', [{ name: 'HSCUSTOM', writable: true }])));
      }
      return held;
    },
  };
  const scope = new ScopeService({ api });
  scope.setRequested('USER');
  await scope.load();
  await SETTLE();
  assert.equal(calls.length, 2, 'the unlisted namespace was verified');

  scope.reset();
  release();
  await SETTLE();

  assert.equal(scope.refusal(), null, 'the previous principal refusal is not shown to the next one');
});

test('a malformed list entry is dropped rather than becoming a namespace named ""', async () => {
  const api = stubApi([
    ok(
      listBody('HSCUSTOM', [
        { name: 'HSCUSTOM', writable: true },
        { writable: true },
        'USER',
        null,
      ])
    ),
  ]);
  const scope = new ScopeService({ api });
  await scope.load();
  assert.deepEqual(
    scope.namespaces().map((entry) => entry.name),
    ['HSCUSTOM']
  );
});

test('a failed list read settles nothing, so a later load can still answer', async () => {
  const api = stubApi([
    { kind: 'error', status: 500, code: 'INTERNAL', reason: null, detail: null },
    ok(listBody('HSCUSTOM', [{ name: 'HSCUSTOM', writable: true }])),
  ]);
  const scope = new ScopeService({ api });
  await scope.load();
  assert.equal(scope.loaded(), false);

  await scope.load();
  assert.equal(scope.loaded(), true);
  assert.equal(scope.namespace(), 'HSCUSTOM');
});

test('one request however many callers', async () => {
  const api = stubApi([ok(listBody('HSCUSTOM', []))]);
  const scope = new ScopeService({ api });
  await Promise.all([scope.load(), scope.load(), scope.load()]);
  assert.equal(api.calls.length, 1);
});

// --- The Integration AC, composed -----------------------------------------------------------
//
// The rows above exercise `ScopeService` against a stub API, and `navigation.test.mjs` exercises
// `NavigationService` the same way. Neither observes the join, and the lines that make it --
// `scope: () => scope.namespace()` and `onScopeChange(scope, ...)` -- live in `main.ts`, which no
// test constructs. This row builds the real three over one stub `fetch`, wired exactly as
// `main.ts` wires them, so "the scope's consumer re-reads carrying `ns=USER`" is asserted on the
// request that actually reaches the network.
//
// Mutation (Rule 19): drop the `?ns=` attachment from `ApiService.scopedPath` -> the two scoped
// assertions below go red while every row above stays green.

const { ApiService } = await import(corePath('api.ts'));
const { NavigationService, NAVIGATION_PATH } = await import(corePath('navigation.ts'));

/**
 * Everything `ApiService` asks of its two collaborators and nothing more. A tab holding no pair
 * takes the plain path, so neither the early-renew nor the 401-retry branch is entered and the
 * recorded calls are one per request.
 */
function bearerless() {
  return {
    tokens: { read: () => null, accessToken: () => '' },
    session: {
      remainingMs: () => 1,
      refresh: async () => false,
      noteInstallInFlight: () => false,
    },
  };
}

/** One area of a navigation map, in the shape `navigation.test.mjs` builds them. */
function mapArea(allowed, failedPair) {
  return { key: 'logs', allowed, failedPair, screens: [] };
}

test('Integration (Rule 1), composed: the map is re-read against the namespace now in force', async () => {
  const paths = [];
  // `logs` is allowed in HSCUSTOM and refused in USER, so the verdict says which namespace the
  // map was computed against -- not merely that a second request happened.
  const verdictFor = (path) =>
    path.includes('ns=USER')
      ? mapArea(false, '%Admin_Operate:USE')
      : mapArea(true, '');

  const { tokens, session } = bearerless();
  const fetched = async (path) => {
    paths.push(path);
    const body = path.startsWith(NAMESPACES_PATH)
      ? {
          scope: 'HSCUSTOM',
          namespaces: [
            { name: 'HSCUSTOM', writable: true },
            { name: 'USER', writable: true },
          ],
        }
      : { areas: [verdictFor(path)] };
    return { status: 200, text: async () => JSON.stringify(body) };
  };

  // The forward reference `main.ts` documents: the API service needs a scope source, and the
  // scope service needs the API service to fetch its own list.
  let scope;
  const api = new ApiService({
    fetch: fetched,
    tokens,
    session,
    scope: () => scope.namespace(),
  });
  scope = new ScopeService({ api });
  const navigation = new NavigationService({ api });
  onScopeChange(scope, () => {
    if (scope.loaded()) navigation.reload();
  });

  // Cold sign-in: the map is read before the list can exist, so it carries no namespace.
  await navigation.load();
  assert.equal(paths[0], NAVIGATION_PATH, 'the first map read carries no ns -- there is no scope yet');
  assert.equal(navigation.areaVerdict('logs').allowed, true);

  // The list arriving is itself the first resolution, and it wakes the consumer.
  await scope.load();
  await SETTLE();
  assert.equal(paths[1], NAMESPACES_PATH, 'the list read is the one call that carries no ns');
  assert.equal(paths[2], NAVIGATION_PATH + '?ns=HSCUSTOM', 'and the map is re-read against the resolved scope');

  // The selection AD-44 is about: a scope change re-fetches its consumer in place.
  assert.equal(scope.select('USER'), true);
  await SETTLE();
  assert.equal(paths[3], NAVIGATION_PATH + '?ns=USER', 'the consumer re-reads carrying the namespace just chosen');
  assert.equal(
    navigation.areaVerdict('logs').allowed,
    false,
    'and the rail gates on the verdicts that namespace returned, with no reload and no re-route'
  );
  assert.equal(paths.length, 4, 'one request per move, and no request for a move that did not happen');
});

test('a sign-out drops the list without waking the map read it just dropped', async () => {
  const paths = [];
  const { tokens, session } = bearerless();
  const fetched = async (path) => {
    paths.push(path);
    const body = path.startsWith(NAMESPACES_PATH)
      ? { scope: 'HSCUSTOM', namespaces: [{ name: 'HSCUSTOM', writable: true }] }
      : { areas: [mapArea(true, '')] };
    return { status: 200, text: async () => JSON.stringify(body) };
  };

  let scope;
  const api = new ApiService({ fetch: fetched, tokens, session, scope: () => scope.namespace() });
  scope = new ScopeService({ api });
  const navigation = new NavigationService({ api });
  onScopeChange(scope, () => {
    if (scope.loaded()) navigation.reload();
  });

  await scope.load();
  await SETTLE();
  const before = paths.length;

  // What `App` does on leaving the signed-in state. The resolved scope moves back to '', which
  // is a change -- but it is the tab being given up, not a namespace being switched.
  navigation.reset();
  scope.reset();
  await SETTLE();

  assert.equal(paths.length, before, 'nothing is re-read for a principal that has just left');
  assert.equal(scope.namespace(), '', 'and nothing is scoped until the next principal is answered');
});
