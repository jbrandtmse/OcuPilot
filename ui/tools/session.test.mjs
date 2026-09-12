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

// --- Sign-out (the half this story owns; Story 1.7 owns the screen) --------------------------

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
  assert.equal(session.state(), 'form');
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

const signInTemplate = (() => {
  const source = readFileSync(
    join(dirname(fileURLToPath(import.meta.url)), '..', 'src', 'app', 'shell', 'sign-in.ts'),
    'utf8'
  );
  const match = /template:\s*`([\s\S]*?)`,\n\}\)/.exec(source);
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
  assert.equal(session.state(), 'form');

  renewal.run();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(tokens.read(), null, 'the stale timer did not re-mint a pair');
  assert.equal(session.state(), 'form', 'and the sign-out held');
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

// --- The Angular layer's wiring, read out of its own source --------------------------------
//
// `app.ts` and `main.ts` have no component runner until Story 1.9 (DW-93), and both carry
// decisions nothing else in the suite can see: the gate that withholds `<router-outlet />`
// from an unauthenticated user, and the composition root that starts the probe and reaches
// the browser through the two guarded readers. Reading the source is weaker than rendering
// and it is not nothing -- each of these is a single line whose removal type-checks, builds
// clean, and leaves every other test green.

const appRoot = join(dirname(fileURLToPath(import.meta.url)), '..', 'src');

test('Integration AC: app.ts withholds the routed outlet from every state but signed-in', () => {
  const source = readFileSync(join(appRoot, 'app', 'app.ts'), 'utf8');
  const match = /template:\s*`([\s\S]*?)`,\n\}\)/.exec(source);
  assert.ok(match, 'app.ts must carry one inline template: `...` block');
  const template = match[1];

  const gate = /@if\s*\(([^)]*)\)\s*\{([\s\S]*?)\}\s*@else\s*\{([\s\S]*?)\}/.exec(template);
  assert.ok(gate, 'the outlet must sit behind an @if/@else gate');
  assert.match(gate[1], /^\s*signedIn\s*$/, 'and the condition is the session gate');
  assert.match(gate[2], /<router-outlet\s*\/>/, 'the signed-in branch renders the routed screen');
  assert.ok(
    !/<router-outlet/.test(gate[3]),
    'and the other branch must NOT -- every other state renders sign-in'
  );
  assert.match(gate[3], /<app-sign-in\s*\/>/);
  assert.match(
    source,
    /isSignedIn\(this\.sessionState\(\)\)/,
    'the gate reads the shared rule rather than restating it'
  );
});

test('main.ts starts the probe at bootstrap through the two guarded browser readers', () => {
  const source = readFileSync(join(appRoot, 'main.ts'), 'utf8');

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
});
