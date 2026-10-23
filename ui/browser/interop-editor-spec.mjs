/**
 * What every browser spec of an embedded vendor interoperability editor asserts (Story 20.13, AD-63),
 * shared by that story's frame spec and by the specs of the screens that mount the editors
 * (Stories 20.7, 20.8 and 20.10).
 *
 * **The questions are about the real editors.** An editor loaded in a frame is the vendor's own
 * Angular bundle, so what it requests, what it stores and what it says to its host can only be read
 * from a browser. This module arms the observers before the frame loads (`watchEditorTraffic`,
 * `watchPolicyViolations`, `armMessageCounters`), then asks two questions of the result:
 *
 * - `assertSignedInSilently`: the editor signed itself in from the browser-level login with an
 *   empty-body login and no password, in normal mode; it asked for the document its own parameter
 *   names; no request carried a password, either OcuPilot token or a mode flag; no message crossed
 *   in either direction; and the tab's storage and the shell's content-security policy are as they
 *   were (AC1 and AC2).
 * - `assertSignOutEndsEditors`: after Sign out in the account menu no frame remains, no editor key
 *   is left in the tab, and the editor's login, its held access token and its held refresh token
 *   each answer 401 (AC3). `editorSessionControls` shows, before the sign-out, that the same three
 *   requests are answered while signed in, so a 401 afterwards is the sign-out's.
 *
 * **Reading the frame is the test's right, never OcuPilot's.** The shipped client reads nothing in a
 * frame (AD-63 limit 3); this module reads the editor's storage and text through puppeteer only to
 * judge it.
 *
 * Named without the `.browser-spec` suffix, so `npm run test:browser` does not collect it as a spec.
 * It signs in nothing itself: the caller's context comes from `panel-spec.mjs`'s `signedInAt`.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { SHELL_PATH } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { PAIR_STORAGE_KEY } = await import(join(uiRoot, 'src', 'app', 'core', 'token-store.ts'));

/** The editors' own web application, and the application the shell's sign-out posts to. */
export const EDITOR_API = '/api/interop-editors/';
const LOGOUT_PATH = '/api/ocupilot/logout';

/**
 * Each embedded app's storage prefix and the segment its document read uses, both read from its
 * bundle and measured on the instance (Stories 20.13 and 20.8).
 */
export const EDITOR_APPS = {
  'rule-editor': { prefix: 'Rule_Editor', segment: 'rules' },
  'dtl-editor': { prefix: 'DTL_Editor', segment: 'dtl' },
  'bpl-editor': { prefix: 'BPL_Editor', segment: 'bpl' },
  'schema-viewer': { prefix: 'Schema_Viewer', segment: 'schemas' },
  'interop-editor': { prefix: 'Interop-Editors', segment: 'productions' },
};

/** Whether `key` is one a vendor app keeps in the tab: any `EDITOR_APPS` prefix followed by `-`, or a `_Editor-` key of an app this module does not name. */
export function isEditorKey(key) {
  return key.includes('_Editor-') || Object.values(EDITOR_APPS).some(({ prefix }) => key.includes(`${prefix}-`));
}

/** The frame a spec mounts or a screen draws, unless the caller names another. */
export const DEFAULT_FRAME_SELECTOR = 'app-screen-outlet iframe';

const STRINGS = loadStrings();

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/** Poll `read` until `accept` takes its answer, failing with `what` and the last answer on timeout. */
export async function until(read, accept, what, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let last;
  while (Date.now() < deadline) {
    try {
      last = await read();
      if (accept(last)) return last;
    } catch (error) {
      last = `(${error.message})`;
    }
    await sleep(100);
  }
  assert.fail(`${what}: waited ${timeoutMs} ms, last read ${JSON.stringify(last)}`);
}

/** The selector of the frame an editor screen draws. */
export const SCREEN_FRAME_SELECTOR = 'app-interop-editor-frame iframe';

/** The editor screen has answered the list's read: its section is no longer busy and it draws a block. */
export async function answered(page, timeoutMs) {
  await page.waitForFunction(
    () => {
      const section = document.querySelector('app-interop-editor-page section');
      return section !== null && section.getAttribute('aria-busy') === 'false' && section.querySelector('[data-ocu-editor]') !== null;
    },
    { timeout: timeoutMs }
  );
}

/** The screen's frame, as a puppeteer frame, once it is drawn. */
export async function editorFrame(page, timeoutMs) {
  const handle = await page.waitForSelector(SCREEN_FRAME_SELECTOR, { timeout: timeoutMs });
  return handle.contentFrame();
}

/** Wait until the frame's editor shows the signed-in person `username` and `text`, answering the puppeteer frame. */
export async function editorShows(page, username, text, timeoutMs) {
  const frame = await editorFrame(page, timeoutMs);
  await until(() => frame.evaluate(() => document.body.innerText), (body) => body.includes(username) && body.includes(text), `the editor shows ${text}`, timeoutMs);
  return frame;
}

/** Wait until the editor's snackbar holds a sentence `accept` takes, and answer the sentence. */
export async function snackbarWhere(frame, accept, what, timeoutMs) {
  return until(
    () => frame.evaluate(() => Array.from(document.querySelectorAll('.mdc-snackbar__label')).map((node) => node.innerText.trim())),
    (labels) => labels.some(accept),
    what,
    timeoutMs
  ).then((labels) => labels.find(accept));
}

/** The tab's `sessionStorage` keys and OcuPilot's stored pair, exactly as stored. */
export function tabSnapshot(page) {
  return page.evaluate((pairKey) => ({ keys: Object.keys(sessionStorage), pair: sessionStorage.getItem(pairKey) }), PAIR_STORAGE_KEY);
}

/**
 * Record every request to `/ui/interop/` and `/api/interop-editors/` that `page` or a frame in it
 * makes, and every http(s) request a frame in it makes to anywhere else on the instance, so the
 * clauses about what a request carries cover all that an editor sends and not only its own two
 * applications: its origin, method, path, query, post body (`null` when it has none), Authorization header
 * (`''` when it has none) and status (`null` until answered). The returned list grows as requests
 * arrive.
 */
export function watchEditorTraffic(page) {
  const entries = [];
  const byRequest = new Map();
  page.on('request', (request) => {
    const url = new URL(request.url());
    const owned = url.pathname.startsWith('/ui/interop/') || url.pathname.startsWith(EDITOR_API);
    const frame = request.frame();
    const fromFrame = frame !== null && frame !== page.mainFrame() && /^https?:$/.test(url.protocol);
    if (!owned && !fromFrame) return;
    const entry = {
      origin: url.origin,
      method: request.method(),
      path: url.pathname,
      query: url.search,
      body: request.postData() ?? null,
      authorization: request.headers().authorization ?? '',
      status: null,
    };
    entries.push(entry);
    byRequest.set(request, entry);
  });
  page.on('response', (response) => {
    const entry = byRequest.get(response.request());
    if (entry !== undefined) entry.status = response.status();
  });
  return entries;
}

/** Record the console messages of `page` and its frames that report a content-security-policy violation. */
export function watchPolicyViolations(page) {
  const found = [];
  page.on('console', (message) => {
    if (/content security policy/i.test(message.text())) found.push(message.text());
  });
  return found;
}

/**
 * Count the `message` events every window sees, in the shell and in every frame that loads after
 * this call. A listener in each window records into the top window, which the frames share by origin.
 * Answers `{ seen, reset }`: `seen()` lists what was received, `reset()` forgets it.
 */
export async function armMessageCounters(page) {
  const install = () => {
    if (window.__ocuMessageListener === true) return;
    window.__ocuMessageListener = true;
    window.addEventListener(
      'message',
      (event) => {
        const log = (window.top.__ocuMessages = window.top.__ocuMessages ?? []);
        log.push({ in: window.location.pathname, from: event.origin, kind: typeof event.data });
      },
      true
    );
  };
  await page.evaluateOnNewDocument(install);
  await page.evaluate(install);
  return {
    seen: () => page.evaluate(() => window.__ocuMessages ?? []),
    reset: () => page.evaluate(() => (window.__ocuMessages = [])),
  };
}

/** The editor's own access and refresh tokens as held in the tab, or `null` before it has stored both. */
export async function readEditorTokens(page, editor) {
  const { prefix } = EDITOR_APPS[editor];
  return page.evaluate((storagePrefix) => {
    const pick = (suffix) => {
      const key = Object.keys(sessionStorage).find((candidate) => new RegExp(`^${storagePrefix}-\\d+-${suffix}$`).test(candidate));
      return key === undefined ? null : sessionStorage.getItem(key);
    };
    const accessToken = pick('accessToken');
    const refreshToken = pick('refreshToken');
    return accessToken === null || refreshToken === null || accessToken === '' || refreshToken === '' ? null : { accessToken, refreshToken };
  }, prefix);
}

/** Wait until the editor has stored both its tokens, answering them. */
export function waitForEditorTokens(page, editor, timeoutMs) {
  return until(() => readEditorTokens(page, editor), (held) => held !== null, `the ${editor} holds its own token pair`, timeoutMs);
}

/** The shell's policy as the instance sends it, and the exact policy `Test/Static.cls` pins for the same nonce. */
async function shellPolicies(config) {
  const answer = await fetch(`${config.origin}${SHELL_PATH}`);
  const sent = answer.headers.get('content-security-policy') ?? '';
  const nonce = /'nonce-([^']+)'/.exec(sent)?.[1] ?? '';
  const source = readFileSync(join(uiRoot, '..', 'src', 'OcuPilot', 'Test', 'Static.cls'), 'utf8');
  const pinned = /Set tExpected = "([^"]*)" _ tNonce _ "([^"]*)"/.exec(source);
  assert.ok(pinned !== null && nonce !== '', `the pinned policy and the sent nonce are both readable: ${sent}`);
  return { sent, expected: `${pinned[1]}${nonce}${pinned[2]}` };
}

/** `text` with its percent-escapes decoded, or as it is where they are malformed. */
function safeDecode(text) {
  try {
    return decodeURIComponent(text);
  } catch {
    return text;
  }
}

/** Whether `text` names a parameter called `name` in a URL query or a form body. */
function namesParameter(text, name) {
  return [...new URLSearchParams(text.startsWith('?') ? text.slice(1) : text).keys()].some((key) => key.toLowerCase() === name.toLowerCase());
}

/**
 * AC1 and AC2, for one editor frame that has loaded (or is loading) in `page`.
 *
 * `expected` names `config`, the `editor`, the `namespace` and `documentName` the frame was given
 * (`''` for an editor framed empty, which asks for no document), the `traffic`, `messages` and
 * `violations` observers armed before it loaded, and `before`, the `tabSnapshot` taken before it
 * was mounted. Waits for the editor to sign in and, when it was given a document, to ask for it,
 * then asserts every clause; any `frameSelector` may name the frame. A caller that knows the status
 * the document's read must answer (404 for a name nothing holds, 200 for a present one) passes it
 * as `documentStatus`; without it the read need only be answered.
 */
export async function assertSignedInSilently({
  page,
  config,
  editor,
  namespace,
  documentName,
  traffic,
  messages,
  violations,
  before,
  frameSelector = DEFAULT_FRAME_SELECTOR,
  documentStatus = null,
}) {
  const timeoutMs = config.navigationTimeoutMs;
  const frameOf = async () => (await (await page.$(frameSelector)).contentFrame());

  // AC2: nothing was pre-written. Before the frame loaded, every key in the tab was OcuPilot's.
  assert.ok(before.keys.length > 0 && before.keys.every((key) => key.startsWith('ocupilot.')), `before the frame loaded every tab key began ocupilot.: ${JSON.stringify(before.keys)}`);
  assert.notEqual(before.pair, null, 'and the tab held its token pair');
  const ocupilot = JSON.parse(before.pair);

  // AC1: it signed itself in, from the browser-level login, with an empty body and no password.
  const logins = await until(
    () => traffic.filter((entry) => entry.method === 'POST' && entry.path === `${EDITOR_API}login`),
    (entries) => entries.length > 0 && entries.every((entry) => entry.status !== null),
    'the editor posts its login and it is answered',
    timeoutMs
  );
  for (const login of logins) {
    assert.equal(login.body, null, 'the editor login carries no body');
    assert.equal(login.authorization, '', 'and no Authorization header');
    assert.equal(login.status, 200, 'and is answered 200 from the browser-level login alone');
  }
  const tokens = await waitForEditorTokens(page, editor, timeoutMs);
  await until(
    async () => (await frameOf()).evaluate(() => document.body.innerText),
    (text) => text.includes(config.username),
    `the editor renders signed in as ${config.username}`,
    timeoutMs
  );
  const frame = await frameOf();
  assert.equal(await frame.$('input[type="password"]'), null, 'the frame holds no password field');
  assert.equal(await frame.$('input[autocomplete="current-password"]'), null, 'and no current-password field');

  // AC1: it asked for the document its own parameter names (an editor framed with no document asks for none).
  if (documentName !== '') {
    const documentRead = `${EDITOR_API}v7/${encodeURIComponent(namespace)}/${EDITOR_APPS[editor].segment}/${documentName}`;
    const reads = await until(
      () => traffic.filter((entry) => entry.method === 'GET' && entry.path === documentRead),
      (entries) => entries.length > 0 && entries.every((entry) => entry.status !== null),
      `the editor requests ${documentRead} and it is answered`,
      timeoutMs
    );
    if (documentStatus !== null) {
      assert.deepEqual(
        reads.map((entry) => entry.status),
        reads.map(() => documentStatus),
        `the read of ${documentName} is answered ${documentStatus}, as the person the editor signed in as, and not refused`
      );
    }
  }

  // AC1: no request carried a password, either OcuPilot token or a mode flag.
  for (const entry of traffic) {
    const text = safeDecode(`${entry.path}${entry.query}${entry.body ?? ''}${entry.authorization}`);
    const where = `${entry.method} ${entry.path}${entry.query}`;
    assert.ok(!entry.authorization.toLowerCase().startsWith('basic'), `${where} carries no Basic credentials`);
    assert.ok(!/password/i.test(text), `${where} carries no password`);
    const values = [...new URLSearchParams(entry.query).values(), ...entry.path.split('/').map(safeDecode), entry.body ?? ''];
    assert.ok(!values.includes(config.password), `${where} carries the password as no parameter, segment or body`);
    for (const token of [ocupilot.accessToken, ocupilot.refreshToken]) {
      assert.ok(!text.includes(token), `${where} carries neither of OcuPilot's tokens`);
    }
    assert.ok(!/VSCODE|READONLY/i.test(text), `${where} names neither mode flag`);
    assert.equal(namesParameter(entry.query, 'VSCODE'), false, `${where} sets no VSCODE parameter`);
  }
  assert.ok(!/VSCODE/i.test(frame.url()), `the frame's own address names no VSCODE: ${frame.url()}`);

  // AC1: neither the frame nor the shell received a message, and the editor is in normal mode.
  assert.deepEqual(await messages.seen(), [], 'no message reached the shell or the frame');
  assert.equal(await page.evaluate(() => localStorage.getItem('vscodeMode')), null, 'vscodeMode is unset');
  assert.equal(await frame.evaluate(() => localStorage.getItem('vscodeMode')), null, 'also as the frame reads it');
  assert.deepEqual(violations, [], 'no content-security-policy violation was reported');

  // AC2: the editor's tokens are its own, OcuPilot's pair is as it was, and no token sits in persistent storage.
  assert.ok(tokens.accessToken !== ocupilot.accessToken && tokens.accessToken !== ocupilot.refreshToken, "the editor's access token is neither of OcuPilot's tokens");
  assert.ok(tokens.refreshToken !== ocupilot.accessToken && tokens.refreshToken !== ocupilot.refreshToken, "and its refresh token is neither");
  const after = await tabSnapshot(page);
  assert.equal(after.pair, before.pair, "OcuPilot's token pair is byte-identical");
  const persistent = await page.evaluate(() => JSON.stringify(Object.entries(localStorage)));
  for (const token of [ocupilot.accessToken, ocupilot.refreshToken, tokens.accessToken, tokens.refreshToken]) {
    assert.ok(!persistent.includes(token), 'localStorage holds none of the four tokens');
  }
  const policy = await shellPolicies(config);
  assert.equal(policy.sent, policy.expected, "the shell's content-security policy is exactly the one Test/Static.cls pins");
  return { tokens, ocupilot };
}

/** Run `request` as the shell's own document would, from `page`, answering the status and text. */
function inPage(page, request) {
  return page.evaluate(async ({ method, path, headers, body }) => {
    const answer = await fetch(path, { method, headers, body, credentials: 'include' });
    return { status: answer.status, text: await answer.text() };
  }, request);
}

/** The headers the editors' own client sends on every call. */
const JSON_HEADERS = { 'Content-Type': 'application/json', Accept: 'application/json, text/plain, */*' };

const LOGIN = { method: 'POST', path: `${EDITOR_API}login`, headers: JSON_HEADERS, body: undefined };

const readUnder = (accessToken) => ({
  method: 'GET',
  path: `${EDITOR_API}v7/HSCUSTOM/sourcecontrol/enabled`,
  headers: { ...JSON_HEADERS, Authorization: `Bearer ${accessToken}` },
  body: undefined,
});

const refreshWith = (refreshToken) => ({
  method: 'POST',
  path: `${EDITOR_API}refresh`,
  headers: JSON_HEADERS,
  body: JSON.stringify({ refresh_token: refreshToken }),
});

/**
 * Before a sign-out: the three requests AC3 expects to be refused are answered while signed in. The
 * empty-body login answers 200 and mints a pair; a v7 call under the editor's held access token
 * answers 200; and a refresh with the pair that login minted answers 200 (the held refresh token is
 * left unused, so the later refusal is the sign-out's). Answers nothing; asserts.
 */
export async function editorSessionControls(page, held) {
  const login = await inPage(page, LOGIN);
  assert.equal(login.status, 200, 'while signed in the empty-body editors login answers 200');
  const minted = JSON.parse(login.text);
  assert.equal(typeof minted.refresh_token, 'string', 'and mints a refresh token');
  assert.equal((await inPage(page, readUnder(held.accessToken))).status, 200, "while signed in a v7 call under the editor's access token answers 200");
  assert.equal((await inPage(page, refreshWith(minted.refresh_token))).status, 200, 'while signed in a refresh with a live refresh token answers 200');
}

/**
 * Choose Sign out in the account menu and wait until the shell has posted `/logout` and shows its
 * sign-in form. The menu's last item is Sign out, checked by its label.
 */
export async function signOutThroughMenu(page, timeoutMs) {
  const logout = page.waitForResponse((response) => new URL(response.url()).pathname === LOGOUT_PATH && response.request().method() === 'POST', { timeout: timeoutMs });
  await page.click('app-header #ocu-account-trigger');
  await page.waitForSelector('.ocu-account-panel [role="menuitem"]', { visible: true, timeout: timeoutMs });
  const label = await page.evaluate(() => {
    const items = [...document.querySelectorAll('.ocu-account-panel [role^="menuitem"]')];
    const last = items[items.length - 1];
    const text = last.firstChild.textContent.trim();
    last.click();
    return text;
  });
  assert.equal(label, STRINGS.actionSignOut, "the account menu's last item is Sign out");
  assert.ok((await logout).status() < 400, 'the shell posted /logout and it was answered');
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: timeoutMs });
}

/**
 * AC3, after Sign out: no frame remains in the document, no editor key is left in the tab, and the
 * empty-body editors login, a v7 call under `held.accessToken` and a refresh with `held.refreshToken`
 * each answer 401.
 */
export async function assertSignOutEndsEditors(page, held) {
  assert.equal((await page.$$('iframe')).length, 0, 'no frame remains in the document');
  const keys = (await tabSnapshot(page)).keys;
  assert.deepEqual(keys.filter(isEditorKey), [], `no editor key is left in the tab: ${JSON.stringify(keys)}`);
  const answered = {
    login: (await inPage(page, LOGIN)).status,
    accessToken: (await inPage(page, readUnder(held.accessToken))).status,
    refreshToken: (await inPage(page, refreshWith(held.refreshToken))).status,
  };
  assert.deepEqual(
    answered,
    { login: 401, accessToken: 401, refreshToken: 401 },
    "the empty-body editors login, a v7 call under the editor's held access token and a refresh with its held refresh token each answer 401"
  );
}
