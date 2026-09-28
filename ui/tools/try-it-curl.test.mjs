import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

// Pins the try-it console's Copy as curl (`areas/web-applications/try-it.ts` and its store, Story
// 16.24, AD-57 (5)): the command's exact format, the placeholders at every position the record
// masks, the refusals it shares with Send, POSIX quoting proved by running the command through
// `/bin/sh`, and a store that writes the clipboard and never sends. Needs `/bin/sh`, and `curl` on
// PATH for the one test that runs the command against a loopback server.
//
// Mutations (Rule 19), each reddening the named test:
// - write double quotes in place of single quotes in `shellQuote` -> "each hostile value arrives
//   byte for byte".
// - drop the `refuseRequest` call from `curlCommand` -> "a request the console refuses is refused
//   for copy".
// - have `copyCurl` call the store's `dispatch` -> "the store copies and never sends".

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const tryIt = await import(join(uiRoot, 'src', 'app', 'areas', 'web-applications', 'try-it.ts'));
const { TryItStore } = await import(join(uiRoot, 'src', 'app', 'areas', 'web-applications', 'try-it.store.ts'));
const { MASKED_VALUE } = await import(join(uiRoot, 'src', 'app', 'core', 'proposal-view.ts'));
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const { composeRequest, curlCommand, maskedRecord, sentHeaders, shellQuote } = tryIt;

const ORIGIN = 'http://localhost:52776';
const BEARER = `Authorization: Bearer ${STRINGS.tryItCurlAccessToken}`;
const q = (name) => ({ name, in: 'query', required: false, type: 'string' });
const p = (name) => ({ name, in: 'path', required: true, type: 'string' });
const h = (name) => ({ name, in: 'header', required: false, type: 'string' });
const f = (name) => ({ name, in: 'formData', required: false, type: 'string' });

function composed(basePath, verb, path, parameters, values, body = '', origin = ORIGIN) {
  const result = composeRequest(basePath, { verb, path, parameters }, { parameters: values, body }, origin);
  assert.equal(result.kind, 'ok', JSON.stringify(result));
  return result.request;
}

function command(request) {
  const built = curlCommand(request);
  assert.equal(built.kind, 'ok', JSON.stringify(built));
  return built.command;
}

/** Run `script` through `/bin/sh` on stdin (one argument is capped at 128 KiB on Linux). */
function runShell(script) {
  return new Promise((resolve, reject) => {
    const child = spawn('/bin/sh', [], { stdio: ['pipe', 'pipe', 'pipe'], env: { ...process.env, NO_PROXY: '*', no_proxy: '*' } });
    const out = [];
    const err = [];
    child.stdout.on('data', (chunk) => out.push(chunk));
    child.stderr.on('data', (chunk) => err.push(chunk));
    child.on('error', reject);
    child.on('close', (status) => resolve({ status, stdout: Buffer.concat(out), stderr: Buffer.concat(err).toString('utf8') }));
    child.stdin.end(script);
  });
}

/**
 * The arguments `/bin/sh` hands `curl` for `line`, read through a `curl` function that prints each
 * one NUL-terminated. Anything else the line ran would print outside them and fail the parse.
 */
async function argvOf(line) {
  const { status, stdout, stderr } = await runShell(`curl() { for argument in "$@"; do printf '%s\\000' "$argument"; done; }\n${line}\n`);
  assert.equal(status, 0, `the shell ran the command: ${stderr}`);
  assert.equal(stderr, '', 'the shell printed nothing to stderr');
  const parts = stdout.toString('utf8').split('\0');
  assert.equal(parts.pop(), '', 'every byte printed belongs to an argument');
  return parts;
}

/** A fetch that records what it was asked and answers 200. */
function stubFetch() {
  const calls = [];
  const fetch = async (url, init) => {
    calls.push({ url, init });
    return { status: 200, statusText: 'OK', headers: { forEach: () => {} }, arrayBuffer: async () => new ArrayBuffer(0) };
  };
  return { fetch, calls };
}

/** A clipboard that records what it was given and answers `answer`. */
function stubClipboard(answer = true) {
  const written = [];
  return { copyText: async (text) => (written.push(text), answer), written };
}

test('an admin read copies as the one exact line: method, URL and the token placeholder', () => {
  const request = composed('/api/admin', 'get', '/v2/web-apps', [], []);
  assert.equal(command(request), `curl --request 'GET' '${ORIGIN}/api/admin/v2/web-apps' --header '${BEARER}'`);
  assert.equal(STRINGS.tryItCurlAccessToken, '<AccessToken>');
});

test('a write carries its headers in send order, Authorization last, and its body quoted', () => {
  const request = composed('/api/x', 'put', '/y', [h('X-A')], ['1'], '{"n":"it\'s"}');
  assert.equal(
    command(request),
    `curl --request 'PUT' '${ORIGIN}/api/x/y' --header 'X-A: 1' --header 'Content-Type: application/json' --header '${BEARER}' --data-raw '{"n":"it'\\''s"}'`
  );
  assert.deepEqual(sentHeaders(request), [['X-A', '1'], ['Content-Type', 'application/json']]);
});

test('HEAD copies as --head, never --request', () => {
  const line = command(composed('/api/x', 'head', '/y', [], []));
  assert.equal(line, `curl --head '${ORIGIN}/api/x/y' --header '${BEARER}'`);
});

test('a declared Authorization is dropped, as Send drops it: the token placeholder is the only one', () => {
  const line = command(composed('/api/x', 'get', '/y', [h('Authorization'), h('X-Other')], ['Basic abc', 'o1']));
  assert.equal(line, `curl --request 'GET' '${ORIGIN}/api/x/y' --header 'X-Other: o1' --header '${BEARER}'`);
});

test('every secret reads as its name in angle brackets, and neither a typed secret nor the tab\'s token is copied', async () => {
  const request = composed('/api/x', 'post', '/y/{token}', [p('token'), q('apiKey'), q('plain'), h('X-Token')], ['tok1', 'key1', 'p1', 'tok2'], '{"Password":"p","Name":"n"}');
  const argv = await argvOf(command(request));
  assert.equal(argv[2], `${ORIGIN}/api/x/y/<token>?apiKey=<apiKey>&plain=p1`);
  assert.ok(argv.includes('X-Token: <X-Token>'), JSON.stringify(argv));
  assert.equal(argv[argv.length - 1], '{\n  "Password": "<Password>",\n  "Name": "n"\n}');
  const form = composed('/api/x', 'post', '/y', [f('password'), f('user')], ['pw2', 'me']);
  assert.equal(form.curlBody, 'password=<password>&user=me');

  const clipboard = stubClipboard();
  const store = new TryItStore({ fetch: stubFetch().fetch, accessToken: () => 'access-secret-1', copyText: clipboard.copyText });
  await store.copyCurl('1', request);
  await store.copyCurl('2', form);
  const text = clipboard.written.join('\n');
  for (const secret of ['tok1', 'key1', 'tok2', '"p"', 'pw2', 'access-secret-1']) assert.equal(text.includes(secret), false, `${secret} is not copied`);
});

test('a URL with no secret in it is request.url exactly', async () => {
  const request = composed('/api/x', 'get', '/x/../y/{a}', [p('a'), q('q'), q('u')], ["a'b", "O'Brien", '\u00e9\u{1F600}']);
  assert.equal(request.curlUrl, request.url);
  assert.equal(request.url, `${ORIGIN}/api/x/y/a'b?q=O%27Brien&u=%C3%A9%F0%9F%98%80`);
  assert.equal((await argvOf(command(request)))[2], request.url);
});

test('a placeholder is put back only where a secret was: text that looks like one is sent as typed', async () => {
  const request = composed('/api/ocucurl', 'get', '/ocucurl{token}/{v}', [p('token'), p('v'), q('apiKey'), q('note')], ['t', 'ocucurl0ocucurl', 'k', '<apiKey>']);
  assert.equal(request.curlUrl, `${ORIGIN}/api/ocucurl/ocucurl<token>/ocucurl0ocucurl?apiKey=<apiKey>&note=%3CapiKey%3E`);
  const dropped = composed('/api/x', 'get', '/a/{token}/../b', [p('token')], ['t']);
  assert.equal(dropped.curlUrl, dropped.url, 'a segment the parser removes takes its placeholder with it');
});

test('beside a secret, every other path and query value is encoded exactly as request.url encodes it', () => {
  const request = composed('/api/x', 'get', '/y/{token}/{id}', [p('token'), p('id'), q('apiKey'), q('filter')], ['t', 'a/b?c', 'k', 'x&y=1#z']);
  assert.equal(request.url, `${ORIGIN}/api/x/y/t/a%2Fb%3Fc?apiKey=k&filter=x%26y%3D1%23z`);
  assert.equal(request.curlUrl, `${ORIGIN}/api/x/y/<token>/a%2Fb%3Fc?apiKey=<apiKey>&filter=x%26y%3D1%23z`);
});

test('--globoff precedes a URL holding a bracket or a brace, as typed or as the parser encodes it, and is absent otherwise', () => {
  assert.match(command(composed('/api/x[1]', 'get', '/y', [], [])), /^curl --globoff --request 'GET' 'http:\/\/localhost:52776\/api\/x\[1\]\/y'/);
  assert.match(command(composed('/api/x', 'get', '/y', [q('k{0}token')], ['v'])), /^curl --globoff /, 'a placeholder holding a brace');
  // The parser encodes a brace in the path; the base path held one, so the flag is still written.
  const braced = composed('/api/{x}', 'get', '/y', [], []);
  assert.equal(braced.curlUrl, `${ORIGIN}/api/%7Bx%7D/y`);
  assert.match(command(braced), /^curl --globoff --request 'GET' /);
  assert.doesNotMatch(command(composed('/api/x', 'get', '/y', [q('k')], ['v'])), /--globoff/);
});

test('a request the console refuses is refused for copy, with the same verdict', () => {
  assert.deepEqual(curlCommand(composed('/api/admin', 'delete', '/v2/web-app', [], [])), { kind: 'refused', refusal: 'admin-write' });
  assert.deepEqual(curlCommand(composed('/API/OcuPilot', 'get', '/x', [], [])), { kind: 'refused', refusal: 'own-application' });
  const disagreeing = composed('/api/admin', 'delete', '/v2/web-app/{name}', [p('name')], ['..%2F..%2F..%2Fx']);
  assert.deepEqual(curlCommand(disagreeing), { kind: 'refused', refusal: 'admin-write' });
  assert.equal(curlCommand(composed('/api/admin', 'get', '/v2/web-app', [], [])).kind, 'ok', 'a read there is copied');
});

/** The request `argv` describes, as the arguments name it. */
function parseArgv(argv) {
  const request = { method: '', url: '', headers: [], body: null };
  for (let at = 0; at < argv.length; at += 1) {
    const word = argv[at];
    if (word === '--globoff') continue;
    if (word === '--head') request.method = 'HEAD';
    else if (word === '--request') request.method = argv[++at];
    else if (word === '--header') request.headers.push(argv[++at]);
    else if (word === '--data-raw') request.body = argv[++at];
    else request.url = word;
  }
  return request;
}

test('each masked position is the record\'s: the same positions, with <name> where the record shows the mask', async () => {
  const cases = [
    composed('/api/x', 'post', '/y/{token}/{id}', [p('token'), p('id'), q('apiKey'), q('limit'), h('X-Token'), h('X-Trace')], ['t', 'i', 'k', '5', 'h', 'on'], '{"Password":"p","nested":{"secret":"s"},"n":1}'),
    composed('/api/x', 'post', '/y', [f('password'), f('user'), h('Key')], ['p', 'me', 'k']),
    composed('/api/x', 'put', '/y', [q('CredentialName'), q('ReturnRefreshToken')], ['c', 'a'], '["Password"]'),
    composed('/api/x', 'patch', '/y', [], [], 'not json, "Password": "p"'),
  ];
  // The copied placeholders read back as the record's mask; nothing else in the corpus holds `<`.
  const unmask = (text) => text.replace(`Bearer ${STRINGS.tryItCurlAccessToken}`, MASKED_VALUE).replace(/<[^<>]*>/g, MASKED_VALUE);
  for (const request of cases) {
    const copied = parseArgv(await argvOf(command(request)));
    const asRecord = {
      line: `${copied.method} ${unmask(copied.url)}`,
      headers: copied.headers.map(unmask),
      body: copied.body === null ? null : unmask(copied.body),
    };
    assert.deepEqual(asRecord, maskedRecord(request), request.url);
  }
});

// The hostile corpus, authored as escapes (Rule 14): quotes, expansions, escapes, line breaks, shell
// operators, non-ASCII, empty, and 100,000 characters. NUL-free, since no POSIX argument carries one.
const HOSTILE = [
  "'",
  "''",
  '"',
  '$HOME',
  '$(id)',
  '`id`',
  '\\',
  'ends in \\',
  'line\nbreak',
  'carriage\rreturn',
  'tab\there',
  ';&|<>*?~!#',
  '\u00e9',
  '\u{1F600}',
  '',
  "a'b\\c$(id)`x`\n".repeat(10000).slice(0, 100000),
];

test('each hostile value arrives byte for byte in a header, a path, a query and the body, and nothing else runs', async () => {
  assert.equal(HOSTILE[HOSTILE.length - 1].length, 100000);
  for (const value of HOSTILE) {
    const request = composed('/api/x', 'post', '/y/{id}', [p('id'), q('q'), h('X-H')], [value, value, value], value);
    // What the console sends, read off the store's own fetch.
    const { fetch, calls } = stubFetch();
    const store = new TryItStore({ fetch, accessToken: () => 't', copyText: async () => true });
    await store.send('1', request);
    await store.confirm();
    assert.equal(calls.length, 1);
    const { url, init } = calls[0];
    const expected = [
      '--request',
      init.method,
      url,
      ...Object.entries(init.headers)
        .filter(([name]) => name !== 'Authorization')
        .flatMap(([name, header]) => ['--header', `${name}: ${header}`]),
      '--header',
      BEARER,
      ...(init.body === undefined ? [] : ['--data-raw', init.body]),
    ];
    const argv = await argvOf(command(request));
    assert.ok(argv.length === expected.length && argv.every((word, at) => word === expected[at]), `argv for ${JSON.stringify(value.slice(0, 40))}`);
  }
});

test('shellQuote writes one POSIX word: single quotes, each quote inside as \'\\\'\'', () => {
  assert.equal(shellQuote(''), "''");
  assert.equal(shellQuote("it's"), "'it'\\''s'");
  assert.equal(shellQuote('$(id)'), "'$(id)'");
});

test('run by real curl against a loopback server, the command sends the method, URL, headers and body, and --data-raw sends @ as text', async () => {
  const received = [];
  const server = createServer((request, response) => {
    const chunks = [];
    request.on('data', (chunk) => chunks.push(chunk));
    request.on('end', () => {
      received.push({ method: request.method, url: request.url, headers: request.headers, body: Buffer.concat(chunks).toString('utf8') });
      response.end('{"ok":true}');
    });
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    const origin = `http://127.0.0.1:${server.address().port}`;
    const request = composed('/api/x', 'post', '/y/{id}', [p('id'), q('q'), h('X-A')], ['a b', "O'Brien", 'v 1'], '@/etc/passwd', origin);
    const { status, stdout, stderr } = await runShell(`${command(request)}\n`);
    assert.equal(status, 0, `curl on PATH ran the command: ${stderr}`);
    assert.equal(stdout.toString('utf8'), '{"ok":true}');
    assert.equal(received.length, 1);
    const [sent] = received;
    assert.equal(sent.method, 'POST');
    assert.equal(`${origin}${sent.url}`, request.url);
    assert.equal(sent.headers['x-a'], 'v 1');
    assert.equal(sent.headers['content-type'], 'application/json');
    assert.equal(sent.headers.authorization, `Bearer ${STRINGS.tryItCurlAccessToken}`);
    assert.equal(sent.body, '@/etc/passwd', 'the body is the text typed, never a file read');
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

test('the store copies and never sends: the outcome is recorded per console, and a refused copy writes nothing', async () => {
  const { fetch, calls } = stubFetch();
  const clipboard = stubClipboard();
  const store = new TryItStore({ fetch, accessToken: () => 't', copyText: clipboard.copyText });
  const write = composed('/api/mgmnt', 'delete', '/v2/{ns}/{app}', [p('ns'), p('app')], ['USER', 'x']);
  await store.copyCurl('1', write);
  assert.equal(calls.length, 0, 'nothing is sent');
  assert.equal(store.pending(), null, 'a write copied opens no confirmation');
  assert.deepEqual(store.copyOutcome('1'), { copied: true, command: command(write) });
  assert.deepEqual(clipboard.written, [command(write)]);
  assert.equal(store.copyOutcome('2'), null, 'the outcome is per console');

  await store.copyCurl('3', composed('/api/admin', 'delete', '/v2/web-app', [], []));
  await store.copyCurl('3', composed('/api/ocupilot', 'get', '/instance', [], []));
  assert.equal(clipboard.written.length, 1, 'a refused copy never reaches the clipboard');
  assert.equal(store.copyOutcome('3'), null);

  const failing = new TryItStore({ fetch, accessToken: () => 't', copyText: async () => false });
  await failing.copyCurl('1', write);
  assert.deepEqual(failing.copyOutcome('1'), { copied: false, command: command(write) }, 'a failed copy keeps the command to show');
  assert.equal(calls.length, 0);
});

test('a form edit or another document clears the outcome, and a copy the form has moved past never lands', async () => {
  const store = new TryItStore({ fetch: stubFetch().fetch, accessToken: () => 't', copyText: async () => true });
  const request = composed('/api/x', 'get', '/y', [], []);
  await store.copyCurl('1', request);
  store.setValue('1', 0, 'edited');
  assert.equal(store.copyOutcome('1'), null, 'a field edit clears it');
  await store.copyCurl('1', request);
  store.setBody('1', 'edited');
  assert.equal(store.copyOutcome('1'), null, 'a body edit clears it');
  await store.copyCurl('1', request);
  store.reset();
  assert.equal(store.copyOutcome('1'), null, 'another document clears it');

  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const slow = new TryItStore({ fetch: stubFetch().fetch, accessToken: () => 't', copyText: async () => (await gate, true) });
  const copying = slow.copyCurl('1', request);
  slow.setValue('1', 0, 'edited while copying');
  release();
  await copying;
  assert.equal(slow.copyOutcome('1'), null, 'the edit came after the press, so its outcome is dropped');
});

test('a second press empties the status before the clipboard answers, so it is announced again', async () => {
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  let held = false;
  const store = new TryItStore({ fetch: stubFetch().fetch, accessToken: () => 't', copyText: async () => (held ? (await gate, true) : true) });
  const request = composed('/api/x', 'get', '/y', [], []);
  await store.copyCurl('1', request);
  assert.equal(store.copyOutcome('1').copied, true);
  held = true;
  const seen = [];
  store.subscribe(() => seen.push(store.copyOutcome('1')));
  const second = store.copyCurl('1', request);
  assert.deepEqual(seen, [null], 'the listener heard the status empty before the clipboard answered');
  assert.equal(store.copyOutcome('1'), null);
  release();
  await second;
  assert.equal(store.copyOutcome('1').copied, true, 'the second copy lands');
});

test('a request in flight does not block the copy, and the copy does not drop its answer', async () => {
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const calls = [];
  const fetch = async (url, init) => {
    calls.push({ url, init });
    await gate;
    return { status: 200, statusText: 'OK', headers: { forEach: () => {} }, arrayBuffer: async () => new ArrayBuffer(0) };
  };
  const store = new TryItStore({ fetch, accessToken: () => 't', copyText: async () => true });
  const request = composed('/api/x', 'get', '/y', [], []);
  const sent = store.send('1', request);
  assert.equal(store.sending('1'), true);
  await store.copyCurl('1', request);
  assert.equal(store.copyOutcome('1').copied, true);
  release();
  await sent;
  assert.equal(calls.length, 1, 'the copy sent nothing of its own');
  assert.equal(store.answer('1').status, 200, 'the answer in flight still lands');
});
