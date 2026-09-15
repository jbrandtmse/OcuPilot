import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins Story 1.13's client half: the failure taxonomy, the connectivity verdict it publishes,
// and the probe that clears it.
//
// **Unreachability is produced entirely at the injected `fetch` seam** -- a `TypeError`, exactly
// as `api.test.mjs`'s own transport-fault row does -- and the backoff at the injected `schedule`
// seam. Nothing here stops, restarts or otherwise touches the live container, and nothing here
// needs one: `status: 0` is the browser's spelling for "nothing answered", and the whole point of
// the taxonomy is that it is decided from the outcome rather than from the instance.
//
// Mutations (Rule 19):
// - make `classifyFault` return `server-fault` for a 403 -> the table row goes red (and the shell
//   would show "Something failed on the instance" for a privilege the user simply lacks).
// - drop the `status === 0` branch -> every 0 falls into `server-fault`, the probe never arms,
//   and an unreachable instance reads as a broken one with no retry.
// - replace `ConnectivityService`'s keyed `pending` map with an array -> the "one re-ask per
//   reader per clearing" count goes from 3 to 5.
// - delete the `probeArmed` guard -> the backoff test sees two chains and doubled attempts.

const corePath = (name) =>
  join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'app', 'core', name);

const { classifyFault, transportFault, isBannerFault } = await import(corePath('fault.ts'));
const { ConnectivityService, PROBE_BACKOFF_BASE_MS, PROBE_BACKOFF_MAX_MS, PROBE_PATH } =
  await import(corePath('connectivity.ts'));
const { ApiService } = await import(corePath('api.ts'));
const { Session, LOGIN_PATH, REFRESH_PATH, isSignedIn } = await import(corePath('session.ts'));
const { TokenStore } = await import(corePath('token-store.ts'));
const { InstanceService, INSTANCE_PATH } = await import(corePath('instance.ts'));
const { NavigationService, NAVIGATION_PATH } = await import(corePath('navigation.ts'));
const { ScopeService, NAMESPACES_PATH } = await import(corePath('scope.ts'));

const NOW_MS = 1_700_000_000_000;
const PATH = '/api/ocupilot/instance';

function response(status, body = '') {
  return { status, text: async () => body };
}

function memoryStorage() {
  const map = new Map();
  return {
    getItem: (k) => (map.has(k) ? map.get(k) : null),
    setItem: (k, v) => map.set(k, v),
    removeItem: (k) => map.delete(k),
  };
}

function pairBody() {
  return JSON.stringify({
    access_token: 'a1',
    refresh_token: 'r1',
    sub: 'ann',
    iat: NOW_MS / 1000,
    exp: NOW_MS / 1000 + 60,
  });
}

/**
 * A signed-in tab wired exactly as `src/main.ts` wires it: connectivity built first over a lazy
 * `api`, the API service reporting every outcome into it, and the three readers holding it.
 *
 * `dataHandler(path, init, callIndex)` answers anything that is not a token endpoint, so a test
 * can make the same path fail and then succeed.
 */
function wired(dataHandler) {
  const calls = [];
  const scheduled = [];
  const tokens = new TokenStore({
    storage: memoryStorage(),
    navigationType: () => 'navigate',
    newNonce: () => 'nonce-fault',
  });

  const shared = async (path, init) => {
    if (path === LOGIN_PATH || path === REFRESH_PATH) return response(200, pairBody());
    const index = calls.length;
    calls.push({ path, init });
    return dataHandler(path, init, index);
  };

  const connectivity = new ConnectivityService({
    api: () => api,
    schedule: (run, delayMs) => scheduled.push({ run, delayMs }),
  });
  const session = new Session({
    fetch: shared,
    tokens,
    now: () => NOW_MS,
    schedule: () => {},
    onUnreachable: (path) => {
      connectivity.note(transportFault(path));
      // `true` mirrors `src/main.ts` exactly, and the third argument is the whole point of the
      // mirror: this park is registered while the tab is NOT signed in, which is the only state
      // `App` ever calls `connectivity.reset()` in.
      connectivity.retryWhenReachable(
        path,
        () => {
          void session.retrySubmit();
        },
        true
      );
    },
  });
  const api = new ApiService({
    fetch: shared,
    tokens,
    session,
    onFault: (fault) => connectivity.note(fault),
  });
  const instance = new InstanceService({ api, connectivity });
  const navigation = new NavigationService({ api, connectivity });
  const scope = new ScopeService({ api, connectivity });

  return {
    api,
    session,
    connectivity,
    instance,
    navigation,
    scope,
    calls,
    scheduled,
    countOf: (path) => calls.filter((call) => call.path.split('?')[0] === path).length,
    ready: async () => {
      session.start();
      await settle();
    },
  };
}

/** Let every microtask queued by the services above run out. */
async function settle() {
  for (let i = 0; i < 8; i++) await new Promise((resolve) => setImmediate(resolve));
}

// --- The taxonomy is total over JsonResult plus HTTP status --------------------------------

test('every outcome api.ts can produce maps to exactly one Fault kind, and none is unclassified', () => {
  const rows = [
    // [JsonResult, expected kind or null]
    [{ kind: 'ok', status: 200, body: {} }, null],
    [{ kind: 'ok', status: 204, body: null }, null],
    [{ kind: 'installing', status: 503, code: 'INSTALL.INSTALLING' }, 'not-installed'],
    [{ kind: 'installing', status: 503, code: 'INSTALL.UPGRADEREQUIRED' }, 'not-installed'],
    [{ kind: 'installing', status: 503, code: 'INSTALL.FAILED' }, 'not-installed'],
    [err(0, null), 'unreachable'],
    [err(400, 'NS.UNKNOWN'), 'rejected'],
    [err(401, 'AUTH.ANONYMOUS'), 'rejected'],
    [err(403, 'AUTH.NOADMIN'), 'refused'],
    [err(403, 'NS.DENIED'), 'refused'],
    [err(404, 'ROUTE.NOTFOUND'), 'absent'],
    [err(405, 'ROUTE.METHODNOTALLOWED'), 'rejected'],
    [err(409, 'CONFLICT'), 'rejected'],
    [err(412, null), 'rejected'],
    [err(415, null), 'rejected'],
    [err(422, null), 'rejected'],
    [err(499, null), 'rejected'],
    [err(500, 'INTERNAL'), 'server-fault'],
    [err(501, 'ROUTE.NOTIMPLEMENTED'), 'server-fault'],
    // A 503 that is NOT install-in-flight never reaches the `installing` arm (DW-101), so it
    // arrives here as an ordinary error and must read as a server fault, not as an install.
    [err(503, 'SERVICE.DOWN'), 'server-fault'],
    [err(599, null), 'server-fault'],
    // Statuses that cannot reach the error arm through `requestJson` today, asserted anyway:
    // the union has to be total over the type, not over the paths that happen to exist.
    [err(302, null), 'server-fault'],
    [err(204, null), 'server-fault'],
  ];

  for (const [result, expected] of rows) {
    const fault = classifyFault(result, PATH);
    const kind = fault === null ? null : fault.kind;
    assert.equal(kind, expected, `${result.kind} ${result.status} classified as ${kind}`);
    if (fault !== null) {
      assert.equal(fault.path, PATH, 'every fault carries the path it is about (DW-11)');
      assert.equal(fault.status, result.status);
    }
  }

  // Totality, stated as a property rather than as a count of the rows above: a status band the
  // table forgot would still have to answer with one of the six.
  const kinds = new Set([
    'unreachable',
    'not-installed',
    'rejected',
    'refused',
    'absent',
    'server-fault',
  ]);
  for (let status = 0; status < 600; status += 1) {
    if (status >= 200 && status < 300) continue; // an ok, which `requestJson` never errors on
    const fault = classifyFault(err(status, null), PATH);
    assert.ok(fault !== null && kinds.has(fault.kind), `status ${status} is unclassified`);
  }
});

function err(status, code) {
  return { kind: 'error', status, code, reason: null, detail: null };
}

test('a transport fault outside ApiService produces the same unreachable fault', () => {
  // `Session`'s three token endpoints never reach `requestJson`, so there would otherwise be a
  // second construction of "unreachable" with nothing holding the two equal.
  const fromSession = transportFault(LOGIN_PATH);
  const fromApi = classifyFault(err(0, null), LOGIN_PATH);
  assert.deepEqual(fromSession, fromApi);
});

test('only two of the six kinds have banner copy; the other four have their own surfaces', () => {
  assert.equal(isBannerFault(null), false);
  for (const kind of ['unreachable', 'server-fault']) {
    assert.equal(isBannerFault({ kind, status: 0, code: null, path: PATH }), true, kind);
  }
  for (const kind of ['not-installed', 'rejected', 'refused', 'absent']) {
    assert.equal(isBannerFault({ kind, status: 0, code: null, path: PATH }), false, kind);
  }
});

// --- The probe, its backoff, and what clears it ---------------------------------------------

test('the probe re-issues the identity read and adds no route of its own', () => {
  assert.equal(PROBE_PATH, INSTANCE_PATH, 'the probe is the identity read, not a second endpoint');
});

test('an unreachable fault arms one backoff chain, and the delays double to the cap', async () => {
  const harness = wired(() => {
    throw new TypeError('Failed to fetch');
  });
  await harness.ready();

  void harness.api.requestJson(INSTANCE_PATH);
  await settle();
  assert.equal(harness.connectivity.fault()?.kind, 'unreachable');
  assert.equal(harness.scheduled.length, 1, 'one chain, however many failures');
  assert.equal(harness.scheduled[0].delayMs, PROBE_BACKOFF_BASE_MS);

  // A second failing call while one is armed must not start a second chain (DW-102's rule).
  void harness.api.requestJson(INSTANCE_PATH);
  await settle();
  assert.equal(harness.scheduled.length, 1, 'a second failure arms nothing new');

  const delays = [];
  for (let i = 0; i < 6; i++) {
    const next = harness.scheduled[harness.scheduled.length - 1];
    next.run();
    await settle();
    delays.push(harness.scheduled[harness.scheduled.length - 1].delayMs);
  }
  assert.deepEqual(delays.slice(0, 4), [1000, 2000, 4000, 8000]);
  assert.equal(delays[delays.length - 1], PROBE_BACKOFF_MAX_MS, 'and it stops doubling at the cap');
});

test('any HTTP response clears the unreachable verdict -- 401, 403 and 503 included', async () => {
  for (const [status, body, expected] of [
    [200, '{}', null],
    [401, '{"code":"AUTH.ANONYMOUS"}', 'rejected'],
    [403, '{"code":"AUTH.NOADMIN"}', 'refused'],
    [500, '{"code":"INTERNAL"}', 'server-fault'],
  ]) {
    let down = true;
    const harness = wired(() => {
      if (down) throw new TypeError('Failed to fetch');
      return response(status, body);
    });
    await harness.ready();

    void harness.api.requestJson(INSTANCE_PATH);
    await settle();
    assert.equal(harness.connectivity.fault()?.kind, 'unreachable');

    down = false;
    harness.scheduled[harness.scheduled.length - 1].run();
    await settle();

    const kind = harness.connectivity.fault()?.kind ?? null;
    assert.equal(kind, expected, `a ${status} proves reachability and is no longer unreachable`);
  }
});

test('a 503 INSTALL.* is not a server fault, and never arms the connectivity probe', async () => {
  // AD-38: the instance is coming up, `Session` owns the backoff, and reporting it as a failure
  // the user can retry would be the misattribution DW-1 is about.
  const harness = wired(() =>
    response(503, '{"error":"unavailable","code":"INSTALL.INSTALLING"}')
  );
  await harness.ready();

  const result = await harness.api.requestJson(INSTANCE_PATH);
  await settle();

  assert.equal(result.kind, 'installing');
  assert.equal(harness.connectivity.fault()?.kind, 'not-installed');
  assert.equal(harness.scheduled.length, 0, 'connectivity arms nothing -- the session already has');
});

test('a 403 is reported and never retried (AD-8)', async () => {
  const harness = wired(() => response(403, '{"code":"AUTH.NOADMIN"}'));
  await harness.ready();

  const before = harness.countOf(INSTANCE_PATH);
  await harness.api.requestJson(INSTANCE_PATH);
  await settle();

  assert.equal(harness.connectivity.fault()?.kind, 'refused');
  assert.equal(harness.scheduled.length, 0, 'no probe is armed for a refusal');
  assert.equal(harness.countOf(INSTANCE_PATH) - before, 1, 'and the call is made exactly once');
});

// --- One re-ask per reader per clearing ------------------------------------------------------

test('every reader whose read failed re-runs exactly once when the probe answers -- not once per tick', async () => {
  // The AC's own wording. Three readers fail, each of them more than once, and the probe's first
  // response has to produce one re-read each -- three, not five, and not three per tick.
  let down = true;
  const harness = wired(() => {
    if (down) throw new TypeError('Failed to fetch');
    return response(200, '{"areas":[],"namespaces":[],"scope":"HSCUSTOM","adminApiVersion":2}');
  });
  await harness.ready();

  void harness.instance.verify();
  void harness.navigation.load();
  void harness.scope.load();
  await settle();
  // A second failure for two of them, to prove the pending set is keyed rather than queued.
  void harness.navigation.load();
  void harness.scope.load();
  await settle();

  const before = {
    instance: harness.countOf(INSTANCE_PATH),
    navigation: harness.countOf(NAVIGATION_PATH),
    scope: harness.countOf(NAMESPACES_PATH),
  };
  assert.ok(before.navigation >= 2, 'the map read really did fail more than once');

  down = false;
  harness.scheduled[harness.scheduled.length - 1].run();
  await settle();

  // The probe itself is an identity read, so the instance path gains the probe's own call plus
  // its one re-ask; the other two gain exactly one each.
  assert.equal(harness.countOf(NAVIGATION_PATH) - before.navigation, 1, 'the map re-read once');
  assert.equal(harness.countOf(NAMESPACES_PATH) - before.scope, 1, 'the namespace list re-read once');
  assert.equal(harness.countOf(INSTANCE_PATH) - before.instance, 2, 'the probe, and one re-verify');

  // ...and the readers actually settled on that one re-read.
  assert.equal(harness.instance.status(), 'ready');
  assert.equal(harness.navigation.loaded(), true);
  assert.equal(harness.scope.loaded(), true);
  assert.equal(harness.connectivity.fault(), null);

  // A second probe response re-runs nothing: the set was drained, not replayed.
  const after = harness.countOf(NAVIGATION_PATH);
  harness.connectivity.retry();
  await settle();
  assert.equal(harness.countOf(NAVIGATION_PATH), after, 'nothing is owed a second re-read');
});

test('DW-135: a failed map read leaves every verdict UNGATED and publishes the failure', async () => {
  // Fail open, but never silently. Closing the client over an unanswered question would lock a
  // user out of screens they hold (AD-8 makes the server the gate); saying nothing made an
  // unreachable instance read as one the user has no rights on.
  const harness = wired(() => {
    throw new TypeError('Failed to fetch');
  });
  await harness.ready();

  await harness.navigation.load();
  await settle();

  assert.equal(harness.navigation.loaded(), false);
  assert.deepEqual(harness.navigation.areaVerdict('logs'), { allowed: true, failedPair: '' });
  assert.deepEqual(harness.navigation.screenVerdict(''), { allowed: true, failedPair: '' });
  assert.equal(harness.connectivity.fault()?.kind, 'unreachable');
});

test('DW-119: an unclassified identity answer schedules the re-ask it used to leave unscheduled', async () => {
  // Before this the branch set `checking` and arranged nothing -- no request outstanding, no
  // timer armed -- so a tab could sit on the blocking notice indefinitely.
  let failing = true;
  const harness = wired(() =>
    failing ? response(500, '{"code":"INTERNAL"}') : response(200, '{"adminApiVersion":2}')
  );
  await harness.ready();

  await harness.instance.verify();
  await settle();
  assert.equal(harness.instance.status(), 'checking');
  assert.equal(harness.connectivity.fault()?.kind, 'server-fault');

  // A server fault arms no automatic probe -- its Retry is the user's -- so the banner's own
  // control is what drains the re-ask.
  failing = false;
  harness.connectivity.retry();
  await settle();

  assert.equal(harness.instance.status(), 'ready');
  assert.equal(harness.connectivity.fault(), null);
});

test('the re-ask is idempotent: several failures still produce one verify', async () => {
  let failing = true;
  const harness = wired(() =>
    failing ? response(500, '{"code":"INTERNAL"}') : response(200, '{"adminApiVersion":2}')
  );
  await harness.ready();

  await harness.instance.verify();
  await harness.instance.verify();
  await harness.instance.verify();
  await settle();
  const before = harness.countOf(INSTANCE_PATH);

  failing = false;
  harness.connectivity.retry();
  await settle();

  // The probe's own call plus one re-verify. `verifyInFlight` single-flights the re-ask, and the
  // pending set is keyed, so three failures owe one answer.
  assert.equal(harness.countOf(INSTANCE_PATH) - before, 2);
});

// --- DW-104: a submit that met an unreachable instance ---------------------------------------

test('DW-104: a transport fault on submit keeps the form and the typed password, and re-sends on retry', async () => {
  // DW-1's rule is untouched -- a 404 or a 5xx still enters `installing` (see
  // `session.test.mjs`) -- and only the outcome that is not a response at all changes, to the
  // state that has published copy and a recovery.
  //
  // Mutation (Rule 19): drop the `true` third argument from `main.ts`'s (and this harness's)
  // `retryWhenReachable` call -> `App`'s subscriber below deletes the park and "the submit was
  // sent again" goes red with the tab still on `form`.
  let down = true;
  let logins = 0;
  const scheduled = [];
  const tokens = new TokenStore({
    storage: memoryStorage(),
    navigationType: () => 'navigate',
    newNonce: () => 'nonce-submit',
  });
  const shared = async (path) => {
    if (path === LOGIN_PATH) {
      logins += 1;
      if (down) throw new TypeError('Failed to fetch');
      return response(200, pairBody());
    }
    return response(200, '{}');
  };
  const connectivity = new ConnectivityService({
    api: () => api,
    schedule: (run, delayMs) => scheduled.push({ run, delayMs }),
  });
  const session = new Session({
    fetch: shared,
    tokens,
    now: () => NOW_MS,
    schedule: () => {},
    onUnreachable: (path) => {
      connectivity.note(transportFault(path));
      connectivity.retryWhenReachable(
        path,
        () => {
          void session.retrySubmit();
        },
        true
      );
    },
  });
  const api = new ApiService({ fetch: shared, tokens, session, onFault: (f) => connectivity.note(f) });

  // **`App`'s own session subscriber, verbatim from `app.ts:154-157` + `:197-213`.** Without it
  // this test passed while the shipped shell re-sent nothing: `formLogin` settles on `form`,
  // which notifies, and `App` answers every not-signed-in notification with
  // `connectivity.reset()` -- deleting the park one turn after `onUnreachable` made it.
  session.subscribe(() => {
    if (!isSignedIn(session.state())) connectivity.reset();
  });

  session.setUserName('ann');
  session.setPassword('correct horse');
  await session.submitForm();
  await settle();

  assert.equal(session.state(), 'form', 'the form stays on screen -- not the signing-in skeleton');
  assert.equal(session.userName(), 'ann');
  assert.equal(session.password(), 'correct horse', 'what the user typed survives an unanswered submit');
  assert.equal(session.hasUnansweredSubmit(), true);
  assert.equal(connectivity.fault()?.kind, 'unreachable', 'and the banner has something to say');

  // Retry re-sends what the user typed, through the probe's own recovery.
  down = false;
  const loginsBefore = logins;
  connectivity.retry();
  await settle();

  assert.equal(logins - loginsBefore >= 1, true, 'the submit was sent again');
  assert.equal(session.state(), 'signed-in');
  assert.equal(session.password(), '', 'and an ANSWERED submit clears it, exactly as before');
  assert.equal(session.hasUnansweredSubmit(), false);
});

test('DW-104: a rejected submit still clears the password, and a signed-out tab has nothing to re-send', async () => {
  const tokens = new TokenStore({
    storage: memoryStorage(),
    navigationType: () => 'navigate',
    newNonce: () => 'nonce-reject',
  });
  const session = new Session({
    fetch: async () => response(401, ''),
    tokens,
    now: () => NOW_MS,
    schedule: () => {},
  });

  session.setUserName('ann');
  session.setPassword('wrong');
  await session.submitForm();

  assert.equal(session.state(), 'form-rejected');
  assert.equal(session.password(), '', 'an answered rejection clears it (AD-35, AD-47)');
  assert.equal(session.hasUnansweredSubmit(), false);
  assert.equal(await session.retrySubmit(), false, 'and there is nothing to re-send');
});

// --- Review pass: what the first cut left open -----------------------------------------------

test('a successful call drains the parked re-asks, not only the probe\'s own answer', async () => {
  // The kinds that arm no probe -- a 500, a 403, a 401 -- still park a re-ask, so draining only
  // from `runProbe` left one waiting on a human. Worse, the next successful call cleared the
  // fault and took the banner with it, so the Retry that was its only trigger went too: the tab
  // sat on `checking` with no banner, no timer and no request outstanding, which is DW-119's own
  // condition one layer up.
  //
  // The name is a success, not "any answer": a non-success answer that leaves the banner up has
  // not lost the park its trigger, and one that takes the banner away arms the probe instead --
  // the row below this file's backoff rows covers that half.
  //
  // Mutation (Rule 19): delete the `if (fault === null) { … this.drain(); return; }` arm from
  // `ConnectivityService.note` -> this goes red with the instance still `checking`.
  let failing = true;
  const harness = wired((path) =>
    path.startsWith(INSTANCE_PATH) && failing
      ? response(500, '{"code":"INTERNAL"}')
      : response(200, '{"adminApiVersion":2,"areas":[],"namespaces":[],"scope":"HSCUSTOM"}')
  );
  await harness.ready();

  await harness.instance.verify();
  await settle();
  assert.equal(harness.instance.status(), 'checking', 'a 500 settles nothing');
  assert.equal(harness.connectivity.fault()?.kind, 'server-fault');
  assert.equal(harness.scheduled.length, 0, 'and arms no probe of its own');

  // An unrelated call now succeeds. That is the answer the parked reader was waiting for.
  failing = false;
  await harness.navigation.load();
  await settle();

  assert.equal(harness.connectivity.fault(), null, 'the success cleared the verdict');
  assert.equal(harness.instance.status(), 'ready', 'and the parked identity read ran on it');
});

test('the backoff starts over after a recovery, so a second outage does not begin at the cap', async () => {
  // `probeAttempts` only ever incremented, so a tab that went down, came back and went down
  // again waited the full 8 s before its first re-probe instead of 500 ms.
  //
  // Mutation (Rule 19): delete `this.probeAttempts = 0;` from `runProbe` -> the second
  // outage's first delay is 8000 and this goes red.
  let down = true;
  const harness = wired(() => {
    if (down) throw new TypeError('Failed to fetch');
    return response(200, '{"adminApiVersion":2}');
  });
  await harness.ready();

  void harness.api.requestJson(INSTANCE_PATH);
  await settle();
  assert.equal(harness.scheduled[0].delayMs, PROBE_BACKOFF_BASE_MS, 'the first outage starts at the base delay');
  for (let i = 0; i < 5; i++) {
    harness.scheduled[harness.scheduled.length - 1].run();
    await settle();
  }
  assert.equal(
    harness.scheduled[harness.scheduled.length - 1].delayMs,
    PROBE_BACKOFF_MAX_MS,
    'and climbs to the cap'
  );

  down = false;
  harness.scheduled[harness.scheduled.length - 1].run();
  await settle();
  assert.equal(harness.connectivity.fault(), null, 'the instance answered');

  down = true;
  const armed = harness.scheduled.length;
  void harness.api.requestJson(INSTANCE_PATH);
  await settle();
  assert.equal(
    harness.scheduled[armed].delayMs,
    PROBE_BACKOFF_BASE_MS,
    'the second outage re-probes after 500 ms, not after the 8 s the first one ended on'
  );
});

test('an answer that is NOT a success also ends the backoff', async () => {
  // The other reset site, and the one the success path cannot stand in for: a probe answered by
  // a 401 or a 500 proves reachability just as a 200 does, so the chain must start over from
  // the base delay there too. Without its own row this site is invisible -- `note(null)` covers
  // every mutation of it.
  //
  // Mutation (Rule 19): delete `this.probeAttempts = 0;` from `runProbe` -> this goes red with
  // a delay of 1000 (the chain resuming) instead of 500.
  let stage = 'down';
  const harness = wired(() => {
    if (stage === 'down') throw new TypeError('Failed to fetch');
    return response(500, '{"code":"INTERNAL"}');
  });
  await harness.ready();

  void harness.api.requestJson(INSTANCE_PATH);
  await settle();
  assert.equal(harness.scheduled[0].delayMs, PROBE_BACKOFF_BASE_MS);

  stage = 'answering';
  harness.scheduled[harness.scheduled.length - 1].run();
  await settle();
  assert.equal(harness.connectivity.fault()?.kind, 'server-fault', 'the instance answered, badly');

  stage = 'down';
  const armed = harness.scheduled.length;
  void harness.api.requestJson(INSTANCE_PATH);
  await settle();
  assert.equal(
    harness.scheduled[armed].delayMs,
    PROBE_BACKOFF_BASE_MS,
    'the chain starts over after any answer, not only after a successful one'
  );
});

test('AD-8: reset() drops this principal\'s parked work, so a sign-out cannot re-read their map', async () => {
  // The shape `InstanceService`, `NavigationService` and `ScopeService` already have, called
  // from the same place in `app.ts`. A parked re-read is a request about THIS user; one left
  // armed across a sign-out fires their map and namespace reads on whoever signs in next.
  //
  // Mutation (Rule 19): delete `this.pending.clear()` from `ConnectivityService.reset` -> the
  // map read count rises after the sign-out and this goes red.
  let down = true;
  const harness = wired(() => {
    if (down) throw new TypeError('Failed to fetch');
    return response(200, '{"areas":[]}');
  });
  await harness.ready();

  await harness.navigation.load();
  await settle();
  const parked = harness.countOf(NAVIGATION_PATH);
  assert.ok(parked >= 1, 'the map read really did fail');
  assert.equal(harness.connectivity.fault()?.kind, 'unreachable');

  // What `app.ts` does on leaving the signed-in state, in the same gesture as the other three.
  harness.navigation.reset();
  harness.connectivity.reset();
  // The verdict itself SURVIVES, and that is the half a broader reset would get wrong: a fault
  // is an observation about the instance, not an answer about a principal, and `app.ts` runs
  // this on every pass through a not-signed-in state -- so clearing it here would take the
  // banner off the sign-in card in exactly the state DW-104 put it there for.
  assert.equal(
    harness.connectivity.fault()?.kind,
    'unreachable',
    'an unreachable instance is unreachable for whoever signs in next'
  );

  down = false;
  harness.connectivity.retry();
  await settle();
  assert.equal(
    harness.countOf(NAVIGATION_PATH),
    parked,
    'nothing re-read the departed principal\'s map'
  );
});

test('isRecovering(): the real service turns it on at unreachable, holds it through a non-ok answer, and ends it on a success', async () => {
  // The producer of the status bar's fourth published word (EXPERIENCE.md "status-bar connection state"). Every
  // component spec stubs `isRecovering()` and sets the flag by hand, so the computation itself
  // had no executed test host: dropping the arm that turns it on left the whole suite green
  // and made `statusConnectionSigningInAgain` unreachable in the shipped shell.
  //
  // Mutation (Rule 19): change `note`'s `nextRecovering` to `fault === null ? false :
  // wasRecovering` -> the second assertion goes red.
  let stage = 'down';
  const harness = wired(() => {
    if (stage === 'down') throw new TypeError('Failed to fetch');
    if (stage === 'answering') return response(401, '{"code":"AUTH.ANONYMOUS"}');
    return response(200, '{"adminApiVersion":2}');
  });
  await harness.ready();
  assert.equal(harness.connectivity.isRecovering(), false, 'a tab that has not been away is not recovering');

  void harness.api.requestJson(INSTANCE_PATH);
  await settle();
  assert.equal(harness.connectivity.isRecovering(), true, 'nothing answered, so the tab is away');

  stage = 'answering';
  harness.scheduled[harness.scheduled.length - 1].run();
  await settle();
  assert.equal(harness.connectivity.fault()?.kind, 'rejected', 'the instance answered -- no longer unreachable');
  assert.equal(
    harness.connectivity.isRecovering(),
    true,
    'but nothing has succeeded yet, which is exactly the gap the fourth word names'
  );

  stage = 'ok';
  await harness.api.requestJson(INSTANCE_PATH);
  await settle();
  assert.equal(harness.connectivity.isRecovering(), false, 'a success ends it');
  assert.equal(harness.connectivity.fault(), null);
});

test('DW-135: a map read that failed for a principal who has since left parks nothing', async () => {
  // `navigation.ts` checked its generation AFTER the failure branch, so a read belonging to a
  // departed principal still parked a re-run. `scope.ts` already ordered the two the other way;
  // now both do.
  //
  // Mutation (Rule 19): move `if (generation !== this.generation) return;` back below the
  // `result.kind !== 'ok'` branch in `navigation.ts` -> the map is re-read and this goes red.
  let down = true;
  const harness = wired(() => {
    if (down) throw new TypeError('Failed to fetch');
    return response(200, '{"areas":[]}');
  });
  await harness.ready();

  const pending = harness.navigation.load();
  harness.navigation.reset(); // the principal leaves while the read is on the wire
  await pending;
  await settle();
  const before = harness.countOf(NAVIGATION_PATH);

  down = false;
  harness.connectivity.retry();
  await settle();
  assert.equal(
    harness.countOf(NAVIGATION_PATH),
    before,
    'the departed principal\'s failed read parked no re-run'
  );
});

test('a park is never left with neither a banner nor a timer: a 403 after a 500 arms the probe', async () => {
  // The sibling of the stranded re-ask, one kind further along. A 500 parks `verify()` and
  // raises the banner, whose Retry is that park's only trigger, because a server fault arms no
  // probe. A later answer of a kind the banner has no copy for -- a 403 on another reader --
  // replaced the verdict, took the strip off screen, and armed nothing: the tab sat on
  // `checking` with no banner, no timer and no request outstanding, which is DW-119's own
  // condition. Reproduced end to end before the fix.
  //
  // AD-8 is intact either way: the refused REQUEST is never retried. What is armed is the
  // reachability probe, and only for a park that has just lost its trigger -- a park made under
  // a kind that never had a banner arms nothing at all (the row below).
  //
  // Mutation (Rule 19): delete the `isBannerFault(previous) && !isBannerFault(fault)` arm from
  // `ConnectivityService.note` -> `scheduled.length` stays 0 and the instance stays `checking`.
  let broken = true;
  const harness = wired((path) => {
    if (path.split('?')[0] === NAMESPACES_PATH) return response(403, '{"code":"NS.DENIED"}');
    if (broken) return response(500, '{"code":"INTERNAL"}');
    return response(200, '{"adminApiVersion":2,"areas":[],"namespaces":[],"scope":"HSCUSTOM"}');
  });
  await harness.ready();

  await harness.instance.verify();
  await settle();
  assert.equal(harness.instance.status(), 'checking', 'the 500 settled nothing and parked a re-ask');
  assert.equal(isBannerFault(harness.connectivity.fault()), true, 'the banner is the park\'s trigger');
  assert.equal(harness.scheduled.length, 0, 'and a server fault arms no probe of its own');

  // A different reader now answers 403 -- a kind the banner has no copy for.
  await harness.scope.load();
  await settle();
  assert.equal(harness.connectivity.fault()?.kind, 'refused');
  assert.equal(isBannerFault(harness.connectivity.fault()), false, 'the strip is gone');
  assert.equal(harness.scheduled.length, 1, 'so the park that just lost its trigger got a timer');

  broken = false;
  harness.scheduled[harness.scheduled.length - 1].run();
  await settle();
  assert.equal(harness.instance.status(), 'ready', 'and the parked identity read ran on the answer');
});

test('a park made under a kind that never had a banner arms no probe (AD-8: a 403 is never retried)', async () => {
  // The other half of the rule above, and the one that keeps it from becoming a poll: a map
  // read that fails open on a 403 parks, and the NEXT 403 -- which now meets that park -- still
  // schedules nothing, because the refusal IS the answer, not a failure to reach the instance.
  //
  // Two reads, not one, and that is the whole design of the row: a reader registers its park
  // AFTER `requestJson` resolves, so at the first `note` the pending set is still empty and a
  // one-read version of this test passes under any arming rule whatsoever. (Written as one read
  // first; the mutation below stayed green, which was a fact about the test, not about the
  // code.)
  //
  // Mutation (Rule 19): widen the arm to `this.pending.size > 0` alone -> `scheduled.length`
  // becomes 1 and this goes red, with the shell polling a route it has been refused.
  const harness = wired(() => response(403, '{"code":"NS.DENIED"}'));
  await harness.ready();

  await harness.navigation.load();
  await settle();
  assert.equal(harness.connectivity.fault()?.kind, 'refused');

  await harness.scope.load();
  await settle();
  assert.equal(harness.connectivity.fault()?.kind, 'refused', 'a second refusal, with a park now outstanding');
  assert.equal(harness.scheduled.length, 0, 'a refusal is reported, never retried');
});

test('an ORDINARY success ends the backoff, so a second outage does not begin at the cap', async () => {
  // The non-probe recovery, and the site the probe's own reset cannot stand in for. The review
  // pass applied the keyed mutation to `note`'s success arm, saw it stay green, and concluded
  // the line was redundant -- but every backoff row in this file recovers by FIRING the
  // scheduled probe, which is exactly the one path `runProbe`'s reset covers. An outage that
  // ends while ordinary traffic is flowing left `probeAttempts` at the cap.
  //
  // Mutation (Rule 19): delete `this.probeAttempts = 0;` from `note`'s `fault === null` arm ->
  // the second outage's first delay is 8000 and this goes red. (Deleting the reset in
  // `runProbe` instead reddens the two rows above it, not this one.)
  let down = true;
  const harness = wired(() => {
    if (down) throw new TypeError('Failed to fetch');
    return response(200, '{"adminApiVersion":2}');
  });
  await harness.ready();

  void harness.api.requestJson(INSTANCE_PATH);
  await settle();
  for (let i = 0; i < 5; i++) {
    harness.scheduled[harness.scheduled.length - 1].run();
    await settle();
  }
  assert.equal(
    harness.scheduled[harness.scheduled.length - 1].delayMs,
    PROBE_BACKOFF_MAX_MS,
    'the first outage climbed to the cap'
  );

  // The instance comes back, and an ordinary call -- not the probe, not Retry -- is what finds
  // out. The probe scheduled at the cap is still pending; it is the next link in the chain, and
  // what it arms next is the whole question.
  down = false;
  await harness.api.requestJson(INSTANCE_PATH);
  await settle();
  assert.equal(harness.connectivity.fault(), null, 'an ordinary call answered');

  down = true;
  const armed = harness.scheduled.length;
  harness.scheduled[armed - 1].run();
  await settle();
  assert.equal(
    harness.scheduled[armed].delayMs,
    PROBE_BACKOFF_BASE_MS,
    'the second outage re-probes after 500 ms, not after the 8 s the first one ended on'
  );
});
