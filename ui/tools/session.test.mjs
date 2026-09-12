import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the session half of AD-28: the silent-first sequence, the DW-1 classifier, the
// DW-4 single-flight refresh and the state-to-presentation mapping the shell gates on.
//
// Everything here runs against an injected `fetch`, storage, clock and scheduler, so no
// test touches a network, a browser or a timer. The wire behaviour these fakes imitate is
// pinned separately and for real by `OcuPilot.Test.Token` against the live instance --
// including the one that is easy to get wrong: replaying a rotated refresh token revokes
// the whole session, which is why a second concurrent refresh is not merely wasteful.
//
// Mutations (Rule 19):
// - drop the `refreshInFlight` guard in Session.refresh() -> the three-concurrent-401s
//   test counts three /refresh calls instead of one.
// - make classifyLoginStatus return 'credential-failure' for any non-200 -> every DW-1
//   row goes red, reporting a sign-in failure for an instance that is still installing.
// - delete the second silent probe from the failed-refresh path -> the "continues
//   invisibly" test goes red and the user meets a form they should never have seen.

const corePath = (name) =>
  join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'app', 'core', name);

const {
  Session,
  LOGIN_PATH,
  REFRESH_PATH,
  LOGOUT_PATH,
  classifyLoginStatus,
  isInstallInFlight,
  sessionMessageKey,
  isSignedIn,
  isWaiting,
  BACKOFF_BASE_MS,
  BACKOFF_MAX_MS,
  RENEWAL_MARGIN_MS,
} = await import(corePath('session.ts'));
const { TokenStore } = await import(corePath('token-store.ts'));
const { ApiService } = await import(corePath('api.ts'));

const NOW_MS = 1_700_000_000_000;

function pairBody(access, refresh, sub = 'ann', expSeconds = NOW_MS / 1000 + 60) {
  return JSON.stringify({
    access_token: access,
    refresh_token: refresh,
    sub,
    iat: NOW_MS / 1000,
    exp: expSeconds,
  });
}

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

/** A fresh, empty tab: nothing stored, navigated to rather than reloaded. */
function freshTokens() {
  return new TokenStore({
    storage: memoryStorage(),
    navigationType: () => 'navigate',
    newNonce: () => 'nonce-test',
  });
}

/**
 * Build a session over a recording fetch. `handler(path, init, callIndex)` returns the
 * response; the recorded calls are returned alongside so a test can count them.
 */
function makeSession(handler, overrides = {}) {
  const calls = [];
  const scheduled = [];
  const tokens = overrides.tokens ?? freshTokens();
  const session = new Session({
    fetch: async (path, init) => {
      const index = calls.length;
      calls.push({ path, init });
      return handler(path, init, index);
    },
    tokens,
    now: () => NOW_MS,
    schedule: (run, delayMs) => scheduled.push({ run, delayMs }),
  });
  return { session, tokens, calls, scheduled };
}

// --- The classifier (DW-1) ------------------------------------------------------------

test('DW-1: only a 401 from /login is a credential failure', () => {
  assert.equal(classifyLoginStatus(200), 'ok');
  assert.equal(classifyLoginStatus(401), 'credential-failure');
  for (const status of [404, 500, 502, 503, 504, 0]) {
    assert.equal(
      classifyLoginStatus(status),
      'unavailable',
      `${status} says the instance could not answer, never that the password was wrong`
    );
  }
});

test('an INSTALL.* code on a 503 is install-in-flight; the same status with another code is not', () => {
  assert.equal(isInstallInFlight(503, 'INSTALL.INSTALLING'), true);
  assert.equal(isInstallInFlight(503, 'INSTALL.UPGRADEREQUIRED'), true);
  assert.equal(isInstallInFlight(503, 'INSTALL.FAILED'), true);
  assert.equal(isInstallInFlight(503, 'SOMETHING.ELSE'), false);
  assert.equal(isInstallInFlight(503, null), false);
  assert.equal(isInstallInFlight(500, 'INSTALL.INSTALLING'), false);
});

// --- Silent-first -----------------------------------------------------------------------

test('silent mint: an empty-body probe that returns a pair signs the tab in, with no form', async () => {
  const { session, tokens, calls } = makeSession(() => response(200, pairBody('a1', 'r1')));

  session.start();
  assert.equal(session.state(), 'probing', 'the probe is in flight while the shell paints');
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(session.state(), 'signed-in');
  assert.equal(session.userName(), 'ann', 'the shell knows who it signed in as');
  assert.equal(tokens.accessToken(), 'a1');
  assert.equal(calls.length, 1);
  assert.equal(calls[0].path, LOGIN_PATH);
  assert.equal(calls[0].init.body, undefined, 'the probe carries no body');
  assert.equal(
    calls[0].init.credentials,
    'include',
    "the browser's own %ISCMgtPortal cookie is what authenticates a silent mint"
  );
});

test('cold browser: a 401 from the probe shows the form once', async () => {
  const { session, calls } = makeSession(() => response(401, ''));

  session.start();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(session.state(), 'form');
  assert.equal(calls.length, 1, 'the form appears after one probe, not a retry loop');
});

/** A tab that is continuing itself (a reload) and already holds `pair` in storage. */
function reloadedTokens(pair) {
  const storage = memoryStorage();
  storage.setItem('ocupilot.token-pair', JSON.stringify(pair));
  storage.setItem('ocupilot.tab-nonce', 'nonce-kept');
  return new TokenStore({
    storage,
    navigationType: () => 'reload',
    newNonce: () => 'unused',
  });
}

test('a reloaded tab holding a LIVE pair skips the probe entirely (DW-6 continuation)', async () => {
  const tokens = reloadedTokens({
    accessToken: 'a9',
    refreshToken: 'r9',
    sub: 'ann',
    iat: NOW_MS / 1000,
    exp: NOW_MS / 1000 + 60,
  });
  const { session, calls } = makeSession(() => response(200, pairBody('a1', 'r1')), { tokens });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(session.state(), 'signed-in');
  assert.equal(calls.length, 0, 'a continuing tab already holds its session');
});

test('a reloaded tab holding an EXPIRED pair renews it instead of reporting signed-in', async () => {
  // Access tokens last 60 s, so a tab reloaded even a minute later holds a dead one.
  // Adopting it verbatim renders the whole product against a credential the instance will
  // refuse, and with no data call in this story nothing would ever discover it.
  const tokens = reloadedTokens({
    accessToken: 'a9',
    refreshToken: 'r9',
    sub: 'ann',
    iat: NOW_MS / 1000 - 600,
    exp: NOW_MS / 1000 - 540,
  });
  const { session, calls } = makeSession(
    (path) => (path === REFRESH_PATH ? response(200, pairBody('a10', 'r10')) : response(404)),
    { tokens }
  );

  session.start();
  assert.equal(session.state(), 'probing', 'the dead pair is not a session');
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(calls.length, 1);
  assert.equal(calls[0].path, REFRESH_PATH, 'it renews rather than claiming signed-in');
  assert.equal(session.state(), 'signed-in');
  assert.equal(session.pair().accessToken, 'a10');
});

test('a reloaded tab whose refresh token is dead too lands on the session-ended form', async () => {
  const tokens = reloadedTokens({
    accessToken: 'a9',
    refreshToken: 'r9',
    sub: 'ann',
    iat: NOW_MS / 1000 - 6000,
    exp: NOW_MS / 1000 - 5940,
  });
  const { session } = makeSession(() => response(401, ''), { tokens });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(session.state(), 'session-ended', 'not a bare form: the user is told why');
  assert.equal(session.pair(), null);
});

// --- The form -----------------------------------------------------------------------------

test('form accepted: the credentials go in the JSON body as user and password', async () => {
  const { session, tokens, calls } = makeSession((path) =>
    path === LOGIN_PATH ? response(200, pairBody('a2', 'r2')) : response(404)
  );

  session.setUserName('ann');
  session.setPassword('correct horse');
  const accepted = await session.submitForm();

  assert.equal(accepted, true);
  assert.equal(session.state(), 'signed-in');
  assert.equal(tokens.accessToken(), 'a2');
  assert.deepEqual(JSON.parse(calls[0].init.body), { user: 'ann', password: 'correct horse' });
  assert.equal(calls[0].init.headers['Content-Type'], 'application/json');
  assert.equal(session.password(), '', 'the password does not outlive the request that used it');
});

test('form rejected: the user name is kept, the password is cleared, authSignInFailed is selected', async () => {
  const { session, tokens } = makeSession(() => response(401, ''));

  session.setUserName('ann');
  session.setPassword('wrong');
  const accepted = await session.submitForm();

  assert.equal(accepted, false);
  assert.equal(session.state(), 'form-rejected');
  assert.equal(session.userName(), 'ann', 'the user name survives the rejection');
  assert.equal(session.password(), '', 'the password does not');
  assert.equal(
    sessionMessageKey(session.state()),
    'authSignInFailed',
    'and the message slot selects the sign-in failure string'
  );
  assert.equal(tokens.read(), null, 'a rejected attempt stores nothing');
});

test('a rejected password reaches no storage', async () => {
  const storage = memoryStorage();
  const writes = [];
  const recording = {
    getItem: storage.getItem,
    setItem: (k, v) => {
      writes.push(v);
      storage.setItem(k, v);
    },
    removeItem: storage.removeItem,
  };
  const tokens = new TokenStore({
    storage: recording,
    navigationType: () => 'navigate',
    newNonce: () => 'nonce-x',
  });
  const { session } = makeSession(() => response(401, ''), { tokens });

  session.setUserName('ann');
  session.setPassword('super-secret-value');
  await session.submitForm();

  for (const written of writes) {
    assert.ok(
      !String(written).includes('super-secret-value'),
      'no password may be written to per-tab storage (AD-35)'
    );
  }
});

// --- Install in flight (DW-1) --------------------------------------------------------------

test('DW-1: a 404, a 5xx and a network fault all enter installing and re-probe, never form-rejected', async () => {
  for (const outcome of ['404', '503', 'throw']) {
    const { session, scheduled } = makeSession(() => {
      if (outcome === 'throw') throw new TypeError('Failed to fetch');
      return response(Number(outcome), '');
    });

    session.start();
    await new Promise((resolve) => setImmediate(resolve));

    assert.equal(session.state(), 'installing', `${outcome} is not a credential failure`);
    assert.equal(scheduled.length, 1, `${outcome} schedules a re-probe`);
    assert.equal(scheduled[0].delayMs, BACKOFF_BASE_MS);
    assert.equal(
      sessionMessageKey(session.state()),
      'statusConnectionSigningIn',
      'and the presentation stays the signing-in one, which is truthful'
    );
  }
});

test('the re-probe backs off, and a probe that finally succeeds signs the tab in', async () => {
  let attempt = 0;
  const { session, scheduled } = makeSession(() => {
    attempt += 1;
    return attempt < 4 ? response(503, '') : response(200, pairBody('a3', 'r3'));
  });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(scheduled[0].delayMs, BACKOFF_BASE_MS);

  scheduled[0].run();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(session.state(), 'installing', 'still installing after the second attempt');
  assert.equal(scheduled[1].delayMs, BACKOFF_BASE_MS * 2, 'and the wait doubles');

  scheduled[1].run();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(scheduled[2].delayMs, BACKOFF_BASE_MS * 4);

  scheduled[2].run();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(session.state(), 'signed-in', 'the fourth attempt lands');
  assert.equal(scheduled.length, 4, 'the backoff chain stops; one renewal is armed');
  assert.equal(
    scheduled[3].delayMs,
    60_000 - RENEWAL_MARGIN_MS,
    'and what was scheduled is the renewal timer, not a fifth backoff'
  );
});

test('the backoff stops doubling at the cap, driven through the session rather than computed', async () => {
  // An unclamped doubling reaches hours within a dozen attempts, and the `installing` state
  // is precisely the one that must keep re-probing until the instance answers. The previous
  // version of this test recomputed Math.min over two exported constants and would have
  // stayed green with the clamp deleted, so it is driven through enterInstalling here.
  const { session, scheduled } = makeSession(() => response(503, ''));

  session.start();
  await new Promise((resolve) => setImmediate(resolve));

  // Far enough that an unclamped delay would be BACKOFF_BASE_MS * 2**11, ~17 minutes.
  for (let i = 0; i < 11; i += 1) {
    scheduled[scheduled.length - 1].run();
    await new Promise((resolve) => setImmediate(resolve));
  }

  assert.equal(session.state(), 'installing');
  const delays = scheduled.map((s) => s.delayMs);
  assert.equal(delays[0], BACKOFF_BASE_MS, 'it starts at the base');
  assert.equal(delays[1], BACKOFF_BASE_MS * 2, 'and doubles');
  assert.ok(
    delays.every((d) => d <= BACKOFF_MAX_MS),
    `no scheduled delay may exceed the cap: ${JSON.stringify(delays)}`
  );
  assert.equal(
    delays[delays.length - 1],
    BACKOFF_MAX_MS,
    'and once past the cap every further wait is the cap itself'
  );
});

// --- Refresh ---------------------------------------------------------------------------------

test('a refresh sends the refresh token in the JSON body, never as a Bearer', async () => {
  const { session, tokens, calls } = makeSession((path) =>
    path === REFRESH_PATH ? response(200, pairBody('a5', 'r5')) : response(200, pairBody('a4', 'r4'))
  );

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  const renewed = await session.refresh();

  assert.equal(renewed, true);
  const refreshCall = calls.find((c) => c.path === REFRESH_PATH);
  assert.deepEqual(JSON.parse(refreshCall.init.body), { refresh_token: 'r4' });
  assert.equal(
    refreshCall.init.headers['Authorization'],
    undefined,
    'a refresh token presented as a Bearer is refused by the instance'
  );
  assert.equal(tokens.accessToken(), 'a5', 'and the rotated pair replaces the old one');
});

test('a failed refresh runs the silent probe once more, and on 200 the user sees nothing', async () => {
  let refreshes = 0;
  let logins = 0;
  const { session } = makeSession((path) => {
    if (path === REFRESH_PATH) {
      refreshes += 1;
      return response(401, '');
    }
    logins += 1;
    return response(200, pairBody(`a${logins}`, `r${logins}`));
  });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(session.state(), 'signed-in');

  const renewed = await session.refresh();

  assert.equal(refreshes, 1);
  assert.equal(logins, 2, 'EXPERIENCE.md :571 -- the silent probe runs once more before the form');
  assert.equal(renewed, true);
  assert.equal(session.state(), 'signed-in', 'and the session continues invisibly');
});

test('a failed refresh whose silent retry is also refused ends the session, with the route preserved', async () => {
  let logins = 0;
  const { session } = makeSession((path) => {
    if (path === REFRESH_PATH) return response(401, '');
    logins += 1;
    return logins === 1 ? response(200, pairBody('a1', 'r1')) : response(401, '');
  });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  const renewed = await session.refresh();

  assert.equal(renewed, false);
  assert.equal(session.state(), 'session-ended');
  assert.equal(
    sessionMessageKey(session.state()),
    'authSessionEnded',
    'the form returns carrying "Your session ended."'
  );
});

test('a refresh that cannot reach the instance is install-in-flight, not a session end', async () => {
  const { session } = makeSession((path) => {
    if (path === REFRESH_PATH) return response(503, '');
    return response(200, pairBody('a1', 'r1'));
  });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  const renewed = await session.refresh();

  assert.equal(renewed, false);
  assert.equal(session.state(), 'installing');
});

// --- DW-4: single flight ------------------------------------------------------------------------

test('DW-4: three concurrent 401s resolve through exactly one refresh, and each retries once', async () => {
  let refreshes = 0;
  let rotated = false;
  const dataCalls = [];

  const tokens = freshTokens();
  // One fetch behind both the session and the API service, exactly as in the browser.
  const shared = async (path, init) => {
    if (path === LOGIN_PATH) return response(200, pairBody('access-1', 'refresh-1'));
    if (path === REFRESH_PATH) {
      refreshes += 1;
      rotated = true;
      return response(200, pairBody('access-2', 'refresh-2'));
    }
    dataCalls.push({ path, authorization: init.headers['Authorization'] });
    return rotated ? response(200, '{}') : response(401, '');
  };
  const session = new Session({ fetch: shared, tokens, now: () => NOW_MS, schedule: () => {} });
  const api = new ApiService({ fetch: shared, tokens, session });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(tokens.accessToken(), 'access-1');

  const results = await Promise.all([
    api.request('/api/ocupilot/a'),
    api.request('/api/ocupilot/b'),
    api.request('/api/ocupilot/c'),
  ]);

  assert.deepEqual(
    results.map((r) => r.status),
    [200, 200, 200],
    'every waiter completes'
  );
  assert.equal(refreshes, 1, 'one refresh, however many callers were waiting');
  assert.equal(dataCalls.length, 6, 'three 401s and three retries');
  assert.deepEqual(
    dataCalls.slice(0, 3).map((c) => c.authorization),
    ['Bearer access-1', 'Bearer access-1', 'Bearer access-1']
  );
  assert.deepEqual(
    dataCalls.slice(3).map((c) => c.authorization),
    ['Bearer access-2', 'Bearer access-2', 'Bearer access-2'],
    'and every retry carries the rotated token, not the one the refresh killed'
  );
});

test('a failed refresh resolves every waiter to the session-ended path, once', async () => {
  let refreshes = 0;
  let logins = 0;
  const tokens = freshTokens();
  const shared = async (path, init) => {
    if (path === REFRESH_PATH) {
      refreshes += 1;
      return response(401, '');
    }
    if (path === LOGIN_PATH) {
      logins += 1;
      return logins === 1 ? response(200, pairBody('access-1', 'refresh-1')) : response(401, '');
    }
    void init;
    return response(401, '');
  };
  const session = new Session({ fetch: shared, tokens, now: () => NOW_MS, schedule: () => {} });
  const api = new ApiService({ fetch: shared, tokens, session });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));

  const results = await Promise.all([
    api.request('/api/ocupilot/a'),
    api.request('/api/ocupilot/b'),
    api.request('/api/ocupilot/c'),
  ]);

  assert.deepEqual(
    results.map((r) => r.status),
    [401, 401, 401]
  );
  assert.equal(refreshes, 1, 'one refresh attempt, not three');
  assert.equal(logins, 2, 'one silent retry, not three');
  assert.equal(session.state(), 'session-ended');
});

// --- Sign-out ---------------------------------------------------------------------------------
//
// The wire half is pinned for real against the live instance by OcuPilot.Test.Token: with
// both credentials the browser-level login is gone afterwards; with the Bearer alone it
// survives. What is pinned here is the client's side of AD-28 and the whole of DW-5.

test('sign-out carries the Bearer and the cookie, and clears the tab', async () => {
  const { session, tokens, calls } = makeSession(() => response(200, pairBody('a1', 'r1')));

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  await session.signOut();

  const logout = calls.find((c) => c.path === LOGOUT_PATH);
  assert.ok(logout, 'sign-out reaches the instance');
  assert.equal(logout.init.headers['Authorization'], 'Bearer a1');
  assert.equal(logout.init.credentials, 'include', 'Bearer alone would leave the browser signed in');
  assert.equal(tokens.read(), null);
  assert.equal(session.state(), 'signed-out');
  assert.equal(
    sessionMessageKey(session.state()),
    'authSignedOut',
    'and the form says the user signed out, not that their session ended'
  );
});

test('sign-out clears the user name, so the form does not pre-fill the last user on a shared machine', async () => {
  // `sign-in.ts` seeds its user-name field from `session.userName()`. Keeping the name is
  // EXPERIENCE.md's rule for a rejected *attempt* inside one sign-in, not for a sign-out --
  // which is the machine being handed over. Without the clear, the next person at the
  // keyboard is shown who just signed out, and every other test here stays green.
  const { session } = makeSession(() => response(200, pairBody('a1', 'r1')));

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(session.userName(), 'ann', 'the signed-in name is what the menu trigger shows');

  await session.signOut();

  assert.equal(session.userName(), '', 'and it is gone with the pair');
});

test('sign-out from a tab holding no pair settles locally and issues no logout', async () => {
  // There is nothing a request could do: a logout carrying the cookie alone is refused 401
  // (OcuPilot.Test.Token.TestACookieOnlyLogoutIsRefused). Without the guard the tab sends
  // an `Authorization: Bearer ` with no token after it, and the suite stays green.
  const { session, tokens, calls } = makeSession(() => response(401, ''));

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(tokens.read(), null, 'the probe minted nothing');

  await session.signOut();

  assert.ok(
    !calls.some((c) => c.path === LOGOUT_PATH),
    'no logout goes out when there is no Bearer to carry'
  );
  assert.equal(session.state(), 'signed-out');
});

test('DW-5: the tab is already cleared and signed-out when the logout is issued', async () => {
  // The ordering IS the fix. A catch around the request covers a throw and nothing else;
  // clearing first covers a throw, a non-2xx and a hang with one rule.
  const seen = [];
  const { session, tokens } = makeSession((path) => {
    if (path === LOGOUT_PATH) {
      seen.push({ state: session.state(), pair: tokens.read() });
      return response(200, '');
    }
    return response(200, pairBody('a1', 'r1'));
  });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  await session.signOut();

  assert.equal(seen.length, 1, 'one logout request');
  assert.equal(seen[0].state, 'signed-out', 'the local half ran before the request went out');
  assert.equal(seen[0].pair, null, 'and the pair was already gone from the tab');
});

test('DW-5: a logout that throws leaves the tab cleared and signed-out', async () => {
  const { session, tokens } = makeSession((path) => {
    if (path === LOGOUT_PATH) throw new TypeError('Failed to fetch');
    return response(200, pairBody('a1', 'r1'));
  });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  await session.signOut();

  assert.equal(tokens.read(), null, 'no token may survive on a shared machine');
  assert.equal(session.state(), 'signed-out');
});

test('DW-5: a logout answered 401 changes nothing locally', async () => {
  // Observed on the instance: logging out an already-dead pair answers 401. That is the
  // session being gone, which is what was asked for -- never a reason to revert the tab.
  const { session, tokens } = makeSession((path) =>
    path === LOGOUT_PATH ? response(401, '') : response(200, pairBody('a1', 'r1'))
  );

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  await session.signOut();

  assert.equal(tokens.read(), null);
  assert.equal(session.state(), 'signed-out');
});

test('DW-5: a logout that never settles does not hold the tab signed in', async () => {
  const { session, tokens } = makeSession((path) =>
    path === LOGOUT_PATH ? new Promise(() => {}) : response(200, pairBody('a1', 'r1'))
  );

  session.start();
  await new Promise((resolve) => setImmediate(resolve));

  // Deliberately not awaited: the request never settles, and that is the point -- the
  // local half has already happened by the time signOut() returns its promise.
  const pending = session.signOut();
  assert.equal(tokens.read(), null, 'cleared before the request was issued, not after it answered');
  assert.equal(session.state(), 'signed-out');

  // `signOut()` is declared `async`, so `pending instanceof Promise` holds for any body and
  // pins nothing. What is worth pinning is that it has NOT settled: the request never
  // answers, so a caller awaiting it waits, while the tab above is already signed out.
  let settled = false;
  void pending.then(() => {
    settled = true;
  });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(settled, false, 'the promise tracks the request, which is still in flight');
});

test('a backoff probe armed before sign-out lands after it and adopts nothing', async () => {
  // The other half of DW-5. A failed logout leaves the browser-level login alive, so a
  // probe scheduled before the sign-out would mint a fresh pair from it and sign the tab
  // straight back in -- seconds after the user asked to be signed out.
  let probes = 0;
  const { session, tokens, scheduled } = makeSession((path) => {
    if (path !== LOGIN_PATH) return response(200, '');
    probes += 1;
    return probes === 1 ? response(503, '') : response(200, pairBody('a1', 'r1'));
  });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(session.state(), 'installing', 'a backoff probe is armed');
  assert.equal(scheduled.length, 1);

  await session.signOut();
  assert.equal(session.state(), 'signed-out');

  scheduled[0].run();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(probes, 1, 'the armed probe never reached the wire');
  assert.equal(tokens.read(), null, 'so no pair was adopted');
  assert.equal(session.state(), 'signed-out', 'and the sign-out held');
});

test('sign-out resets the backoff, so a later sign-in starts from the base delay', async () => {
  // signOut() clears installAttempts. Without that, a tab that had backed off to the 8 s cap
  // before signing out inherits that position: the first re-probe after the user signs back
  // in is 16x later than it should be, on the signing-in skeleton the whole time.
  const { session, scheduled } = makeSession(() => response(503, ''));

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  for (let i = 0; i < 5; i += 1) {
    scheduled[scheduled.length - 1].run();
    await new Promise((resolve) => setImmediate(resolve));
  }
  assert.equal(
    scheduled[scheduled.length - 1].delayMs,
    BACKOFF_MAX_MS,
    'the chain has backed off to the cap'
  );

  await session.signOut();
  const before = scheduled.length;

  await session.submitForm();
  assert.equal(session.state(), 'installing', 'the instance is still unavailable');
  assert.equal(
    scheduled[before].delayMs,
    BACKOFF_BASE_MS,
    'the new chain starts from the base delay, not where the old one left off'
  );
});

test('a probe already in flight when sign-out happens adopts nothing', async () => {
  let release = () => {};
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const { session, tokens } = makeSession(async (path) => {
    if (path !== LOGIN_PATH) return response(200, '');
    await gate;
    return response(200, pairBody('a1', 'r1'));
  });

  session.start();
  assert.equal(session.state(), 'probing');

  await session.signOut();
  assert.equal(session.state(), 'signed-out');

  release();
  await new Promise((resolve) => setImmediate(resolve));
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(tokens.read(), null, 'the probe that answered after the sign-out stored nothing');
  assert.equal(session.state(), 'signed-out');
});

test('a refresh already in flight when sign-out happens adopts nothing', async () => {
  let release = () => {};
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const { session, tokens } = makeSession(async (path) => {
    if (path === LOGIN_PATH) return response(200, pairBody('a1', 'r1'));
    if (path !== REFRESH_PATH) return response(200, '');
    await gate;
    return response(200, pairBody('a2', 'r2'));
  });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(session.state(), 'signed-in');

  const refreshing = session.refresh();
  await session.signOut();
  assert.equal(session.state(), 'signed-out');

  release();
  assert.equal(await refreshing, false, 'the refresh reports that it settled nothing');
  assert.equal(tokens.read(), null, 'the rotated pair is not adopted behind a sign-out');
  assert.equal(session.state(), 'signed-out');
});

// --- The mapping app.ts gates on -------------------------------------------------------------

test('Integration AC: only signed-in renders the routed screen; every other state renders sign-in', () => {
  const states = [
    'probing',
    'signed-in',
    'form',
    'form-rejected',
    'password-expired',
    'session-ended',
    'signed-out',
    'installing',
  ];
  const signedIn = states.filter((s) => isSignedIn(s));
  assert.deepEqual(signedIn, ['signed-in']);
});

test('installing renders the signing-in presentation, never the credentials form (DW-1)', () => {
  // The user-visible half of DW-1. Asking for a password while the instance is still
  // installing tells the user to fix something that was never their problem, and
  // `sign-in.ts` selects its branch from this function rather than restating the rule.
  const waiting = [
    'probing',
    'signed-in',
    'form',
    'form-rejected',
    'password-expired',
    'session-ended',
    'signed-out',
    'installing',
  ].filter((s) => isWaiting(s));
  assert.deepEqual(waiting, ['probing', 'installing']);
});

test('each state selects the message its slot renders, and only signed-in and form carry none', () => {
  assert.equal(sessionMessageKey('probing'), 'statusConnectionSigningIn');
  assert.equal(sessionMessageKey('installing'), 'statusConnectionSigningIn');
  assert.equal(sessionMessageKey('form-rejected'), 'authSignInFailed');
  assert.equal(sessionMessageKey('password-expired'), 'authPasswordExpired');
  assert.equal(sessionMessageKey('session-ended'), 'authSessionEnded');
  assert.equal(
    sessionMessageKey('signed-out'),
    'authSignedOut',
    'the user who chose Sign out is not told their session ended'
  );
  assert.equal(sessionMessageKey('signed-in'), null);
  assert.equal(sessionMessageKey('form'), null);
});

test('every key the message slot can select exists in the string source', async () => {
  const { loadStrings } = await import('./strings.mjs');
  const strings = loadStrings();
  for (const state of [
    'probing',
    'installing',
    'form-rejected',
    'password-expired',
    'session-ended',
    'signed-out',
  ]) {
    const key = sessionMessageKey(state);
    assert.ok(
      Object.prototype.hasOwnProperty.call(strings, key),
      `sessionMessageKey('${state}') selects ${key}, which strings.ts does not carry`
    );
  }
});

// --- The containers the matrix rows name, read out of the component's own template --------
//
// `sign-in.ts` has no component runner until Story 1.9 (DW-93), so the two accessibility
// containers the I/O matrix names are pinned by reading the template source. That is weaker
// than a render, and it is not nothing: both are single attributes that a reformat or a
// careless edit drops silently, and nothing else in the suite would notice.
//
// Mutation (Rule 19): drop `role="alert"` from the failure line, or `aria-busy`/`aria-hidden`
// from the skeleton, -> the matching assertion goes red.

const signInSource = readFileSync(
  join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'app', 'shell', 'sign-in.ts'),
  'utf8'
);

const signInTemplate = (() => {
  const match = /template:\s*`([\s\S]*?)`,\n\}\)/.exec(signInSource);
  assert.ok(match, 'sign-in.ts must carry one inline template: `...` block');
  return match[1];
})();

test('the sign-in failure is announced: authSignInFailed sits inside a role="alert" element', () => {
  const opening = /<([a-z-]+)([^>]*)>\s*\{\{\s*STRINGS\.authSignInFailed\s*\}\}/.exec(
    signInTemplate
  );
  assert.ok(opening, 'the template must render STRINGS.authSignInFailed');
  assert.match(
    opening[2],
    /\brole="alert"/,
    'a rejected attempt must reach assistive technology without the user moving focus'
  );
});

test('the signing-in skeleton is decoration inside a busy region, and the status line is not', () => {
  const region = /<section([^>]*)>([\s\S]*?)<\/section>/.exec(signInTemplate);
  assert.ok(region, 'the signing-in state must render one section');
  assert.match(region[1], /\baria-busy="true"/, 'the region announces that it is working');

  // The skeleton element's full extent, brace-counted rather than "up to the first
  // </div>" -- the bars are themselves divs, so the first closing tag is still inside it.
  const open = /<div([^>]*\bclass="ocu-skeleton"[^>]*)>/.exec(region[2]);
  assert.ok(open, 'the region must carry the skeleton bars');
  assert.match(open[1], /\baria-hidden="true"/, 'the bars themselves are decoration');

  const tail = region[2].slice(open.index);
  let depth = 0;
  let end = -1;
  for (const tag of tail.matchAll(/<\/?div\b/g)) {
    depth += tag[0] === '</div' ? -1 : 1;
    if (depth === 0) {
      end = tag.index + tag[0].length;
      break;
    }
  }
  assert.ok(end > 0, 'the skeleton element must be balanced');
  const hidden = tail.slice(0, end);

  assert.ok(
    !hidden.includes('STRINGS.statusConnectionSigningIn'),
    'the status line must not be inside the aria-hidden subtree, where nothing can read it'
  );
  assert.ok(
    region[2].replace(hidden, '').includes('STRINGS.statusConnectionSigningIn'),
    'and it must be in the busy region, carrying the meaning the bars cannot'
  );
});

test('the signed-out message is a banner, not an alert: the user caused it', () => {
  const opening = /<([a-z-]+)([^>]*)>\s*\{\{\s*STRINGS\.authSignedOut\s*\}\}/.exec(signInTemplate);
  assert.ok(opening, 'the template must render STRINGS.authSignedOut');
  assert.match(
    opening[2],
    /\bclass="[^"]*\bocu-banner\b/,
    'a chosen sign-out is confirmed as a banner'
  );
  assert.ok(
    !/\brole="alert"/.test(opening[2]),
    'and never interrupts with an alert, which is reserved for the rejection the user did not choose'
  );
});

test('the signed-out banner is gated on signed-out, not on some other state', () => {
  // Without this the banner's own condition is unpinned: `signedOut` could compare against
  // 'authSessionEnded' and the suite would stay green, the build clean and the template text
  // byte-identical -- leaving a chosen sign-out silent and an instance-ended session showing
  // two identical banners. That is exactly the confusion AC 2 exists to prevent.
  const gate = /@if \((\w+)\) \{\s*<[a-z-]+[^>]*>\s*\{\{\s*STRINGS\.authSignedOut\s*\}\}/.exec(
    signInTemplate
  );
  assert.ok(gate, 'the authSignedOut banner must sit inside an @if block');
  assert.equal(gate[1], 'signedOut', 'gated on the signed-out getter');
  assert.match(
    signInSource,
    /get signedOut\(\): boolean \{\s*return sessionMessageKey\(this\.sessionState\(\)\) === 'authSignedOut';/,
    'and that getter compares against authSignedOut, never authSessionEnded'
  );
});

test('each status block opens at the slot\'s own level, so none is unreachable behind another', () => {
  // The two assertions above match the banner wherever it sits. Nest the `@if (signedOut)`
  // block inside `@if (rejected)` -- two conditions that can never both hold -- and both
  // still pass, the template text is byte-identical, the build is clean, and a user who
  // chose Sign out lands on a bare form with no confirmation at all.
  const slot = /<div[^>]*\bclass="ocu-signin-status"[^>]*>([\s\S]*?)<\/div>\s*<\/form>/.exec(
    signInTemplate
  );
  assert.ok(slot, 'the status slot must be the last element of the form');

  // Brace-count at the slot's own level. `{{ ... }}` interpolations contribute a balanced
  // pair each, so they never move the depth a block is read at.
  const top = [];
  let depth = 0;
  for (const token of slot[1].matchAll(/@if \((\w+)\) \{|\{|\}/g)) {
    if (token[1] !== undefined) {
      if (depth === 0) top.push(token[1]);
      depth += 1;
    } else {
      depth += token[0] === '{' ? 1 : -1;
    }
  }
  assert.deepEqual(
    top,
    ['rejected', 'expired', 'ended', 'signedOut'],
    'four status conditions, each a sibling of the others -- a nested one can never render'
  );
});

test('a subscriber is notified on every state change and can unsubscribe', async () => {
  const { session } = makeSession(() => response(401, ''));
  const seen = [];
  const stop = session.subscribe(() => seen.push(session.state()));

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  assert.deepEqual(seen, ['form']);

  stop();
  session.setUserName('ann');
  session.setPassword('x');
  await session.submitForm();
  assert.deepEqual(seen, ['form'], 'nothing reaches a listener that unsubscribed');
});

// --- AD-28: the renewal timer -------------------------------------------------------------
//
// "The client refreshes on a timer derived from the token's own lifetime and retries once
// on a 401 ... because a turn can outlive an access token." Without the timer half, a pair
// is only ever renewed at the moment a call discovers it dead, so an idle tab's refresh
// token (900 s) expires behind a dead access token (60 s) and the session is gone.
//
// Mutation (Rule 19): delete the `scheduleRenewal()` call from Session.adopt() -> "a minted
// pair arms a renewal..." goes red, and nothing in the client renews on time again.

test('a minted pair arms a renewal timer derived from its own exp, short of expiry', async () => {
  const { session, scheduled } = makeSession(() => response(200, pairBody('a1', 'r1')));

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(session.state(), 'signed-in');

  const renewals = scheduled.filter((s) => s.delayMs > BACKOFF_MAX_MS);
  assert.equal(renewals.length, 1, 'exactly one renewal is armed');
  assert.equal(
    renewals[0].delayMs,
    60_000 - RENEWAL_MARGIN_MS,
    'derived from the pair, not from a constant interval'
  );
  assert.ok(renewals[0].delayMs < 60_000, 'and it fires before the token expires, not after');
});

test('the armed renewal rotates the pair with no call having been made', async () => {
  let minted = 0;
  const { session, scheduled } = makeSession((path) => {
    if (path === LOGIN_PATH) return response(200, pairBody('a1', 'r1'));
    minted += 1;
    return response(200, pairBody(`a${minted + 1}`, `r${minted + 1}`));
  });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(session.pair().accessToken, 'a1');

  scheduled.find((s) => s.delayMs > BACKOFF_MAX_MS).run();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(minted, 1, 'the timer refreshed on its own, with no data call to prompt it');
  assert.equal(session.pair().accessToken, 'a2');
  assert.equal(session.state(), 'signed-in', 'and the user saw nothing');
});

test('a renewal armed before sign-out cannot sign the tab back in after it', async () => {
  // The scheduler is injected as a bare (run, delay) => void, so there is no handle to
  // clear. A generation counter is what disarms a timer instead; without it the pending
  // renewal fires after signOut(), mints a fresh pair, and silently undoes the sign-out.
  const { session, scheduled, tokens } = makeSession(() => response(200, pairBody('a1', 'r1')));

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  const renewal = scheduled.find((s) => s.delayMs > BACKOFF_MAX_MS);

  await session.signOut();
  assert.equal(session.state(), 'signed-out');

  renewal.run();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(tokens.read(), null, 'the stale timer did not re-mint a pair');
  assert.equal(session.state(), 'signed-out', 'and the sign-out held');
});

test('a renewal armed for a superseded pair does not rotate the pair that replaced it', async () => {
  // The case the generation counter exists for, and the one the sign-out test above cannot
  // reach: after a rotation the tab still holds A pair, so a "do we hold anything?" check
  // passes and the stale timer refreshes again -- rotating a pair that has plenty of life
  // left, and on this instance every extra rotation is a chance to revoke the session.
  let refreshes = 0;
  const { session, scheduled } = makeSession((path) => {
    if (path === LOGIN_PATH) return response(200, pairBody('a1', 'r1'));
    refreshes += 1;
    return response(200, pairBody(`a${refreshes + 1}`, `r${refreshes + 1}`));
  });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  const stale = scheduled.find((s) => s.delayMs > BACKOFF_MAX_MS);

  // The pair rotates once, which arms a second renewal and supersedes the first.
  stale.run();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(refreshes, 1);
  assert.equal(session.pair().accessToken, 'a2');

  // Now the superseded timer fires late.
  stale.run();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(refreshes, 1, 'the stale renewal did nothing; only the live one is armed');
  assert.equal(session.pair().accessToken, 'a2');
});

test('a pair with no exp arms no renewal and keeps the retry-on-401 path', async () => {
  // Unknown expiry is not "expires now": there is no lifetime to derive a timer from, and
  // inventing one would rotate the pair on a schedule the instance never agreed to.
  const { session, scheduled } = makeSession(() =>
    response(200, JSON.stringify({ access_token: 'a1', refresh_token: 'r1', sub: 'ann' }))
  );

  session.start();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(session.state(), 'signed-in');
  assert.deepEqual(scheduled, [], 'nothing is armed on a pair that declares no lifetime');
});

// --- One submit at a time ------------------------------------------------------------------

test('two submits in flight produce one login, not two sids', async () => {
  // The form does unmount as soon as formLogin sets `probing`, but change detection is
  // scheduled rather than synchronous (AD-19, zoneless), so a second Enter or click can
  // land first. Two logins mint two sids; the second adopt() overwrites the first pair and
  // leaves that session live on the instance with nothing holding it.
  let logins = 0;
  const { session } = makeSession((path) => {
    if (path !== LOGIN_PATH) return response(404);
    logins += 1;
    return response(200, pairBody(`a${logins}`, `r${logins}`));
  });

  session.setUserName('ann');
  session.setPassword('secret');

  const [first, second] = await Promise.all([session.submitForm(), session.submitForm()]);

  assert.equal(logins, 1, 'the second submit joined the first rather than starting its own');
  assert.equal(first, true);
  assert.equal(second, true, 'and both callers got the same outcome');
  assert.equal(session.state(), 'signed-in');
  assert.equal(session.password(), '', 'the password is cleared exactly once, on the outcome');
});

// --- DW-102: one install-backoff chain, however many callers ---------------------------------

test('DW-102: a data call and the session probe entering install backoff arm one chain, not two', async () => {
  const { session, scheduled } = makeSession(() => response(200, pairBody('a1', 'r1')));

  assert.equal(
    session.noteInstallInFlight(503, 'INSTALL.INSTALLING'),
    true,
    'the first caller is told this is an install, not a failure'
  );
  assert.equal(session.noteInstallInFlight(503, 'INSTALL.INSTALLING'), true, 'and so is the second');

  assert.equal(scheduled.length, 1, 'but only one probe is armed');
  assert.equal(
    scheduled[0].delayMs,
    BACKOFF_BASE_MS,
    'at the base delay -- a second arming would have counted a second attempt and doubled it'
  );
  assert.equal(session.state(), 'installing', 'and both callers see the same waiting state');
});

test('DW-102: the second caller mints no second sid and overwrites no stored pair', async () => {
  let probes = 0;
  const { session, tokens, scheduled } = makeSession((path) => {
    if (path !== LOGIN_PATH) return response(200, '');
    probes += 1;
    return response(200, pairBody(`a${probes}`, `r${probes}`));
  });

  session.noteInstallInFlight(503, 'INSTALL.INSTALLING');
  session.noteInstallInFlight(503, 'INSTALL.INSTALLING');

  for (const armed of scheduled) armed.run();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(probes, 1, 'one /login, so one sid');
  assert.equal(tokens.accessToken(), 'a1', 'and the pair the one chain adopted is the one held');
  assert.equal(session.state(), 'signed-in');
});

test('DW-102: the chain is armed again once the probe it armed has run', async () => {
  const { session, scheduled } = makeSession(() => response(503, ''));

  session.noteInstallInFlight(503, 'INSTALL.INSTALLING');
  assert.equal(scheduled.length, 1);

  scheduled[0].run();
  await new Promise((resolve) => setImmediate(resolve));

  assert.ok(scheduled.length >= 2, 'the refused probe backs off again -- the guard is not a latch');
});

test('DW-102: a caller arriving while the armed probe is on the wire arms no second chain', async () => {
  // `backoffArmed` covers only the armed window -- the scheduled callback clears it before
  // it probes. Without a second guard, a data call answering 503 during that probe's own
  // /login arms a second chain, and the two mint two sids and overwrite each other's pair,
  // which is the whole of what DW-102 forbids. The session stays `installing` for the
  // entire chain, armed and probing alike, so that is what the guard reads.
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  let logins = 0;
  const { session, scheduled, tokens } = makeSession(async (path) => {
    if (path !== LOGIN_PATH) return response(200, '');
    logins += 1;
    await gate;
    return response(200, pairBody(`a${logins}`, `r${logins}`));
  });

  session.noteInstallInFlight(503, 'INSTALL.INSTALLING');
  assert.equal(scheduled.length, 1, 'the first caller arms the chain');

  scheduled[0].run();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(logins, 1, 'whose probe is now on the wire');

  assert.equal(
    session.noteInstallInFlight(503, 'INSTALL.INSTALLING'),
    true,
    'a data call meeting a 503 in that window is still told installing'
  );
  assert.equal(scheduled.length, 1, 'but arms no second probe');

  release();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(logins, 1, 'one /login, so one sid');
  assert.equal(tokens.accessToken(), 'a1', 'and the pair the one chain adopted is the one held');
  assert.equal(session.state(), 'signed-in');
});

test('DW-107: a 503 that answers after sign-out arms nothing and leaves the tab signed out', async () => {
  // The other end of DW-107's window. A data call already on the wire when Sign out was
  // chosen answers afterwards; arming here would put the signed-out tab back on the
  // installing presentation, which is the state the user just left deliberately.
  const { session, scheduled, tokens } = makeSession(() => response(200, pairBody('a1', 'r1')));

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(session.state(), 'signed-in');

  await session.signOut();
  assert.equal(session.state(), 'signed-out');
  const armedAtSignOut = scheduled.length;

  assert.equal(
    session.noteInstallInFlight(503, 'INSTALL.INSTALLING'),
    true,
    'the caller is told what its own 503 said'
  );

  assert.equal(session.state(), 'signed-out', 'but the tab stays where the user put it');
  assert.equal(scheduled.length, armedAtSignOut, 'and nothing is armed');
  assert.equal(tokens.read(), null, 'so no pair can be minted from it');
});

test('DW-102: a response that is not install-in-flight arms nothing and changes no state', async () => {
  const { session, scheduled } = makeSession(() => response(200, pairBody('a1', 'r1')));

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  const armedAfterSignIn = scheduled.length;

  assert.equal(session.noteInstallInFlight(503, 'SERVICE.DOWN'), false, 'not every 503 is an install');
  assert.equal(session.noteInstallInFlight(500, 'INSTALL.INSTALLING'), false, 'and not every INSTALL. code is a 503');
  assert.equal(scheduled.length, armedAfterSignIn, 'neither armed a probe');
  assert.equal(session.state(), 'signed-in', 'and neither moved the tab off the product');
});

// --- DW-107: a refresh STARTED after sign-out cannot re-mint ---------------------------------

test('DW-107: a refresh started after sign-out adopts nothing and issues no request', async () => {
  // The browser-level login a failed logout left alive would answer /login with a fresh
  // pair, so a refresh that fell through to the silent probe here would sign the tab back
  // in seconds after the user signed out. signOutGeneration cannot catch this one: a chain
  // STARTED after the sign-out captures the new generation.
  const { session, tokens, calls } = makeSession((path) =>
    path === LOGIN_PATH ? response(200, pairBody('after', 'after')) : response(200, '')
  );

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(session.state(), 'signed-in');

  await session.signOut();
  assert.equal(session.state(), 'signed-out');
  const afterSignOut = calls.length;

  const renewed = await session.refresh();

  assert.equal(renewed, false, 'the refresh reports failure rather than a rescue');
  assert.equal(calls.length, afterSignOut, 'and reached the wire not at all');
  assert.equal(tokens.read(), null, 'no pair was minted from a login the logout may have left alive');
  assert.equal(session.state(), 'signed-out', 'and the sign-out held');
});

test('DW-107: the guard is scoped to signed-out -- a pairless refresh elsewhere still probes once', async () => {
  // The same line must not disarm the rescue EXPERIENCE.md :571 asks for, which runs when a
  // tab loses its pair without the user asking to be signed out.
  const { session, calls } = makeSession(() => response(401, ''));

  session.start();
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(session.state(), 'form', 'a cold browser, holding no pair');
  const afterProbe = calls.length;

  await session.refresh();

  assert.equal(calls.length, afterProbe + 1, 'the silent probe still runs');
});

// --- The instance guard (AD-27) --------------------------------------------------------------

const {
  InstanceService,
  INSTANCE_PATH,
  REQUIRED_ADMIN_API_VERSION,
  NO_ADMIN_CODE,
  VERSION_PLACEHOLDER,
  isInstanceReady,
  formatVersionMismatch,
  serverFlagKind,
} = await import(corePath('instance.ts'));

const { loadStrings: loadStringsSource } = await import('./strings.mjs');
/** The string source as it ships, for the two tests that read the mismatch sentence. */
const shippedStrings = loadStringsSource();

/** A signed-in tab with an `InstanceService` over the same fetch. */
function withInstance(dataHandler) {
  const calls = [];
  const tokens = freshTokens();
  const shared = async (path, init) => {
    if (path === LOGIN_PATH) return response(200, pairBody('a1', 'r1'));
    calls.push({ path, init });
    return dataHandler(path, init, calls.length - 1);
  };
  const session = new Session({ fetch: shared, tokens, now: () => NOW_MS, schedule: () => {} });
  const api = new ApiService({ fetch: shared, tokens, session });
  return {
    session,
    calls,
    instance: new InstanceService({ api }),
    ready: async () => {
      session.start();
      await new Promise((resolve) => setImmediate(resolve));
    },
  };
}

function identityBody(adminApiVersion, extra = {}) {
  return JSON.stringify({
    adminApiVersion,
    instanceName: 'IRIS',
    instanceVersion: 'IRIS for UNIX 2026.2',
    buildIdentity: 'dev',
    serverFlag: '',
    licensedTo: 'InterSystems IRIS Community',
    serverName: 'B066BA383583',
    ...extra,
  });
}

test('AC1: a v2 instance settles ready, and the seven identity fields are kept', async () => {
  const harness = withInstance(() => response(200, identityBody(REQUIRED_ADMIN_API_VERSION)));
  await harness.ready();

  assert.equal(await harness.instance.verify(), 'ready');
  assert.equal(harness.instance.adminApiVersion(), 2);
  assert.equal(harness.instance.instanceName(), 'IRIS');
  assert.equal(harness.instance.instanceVersion(), 'IRIS for UNIX 2026.2');
  assert.equal(harness.instance.buildIdentity(), 'dev', 'DW-3: the version row stamp reaches the browser');
  // Story 1.10's three: the status bar's server, licensed-to and flag segments.
  assert.equal(harness.instance.serverFlag(), '');
  assert.equal(harness.instance.licensedTo(), 'InterSystems IRIS Community');
  assert.equal(harness.instance.serverName(), 'B066BA383583');
  assert.equal(harness.calls.length, 1, 'exactly one identity call');
  assert.equal(harness.calls[0].path, INSTANCE_PATH);
  assert.equal(harness.calls[0].init.credentials, 'omit', 'carrying only the Bearer (AD-28)');
  assert.equal(harness.calls[0].init.headers['Authorization'], 'Bearer a1');
});

test('AC3: any other version settles version-mismatch and keeps the number the notice names', async () => {
  const harness = withInstance(() => response(200, identityBody(1)));
  await harness.ready();

  assert.equal(await harness.instance.verify(), 'version-mismatch');
  assert.equal(harness.instance.adminApiVersion(), 1);
});

test('AC3: an absent or probe-failed admin API reports 0 and is a mismatch, not a privilege problem', async () => {
  const harness = withInstance(() => response(200, identityBody(0)));
  await harness.ready();

  assert.equal(await harness.instance.verify(), 'version-mismatch');
  assert.equal(harness.instance.adminApiVersion(), 0);
});

test('Story 1.10: the status-bar fields are strings or nothing, never whatever the wire carried', async () => {
  // The same defence every other field on this response has: a number, a null or a missing
  // key reads as `''`, and the status bar drops that segment rather than rendering `null`.
  const harness = withInstance(() =>
    response(
      200,
      JSON.stringify({ adminApiVersion: 2, serverFlag: 7, licensedTo: null })
    )
  );
  await harness.ready();
  await harness.instance.verify();

  assert.equal(harness.instance.serverFlag(), '');
  assert.equal(harness.instance.licensedTo(), '');
  assert.equal(harness.instance.serverName(), '', 'a key the response never carried');
});

test('Story 1.10: reset forgets the status-bar fields with the rest of the verdict (AD-8)', async () => {
  const harness = withInstance(() => response(200, identityBody(2, { serverFlag: 'TEST' })));
  await harness.ready();
  await harness.instance.verify();
  assert.equal(harness.instance.serverFlag(), 'TEST');

  harness.instance.reset();
  assert.equal(harness.instance.serverFlag(), '');
  assert.equal(harness.instance.licensedTo(), '');
  assert.equal(harness.instance.serverName(), '');
});

test('DW-10: serverFlagKind case-folds the four, reports absence, and never guesses', () => {
  // Stored modes are upper case -- IRIS's own setter upper-cases its argument -- so a
  // comparison against what happens to be stored today would break on a lower-case write.
  assert.equal(serverFlagKind('LIVE'), 'live');
  assert.equal(serverFlagKind('Test'), 'test');
  assert.equal(serverFlagKind('failover'), 'failover');
  assert.equal(serverFlagKind(' DEVELOPMENT '), 'development');

  // The common state, and the one DW-10 is about: an unflagged instance gets NO badge.
  // Answering `live` here is the failure the entry was filed for.
  assert.equal(serverFlagKind(''), 'none');
  assert.equal(serverFlagKind('   '), 'none');

  // Only a direct write to `^%SYS("SystemMode")` can produce this, and it is shown verbatim
  // rather than mapped onto one of the four.
  assert.equal(serverFlagKind('STANDBY'), 'unknown');
  assert.equal(serverFlagKind('live-ish'), 'unknown');
});

test('AC4: the router 403 settles no-privileges, read from the code and never the reason', async () => {
  const harness = withInstance(() =>
    response(
      403,
      JSON.stringify({
        error: 'forbidden',
        reason: 'This account holds no InterSystems IRIS administrative privilege',
        code: NO_ADMIN_CODE,
      })
    )
  );
  await harness.ready();

  assert.equal(await harness.instance.verify(), 'no-privileges');
  assert.equal(harness.instance.adminApiVersion(), 0, 'and no version is reported to name');
});

test('AC4: neither notice is ever selected for the other one\'s cause', async () => {
  const denied = withInstance(() => response(403, JSON.stringify({ code: NO_ADMIN_CODE })));
  await denied.ready();
  assert.notEqual(await denied.instance.verify(), 'version-mismatch');

  const mismatched = withInstance(() => response(200, identityBody(1)));
  await mismatched.ready();
  assert.notEqual(await mismatched.instance.verify(), 'no-privileges');

  const otherRefusal = withInstance(() => response(403, JSON.stringify({ code: 'SOMETHING.ELSE' })));
  await otherRefusal.ready();
  assert.equal(
    await otherRefusal.instance.verify(),
    'checking',
    'a 403 that is not the administrative gate is not the no-privileges notice either'
  );
});

test('an install in flight settles nothing, so a later verify can still answer', async () => {
  let answers = 0;
  const harness = withInstance(() => {
    answers += 1;
    return answers === 1
      ? response(503, JSON.stringify({ code: 'INSTALL.INSTALLING' }))
      : response(200, identityBody(2));
  });
  await harness.ready();

  assert.equal(await harness.instance.verify(), 'checking', 'nothing is claimed about the instance');
  assert.equal(harness.session.state(), 'installing', 'and the session is backing off (DW-101)');

  assert.equal(await harness.instance.verify(), 'ready', 'the unsettled answer is retried');
});

test('DW-119: a generic identity failure settles nothing, so a later verify can still answer', async () => {
  // Neither AUTH.NOADMIN nor an install-in-flight 503 -- a plain 500, or any other failure
  // this shell cannot explain. Nothing here schedules that later call on its own (that
  // scheduler is Story 1.13's, per this spec's own Design Notes), but the fall-through must
  // not mark the answer settled either, or the one avenue back to a conclusive verdict --
  // a caller invoking verify() again -- would replay the same stale 'checking' forever.
  let answers = 0;
  const harness = withInstance(() => {
    answers += 1;
    return answers === 1
      ? response(500, JSON.stringify({ code: 'SOMETHING.UNEXPECTED' }))
      : response(200, identityBody(2));
  });
  await harness.ready();

  assert.equal(await harness.instance.verify(), 'checking', 'nothing is claimed about the instance');
  assert.equal(
    await harness.instance.verify(),
    'ready',
    'a later verify -- however it comes to be called -- can still settle it'
  );
  assert.equal(
    harness.calls.filter((c) => c.path === INSTANCE_PATH).length,
    2,
    'which took a second identity call, not a cached stale answer'
  );
});

test('AC1: a settled answer is not re-fetched, so exactly one identity call goes out', async () => {
  const harness = withInstance(() => response(200, identityBody(2)));
  await harness.ready();

  await Promise.all([harness.instance.verify(), harness.instance.verify()]);
  await harness.instance.verify();

  assert.equal(harness.calls.length, 1, 'concurrent callers share one request, and a settled one repeats none');
});

// The three values the client holds a copy of. Each is compared against the literal the
// server actually emits or serves, not against itself: a test that builds its fixture body
// from the same constant it then asserts is green under any rename, and the real 403 or
// the real path would miss the branch in production with the suite still passing.

test('the client\'s copy of the route path and the refusal code are the ones the server serves', () => {
  assert.equal(
    INSTANCE_PATH,
    '/api/ocupilot/instance',
    'the path OcuPilot.Api.Router maps as <Route Url="/instance" Method="GET"/> under /api/ocupilot'
  );
  assert.equal(
    NO_ADMIN_CODE,
    'AUTH.NOADMIN',
    'the code OcuPilot.Api.Error emits for the router administrative gate (Api/Error.cls)'
  );
});

test('DW-121: the port and the client require the same admin API version', () => {
  // AdminPort.APIVERSION (ObjectScript) and REQUIRED_ADMIN_API_VERSION (this module) are
  // two sources for one fact (AD-27, NFR-8), and nothing before this test checked that a
  // version bump on one side reached the other. Read from the class source directly --
  // rather than trusted as a comment -- so this is a cross-language check, not a restatement
  // of either constant.
  const portPath = join(
    dirname(fileURLToPath(import.meta.url)),
    '..',
    '..',
    'src',
    'OcuPilot',
    'Port',
    'AdminPort.cls'
  );
  const portSource = readFileSync(portPath, 'utf8');
  const match = /Parameter APIVERSION As INTEGER = (\d+);/.exec(portSource);
  assert.ok(match, 'AdminPort.cls must declare "Parameter APIVERSION As INTEGER = <n>;"');
  assert.equal(
    Number(match[1]),
    REQUIRED_ADMIN_API_VERSION,
    'a version bump on one side must be matched on the other'
  );
});

test('the mismatch sentence names the version the client actually requires', () => {
  // The number in the copy and the number the comparison uses are two sources for one
  // fact. Bumping the supported version without rewording the sentence would ship a
  // notice that contradicts the check that produced it.
  assert.ok(
    shippedStrings.authAdminApiVersionMismatch.includes(`needs version ${REQUIRED_ADMIN_API_VERSION}`),
    'the sentence must name REQUIRED_ADMIN_API_VERSION'
  );
  assert.ok(
    shippedStrings.authAdminApiVersionMismatch.includes(VERSION_PLACEHOLDER),
    'and keep the placeholder the component substitutes'
  );
});

test('AC3: the mismatch sentence is formatted with the reported version, placeholder and all', () => {
  // Executed, not read out of the component's source: the component has no runner until
  // Story 1.9 (DW-93), and renaming the placeholder on one side only is exactly the
  // mutation a source-text regex cannot see.
  assert.equal(
    formatVersionMismatch(shippedStrings.authAdminApiVersionMismatch, 1),
    "This instance's admin API is version 1; OcuPilot needs version 2."
  );
  assert.equal(
    formatVersionMismatch(shippedStrings.authAdminApiVersionMismatch, 0),
    "This instance's admin API is version 0; OcuPilot needs version 2.",
    'an absent or probe-failed API reports 0, and 0 is a version like any other here'
  );
  assert.ok(
    !formatVersionMismatch(shippedStrings.authAdminApiVersionMismatch, 3).includes(VERSION_PLACEHOLDER),
    'nothing of the placeholder survives into what the user reads'
  );
});

test('Integration AC: only ready opens the gate -- every other instance status withholds the outlet', () => {
  // Executed over the whole type, so widening the predicate (`=== ready || === checking`)
  // goes red here rather than shipping a routed screen on an unverified instance.
  assert.equal(isInstanceReady('ready'), true);
  for (const status of ['checking', 'version-mismatch', 'no-privileges']) {
    assert.equal(isInstanceReady(status), false, `${status} must not open the routed outlet`);
  }
});

test('AC4: a second principal in the same tab does not inherit the first one\'s verdict', async () => {
  // signOut() clears the tab in place without a reload, so the service outlives the user.
  let answers = 0;
  const harness = withInstance(() => {
    answers += 1;
    return answers === 1
      ? response(200, identityBody(2))
      : response(403, JSON.stringify({ code: NO_ADMIN_CODE }));
  });
  await harness.ready();

  assert.equal(await harness.instance.verify(), 'ready', 'the first principal is an administrator');

  await harness.session.signOut();
  harness.instance.reset();

  assert.equal(harness.instance.status(), 'checking', 'the verdict is forgotten with the principal');
  assert.equal(
    await harness.instance.verify(),
    'no-privileges',
    'and the next principal is asked about on its own account'
  );
  assert.equal(
    harness.calls.filter((c) => c.path === INSTANCE_PATH).length,
    2,
    'which takes a second identity call, not a cached answer'
  );
});

test('AC4: an identity answer that arrives after a reset settles nothing', async () => {
  // The generation guard, for the same reason Session has one: a call already on the wire
  // when the user signed out must not land the previous principal's verdict on the next.
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const harness = withInstance(async () => {
    await gate;
    return response(200, identityBody(2));
  });
  await harness.ready();

  const inFlight = harness.instance.verify();
  harness.instance.reset();
  release();
  await inFlight;

  assert.equal(harness.instance.status(), 'checking', 'the late answer is discarded');
  assert.equal(harness.instance.adminApiVersion(), 0, 'and none of its fields are kept');
});

// --- The Angular layer's wiring, read out of its own source --------------------------------
//
// `app.ts` and `main.ts` have no component runner until Story 1.9 (DW-93), and both carry
// decisions nothing else in the suite can see: the gate that withholds `<router-outlet />`
// from an unauthenticated user, and the composition root that starts the probe and reaches
// the browser through the two guarded readers. Reading the source is weaker than rendering
// and it is not nothing -- each of these is a single line whose removal type-checks, builds
// clean, and leaves every other test green.

const appRoot = join(dirname(fileURLToPath(import.meta.url)), '..', 'src');

/**
 * The two gates in `app.ts` nest, so the branches are found by counting braces rather than
 * by a non-greedy regex, which stops at the first `}` it meets -- inside the inner block --
 * and silently reports the wrong branch as the outer one. Interpolations are blanked first
 * because `{{ ... }}` carries braces of its own.
 */
function appTemplateBranches() {
  const source = readFileSync(join(appRoot, 'app', 'app.ts'), 'utf8');
  const match = /template:\s*`([\s\S]*?)`,\n\}\)/.exec(source);
  assert.ok(match, 'app.ts must carry one inline template: `...` block');
  const template = match[1].replace(/\{\{[\s\S]*?\}\}/g, (m) => ' '.repeat(m.length));

  const matchingBrace = (text, openIndex) => {
    let depth = 0;
    for (let i = openIndex; i < text.length; i += 1) {
      if (text[i] === '{') depth += 1;
      else if (text[i] === '}') {
        depth -= 1;
        if (depth === 0) return i;
      }
    }
    return -1;
  };

  const branchesOf = (text, condition) => {
    const header = new RegExp(`@if\\s*\\(\\s*${condition}\\s*\\)\\s*\\{`).exec(text);
    assert.ok(header, `expected an @if (${condition}) block`);
    const open = text.indexOf('{', header.index);
    const close = matchingBrace(text, open);
    assert.ok(close > open, `the @if (${condition}) block must be balanced`);
    const rest = text.slice(close + 1);
    assert.match(rest, /^\s*@else\s*\{/, `@if (${condition}) must carry an @else`);
    const elseOpen = close + 1 + rest.indexOf('{');
    const elseClose = matchingBrace(text, elseOpen);
    assert.ok(elseClose > elseOpen, `the @else for ${condition} must be balanced`);
    return {
      then: text.slice(open + 1, close),
      otherwise: text.slice(elseOpen + 1, elseClose),
    };
  };

  const session = branchesOf(template, 'signedIn');
  return { source, session, instance: branchesOf(session.then, 'instanceReady') };
}

test('Integration AC: app.ts withholds the routed outlet from every state but signed-in', () => {
  const { source, session } = appTemplateBranches();

  assert.match(
    session.then,
    /<router-outlet\s*\/>/,
    'the signed-in branch is where the routed screen can render'
  );
  assert.ok(
    !/<router-outlet/.test(session.otherwise),
    'and the other branch must NOT -- every other state renders sign-in'
  );
  assert.match(session.otherwise, /<app-sign-in\s*\/>/);
  assert.match(
    source,
    /isSignedIn\(this\.sessionState\(\)\)/,
    'the gate reads the shared rule rather than restating it'
  );

  // Integration AC, the sign-out half. Story 1.10 moved the account menu into the status bar
  // it was always drawn for, so what the signed-in branch has to carry is that band; the menu
  // is mounted by `status-bar.ts` and by nothing else, which is what keeps "the user segment
  // is the band's only interactive element" true and keeps Sign out reachable exactly while
  // the frame is.
  assert.match(
    session.then,
    /<app-status-bar\s*\/>/,
    'a signed-in tab must be able to reach Sign out, which now lives in the status bar'
  );
  assert.ok(
    !/<app-status-bar/.test(session.otherwise),
    'and a tab that is not signed in must not carry the band that holds it'
  );
  assert.ok(
    !/<app-account-menu/.test(source),
    'app.ts no longer mounts the menu itself -- two mounts would be two triggers with one id'
  );
  assert.match(
    readFileSync(join(appRoot, 'app', 'shell', 'status-bar.ts'), 'utf8'),
    /<app-account-menu\s*\/>/,
    'the status bar is what mounts it'
  );
});

test('Integration AC: app.ts renders the instance notice and withholds the outlet on anything but ready', () => {
  const { source, session, instance } = appTemplateBranches();

  assert.match(
    instance.then,
    /<router-outlet\s*\/>/,
    'the routed screen renders only when the instance is ready'
  );
  assert.ok(
    !/<app-instance-notice/.test(instance.then),
    'and the notice does not render beside it'
  );
  assert.match(
    instance.otherwise,
    /<app-instance-notice\s*\/>/,
    'every other instance state renders the blocking notice'
  );
  assert.ok(
    !/<router-outlet/.test(instance.otherwise),
    'and withholds the routed screen -- no area screen loads on a mismatch'
  );

  // The status bar is inside the ready branch, because it is part of the frame. A user held
  // behind either blocking notice therefore reaches Sign out through the notice's own button
  // rather than through the band -- which is what `instance-notice.ts` renders for exactly
  // the no-privileges variant, whose only exit it is.
  assert.match(
    instance.then,
    /<app-status-bar\s*\/>/,
    'the frame carries the status bar'
  );
  assert.ok(
    !/<app-status-bar/.test(instance.otherwise),
    'and the blocking notice renders without the frame around it'
  );
  assert.match(
    readFileSync(join(appRoot, 'app', 'shell', 'instance-notice.ts'), 'utf8'),
    /this\.session\.signOut\(\)/,
    'so the notice must carry its own way out'
  );

  // The bands are in the order EXPERIENCE.md `:581` reads them, which is also the Tab order:
  // header, then the row holding the rail, the side bar and the content column, then the
  // status bar. Asserted on the source order because that IS the DOM order -- no `tabindex`
  // above 0 exists anywhere in the client to reorder it.
  const bands = [...instance.then.matchAll(/<app-(header|rail|side-bar|locator-bar|command-bar|status-bar)\s*\/>/g)].map(
    (m) => m[1]
  );
  assert.deepEqual(bands, [
    'header',
    'rail',
    'side-bar',
    'locator-bar',
    'command-bar',
    'status-bar',
  ]);

  assert.match(
    source,
    /isInstanceReady\(this\.instanceStatus\(\)\)/,
    "the gate reads the service's own predicate, which is asserted over every status above"
  );
  assert.match(
    source,
    /void this\.instance\.verify\(\)/,
    'and something has to make the call, or the notice renders forever'
  );

  // The other half of AD-8's "resolved in the calling process, never cached". `reset()` is
  // what ends the previous principal's claim on the verdict, and `App` is its only caller
  // in the whole client -- the two AC4 tests above call it themselves, so deleting this
  // line from app.ts type-checks, builds clean and leaves every one of them green while a
  // second principal signing in to the same tab inherits the first one's answer.
  assert.match(
    source,
    /this\.instance\.reset\(\)/,
    'and the verdict is dropped when the session leaves signed-in, or the next principal inherits it'
  );

  // The navigation map is the same kind of answer and has the same two callers, neither of
  // which any component spec reaches -- no spec renders `App`. Deleting either line
  // type-checks, builds clean and leaves all 305 tests green: without the load the map is
  // never fetched and every entry falls back to UNGATED, so a user who may reach almost
  // nothing sees a fully open rail; without the reset the next principal in the tab inherits
  // the last one's gating (AD-8).
  assert.match(
    source,
    /void this\.navigation\.load\(\)/,
    'something has to fetch the navigation map, or every gate falls back to ungated'
  );
  assert.match(
    source,
    /this\.navigation\.reset\(\)/,
    'and the map is dropped when the session leaves signed-in, or the next principal inherits it'
  );
});

// --- The account menu, read out of its own source ---------------------------------------------
//
// Same technique and same limit as the sign-in template read above: `account-menu.ts` has
// no component runner until Story 1.9 (DW-93), and every assertion below is a single
// attribute or call whose removal type-checks, builds clean and leaves every other test
// green -- the menu would still open and still look right while being unreachable by
// keyboard, unlabelled, or wired to nothing at all.

const accountMenuSource = readFileSync(
  join(appRoot, 'app', 'shell', 'account-menu.ts'),
  'utf8'
);

const accountMenuTemplate = (() => {
  const match = /template:\s*`([\s\S]*?)`,\n\}\)/.exec(accountMenuSource);
  assert.ok(match, 'account-menu.ts must carry one inline template: `...` block');
  return match[1];
})();

test('the account menu item is Sign out, from the string source, and it calls signOut()', () => {
  const item = /<button([^>]*)>\s*\{\{\s*STRINGS\.actionSignOut\s*\}\}/.exec(accountMenuTemplate);
  assert.ok(item, 'the menu must render STRINGS.actionSignOut -- no new string is introduced');
  assert.match(item[1], /\brole="menuitem"/, 'as a menu item');
  assert.match(
    item[1],
    /\(click\)="chooseSignOut\(\)"/,
    'choosing it must reach the session, not merely close the menu'
  );
  assert.match(
    accountMenuSource,
    /this\.session\.signOut\(\)/,
    'and chooseSignOut() is what calls Session.signOut()'
  );
});

test('the trigger announces the menu it opens, and the glyph beside it is decoration', () => {
  const trigger = /<button([\s\S]*?)>/.exec(accountMenuTemplate);
  assert.ok(trigger, 'the menu must have a trigger button');
  assert.match(trigger[1], /\baria-haspopup="menu"/, 'it announces that it opens a menu');
  assert.match(
    trigger[1],
    /\[attr\.aria-expanded\]="open"/,
    'and whether the menu is open right now -- a static value would be a lie half the time'
  );

  const panel = /<div([^>]*\brole="menu"[^>]*)>/.exec(accountMenuTemplate);
  assert.ok(panel, 'the panel is a role="menu"');
  const labelledBy = /\baria-labelledby="([^"]*)"/.exec(panel[1]);
  assert.ok(labelledBy, 'labelled by the trigger, which needs no new string');
  assert.ok(
    accountMenuTemplate.includes(`id="${labelledBy[1]}"`),
    `aria-labelledby names ${labelledBy[1]}, which no element in this template carries`
  );

  // The trigger's whole accessible name is the user name, so the interpolation that renders
  // it is load-bearing: delete that span and the button's only content is the aria-hidden
  // caret, leaving a control with no accessible name at all -- and every other assertion
  // here, the type-check and the build all stay green.
  const triggerElement = /<button\b[\s\S]*?<\/button>/.exec(accountMenuTemplate);
  assert.ok(triggerElement, 'the trigger button must be a complete element');
  assert.match(
    triggerElement[0],
    /\{\{\s*userName\(\)\s*\}\}/,
    'the trigger renders the signed-in user name, which is its accessible name'
  );

  const caret = /<span([^>]*)>\s*\{\{\s*caretGlyph\s*\}\}/.exec(accountMenuTemplate);
  assert.ok(caret, 'the caret is interpolated from TypeScript, never typed into the template');
  assert.match(
    caret[1],
    /\baria-hidden="true"/,
    'so the accessible name is the user name alone'
  );
  assert.match(
    accountMenuSource,
    /caretGlyph = '\\u25BE'/,
    'and the glyph is an escape, never a literal non-ASCII byte (Rule 14)'
  );
});

test('the trigger is what opens the menu, and opening moves focus into it', () => {
  // The story's whole Intent is that something reaches signOut(). Nothing above pins the
  // one binding that makes the panel appear: delete `(click)="toggle()"` and the type-check
  // passes, the build is clean, every other account-menu assertion still matches, and Sign
  // out is unreachable. The focus move is in the same position.
  const trigger = /<button([\s\S]*?)>/.exec(accountMenuTemplate);
  assert.ok(trigger, 'the menu must have a trigger button');
  assert.match(
    trigger[1],
    /\(click\)="toggle\(\)"/,
    'activating the trigger is the only way the panel is ever rendered'
  );
  assert.match(
    accountMenuTemplate,
    /@if \(open\) \{/,
    'and the panel is gated on the flag toggle() sets'
  );
  assert.match(
    accountMenuTemplate,
    /#firstItem\b/,
    'the item carries the view-query reference the focus move reads'
  );
  assert.match(
    accountMenuSource,
    /this\.firstItemEl\(\)\?\.nativeElement\.focus\(\)/,
    'and opening moves focus to it -- a role="menu" that never takes focus is one in name only'
  );
});

test('Escape reaches the account menu through the overlay stack, and returns focus to the trigger', () => {
  // Story 1.10 moved Escape to one authority (DW-137). A local `(keydown.escape)` binding as
  // well would close the menu AND let the same key press reach the side bar underneath, so
  // its absence is the assertion, not an omission.
  assert.ok(
    !/keydown\.escape/.test(accountMenuTemplate),
    'no local Escape binding -- one key press must close one thing'
  );
  assert.match(
    accountMenuSource,
    /this\.overlays\.push\(ACCOUNT_MENU_OVERLAY_ID, \(\) => this\.closeAndRefocus\(\)\)/,
    'opening registers with the stack, and closeAndRefocus is what Escape runs'
  );
  const body = /closeAndRefocus\(\): void \{([\s\S]*?)\n {2}\}/.exec(accountMenuSource);
  assert.ok(body, 'closeAndRefocus must exist');
  const focusAt = body[1].indexOf('nativeElement.focus()');
  const closeAt = body[1].indexOf('this.openFlag.set(false)');
  assert.ok(focusAt >= 0, 'it must move focus back to the trigger');
  assert.ok(closeAt >= 0, 'and close the menu');
  assert.ok(
    focusAt < closeAt,
    'focus moves BEFORE the item is removed -- removing a control while it holds focus is banned'
  );
});

// --- The instance notice, read out of its own source ------------------------------------------
//
// Same technique and same limit as the two template reads above: `instance-notice.ts` has no
// component runner until Story 1.9 (DW-93). What it buys is the one property no executed test
// covers -- that the two variants are siblings, each carrying only its own words, so neither
// can ever render the other's.

const instanceNoticeSource = readFileSync(
  join(appRoot, 'app', 'shell', 'instance-notice.ts'),
  'utf8'
);

const instanceNoticeTemplate = (() => {
  const match = /template:\s*`([\s\S]*?)`,\n\}\)/.exec(instanceNoticeSource);
  assert.ok(match, 'instance-notice.ts must carry one inline template: `...` block');
  return match[1];
})();

/** The body of the `@if (<condition>)` block, by brace count (interpolations blanked first). */
function noticeVariant(condition) {
  const blanked = instanceNoticeTemplate.replace(/\{\{[\s\S]*?\}\}/g, (m) => ' '.repeat(m.length));
  const header = new RegExp(`@if\\s*\\(\\s*${condition}\\s*\\)\\s*\\{`).exec(blanked);
  assert.ok(header, `the notice must carry an @if (${condition}) variant`);
  const open = blanked.indexOf('{', header.index);
  let depth = 0;
  for (let i = open; i < blanked.length; i += 1) {
    if (blanked[i] === '{') depth += 1;
    else if (blanked[i] === '}') {
      depth -= 1;
      if (depth === 0) return instanceNoticeTemplate.slice(open + 1, i);
    }
  }
  assert.fail(`the @if (${condition}) block is unbalanced`);
  return '';
}

test('AC4: the two notice variants are siblings, and neither carries the other\'s words', () => {
  const mismatch = noticeVariant('mismatch');
  const noPrivileges = noticeVariant('noPrivileges');

  assert.ok(!mismatch.includes('@if'), 'the mismatch variant is not nested inside another condition');
  assert.ok(
    !noPrivileges.includes('@if'),
    'nor is the no-privileges one -- nesting would make one unreachable'
  );

  assert.match(mismatch, /\{\{\s*mismatchMessage\(\)\s*\}\}/, 'the mismatch variant names the version');
  assert.ok(
    !/STRINGS\.authNoAdminPrivileges/.test(mismatch),
    'and never says "no administrative privileges" -- EXPERIENCE.md :429 forbids exactly that'
  );

  assert.match(noPrivileges, /\{\{\s*STRINGS\.authNoAdminPrivileges\s*\}\}/);
  assert.ok(
    !/mismatchMessage/.test(noPrivileges),
    'and never names a version, which would dress a privilege problem as a mismatch'
  );

  assert.match(
    instanceNoticeSource,
    /this\.instanceStatus\(\) === 'version-mismatch'/,
    'the mismatch variant is gated on the mismatch status and no other'
  );
  assert.match(
    instanceNoticeSource,
    /this\.instanceStatus\(\) === 'no-privileges'/,
    'and the no-privileges variant on its own'
  );
});

test('AC3: the mismatch variant offers the classic portal, and BOTH variants offer Sign out', () => {
  const mismatch = noticeVariant('mismatch');
  const noPrivileges = noticeVariant('noPrivileges');

  const link = /<a([\s\S]*?)>/.exec(mismatch);
  assert.ok(link, 'the mismatch variant must carry a link out (AD-44)');
  assert.match(link[1], /class="ocu-button-secondary"/, 'as DESIGN.md :1066 draws it');
  assert.match(mismatch, /\{\{\s*STRINGS\.classicLinkCardTitle\s*\}\}/, 'reading an existing string');
  assert.match(
    instanceNoticeSource,
    /CLASSIC_PORTAL_HREF = '\/csp\/sys\//,
    'and pointing at the classic portal'
  );

  // Sign out is the section's, not one variant's. Story 1.10 put the account menu inside the
  // status bar, which renders only once the instance is `ready`, so this notice is the only
  // exit a held user has -- in BOTH variants. Asserting it on the whole template and denying
  // it inside each variant body is what makes "both" the falsifiable claim: moving the button
  // back into either `@if` turns this red.
  const button = /<button([^>]*)>\s*\{\{\s*STRINGS\.actionSignOut\s*\}\}/.exec(
    instanceNoticeTemplate
  );
  assert.ok(button, 'the notice must offer Sign out');
  assert.match(button[1], /class="ocu-button-text"/, 'as DESIGN.md :1066 draws it');
  assert.match(button[1], /\(click\)="chooseSignOut\(\)"/, 'and it must reach the session');
  assert.ok(
    !/STRINGS\.actionSignOut/.test(mismatch) && !/STRINGS\.actionSignOut/.test(noPrivileges),
    'and it must sit outside both variants, so a version-mismatched tab is not stranded signed in'
  );
  assert.match(
    instanceNoticeSource,
    /this\.session\.signOut\(\)/,
    'through the same signOut() the account menu calls'
  );
});

test('an unsettled check still reaches Sign out: the section is behind no condition at all', () => {
  // app.ts renders <app-instance-notice /> for every instance state but `ready`, which is
  // THREE states: `checking` reaches this component too, and it is not only the transient
  // opening state -- InstanceService.runVerify()'s final branch settles nothing for any
  // failure the shell cannot explain, and nothing retries (DW-119). Both variants are false
  // there, so gating the whole composition on "a variant has something to say" left that tab
  // signed in on an empty page with no exit, the same AD-28 break the version-mismatch fix
  // closed one state over. The variants' sentences stay conditional; the section and its
  // Sign out do not.
  assert.ok(
    !/hasNotice/.test(instanceNoticeSource),
    'no condition gates the composition, so every non-ready state renders the exit'
  );
  assert.match(
    instanceNoticeTemplate,
    /^\s*<section class="ocu-empty-state">/,
    'the section is the template\'s own first element'
  );
  // Falsifiable against the shape that caused the break: the Sign out button must not sit
  // inside any @if, so no instance state can render the section without it.
  const beforeButton = instanceNoticeTemplate.slice(
    0,
    instanceNoticeTemplate.indexOf('STRINGS.actionSignOut')
  );
  const opened = (beforeButton.match(/@if\s*\(/g) ?? []).length;
  const closed = (beforeButton.match(/\n\s*\}/g) ?? []).length;
  assert.equal(opened, closed, 'and it sits at section level, inside no @if block');
});

test('the version in the mismatch sentence is substituted in TypeScript, never typed into the template', () => {
  assert.ok(
    !instanceNoticeTemplate.includes('version'),
    'no part of the sentence is spelled in the template'
  );
  assert.match(
    instanceNoticeSource,
    /formatVersionMismatch\(\s*STRINGS\.authAdminApiVersionMismatch,\s*this\.reportedVersion\(\)\s*\)/,
    'the component delegates to the formatter asserted over real values above, and spells no substitution of its own'
  );
  assert.ok(
    !/\.replace\(/.test(instanceNoticeSource),
    'so there is no second, unexecuted copy of the substitution rule in the component'
  );
});

test('main.ts starts the probe at bootstrap and provides the instance service the shell gates on', () => {
  const source = readFileSync(join(appRoot, 'main.ts'), 'utf8');

  assert.match(
    source,
    /\{\s*provide:\s*InstanceService,\s*useValue:\s*instance\s*\}/,
    'without this provider the root component cannot inject the gate and the shell will not bootstrap'
  );

  assert.match(
    source,
    /storage:\s*readSessionStorage\(\)/,
    'a bare `sessionStorage` here throws where site data is blocked, aborting the bootstrap'
  );
  assert.match(
    source,
    /navigationType:\s*readNavigationKind/,
    'DW-6 decides on the navigation kind, so the real reader has to be wired to it'
  );
  assert.match(
    source,
    /^\s*session\.start\(\);\s*$/m,
    'without this the shell renders the form forever and never probes (AC1)'
  );

  // DW-9's only edge in the running product: `ApiService` reports a 403 and the navigation
  // map re-reads itself. Both halves are tested in isolation in navigation.test.mjs -- that
  // file builds its own ApiService and calls noteForbidden() itself -- so deleting this one
  // line leaves every test green while a role revoked mid-session is never noticed.
  assert.match(
    source,
    /onForbidden:\s*\(\)\s*=>\s*navigation\.noteForbidden\(\)/,
    'without this a 403 never re-reads the map and stale gating survives until a full reload (DW-9)'
  );
  assert.match(
    source,
    /\{\s*provide:\s*NavigationService,\s*useValue:\s*navigation\s*\}/,
    'without this provider the rail, side bar and routed outlet cannot inject the map'
  );
  // Nothing type-checks the DI graph -- no class in ui/src carries an @Injectable decorator --
  // and every component spec supplies its own ShellState, so deleting the bootstrap's provider
  // builds clean, keeps the suite green, and throws NullInjectorError in every signed-in
  // browser the first time <app-rail /> renders: a blank shell behind a successful sign-in.
  assert.match(
    source,
    /\{\s*provide:\s*ShellState,\s*useValue:\s*shell\s*\}/,
    'without this provider the rail, side bar and routed outlet fail to construct at all'
  );
  assert.match(
    source,
    /\{\s*provide:\s*PreferenceStore,\s*useValue:\s*preferences\s*\}/,
    "without this the side bar's remembered open state has no store behind it"
  );
  // The same guard for the one root service Story 1.10 added. Every component spec supplies
  // its own OverlayStack -- app.spec.ts included -- so without this clause the bootstrap
  // provider can be deleted with a clean build and a green suite, and every signed-in browser
  // throws NullInjectorError out of the root component's Escape handler.
  assert.match(
    source,
    /\{\s*provide:\s*OverlayStack,\s*useValue:\s*overlays\s*\}/,
    'without this provider Escape throws out of the root component and the shell never renders'
  );
  // Story 1.11's three lines, the same guard for the same reason. Each half is tested in
  // isolation -- api.test.mjs passes its own `scope` option, scope.test.mjs subscribes its own
  // listener, namespace-switch.spec.ts provides its own ScopeService -- so each of these can be
  // deleted with a clean build and a green suite while the running shell loses the feature.
  assert.match(
    source,
    /scope:\s*\(\)\s*=>\s*scope\.namespace\(\)/,
    'without this no request the shell makes carries ?ns= and every read runs in the install namespace (AD-44)'
  );
  assert.match(
    source,
    /onScopeChange\(\s*scope,/,
    'without this a namespace change never re-reads the navigation map -- the scope switches and nothing re-fetches'
  );
  assert.match(
    source,
    /\{\s*provide:\s*ScopeService,\s*useValue:\s*scope\s*\}/,
    'without this provider <app-namespace-switch /> throws NullInjectorError the first time the header renders'
  );
});
