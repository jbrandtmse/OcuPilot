import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, relative, sep } from 'node:path';

// Pins AD-20 (every API path absolute, refused by the one service) and the credential half
// of AD-28 and AD-47: a Bearer from per-tab storage is the only thing on the wire, and no
// OcuPilot code writes a cookie, persistent storage, a cross-tab channel or a frame message.
//
// The last of those is a property of the SOURCE, not of one call, so it is checked by a scan
// over the whole of ui/src rather than by exercising the service -- an API service that
// behaved perfectly would still be wrong if a screen wrote the token to localStorage.
//
// Mutations (Rule 19):
// - make isOcuPilotApiPath accept a relative path -> the throw tests go red (and the
//   deep-link fallback would answer the request with index.html, which is the silent failure
//   AD-20 exists to prevent).
// - relax it to `path.startsWith('/') && !path.startsWith('//')` -> the backslash and
//   /csp/sys rows go red; both of those reach a destination the Bearer must never see.
// - set `credentials: 'include'` in ApiService.buildInit -> the credential test goes red.
// - add `localStorage.setItem(...)` anywhere under ui/src -> the source scan goes red.

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const corePath = (name) => join(uiRoot, 'src', 'app', 'core', name);

const { ApiService, isOcuPilotApiPath, API_PATH_PREFIX, RELATIVE_PATH_MESSAGE } = await import(
  corePath('api.ts')
);
const { Session, REFRESH_PATH, LOGIN_PATH, API_ROOT, isInstallInFlight } = await import(
  corePath('session.ts')
);
const { TokenStore } = await import(corePath('token-store.ts'));

const NOW_MS = 1_700_000_000_000;

function response(status, body = '') {
  return { status, text: async () => body };
}

function pairBody(access, refresh, expSeconds = NOW_MS / 1000 + 60) {
  return JSON.stringify({
    access_token: access,
    refresh_token: refresh,
    sub: 'ann',
    iat: NOW_MS / 1000,
    exp: expSeconds,
  });
}

function memoryStorage() {
  const map = new Map();
  return {
    getItem: (k) => (map.has(k) ? map.get(k) : null),
    setItem: (k, v) => map.set(k, v),
    removeItem: (k) => map.delete(k),
  };
}

/**
 * A signed-in tab over one shared fetch. `dataHandler(path, init, callIndex)` answers
 * anything that is not a token endpoint.
 */
function signedIn(dataHandler, options = {}) {
  const calls = [];
  let refreshes = 0;
  let logins = 0;
  let accessSerial = 1;
  const tokens = new TokenStore({
    storage: memoryStorage(),
    navigationType: () => 'navigate',
    newNonce: () => 'nonce-api',
  });
  const shared = async (path, init) => {
    if (path === LOGIN_PATH) {
      logins += 1;
      // `probeFails` refuses every probe after the one that signed the tab in, which is
      // what a browser-level login that has genuinely ended looks like.
      if (options.probeFails === true && logins > 1) return response(401, '');
      return response(200, pairBody(`access-${accessSerial}`, `refresh-${accessSerial}`, options.exp));
    }
    if (path === REFRESH_PATH) {
      refreshes += 1;
      accessSerial += 1;
      if (options.refreshFails === true) return response(401, '');
      return response(200, pairBody(`access-${accessSerial}`, `refresh-${accessSerial}`));
    }
    const index = calls.length;
    calls.push({ path, init });
    return dataHandler(path, init, index);
  };
  const session = new Session({ fetch: shared, tokens, now: () => NOW_MS, schedule: () => {} });
  const api = new ApiService({ fetch: shared, tokens, session });
  return {
    api,
    session,
    tokens,
    calls,
    refreshCount: () => refreshes,
    ready: async () => {
      session.start();
      await new Promise((resolve) => setImmediate(resolve));
    },
  };
}

// --- AD-20: absolute paths only ---------------------------------------------------------

test('the guard prefix and the session module agree on where the API lives', () => {
  // api.ts spells the prefix out because node --test's resolver cannot follow a runtime
  // import between these two modules. That duplication is only safe while this holds.
  assert.equal(API_PATH_PREFIX, `${API_ROOT}/`);
  assert.equal(LOGIN_PATH.startsWith(API_PATH_PREFIX), true);
  assert.equal(REFRESH_PATH.startsWith(API_PATH_PREFIX), true);
});

test('isOcuPilotApiPath accepts an API path and refuses everything else', () => {
  assert.equal(isOcuPilotApiPath('/api/ocupilot/info'), true);
  assert.equal(isOcuPilotApiPath('api/ocupilot/info'), false);
  assert.equal(isOcuPilotApiPath('./api/ocupilot/info'), false);
  assert.equal(isOcuPilotApiPath(''), false);
  assert.equal(isOcuPilotApiPath('//evil.example/api'), false, 'protocol-relative leaves the origin');
  assert.equal(isOcuPilotApiPath('https://evil.example/api'), false);
  // `new URL('/\\host/x', origin)` resolves to http://host/x -- the URL parser treats a
  // backslash as a separator, so a single leading slash is not an origin guarantee.
  assert.equal(isOcuPilotApiPath('/\\evil.example/api'), false, 'a backslash also leaves the origin');
  // AC3's last clause: the token pair never reaches the classic portal or a vendor editor.
  assert.equal(isOcuPilotApiPath('/csp/sys/UtilHome.csp'), false);
  assert.equal(isOcuPilotApiPath('/ui/interop/index.html'), false);
  assert.equal(isOcuPilotApiPath('/api/ocupilotx/info'), false, 'the prefix is a path segment');

  // Dot segments: the spelling begins with the API root and the REQUEST-TARGET does not.
  // fetch resolves the path before sending, so each of these arrives at /csp/sys with the
  // Bearer attached unless the guard normalizes the same way the network stack will.
  assert.equal(
    isOcuPilotApiPath('/api/ocupilot/../../csp/sys/UtilHome.csp'),
    false,
    'dot segments resolve out of the API root'
  );
  assert.equal(isOcuPilotApiPath('/api/ocupilot/./../csp/sys/y'), false);
  assert.equal(
    isOcuPilotApiPath('/api/ocupilot/%2E%2E/%2E%2E/csp/sys'),
    false,
    'a percent-encoded dot segment is still a dot segment to the URL parser'
  );
  assert.equal(
    isOcuPilotApiPath('/api/ocupilot/..\\..\\csp/sys/x'),
    false,
    'the parser treats a backslash as a separator, so it climbs too'
  );

  // ...and an entity id that merely CONTAINS encoded separators still resolves inside the
  // root, so the normalization does not refuse the ids AD-13 encodes.
  assert.equal(isOcuPilotApiPath('/api/ocupilot/task/%252F'), true);
  assert.equal(isOcuPilotApiPath('/api/ocupilot/log?since=1'), true);
});

test('the classic portal is refused before any network call, not merely never called', async () => {
  const harness = signedIn(() => response(200, '{}'));
  await harness.ready();

  for (const hostile of [
    '/csp/sys/UtilHome.csp',
    '/\\evil.example/steal',
    '/api/ocupilot/../../csp/sys/UtilHome.csp',
    '/api/ocupilot/%2E%2E/%2E%2E/csp/sys',
    '/api/ocupilot/..\\..\\csp/sys/x',
  ]) {
    await assert.rejects(() => harness.api.request(hostile), /absolute from the origin root/);
  }
  assert.equal(harness.calls.length, 0, 'no Bearer left the API root');
});

test('a relative path throws before any network call is made', async () => {
  const harness = signedIn(() => response(200, '{}'));
  await harness.ready();

  await assert.rejects(
    () => harness.api.request('api/ocupilot/info'),
    (err) => {
      assert.ok(err instanceof Error);
      assert.ok(
        err.message.startsWith(RELATIVE_PATH_MESSAGE),
        `expected the AD-20 message, got: ${err.message}`
      );
      return true;
    }
  );
  assert.equal(harness.calls.length, 0, 'nothing reached the network');
});

// --- AD-28: Bearer only -------------------------------------------------------------------

test('the only credential on the wire is the Bearer from per-tab storage', async () => {
  const harness = signedIn(() => response(200, '{}'));
  await harness.ready();

  await harness.api.request('/api/ocupilot/info');

  const { init } = harness.calls[0];
  assert.equal(init.headers['Authorization'], 'Bearer access-1');
  assert.equal(init.credentials, 'omit', 'no cookie is attached to a data call');
  assert.deepEqual(
    Object.keys(init.headers),
    ['Authorization'],
    'and nothing else is added to the request -- no Cookie, no query credential'
  );
});

test('a caller-supplied method, body and header survive alongside the Bearer', async () => {
  const harness = signedIn(() => response(200, '{}'));
  await harness.ready();

  await harness.api.request('/api/ocupilot/thing', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: '{"a":1}',
  });

  const { init } = harness.calls[0];
  assert.equal(init.method, 'POST');
  assert.equal(init.body, '{"a":1}');
  assert.equal(init.headers['Content-Type'], 'application/json');
  assert.equal(init.headers['Authorization'], 'Bearer access-1');
});

test('a tab holding no pair sends no Authorization header at all, rather than an empty one', async () => {
  const harness = signedIn(() => response(200, '{}'));
  // No `ready()`: the tab was never signed in.
  await harness.api.request('/api/ocupilot/info');

  assert.equal(harness.calls[0].init.headers['Authorization'], undefined);
});

// --- DW-4: refresh and retry ------------------------------------------------------------------

test('a 401 refreshes once and the retry carries the rotated token', async () => {
  let attempts = 0;
  const harness = signedIn(() => {
    attempts += 1;
    return attempts === 1 ? response(401, '') : response(200, '{}');
  });
  await harness.ready();

  const result = await harness.api.request('/api/ocupilot/info');

  assert.equal(result.status, 200);
  assert.equal(harness.refreshCount(), 1, 'exactly one refresh');
  assert.equal(harness.calls.length, 2, 'one attempt and one retry');
  assert.equal(harness.calls[0].init.headers['Authorization'], 'Bearer access-1');
  assert.equal(
    harness.calls[1].init.headers['Authorization'],
    'Bearer access-2',
    'the retry presents the token the refresh issued, never the one it killed'
  );
});

test('a 401 that the refresh fixes is answered on the retry', async () => {
  let attempts = 0;
  const harness = signedIn(() => {
    attempts += 1;
    return attempts === 1 ? response(401, '') : response(200, '{"ok":true}');
  });
  await harness.ready();

  const result = await harness.api.request('/api/ocupilot/info');

  assert.equal(result.status, 200);
  assert.equal(harness.refreshCount(), 1);
  assert.equal(harness.calls.length, 2);
});

test('a second 401 after the retry is returned as it is, never refreshed again', async () => {
  const harness = signedIn(() => response(401, ''));
  await harness.ready();

  const result = await harness.api.request('/api/ocupilot/info');

  assert.equal(result.status, 401);
  assert.equal(harness.refreshCount(), 1, 'refreshing again would be a loop');
  assert.equal(harness.calls.length, 2);
});

test('a refresh refused by the instance still retries when the silent probe rescues it', async () => {
  // EXPERIENCE.md :571 -- a browser-level login that is still good mints a fresh pair, so
  // the call completes and the user sees nothing.
  let attempts = 0;
  const harness = signedIn(
    () => {
      attempts += 1;
      return attempts === 1 ? response(401, '') : response(200, '{}');
    },
    { refreshFails: true }
  );
  await harness.ready();

  const result = await harness.api.request('/api/ocupilot/info');

  assert.equal(result.status, 200);
  assert.equal(harness.calls.length, 2, 'the call is retried on the pair the probe minted');
  assert.equal(harness.session.state(), 'signed-in');
});

test('a refresh the silent probe cannot rescue returns the original 401 and ends the session', async () => {
  const harness = signedIn(() => response(401, ''), { refreshFails: true, probeFails: true });
  await harness.ready();

  const result = await harness.api.request('/api/ocupilot/info');

  assert.equal(result.status, 401);
  assert.equal(harness.calls.length, 1, 'there is nothing to retry with');
  assert.equal(harness.session.state(), 'session-ended');
});

test('an already-expired pair is renewed before the request, not after a wasted 401', async () => {
  const harness = signedIn(() => response(200, '{}'), { exp: NOW_MS / 1000 - 1 });
  await harness.ready();

  await harness.api.request('/api/ocupilot/info');

  assert.equal(harness.refreshCount(), 1);
  assert.equal(harness.calls.length, 1, 'one data call, not a 401 and a retry');
  assert.equal(harness.calls[0].init.headers['Authorization'], 'Bearer access-2');
});

test('a pre-emptive renewal that fails sends the call once and does not refresh a second time', async () => {
  // The pair is expired, the refresh is refused and the rescue probe is refused too, so
  // by the time the call goes out the session has already ended and the tab holds nothing.
  // The caller is still owed a response -- but the 401 it gets back must NOT re-enter the
  // refresh path, which would start a second probe chain behind a dead session.
  const harness = signedIn(() => response(401, ''), {
    exp: NOW_MS / 1000 - 1,
    refreshFails: true,
    probeFails: true,
  });
  await harness.ready();

  const result = await harness.api.request('/api/ocupilot/info');

  assert.equal(result.status, 401);
  assert.equal(harness.refreshCount(), 1, 'the failed pre-emptive refresh is the only one');
  assert.equal(harness.calls.length, 1, 'and the call is sent once, not retried');
  assert.equal(harness.session.state(), 'session-ended');
});

// --- requestJson: the envelope reader (AD-12, AD-39, DW-101) ---------------------------------
//
// Mutations (Rule 19):
// - have requestJson read `reason` instead of `code` to classify -> the AUTH.NOADMIN row and
//   the install rows go red; the shell would key off text that may be reworded freely.
// - drop the `this.session.noteInstallInFlight(...)` call -> the DW-101 tests go red and an
//   install-in-flight 503 reaches the caller raw.

/** A response whose body can be read exactly once, as `fetch`'s own can. */
function singleRead(status, body = '') {
  let read = false;
  return {
    status,
    text: async () => {
      if (read) throw new Error('body already consumed');
      read = true;
      return body;
    },
  };
}

test('requestJson hands back the parsed body on a 200', async () => {
  const harness = signedIn(() => response(200, '{"adminApiVersion":2,"instanceName":"IRIS"}'));
  await harness.ready();

  const result = await harness.api.requestJson('/api/ocupilot/instance');

  assert.equal(result.kind, 'ok');
  assert.equal(result.status, 200);
  assert.deepEqual(result.body, { adminApiVersion: 2, instanceName: 'IRIS' });
});

test('requestJson reads the body exactly once, because text() is single-read', async () => {
  const harness = signedIn(() => singleRead(200, '{"ok":true}'));
  await harness.ready();

  const result = await harness.api.requestJson('/api/ocupilot/instance');

  assert.equal(result.kind, 'ok', 'a second text() would have rejected and lost the body');
  assert.deepEqual(result.body, { ok: true });
});

test('requestJson reports a failure by its machine code, and carries the reason without keying off it', async () => {
  const harness = signedIn(() =>
    response(403, '{"error":"forbidden","reason":"This account holds no ...","code":"AUTH.NOADMIN"}')
  );
  await harness.ready();

  const result = await harness.api.requestJson('/api/ocupilot/instance');

  assert.equal(result.kind, 'error');
  assert.equal(result.status, 403);
  assert.equal(result.code, 'AUTH.NOADMIN');
  assert.equal(result.reason, 'This account holds no ...');
});

test('requestJson survives a failure whose body is not an envelope at all', async () => {
  const harness = signedIn(() => response(502, '<html>gateway</html>'));
  await harness.ready();

  const result = await harness.api.requestJson('/api/ocupilot/instance');

  assert.equal(result.kind, 'error');
  assert.equal(result.status, 502);
  assert.equal(result.code, null, 'no code is null, never an invented one');
  assert.equal(result.reason, null);
});

test('DW-101: an INSTALL.* 503 is classified installing and the session enters backoff', async () => {
  const harness = signedIn(() =>
    response(503, '{"error":"unavailable","reason":"Install is still running","code":"INSTALL.INSTALLING"}')
  );
  await harness.ready();
  assert.equal(harness.session.state(), 'signed-in');

  const result = await harness.api.requestJson('/api/ocupilot/instance');

  assert.equal(result.kind, 'installing', 'the caller is told installing, never handed the raw 503');
  assert.equal(result.code, 'INSTALL.INSTALLING');
  assert.equal(harness.session.state(), 'installing', 'and the session is backing off');
});

test('DW-101: a 503 whose code is not INSTALL.* is an ordinary error and starts no backoff', async () => {
  const harness = signedIn(() =>
    response(503, '{"error":"unavailable","reason":"Down for maintenance","code":"SERVICE.DOWN"}')
  );
  await harness.ready();

  const result = await harness.api.requestJson('/api/ocupilot/instance');

  assert.equal(result.kind, 'error');
  assert.equal(result.code, 'SERVICE.DOWN');
  assert.equal(harness.session.state(), 'signed-in', 'the tab is not put on the signing-in screen');
});

test('requestJson reports a transport fault as an outcome, never as a rejection', async () => {
  // Callers reach requestJson through `void` (the identity check does), so a rejection here
  // is an unhandled rejection no screen ever hears about. Status 0 is the browser's own
  // spelling for "the request never got an answer".
  const harness = signedIn(() => {
    throw new TypeError('Failed to fetch');
  });
  await harness.ready();

  const result = await harness.api.requestJson('/api/ocupilot/instance');

  assert.equal(result.kind, 'error');
  assert.equal(result.status, 0, 'no status, because nothing answered');
  assert.equal(result.code, null, 'and no envelope to read a code from');
  assert.equal(result.reason, null);
  assert.equal(harness.session.state(), 'signed-in', 'a dropped call is not a sign-out');
});

test("requestJson's classification is isInstallInFlight's, row for row", async () => {
  // api.ts cannot import the predicate at runtime (node --test's resolver needs a file
  // extension; `moduleResolution: "bundler"` refuses one), so it asks the session instead.
  // This is the assertion that the two never drift: the same table, both ways.
  const rows = [
    [503, 'INSTALL.INSTALLING'],
    [503, 'INSTALL.UPGRADEREQUIRED'],
    [503, 'INSTALL.FAILED'],
    [503, 'SERVICE.DOWN'],
    [503, null],
    [500, 'INSTALL.INSTALLING'],
    [403, 'AUTH.NOADMIN'],
  ];

  for (const [status, code] of rows) {
    const body = code === null ? '{"error":"unavailable"}' : JSON.stringify({ code });
    const harness = signedIn(() => response(status, body));
    await harness.ready();

    const result = await harness.api.requestJson('/api/ocupilot/instance');

    assert.equal(
      result.kind === 'installing',
      isInstallInFlight(status, code),
      `row ${status} / ${String(code)} classified as ${result.kind}`
    );
  }
});

// --- The source scan: no other credential channel exists anywhere in the client -------------

const FORBIDDEN = [
  { pattern: /\bdocument\s*\.\s*cookie\b/, why: 'a token must never be written to a cookie (AD-28)' },
  { pattern: /\blocalStorage\b/, why: 'token storage is per tab, never persistent (AD-47)' },
  { pattern: /\bBroadcastChannel\b/, why: 'no cross-tab broadcast of session state (AD-47)' },
  {
    pattern: /addEventListener\s*\(\s*['"]storage['"]/,
    why: 'a storage listener is a cross-tab channel by another name (AD-47)',
  },
  { pattern: /\.postMessage\s*\(/, why: 'a token is never posted into a frame (AD-28, AD-35)' },
];

const SCAN_EXTENSIONS = new Set(['.ts', '.html', '.scss', '.json', '.js', '.mjs']);
const PRUNE = new Set(['node_modules', 'dist', '.angular']);

function walk(dir, onFile) {
  for (const entry of readdirSync(dir)) {
    if (PRUNE.has(entry)) continue;
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) {
      walk(full, onFile);
      continue;
    }
    if (!SCAN_EXTENSIONS.has(entry.slice(entry.lastIndexOf('.')))) continue;
    onFile(full, readFileSync(full, 'utf8'));
  }
}

// Comments are prose: this file's own rule list and token-store.ts's header both NAME the
// forbidden APIs in order to explain why they are forbidden, and failing the build on an
// explanation would leave no way to write one. Same treatment client-lint.mjs applies.
const COMMENT_RE = /\/\*[\s\S]*?\*\/|(?:^|(?<=[\s;{}(]))\/\/[^\n]*/g;

function blankComments(text) {
  return text.replace(COMMENT_RE, (m) => m.replace(/[^\n]/g, ' '));
}

test('no code under ui/src writes a cookie, persistent storage, a cross-tab channel or a frame message', () => {
  const offenders = [];
  walk(join(uiRoot, 'src'), (fullPath, text) => {
    const code = blankComments(text);
    code.split('\n').forEach((line, idx) => {
      for (const { pattern, why } of FORBIDDEN) {
        if (pattern.test(line)) {
          offenders.push(`${relative(uiRoot, fullPath).split(sep).join('/')}:${idx + 1}: ${line.trim()} -- ${why}`);
        }
      }
    });
  });
  assert.deepEqual(offenders, [], `forbidden credential channels found:\n${offenders.join('\n')}`);
});

test('the scan itself catches each forbidden shape on a fixture, and ignores a comment that names one', () => {
  const fixture = [
    "// we never touch document.cookie or localStorage here",
    '/* BroadcastChannel is forbidden */',
    'document.cookie = "x=1";',
    'localStorage.setItem("k", "v");',
    'new BroadcastChannel("ocupilot");',
    "window.addEventListener('storage', handler);",
    'frame.postMessage(token, "*");',
    'const fine = sessionStorage.getItem("k");',
  ].join('\n');

  const code = blankComments(fixture);
  const hits = [];
  code.split('\n').forEach((line, idx) => {
    for (const { pattern } of FORBIDDEN) {
      if (pattern.test(line)) hits.push(idx + 1);
    }
  });
  assert.deepEqual(hits, [3, 4, 5, 6, 7], 'five real violations, and neither comment nor sessionStorage');
});

test('the one place a cookie travels is the token endpoints, and only as credentials:include', async () => {
  // The browser attaches CSPBrowserId itself; no OcuPilot code reads or writes it. This
  // asserts the split: token endpoints include credentials, data calls omit them.
  const harness = signedIn(() => response(200, '{}'));
  await harness.ready();
  await harness.api.request('/api/ocupilot/info');

  assert.equal(harness.calls[0].init.credentials, 'omit');
  const sessionSource = readFileSync(corePath('session.ts'), 'utf8');
  const apiSource = readFileSync(corePath('api.ts'), 'utf8');
  assert.ok(
    /credentials:\s*'include'/.test(sessionSource),
    'the token endpoints must send the browser-level cookie'
  );
  assert.ok(
    !/credentials:\s*'include'/.test(apiSource),
    'and the API service must never send it'
  );
});
