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
  BACKOFF_BASE_MS,
  BACKOFF_MAX_MS,
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

test('a reloaded tab holding a pair skips the probe entirely (DW-6 continuation)', async () => {
  const storage = memoryStorage();
  storage.setItem(
    'ocupilot.token-pair',
    JSON.stringify({ accessToken: 'a9', refreshToken: 'r9', sub: 'ann', iat: 1, exp: 2 })
  );
  storage.setItem('ocupilot.tab-nonce', 'nonce-kept');
  const tokens = new TokenStore({
    storage,
    navigationType: () => 'reload',
    newNonce: () => 'unused',
  });
  const { session, calls } = makeSession(() => response(200, pairBody('a1', 'r1')), { tokens });

  session.start();
  await new Promise((resolve) => setImmediate(resolve));

  assert.equal(session.state(), 'signed-in');
  assert.equal(calls.length, 0, 'a continuing tab already holds its session');
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
  assert.equal(scheduled.length, 3, 'and nothing further is scheduled');
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
