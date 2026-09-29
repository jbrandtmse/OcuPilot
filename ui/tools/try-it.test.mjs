import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the try-it console's rules (`areas/web-applications/try-it.ts`, Story 16.1, AD-57) and its
// store's sending contract (`try-it.store.ts`): composition from the document alone, the two
// refusals after browser-equivalent resolution, the masked record, text-only rendering, and the
// request the store issues. Needs nothing but the checkout.
//
// Mutations (Rule 19), each reddening the named test:
// - drop the `.`/`..` segment check in `composeRequest` -> "a path parameter of . or .. is refused".
// - remove the own-application arm of `refusal` -> "every spelling of OcuPilot's own applications".
// - remove the admin-write arm of `refusal` -> "a write under /api/admin is refused".
// - skip the percent-decode in `resolveTarget` -> the `%6F` and `%2e` spellings.
// - skip the case fold in `resolveTarget` -> the `/API/OcuPilot` spelling.
// - skip the slash collapse in `resolveTarget` -> the `//api//ocupilot` spelling.
// - skip the trailing-slash drop in `resolveTarget` -> the resolution table (the whole-segment
//   match alone already refuses `/api/admin/`).
// - skip the dot-segment removal after decoding -> the `%2e%2e` and `%2F..%2F` spellings.
// - make `refuseRequest` read only the fully decoded path -> "a path whose readings disagree".
// - stop masking a secret-named query value -> "every secret the request carries reads masked".
// - read a status-0 response as an answer in `TryItStore.dispatch` -> "a redirect answer ... is a
//   redirected outcome".
// - skip the `buildable` check before `fetch` -> "a request the browser would not build".
// - record a rejected fetch as `unsent` -> "a fetch that rejects".
// - read a body that broke off as an empty answer -> "an answer whose body breaks off".
// - drop the outcome reset at the start of a send -> "a new send clears the last outcome".

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const tryIt = await import(join(uiRoot, 'src', 'app', 'areas', 'web-applications', 'try-it.ts'));
const { TryItStore } = await import(join(uiRoot, 'src', 'app', 'areas', 'web-applications', 'try-it.store.ts'));
const { MASKED_VALUE } = await import(join(uiRoot, 'src', 'app', 'core', 'proposal-view.ts'));

const { composeRequest, resolveTarget, refusal, refuseRequest, isSafeVerb, maskedRecord, renderBody, TEXT_CAP_BYTES } = tryIt;

const ORIGIN = 'http://localhost:52776';
const q = (name) => ({ name, in: 'query', required: false, type: 'string' });
const p = (name) => ({ name, in: 'path', required: true, type: 'string' });
const h = (name) => ({ name, in: 'header', required: false, type: 'string' });

function compose(basePath, verb, path, parameters, values, body = '') {
  return composeRequest(basePath, { verb, path, parameters }, { parameters: values, body }, ORIGIN);
}

function composed(...args) {
  const result = compose(...args);
  assert.equal(result.kind, 'ok', JSON.stringify(result));
  return result.request;
}

/** Whether a request to `path` by `verb` on this origin is refused, and how. */
const verdict = (verb, path) => refuseRequest(verb, `${ORIGIN}${path}`);

test('a JWT application GET composes from the document: base path, operation path, verb upper-cased', () => {
  const request = composed('/api/admin', 'get', '/v2/web-apps', [], []);
  assert.equal(request.method, 'GET');
  assert.equal(request.url, `${ORIGIN}/api/admin/v2/web-apps`);
  assert.equal(request.body, null);
  assert.equal(verdict(request.method, '/api/admin/v2/web-apps'), null, 'an admin API read is sent');
});

test('a path parameter fills exactly one segment, encoded; query and header parameters are sent when filled', () => {
  const request = composed('/api/mgmnt', 'get', '/v2/{namespace}/{app}', [p('namespace'), p('app'), q('limit'), h('X-Trace'), q('empty')], ['%SYS', 'a/b c', '5', 'on', '']);
  assert.equal(request.url, `${ORIGIN}/api/mgmnt/v2/%25SYS/a%2Fb%20c?limit=5`);
  assert.deepEqual(request.headers, [['X-Trace', 'on']]);
});

test('a path parameter of . or .. is refused at its field, and nothing is composed', () => {
  assert.deepEqual(compose('/api/mgmnt', 'get', '/v2/{namespace}/x', [q('a'), p('namespace')], ['', '..']), { kind: 'traversal', index: 1 });
  assert.deepEqual(compose('/api/mgmnt', 'get', '/v2/{namespace}/x', [p('namespace')], ['.']), { kind: 'traversal', index: 0 });
  assert.equal(compose('/api/mgmnt', 'get', '/v2/{namespace}/x', [p('namespace')], ['..x']).kind, 'ok', 'a value that is not a dot segment is sent');
});

test('a base path that is not a path on this origin has no address', () => {
  assert.deepEqual(compose('//evil.example', 'get', '/x', [], []), { kind: 'no-address' });
  assert.deepEqual(compose('/\\evil.example', 'get', '/x', [], []), { kind: 'no-address' });
  assert.deepEqual(compose('HS.FHIRServer.MFE.V1', 'get', '/x', [], []), { kind: 'no-address' });
});

test('a body is sent for a verb that takes one, as JSON; form parameters become a URL-encoded body', () => {
  const put = composed('/api/x', 'put', '/y', [], [], '{"a":1}');
  assert.equal(put.body, '{"a":1}');
  assert.deepEqual(put.headers, [['Content-Type', 'application/json']]);
  assert.equal(composed('/api/x', 'get', '/y', [], [], '{"a":1}').body, null, 'a GET sends no body');
  const form = composed('/api/x', 'post', '/y', [{ name: 'user', in: 'formData', required: false, type: 'string' }], ['me']);
  assert.equal(form.body, 'user=me');
  assert.deepEqual(form.headers, [['Content-Type', 'application/x-www-form-urlencoded']]);
});

test('resolveTarget resolves each spelling to the one path the browser and the instance reach', () => {
  const cases = [
    ['/api/ocupilot/x', '/api/ocupilot/x'],
    ['/api/%6Fcupilot/x', '/api/ocupilot/x'],
    ['/api/%252Fx', '/api/x'],
    ['/api/admin/%2e%2e/ocupilot', '/api/ocupilot'],
    ['/api/admin%2F..%2Fx', '/api/x'],
    ['//api///ocupilot//x', '/api/ocupilot/x'],
    ['/api/ocupilot/', '/api/ocupilot'],
    ['/', '/'],
    ['/API/OcuPilot/X', '/api/ocupilot/x'],
    ['/api/%5Cocupilot', '/api/ocupilot'],
  ];
  for (const [spelling, resolved] of cases) assert.equal(resolveTarget(`${ORIGIN}${spelling}`), resolved, spelling);
  assert.equal(resolveTarget('not a url'), null);
});

test('every spelling of OcuPilot\'s own applications is refused, whatever the verb', () => {
  const spellings = (app) => [
    `${app}/x`,
    `${app.toUpperCase()}/x`,
    `${app.replace('ocupilot', 'OcuPilot')}/x`,
    `${app.replace('o', '%6F')}/x`,
    `${app.replace('ocupilot', '%6Fcupilot')}/x`,
    `/api/admin/../..${app}/x`,
    `/api/%2e%2e/%2e%2e${app}/x`,
    `/api%2F..${app}/x`,
    `/api/%252e%252e${app}/x`,
    `/${app}/x`.replace(/\//g, '//'),
    app,
    `${app}/`,
    `${app}\\x`,
  ];
  for (const app of tryIt.OWN_APPLICATIONS) {
    for (const spelling of spellings(app)) {
      for (const verb of ['GET', 'HEAD', 'OPTIONS', 'POST', 'DELETE']) {
        assert.equal(verdict(verb, spelling), 'own-application', `${verb} ${spelling}`);
      }
    }
  }
  assert.equal(verdict('GET', '/api/ocupilotx/x'), null, 'the match is on whole segments');
  assert.equal(verdict('GET', '/ocupilotx'), null);
  assert.equal(verdict('GET', '/api/mgmnt/v2/'), null, 'another application is sent');
});

test('a composed request that resolves under OcuPilot\'s own application is refused, from the document', () => {
  const request = composed('/api/mgmnt', 'get', '/v2/{namespace}/x', [p('namespace')], ['%2e%2e%2F%2e%2e%2Focupilot']);
  assert.equal(refuseRequest(request.method, request.url), 'own-application');
  assert.equal(refusal('GET', null), 'own-application', 'a target that does not resolve is not sent');
  assert.equal(refuseRequest('GET', 'not a url'), 'own-application');
});

test('a path whose readings disagree is refused when any reading lies under a protected application', () => {
  // Fully decoded, each of these leaves the protected prefix; on the wire, decoded once, it is still under it.
  assert.equal(verdict('DELETE', '/api/admin/v2/thing/..%252F..%252F..%252Fx'), 'admin-write');
  assert.equal(verdict('DELETE', '/api/admin%2F..%2Fx'), 'admin-write');
  assert.equal(verdict('GET', '/api/ocupilot/v2/thing/..%252F..%252F..%252F..%252Fx'), 'own-application');
  const typed = composed('/api/admin', 'delete', '/v2/web-app/{name}', [p('name')], ['..%2F..%2F..%2Fx']);
  assert.equal(resolveTarget(typed.url), '/api/x', 'the fully decoded reading alone leaves /api/admin');
  assert.equal(refuseRequest(typed.method, typed.url), 'admin-write');
  assert.equal(verdict('GET', '/api/admin/v2/thing/..%252F..%252F..%252Fx'), null, 'a read there is still sent');
  assert.equal(verdict('DELETE', '/api/mgmnt/v2/..%252Fx'), null, 'a write elsewhere is still confirmed, not refused');
});

test('a write under /api/admin is refused by every spelling, and a read is not', () => {
  const spellings = ['/api/admin/v2/web-app', '/API/Admin/v2/web-app', '/api/%61dmin/v2/web-app', '/api/mgmnt/../admin/v2/web-app', '//api//admin//v2', '/api/admin', '/api/admin/', '/api/admin%2Fv2'];
  for (const spelling of spellings) {
    for (const verb of ['POST', 'PUT', 'PATCH', 'DELETE', 'delete']) {
      assert.equal(verdict(verb, spelling), 'admin-write', `${verb} ${spelling}`);
    }
    for (const verb of ['GET', 'HEAD', 'OPTIONS']) assert.equal(verdict(verb, spelling), null, `${verb} ${spelling}`);
  }
  assert.equal(verdict('DELETE', '/api/adminx/v2'), null, 'the match is on whole segments');
  assert.equal(verdict('DELETE', '/api/mgmnt/v2/x'), null, 'a write elsewhere is confirmed, not refused');
});

test('isSafeVerb: GET, HEAD and OPTIONS, in any case, and nothing else', () => {
  for (const verb of ['GET', 'get', 'Head', 'OPTIONS']) assert.equal(isSafeVerb(verb), true, verb);
  for (const verb of ['POST', 'PUT', 'PATCH', 'DELETE', 'TRACE']) assert.equal(isSafeVerb(verb), false, verb);
});

test('every secret the request carries reads masked in its record and its display URL', () => {
  const request = composed('/api/x', 'post', '/y/{token}', [p('token'), q('apiKey'), q('plain'), h('X-Token'), h('X-Other'), h('Authorization')], ['tok1', 'key1', 'p1', 'tok2', 'o1', 'Basic abc'], '{"Password":"pw1","User":"me","nested":{"secret":"s"}}');
  assert.ok(request.url.includes('tok1') && request.url.includes('apiKey=key1'), 'the real URL carries the values');
  const record = maskedRecord(request);
  const text = [record.line, ...record.headers, record.body].join('\n');
  for (const secret of ['tok1', 'key1', 'tok2', 'pw1', 'Basic abc']) assert.equal(text.includes(secret), false, `${secret} is masked: ${text}`);
  for (const shown of ['p1', 'o1', '"me"', '"secret": "s"']) assert.ok(text.includes(shown), `${shown} is shown: ${text}`);
  assert.ok(record.line.startsWith('POST '));
  assert.ok(record.line.includes(`apiKey=${MASKED_VALUE}`));
  assert.ok(record.headers.includes(`X-Token: ${MASKED_VALUE}`));
  assert.ok(record.headers.includes(`Authorization: ${MASKED_VALUE}`), 'the Authorization the tab fills reads masked');
  assert.ok(record.body.includes(`"Password": "${MASKED_VALUE}"`));
});

test('renderBody: JSON pretty-printed, text decoded to the cap with the cut marked, non-text as a byte count', () => {
  const bytes = (text) => new TextEncoder().encode(text);
  assert.deepEqual(renderBody('application/json; charset=UTF-8', bytes('{"a":[1]}')), { kind: 'json', text: '{\n  "a": [\n    1\n  ]\n}', byteCount: 9, cut: false });
  assert.deepEqual(renderBody('application/json', bytes('<img src=x onerror=alert(1)>')), { kind: 'text', text: '<img src=x onerror=alert(1)>', byteCount: 28, cut: false });
  assert.equal(renderBody('text/html', bytes('<b>x</b>')).text, '<b>x</b>', 'markup is text');
  const long = renderBody('text/plain', new Uint8Array(TEXT_CAP_BYTES + 10).fill(65));
  assert.equal(long.cut, true);
  assert.equal(long.text.length, TEXT_CAP_BYTES);
  assert.equal(TEXT_CAP_BYTES, 262144);
  assert.deepEqual(renderBody('image/png', new Uint8Array(42)), { kind: 'binary', text: '', byteCount: 42, cut: false });
});

/** A fetch that records what it was asked and answers `answer`, or rejects when `answer` is null. */
function stubFetch(answer) {
  const calls = [];
  const fetch = async (url, init) => {
    calls.push({ url, init });
    if (answer === null) throw new TypeError('Failed to fetch');
    return {
      status: answer.status,
      statusText: answer.statusText ?? '',
      headers: { forEach: (callback) => Object.entries(answer.headers ?? {}).forEach(([name, value]) => callback(value, name)) },
      arrayBuffer: async () => new TextEncoder().encode(answer.body ?? '').buffer,
    };
  };
  return { fetch, calls };
}

test('the store sends a safe verb at once: same origin, the tab\'s Bearer, no cookie, no redirect followed', async () => {
  const { fetch, calls } = stubFetch({ status: 200, statusText: 'OK', headers: { 'content-type': 'application/json' }, body: '{"ok":true}' });
  const store = new TryItStore({ fetch, accessToken: () => 'access-1' });
  await store.send('1', composed('/api/admin', 'get', '/v2/web-apps', [], []));
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, `${ORIGIN}/api/admin/v2/web-apps`);
  assert.deepEqual(calls[0].init, { method: 'GET', headers: { Authorization: 'Bearer access-1' }, credentials: 'omit', redirect: 'manual' });
  assert.equal(store.answer('1').status, 200);
  assert.equal(store.answer('1').body.text, '{\n  "ok": true\n}');
  assert.equal(store.record('1').headers.join('\n').includes('access-1'), false, 'the record never holds the token');
});

test('the store holds a write for its confirmation: cancel sends nothing, confirm sends it once', async () => {
  const { fetch, calls } = stubFetch({ status: 204, statusText: 'No Content' });
  const store = new TryItStore({ fetch, accessToken: () => 't' });
  const request = composed('/api/mgmnt', 'delete', '/v2/{ns}/{app}', [p('ns'), p('app')], ['USER', 'x']);
  await store.send('2', request);
  assert.equal(calls.length, 0);
  assert.equal(store.pending().request, request);
  store.cancel();
  assert.equal(store.pending(), null);
  assert.equal(calls.length, 0, 'cancel sends nothing');
  await store.send('2', request);
  await store.confirm();
  await store.confirm();
  assert.equal(calls.length, 1, 'confirm sends once');
  assert.equal(calls[0].init.method, 'DELETE');
});

test('the store refuses at send what refusal refuses, whatever the caller composed', async () => {
  const { fetch, calls } = stubFetch({ status: 200 });
  const store = new TryItStore({ fetch, accessToken: () => 't' });
  await store.send('3', composed('/api/ocupilot', 'get', '/instance', [], []));
  await store.send('3', composed('/api/admin', 'delete', '/v2/web-app', [q('name')], ['/x']));
  assert.equal(store.pending(), null, 'a refused write is not held for a confirmation');
  await store.confirm();
  assert.equal(calls.length, 0);
});

test('a fetch that rejects is a failed outcome, with no status invented', async () => {
  const { fetch, calls } = stubFetch(null);
  const store = new TryItStore({ fetch, accessToken: () => 't' });
  await store.send('4', composed('/api/mgmnt', 'get', '/v2/', [], []));
  assert.equal(calls.length, 1, 'the request was built and handed to fetch');
  assert.equal(store.outcome('4'), 'failed');
  assert.equal(store.answer('4'), null);
  assert.equal(store.sending('4'), false);
});

test('an answer whose body breaks off is a failed outcome: no complete answer came back', async () => {
  const fetch = async () => ({
    status: 201,
    statusText: 'Created',
    headers: { forEach: () => {} },
    arrayBuffer: async () => {
      throw new TypeError('network error');
    },
  });
  const store = new TryItStore({ fetch, accessToken: () => 't' });
  await store.send('9', composed('/api/mgmnt', 'get', '/v2/', [], []));
  assert.equal(store.outcome('9'), 'failed');
  assert.equal(store.answer('9'), null);
});

test('a new send clears the last outcome while it is in flight', async () => {
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  let calls = 0;
  const fetch = async () => {
    calls += 1;
    if (calls === 1) throw new TypeError('Failed to fetch');
    await gate;
    return { status: 200, statusText: 'OK', headers: { forEach: () => {} }, arrayBuffer: async () => new ArrayBuffer(0) };
  };
  const store = new TryItStore({ fetch, accessToken: () => 't' });
  const request = composed('/api/mgmnt', 'get', '/v2/', [], []);
  await store.send('10', request);
  assert.equal(store.outcome('10'), 'failed');
  const second = store.send('10', request);
  assert.equal(store.sending('10'), true);
  assert.equal(store.outcome('10'), null, 'the last outcome is not shown beside a request in flight');
  release();
  await second;
  assert.equal(store.outcome('10'), null);
  assert.equal(store.answer('10').status, 200);
});

test('a request the browser would not build is an unsent outcome, and fetch is never called', async () => {
  const form = (name) => ({ name, in: 'formData', required: false, type: 'string' });
  for (const [label, request] of [
    ['a header value past Latin-1', composed('/api/mgmnt', 'get', '/v2/', [h('X-Name')], ['\u65e5'])],
    ['a header value holding a line break', composed('/api/mgmnt', 'get', '/v2/', [h('X-Name')], ['a\nb'])],
    ['a GET carrying a form body', composed('/api/mgmnt', 'get', '/v2/', [form('name')], ['x'])],
  ]) {
    const { fetch, calls } = stubFetch({ status: 200 });
    const store = new TryItStore({ fetch, accessToken: () => 't' });
    await store.send('8', request);
    assert.equal(calls.length, 0, `${label}: nothing is handed to fetch`);
    assert.equal(store.outcome('8'), 'unsent', label);
    assert.equal(store.answer('8'), null, label);
    assert.notEqual(store.record('8'), null, `${label}: the record still shows what was composed`);
  }
  const { fetch, calls } = stubFetch({ status: 200 });
  const store = new TryItStore({ fetch, accessToken: () => 't' });
  await store.send('8', composed('/api/mgmnt', 'get', '/v2/', [h('X-Name')], ['caf\u00e9']));
  assert.equal(calls.length, 1, 'a Latin-1 header value is built and sent');
  assert.equal(store.outcome('8'), null);
});

test('a secret-named form parameter reads masked in the record body', () => {
  const form = (name) => ({ name, in: 'formData', required: false, type: 'string' });
  const request = composed('/api/x', 'post', '/y', [form('password'), form('user')], ['pw2', 'me']);
  assert.equal(request.body, 'password=pw2&user=me');
  assert.equal(maskedRecord(request).body, `password=${MASKED_VALUE}&user=me`);
});

test('the store sends the tab\'s token as the one Authorization: a declared one is dropped, and with no token none is sent', async () => {
  const request = composed('/api/x', 'get', '/y', [h('Authorization'), h('X-Other')], ['Basic abc', 'o1']);
  const withToken = stubFetch({ status: 200 });
  await new TryItStore({ fetch: withToken.fetch, accessToken: () => 'access-2' }).send('5', request);
  assert.deepEqual(withToken.calls[0].init.headers, { 'X-Other': 'o1', Authorization: 'Bearer access-2' });
  const without = stubFetch({ status: 200 });
  await new TryItStore({ fetch: without.fetch, accessToken: () => '' }).send('5', request);
  assert.deepEqual(without.calls[0].init.headers, { 'X-Other': 'o1' });
});

test('a redirect answer (fetch resolved, redirect: manual) is a redirected outcome, never an answer of status 0', async () => {
  // AD-57 (1) sends `redirect: 'manual'`, so a redirect answers with an opaque response: `fetch`
  // resolves (it does not reject) with `status: 0` and an empty `statusText`.
  const { fetch } = stubFetch({ status: 0, statusText: '', headers: {}, body: '' });
  const store = new TryItStore({ fetch, accessToken: () => 't' });
  await store.send('7', composed('/api/mgmnt', 'get', '/v2/', [], []));
  assert.equal(store.outcome('7'), 'redirected', 'the fetch resolved with status 0');
  assert.equal(store.answer('7'), null, 'no answer, so no status 0 to show');
  assert.notEqual(store.record('7'), null, 'the request was still recorded before the outcome landed');

  const ordinary = stubFetch({ status: 404, statusText: 'Not Found', headers: {}, body: '' });
  const other = new TryItStore({ fetch: ordinary.fetch, accessToken: () => 't' });
  await other.send('7', composed('/api/mgmnt', 'get', '/v2/', [], []));
  assert.equal(other.outcome('7'), null, 'a non-2xx status is an answer');
  assert.equal(other.answer('7').status, 404);
});

test('reset forgets every console, and an answer still in flight does not land', async () => {
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const fetch = async () => {
    await gate;
    return { status: 200, statusText: 'OK', headers: { forEach: () => {} }, arrayBuffer: async () => new ArrayBuffer(0) };
  };
  const store = new TryItStore({ fetch, accessToken: () => 't' });
  store.toggle('6');
  store.setValue('6', 0, 'typed');
  const sent = store.send('6', composed('/api/mgmnt', 'get', '/v2/', [], []));
  assert.equal(store.sending('6'), true);
  store.reset();
  release();
  await sent;
  assert.equal(store.isOpen('6'), false);
  assert.equal(store.value('6', 0), '');
  assert.equal(store.record('6'), null);
  assert.equal(store.answer('6'), null);
  assert.equal(store.sending('6'), false);
});
